import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp, FieldValue } from "firebase-admin/firestore";
import {
  onCall,
  HttpsError,
  CallableRequest,
} from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { randomBytes, createHash } from "node:crypto";
import { z } from "zod";
import { signQr, verifyQr } from "./domain";
import { AsyncLocalStorage } from "node:async_hooks";
initializeApp();
const db = getFirestore();
const qrSecret = defineSecret("QR_SIGNING_SECRET");
const emulator = process.env.FUNCTIONS_EMULATOR === "true";
const requestClock = new AsyncLocalStorage<number>();
function serverNow(): number {
  return requestClock.getStore() ?? Date.now();
}
const options = {
  region: "asia-southeast1",
  enforceAppCheck: process.env.ENFORCE_APP_CHECK === "true",
  maxInstances: 5,
};
const id = z
  .string()
  .min(1)
  .max(120)
  .regex(/^[a-zA-Z0-9_-]+$/);
function fail(code: string): never {
  throw new HttpsError(
    code === "UNAUTHENTICATED"
      ? "unauthenticated"
      : code === "PERMISSION_DENIED" || code === "NOT_ENROLLED"
        ? "permission-denied"
        : "failed-precondition",
    code,
    { code },
  );
}
async function actor(r: CallableRequest) {
  if (!r.auth) fail("UNAUTHENTICATED");
  const p = (await db.doc(`users/${r.auth.uid}`).get()).data();
  if (!p?.active || !["lecturer", "student"].includes(p.role))
    fail("PERMISSION_DENIED");
  return { uid: r.auth.uid, role: p.role, profile: p };
}
async function classAccess(
  r: CallableRequest,
  classId: string,
  required?: string,
) {
  const a = await actor(r);
  const c = (await db.doc(`classes/${classId}`).get()).data();
  if (!c || (required && a.role !== required)) fail("PERMISSION_DENIED");
  if (a.role === "lecturer") {
    if (!c.lecturerUids.includes(a.uid)) fail("PERMISSION_DENIED");
  } else if (
    !(await db.doc(`classes/${classId}/members/${a.uid}`).get()).data()?.active
  )
    fail("NOT_ENROLLED");
  return { ...a, cls: c };
}
function endpoint(
  schema: z.ZodTypeAny,
  fn: (r: CallableRequest, d: any) => Promise<unknown>,
  secrets: ReturnType<typeof defineSecret>[] = [],
) {
  return onCall({ ...options, secrets }, async (r) => {
    try {
      await actor(r);
      // Trusted, emulator-only deterministic clock. No callable/client can set it.
      const fixed = emulator
        ? (await db.doc("testClock/control").get()).data()?.now
        : undefined;
      if (Number.isFinite(fixed))
        return await requestClock.run(fixed, () => fn(r, schema.parse(r.data)));
      return await fn(r, schema.parse(r.data));
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      if (e instanceof z.ZodError)
        throw new HttpsError("invalid-argument", "INVALID_INPUT");
      throw new HttpsError("internal", "SERVER_ERROR");
    }
  });
}
async function limit(uid: string, action: string) {
  const ref = db.doc(`rateLimits/${uid}_${action}`);
  await db.runTransaction(async (t) => {
    const d = (await t.get(ref)).data();
    const now = serverNow();
    if (d && now - d.start < 60000 && d.count >= 30) fail("RATE_LIMITED");
    t.set(
      ref,
      !d || now - d.start >= 60000
        ? { start: now, count: 1 }
        : { start: d.start, count: d.count + 1 },
    );
  });
}
const ts = (n: number) => Timestamp.fromMillis(n);
const stableId = (value: string) => createHash("sha256").update(value).digest("hex");
export const setClassAttendanceConfig = endpoint(
  z.object({classId:id,totalSlots:z.number().int().min(1).max(1000)}).strict(),
  async(r,d)=>{
    await classAccess(r,d.classId,"lecturer");
    await db.runTransaction(async t=>{
      const cls=await t.get(db.doc(`classes/${d.classId}`));
      if(!cls.data()?.lecturerUids?.includes(r.auth!.uid)) fail("PERMISSION_DENIED");
      const sessions=await t.get(db.collection("attendanceSessions").where("classId","==",d.classId));
      const slots=new Set(sessions.docs.filter(s=>s.data().status==="finalized"&&s.data().attendanceCompleted!==false)
        .map(s=>s.data().classSessionId||s.id));
      if(slots.size>d.totalSlots) fail("TOTAL_SLOTS_BELOW_COMPLETED");
      t.update(cls.ref,{totalSlots:d.totalSlots,attendanceConfigUpdatedBy:r.auth!.uid,attendanceConfigUpdatedAt:ts(serverNow())});
    });
    return {saved:true,totalSlots:d.totalSlots};
  },
);
export const createAttendanceSession = endpoint(
  z.object({classId:id,title:z.string().trim().min(1).max(300),slot:z.number().int().min(1).max(12),
    durationMinutes:z.number().int().min(1).max(240),
    startTime:z.string().regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/),endTime:z.string().regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/)}),
  async(r,d)=>{
    const a=await classAccess(r,d.classId,"lecturer");
    if(d.startTime>=d.endTime) fail("INVALID_INPUT");
    const now=serverNow(), date=new Date(now+7*3600000).toISOString().slice(0,10);
    const sessionId=stableId(`${d.classId}|${date}|${d.slot}`);
    const lesson=db.doc(`classSessions/${sessionId}`), session=db.doc(`attendanceSessions/${sessionId}`);
    await db.runTransaction(async t=>{
      const [existing,members]=await Promise.all([t.get(session),t.get(db.collection(`classes/${d.classId}/members`).where("active","==",true))]);
      if(existing.exists) return;
      if(members.size>400) fail("CLASS_TOO_LARGE");
      const detail={classId:d.classId,subjectId:a.cls.subjectId,subjectName:a.cls.subjectName || a.cls.subjectId,
        classCode:a.cls.classCode,slot:d.slot};
      const startsAt=Date.parse(`${date}T${d.startTime}:00+07:00`),endsAt=Date.parse(`${date}T${d.endTime}:00+07:00`);
      t.create(lesson,{...detail,title:d.title,lecturerUid:a.uid,startsAt:ts(startsAt),endsAt:ts(endsAt),status:"scheduled",createdAt:ts(now)});
      t.create(session,{...detail,classSessionId:sessionId,createdBy:a.uid,status:"open",opensAt:ts(now),closesAt:ts(now+d.durationMinutes*60000),
        sessionVersion:1,qrRotationSeconds:120,eligibleStudentUids:members.docs.map(m=>m.id)});
    });
    return {attendanceSessionId:sessionId,classSessionId:sessionId};
  },
);

