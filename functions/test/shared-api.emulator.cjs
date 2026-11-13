const assert = require("node:assert/strict");
const { before, after, test } = require("node:test");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { fixture } = require("../../backend/test/portal-fixture.cjs");
const { dispatch } = require("../lib/shared/domain/logic");
const { SharedDataset, rowId } = require("../lib/shared/dataset");

const datasetId = "dataset-22222222-2222-4222-8222-222222222222";
const actor = (email, provider = "google.com") => ({ email, signInProvider: provider, firebaseUid: email });
const teacher = actor("teacher@fpt.edu.vn");
const student = actor("student@fpt.edu.vn", "password");
const other = actor("other@fpt.edu.vn");
let app, root, dataset;
const fixtureData = fixture();
const localDate = new Date(Date.now() + 7 * 3600000);
const date = localDate.toISOString().slice(0,10);
const day = localDate.getUTCDay() || 7;
fixtureData.add("Schedules", { scheduleId: "test-today", lecturerId: "l1", classCode: "SE1", subjectCode: "PRM393",
  dayOfWeek: day, slot: 1, startTime: "00:00", endTime: "23:59", room: "A101" });

before(async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, "Only run against the Firestore emulator");
  app = initializeApp({ projectId: "demo-fap-lab2" }, "shared-api-test");
  const db = getFirestore(app);
  root = db.doc("sharedApiDatasets/" + datasetId);
  await db.recursiveDelete(root);
  await root.set({ state: "ready", sequence: 0 });
  const batch = db.batch();
  for (const [table, [header, ...rows]] of Object.entries(fixtureData.store)) {
    rows.forEach((values, index) => {
      const row = Object.fromEntries(header.map((key,i) => [key, values[i]]));
      const identityEmail = table === "Lecturers" ? row.email : table === "Students" ? row.schoolEmail : null;
      batch.set(root.collection(table).doc(rowId(values[0])), {
        row, position: String(index).padStart(10,"0"), ...(identityEmail ? { identityEmail } : {}),
      });
    });
  }
  await batch.commit();
  dataset = new SharedDataset(db, datasetId);
});
after(async () => {
  if (root) await getFirestore(app).recursiveDelete(root);
  if (app) await deleteApp(app);
});
const call = (identity, request, writable = true) => dataset.run((rows) =>
  dispatch(Object.assign(rows, {
    identity,
    pushAfterCommit: (_, result) => {
      if (result && typeof result === "object") delete result._groupPush;
      return result;
    },
  }), request), writable);
const portal = (identity, method, data, writable) =>
  call(identity, { action: "portalCall", firebaseAuth: identity === student, method, data }, writable);
const mobile = (name, input) => call(teacher, { action: "lab2Call", name, input });
const desktop = (name, input) => call(teacher, { action: "desktopAttendanceCall", name, input });

test("desktop and mobile share attendance revisions, captured roster, and retry receipts", async () => {
  const scope = { classId: "c1", sessionDate: date, slot: 1, scheduleId: "test-today", exceptionId: "" };
  const context = await desktop("getQuickAttendanceContext", scope);
  assert.equal(context.students.length, 2);
  const request = { ...scope, expectedRevision: context.revision, clientRequestId: "desktop-test-1",
    studentIds: context.students.map((row) => row.studentId), exceptions: [{ studentId: "s2", status: "ABSENT" }] };
  const saved = await desktop("submitQuickAttendance", request);
  assert.equal(saved.status, "CLOSED");
  const retry = await desktop("submitQuickAttendance", request);
  assert.equal(retry.alreadySaved, true);
  const next = await mobile("getQuickAttendanceContext", scope);
  assert.equal(next.students.find(row => row.studentId === "s1").status, "present");
  assert.equal(next.students.find(row => row.studentId === "s2").status, "absent");
  await assert.rejects(call(other, { action: "desktopAttendanceCall", name: "getQuickAttendanceContext", input: scope }), /PERMISSION_DENIED/);
  const snapshot = await call(teacher, { action: "lab2Snapshot", googleLecturerOnly: true });
  assert.equal(snapshot.collections.classes.length, 1);
});

