import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { createHash } from "node:crypto";
import { z } from "zod";
const key = defineSecret("OPENALEX_API_KEY");
export function safeUrl(value: unknown): string | null {
  try {
    const u = new URL(String(value));
    return u.protocol === "https:" && !u.username && !u.password
      ? u.href
      : null;
  } catch {
    return null;
  }
}
export function normalizeArticle(item: any, source: string) {
  const doi = String(item.doi || item.DOI || "")
    .replace(/^https?:\/\/(dx\.)?doi\.org\//i, "")
    .trim()
    .toLowerCase();
  const title = String(
    source === "OpenAlex" ? item.title : item.title?.[0] || "",
  )
    .replace(/<[^>]+>/g, "")
    .trim();
  const url = safeUrl(
    doi
      ? `https://doi.org/${doi}`
      : item.primary_location?.landing_page_url || item.URL,
  );
  if (!title || !url) return null;
  const parts = item.published?.["date-parts"]?.[0];
  const publishedAt =
    source === "OpenAlex"
      ? item.publication_date
      : parts
        ? `${parts[0]}-${String(parts[1] || 1).padStart(2, "0")}-${String(parts[2] || 1).padStart(2, "0")}`
        : null;
  const authors =
    source === "OpenAlex"
      ? (item.authorships || [])
          .map((a: any) => a.author?.display_name)
          .filter(Boolean)
      : (item.author || []).map((a: any) =>
          [a.given, a.family].filter(Boolean).join(" "),
        );
  return {
    id: createHash("sha256")
      .update(doi || url)
      .digest("hex"),
    doi: doi || null,
    title: title.slice(0, 600),
    url,
    source,
    publisher: String(
      item.primary_location?.source?.display_name || item.publisher || source,
    ),
    publishedAt: publishedAt || null,
    authors: authors.slice(0, 10),
    abstractSnippet: articleAbstract(item),
  };
}
export function articleAbstract(item:any):string|null {
  if(typeof item.abstract === "string") return item.abstract.replace(/<[^>]*>/g," ").replace(/\s+/g," ").trim().slice(0,12000)||null;
  const index=item.abstract_inverted_index;
  if(!index||typeof index!=="object")return null;
  const words=new Map<number,string>();
  for(const [word,positions] of Object.entries(index)) if(Array.isArray(positions))
    for(const position of positions) if(Number.isInteger(position)&&position>=0&&position<3000)words.set(position,word);
  return [...words.entries()].sort((a,b)=>a[0]-b[0]).map(e=>e[1]).join(" ").slice(0,12000)||null;
}
export async function fetchJson(
  url: URL,
  headers: Record<string, string>,
  fetcher: typeof fetch = fetch,
) {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const res = await fetcher(url, {
        headers,
        signal: AbortSignal.timeout(8000),
      });
      if (res.ok) return await res.json();
      if (res.status !== 429 && res.status < 500)
        throw Error("ARTICLE_SOURCE_UNAVAILABLE");
    } catch (e) {
      if (attempt === 2) throw Error("ARTICLE_SOURCE_UNAVAILABLE");
    }
    if (attempt < 2)
      await new Promise((resolve) => setTimeout(resolve, 250 * 2 ** attempt));
  }
  throw Error("ARTICLE_SOURCE_UNAVAILABLE");
}
export const discoverArticles = onCall(
  {
    region: "asia-southeast1",
    maxInstances: 5,
    secrets: [key],
    enforceAppCheck: process.env.ENFORCE_APP_CHECK === "true",
  },
  async (r) => {
    if (!r.auth) throw new HttpsError("unauthenticated", "UNAUTHENTICATED");
    const parsed = z
      .object({
        subjectId: z.string().regex(/^[\w-]+$/),
        query: z.string().trim().max(150).default(""),
        source: z.enum(["OpenAlex", "Crossref"]).default("OpenAlex"),
        page: z.number().int().min(1).max(100).default(1),
        sort: z.enum(["recent", "relevance"]).default("recent"),
        fromDate: z
          .string()
          .regex(/^\d{4}-\d{2}-\d{2}$/)
          .optional(),
      })
      .safeParse(r.data);
    if (!parsed.success)
      throw new HttpsError("invalid-argument", "INVALID_INPUT");
    const d = parsed.data;
    const db = getFirestore();
    const user = (await db.doc(`users/${r.auth.uid}`).get()).data();
    if (
      !user?.active ||
      !["lecturer", "student"].includes(user.role) ||
      !user.subjectIds?.includes(d.subjectId)
    )
      throw new HttpsError("permission-denied", "PERMISSION_DENIED");
    // Per-user request budget before contacting paid external providers.
    await db.runTransaction(async (t) => {
      const ref = db.doc(`rateLimits/${r.auth!.uid}_news`);
      const previous = (await t.get(ref)).data();
      const now = Date.now();
      if (previous && now - previous.start < 60000 && previous.count >= 12)
        throw new HttpsError("resource-exhausted", "RATE_LIMITED");
      t.set(
        ref,
        !previous || now - previous.start >= 60000
          ? { start: now, count: 1 }
          : { start: previous.start, count: previous.count + 1 },
      );
    });
    const subject = (await db.doc(`subjects/${d.subjectId}`).get()).data();
    if (!subject) throw new HttpsError("not-found", "SUBJECT_NOT_FOUND");
    const query = d.query
      ? `${subject.keywords[0]} ${d.query}`
      : subject.keywords.join(" OR ");
    const cacheId = createHash("sha256")
      .update(JSON.stringify({ ...d, query }))
      .digest("hex");
    const cacheRef = db.doc(`articleFeeds/${cacheId}`);
    const cached = (await cacheRef.get()).data();
    const now = Date.now();
    if (cached && cached.expiresAt > now)
      return { ...cached, cached: true, stale: false };
    try {
      const url = new URL(
        d.source === "OpenAlex"
          ? "https://api.openalex.org/works"
          : "https://api.crossref.org/works",
      );
      const headers: Record<string, string> = {
        "User-Agent": "FAP-Smart-Lecturer-Lab2/1.0",
      };
      if (d.source === "OpenAlex") {
        url.searchParams.set("search", query);
        url.searchParams.set("per_page", "20");
        url.searchParams.set("page", String(d.page));
        url.searchParams.set(
          "sort",
          d.sort === "recent"
            ? "publication_date:desc"
            : "relevance_score:desc",
        );
        if (d.fromDate)
          url.searchParams.set("filter", `from_publication_date:${d.fromDate}`);
        const apiKey =
          process.env.FUNCTIONS_EMULATOR === "true"
            ? process.env.OPENALEX_API_KEY
            : key.value();
        if (
          apiKey &&
          !(
            process.env.FUNCTIONS_EMULATOR === "true" &&
            apiKey === "emulator-public-access"
          )
        )
          headers.Authorization = `Bearer ${apiKey}`;
      } else {
        url.searchParams.set("query", query);
        url.searchParams.set("rows", "20");
        url.searchParams.set("offset", String((d.page - 1) * 20));
        url.searchParams.set(
          "sort",
          d.sort === "recent" ? "published" : "relevance",
        );
        url.searchParams.set("order", "desc");
        if (d.fromDate)
          url.searchParams.set("filter", `from-pub-date:${d.fromDate}`);
        if (process.env.CROSSREF_MAILTO)
          url.searchParams.set("mailto", process.env.CROSSREF_MAILTO);
      }
      const json: any = await fetchJson(url, headers);
      const items = d.source === "OpenAlex" ? json.results : json.message.items;
      const unique = new Map<string, any>();
      for (const item of items) {
        const a = normalizeArticle(item, d.source);
        if (a) unique.set(a.id, a);
      }
      const articles = [...unique.values()];
      const batch = db.batch();
      for (const a of articles)
        batch.set(
          db.doc(`articleCache/${a.id}`),
          {
            ...a,
            subjectIds: FieldValue.arrayUnion(d.subjectId),
            fetchedAt: now,
            expiresAt: now + 21600000,
          },
          { merge: true },
        );
      const feed = {
        articles,
        nextPage: items.length === 20 ? d.page + 1 : null,
        fetchedAt: now,
        expiresAt: now + 21600000,
      };
      batch.set(cacheRef, feed);
      await batch.commit();
      return { ...feed, cached: false, stale: false };
    } catch {
      if (cached) return { ...cached, cached: true, stale: true };
      throw new HttpsError("unavailable", "ARTICLE_SOURCE_UNAVAILABLE");
    }
  },
);
