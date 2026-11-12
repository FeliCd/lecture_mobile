const assert = require("node:assert/strict");
const { test, before, after } = require("node:test");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { SharedDataset, rowId, enforceSharedRateLimit } = require("../lib/shared/dataset");
const { groupSignup, parseSignupInput } = require("../lib/shared/group-signup");

const projectId = "demo-fap-lab2";
const datasetId = "dataset-11111111-1111-4111-8111-111111111111";
const domains = new Set(["fpt.edu.vn"]);
const identity = (email, verified = true, provider = "google.com") => ({
  email: email + "@fpt.edu.vn", email_verified: verified, firebase: { sign_in_provider: provider },
});
const teacher = identity("lecturer");
const s1 = identity("student1");
const s2 = identity("student2");
let app, db, root, dataset;

before(async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, "Run this test against Firestore emulator");
  app = initializeApp({ projectId }, "shared-group-signup-test");
  db = getFirestore(app);
  root = db.doc("sharedApiDatasets/" + datasetId);
  await db.recursiveDelete(root);
  await root.set({ state: "ready", sequence: 17 });
  dataset = new SharedDataset(db, datasetId);
  const seed = [
    ["Classes", "c1", { classId: "c1", lecturerId: "l1" }],
    ["Lecturers", "l1", { lecturerId: "l1", email: teacher.email }, teacher.email],
    ["Lecturers", "l2", { lecturerId: "l2", email: "other@fpt.edu.vn" }, "other@fpt.edu.vn"],
    ["Students", "s1", { studentId: "s1", schoolEmail: s1.email }, s1.email],
    ["Students", "s2", { studentId: "s2", schoolEmail: s2.email }, s2.email],
    ["Enrollments", "e1", { enrollmentId: "e1", classId: "c1", studentId: "s1" }],
    ["Enrollments", "e2", { enrollmentId: "e2", classId: "c1", studentId: "s2" }],
  ];
  await Promise.all(seed.map(([table, id, row, identityEmail], index) =>
    root.collection(table).doc(rowId(id)).set({
      row, position: String(index), ...(identityEmail ? { identityEmail } : {}),
    })));
});
after(async () => {
  if (root) await db.recursiveDelete(root);
  if (app) await deleteApp(app);
});
const call = (actor, data) => dataset.run((rows) =>
  groupSignup(rows, actor, parseSignupInput({ classId: "c1", ...data }), domains));