test("mobile publishes the shared gradebook and Student Web sees only the published snapshot", async () => {
  const classId = "c1";
  const mobilePortal = (method, data) => mobile("portalCall", { method, data });
  const getGradebook = await mobilePortal("getGradebook", { classId });
  const students = getGradebook.students.map(row => ({ studentId: row.studentId, grades: { quiz: row.studentId === "s1" ? 0 : 10 }, comment: "" }));
  const draft = { classId, version: 0, students, components: [{ id: "quiz", name: "Quiz", maxScore: 10 }] };
  await assert.rejects(portal(teacher,"saveGradebook",draft,false), /DATABASE_MAINTENANCE/);
  await mobilePortal("saveGradebook", draft);
  assert.equal((await portal(student,"getMyPublishedGrades",{classId})).published, false);
  const payload = { classId, version: 1, requestKey: "publish-from-mobile-001", studentIds: students.map(row => row.studentId) };
  const publication = await mobilePortal("publishGrades", payload);
  assert.equal((await mobilePortal("publishGrades", payload)).publicationId, publication.publicationId);
  const desktopBook = await portal(teacher, "getGradebook", { classId });
  assert.equal(desktopBook.activePublicationId, publication.publicationId);
  assert.equal(desktopBook.version, 2);
  const published = await portal(student, "getMyPublishedGrades", { classId });
  assert.equal(published.publicationId, publication.publicationId);
  assert.equal(published.grades.quiz, 0);
  await assert.rejects(portal(student,"getGradebook",{classId}), /PERMISSION_DENIED/);
  await assert.rejects(portal(other,"getGradebook",{classId}), /PERMISSION_DENIED/);
});

test("group chat stores attachment bytes atomically and authorizes downloads through membership", async () => {
  const classId = "c1", groupId = "group-id-for-tests", otherId = "other-group-id-for-tests";
  await portal(teacher,"saveGroupPlan",{classId,version:0,requestKey:"save-test-group-001",groups:[
    {id:groupId,name:"One",memberIds:["s1"]},{id:otherId,name:"Two",memberIds:["s2"]},
  ]});
  const base64 = Buffer.from("Firebase attachment fixture").toString("base64");
  const sent = await portal(teacher,"sendGroupMessage",{classId,groupId,requestKey:"test-message-receipt",text:"Hello",file:{name:"proof.txt",base64}});
  const view = await portal(student,"getGroupMessages",{classId,groupId});
  assert.equal(view.messages[0].hasFile,true);
  assert.equal(view.messages[0].fileId,undefined);
  assert.equal((await portal(student,"downloadGroupFile",{classId,groupId,messageId:sent.id})).base64,base64);
  await assert.rejects(portal(student,"getGroupMessages",{classId,groupId:otherId}), /GROUP_ACCESS_DENIED/);
});
const { getAuth } = require("firebase-admin/auth");

test("deployed HTTP envelope protects private actions and accepts a verified Firebase student", async (context) => {
  if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) return context.skip("Start Auth and Functions emulators to test HTTPS");
  const auth = getAuth(app);
  const uid = "shared-api-student";
  const email = student.email;
  const password = "Test-only-password-8";
  await auth.createUser({ uid, email, emailVerified: true, password });
  try {
    const signIn = await fetch(
      "http://" + process.env.FIREBASE_AUTH_EMULATOR_HOST + "/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator",
      { method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password, returnSecureToken: true }) },
    );
    assert.equal(signIn.status, 200);
    const { idToken } = await signIn.json();
    const endpoint = "http://127.0.0.1:5001/demo-fap-lab2/asia-southeast1/sharedApi";
    const request = (body, token) => fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...(token ? { Authorization: "Bearer " + token } : {}) },
      body: JSON.stringify(body),
    }).then(response => response.json());
    assert.equal((await request({ action: "lab2Health" })).data.database, "firestore");
    assert.deepEqual(await request({ action: "lab2Snapshot" }), { ok: false, error: "UNAUTHENTICATED" });
    const classes = await request({ action: "portalCall", method: "listClasses", firebaseAuth: true }, idToken);
    assert.deepEqual(classes.data.map(cls => cls.classId), ["c1"]);
    const desk = await request({ action: "profile" }, idToken);
    assert.equal(desk.error, "GOOGLE_ONLY");
  } finally {
    await auth.deleteUser(uid);
  }
});
