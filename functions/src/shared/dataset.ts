import { createHash } from "node:crypto";
import {
  Firestore,
  Transaction,
  DocumentReference,
  DocumentSnapshot,
  Timestamp,
} from "firebase-admin/firestore";

export const rowId = (value: string) =>
  createHash("sha256").update(value).digest("hex");

type Row = Record<string, string>;
type Change = {
  table: string;
  key: string;
  id: string;
  row: Record<string, unknown> | null;
};

export class SharedDataset {
  constructor(
    private readonly db: Firestore,
    private readonly datasetId: string,
  ) {
    if (!/^dataset-[a-f0-9-]{36}$/.test(datasetId))
      throw new Error("INVALID_SHARED_FIRESTORE_CONFIG");
  }

  async run<T>(operation: (rows: SharedRows) => Promise<T>, writesEnabled = true, requireFirebaseWriter = false): Promise<T> {
    const ref = this.db.collection("sharedApiDatasets").doc(this.datasetId);
    return this.db.runTransaction(async (transaction) => {
      const marker = await transaction.get(ref);
      if (marker.get("state") !== "ready") throw new Error("DATABASE_NOT_READY");
      const rows = new SharedRows(transaction, marker);
      const result = await operation(rows);
      if (rows.hasChanges && (!writesEnabled || (requireFirebaseWriter && !rows.firebaseWriter))) throw new Error("DATABASE_MAINTENANCE");
      await rows.commit();
      return result;
    });
  }
}

export class SharedRows {
  private readonly changes = new Map<string, Change>();
  private readonly attachments = new Map<string, Buffer>();
  private readonly mail = new Map<string, { to: string; message: { subject: string; text: string } }>();
  private readonly cache = new Map<string, Promise<DocumentSnapshot[]>>();

  get firebaseWriter(): boolean {
    return this.marker.get("backendWriter") === "firebase";
  }

  get hasChanges(): boolean {
    return this.changes.size > 0 || this.attachments.size > 0 || this.mail.size > 0;
  }

  constructor(
    private readonly transaction: Transaction,
    private readonly marker: DocumentSnapshot,
  ) {}

  private ref(table: string, id: string): DocumentReference {
    return this.marker.ref.collection(table).doc(rowId(id));
  }

  private decode(snapshot: DocumentSnapshot, key: string): Row {
    const row = snapshot.get("row") as Row | undefined;
    if (!row?.[key] || rowId(row[key]) !== snapshot.id ||
        Object.values(row).some((value) => typeof value !== "string") ||
        typeof snapshot.get("position") !== "string") {
      throw new Error("INVALID_FIRESTORE_ROW");
    }
    return row;
  }

  private async select(
    table: string,
    key: string,
    selector: string,
    query: () => Promise<DocumentSnapshot[]>,
    matches: (row: Row) => boolean,
  ): Promise<Row[]> {
    const cacheKey = JSON.stringify([table, selector]);
    let read = this.cache.get(cacheKey);
    if (!read) {
      read = query();
      this.cache.set(cacheKey, read);
    }
    const ordered = (await read).filter((doc) => doc.exists)
      .sort((a, b) => a.get("position").localeCompare(b.get("position")));
    const result = new Map(ordered.map((doc) => {
      const row = this.decode(doc, key);
      return [row[key], row];
    }));
    for (const change of this.changes.values()) {
      if (change.table !== table) continue;
      const row = change.row && Object.fromEntries(Object.entries(change.row)
        .map(([field, value]) => [field, String(value ?? "")]));
      if (row && matches(row)) result.set(change.id, row);
      else result.delete(change.id);
    }
    return [...result.values()].map((row) => ({ ...row }));
  }

  async get(table: string, key: string, id: string): Promise<Row | undefined> {
    return (await this.getAll(table, key, [id]))[0];
  }

  async getAll(table: string, key: string, ids: string[]): Promise<Row[]> {
    const unique = [...new Set(ids)].sort();
    if (!unique.length) return [];
    const set = new Set(unique);
    return this.select(table, key, JSON.stringify(["ids", unique]),
      () => this.transaction.getAll(...unique.map((id) => this.ref(table, id))),
      (row) => set.has(row[key]));
  }

  list(table: string, key: string): Promise<Row[]> {
    return this.select(table, key, "all", async () =>
      (await this.transaction.get(this.marker.ref.collection(table))).docs, () => true);
  }

  where(table: string, key: string, field: string, value: string): Promise<Row[]> {
    return this.whereAny(table, key, field, [value]);
  }

