const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  collection,
  query,
  where,
  getDocs,
  serverTimestamp,
  updateDoc,
} = require("firebase/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { signQr } = require("../lib/domain");
const projectId = "demo-fap-lab2";
let env;
const tokens = {};
let db;
async function token(email) {
  const response = await fetch(
    "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email,
        password: process.env.DEMO_PASSWORD || "EmulatorOnly123!",
        returnSecureToken: true,
      }),
    },
  );
  const json = await response.json();
  if (!json.idToken) throw Error(JSON.stringify(json));
  return json.idToken;
}
async function call(name, data, user = "lecturer-0") {
  const response = await fetch(
    `http://127.0.0.1:5001/${projectId}/asia-southeast1/${name}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(user ? { Authorization: `Bearer ${tokens[user]}` } : {}),
      },
      body: JSON.stringify({ data }),
    },
  );
  const json = await response.json();
  if (json.error) throw Error(json.error.message);
  assert.ok(json.result !== undefined, JSON.stringify(json));
  return json.result;
}
before(
  async () => {
    if (!process.env.FIRESTORE_EMULATOR_HOST)
      throw Error("Run with firebase emulators:exec");
    env = await initializeTestEnvironment({
      projectId,
      firestore: {
        rules: fs.readFileSync("../firebase/firestore.rules", "utf8"),
        host: "127.0.0.1",
        port: 8080,
      },
    });
    initializeApp({ projectId });
    db = getFirestore();
    await db
      .doc("testClock/control")
      .set({ now: Math.floor(Date.now() / 120000) * 120000 + 1000 });
    for (const [uid, email] of [
      ["lecturer-0", "lecturer.a@example.test"],
      ["lecturer-1", "lecturer.b@example.test"],
      ["student-0", "student.0@example.test"],
      ["outsider", "outsider@example.test"],
    ])
      tokens[uid] = await token(email);
  },
  { timeout: 60000 },
);
after(async () => {
  if (db) await db.doc("testClock/control").delete();
  if (env) await env.cleanup();
});
test("rules enforce role, class ownership, private answers and server-only writes", async () => {
  const teacher = env.authenticatedContext("lecturer-0").firestore(),
    student = env.authenticatedContext("student-0").firestore(),
    outsider = env.authenticatedContext("outsider").firestore(),
    anonymous = env.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(teacher, "classes/class-0")));
  await assertFails(getDoc(doc(teacher, "classes/class-2")));
  await assertSucceeds(
    getDoc(doc(student, "attendanceRecords/history-0-0_student-0")),
  );
  await assertFails(
    getDoc(doc(student, "attendanceRecords/history-0-0_student-1")),
  );
  await assertFails(getDoc(doc(student, "quizPrivate/demo-quiz-0")));
  await assertFails(getDoc(doc(teacher, "quizPrivate/demo-quiz-0")));
  await assertFails(
    setDoc(doc(student, "attendanceRecords/forged"), {
      classId: "class-0",
      studentUid: "student-0",
      status: "present",
    }),
  );
  await assertFails(
    setDoc(doc(teacher, "users/lecturer-0"), {
      role: "lecturer",
      active: true,
    }),
  );
  await assertFails(getDoc(doc(outsider, "classes/class-0")));
  await assertFails(getDoc(doc(anonymous, "classes/class-0")));
  await assertSucceeds(
    getDocs(
      query(
        collection(teacher, "classes"),
        where("lecturerUids", "array-contains", "lecturer-0"),
      ),
    ),
  );
  await assertSucceeds(
    getDocs(
      query(
        collection(student, "attendanceRecords"),
        where("classId", "==", "class-0"),
        where("studentUid", "==", "student-0"),
      ),
    ),
  );
  await db.doc("users/disabled").set({ role: "student", active: false });
  await assertFails(
    getDoc(
      doc(env.authenticatedContext("disabled").firestore(), "classes/class-0"),
    ),
  );
});
test("attendance end to end: role, duplicate race, forged/expired/outside class and idempotent finalization", async () => {
  await assert.rejects(
    call("createClassSession", { classId: "class-2", title: "Forbidden" }),
    /PERMISSION_DENIED/,
  );
  const base = await call("createClassSession", {
    classId: "class-0",
    title: "Integration session",
  });
  const sessionId = base.classSessionId;
  await call("openAttendanceSession", {
    classSessionId: sessionId,
    durationMinutes: 10,
    lateAfterMinutes: 5,
  });
  await assert.rejects(
    call("openAttendanceSession", {
      classSessionId: sessionId,
      durationMinutes: 10,
      lateAfterMinutes: 5,
    }),
    /SESSION_CLOSED/,
  );
  const qr = await call("getQrToken", { attendanceSessionId: sessionId });
  await assert.rejects(
    call("getQrToken", { attendanceSessionId: sessionId }, "student-0"),
    /PERMISSION_DENIED/,
  );
  await assert.rejects(
    call("checkInWithQr", { token: qr.token }, "outsider"),
    /NOT_ENROLLED/,
  );
  await assert.rejects(
    call("checkInWithQr", { token: qr.token + "bad" }, "student-0"),
    /QR_INVALID/,
  );
  const old = signQr(
    { sessionId, slotId: 0, sessionVersion: 1, expiresAt: 1 },
    "emulator-only-signing-key",
  );
  await assert.rejects(
    call("checkInWithQr", { token: old }, "student-0"),
    /QR_EXPIRED/,
  );
  const races = await Promise.allSettled([
    call("checkInWithQr", { token: qr.token }, "student-0"),
    call("checkInWithQr", { token: qr.token }, "student-0"),
  ]);
  assert.equal(races.filter((r) => r.status === "fulfilled").length, 1);
  assert.match(
    races.find((r) => r.status === "rejected").reason.message,
    /ALREADY_CHECKED_IN/,
  );
  const results = await call("closeAttendanceSession", {
    attendanceSessionId: sessionId,
  });
  assert.equal(results.status, "finalized");
  await call("closeAttendanceSession", { attendanceSessionId: sessionId });
  const records = await db
    .collection("attendanceRecords")
    .where("attendanceSessionId", "==", sessionId)
    .get();
  assert.equal(records.size, 10);
  assert.equal(
    records.docs.filter((d) => d.data().status === "absent").length,
    9,
  );
  await assert.rejects(
    call("checkInWithQr", { token: qr.token }, "student-0"),
    /SESSION_CLOSED/,
  );
});
test("attendance secret rotation and lecturer corrections enforce authorization and preserve history", async () => {
  const {classSessionId: sessionId} = await call("createClassSession", {classId:"class-0",title:"Secret and corrections"});
  const input = {attendanceSessionId:sessionId};
  await call("openAttendanceSession", {classSessionId:sessionId,durationMinutes:10,lateAfterMinutes:5});
  const old = await call("getQrToken", input);
  await assert.rejects(call("rotateAttendanceQr", {...input,secretEnabled:true}, "student-0"), /PERMISSION_DENIED/);
  await assert.rejects(call("rotateAttendanceQr", {...input,secretEnabled:true}, "lecturer-1"), /PERMISSION_DENIED/);
  await call("rotateAttendanceQr", {...input,secretEnabled:true});
  const qr = await call("getQrToken", input);
  assert.match(qr.secretCode, /^\d{6}$/);
  assert.equal(qr.secretEnabled, true);
  assert.equal(JSON.parse(Buffer.from(qr.token.split('.')[0], 'base64url')).secretRequired, true);
  const student = env.authenticatedContext("student-0").firestore();
  await assertFails(getDoc(doc(student, `attendancePrivate/${sessionId}`)));
  await assert.rejects(call("checkInWithQr", {token:old.token}, "student-0"), /SESSION_CLOSED/);
  await assert.rejects(call("checkInWithQr", {token:qr.token}, "student-0"), /SECRET_REQUIRED/);
  await assert.rejects(call("checkInWithQr", {token:qr.token,secretCode:'wrong'}, "student-0"), /SECRET_INVALID/);
  await call("checkInWithQr", {token:qr.token,secretCode:qr.secretCode}, "student-0");
  const record = db.doc(`attendanceRecords/${sessionId}_student-0`);
  const checkedInAt = (await record.get()).data().checkedInAt.toMillis();
  const correction = {...input, studentUid:"student-0",status:"absent",notes:"Approved leave"};
  await assert.rejects(call("updateAttendanceRecord", correction, "student-0"), /PERMISSION_DENIED/);
  await assert.rejects(call("updateAttendanceRecord", correction, "lecturer-1"), /PERMISSION_DENIED/);
  await assert.rejects(call("updateAttendanceRecord", {...correction,studentUid:"outsider"}), /NOT_ENROLLED/);
  await assert.rejects(call("updateAttendanceRecord", {...correction,notes:""}), /INVALID_INPUT/);
  await call("updateAttendanceRecord", correction);
  assert.equal((await record.get()).data().status,"absent");
  assert.equal((await record.get()).data().checkedInAt.toMillis(),checkedInAt);
  await call("rotateAttendanceQr", {...input,secretEnabled:false});
  assert.equal((await call("getQrToken", input)).secretEnabled,false);
  await call("closeAttendanceSession", input);
  await assert.rejects(call("rotateAttendanceQr", input), /SESSION_CLOSED/);
  await call("updateAttendanceRecord", {...correction,status:"present",notes:"Corrected after close"});
  assert.equal((await record.get()).data().status,"present");
  const audit = await db.collection("attendanceAudit").where("attendanceSessionId","==",sessionId).get();
  assert.equal(audit.size,2);
});

test("private article libraries allow verified owners, protect summaries and deny peer/unverified writes", async () => {
  const own=env.authenticatedContext("library-teacher",{email:"teacher@fpt.edu.vn",email_verified:true}).firestore();
  const peer=env.authenticatedContext("library-other",{email:"other@fpt.edu.vn",email_verified:true}).firestore();
  const unverified=env.authenticatedContext("unverified",{email_verified:false}).firestore();
  const path="articleLibraries/library-teacher/articles/article1";
  const article={title:"Saved article",url:"https://doi.org/10.1/demo",doi:"10.1/demo",source:"Crossref",publisher:"Journal",
    authors:["Author"],subjectIds:["PRM393"],publishedAt:"2026-10-09",sourceSummary:"Source abstract",summary:"Lecturer summary",
    savedAt:serverTimestamp(),updatedAt:serverTimestamp()};
  await assertSucceeds(setDoc(doc(own,path),article));
  await assertSucceeds(getDoc(doc(own,path)));
  await assertFails(getDoc(doc(peer,path)));
  await assertFails(setDoc(doc(peer,path),article));
  await assertFails(setDoc(doc(unverified,"articleLibraries/unverified/articles/1"),article));
  await assertFails(setDoc(doc(own,"articleLibraries/library-teacher/articles/bad"),{...article,role:"lecturer"}));
  await assertSucceeds(updateDoc(doc(own,path),{summary:"Edited summary",updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(own,path),{savedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
  assert.equal((await getDoc(doc(own,path))).data().summary,"Edited summary");
  await assertSucceeds(getDocs(query(collection(own,"articleLibraries/library-teacher/articles"))));
});

test("lecturer imports and timed sessions are atomic, named by subject/slot, binary and freeze membership", async()=>{
  const schedules=[{semester:"FA26",subjectCode:"TEST399",subjectName:"Test subject",classCode:"TEST999",dayOfWeek:1,slot:2,startTime:"10:00",endTime:"12:00",room:"A101"}];
  await assert.rejects(call("importTimetable",{schedules},"student-0"),/PERMISSION_DENIED/);
  await call("importTimetable",{schedules});
  await call("importTimetable",{schedules});
  const found=await db.collection("classes").where("classCode","==","TEST999").get();
  assert.equal(found.size,1);
  const classId=found.docs[0].id;
  const students=[{studentCode:"SE991",fullName:"Imported student",schoolEmail:"",classCode:"TEST999"}];
  assert.equal((await call("importClassStudents",{classId,students})).added,1);
  assert.equal((await call("importClassStudents",{classId,students})).existing,1);
  await assert.rejects(call("importClassStudents",{classId,students},"lecturer-1"),/PERMISSION_DENIED/);
  const session=await call("createAttendanceSession",{classId,title:"Test subject • Slot 2",slot:2,durationMinutes:60,startTime:"10:00",endTime:"12:00"});
  const docSession=db.doc(`attendanceSessions/${session.attendanceSessionId}`), data=(await docSession.get()).data();
  assert.equal(data.slot,2);assert.equal(data.subjectName,"Test subject");assert.equal(data.eligibleStudentUids.length,1);
  assert.equal(data.closesAt.toMillis()-data.opensAt.toMillis(),3600000);
  assert.equal((await call("createAttendanceSession",{classId,title:"Test subject • Slot 2",slot:2,durationMinutes:240,startTime:"10:00",endTime:"12:00"})).attendanceSessionId,session.attendanceSessionId);
  assert.equal((await docSession.get()).data().closesAt.toMillis(),data.closesAt.toMillis());
  await call("importClassStudents",{classId,students:[{...students[0],studentCode:"SE992",fullName:"Later student"}]});
  assert.equal((await docSession.get()).data().eligibleStudentUids.length,1);
  await assert.rejects(call("updateAttendanceRecord",{attendanceSessionId:session.attendanceSessionId,studentUid:data.eligibleStudentUids[0],status:"late",notes:"not supported"}),/INVALID_INPUT/);
});

test("quiz/poll: answers private, membership, double submit, deadline and reveal", async () => {
  const data = {
    classId: "class-0",
    type: "quiz",
    question: "Pick one",
    options: [
      { id: "a", text: "A" },
      { id: "b", text: "B" },
    ],
    correctOptionId: "b",
    durationSeconds: 180,
  };
  await assert.rejects(
    call("createQuiz", { ...data, classId: "class-2" }),
    /PERMISSION_DENIED/,
  );
  const { quizId } = await call("createQuiz", data);
  assert.equal(
    (await db.doc(`quizzes/${quizId}`).get()).data().correctOptionId,
    undefined,
  );
  await call("openQuiz", { quizId });
  await assert.rejects(
    call("submitQuiz", { quizId, selectedOptionId: "b" }, "outsider"),
    /NOT_ENROLLED/,
  );
  const races = await Promise.allSettled([
    call("submitQuiz", { quizId, selectedOptionId: "b" }, "student-0"),
    call("submitQuiz", { quizId, selectedOptionId: "b" }, "student-0"),
  ]);
  assert.equal(races.filter((r) => r.status === "fulfilled").length, 1);
  const student = env.authenticatedContext("student-0").firestore();
  await assertSucceeds(
    getDoc(doc(student, "quizResponses/not-created_student-0")),
  );
  await assertFails(getDoc(doc(student, `quizResults/${quizId}`)));
  await assertFails(getDoc(doc(student, `quizStats/${quizId}`)));
  await call("closeQuiz", { quizId });
  await assertSucceeds(getDoc(doc(student, `quizResults/${quizId}`)));
  const result = (await db.doc(`quizResults/${quizId}`).get()).data();
  assert.equal(result.totalResponses, 1);
  assert.equal(result.correctCount, 1);
  await assert.rejects(
    call("submitQuiz", { quizId, selectedOptionId: "b" }, "student-0"),
    /QUIZ_CLOSED/,
  );
  const poll = await call("createQuiz", {
    ...data,
    type: "poll",
    correctOptionId: undefined,
  });
  await call("openQuiz", { quizId: poll.quizId });
  await db
    .doc(`quizzes/${poll.quizId}`)
    .update({
      closesAt: Timestamp.fromMillis(
        (await db.doc("testClock/control").get()).data().now - 1000,
      ),
    });
  await assert.rejects(
    call(
      "submitQuiz",
      { quizId: poll.quizId, selectedOptionId: "a" },
      "student-0",
    ),
    /QUIZ_CLOSED/,
  );
  await call("closeQuiz", { quizId: poll.quizId });
  assert.equal(
    (await db.doc(`quizResults/${poll.quizId}`).get()).data().correctOptionId,
    undefined,
  );
});
test("share uses class authorization and matching subject; student reads only its classes", async () => {
  await db.doc("articleCache/testarticle").set({
    id: "testarticle",
    title: "Fixture only",
    url: "https://doi.org/10.1/test",
    source: "fixture",
    subjectIds: ["PRM393"],
  });
  await assert.rejects(
    call("shareArticle", { classId: "class-2", articleId: "testarticle" }),
    /PERMISSION_DENIED/,
  );
  await assert.rejects(
    call("shareArticle", { classId: "class-1", articleId: "testarticle" }),
    /PERMISSION_DENIED/,
  );
  const result = await call("shareArticle", {
    classId: "class-0",
    articleId: "testarticle",
    note: "Demo fixture",
  });
  await assertSucceeds(
    getDoc(
      doc(
        env.authenticatedContext("student-0").firestore(),
        `sharedArticles/${result.shareId}`,
      ),
    ),
  );
  await assertFails(
    getDoc(
      doc(
        env.authenticatedContext("outsider").firestore(),
        `sharedArticles/${result.shareId}`,
      ),
    ),
  );
});
