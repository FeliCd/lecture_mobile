// Preview by default. Operator-only tool: never runs in the Flutter client.
const fs = require("node:fs");
const path = require("node:path");
const localRequire = require("node:module").createRequire(
  path.resolve(__dirname, "../functions/package.json"),
);
function parseCsv(text) {
  const rows = [];
  let row = [],
    cell = "",
    quoted = false;
  text = text.replace(/^\uFEFF/, "");
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') {
      if (quoted && text[i + 1] === '"') {
        cell += '"';
        i++;
      } else quoted = !quoted;
    } else if (c === "," && !quoted) {
      row.push(cell);
      cell = "";
    } else if ((c === "\n" || c === "\r") && !quoted) {
      if (c === "\r" && text[i + 1] === "\n") i++;
      row.push(cell);
      if (row.some((v) => v.trim())) rows.push(row);
      row = [];
      cell = "";
    } else cell += c;
  }
  if (quoted) throw Error("Unclosed CSV quote");
  if (cell || row.length) {
    row.push(cell);
    rows.push(row);
  }
  return rows;
}
function preview(text) {
  const [header, ...rows] = parseCsv(text);
  if (!header) throw Error("Empty CSV");
  for (const h of ["classCode", "studentCode", "fullName"])
    if (!header.includes(h)) throw Error(`Missing ${h}`);
  const seen = new Set(),
    errors = [],
    valid = [];
  rows.forEach((cells, i) => {
    const r = Object.fromEntries(
      header.map((h, j) => [h.trim(), (cells[j] || "").trim()]),
    );
    const key = `${r.classCode.toUpperCase()}_${r.studentCode.toUpperCase()}`;
    const message =
      !r.classCode || !r.studentCode || !r.fullName
        ? "Missing required values"
        : seen.has(key)
          ? "Duplicate class/student"
          : r.email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(r.email)
            ? "Invalid email"
            : null;
    seen.add(key);
    if (message) errors.push({ row: i + 2, message });
    else
      valid.push({
        ...r,
        classCode: r.classCode.toUpperCase(),
        studentCode: r.studentCode.toUpperCase(),
      });
  });
  return { valid, errors };
}
async function main() {
  const args = process.argv.slice(2),
    file = args.find((a) => !a.startsWith("--"));
  if (!file) throw Error("node scripts/import-roster.cjs roster.csv [--apply]");
  const report = preview(fs.readFileSync(file, "utf8"));
  console.log(
    JSON.stringify(
      { validCount: report.valid.length, errors: report.errors },
      null,
      2,
    ),
  );
  if (!args.includes("--apply")) return;
  if (report.errors.length) throw Error("Resolve row errors before applying");
  if (
    !process.env.FIRESTORE_EMULATOR_HOST ||
    !process.env.FIREBASE_AUTH_EMULATOR_HOST
  )
    throw Error(
      "This Lab import tool only applies to emulators; production requires a reviewed operator process.",
    );
  const { initializeApp } = localRequire("firebase-admin/app"),
    { getFirestore, Timestamp } = localRequire("firebase-admin/firestore"),
    { getAuth } = localRequire("firebase-admin/auth");
  initializeApp({ projectId: "demo-fap-lab2" });
  const db = getFirestore(),
    auth = getAuth();
  let added = 0,
    pending = 0;
  for (const row of report.valid) {
    const classes = await db
      .collection("classes")
      .where("classCode", "==", row.classCode)
      .get();
    if (classes.size !== 1)
      throw Error(
        `Ambiguous or unknown classCode ${row.classCode}; include unique term mapping before import`,
      );
    const cls = classes.docs[0];
    let user = null;
    if (row.email) {
      try {
        user = await auth.getUserByEmail(row.email);
      } catch (e) {
        if (e.code !== "auth/user-not-found") throw e;
      }
    }
    if (!user) {
      await db
        .doc(`pendingEnrollments/${cls.id}_${row.studentCode}`)
        .set({ ...row, classId: cls.id, status: "pending_uid_mapping" });
      pending++;
      continue;
    }
    await db.runTransaction(async (t) => {
      const c = (await t.get(cls.ref)).data(),
        profile = (await t.get(db.doc(`users/${user.uid}`))).data();
      if (!profile?.active || profile.role !== "student")
        throw Error("UID is not an approved student");
      const existing = await t.get(
        db
          .collection(`classes/${cls.id}/members`)
          .where("studentCode", "==", row.studentCode),
      );
      if (existing.docs.some((d) => d.id !== user.uid))
        throw Error(`studentCode already mapped: ${row.studentCode}`);
      const members = [...new Set([...c.studentUids, user.uid])];
      const m = db.doc(`classes/${cls.id}/members/${user.uid}`);
      const previous = (await t.get(m)).data();
      t.set(m, {
        studentUid: user.uid,
        studentCode: row.studentCode,
        displayName: row.fullName,
        active: true,
        enrolledAt: previous?.enrolledAt || Timestamp.now(),
      });
      t.update(cls.ref, { studentUids: members, studentCount: members.length });
      t.update(db.doc(`users/${user.uid}`), {
        subjectIds: [...new Set([...(profile.subjectIds || []), c.subjectId])],
      });
    });
    added++;
  }
  console.log({ added, pending });
}
module.exports = { parseCsv, preview };
if (require.main === module)
  main().catch((e) => {
    console.error(e.message);
    process.exitCode = 1;
  });
