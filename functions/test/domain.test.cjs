const { test } = require("node:test");
const assert = require("node:assert/strict");
const { signQr, verifyQr, attendanceRate } = require("../lib/domain");
const { normalizeArticle, safeUrl, fetchJson } = require("../lib/news");
test("signed QR valid, expired, tampered, wrong secret and obsolete slot", () => {
  const now = 240001;
  const p = { sessionId: "s", slotId: 2, sessionVersion: 1, expiresAt: 360000 };
  const token = signQr(p, "secret");
  assert.deepEqual(verifyQr(token, "secret", now), p);
  assert.throws(() => verifyQr(token, "wrong", now), /QR_INVALID/);
  assert.throws(() => verifyQr(token + "x", "secret", now), /QR_INVALID/);
  assert.throws(() => verifyQr(token, "secret", 360000), /QR_EXPIRED/);
  assert.throws(
    () => verifyQr(signQr({ ...p, slotId: 1 }, "secret"), "secret", now),
    /QR_EXPIRED/,
  );
});
test("attendance denominator excludes excused and late counts as attended", () => {
  assert.ok(
    Math.abs(
      attendanceRate(["present", "late", "absent", "excused"]) - 200 / 3,
    ) < 1e-10,
  );
  assert.equal(attendanceRate(["excused"]), null);
  assert.equal(attendanceRate([]), null);
});
test("DOI normalization dedupes across providers and rejects unsafe URLs", () => {
  const a = normalizeArticle(
    {
      title: "A",
      doi: "https://doi.org/10.1/AbC",
      publication_date: "2026-10-01",
    },
    "OpenAlex",
  );
  const b = normalizeArticle({ title: ["B"], DOI: "10.1/abc" }, "Crossref");
  assert.equal(a.id, b.id);
  assert.equal(
    normalizeArticle(
      {
        title: "A",
        primary_location: { landing_page_url: "javascript:alert(1)" },
      },
      "OpenAlex",
    ),
    null,
  );
  assert.equal(safeUrl("https://user:pass@example.com"), null);
});
test("article source retries 429 then succeeds and rejects bad metadata", async () => {
  let attempts = 0;
  const result = await fetchJson(
    new URL("https://example.test"),
    {},
    async () =>
      ++attempts < 2
        ? { ok: false, status: 429 }
        : { ok: true, json: async () => ({ results: [] }) },
  );
  assert.equal(attempts, 2);
  assert.deepEqual(result, { results: [] });
  assert.equal(normalizeArticle({ DOI: "10.1/x" }, "Crossref"), null);
});
