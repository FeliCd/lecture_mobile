// Run from the project root: node output/prm/Demo_PRM_Fixture.cjs
// Each run creates a fresh in-memory workbook and a controlled clock.
const assert = require('node:assert/strict');
const { fixture } = require('../../backend/test/portal-fixture.cjs');

const date = '2026-11-09';
const { c, book, teacher, student, add, setNow } = fixture(date + 'T01:00:00Z');
const studentB = c.lab2Actor_(
  { email: 'other-student@fpt.edu.vn', firebaseUid: 'fixture-student-b' },
  c.config_(),
  book,
);
const portal = (actor, method, data = {}) => c.portalCall_(book, actor, method, data);
const mobile = (method, data) => c.lab2Mutate_(book, teacher, method, data);
const rows = table => c.lab2Read_(book, table);
const proof = { environment: 'local Apps Script source + in-memory Sheets + fixture identity', classId: 'c1', date, slot: 1 };

add('Schedules', {
  scheduleId: 'prm-demo', lecturerId: 'l1', semester: '', subjectCode: 'PRM393',
  classCode: 'SE1', dayOfWeek: 1, slot: 1, startTime: '09:00', endTime: '10:30',
});

const [occurrence] = portal(student, 'listOccurrences', { classId: 'c1', date });
const leaveInput = {
  classId: 'c1', sessionDate: date, occurrenceId: occurrence.occurrenceId,
  reason: 'Có lịch hẹn khám bệnh', requestKey: 'prm-demo-leave-0001',
};
const leave = portal(student, 'submitLeaveRequest', leaveInput);
assert.equal(leave.status, 'PENDING');
assert.throws(() => portal(student, 'submitLeaveRequest', {
  ...leaveInput, requestKey: 'prm-demo-leave-0002',
}), /LEAVE_DUPLICATE/);
assert.equal(rows('PortalLeaveRequests').length, 1);
const approved = portal(teacher, 'reviewLeaveRequest', {
  classId: 'c1', id: leave.id, version: leave.version, status: 'APPROVED',
});
assert.equal(approved.status, 'APPROVED');
assert.equal(portal(student, 'listMyLeaveRequests')[0].status, 'APPROVED');
assert.throws(() => portal(student, 'cancelLeaveRequest', {
  id: leave.id, version: approved.version,
}), /LEAVE_TOO_LATE/);
proof.WF01 = { leaveId: leave.id, states: [leave.status, approved.status], rejected: ['LEAVE_DUPLICATE', 'LEAVE_TOO_LATE'] };

setNow(date + 'T02:00:00Z');
const open = mobile('createClassSession', { classId: 'c1', sessionDate: date, slot: '1', durationMinutes: 10 });
assert.equal(open.status, 'OPEN');
const sessionId = open.sessionId;
const qr = new URL(mobile('getQrToken', { attendanceSessionId: sessionId }).token);
// Substitute the result of Google verification. All session and roster checks still run.
c.authenticateStudent_ = () => studentB.entity;
const checkIn = () => c.handleStudentCheckIn_({
  confirmPresent: true, sessionId, token: qr.searchParams.get('token'),
});
assert.equal(checkIn().status, 'PRESENT');
assert.equal(checkIn().alreadyRecorded, true);
mobile('closeAttendanceSession', { attendanceSessionId: sessionId });
const closed = rows('Sessions').find(row => row.sessionId === sessionId);
const attendance = rows('Attendance').filter(row => row.sessionId === sessionId);
assert.equal(closed.status, 'CLOSED');
assert.equal(attendance.find(row => row.studentId === 's1').status, 'EXCUSED');
assert.equal(attendance.find(row => row.studentId === 's2').status, 'PRESENT');
assert.throws(checkIn, /Phiên đã kết thúc/);
proof.WF02 = { sessionId, state: closed.status, A: 'EXCUSED', B: 'PRESENT', duplicate: 'alreadyRecorded', rejected: 'Phiên đã kết thúc' };

c.lab2FirebaseIdentity_ = () => ({
  email: 'teacher@fpt.edu.vn', firebaseUid: 'fixture-teacher', signInProvider: 'google.com', emailVerified: true,
});
const gradeMobile = (method, data) => c.lab2Handle_({
  action: 'lab2Call', idToken: 'fixture-token', name: 'portalCall', input: { method, data },
});
const components = [{ id: 'demo', name: 'Bài thực hành', maxScore: 10 }];
const draft = (version, score) => ({
  classId: 'c1', version, components,
  students: [
    { studentId: 's1', grades: { demo: 0 }, comment: '' },
    { studentId: 's2', grades: { demo: score }, comment: '' },
  ],
});
const publication = (version, requestKey) => ({ classId: 'c1', version, studentIds: ['s1', 's2'], requestKey });
const readScore = () => portal(studentB, 'getMyPublishedGrades', { classId: 'c1' }).grades.demo;
portal(teacher, 'saveGradebook', draft(0, 7));
portal(teacher, 'publishGrades', publication(1, 'prm-demo-publish-0001'));
const before = readScore();
gradeMobile('saveGradebook', draft(2, 8.5));
const desktopDraft = portal(teacher, 'getGradebook', { classId: 'c1' });
assert.equal(desktopDraft.students.find(row => row.studentId === 's2').grades.demo, 8.5);
const afterDraft = readScore();
assert.throws(() => gradeMobile('publishGrades', publication(2, 'prm-demo-stale-0001')), /VERSION_CONFLICT/);
const published = gradeMobile('publishGrades', publication(3, 'prm-demo-publish-0002'));
const afterPublish = readScore();
assert.deepEqual([before, afterDraft, afterPublish], [7, 7, 8.5]);
assert.equal(portal(student, 'getMyPublishedGrades', { classId: 'c1', studentId: 's2' }).grades.demo, 0);
proof.WF03 = { publicationId: published.publicationId, before, afterDraft, afterPublish, rejected: 'VERSION_CONFLICT' };

process.stdout.write(JSON.stringify(proof, null, 2) + '\n');