  whereAny(table: string, key: string, field: string, values: string[]): Promise<Row[]> {
    const unique = [...new Set(values)].sort();
    if (!unique.length) return Promise.resolve([]);
    const set = new Set(unique);
    return this.select(table, key, JSON.stringify([field, unique]), async () => {
      const result: DocumentSnapshot[] = [];
      for (let offset = 0; offset < unique.length; offset += 25) {
        const chunk = unique.slice(offset, offset + 25);
        const query = this.marker.ref.collection(table)
          .where(field, chunk.length === 1 ? "==" : "in", chunk.length === 1 ? chunk[0] : chunk);
        result.push(...(await this.transaction.get(query)).docs);
      }
      return result;
    }, (row) => field === "identityEmail"
      ? set.has((row[table === "Lecturers" ? "email" : "schoolEmail"] || "").trim().toLowerCase())
      : set.has(row[field.slice(4)]));
  }

  private attachmentRef(id: string): DocumentReference {
    return this.marker.ref.collection("GroupAttachmentContent").doc(rowId(id));
  }

  async readAttachment(id: string): Promise<Buffer> {
    const value = this.attachments.get(id) ?? (await this.transaction.get(this.attachmentRef(id))).get("bytes");
    if (!Buffer.isBuffer(value) || !value.length || value.length > 512000)
      throw new Error("GROUP_FILE_UNAVAILABLE");
    return value;
  }

  storeAttachment(id: string, bytes: Buffer): void {
    if (!id || !bytes.length || bytes.length > 512000) throw new Error("INVALID_FILE");
    this.attachments.set(id, bytes);
  }

  private mailRef(id: string): DocumentReference {
    return this.marker.ref.firestore.collection("sharedTaskMail").doc(rowId(this.marker.id + "|" + id));
  }

  async mailDelivery(id: string): Promise<{ state?: string } | undefined> {
    const snapshot = await this.transaction.get(this.mailRef(id));
    return snapshot.exists ? snapshot.get("delivery") ?? {} : undefined;
  }

  queueMail(id: string, to: string, subject: string, text: string): void {
    this.mail.set(id, { to, message: { subject, text } });
  }

  remove(table: string, id: string): void {
    if (!id) throw new Error("INVALID_INPUT");
    this.changes.set(this.ref(table, id).path, { table, id, key: "", row: null });
  }

  set(table: string, key: string, row: Record<string, unknown>): void {
    const id = String(row[key] ?? "");
    if (!id) throw new Error("INVALID_INPUT");
    this.changes.set(this.ref(table, id).path, { table, key, id, row });
  }

  async commit(): Promise<void> {
    if (!this.hasChanges) return;
    const sequence = this.marker.get("sequence");
    if (!Number.isSafeInteger(sequence) || sequence < 0 || sequence >= Number.MAX_SAFE_INTEGER)
      throw new Error("DATABASE_NOT_READY");

    // Keep the old document IDs, string values, and insertion order. The marker
    // serializes mutations that enforce invariants across multiple collections.
    const changes = [...this.changes.values()];
    const refs = changes.map(({ table, id }) => this.ref(table, id));
    const previous = refs.length ? await this.transaction.getAll(...refs) : [];
    const stamp = String(sequence + 1).padStart(16, "0");
    changes.forEach(({ table, key, row }, index) => {
      if (!row) {
        this.transaction.delete(refs[index]);
        return;
      }
      const data = Object.fromEntries(Object.entries(row).map(([name, value]) =>
        [name, String(value ?? "")]));
      if (!data[key]) throw new Error("INVALID_INPUT");
      const position = previous[index].exists
        ? previous[index].get("position")
        : "1" + stamp + String(index).padStart(7, "0");
      if (typeof position !== "string") throw new Error("INVALID_FIRESTORE_ROW");
      const emailField = table === "Lecturers" ? "email" : table === "Students" ? "schoolEmail" : null;
      this.transaction.set(refs[index], {
        row: data,
        position,
        ...(emailField ? { identityEmail: (data[emailField] || "").trim().toLowerCase() } : {}),
      });
    });
    for (const [id, bytes] of this.attachments)
      this.transaction.set(this.attachmentRef(id), { bytes });
    for (const [id, message] of this.mail) this.transaction.create(this.mailRef(id), message);
    this.transaction.update(this.marker.ref, { sequence: sequence + 1 });
  }
}

export async function enforceSharedRateLimit(db: Firestore, uid: string, action: string, max: number): Promise<void> {
  const ref = db.collection("sharedApiRateLimits").doc(rowId(uid + "|" + action));
  await db.runTransaction(async (transaction) => {
    const now = Date.now();
    const snapshot = await transaction.get(ref);
    const start = snapshot.get("start");
    const sameWindow = typeof start === "number" && now - start < 60_000;
    const count = sameWindow ? Number(snapshot.get("count")) : 0;
    if (count >= max) throw new Error("RATE_LIMITED");
    transaction.set(ref, {
      start: sameWindow ? start : now,
      count: count + 1,
      expiresAt: Timestamp.fromMillis(now + 120_000),
    });
  });
}