test("verified owner opens a round, concurrent students choose, and closure preserves group plan", async () => {
  const open = { action: "open", version: 0, groupCount: 2, requestKey: "open-group-round-01" };
  await assert.rejects(call(s1, open), /PERMISSION_DENIED/);
  await assert.rejects(call(identity("other"), open), /NOT_ENROLLED/);
  await assert.rejects(call(identity("lecturer", false), open), /PERMISSION_DENIED/);
  await assert.rejects(call(identity("lecturer", true, "password"), open), /NOT_ENROLLED/);
  await assert.rejects(call(teacher, { ...open, version: 99 }), /VERSION_CONFLICT/);
  assert.equal((await call(s1, { action: "status" })).state, "NONE");
  const round = await call(teacher, open);
  assert.equal(round.state, "OPEN");
  assert.equal(round.groupCount, 2);
  assert.equal((await call(teacher, open)).roundId, round.roundId);
  assert.equal((await root.get()).get("sequence"), 18);
  const [g1, g2] = round.groups;
  const studentView = await call(s1, { action: "status" });
  assert.equal(studentView.selectedGroupId, null);
  assert.ok(studentView.groups.every((group) => !("memberIds" in group)));
  await assert.rejects(call(identity("unregistered"), { action: "status" }), /NOT_ENROLLED/);

  const choose = { action: "choose", roundId: round.roundId, groupId: g1.id };
  await assert.rejects(call(s1, { ...choose, studentId: "s2" }), /INVALID_INPUT/);
  await Promise.all([call(s1, choose), call(s2, choose)]);
  const planRef = root.collection("PortalGroupPlans").doc(rowId("c1"));
  const first = await planRef.get();
  assert.equal(first.get("row.version"), "3");
  assert.deepEqual(JSON.parse(first.get("row.groups"))[0].memberIds.sort(), ["s1", "s2"]);

  await call(s1, choose);
  assert.equal((await planRef.get()).get("row.version"), "3");
  const switched = await call(s1, { ...choose, groupId: g2.id });
  assert.equal(switched.selectedGroupId, g2.id);
  const updated = await planRef.get();
  assert.equal(updated.get("position"), first.get("position"));
  assert.deepEqual(JSON.parse(updated.get("row.groups")).map((group) => group.memberIds), [["s2"], ["s1"]]);
  const ownPlan = await call(s1, { action: "plan" });
  assert.deepEqual(ownPlan.groups.map((item) => item.id), [g2.id]);
  assert.deepEqual(ownPlan.students.map((student) => Object.keys(student).sort()), [
    ["fullName", "studentCode", "studentId"],
  ]);
  assert.deepEqual(ownPlan.students.map((student) => student.studentId), ["s1"]);
  assert.equal((await call(teacher, { action: "plan" })).students.length, 2);

  await assert.rejects(call(s1, { action: "close", roundId: round.roundId }), /PERMISSION_DENIED/);
  const closed = await call(teacher, { action: "close", roundId: round.roundId });
  assert.equal(closed.state, "CLOSED");
  assert.equal(closed.assignedCount, 2);
  await assert.rejects(call(s2, choose), /GROUP_SIGNUP_NOT_OPEN/);
  assert.equal((await call(s2, { action: "status" })).state, "NONE");
  assert.equal((await planRef.get()).get("row.version"), "4");
  const legacy = root.collection("PortalGroupSignupSheets").doc(rowId("c1"));
  await legacy.set({ row: { classId: "c1", state: "OPEN" }, position: "0" });
  await assert.rejects(
    call(teacher, { ...open, version: 4, requestKey: "open-group-round-02" }),
    /LEGACY_GROUP_SIGNUP_OPEN/,
  );
  await legacy.delete();

  const reopened = await call(teacher, { ...open, version: 4, requestKey: "open-group-round-02" });
  assert.notEqual(reopened.roundId, round.roundId);
  assert.equal(reopened.assignedCount, 2);
  await assert.rejects(call(s1, choose), /GROUP_SIGNUP_NOT_OPEN/);
});

test("limits repeated Firebase requests transactionally", async () => {
  const uid = "test-" + require("node:crypto").randomUUID();
  await enforceSharedRateLimit(db, uid, "group-signup", 1);
  await assert.rejects(enforceSharedRateLimit(db, uid, "group-signup", 1), /RATE_LIMITED/);
});
const { getAuth } = require("firebase-admin/auth");

test("callable requires a Firebase ID token and checks the student's membership", async (context) => {
  if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) return context.skip("Start Auth and Functions emulators to test HTTPS");
  const auth = getAuth(app);
  const uid = "group-signup-emulator-student";
  const email = s1.email;
  const password = "Test-only-password-9";
  await auth.deleteUser(uid).catch((error) => {
    if (error.code !== "auth/user-not-found") throw error;
  });
  await auth.createUser({ uid, email, emailVerified: true, password });
  try {
    const signIn = await fetch(
      "http://" + process.env.FIREBASE_AUTH_EMULATOR_HOST + "/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator",
      { method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password, returnSecureToken: true }) },
    );
    assert.equal(signIn.status, 200);
    const { idToken } = await signIn.json();
    const endpoint = "http://127.0.0.1:5001/" + projectId + "/asia-southeast1/sharedGroupSignup";
    const request = (token) => fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...(token ? { Authorization: "Bearer " + token } : {}) },
      body: JSON.stringify({ data: { action: "status", classId: "c1" } }),
    });
    const anonymous = await request();
    assert.equal(anonymous.status, 401);
    const verified = await request(idToken);
    const json = await verified.json();
    assert.equal(verified.status, 200, JSON.stringify(json));
    assert.equal(json.result.state, "OPEN");
  } finally {
    await auth.deleteUser(uid);
  }
});