const scheduleInput=z.object({semester:z.string().trim().min(1).max(100),subjectCode:z.string().trim().min(1).max(100),
  subjectName:z.string().trim().max(200).default(""),classCode:z.string().trim().min(1).max(100),
  dayOfWeek:z.number().int().min(1).max(7),slot:z.number().int().min(1).max(12),
  startTime:z.string().regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/),endTime:z.string().regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/),room:z.string().trim().max(100).default("")});
export const importTimetable=endpoint(z.object({schedules:z.array(scheduleInput).min(1).max(100)}),async(r,d)=>{
  const a=await actor(r);if(a.role!=="lecturer")fail("PERMISSION_DENIED");
  const existing=await db.collection("classes").where("lecturerUids","array-contains",a.uid).get();
  const rows=d.schedules.map((raw:any)=>({...raw,semester:raw.semester.toUpperCase(),subjectCode:raw.subjectCode.toUpperCase(),classCode:raw.classCode.toUpperCase()}));
  const plans=new Map<string,any>(),seen=new Set<string>();
  for(const row of rows){
    if(row.startTime>=row.endTime)fail("INVALID_INPUT");
    const key=`${row.semester}|${row.subjectCode}|${row.classCode}`;
    const matches=existing.docs.filter(c=>c.data().term===row.semester&&c.data().subjectId===row.subjectCode&&c.data().classCode===row.classCode);
    if(matches.length>1)fail("INVALID_INPUT");
    const classId=matches[0]?.id || stableId(`${a.uid}|${key}`);
    const scheduleId=stableId(`${a.uid}|${classId}|${row.dayOfWeek}|${row.slot}`);
    if(seen.has(scheduleId))fail("INVALID_INPUT");seen.add(scheduleId);
    plans.set(classId,{row,ref:db.doc(`classes/${classId}`)});
    row.classId=classId;row.scheduleId=scheduleId;
  }
  await db.runTransaction(async t=>{
    const refs=[...plans.values()].map(p=>p.ref);
    const classes=await t.getAll(...refs);
    classes.forEach((c:any,i:number)=>{
      const plan=[...plans.values()][i],row=plan.row;
      if(c.exists&&!c.data()!.lecturerUids.includes(a.uid))fail("PERMISSION_DENIED");
      if(!c.exists)t.create(plan.ref,{term:row.semester,subjectId:row.subjectCode,subjectName:row.subjectName||row.subjectCode,
        classCode:row.classCode,lecturerUids:[a.uid],studentUids:[],studentCount:0});
    });
    for(const row of rows){
      t.set(db.doc(`schedules/${row.scheduleId}`),{classId:row.classId,lecturerUid:a.uid,term:row.semester,subjectId:row.subjectCode,
        subjectName:row.subjectName||row.subjectCode,classCode:row.classCode,dayOfWeek:row.dayOfWeek,slot:row.slot,
        startTime:row.startTime,endTime:row.endTime,room:row.room});
    }
    const subjects=[...new Set<string>(rows.map((v:any)=>v.subjectCode))];
    for(const subject of subjects)t.set(db.doc(`subjects/${subject}`),{name:rows.find((v:any)=>v.subjectCode===subject).subjectName||subject},{merge:true});
    t.update(db.doc(`users/${a.uid}`),{subjectIds:FieldValue.arrayUnion(...subjects)});
  });
  return {saved:rows.length};
});
export const importClassStudents=endpoint(z.object({classId:id,students:z.array(z.object({studentCode:z.string().trim().regex(/^[A-Za-z0-9][A-Za-z0-9._-]{1,39}$/),
  fullName:z.string().trim().min(1).max(200),schoolEmail:z.union([z.string().trim().email().max(254),z.literal("")]).default(""),
  classCode:z.string().trim().optional()})).min(1).max(400)}),async(r,d)=>{
  const a=await classAccess(r,d.classId,"lecturer"),seen=new Set<string>();
  const students=d.students.map((s:any)=>({...s,studentCode:s.studentCode.toUpperCase(),schoolEmail:s.schoolEmail.toLowerCase()}));
  for(const s of students){if(seen.has(s.studentCode)||(s.classCode&&s.classCode.toUpperCase()!==a.cls.classCode.toUpperCase()))fail("INVALID_INPUT");seen.add(s.studentCode);}
  return db.runTransaction(async t=>{
    const roster=await t.get(db.collection(`classes/${d.classId}/members`).where("active","==",true));
    const refs=students.map((s:any)=>db.doc(`classes/${d.classId}/members/student-${stableId(s.studentCode).slice(0,24)}`));
    const old=await t.getAll(...refs);
    const existingByCode=new Map(roster.docs.map(m=>[m.data().studentCode,m]));
    let added=0,existing=0;const newUids:string[]=[];
    students.forEach((s:any,i:number)=>{
      const previous:any=existingByCode.get(s.studentCode)?.data() || old[i].data();
      if(previous&&previous.displayName.trim().toLowerCase().replace(/\s+/g,' ')!==s.fullName.toLowerCase().replace(/\s+/g,' '))fail("INVALID_INPUT");
      if(previous?.active){existing++;return;}
      added++;newUids.push(refs[i].id);
      t.set(refs[i],{studentCode:s.studentCode,displayName:s.fullName,schoolEmail:s.schoolEmail,active:true,enrolledAt:ts(serverNow())});
    });
    if(roster.size+added>400)fail("CLASS_TOO_LARGE");
    if(added)t.update(db.doc(`classes/${d.classId}`),{studentUids:FieldValue.arrayUnion(...newUids),studentCount:roster.size+added});
    return {added,existing};
  });
});
export const createClassSession = endpoint(
  z.object({ classId: id, title: z.string().trim().min(1).max(150) }),
  async (r, d) => {
    const a = await classAccess(r, d.classId, "lecturer");
    const ref = db.collection("classSessions").doc();
    const now = serverNow();
    await ref.create({
      ...d,
      subjectId: a.cls.subjectId,
      lecturerUid: a.uid,
      startsAt: ts(now),
      endsAt: ts(now + 90 * 60000),
      status: "scheduled",
      createdAt: ts(now),
    });
    return { classSessionId: ref.id };
  },
);
export const openAttendanceSession = endpoint(
  z.object({
    classSessionId: id,
    durationMinutes: z.number().int().min(1).max(240),
    lateAfterMinutes: z.number().int().min(0).max(240).optional(),
  }),
  async (r, d) => {
    const base = (
      await db.doc(`classSessions/${d.classSessionId}`).get()
    ).data();
    if (!base) fail("SESSION_CLOSED");
    const a = await classAccess(r, base.classId, "lecturer");
    // One deterministic attendance session per teaching session prevents double opens.
    const ref = db.doc(`attendanceSessions/${d.classSessionId}`);
    await db.runTransaction(async (t) => {
      const [previous, members, lesson] = await Promise.all([
        t.get(ref),
        t.get(
          db
            .collection(`classes/${base.classId}/members`)
            .where("active", "==", true),
        ),
        t.get(db.doc(`classSessions/${d.classSessionId}`)),
      ]);
      if (previous.exists || lesson.data()?.status !== "scheduled")
        fail("SESSION_CLOSED");
      const now = serverNow();
      t.create(ref, {
        classSessionId: d.classSessionId,
        classId: base.classId,
        createdBy: a.uid,
        status: "open",
        opensAt: ts(now),
        closesAt: ts(now + d.durationMinutes * 60000),
        subjectId: base.subjectId,
        subjectName: a.cls.subjectName || base.subjectId,
        classCode: a.cls.classCode,
        slot: base.slot || 1,
        sessionVersion: 1,
        qrRotationSeconds: 120,
        eligibleStudentUids: members.docs
          .filter((m) => m.data().enrolledAt.toMillis() <= now)
          .map((m) => m.id),
      });
    });
    return { attendanceSessionId: ref.id };
  },
);
export const getQrToken = endpoint(
  z.object({ attendanceSessionId: id }),
  async (r, d) => {
    const s = (
      await db.doc(`attendanceSessions/${d.attendanceSessionId}`).get()
    ).data();
    if (!s) fail("SESSION_CLOSED");
    await classAccess(r, s.classId, "lecturer");
    const now = serverNow();
    if (s.status !== "open" || now >= s.closesAt.toMillis())
      fail("SESSION_CLOSED");
    const slot = Math.floor(now / 120000);
    const expiresAt = Math.min((slot + 1) * 120000, s.closesAt.toMillis());
    const secret = (await db.doc(`attendancePrivate/${d.attendanceSessionId}`).get()).data()?.secretCode || "";
    return {
      token: signQr(
        {
          sessionId: d.attendanceSessionId,
          slotId: slot,
          sessionVersion: s.sessionVersion,
          expiresAt,
          secretRequired: !!secret,
        },
        emulator ? "emulator-only-signing-key" : qrSecret.value(),
      ),
      expiresAt,
      serverNow: now,
      rotationSeconds: 120,
      secretEnabled: !!secret,
      secretCode: secret,
    };
  },
  [qrSecret],
);
export const checkInWithQr = endpoint(
  z.object({ token: z.string().min(1).max(2000), secretCode: z.string().trim().max(30).optional() }),
  async (r, d) => {
    const a = await actor(r);
    if (a.role !== "student") fail("PERMISSION_DENIED");
    await limit(a.uid, "checkin");
    let p;
    try {
      p = verifyQr(
        d.token,
        emulator ? "emulator-only-signing-key" : qrSecret.value(),
        serverNow(),
      );
    } catch (e) {
      fail((e as Error).message);
    }
    const sref = db.doc(`attendanceSessions/${p.sessionId}`);
    const initial = (await sref.get()).data();
    if (!initial) fail("SESSION_CLOSED");
    await classAccess(r, initial.classId, "student");
    return db.runTransaction(async (t) => {
      const record = db.doc(`attendanceRecords/${p.sessionId}_${a.uid}`);
      const [ss, rr, member, privateSession] = await Promise.all([
        t.get(sref),
        t.get(record),
        t.get(db.doc(`classes/${initial.classId}/members/${a.uid}`)),
        t.get(db.doc(`attendancePrivate/${p.sessionId}`)),
      ]);
      const s = ss.data()!;
      const now = serverNow();
      try {
        verifyQr(
          d.token,
          emulator ? "emulator-only-signing-key" : qrSecret.value(),
          now,
        );
      } catch (e) {
        fail((e as Error).message);
      }
      if (!member.data()?.active || !s.eligibleStudentUids.includes(a.uid))
        fail("NOT_ENROLLED");
      if (
        s.status !== "open" ||
        now >= s.closesAt.toMillis() ||
        s.sessionVersion !== p.sessionVersion
      )
        fail("SESSION_CLOSED");
      if (rr.exists) fail("ALREADY_CHECKED_IN");
      const secret = privateSession.data()?.secretCode;
      if (secret && !d.secretCode) fail("SECRET_REQUIRED");
      if (secret && d.secretCode !== secret) fail("SECRET_INVALID");
      const status = "present";
      t.create(record, {
        attendanceSessionId: p.sessionId,
        classSessionId: s.classSessionId,
        classId: s.classId,
        subjectId: s.subjectId || initial.subjectId || "",
        subjectName: s.subjectName || "",
        slot: s.slot || 1,
        studentUid: a.uid,
        status,
        checkedInAt: ts(now),
        recordedAt: ts(now),
        recordedBy: "qr",
      });
      return { attendanceSessionId: p.sessionId, status, checkedInAt: now };
    });
  },
  [qrSecret],
);
async function finalize(sessionId: string) {
  const ref = db.doc(`attendanceSessions/${sessionId}`);
  await db.runTransaction(async (t) => {
    const s = (await t.get(ref)).data();
    if (!s || s.status === "cancelled" || s.status === "finalized") return;
    // Atomic finalization capped for a Lab-sized class; never silently truncate.
    if (s.eligibleStudentUids.length > 400)
      throw new HttpsError("resource-exhausted", "CLASS_TOO_LARGE");
    const refs = s.eligibleStudentUids.map((uid: string) =>
      db.doc(`attendanceRecords/${sessionId}_${uid}`),
    );
    const records = refs.length ? await t.getAll(...refs) : [];
    const now = serverNow();
    records.forEach((rec, i) => {
      if (!rec.exists)
        t.create(refs[i], {
          attendanceSessionId: sessionId,
          classSessionId: s.classSessionId,
          classId: s.classId,
          subjectId: s.subjectId || "",
          subjectName: s.subjectName || "",
          slot: s.slot || 1,
          studentUid: s.eligibleStudentUids[i],
          status: "absent",
          recordedAt: ts(now),
          recordedBy: "system",
        });
    });
    t.update(ref, {
      status: "finalized",
      finalizedAt: ts(now),
      sessionVersion: s.sessionVersion + 1,
    });
    t.update(db.doc(`classSessions/${s.classSessionId}`), {
      status: "completed",
    });
  });
  return { status: "finalized" };
}
export const closeAttendanceSession = endpoint(
  z.object({ attendanceSessionId: id }),
  async (r, d) => {
    const s = (
      await db.doc(`attendanceSessions/${d.attendanceSessionId}`).get()
    ).data();
    if (!s) fail("SESSION_CLOSED");
    await classAccess(r, s.classId, "lecturer");
    return finalize(d.attendanceSessionId);
  },
);
export const rotateAttendanceQr = endpoint(
  z.object({ attendanceSessionId: id, secretEnabled: z.boolean().optional() }),
  async (r, d) => {
    const ref = db.doc(`attendanceSessions/${d.attendanceSessionId}`);
    const initial = (await ref.get()).data();
    if (!initial) fail("SESSION_CLOSED");
    await classAccess(r, initial.classId, "lecturer");
    await db.runTransaction(async (t) => {
      const privateRef = db.doc(`attendancePrivate/${d.attendanceSessionId}`);
      const [ss, ps] = await Promise.all([t.get(ref), t.get(privateRef)]);
      const s = ss.data()!;
      if (s.status !== "open" || serverNow() >= s.closesAt.toMillis()) fail("SESSION_CLOSED");
      const old = ps.data()?.secretCode || "";
      const secretCode = d.secretEnabled === undefined ? old : d.secretEnabled
        ? (randomBytes(4).readUInt32BE() % 1000000).toString().padStart(6, "0") : "";
      t.set(privateRef, {secretCode});
      t.update(ref, {sessionVersion: s.sessionVersion + 1});
    });
    return {updated: true};
  },
);
export const updateAttendanceRecord = endpoint(
  z.object({attendanceSessionId: id, studentUid: id,
    status: z.enum(["present", "absent"]), notes: z.string().trim().min(1).max(500)}),
  async (r, d) => {
    const sessionRef = db.doc(`attendanceSessions/${d.attendanceSessionId}`);
    const initial = (await sessionRef.get()).data();
    if (!initial) fail("SESSION_CLOSED");
    const a = await classAccess(r, initial.classId, "lecturer");
    await db.runTransaction(async (t) => {
      const recordRef = db.doc(`attendanceRecords/${d.attendanceSessionId}_${d.studentUid}`);
      const [ss, rr] = await Promise.all([t.get(sessionRef), t.get(recordRef)]);
      const s = ss.data()!;
      if (!["open", "finalized"].includes(s.status)) fail("SESSION_CLOSED");
      if (!s.eligibleStudentUids.includes(d.studentUid) && !rr.exists) fail("NOT_ENROLLED");
      const now = serverNow();
      t.set(recordRef, {attendanceSessionId:d.attendanceSessionId, classSessionId:s.classSessionId,
        classId:s.classId, subjectId:s.subjectId || "", subjectName:s.subjectName || "",slot:s.slot || 1,
        studentUid:d.studentUid, status:d.status, notes:d.notes,
        recordedAt:ts(now), recordedBy:a.uid}, {merge:true});
      t.create(db.collection("attendanceAudit").doc(), {classId:s.classId, attendanceSessionId:d.attendanceSessionId,
        studentUid:d.studentUid, previousStatus:rr.data()?.status || null, status:d.status,
        notes:d.notes, updatedBy:a.uid, updatedAt:ts(now)});
    });
    return {updated:true};
  },
);
export const createQuiz = endpoint(
  z.object({
    classId: id,
    type: z.enum(["quiz", "poll"]),
    question: z.string().trim().min(1).max(500),
    options: z
      .array(z.object({ id: id, text: z.string().trim().min(1).max(200) }))
      .min(2)
      .max(5),
    correctOptionId: id.optional(),
    durationSeconds: z.number().int().min(60).max(900),
  }),
  async (r, d) => {
    const a = await classAccess(r, d.classId, "lecturer");
    if (
      new Set(d.options.map((o: any) => o.id)).size !== d.options.length ||
      (d.type === "quiz" &&
        !d.options.some((o: any) => o.id === d.correctOptionId)) ||
      (d.type === "poll" && d.correctOptionId)
    )
      throw new HttpsError("invalid-argument", "INVALID_INPUT");
    const ref = db.collection("quizzes").doc();
    const { correctOptionId, ...publicData } = d;
    const batch = db.batch();
    batch.create(ref, {
      ...publicData,
      subjectId: a.cls.subjectId,
      createdBy: a.uid,
      status: "scheduled",
      joinCode: randomBytes(4).toString("hex").toUpperCase(),
      createdAt: ts(serverNow()),
    });
    batch.create(
      db.doc(`quizPrivate/${ref.id}`),
      correctOptionId ? { correctOptionId } : {},
    );
    batch.create(db.doc(`quizStats/${ref.id}`), {
      classId: d.classId,
      totalResponses: 0,
      optionCounts: Object.fromEntries(d.options.map((o: any) => [o.id, 0])),
    });
    await batch.commit();
    return { quizId: ref.id };
  },
);
export const openQuiz = endpoint(z.object({ quizId: id }), async (r, d) => {
  const ref = db.doc(`quizzes/${d.quizId}`);
  const q = (await ref.get()).data();
  if (!q) fail("QUIZ_CLOSED");
  await classAccess(r, q.classId, "lecturer");
  return db.runTransaction(async (t) => {
    const quiz = (await t.get(ref)).data()!;
    if (quiz.status !== "scheduled") fail("QUIZ_CLOSED");
    const now = serverNow();
    t.update(ref, {
      status: "open",
      opensAt: ts(now),
      closesAt: ts(now + quiz.durationSeconds * 1000),
    });
    return { status: "open" };
  });
});
export const submitQuiz = endpoint(
  z.object({ quizId: id, selectedOptionId: id }),
  async (r, d) => {
    const qref = db.doc(`quizzes/${d.quizId}`);
    const q = (await qref.get()).data();
    if (!q) fail("QUIZ_CLOSED");
    const a = await classAccess(r, q.classId, "student");
    await limit(a.uid, "quiz");
    return db.runTransaction(async (t) => {
      const ref = db.doc(`quizResponses/${d.quizId}_${a.uid}`);
      const stats = db.doc(`quizStats/${d.quizId}`);
      const [qs, rs, ss, ms] = await Promise.all([
        t.get(qref),
        t.get(ref),
        t.get(stats),
        t.get(db.doc(`classes/${q.classId}/members/${a.uid}`)),
      ]);
      const current = qs.data()!;
      const now = serverNow();
      if (!ms.data()?.active) fail("NOT_ENROLLED");
      if (current.status !== "open" || now >= current.closesAt.toMillis())
        fail("QUIZ_CLOSED");
      if (rs.exists) fail("ALREADY_SUBMITTED");
      if (!current.options.some((o: any) => o.id === d.selectedOptionId))
        throw new HttpsError("invalid-argument", "INVALID_INPUT");
      t.create(ref, {
        quizId: d.quizId,
        classId: q.classId,
        studentUid: a.uid,
        selectedOptionId: d.selectedOptionId,
        submittedAt: ts(now),
      });
      const counts = { ...ss.data()!.optionCounts };
      counts[d.selectedOptionId]++;
      t.update(stats, {
        totalResponses: ss.data()!.totalResponses + 1,
        optionCounts: counts,
        updatedAt: ts(now),
      });
      return { accepted: true, submittedAt: now };
    });
  },
);
async function publishQuiz(quizId: string) {
  const ref = db.doc(`quizzes/${quizId}`);
  return db.runTransaction(async (t) => {
    const [qs, ps, ss] = await Promise.all([
      t.get(ref),
      t.get(db.doc(`quizPrivate/${quizId}`)),
      t.get(db.doc(`quizStats/${quizId}`)),
    ]);
    const q = qs.data()!;
    if (q.status === "published") return { status: "published" };
    if (q.status !== "open") fail("QUIZ_CLOSED");
    const privateData = ps.data()!;
    const stats = ss.data()!;
    t.set(db.doc(`quizResults/${quizId}`), {
      ...stats,
      ...privateData,
      correctCount:
        q.type === "quiz"
          ? stats.optionCounts[privateData.correctOptionId] || 0
          : null,
    });
    t.update(ref, { status: "published", closedAt: ts(serverNow()) });
    return { status: "published" };
  });
}
export const closeQuiz = endpoint(z.object({ quizId: id }), async (r, d) => {
  const q = (await db.doc(`quizzes/${d.quizId}`).get()).data();
  if (!q) fail("QUIZ_CLOSED");
  await classAccess(r, q.classId, "lecturer");
  return publishQuiz(d.quizId);
});
export const expireActivities = onSchedule(
  { ...options, schedule: "every 1 minutes" },
  async () => {
    const now = Timestamp.now();
    const attendance = await db
      .collection("attendanceSessions")
      .where("status", "==", "open")
      .get();
    for (const s of attendance.docs)
      if (s.data().closesAt.toMillis() <= now.toMillis()) await finalize(s.id);
    const quizzes = await db
      .collection("quizzes")
      .where("status", "==", "open")
      .get();
    for (const q of quizzes.docs)
      if (q.data().closesAt.toMillis() <= now.toMillis())
        await publishQuiz(q.id);
  },
);
export const shareArticle = endpoint(
  z.object({
    classId: id,
    articleId: id,
    note: z.string().max(500).default(""),
  }),
  async (r, d) => {
    const a = await classAccess(r, d.classId, "lecturer");
    const article = (await db.doc(`articleCache/${d.articleId}`).get()).data();
    if (!article) throw new HttpsError("not-found", "ARTICLE_NOT_FOUND");
    if (!article.subjectIds?.includes(a.cls.subjectId))
      fail("PERMISSION_DENIED");
    const ref = db.doc(`sharedArticles/${d.classId}_${d.articleId}`);
    await ref.set({
      ...d,
      subjectId: a.cls.subjectId,
      sharedBy: a.uid,
      sharedAt: Timestamp.now(),
      article,
    });
    return { shareId: ref.id };
  },
);
export { discoverArticles } from "./news";
