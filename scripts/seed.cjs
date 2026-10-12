// This script refuses production; use a reviewed operator process for real users.
const localRequire = require("node:module").createRequire(
  require("node:path").resolve(__dirname, "../functions/package.json"),
);
const { initializeApp } = localRequire("firebase-admin/app");
const { getAuth } = localRequire("firebase-admin/auth");
const { getFirestore, Timestamp } = localRequire("firebase-admin/firestore");
if (
  !process.env.FIRESTORE_EMULATOR_HOST ||
  !process.env.FIREBASE_AUTH_EMULATOR_HOST
)
  throw Error("Emulators required");
initializeApp({ projectId: "demo-fap-lab2" });
const db = getFirestore(),
  auth = getAuth();
const password = process.env.DEMO_PASSWORD || "EmulatorOnly123!";
const time = (n) => Timestamp.fromMillis(n);
(async () => {
  const subjects = [
    [
      "PRM393",
      "Lập trình di động",
      ["Flutter", "Dart", "Mobile application development"],
    ],
    ["PRN212", "Phát triển .NET", ["ASP.NET Core", "Entity Framework", ".NET"]],
    [
      "SWE201c",
      "Kỹ thuật phần mềm",
      ["Software architecture", "Agile", "Software testing"],
    ],
  ];
  for (const [code, name, keywords] of subjects)
    await db
      .doc(`subjects/${code}`)
      .set({ code, name, keywords, active: true });
  for (let i = 0; i < 13; i++) {
    const lecturer = i < 2,
      uid = lecturer
        ? `lecturer-${i}`
        : i === 12
          ? "outsider"
          : `student-${i - 2}`;
    const email = lecturer
      ? `lecturer.${i === 0 ? "a" : "b"}@example.test`
      : i === 12
        ? "outsider@example.test"
        : `student.${i - 2}@example.test`;
    try {
      await auth.createUser({
        uid,
        email,
        password,
        displayName: lecturer
          ? `Giảng viên ${i === 0 ? "A" : "B"}`
          : `Sinh viên ${i - 2}`,
      });
    } catch (e) {
      if (
        e.code !== "auth/uid-already-exists" &&
        e.code !== "auth/email-already-exists"
      )
        throw e;
    }
    await db
      .doc(`users/${uid}`)
      .set({
        uid,
        email,
        displayName: lecturer
          ? `Giảng viên ${i === 0 ? "A" : "B"}`
          : `Sinh viên ${i - 2}`,
        role: lecturer ? "lecturer" : "student",
        active: true,
        subjectIds: i === 12 ? [] : subjects.map((s) => s[0]),
        studentCode: lecturer ? "" : `SE${String(i - 2).padStart(6, "0")}`,
      });
  }
  const students = Array.from({ length: 10 }, (_, i) => `student-${i}`);
  for (let c = 0; c < 3; c++) {
    const classId = `class-${c}`,
      subjectId = subjects[c][0],
      now = Date.now();
    await db
      .doc(`classes/${classId}`)
      .set({
        classCode: `SE${1928 + c}`,
        subjectId,
        term: "Fall 2026",
        lecturerUids: [c === 2 ? "lecturer-1" : "lecturer-0"],
        studentUids: students,
        studentCount: 10,
        status: "active",
      });
    await db.doc(`schedules/demo-schedule-${c}`).set({
      lecturerUid: c === 2 ? "lecturer-1" : "lecturer-0",
      classId, classCode: `SE${1928 + c}`, subjectId,
      term: "Fall 2026", dayOfWeek: c + 2, slot: c + 1,
      startTime: c === 0 ? "07:30" : c === 1 ? "10:00" : "12:50",
      endTime: c === 0 ? "09:50" : c === 1 ? "12:20" : "15:10",
      room: `Demo ${201 + c}`,
    });
    for (let i = 0; i < 10; i++)
      await db
        .doc(`classes/${classId}/members/student-${i}`)
        .set({
          studentUid: `student-${i}`,
          studentCode: `SE${String(i).padStart(6, "0")}`,
          displayName: `Sinh viên ${i}`,
          active: true,
          enrolledAt: time(now - 60 * 86400000),
        });
    for (let j = 0; j < 5; j++) {
      const sessionId = `history-${c}-${j}`,
        starts = now - (j + 1) * 86400000;
      await db
        .doc(`classSessions/${sessionId}`)
        .set({
          classId,
          subjectId,
          lecturerUid: c === 2 ? "lecturer-1" : "lecturer-0",
          title: `Buổi ${5 - j}`,
          startsAt: time(starts),
          endsAt: time(starts + 5400000),
          status: "completed",
        });
      await db
        .doc(`attendanceSessions/${sessionId}`)
        .set({
          classId,
          classSessionId: sessionId,
          status: "finalized",
          eligibleStudentUids: students,
          opensAt: time(starts),
          closesAt: time(starts + 600000),
          finalizedAt: time(starts + 600000),
          sessionVersion: 2,
        });
      for (let i = 0; i < 10; i++)
        await db
          .doc(`attendanceRecords/${sessionId}_student-${i}`)
          .set({
            classId,
            classSessionId: sessionId,
            attendanceSessionId: sessionId,
            studentUid: `student-${i}`,
            status: ["present", "late", "absent", "excused"][(i + j) % 4],
            recordedAt: time(starts),
            recordedBy: "system",
          });
    }
    const qid = `demo-quiz-${c}`,
      type = c === 2 ? "poll" : "quiz";
    await db.doc(`quizzes/${qid}`).set({
      classId,
      subjectId,
      type,
      question:
        type === "poll"
          ? "Bạn muốn ôn tập nội dung nào?"
          : "Thành phần nào quản lý trạng thái?",
      options: [
        { id: "a", text: "Widget" },
        { id: "b", text: "State" },
      ],
      status: "scheduled",
      durationSeconds: 180,
      createdBy: c === 2 ? "lecturer-1" : "lecturer-0",
      createdAt: time(now),
    });
    await db
      .doc(`quizPrivate/${qid}`)
      .set(type === "quiz" ? { correctOptionId: "b" } : {});
    await db
      .doc(`quizStats/${qid}`)
      .set({ classId, totalResponses: 0, optionCounts: { a: 0, b: 0 } });
  }
  // Fixture metadata is clearly labelled and never injected into the real API feed.
  const fixtures = [
    [
      "PRM393",
      "Flutter theme documentation",
      "https://docs.flutter.dev/cookbook/design/themes",
    ],
    [
      "PRN212",
      "Firebase authentication documentation",
      "https://firebase.google.com/docs/auth/flutter/start",
    ],
    [
      "SWE201c",
      "Firestore transactions documentation",
      "https://firebase.google.com/docs/firestore/manage-data/transactions",
    ],
  ];
  for (let i = 0; i < fixtures.length; i++) {
    const [subjectId, title, url] = fixtures[i];
    const article = {
      id: `demo-article-${i}`,
      title: `[DEMO FIXTURE] ${title}`,
      url,
      source: "Demo fixture",
      publisher: "Official documentation (fixture)",
      authors: [],
      publishedAt: null,
      abstractSnippet: null,
      subjectIds: [subjectId],
      fetchedAt: Date.now(),
      expiresAt: Date.now() + 21600000,
    };
    await db.doc(`articleCache/${article.id}`).set(article);
    await db
      .doc(`sharedArticles/class-${i}_${article.id}`)
      .set({
        classId: `class-${i}`,
        subjectId,
        articleId: article.id,
        article,
        note: "Dữ liệu mẫu minh họa tài liệu lớp, không phải bài báo tìm từ API.",
        sharedBy: i === 2 ? "lecturer-1" : "lecturer-0",
        sharedAt: time(Date.now()),
      });
  }
  const opens = Date.now();
  await db
    .doc("classSessions/demo-open-0")
    .set({
      classId: "class-0",
      subjectId: "PRM393",
      title: "[DEMO FIXTURE] Phiên đang mở",
      startsAt: time(opens),
      endsAt: time(opens + 5400000),
      status: "scheduled",
      lecturerUid: "lecturer-0",
    });
  await db
    .doc("attendanceSessions/demo-open-0")
    .set({
      classId: "class-0",
      classSessionId: "demo-open-0",
      createdBy: "lecturer-0",
      status: "open",
      opensAt: time(opens),
      closesAt: time(opens + 1800000),
      lateThresholdAt: time(opens + 300000),
      qrRotationSeconds: 120,
      sessionVersion: 1,
      eligibleStudentUids: students,
    });
  console.log(
    "Synthetic emulator dataset ready. Lecturer A/B, student.0–9, outsider. Password: DEMO_PASSWORD or documented emulator-only default.",
  );
})().catch((e) => {
  console.error(e.message);
  process.exitCode = 1;
});
