const { createHash, randomUUID } = require("node:crypto");
const { XMLParser } = require("fast-xml-parser");

const lab2Hash_ = value => createHash("sha256").update(value).digest("hex");
const configValue = name => process.env[name] || "";
const config_ = () => ({
    domains: (configValue("SHARED_SCHOOL_DOMAINS") || "fpt.edu.vn,fe.edu.vn")
        .split(",").map(value => value.trim().toLowerCase()),
});
const vietnamDate = now => new Date(now + 7 * 3600000).toISOString().slice(0, 10);
const mapAsync = async (items, f) => {
    const result = [];
    for (const item of items) result.push(await f(item));
    return result;
};
const filterAsync = async (items, f) => {
    const result = [];
    for (const item of items) if (await f(item)) result.push(item);
    return result;
};
const lab2Health_ = () => ({
    version: "shared-firebase-v1",
    database: "firestore",
    firestoreMigrationVersion: 1,
    capabilities: ["attendanceSafety", "subjectInsights", "scheduleExceptions", "rosterAudit",
        "scheduleDrivenSessions", "bulkPendingAttendance", "quickAttendanceDaily", "courseSlotAttendance"],
    quizEnabled: false,
    firebaseProject: process.env.GCLOUD_PROJECT,
    authConfigured: true,
    openAlexConfigured: !!configValue("OPENALEX_API_KEY"),
});
const headerFor = table => {
    if (table === "PortalGroupSignups")
        return ["classId", "roundId", "state", "requestKey", "createdAt", "updatedAt", "closedAt"];
    const header = Object.hasOwn(SCHEMA, table) ? SCHEMA[table] :
        Object.hasOwn(LAB2_TABLES, table) ? LAB2_TABLES[table] : null;
    if (!header) throw Error("INVALID_INPUT");
    return header;
};
const sharedHasTable_ = (book, table) => Object.hasOwn(SCHEMA, table) || Object.hasOwn(LAB2_TABLES, table);
const lab2Read_ = (book, table) => book.list(table, headerFor(table)[0]);
const lab2ReadNewsCache_ = lab2Read_;
const read_ = async (book, table) => ({ rows: await lab2Read_(book, table) });
const sharedRowsById_ = (book, table, ids) =>
    book.getAll(table, headerFor(table)[0], ids.filter(id => typeof id === "string" && id));
const sharedIdentityRows_ = (book, table, email) =>
    book.where(table, headerFor(table)[0], "identityEmail", email);
function sharedRowsWhere_(book, table, key, value) {
    const header = headerFor(table);
    if (!header.includes(key)) throw Error("INVALID_INPUT");
    const values = Array.isArray(value) ? value : [value];
    if (header[0] === key) return sharedRowsById_(book, table, values.map(String));
    return book.whereAny(table, header[0], "row." + key, values.map(String));
}
const firestoreRows_ = (book, table, filter, ids) => ids ? sharedRowsById_(book, table, ids) :
    filter ? sharedRowsWhere_(book, table, filter[0], filter[1]) : lab2Read_(book, table);
function lab2Write_(book, changes) {
    for (const { table, row, delete: remove, id } of changes) {
        const header = headerFor(table);
        if (remove) book.remove(table, id);
        else book.set(table, header[0], Object.fromEntries(header.map(key => [key, row[key] ?? ""])));
    }
}
async function authenticate_(_, cfg, book) {
    const identity = book.identity;
    if (identity.signInProvider !== "google.com") throw Error("GOOGLE_ONLY");
    if (!cfg.domains.includes(identity.email.split("@")[1])) throw Error("PERMISSION_DENIED");
    const teachers = await sharedIdentityRows_(book, "Lecturers", identity.email);
    if (teachers.length !== 1) throw Error("PROFILE_NOT_REGISTERED");
    return teachers[0];
}
async function authenticateFirebaseStudent_(_, cfg, book) {
    if (!cfg.domains.includes(book.identity.email.split("@")[1])) throw Error("PERMISSION_DENIED");
    const students = await sharedIdentityRows_(book, "Students", book.identity.email);
    if (students.length !== 1) throw Error("PROFILE_NOT_REGISTERED");
    return students[0];
}
async function fetchText(url, options) {
    const response = await fetch(url, {
        headers: options.headers,
        redirect: "error",
        signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) {
        await response.body?.cancel();
        return { getResponseCode: () => response.status, getContentText: () => "" };
    }
    const reader = response.body?.getReader();
    const parts = [];
    let size = 0;
    if (reader) {
        try {
            while (true) {
                const { done, value } = await reader.read();
                if (done) break;
                size += value.length;
                if (size > 2_000_000) throw Error("UPSTREAM_UNAVAILABLE");
                parts.push(value);
            }
        } finally {
            await reader.cancel().catch(() => {});
        }
    }
    const content = Buffer.concat(parts).toString("utf8");
    return { getResponseCode: () => response.status, getContentText: () => content };
}
function contentRss_(xml) {
    if (/<!DOCTYPE/i.test(xml)) throw Error("UPSTREAM_UNAVAILABLE");
    const parser = new XMLParser({ ignoreAttributes: false, parseTagValue: false, processEntities: false });
    const source = parser.parse(xml);
    const entries = source.rss?.channel?.item ?? source.feed?.entry ?? [];
    return (Array.isArray(entries) ? entries : [entries]).slice(0, 60).map(row => {
        const text = key => String(row[key]?.["#text"] ?? row[key] ?? "");
        const link = Array.isArray(row.link) ? row.link[0] : row.link;
        const html = text("content:encoded") || text("content") || text("description") || text("summary");
        const media = row["media:thumbnail"] || row["media:content"] || row.enclosure;
        return {
            title: text("title"),
            url: link?.["@_href"] || text("link"),
            publishedAt: text("pubDate") || text("published") || text("updated"),
            excerpt: text("description") || text("summary"),
            imageUrl: contentImageUrl_(media?.["@_url"] || html.match(/<img\b[^>]*?\ssrc\s*=\s*["']([^"']+)["']/i)?.[1]),
        };
    });
}

const SCHEMA = Object.freeze({
    Lecturers: ['lecturerId', 'lecturerCode', 'fullName', 'email', 'department'],
    Schedules: ['scheduleId', 'lecturerId', 'semester', 'subjectCode', 'subjectName', 'classCode', 'dayOfWeek', 'slot', 'startTime', 'endTime', 'room', 'sourceType'],
    Classes: ['classId', 'semester', 'subjectCode', 'subjectName', 'classCode', 'lecturerId'],
    Students: ['studentId', 'studentCode', 'fullName', 'schoolEmail'],
    Enrollments: ['enrollmentId', 'classId', 'studentId'],
    Sessions: ['sessionId', 'classId', 'date', 'slot', 'startTime', 'endTime', 'status', 'currentToken', 'tokenExpiredAt', 'createdBy'],
    Attendance: ['attendanceId', 'sessionId', 'studentId', 'status', 'checkInTime', 'updatedAt', 'note', 'updatedBy'],
    SyncLogs: ['logId', 'action', 'userEmail', 'timestamp', 'description']
});
function validateSchedule_(input, lecturer) {
    if (!input || typeof input !== 'object' || Array.isArray(input))
        throw new Error('Dòng lịch không hợp lệ.');
    const row = {};
    SCHEMA.Schedules.forEach(key => {
        if (typeof input[key] !== 'string' && typeof input[key] !== 'number')
            throw new Error('Thiếu trường ' + key);
        row[key] = String(input[key]).trim();
        if (!row[key] || row[key].length > 300)
            throw new Error('Trường trống hoặc quá dài: ' + key);
    });
    if (row.lecturerId !== lecturer.lecturerId)
        throw new Error('Không được sửa lịch giảng viên khác.');
    ['semester', 'subjectCode', 'classCode'].forEach(k => row[k] = row[k].toUpperCase());
    if (!/^[A-Z]{2,6}\d{3}[A-Z0-9]*$/.test(row.subjectCode))
        throw new Error('Mã môn không hợp lệ.');
    if (!/^[1-7]$/.test(row.dayOfWeek) || !/^(?:[1-9]|1[0-2])$/.test(row.slot))
        throw new Error('Thứ hoặc slot không hợp lệ.');
    const time = /^(?:[01]\d|2[0-3]):[0-5]\d$/;
    if (!time.test(row.startTime) || !time.test(row.endTime) || row.startTime === row.endTime)
        throw new Error('Giờ học không hợp lệ.');
    if (!['MANUAL', 'IMAGE'].includes(row.sourceType))
        throw new Error('Nguồn lịch không hợp lệ.');
    return row;
}
function mutateSchedules_(existing, action, request, lecturer) {
    const result = existing.map(r => ({ ...r }));
    const index = new Map(result.map((r, i) => [r.scheduleId, i]));
    if (action === 'deleteRow') {
        const i = index.get(request.id);
        if (i === undefined)
            throw new Error('Không tìm thấy lịch.');
        if (result[i].lecturerId !== lecturer.lecturerId)
            throw new Error('Không được xóa lịch giảng viên khác.');
        result.splice(i, 1);
        return result;
    }
    const inputs = action === 'batchUpdate' ? request.rows : [request.row];
    if (!Array.isArray(inputs) || inputs.length < 1 || inputs.length > 100)
        throw new Error('Batch phải có 1–100 dòng.');
    const rows = inputs.map(r => validateSchedule_(r, lecturer));
    if (new Set(rows.map(r => r.scheduleId)).size !== rows.length)
        throw new Error('Trùng ID trong batch.');
    rows.forEach(row => {
        const i = index.get(row.scheduleId);
        if (i !== undefined && result[i].lecturerId !== lecturer.lecturerId)
            throw new Error('Không được sửa lịch giảng viên khác.');
        if (action === 'appendRow' && i !== undefined)
            throw new Error('ID lịch đã tồn tại.');
        if (action === 'updateRow' && (i === undefined || request.id !== row.scheduleId))
            throw new Error('ID cập nhật không khớp.');
        if (i === undefined) {
            index.set(row.scheduleId, result.length);
            result.push(row);
        }
        else
            result[i] = row;
    });
    const signatures = new Set();
    for (const row of result) {
        const signature = [row.lecturerId, row.semester, row.subjectCode, row.classCode, row.dayOfWeek, row.slot, row.startTime, row.endTime].join('|');
        if (signatures.has(signature))
            throw new Error('Lịch dạy bị trùng. Kiểm tra lại các dòng trước khi lưu.');
        signatures.add(signature);
    }
    return result;
}
async function handleSession_(book, cfg, lecturer, request) {
    {
        const sessions = (await read_(book, 'Sessions'));
        if (request.classId)
            (await lab2Class_(book, lab2DesktopActor_(lecturer), String(request.classId).trim(), true));
        if (request.sessionId) {
            const target = sessions.rows.find(s => s.sessionId === request.sessionId);
            if (!target)
                throw new Error('PERMISSION_DENIED');
            (await lab2Class_(book, lab2DesktopActor_(lecturer), target.classId, true));
        }
        if (request.action === 'resetSession') {
            const oldIndex = sessions.rows.findIndex(row => row.sessionId === request.sessionId);
            const old = sessions.rows[oldIndex];
            if (!old || old.createdBy !== lecturer.lecturerId)
                throw new Error('Không có quyền reset phiên này.');
            const successors = sessions.rows.filter(row => row.sessionId !== old.sessionId && row.classId === old.classId && row.date === old.date && row.slot === old.slot && row.status !== 'RESET');
            if (successors.length > 1)
                throw Error('INVALID_DATABASE_IDS');
            const successor = successors[0];
            if (old.status === 'RESET' && successor) {
                if (successor.status === 'OPEN' && (await lab2Meta_(book, successor)).closesAt <= Date.now())
                    (await lab2Finalize_(book, successor, true));
                const current = (await lab2Read_(book, 'Sessions')).find(s => s.sessionId === successor.sessionId);
                return { ...sessionView_(current), ...(await lab2SessionReceipt_(book, current)) };
            }
            if (old.status === 'RESET')
                throw new Error('Phiên đã reset. Tải lại danh sách phiên.');
            if (successor)
                throw new Error('Buổi học đang có nhiều phiên. Kiểm tra trước khi reset.');
            const receipt = (await lab2CreateFromOccurrence_(book, lab2DesktopActor_(lecturer), { classId: old.classId, sessionDate: old.date, slot: old.slot, durationMinutes: 10 }, { token: randomUUID(), secret: '', expiresAt: Date.now() + 120000 }, old));
            return { ...sessionView_((await lab2Read_(book, 'Sessions')).find(s => s.sessionId === receipt.sessionId)), ...receipt };
        }
        if (request.action === 'createSession') {
            const classId = String(request.classId || '').trim();
            const slot = String(request.slot || '').trim();
            const date = String(request.date || '').trim();
            const token = String(request.currentToken || '').trim();
            const secret = String(request.currentSecretCode || '').trim();
            const expiredAt = String(request.tokenExpiredAt || '').trim();
            if (!classId || !date || !slot || !token || token.length > 256 || (secret && !/^\d{6}$/.test(secret)) || !Number.isFinite(Date.parse(expiredAt)) || Date.parse(expiredAt) <= Date.now())
                throw Error('INVALID_INPUT');
            const receipt = (await lab2CreateFromOccurrence_(book, lab2DesktopActor_(lecturer), { classId, sessionDate: date, slot, durationMinutes: request.durationMinutes == null ? 10 : request.durationMinutes }, { token, secret, expiresAt: Date.parse(expiredAt) }));
            return { ...sessionView_((await lab2Read_(book, 'Sessions')).find(s => s.sessionId === receipt.sessionId)),
                opensAt: receipt.opensAt, closesAt: receipt.closesAt, effectiveDurationMinutes: receipt.effectiveDurationMinutes };
        }
        if (request.action === 'rotateToken') {
            const sessionId = String(request.sessionId || '').trim();
            const token = String(request.currentToken || '').trim();
            const secret = String(request.currentSecretCode || '').trim();
            const expiredAt = String(request.tokenExpiredAt || '').trim();
            const index = sessions.rows.findIndex(r => r.sessionId === sessionId);
            if (index === -1)
                throw new Error('Không tìm thấy phiên điểm danh.');
            if (sessions.rows[index].createdBy !== lecturer.lecturerId)
                throw new Error('Không có quyền sửa phiên điểm danh này.');
            if (sessions.rows[index].status !== 'OPEN')
                throw new Error('Phiên không còn mở.');
            (await lab2Class_(book, lab2DesktopActor_(lecturer), sessions.rows[index].classId, true));
            const meta = (await lab2Meta_(book, sessions.rows[index]));
            if (Date.now() >= meta.closesAt || !token || token.length > 256 || (secret && !/^\d{6}$/.test(secret)) ||
                !Number.isFinite(Date.parse(expiredAt)) || Date.parse(expiredAt) <= Date.now())
                throw new Error('INVALID_INPUT');
            const combinedToken = secret ? (token + '#' + secret) : token;
            lab2Write_(book, [{ table: 'Sessions', row: { ...sessions.rows[index], currentToken: combinedToken,
                        tokenExpiredAt: new Date(Math.min(Date.parse(expiredAt), meta.closesAt)).toISOString() } }]);
            return { saved: true };
        }
        if (request.action === 'closeSession') {
            const sessionId = String(request.sessionId || '').trim();
            const index = sessions.rows.findIndex(r => r.sessionId === sessionId);
            if (index === -1)
                throw new Error('Không tìm thấy phiên điểm danh.');
            if (sessions.rows[index].createdBy !== lecturer.lecturerId)
                throw new Error('Không có quyền kết thúc phiên điểm danh này.');
            if (sessions.rows[index].status === 'RESET')
                throw new Error('Phiên này đã được thay thế. Tải lại phiên hiện tại.');
            if (typeof lab2Finalize_ !== 'function')
                throw new Error('SHARED_BACKEND_SETUP_REQUIRED');
            (await lab2Class_(book, lab2DesktopActor_(lecturer), sessions.rows[index].classId, true));
            (await lab2Finalize_(book, sessions.rows[index]));
            return { closed: true };
        }
        if (request.action === 'getSessionAttendance') {
            const sessionId = String(request.sessionId || '').trim();
            if (!sessions.rows.some(s => s.sessionId === sessionId && s.createdBy === lecturer.lecturerId))
                throw new Error('Không có quyền đọc phiên.');
            const attendance = (await read_(book, 'Attendance')).rows.filter(r => r.sessionId === sessionId);
            const students = (await read_(book, 'Students')).rows;
            const studentMap = new Map(students.map(s => [s.studentId, s]));
            return attendance.map(a => {
                const student = studentMap.get(a.studentId);
                return {
                    ...a,
                    studentCode: student ? student.studentCode : '',
                    fullName: student ? student.fullName : ''
                };
            });
        }
        if (request.action === 'getSessionsByClass') {
            const targetId = String(request.classId || '').trim().toUpperCase();
            if (!targetId)
                return [];
            for (const s of sessions.rows.filter(r => String(r.classId).trim().toUpperCase() === targetId && r.status === 'OPEN')) {
                if ((await lab2Meta_(book, s)).closesAt <= Date.now())
                    (await lab2Finalize_(book, s, true));
            }
            const matches = (await lab2Read_(book, 'Sessions')).filter(r => {
                const rowClassId = String(r.classId || '').trim().toUpperCase();
                if (!rowClassId)
                    return false;
                const matchesLecturer = (r.createdBy === lecturer.lecturerId || !r.createdBy);
                const matchesClass = rowClassId === targetId && r.status !== 'RESET';
                return matchesLecturer && matchesClass;
            });
            return mapAsync(matches, async r => ({ ...r, ...await lab2SessionReceipt_(book, r) }));
        }
        if (request.action === 'getClassHistory') {
            const classId = String(request.classId || '').trim();
            const classSessions = sessions.rows.filter(r => r.classId === classId && r.createdBy === lecturer.lecturerId && r.status !== 'RESET');
            const sessionIds = new Set(classSessions.map(s => s.sessionId));
            const attendance = (await read_(book, 'Attendance')).rows.filter(r => sessionIds.has(r.sessionId));
            const students = (await read_(book, 'Students')).rows;
            const studentMap = new Map(students.map(s => [s.studentId, s]));
            return attendance.map(a => {
                const student = studentMap.get(a.studentId);
                return {
                    ...a,
                    studentCode: student ? student.studentCode : '',
                    fullName: student ? student.fullName : ''
                };
            });
        }
        if (request.action === 'getLecturerClasses') {
            const lecturerId = lecturer.lecturerId;
            return (await read_(book, 'Classes')).rows.filter(r => r.lecturerId === lecturerId);
        }
        if (request.action === 'updateAttendance') {
            const attendanceId = String(request.attendanceId || '').trim();
            const status = String(request.status || '').trim().toUpperCase();
            const note = String(request.note || '').trim();
            const updatedBy = lecturer.email;
            const nowIso = new Date().toISOString();
            const attendance = (await read_(book, 'Attendance'));
            const index = attendance.rows.findIndex(r => r.attendanceId === attendanceId);
            if (index === -1)
                throw new Error('Không tìm thấy bản ghi điểm danh.');
            const owned = sessions.rows.find(s => s.sessionId === attendance.rows[index].sessionId && s.createdBy === lecturer.lecturerId && s.status !== 'RESET');
            if (!owned || !['PRESENT', 'LATE', 'ABSENT', 'EXCUSED'].includes(status))
                throw new Error('Không có quyền sửa bản ghi hoặc trạng thái không hợp lệ.');
            if (typeof lab2Correct_ !== 'function')
                throw new Error('SHARED_BACKEND_SETUP_REQUIRED');
            (await lab2Correct_(book, lab2DesktopActor_(lecturer), owned, attendance.rows[index].studentId, status, note, attendance.rows[index]));
            return { saved: true };
        }
        if (request.action === 'markAbsent') {
            const sessionId = String(request.sessionId || '').trim();
            const studentCodes = Array.isArray(request.studentCodes) ? request.studentCodes : [];
            const markedBy = lecturer.email;
            const owned = sessions.rows.find(s => s.sessionId === sessionId && s.createdBy === lecturer.lecturerId && s.status === 'CLOSED');
            if (!owned)
                throw new Error('Chỉ chốt vắng cho phiên đã đóng của bạn.');
            (await lab2Class_(book, lab2DesktopActor_(lecturer), owned.classId, true));
            const frozen = (await lab2Meta_(book, owned)).eligibleStudentIds;
            const enrollmentIds = new Set(frozen || (await read_(book, 'Attendance')).rows.filter(e => e.sessionId === owned.sessionId).map(e => e.studentId));
            const nowIso = new Date().toISOString();
            const attendance = (await read_(book, 'Attendance'));
            const students = (await read_(book, 'Students')).rows;
            const studentMap = new Map(students.map(s => [s.studentCode, s]));
            const newRows = [];
            studentCodes.forEach(code => {
                const student = studentMap.get(code);
                if (student && enrollmentIds.has(student.studentId)) {
                    const already = attendance.rows.some(a => a.sessionId === sessionId && a.studentId === student.studentId);
                    if (!already) {
                        const newRecord = {
                            attendanceId: randomUUID(),
                            sessionId: sessionId,
                            studentId: student.studentId,
                            status: 'ABSENT',
                            checkInTime: '',
                            updatedAt: nowIso,
                            note: 'Chốt vắng tự động khi kết thúc phiên',
                            updatedBy: markedBy
                        };
                        newRows.push({ table: 'Attendance', row: newRecord });
                    }
                }
            });
            lab2Write_(book, newRows);
            return { saved: true, count: newRows.length };
        }
        throw new Error('Thao tác session chưa được hỗ trợ.');
    }
}
function sessionView_(session) {
    const [currentToken, currentSecretCode = ''] = String(session.currentToken || '').split('#');
    return { ...session, currentToken, currentSecretCode };
}
async function assertMobileQrSession_(book, session, request, student) {
    if (!sharedHasTable_(book, 'Lab2SessionMeta'))
        return;
    const row = (await sharedRowsWhere_(book, 'Lab2SessionMeta', 'sessionId', session.sessionId))[0];
    if (!row)
        return; // Desktop legacy behavior stays in its own handler.
    const deadline = Number(row.closesAt);
    const expiry = Date.parse(session.tokenExpiredAt), view = sessionView_(session);
    if (!Number.isFinite(deadline) || Date.now() >= deadline || !Number.isFinite(expiry) || Date.now() >= expiry)
        throw new Error('Phiên điểm danh đã hết hạn. Quét mã của phiên mới.');
    if (!view.currentToken || String(request.token || '') !== view.currentToken)
        throw new Error('Mã QR đã thay đổi. Quét mã mới đang hiển thị.');
    if (student) {
        let eligible;
        try {
            eligible = JSON.parse(row.eligibleStudentIds);
        }
        catch (_) {
            throw new Error('Không đọc được danh sách phiên. Liên hệ giảng viên.');
        }
        if (!Array.isArray(eligible) || !eligible.includes(student.studentId))
            throw new Error('Sinh viên không thuộc danh sách lớp tại thời điểm mở phiên.');
    }
}
async function studentContext_(request, cfg, book, byCode = false, verifiedStudent = null) {
    let student;
    if (byCode) {
        // Legacy route can only be used with verified Google identity, even when enabled.
        if (configValue('ALLOW_VERIFIED_STUDENT_CODE') !== 'true')
            throw new Error('Điểm danh bằng MSSV đã tắt. Đăng nhập Google hoặc liên hệ giảng viên.');
        const verified = verifiedStudent || (await authenticateFirebaseStudent_(request.idToken, cfg, book));
        const code = String(request.studentCode || '').trim().toUpperCase();
        if (!/^[A-Z0-9]{5,20}$/.test(code))
            throw new Error('Vui lòng nhập MSSV hợp lệ.');
        const matches = (await read_(book, 'Students')).rows.filter(s => String(s.studentCode).trim().toUpperCase() === code);
        if (matches.length !== 1)
            throw new Error('MSSV chưa có hoặc bị trùng trong danh sách sinh viên.');
        student = matches[0];
        if (student.studentId !== verified.studentId)
            throw new Error('MSSV không thuộc tài khoản đã xác minh.');
    }
    else
        student = verifiedStudent || await authenticateFirebaseStudent_(request.idToken, cfg, book);
    const session = (await sharedRowsWhere_(book, 'Sessions', 'sessionId', request.sessionId))[0];
    if (!session)
        throw new Error('Phiên điểm danh không tồn tại.');
    if (session.status !== 'OPEN')
        throw new Error('Phiên đã kết thúc hoặc được reset. Quét mã mới.');
    (await assertMobileQrSession_(book, session, request, student));
    if (!(await sharedRowsWhere_(book, 'Enrollments', 'classId', session.classId)).some(e => e.studentId === student.studentId))
        throw new Error('Sinh viên không thuộc danh sách lớp của buổi học này.');
    const cls = (await sharedRowsWhere_(book, 'Classes', 'classId', session.classId))[0];
    if (!cls)
        throw new Error('Không tìm thấy lớp học.');
    return { student, session, cls };
}
async function handleStudentSession_(book, request) {
    const cfg = config_();
    const { student, session, cls } = (await studentContext_(request, cfg, book));
    return { student: { fullName: student.fullName, studentCode: student.studentCode, email: student.schoolEmail },
        session: { sessionId: session.sessionId, classCode: cls.classCode, subjectCode: cls.subjectCode,
            date: session.date, slot: session.slot, startTime: session.startTime, endTime: session.endTime,
            secretEnabled: !!sessionView_(session).currentSecretCode } };
}
async function handleStudentCheckIn_(book, request, byCode = false) {
    if (request.confirmPresent !== true)
        throw new Error('Bạn phải xác nhận đang có mặt trong lớp để điểm danh.');
    const cfg = config_();
    if (byCode && configValue('ALLOW_VERIFIED_STUDENT_CODE') !== 'true')
        throw new Error('Điểm danh bằng MSSV đã tắt. Đăng nhập Google hoặc liên hệ giảng viên.');
    // Verify over the network before acquiring the write lock; reread session/roster inside it.
    const verified = (await authenticateFirebaseStudent_(request.idToken, cfg, book));
    {
        const { student, session } = (await studentContext_(request, cfg, book, byCode, verified));
        const view = sessionView_(session);
        const expires = new Date(session.tokenExpiredAt).getTime();
        if (!byCode && (!Number.isFinite(expires) || Date.now() >= expires))
            throw new Error('Mã điểm danh đã hết hạn. Quét mã mới hoặc nhập Secret Code hiện tại.');
        if (view.currentSecretCode) {
            if (String(request.secretCode || '') !== view.currentSecretCode)
                throw new Error('Giảng viên đang bật Secret Code. Nhập mã hiện tại hoặc quét lại QR.');
        }
        else if (!byCode) {
            if (request.useSecret === true)
                throw new Error('Secret Code chưa được bật. Quét lại mã QR.');
            if (!view.currentToken || String(request.token || '') !== view.currentToken)
                throw new Error('Mã QR không hợp lệ hoặc đã thay đổi. Quét mã mới.');
        }
        const previous = (await sharedRowsWhere_(book, 'Attendance', 'sessionId', session.sessionId)).filter(a => a.studentId === student.studentId);
        if (previous.length > 1)
            throw new Error('INVALID_DATABASE_IDS');
        if (previous.length) {
            if (!['PRESENT', 'LATE'].includes(previous[0].status))
                throw new Error('Điểm danh đã được giảng viên điều chỉnh. Liên hệ giảng viên.');
            return { status: previous[0].status, checkInTime: previous[0].checkInTime, studentCode: student.studentCode, fullName: student.fullName, alreadyRecorded: true };
        }
        const nowIso = new Date().toISOString();
        const record = { attendanceId: randomUUID(), sessionId: session.sessionId, studentId: student.studentId,
            status: 'PRESENT', checkInTime: nowIso, updatedAt: nowIso,
            note: byCode ? 'Student code; presence confirmed' : 'Google verified; presence confirmed',
            updatedBy: byCode ? student.studentCode : student.schoolEmail };
        lab2Write_(book, [{ table: 'Attendance', row: record }]);
        return { status: record.status, checkInTime: nowIso, studentCode: student.studentCode, fullName: student.fullName };
    }
}
async function handle_(book, request) {
    const cfg = config_();
    const lecturer = (await authenticate_(request.idToken, cfg, book));
    if (request.action === 'profile')
        return lecturer;
    if (request.action === 'desktopAttendanceCall') {
        return (await lab2DesktopAttendance_(book, lecturer, request));
    }
    if (['getRoster', 'importRoster'].includes(request.action)) {
        return (await handleRoster_(book, cfg, lecturer, request));
    }
    if (['resetSession', 'createSession', 'rotateToken', 'closeSession', 'getSessionAttendance', 'getSessionsByClass', 'getClassHistory', 'updateAttendance', 'markAbsent', 'getLecturerClasses'].includes(request.action)) {
        return (await handleSession_(book, cfg, lecturer, request));
    }
    if (request.action === 'getRows') {
        if (!['Lecturers', 'Schedules', 'Classes', 'Sessions', 'Attendance'].includes(request.sheet))
            throw new Error('Module này chưa được cấp quyền đọc.');
        return (await read_(book, request.sheet)).rows.filter(r => r.lecturerId === lecturer.lecturerId || r.createdBy === lecturer.lecturerId);
    }
    if (request.sheet !== 'Schedules' || !['appendRow', 'updateRow', 'deleteRow', 'batchUpdate'].includes(request.action)) {
        throw new Error('Thao tác chưa được hỗ trợ. Không có generic write cho sheet khác.');
    }
    {
        const current = (await read_(book, 'Schedules'));
        const rows = mutateSchedules_(current.rows, request.action, request, lecturer);
        {
            const old = new Map(current.rows.map(row => [row.scheduleId, row]));
            const next = new Set(rows.map(row => row.scheduleId));
            const changes = rows.filter(row => JSON.stringify(old.get(row.scheduleId)) !== JSON.stringify(row)).map(row => ({ table: 'Schedules', row }));
            current.rows.filter(row => !next.has(row.scheduleId)).forEach(row => changes.push({ table: 'Schedules', id: row.scheduleId, delete: true }));
            changes.push({ table: 'SyncLogs', row: { logId: randomUUID(), action: request.action, userEmail: lecturer.email,
                    timestamp: new Date().toISOString(), description: 'Schedules: ' + rows.length + ' rows after mutation' } });
            lab2Write_(book, changes);
        }
        return { saved: true };
    }
}
function rosterTarget_(request, classes, schedules, lecturer) {
    const fields = ['semester', 'subjectCode', 'classCode'];
    const target = Object.fromEntries(fields.map(k => [k, String(request[k] || '').trim().toUpperCase()]));
    if (fields.some(k => !target[k] || target[k].length > 100))
        throw new Error('Thiếu học kỳ, môn hoặc mã lớp.');
    const matches = r => r.lecturerId === lecturer.lecturerId && fields.every(k => String(r[k]).trim().toUpperCase() === target[k]);
    const found = classes.filter(matches);
    if (found.length > 1)
        throw new Error('Trùng khóa lớp. Cần xử lý trước khi nhập sinh viên.');
    const schedule = schedules.find(matches);
    if (!found.length && !schedule)
        throw new Error('Lớp không thuộc lịch dạy của bạn.');
    return { ...target, lecturerId: lecturer.lecturerId, classId: found[0]?.classId || '', subjectName: found[0]?.subjectName || schedule?.subjectName || '' };
}
function importRoster_(request, state, lecturer, uuid) {
    const target = rosterTarget_(request, state.classes, state.schedules, lecturer);
    if (!Array.isArray(request.students) || !request.students.length || request.students.length > 1000)
        throw new Error('Nhập từ 1 đến 1.000 sinh viên mỗi lần.');
    const students = state.students.map(s => ({ ...s }));
    const classes = state.classes.map(c => ({ ...c }));
    const enrollments = state.enrollments.map(e => ({ ...e }));
    const codes = new Map();
    for (const s of students) {
        const code = String(s.studentCode).trim().toUpperCase();
        if (codes.has(code))
            throw new Error('Mã sinh viên trùng trong hệ thống. Cần xử lý trước khi nhập.');
        codes.set(code, s);
    }
    if (!target.classId) {
        target.classId = uuid();
        classes.push({ ...target });
    }
    const enrolled = new Set(enrollments.filter(e => e.classId === target.classId).map(e => e.studentId));
    let added = 0, existing = 0;
    const seen = new Map();
    for (const input of request.students) {
        if (!input || typeof input !== 'object')
            throw new Error('Dòng sinh viên không hợp lệ.');
        const code = String(input.studentCode || '').trim().toUpperCase();
        const fullName = String(input.fullName || '').trim();
        const schoolEmail = String(input.schoolEmail || '').trim().toLowerCase();
        if (String(input.classCode || '').trim().toUpperCase() !== target.classCode)
            throw new Error('Mã lớp trong file không khớp lớp đích.');
        if (!/^[A-Z0-9][A-Z0-9._-]{1,39}$/.test(code) || !fullName || fullName.length > 200 || schoolEmail.length > 254 ||
            (schoolEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(schoolEmail)))
            throw new Error('Mã sinh viên, họ tên hoặc email không hợp lệ.');
        const signature = JSON.stringify([fullName, schoolEmail]);
        if (seen.has(code) && seen.get(code) !== signature)
            throw new Error('Một mã sinh viên có nhiều thông tin khác nhau trong file.');
        seen.set(code, signature);
        let student = codes.get(code);
        if (student && String(student.fullName).trim().toLowerCase().replace(/\s+/g, ' ') !== fullName.toLowerCase().replace(/\s+/g, ' ')) {
            throw new Error('Họ tên không khớp mã sinh viên ' + code + ' đã có. Kiểm tra lại file.');
        }
        if (!student) {
            student = { studentId: uuid(), studentCode: code, fullName, schoolEmail };
            students.push(student);
            codes.set(code, student);
        }
        if (enrolled.has(student.studentId)) {
            existing++;
            continue;
        }
        enrollments.push({ enrollmentId: uuid(), classId: target.classId, studentId: student.studentId });
        enrolled.add(student.studentId);
        added++;
    }
    return { classes, students, enrollments, added, existing, classId: target.classId };
}
async function handleRoster_(book, cfg, lecturer, request) {
    {
        const classes = (await read_(book, 'Classes')), students = (await read_(book, 'Students')), enrollments = (await read_(book, 'Enrollments'));
        const schedules = (await read_(book, 'Schedules')).rows;
        const target = rosterTarget_(request, classes.rows, schedules, lecturer);
        if (request.action === 'getRoster') {
            const ids = new Set(enrollments.rows.filter(e => e.classId === target.classId).map(e => e.studentId));
            return students.rows.filter(s => ids.has(s.studentId)).map(s => ({ ...s, classCode: target.classCode }));
        }
        const next = importRoster_(request, { classes: classes.rows, students: students.rows, enrollments: enrollments.rows, schedules }, lecturer, () => randomUUID());
        {
            const changes = [];
            for (const [table, current, rows] of [['Classes', classes, next.classes], ['Students', students, next.students], ['Enrollments', enrollments, next.enrollments]]) {
                for (const row of rows.slice(current.rows.length))
                    changes.push({ table, row });
            }
            changes.push({ table: 'SyncLogs', row: { logId: randomUUID(), action: 'importRoster', userEmail: lecturer.email,
                    timestamp: new Date().toISOString(), description: 'Added enrollments: ' + next.added } });
            lab2Write_(book, changes);
            return { added: next.added, existing: next.existing, classId: next.classId };
        }
    }
}
const LAB2_TABLES = Object.freeze({
    PortalGroupSignupSheets: ['classId', 'spreadsheetId', 'sheetId', 'state', 'planVersion', 'groups', 'roster', 'prepared', 'createdBy', 'lecturerId', 'lecturerEmail', 'createdAt', 'lastSyncedAt', 'lastError', 'requestKey'],
    PortalGroupTasks: ['id', 'classId', 'groupId', 'groupName', 'title', 'description', 'dueAt', 'createdAt', 'createdBy', 'requestKey', 'fingerprint'],
    PortalTaskNotifications: ['id', 'taskId', 'classId', 'groupId', 'studentId', 'email', 'createdAt', 'readAt', 'emailStatus', 'emailSentAt'],
    PortalGroupPlans: ['classId', 'groups', 'version', 'updatedAt', 'updatedBy', 'requestKey'],
    PortalGroupReceipts: ['id', 'classId', 'groupId', 'actor', 'receipts'],
    PortalGroupMessages: ['id', 'classId', 'groupId', 'sender', 'senderName', 'text', 'fileId', 'fileName', 'mimeType', 'size', 'createdAt', 'requestKey'],
    PortalGroupPushDevices: ['id', 'actor', 'firebaseUid', 'platform', 'token', 'updatedAt'],
    PortalLeaveRequests: ['id', 'classId', 'studentId', 'occurrenceId', 'scheduleId', 'exceptionId', 'sessionDate', 'slot', 'startTime', 'endTime', 'reason', 'status', 'submittedAt', 'reviewedAt', 'reviewedBy', 'reviewNote', 'version', 'requestKey'],
    PortalGradebooks: ['classId', 'components', 'version', 'activePublicationId', 'updatedAt', 'updatedBy'],
    PortalGradeDrafts: ['id', 'classId', 'studentId', 'grades', 'comment'],
    PortalPublications: ['id', 'classId', 'version', 'components', 'publishedAt', 'publishedBy', 'requestKey'],
    PortalPublishedGrades: ['id', 'publicationId', 'studentId', 'grades', 'comment'],
    PortalAudit: ['id', 'classId', 'entityId', 'actor', 'action', 'at', 'detail'],
    Lab2ClassAttendanceConfig: ['classId', 'totalSlots', 'updatedBy', 'updatedAt'],
    Lab2AttendanceCompletion: ['sessionId', 'status', 'confirmedAt', 'confirmedBy'],
    Lab2SessionMeta: ['sessionId', 'title', 'opensAt', 'closesAt', 'lateThresholdAt', 'eligibleStudentIds'],
    Lab2SharedArticles: ['id', 'classId', 'articleId', 'article', 'sharedBy', 'note', 'sharedAt'],
    Lab2ArticleCache: ['id', 'article', 'subjectIds', 'expiresAt'],
    Lab2Feeds: ['id', 'feed', 'expiresAt'],
    AttendanceAudit: ['id', 'sessionId', 'studentId', 'actorUid', 'changedAt', 'oldStatus', 'newStatus', 'reason'],
    SubjectContentConfig: ['subjectCode', 'topicKeywords', 'excludeKeywords', 'sourceIds', 'enabled', 'updatedAt'],
    ContentSourceRegistry: ['sourceId', 'label', 'type', 'url', 'enabled'],
    SubjectContentCache: ['id', 'feed', 'expiresAt'],
    ScheduleExceptions: ['id', 'scheduleId', 'classId', 'date', 'kind', 'targetDate', 'slot', 'startTime', 'endTime', 'room', 'reason', 'createdBy', 'updatedAt'],
    RosterAudit: ['id', 'classId', 'studentId', 'actorUid', 'changedAt', 'oldValue', 'newValue', 'reason']
});
async function lab2Actor_(identity, cfg, book) {
    if (!cfg.domains.includes(identity.email.split('@')[1]))
        throw Error('PERMISSION_DENIED');
    const teachers = (await sharedIdentityRows_(book, 'Lecturers', identity.email));
    if (teachers.length > 1)
        throw Error('DUPLICATE_PROFILE');
    if (teachers.length === 1)
        return { ...identity, role: 'lecturer', entity: teachers[0], uid: 'lecturer-' + teachers[0].lecturerId };
    const students = (await sharedIdentityRows_(book, 'Students', identity.email));
    if (students.length !== 1)
        throw Error('PROFILE_NOT_REGISTERED');
    return { ...identity, role: 'student', entity: students[0], uid: 'student-' + students[0].studentId };
}
async function lab2Class_(book, actor, id, teacherOnly) {
    const cls = (await sharedRowsWhere_(book, 'Classes', 'classId', id))[0];
    if (!cls)
        throw Error('PERMISSION_DENIED');
    if (actor.role === 'lecturer') {
        if (cls.lecturerId !== actor.entity.lecturerId)
            throw Error('PERMISSION_DENIED');
    }
    else if (teacherOnly || !(await sharedRowsWhere_(book, 'Enrollments', 'classId', id)).some(e => e.studentId === actor.entity.studentId)) {
        throw Error('NOT_ENROLLED');
    }
    return cls;
}
function lab2Millis_(date, time) {
    const value = Date.parse(String(date) + 'T' + String(time || '00:00') + ':00+07:00');
    if (!Number.isFinite(value))
        throw Error('INVALID_SESSION_DATE');
    return value;
}
async function lab2Meta_(book, session) {
    const stored = (await sharedRowsWhere_(book, 'Lab2SessionMeta', 'sessionId', session.sessionId))[0];
    if (stored)
        return { ...stored, opensAt: Number(stored.opensAt), closesAt: Number(stored.closesAt), lateThresholdAt: Number(stored.lateThresholdAt),
            eligibleStudentIds: JSON.parse(stored.eligibleStudentIds) };
    // Desktop legacy sessions have no late threshold or historical membership snapshot.
    return { sessionId: session.sessionId, title: 'Slot ' + session.slot, opensAt: lab2Millis_(session.date, session.startTime),
        closesAt: lab2Millis_(session.date, session.endTime) + (session.endTime < session.startTime ? 86400000 : 0), lateThresholdAt: null, eligibleStudentIds: null };
}
async function lab2Finalize_(book, session, automatic = false) {
    if (session.status !== 'OPEN')
        return;
    const meta = (await lab2Meta_(book, session));
    const eligible = meta.eligibleStudentIds || (await sharedRowsWhere_(book, 'Attendance', 'sessionId', session.sessionId)).map(e => e.studentId);
    if (eligible.length > 400)
        throw Error('CLASS_TOO_LARGE');
    const attendance = (await sharedRowsWhere_(book, 'Attendance', 'sessionId', session.sessionId));
    const now = new Date().toISOString();
    const changes = [{ table: 'Sessions', row: { ...session, status: 'CLOSED', currentToken: '', tokenExpiredAt: '' } },
        { table: 'Lab2AttendanceCompletion', row: { sessionId: session.sessionId, status: automatic ? 'PENDING' : 'CONFIRMED', confirmedAt: automatic ? '' : now, confirmedBy: automatic ? '' : session.createdBy } }];
    const excused = typeof portalApprovedForSession_ === 'function' ? (await portalApprovedForSession_(book, session)) : new Map();
    for (const id of new Set(eligible))
        if (!attendance.some(a => a.studentId === id)) {
            changes.push({ table: 'Attendance', row: { attendanceId: randomUUID(), sessionId: session.sessionId, studentId: id,
                    status: excused.has(id) ? 'EXCUSED' : 'ABSENT', checkInTime: '', updatedAt: now, note: excused.has(id) ? 'Approved leave: ' + excused.get(id).id : 'Lab2 finalized', updatedBy: session.createdBy } });
        }
    lab2Write_(book, changes);
}
function lab2EffectiveRoom_(tables, session, cls) {
    const changes = (tables.ScheduleExceptions || []).filter(e => e.classId === cls.classId);
    const exception = changes.filter(e => e.targetDate === session.date && String(e.slot) === String(session.slot) && ['MAKEUP', 'RESCHEDULED'].includes(e.kind));
    if (exception.length === 1)
        return exception[0].room || '';
    const bases = (tables.Schedules || []).filter(s => s.lecturerId === cls.lecturerId && s.semester === cls.semester && s.classCode === cls.classCode && s.subjectCode === cls.subjectCode && String(s.slot) === String(session.slot) && Number(s.dayOfWeek) === lab2Day_(session.date));
    if (bases.length !== 1)
        return '';
    const overrides = changes.filter(e => e.scheduleId === bases[0].scheduleId && e.date === session.date && ['ROOM_CHANGED', 'RESTORED'].includes(e.kind));
    return overrides.length === 1 ? overrides[0].room || '' : bases[0].room || '';
}
function lab2SnapshotFrom_(tables, actor) {
    const classes = tables.Classes.filter(c => actor.role === 'lecturer' ? c.lecturerId === actor.entity.lecturerId :
        tables.Enrollments.some(e => e.classId === c.classId && e.studentId === actor.entity.studentId));
    const ids = new Set(classes.map(c => c.classId));
    const subjects = [...new Set(classes.map(c => c.subjectCode))];
    const c = { classes: [], subjects: subjects.map(id => ({ id, code: id, name: classes.find(x => x.subjectCode === id).subjectName, active: true })),
        schedules: [], classSessions: [], attendanceSessions: [], attendanceRecords: [], sharedArticles: [] };
    if (actor.role === 'lecturer') {
        c.schedules = (tables.Schedules || []).filter(s => s.lecturerId === actor.entity.lecturerId).map(s => {
            const matches = classes.filter(x => x.semester === s.semester && x.subjectCode === s.subjectCode && x.classCode === s.classCode);
            return { id: s.scheduleId, lecturerUid: actor.uid, classId: matches.length === 1 ? matches[0].classId : null,
                term: s.semester, subjectId: s.subjectCode, subjectName: s.subjectName, classCode: s.classCode,
                dayOfWeek: Number(s.dayOfWeek), slot: Number(s.slot), startTime: s.startTime, endTime: s.endTime, room: s.room };
        });
    }
    for (const cls of classes) {
        const students = tables.Students.filter(s => tables.Enrollments.some(e => e.classId === cls.classId && e.studentId === s.studentId));
        c.classes.push({ id: cls.classId, classCode: cls.classCode, subjectId: cls.subjectCode, subjectName: cls.subjectName, term: cls.semester,
            lecturerUids: ['lecturer-' + cls.lecturerId], studentUids: actor.role === 'lecturer' ? students.map(s => 'student-' + s.studentId) : [actor.uid],
            studentCount: students.length, status: 'active',
            totalSlots: Number((tables.Lab2ClassAttendanceConfig || []).find(r => r.classId === cls.classId)?.totalSlots) || null });
        c['classes/' + cls.classId + '/members'] = students.filter(s => actor.role === 'lecturer' || s.studentId === actor.entity.studentId)
            .map(s => ({ id: 'student-' + s.studentId, studentUid: 'student-' + s.studentId, studentCode: s.studentCode, displayName: s.fullName, schoolEmail: s.schoolEmail, active: true }));
    }
    for (const s of tables.Sessions.filter(s => ids.has(s.classId) && s.status !== 'RESET')) {
        const cls = classes.find(x => x.classId === s.classId);
        const records = tables.Attendance.filter(a => a.sessionId === s.sessionId);
        const raw = tables.Lab2SessionMeta.find(m => m.sessionId === s.sessionId);
        const eligible = raw ? JSON.parse(raw.eligibleStudentIds) : s.status === 'CLOSED' ?
            [...new Set(records.map(a => a.studentId))] : tables.Enrollments.filter(e => e.classId === s.classId).map(e => e.studentId);
        const opens = raw ? Number(raw.opensAt) : lab2Millis_(s.date, s.startTime);
        const closes = raw ? Number(raw.closesAt) : lab2Millis_(s.date, s.endTime) + (s.endTime < s.startTime ? 86400000 : 0);
        const room = lab2EffectiveRoom_(tables, s, cls);
        c.classSessions.push({ id: s.sessionId, classId: s.classId, subjectId: cls.subjectCode, subjectName: cls.subjectName, classCode: cls.classCode, title: raw ? raw.title : 'Slot ' + s.slot,
            room, lecturerUid: 'lecturer-' + cls.lecturerId, slot: Number(s.slot), startsAt: lab2Millis_(s.date, s.startTime), endsAt: lab2Millis_(s.date, s.endTime) + (s.endTime < s.startTime ? 86400000 : 0),
            status: s.status === 'CLOSED' && !tables.Lab2AttendanceCompletion.some(m => m.sessionId === s.sessionId && m.status === 'PENDING') ? 'completed' : 'scheduled' });
        c.attendanceSessions.push({ id: s.sessionId, classId: s.classId, classSessionId: s.sessionId, subjectId: cls.subjectCode, subjectName: cls.subjectName, classCode: cls.classCode, room, slot: Number(s.slot), opensAt: opens, closesAt: closes,
            lateThresholdAt: raw ? Number(raw.lateThresholdAt) : null, status: s.status === 'CLOSED' ? 'finalized' : 'open',
            sessionDate: s.date, attendanceCompleted: s.status === 'CLOSED' && !tables.Lab2AttendanceCompletion.some(m => m.sessionId === s.sessionId && m.status === 'PENDING'),
            eligibleStudentUids: eligible.filter(id => actor.role === 'lecturer' || id === actor.entity.studentId).map(id => 'student-' + id),
            checkedInCount: records.filter(a => ['PRESENT', 'LATE'].includes(a.status) && (actor.role === 'lecturer' || a.studentId === actor.entity.studentId)).length,
            eligibleCount: eligible.filter(id => actor.role === 'lecturer' || id === actor.entity.studentId).length,
            membershipKnown: !!raw, qrRotationSeconds: null });
        for (const a of records.filter(a => actor.role === 'lecturer' || a.studentId === actor.entity.studentId)) {
            if (!['PRESENT', 'LATE', 'ABSENT', 'EXCUSED'].includes(a.status))
                continue;
            c.attendanceRecords.push({ id: s.sessionId + '_student-' + a.studentId, classId: s.classId, classSessionId: s.sessionId,
                attendanceSessionId: s.sessionId, studentUid: 'student-' + a.studentId, subjectId: cls.subjectCode, subjectName: cls.subjectName, slot: Number(s.slot), status: a.status.toLowerCase(),
                checkedInAt: a.checkInTime ? Date.parse(a.checkInTime) : null, recordedAt: Date.parse(a.updatedAt) || opens, notes: a.note || '' });
        }
    }
    c.sharedArticles = tables.Lab2SharedArticles.filter(r => ids.has(r.classId)).map(r => ({ ...JSON.parse(r.article), id: r.id, classId: r.classId, articleId: r.articleId, sharedBy: r.sharedBy, note: r.note, sharedAt: Number(r.sharedAt) }));
    c.scheduleExceptions = (tables.ScheduleExceptions || []).filter(r => ids.has(r.classId));
    return { version: 'lab2-shared-sheets-v1', syncedAt: Date.now(), profile: { uid: actor.uid, firebaseUid: actor.firebaseUid,
            displayName: actor.entity.fullName, email: actor.email, lecturerId: actor.role === 'lecturer' ? actor.entity.lecturerId : '', department: actor.entity.department || '', role: actor.role, active: true, subjectIds: subjects, attendancePolicy: lab2Policy_() }, collections: c };
}
async function lab2SnapshotTables_(book, actor) {
    const lecturer = actor.role === 'lecturer';
    const classes = lecturer ? (await sharedRowsWhere_(book, 'Classes', 'lecturerId', actor.entity.lecturerId)) :
        (await sharedRowsById_(book, 'Classes', (await sharedRowsWhere_(book, 'Enrollments', 'studentId', actor.entity.studentId)).map(row => row.classId)));
    const classIds = classes.map(row => row.classId);
    const enrollments = (await sharedRowsWhere_(book, 'Enrollments', 'classId', classIds));
    const sessions = (await sharedRowsWhere_(book, 'Sessions', 'classId', classIds)).filter(row => row.status !== 'RESET');
    const sessionIds = sessions.map(row => row.sessionId);
    return {
        Classes: classes, Enrollments: enrollments, Sessions: sessions,
        Schedules: (await sharedRowsWhere_(book, 'Schedules', 'lecturerId', lecturer ? actor.entity.lecturerId : classes.map(row => row.lecturerId))),
        Students: (await sharedRowsById_(book, 'Students', enrollments.map(row => row.studentId))),
        Attendance: (await sharedRowsWhere_(book, 'Attendance', 'sessionId', sessionIds)),
        Lab2SessionMeta: (await sharedRowsById_(book, 'Lab2SessionMeta', sessionIds)),
        Lab2AttendanceCompletion: (await sharedRowsById_(book, 'Lab2AttendanceCompletion', sessionIds)),
        Lab2ClassAttendanceConfig: (await sharedRowsById_(book, 'Lab2ClassAttendanceConfig', classIds)),
        Lab2SharedArticles: (await sharedRowsWhere_(book, 'Lab2SharedArticles', 'classId', classIds)),
        ScheduleExceptions: (await sharedRowsWhere_(book, 'ScheduleExceptions', 'classId', classIds))
    };
}
async function lab2Snapshot_(book, actor) {
    let tables = (await lab2SnapshotTables_(book, actor));
    const allowed = new Set(tables.Classes.filter(c => actor.role === 'lecturer' ? c.lecturerId === actor.entity.lecturerId :
        tables.Enrollments.some(e => e.classId === c.classId && e.studentId === actor.entity.studentId)).map(c => c.classId));
    const expired = tables.Sessions.filter(s => s.status === 'OPEN' && allowed.has(s.classId) &&
        tables.Lab2SessionMeta.some(m => m.sessionId === s.sessionId && Number(m.closesAt) <= Date.now()));
    if (expired.length) {
        {
            for (const old of expired) {
                const current = (await sharedRowsWhere_(book, 'Sessions', 'sessionId', old.sessionId))[0];
                if (current && current.status === 'OPEN' && (await lab2Meta_(book, current)).closesAt <= Date.now())
                    (await lab2Finalize_(book, current, true));
            }
            tables = (await lab2SnapshotTables_(book, actor));
        }
    }
    return lab2SnapshotFrom_(tables, actor);
}
async function lab2ImportTimetable_(book, actor, d) {
    if (actor.role !== 'lecturer')
        throw Error('PERMISSION_DENIED');
    if (!Array.isArray(d.schedules) || !d.schedules.length || d.schedules.length > 100)
        throw Error('INVALID_INPUT');
    const schedules = (await lab2Read_(book, 'Schedules')), classes = (await lab2Read_(book, 'Classes')), changes = [], seen = new Set();
    const owner = actor.entity.lecturerId, time = /^(?:[01]\d|2[0-3]):[0-5]\d$/;
    for (const raw of d.schedules) {
        const row = {};
        for (const k of ['semester', 'subjectCode', 'subjectName', 'classCode', 'startTime', 'endTime', 'room'])
            row[k] = String(raw[k] || '').trim();
        for (const k of ['semester', 'subjectCode', 'classCode'])
            row[k] = row[k].toUpperCase();
        const day = Number(raw.dayOfWeek), slot = Number(raw.slot);
        if (['semester', 'subjectCode', 'classCode'].some(k => !row[k] || row[k].length > 100) || row.subjectName.length > 200 || row.room.length > 100 ||
            !Number.isInteger(day) || day < 1 || day > 7 || !Number.isInteger(slot) || slot < 1 || slot > 12 ||
            !time.test(row.startTime) || !time.test(row.endTime) || row.startTime === row.endTime)
            throw Error('INVALID_INPUT');
        const match = c => ['semester', 'subjectCode', 'classCode'].every(k => String(c[k]).trim().toUpperCase() === row[k]);
        const key = [row.semester, row.subjectCode, row.classCode, day, slot].join('|');
        if (seen.has(key))
            throw Error('INVALID_INPUT');
        seen.add(key);
        const classMatches = classes.filter(match);
        if (classMatches.some(c => c.lecturerId !== owner))
            throw Error('PERMISSION_DENIED');
        if (classMatches.length > 1)
            throw Error('INVALID_DATABASE_IDS');
        if (!classMatches.length) {
            const cls = { classId: randomUUID(), semester: row.semester, subjectCode: row.subjectCode,
                subjectName: row.subjectName || row.subjectCode, classCode: row.classCode, lecturerId: owner };
            classes.push(cls);
            changes.push({ table: 'Classes', row: cls });
        }
        const matches = schedules.filter(s => s.lecturerId === owner && match(s) && Number(s.dayOfWeek) === day && Number(s.slot) === slot);
        if (matches.length > 1)
            throw Error('INVALID_DATABASE_IDS');
        changes.push({ table: 'Schedules', row: { ...row, scheduleId: matches[0] ? matches[0].scheduleId : randomUUID(),
                lecturerId: owner, dayOfWeek: day, slot, sourceType: 'MANUAL' } });
    }
    lab2Write_(book, changes);
    return { saved: d.schedules.length };
}
async function lab2ImportStudents_(book, actor, d) {
    if (actor.role !== 'lecturer')
        throw Error('PERMISSION_DENIED');
    const cls = (await lab2Class_(book, actor, d.classId, true));
    if (!Array.isArray(d.students) || !d.students.length || d.students.length > 400)
        throw Error('INVALID_INPUT');
    const state = { classes: (await lab2Read_(book, 'Classes')), students: (await lab2Read_(book, 'Students')),
        enrollments: (await lab2Read_(book, 'Enrollments')), schedules: (await lab2Read_(book, 'Schedules')) };
    const next = importRoster_({ ...cls, students: d.students }, state, actor.entity, () => randomUUID());
    const size = next.enrollments.filter(e => e.classId === cls.classId).length;
    if (size > 400)
        throw Error('CLASS_TOO_LARGE');
    const changes = [];
    for (const [table, old, rows] of [['Classes', state.classes, next.classes], ['Students', state.students, next.students], ['Enrollments', state.enrollments, next.enrollments]])
        for (const row of rows.slice(old.length))
            changes.push({ table, row });
    lab2Write_(book, changes);
    return { added: next.added, existing: next.existing };
}
async function lab2Mutate_(book, actor, name, d) {
    {
        if (name === 'setClassAttendanceConfig')
            return (await lab2SetClassAttendanceConfig_(book, actor, d));
        if (name === 'importTimetable')
            return (await lab2ImportTimetable_(book, actor, d));
        if (name === 'importClassStudents')
            return (await lab2ImportStudents_(book, actor, d));
        if (name === 'saveScheduleException')
            return (await lab2SaveException_(book, actor, d));
        if (name === 'updateClassStudent')
            return (await lab2UpdateStudent_(book, actor, d));
        if (name === 'createClassSession') {
            return (await lab2CreateFromOccurrence_(book, actor, d));
        }
        if (name === 'submitQuickAttendance')
            return (await lab2QuickSubmit_(book, actor, d));
        if (name === 'checkInWithQr') {
            if (actor.role !== 'student')
                throw Error('PERMISSION_DENIED');
            const text = String(d.token || '');
            if (text.length > 2000)
                throw Error('QR_INVALID');
            const params = {};
            text.replace(/[?&]([^=&]+)=([^&]*)/g, (_, k, v) => { params[decodeURIComponent(k)] = decodeURIComponent(v); return ''; });
            if (!params.sessionId || !params.token)
                throw Error('QR_INVALID');
            const s = (await lab2Read_(book, 'Sessions')).find(s => s.sessionId === params.sessionId);
            if (!s)
                throw Error('QR_INVALID');
            (await lab2Class_(book, actor, s.classId, false));
            const meta = (await lab2Meta_(book, s)), view = sessionView_(s), now = Date.now();
            if (s.status !== 'OPEN' || now >= meta.closesAt)
                throw Error('SESSION_CLOSED');
            if (meta.eligibleStudentIds && !meta.eligibleStudentIds.includes(actor.entity.studentId))
                throw Error('NOT_ENROLLED');
            if (!Number.isFinite(Date.parse(s.tokenExpiredAt)) || now >= Date.parse(s.tokenExpiredAt))
                throw Error('QR_EXPIRED');
            if (!view.currentToken || params.token !== view.currentToken)
                throw Error('QR_INVALID');
            if (view.currentSecretCode) {
                if (!d.secretCode)
                    throw Error('SECRET_REQUIRED');
                if (String(d.secretCode).trim() !== view.currentSecretCode)
                    throw Error('SECRET_INVALID');
            }
            const previous = (await sharedRowsWhere_(book, 'Attendance', 'sessionId', s.sessionId)).filter(a => a.studentId === actor.entity.studentId);
            if (previous.length > 1)
                throw Error('INVALID_DATABASE_IDS');
            if (previous.length) {
                if (!['PRESENT', 'LATE'].includes(previous[0].status))
                    throw Error('ATTENDANCE_ADJUSTED');
                return { status: previous[0].status.toLowerCase(), checkedInAt: Date.parse(previous[0].checkInTime), alreadyRecorded: true };
            }
            const status = 'PRESENT';
            lab2Write_(book, [{ table: 'Attendance', row: { attendanceId: randomUUID(), sessionId: s.sessionId, studentId: actor.entity.studentId,
                        status, checkInTime: new Date(now).toISOString(), updatedAt: new Date(now).toISOString(), note: 'Firebase verified; Mobile Lab2', updatedBy: actor.email } }]);
            return { status: status.toLowerCase(), checkedInAt: now };
        }
        if (actor.role !== 'lecturer')
            throw Error('PERMISSION_DENIED');
        const sessionId = d.attendanceSessionId || d.classSessionId;
        const s = (await lab2Read_(book, 'Sessions')).find(s => s.sessionId === sessionId);
        if (!s)
            throw Error('PERMISSION_DENIED');
        (await lab2Class_(book, actor, s.classId, true));
        if (name === 'bulkUpdatePendingAttendance')
            return (await lab2BulkPending_(book, actor, s, d));
        if (name === 'updateAttendanceRecord') {
            if (s.status === 'RESET')
                throw Error('SESSION_CLOSED');
            const status = String(d.status || '').toUpperCase(), notes = String(d.notes || '').trim();
            const studentId = String(d.studentUid || '').replace(/^student-/, '');
            if (!['PRESENT', 'LATE', 'ABSENT', 'EXCUSED'].includes(status) || notes.length > 500 || !notes)
                throw Error('INVALID_INPUT');
            const meta = (await lab2Meta_(book, s));
            const eligible = meta.eligibleStudentIds || (await lab2Read_(book, 'Enrollments')).filter(e => e.classId === s.classId).map(e => e.studentId);
            const previous = (await sharedRowsWhere_(book, 'Attendance', 'sessionId', s.sessionId)).filter(a => a.studentId === studentId);
            if (previous.length > 1)
                throw Error('INVALID_DATABASE_IDS');
            if (!eligible.includes(studentId) && !previous.length)
                throw Error('NOT_ENROLLED');
            const old = previous[0], now = new Date().toISOString();
            (await lab2Correct_(book, actor, s, studentId, status, notes, old));
            return { updated: true };
        }
        if (name === 'closeAttendanceSession') {
            if (s.status === 'RESET')
                throw Error('SESSION_CLOSED');
            (await lab2Finalize_(book, s));
            return { closed: true };
        }
        const meta = (await lab2Meta_(book, s)), now = Date.now();
        if (s.status !== 'OPEN' || now >= meta.closesAt)
            throw Error('SESSION_CLOSED');
        if (name === 'openAttendanceSession')
            return { attendanceSessionId: s.sessionId };
        if (name === 'rotateAttendanceQr') {
            if (d.secretEnabled != null && typeof d.secretEnabled !== 'boolean')
                throw Error('INVALID_INPUT');
            const old = sessionView_(s), enabled = d.secretEnabled == null ? !!old.currentSecretCode : d.secretEnabled;
            const secret = enabled ? (d.secretEnabled == null && old.currentSecretCode ? old.currentSecretCode : String(parseInt(randomUUID().replace(/-/g, '').slice(0, 8), 16) % 1000000).padStart(6, '0')) : '';
            const token = randomUUID() + randomUUID(), expiry = Math.min(now + 4 * 60 * 60000, meta.closesAt);
            lab2Write_(book, [{ table: 'Sessions', row: { ...s, currentToken: token + (secret ? '#' + secret : ''), tokenExpiredAt: new Date(expiry).toISOString() } }]);
            return { updated: true };
        }
        if (name === 'getQrToken') {
            let view = sessionView_(s), expiry = Date.parse(s.tokenExpiredAt);
            if (!view.currentToken || !Number.isFinite(expiry) || now >= expiry) {
                expiry = Math.min(now + 4 * 60 * 60000, meta.closesAt);
                const value = randomUUID() + randomUUID();
                lab2Write_(book, [{ table: 'Sessions', row: { ...s, currentToken: value + (view.currentSecretCode ? '#' + view.currentSecretCode : ''), tokenExpiredAt: new Date(expiry).toISOString() } }]);
                view = { ...view, currentToken: value };
            }
            const base = configValue('LAB2_CHECKIN_URL') || 'https://fap-attendance-88920.web.app/checkin';
            return { token: base + (base.includes('?') ? '&' : '?') + 'sessionId=' + encodeURIComponent(s.sessionId) + '&token=' + encodeURIComponent(view.currentToken) +
                    '&mode=' + (view.currentSecretCode ? 'google-secret' : 'google') + '&v=5', secretEnabled: !!view.currentSecretCode, secretCode: view.currentSecretCode,
                expiresAt: Math.min(expiry, meta.closesAt), serverNow: now };
        }
        throw Error('FEATURE_DISABLED');
    }
}
function lab2Abstract_(item) {
    if (typeof item.abstract === 'string')
        return item.abstract.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 12000) || null;
    const index = item.abstract_inverted_index;
    if (!index || typeof index !== 'object')
        return null;
    const words = new Map();
    for (const [word, positions] of Object.entries(index))
        if (Array.isArray(positions))
            for (const position of positions)
                if (Number.isInteger(position) && position >= 0 && position < 3000)
                    words.set(position, word);
    return [...words.entries()].sort((a, b) => a[0] - b[0]).map(e => e[1]).join(' ').slice(0, 12000) || null;
}
async function lab2Discover_(book, actor, d) {
    const classes = (await lab2Read_(book, 'Classes')).filter(c => c.subjectCode === d.subjectId);
    const classIds = new Set(actor.role === 'lecturer' ? classes.filter(c => c.lecturerId === actor.entity.lecturerId).map(c => c.classId) : (await sharedRowsWhere_(book, 'Enrollments', 'studentId', actor.entity.studentId)).map(e => e.classId));
    if (!classes.some(c => classIds.has(c.classId)))
        throw Error('PERMISSION_DENIED');
    const source = d.source, page = Number(d.page || 1), sort = d.sort || 'recent';
    if (!['OpenAlex', 'Crossref'].includes(source) || !['recent', 'relevance'].includes(sort) || !Number.isInteger(page) || page < 1 || page > 50)
        throw Error('INVALID_INPUT');
    const keywords = { PRM393: 'Flutter Dart mobile development', PRN212: 'ASP.NET Core', SWE201c: 'software engineering' };
    const query = String(d.query || keywords[d.subjectId] || classes[0].subjectName).trim();
    if (!query || query.length > 150 || d.fromDate && !/^\d{4}-\d{2}-\d{2}$/.test(d.fromDate))
        throw Error('INVALID_INPUT');
    const hash = lab2Hash_(JSON.stringify([d.subjectId, source, query, page, sort, d.fromDate || '']));
    const cached = (await lab2ReadNewsCache_(book, 'Lab2Feeds')).find(r => r.id === hash), now = Date.now();
    if (cached && Number(cached.expiresAt) > now)
        return { ...JSON.parse(cached.feed), cached: true, stale: false };
    const headers = {};
    let url;
    if (source === 'OpenAlex') {
        const key = configValue('OPENALEX_API_KEY');
        if (!key)
            throw Error('OPENALEX_SETUP_REQUIRED');
        headers.Authorization = 'Bearer ' + key;
        url = 'https://api.openalex.org/works?search=' + encodeURIComponent(query) + '&per_page=20&page=' + page +
            '&sort=' + (sort === 'recent' ? 'publication_date:desc' : 'relevance_score:desc') + (d.fromDate ? '&filter=from_publication_date:' + d.fromDate : '');
    }
    else {
        url = 'https://api.crossref.org/works?query=' + encodeURIComponent(query) + '&rows=20&offset=' + ((page - 1) * 20) +
            '&sort=' + (sort === 'recent' ? 'published' : 'relevance') + '&order=desc' + (d.fromDate ? '&filter=from-pub-date:' + d.fromDate : '');
    }
    try {
        const response = (await fetchText(url, { headers, muteHttpExceptions: true }));
        if (response.getResponseCode() !== 200)
            throw Error('ARTICLE_SOURCE_UNAVAILABLE');
        const json = JSON.parse(response.getContentText()), items = source === 'OpenAlex' ? json.results : json.message.items;
        const unique = {};
        for (const item of items) {
            const doi = String(item.doi || item.DOI || '').replace(/^https?:\/\/(?:dx\.)?doi.org\//i, '').trim().toLowerCase();
            const rawUrl = doi ? 'https://doi.org/' + doi : source === 'OpenAlex' ? ((item.primary_location || {}).landing_page_url || item.id) : item.URL;
            const title = source === 'OpenAlex' ? item.display_name : (item.title || [])[0];
            if (!title || !/^https:\/\/[^\s@]+$/i.test(rawUrl || ''))
                continue;
            const id = lab2Hash_(doi || rawUrl);
            const parts = ((item.published || item['published-print'] || item['published-online'] || {})['date-parts'] || [])[0];
            const date = source === 'OpenAlex' ? item.publication_date : parts ? parts.map((n, i) => i ? String(n).padStart(2, '0') : String(n)).join('-') : null;
            unique[id] = { id, doi: doi || null, title: String(title).slice(0, 500), url: rawUrl, source,
                publisher: String(source === 'OpenAlex' ? (((item.primary_location || {}).source || {}).display_name || '') : item.publisher || '').slice(0, 200),
                authors: (source === 'OpenAlex' ? (item.authorships || []).map(a => (a.author || {}).display_name) : (item.author || []).map(a => [a.given, a.family].filter(Boolean).join(' '))).filter(Boolean).slice(0, 12),
                publishedAt: date, abstractSnippet: lab2Abstract_(item), subjectIds: [d.subjectId] };
        }
        const articles = Object.values(unique), feed = { articles, nextPage: items.length === 20 ? page + 1 : null, fetchedAt: now, expiresAt: now + 21600000 };
        let cacheSaved = true;
        try {
            {
                const previous = (await lab2ReadNewsCache_(book, 'Lab2ArticleCache'));
                if (previous.length > 2000)
                    throw Error('ARTICLE_CACHE_FULL');
                lab2Write_(book, [{ table: 'Lab2Feeds', row: { id: hash, feed: JSON.stringify(feed), expiresAt: feed.expiresAt } }, ...articles.map(a => {
                        const old = previous.find(r => r.id === a.id);
                        const subjects = [...new Set([...(old ? JSON.parse(old.subjectIds) : []), d.subjectId])];
                        return { table: 'Lab2ArticleCache', row: { id: a.id, article: JSON.stringify(a), subjectIds: JSON.stringify(subjects), expiresAt: feed.expiresAt } };
                    })]);
            }
        }
        catch (_) {
            cacheSaved = false;
        }
        return { ...feed, articles: cacheSaved ? articles : articles.map(a => ({ ...a, canShare: false })), cached: false, stale: false, cacheSaved };
    }
    catch (_) {
        if (cached)
            return { ...JSON.parse(cached.feed), cached: true, stale: true };
        throw Error('ARTICLE_SOURCE_UNAVAILABLE');
    }
}
async function lab2Share_(book, actor, d) {
    const cls = (await lab2Class_(book, actor, d.classId, true)), note = String(d.note || '').trim();
    if (note.length > 500)
        throw Error('INVALID_INPUT');
    const article = (await lab2ReadNewsCache_(book, 'Lab2ArticleCache')).find(a => a.id === d.articleId && JSON.parse(a.subjectIds).includes(cls.subjectCode));
    if (!article)
        throw Error('INVALID_INPUT');
    {
        lab2Write_(book, [{ table: 'Lab2SharedArticles', row: { id: d.classId + '_' + article.id, classId: d.classId,
                    articleId: article.id, article: article.article, sharedBy: actor.uid, note, sharedAt: Date.now() } }]);
        return { shared: true };
    }
}
async function lab2Handle_(book, request) {
    if (request.action === 'lab2Health') {
        const health = lab2Health_();
        return health;
    }
    const cfg = config_();
    const identity = book.identity, actor = (await lab2Actor_(identity, cfg, book));
    const name = request.action === 'lab2Snapshot' ? 'snapshot' : request.name;
    if (name === 'snapshot') {
        if (request.googleLecturerOnly === true) {
            if (identity.signInProvider !== 'google.com')
                throw Error('GOOGLE_ONLY');
            if (actor.role !== 'lecturer')
                throw Error('LECTURER_REQUIRED');
        }
        return (await lab2Snapshot_(book, actor));
    }
    const d = request.input;
    if (!d || typeof d !== 'object' || Array.isArray(d))
        throw Error('INVALID_INPUT');
    if (name === 'portalCall') {
        if (identity.signInProvider !== 'google.com')
            throw Error('GOOGLE_ONLY');
        if (actor.role !== 'lecturer')
            throw Error('PERMISSION_DENIED');
        if (!['getGradebook', 'saveGradebook', 'publishGrades', 'revokeGrades', 'listClassLeaveRequests', 'reviewLeaveRequest', 'applyApprovedLeave'].includes(d.method))
            throw Error('UNKNOWN_PORTAL_METHOD');
        {
            const result = (await portalCall_(book, actor, d.method, d.data || {}));
            // The mobile lab2 transport expects an object. Keep the Portal list API unchanged.
            return d.method === 'listClassLeaveRequests' ? { requests: result } : result;
        }
    }
    if (name === 'groupCall') {
        let result;
        {
            result = (await groupCall_(book, actor, String(d.method || ''), d.data || {}));
        }
        return book.pushAfterCommit(actor, result);
    }
    if (name === 'discoverArticles')
        return (await lab2Discover_(book, actor, d));
    if (name === 'shareArticle')
        return (await lab2Share_(book, actor, d));
    if (name === 'getTeachingOccurrence')
        return (await lab2OccurrenceView_(book, actor, d));
    if (name === 'getAttendanceSessionLive')
        return (await lab2Live_(book, actor, d));
    if (name === 'getQuickAttendanceContext')
        return (await lab2QuickContext_(book, actor, d));
    if (name === 'getSubjectUpdates')
        return (await subjectUpdates_(book, actor, d));
    if (name === 'getSubjectTopics')
        return (await subjectTopics_(book, actor, d));
    if (!['setClassAttendanceConfig', 'createClassSession', 'openAttendanceSession', 'getQrToken', 'checkInWithQr', 'closeAttendanceSession', 'rotateAttendanceQr', 'updateAttendanceRecord', 'submitQuickAttendance', 'bulkUpdatePendingAttendance', 'importTimetable', 'importClassStudents', 'saveScheduleException', 'updateClassStudent'].includes(name))
        throw Error('FEATURE_DISABLED');
    return (await lab2Mutate_(book, actor, name, d));
}
async function lab2ClassAttendanceConfigs_(book) {
    return sharedHasTable_(book, 'Lab2ClassAttendanceConfig')
        ? (await lab2Read_(book, 'Lab2ClassAttendanceConfig')) : [];
}
async function lab2SetClassAttendanceConfig_(book, actor, d) {
    if (actor.role !== 'lecturer')
        throw Error('PERMISSION_DENIED');
    const cls = (await lab2Class_(book, actor, d.classId, true));
    if (Object.keys(d).some(k => !['classId', 'totalSlots'].includes(k)) ||
        !Number.isInteger(d.totalSlots) || d.totalSlots < 1 || d.totalSlots > 1000)
        throw Error('INVALID_INPUT');
    const completion = (await lab2Read_(book, 'Lab2AttendanceCompletion'));
    const confirmed = (await lab2Read_(book, 'Sessions')).filter(s => s.classId === cls.classId && s.status === 'CLOSED' &&
        !completion.some(c => c.sessionId === s.sessionId && c.status === 'PENDING'));
    if (new Set(confirmed.map(s => s.date + '|' + s.slot)).size > d.totalSlots)
        throw Error('TOTAL_SLOTS_BELOW_COMPLETED');
    lab2Write_(book, [{ table: 'Lab2ClassAttendanceConfig', row: { classId: cls.classId, totalSlots: d.totalSlots,
                updatedBy: actor.firebaseUid || actor.uid, updatedAt: new Date().toISOString() } }]);
    return { saved: true, totalSlots: d.totalSlots };
}
function lab2Policy_() {
    const p = { getProperty: configValue };
    const tri = k => p.getProperty(k) === 'true' ? true : p.getProperty(k) === 'false' ? false : null;
    return { lateCountsAsPresent: tri('ATTENDANCE_LATE_COUNTS_PRESENT'),
        excusedInDenominator: tri('ATTENDANCE_EXCUSED_IN_DENOMINATOR'), warningPercent: 15, limitPercent: 20 };
}
async function lab2Correct_(book, actor, session, studentId, status, reason, old) {
    if (!['PRESENT', 'LATE', 'ABSENT', 'EXCUSED'].includes(status) || !reason || reason.length > 500)
        throw Error('INVALID_INPUT');
    (await lab2Class_(book, actor, session.classId, true));
    if (session.status === 'RESET')
        throw Error('SESSION_CLOSED');
    if (old && old.status === status && old.note === reason)
        return; // Retry after lost response.
    const now = new Date().toISOString();
    const audit = { id: randomUUID(), sessionId: session.sessionId, studentId,
        actorUid: actor.firebaseUid || actor.uid, changedAt: now, oldStatus: old ? old.status : 'PENDING', newStatus: status, reason };
    lab2Write_(book, [{ table: 'Attendance', row: { ...old, attendanceId: old ? old.attendanceId : randomUUID(),
                sessionId: session.sessionId, studentId, status, checkInTime: old ? old.checkInTime : '', updatedAt: now, note: reason, updatedBy: actor.email } },
        { table: 'AttendanceAudit', row: audit }]);
}
async function lab2BulkPending_(book, actor, session, d) {
    const entries = d.changes, reason = String(d.notes || '').trim(), requestId = String(d.requestId || '');
    if (!Array.isArray(entries) || !entries.length || entries.length > 400 || !reason || reason.length > 500 ||
        !/^[a-zA-Z0-9-]{16,80}$/.test(requestId) || typeof d.expectedRevision !== 'string')
        throw Error('INVALID_INPUT');
    const seen = new Set(), changes = entries.map(e => {
        if (!e || typeof e !== 'object' || Array.isArray(e))
            throw Error('INVALID_INPUT');
        const id = String(e.studentUid || '').replace(/^student-/, ''), status = String(e.status || '').toUpperCase();
        if (!id || seen.has(id) || !['PRESENT', 'ABSENT'].includes(status))
            throw Error('INVALID_INPUT');
        seen.add(id);
        return { id, status };
    });
    const actorUid = actor.firebaseUid || actor.uid;
    const prefix = 'bulk-' + lab2Hash_(JSON.stringify([session.sessionId, actorUid, requestId])) + '-';
    const audits = (await lab2Read_(book, 'AttendanceAudit')).filter(a => a.id.startsWith(prefix));
    if (audits.length) {
        if (audits.length !== changes.length || changes.some((e, i) => !audits.some(a => a.id === prefix + i &&
            a.studentId === e.id && a.newStatus === e.status && a.reason === reason)))
            throw Error('INVALID_INPUT');
        return { updated: changes.length, alreadyApplied: true };
    }
    const meta = (await lab2Meta_(book, session));
    if (session.status !== 'OPEN' || Date.now() >= meta.closesAt)
        throw Error('SESSION_CLOSED');
    // Legacy sessions without captured membership must use individual corrections.
    if (!meta.eligibleStudentIds)
        throw Error('BULK_ROSTER_REQUIRED');
    const records = (await sharedRowsWhere_(book, 'Attendance', 'sessionId', session.sessionId));
    if (new Set(records.map(a => a.studentId)).size !== records.length)
        throw Error('INVALID_DATABASE_IDS');
    if (d.expectedRevision !== lab2Hash_(JSON.stringify([session.status, records])))
        throw Error('ATTENDANCE_CONFLICT');
    if (changes.some(e => !meta.eligibleStudentIds.includes(e.id)))
        throw Error('NOT_ENROLLED');
    if (changes.some(e => records.some(a => a.studentId === e.id)))
        throw Error('ATTENDANCE_CONFLICT');
    const now = new Date().toISOString(), writes = [];
    changes.forEach((e, i) => {
        writes.push({ table: 'Attendance', row: { attendanceId: randomUUID(), sessionId: session.sessionId,
                studentId: e.id, status: e.status, checkInTime: '', updatedAt: now, note: reason, updatedBy: actor.email } });
        writes.push({ table: 'AttendanceAudit', row: { id: prefix + i, sessionId: session.sessionId, studentId: e.id,
                actorUid, changedAt: now, oldStatus: 'PENDING', newStatus: e.status, reason } });
    });
    lab2Write_(book, writes);
    return { updated: changes.length, alreadyApplied: false };
}
async function reconcileExpiredSessions(book) {
    {
        const meta = (await lab2Read_(book, 'Lab2SessionMeta')), now = Date.now();
        const sessions = (await lab2Read_(book, 'Sessions')).filter(s => s.status === 'OPEN' && meta.some(m => m.sessionId === s.sessionId && Number(m.closesAt) <= now));
        for (const s of sessions.slice(0, 25))
            (await lab2Finalize_(book, s, true));
        return { closed: Math.min(sessions.length, 25), remaining: Math.max(0, sessions.length - 25) };
    }
}
async function lab2Live_(book, actor, d) {
    if (actor.role !== 'lecturer')
        throw Error('PERMISSION_DENIED');
    {
        let session = (await sharedRowsWhere_(book, 'Sessions', 'sessionId', d.sessionId))[0];
        if (!session)
            throw Error('PERMISSION_DENIED');
        const cls = (await lab2Class_(book, actor, session.classId, true)), meta = (await lab2Meta_(book, session));
        if (session.status === 'OPEN' && meta.eligibleStudentIds && meta.closesAt <= Date.now()) {
            (await lab2Finalize_(book, session, true));
            session = (await sharedRowsWhere_(book, 'Sessions', 'sessionId', d.sessionId))[0];
        }
        const records = (await sharedRowsWhere_(book, 'Attendance', 'sessionId', session.sessionId));
        if (new Set(records.map(r => r.studentId)).size !== records.length)
            throw Error('INVALID_DATABASE_IDS');
        const eligible = meta.eligibleStudentIds || (session.status === 'CLOSED' ? records.map(r => r.studentId) :
            (await sharedRowsWhere_(book, 'Enrollments', 'classId', session.classId)).map(e => e.studentId));
        const byId = new Map(records.map(r => [r.studentId, r]));
        const ids = [...new Set([...eligible, ...byId.keys()])];
        const roster = (await sharedRowsById_(book, 'Students', ids));
        const students = ids.map(id => {
            const student = roster.find(s => s.studentId === id) || {}, record = byId.get(id);
            return { studentUid: 'student-' + id, studentCode: student.studentCode || '', displayName: student.fullName || '',
                status: record ? record.status.toLowerCase() : 'pending', notes: record ? record.note : '', checkedInAt: record ? record.checkInTime : null };
        });
        const counts = { eligible: eligible.length, present: 0, late: 0, absent: 0, excused: 0, pending: 0 };
        students.forEach(s => { if (s.status in counts)
            counts[s.status]++; });
        const updated = Math.max(meta.opensAt, ...records.map(r => Date.parse(r.updatedAt) || 0));
        return { sessionId: session.sessionId, classId: session.classId, classCode: cls.classCode, subjectId: cls.subjectCode,
            subjectName: cls.subjectName, room: lab2EffectiveRoom_({ Schedules: (await lab2Read_(book, 'Schedules')), ScheduleExceptions: (await lab2Read_(book, 'ScheduleExceptions')) }, session, cls), sessionDate: session.date, slot: Number(session.slot), status: session.status, serverTime: new Date().toISOString(),
            opensAt: meta.opensAt, closesAt: meta.closesAt, effectiveDurationMinutes: (meta.closesAt - meta.opensAt) / 60000, expiresAt: new Date(meta.closesAt).toISOString(), lastUpdatedAt: new Date(updated).toISOString(),
            revision: lab2Hash_(JSON.stringify([session.status, records])), counts, students };
    }
}
function lab2DesktopActor_(lecturer) {
    return { role: 'lecturer', entity: lecturer, uid: 'lecturer-' + lecturer.lecturerId, email: lecturer.email };
}
async function lab2DesktopAttendance_(book, lecturer, request) {
    const actor = lab2DesktopActor_(lecturer), d = request.input, name = request.name;
    if (!d || typeof d !== 'object' || Array.isArray(d))
        throw Error('INVALID_INPUT');
    if (name === 'getQuickAttendanceContext')
        return (await lab2QuickContext_(book, actor, d));
    if (name === 'submitQuickAttendance')
        return (await lab2Mutate_(book, actor, name, d));
    if (name !== 'getAttendanceDay')
        throw Error('FEATURE_DISABLED');
    const date = String(d.sessionDate || '');
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || new Date(lab2Millis_(date, '00:00') + 7 * 3600000).toISOString().slice(0, 10) !== date)
        throw Error('INVALID_SESSION_DATE');
    {
        const tables = { Classes: (await lab2Read_(book, 'Classes')), Schedules: (await lab2Read_(book, 'Schedules')), ScheduleExceptions: (await lab2Read_(book, 'ScheduleExceptions')) };
        const now = Date.now(), today = vietnamDate(now), lessons = [];
        for (const cls of tables.Classes.filter(c => c.lecturerId === lecturer.lecturerId)) {
            for (const o of (await lab2Occurrences_(book, actor, cls.classId, date, tables))) {
                const current = (await lab2OccurrenceSession_(book, o)), s = current.session;
                const completion = s ? (await lab2Read_(book, 'Lab2AttendanceCompletion')).find(r => r.sessionId === s.sessionId) : null;
                const completed = !!s && s.status === 'CLOSED' && (!completion || completion.status === 'CONFIRMED');
                lessons.push({ ...o, semester: cls.semester, completed, editable: date === today && !current.resetOnly,
                    state: completed ? 'CLOSED' : current.resetOnly ? 'RESET' : date === today ? 'AVAILABLE' : date > today ? 'NOT_YET' : 'DAY_EXPIRED',
                    qrState: lab2OccurrenceState_(o, current, now), sessionId: s ? s.sessionId : null, status: s ? s.status : null,
                    attendanceCompleted: completed });
            }
        }
        lessons.sort((a, b) => a.scheduledStartAt - b.scheduledStartAt || a.classId.localeCompare(b.classId));
        return { sessionDate: date, serverTime: now, lessons };
    }
}
function lab2QuickRevision_(session, records) {
    return session ? lab2Hash_(JSON.stringify([session.status, records])) : '';
}
async function lab2QuickState_(book, actor, d) {
    if (actor.role !== 'lecturer')
        throw Error('PERMISSION_DENIED');
    if (!LAB2_TABLES.Lab2AttendanceCompletion)
        throw Error('ATTENDANCE_BACKEND_UPDATE_REQUIRED');
    const o = (await lab2ResolveOccurrence_(book, actor, d)), existing = (await lab2OccurrenceSession_(book, o)), now = Date.now();
    const session = existing.session || null;
    const completion = session ? (await lab2Read_(book, 'Lab2AttendanceCompletion')).find(m => m.sessionId === session.sessionId) : null;
    const completed = !!session && session.status === 'CLOSED' && (!completion || completion.status === 'CONFIRMED');
    const today = vietnamDate(now);
    const state = completed ? 'CLOSED' : existing.resetOnly ? 'RESET' : o.sessionDate === today ? 'AVAILABLE' : o.sessionDate > today ? 'NOT_YET' : 'DAY_EXPIRED';
    const records = session ? (await sharedRowsWhere_(book, 'Attendance', 'sessionId', session.sessionId)) : [];
    if (new Set(records.map(r => r.studentId)).size !== records.length)
        throw Error('INVALID_DATABASE_IDS');
    let eligible;
    if (session) {
        const meta = (await lab2Meta_(book, session));
        eligible = meta.eligibleStudentIds || (session.status === 'CLOSED' ? records.map(r => r.studentId) :
            (await sharedRowsWhere_(book, 'Enrollments', 'classId', session.classId)).map(e => e.studentId));
    }
    else
        eligible = (await lab2Read_(book, 'Enrollments')).filter(e => e.classId === o.classId).map(e => e.studentId);
    eligible = [...new Set([...eligible, ...records.map(r => r.studentId)])];
    if (eligible.length > 400)
        throw Error('CLASS_TOO_LARGE');
    return { o, session, state, completed, editable: o.sessionDate === today && !existing.resetOnly, provisional: completion && completion.status === 'PENDING', records, eligible, revision: lab2QuickRevision_(session, records), now };
}
function lab2QuickCounts_(eligible, statusOf) {
    const counts = { eligible: eligible.length, present: 0, late: 0, absent: 0, excused: 0, pending: 0 };
    for (const id of eligible) {
        const s = String(statusOf(id) || 'pending').toLowerCase();
        if (s in counts)
            counts[s]++;
    }
    return counts;
}
async function lab2QuickContext_(book, actor, d) {
    {
        const q = (await lab2QuickState_(book, actor, d)), roster = (await lab2Read_(book, 'Students')), byId = new Map(q.records.map(r => [r.studentId, r]));
        const students = q.eligible.map(id => {
            const s = roster.find(x => x.studentId === id) || {}, r = byId.get(id);
            return { studentId: id, studentUid: 'student-' + id, studentCode: s.studentCode || '', displayName: s.fullName || '',
                status: r && !(q.provisional && r.note === 'Lab2 finalized') ? r.status.toLowerCase() : null, notes: r ? r.note : '', updatedAt: r ? r.updatedAt : '' };
        }).sort((a, b) => String(a.studentCode).localeCompare(String(b.studentCode)));
        const savedAt = q.session && q.session.status === 'CLOSED' ? Math.max(0, ...q.records.map(r => Date.parse(r.updatedAt) || 0)) : null;
        const config = (await lab2ClassAttendanceConfigs_(book)).find(c => c.classId === q.o.classId);
        return { ...q.o, totalSlots: config ? Number(config.totalSlots) : null, state: q.state, editable: q.editable, serverTime: q.now, revision: q.revision,
            ...(q.session ? (await lab2SessionReceipt_(book, q.session)) : {}), attendanceCompleted: q.completed, savedAt, students,
            counts: lab2QuickCounts_(q.eligible, id => byId.get(id) && byId.get(id).status) };
    }
}
async function lab2QuickSubmit_(book, actor, d) {
    const ids = Array.isArray(d.studentIds) ? d.studentIds.map(String) : null, list = Array.isArray(d.exceptions) ? d.exceptions : null;
    const requestId = String(d.clientRequestId || '');
    if (!ids || !ids.length || !list || ids.length > 400 || list.length > 400 || typeof d.expectedRevision !== 'string' ||
        new Set(ids).size !== ids.length || !/^[a-zA-Z0-9_-]{1,160}$/.test(requestId))
        throw Error('INVALID_INPUT');
    const wanted = new Map();
    for (const e of list) {
        const id = String(e && (e.studentId || e.studentUid) || '').replace(/^student-/, ''), status = String(e && e.status || '').toUpperCase();
        if (!id || wanted.has(id) || !['PRESENT', 'ABSENT'].includes(status))
            throw Error('INVALID_INPUT');
        wanted.set(id, status);
    }
    const q = (await lab2QuickState_(book, actor, d)), actorUid = actor.firebaseUid || actor.uid;
    const receiptPrefix = 'quick-' + lab2Hash_(JSON.stringify([q.o.occurrenceId, actorUid, requestId])) + '-';
    const fingerprint = lab2Hash_(JSON.stringify([d.expectedRevision, [...ids].sort(), [...wanted].sort((a, b) => a[0].localeCompare(b[0]))]));
    const sameRoster = eligible => eligible.length === ids.length && eligible.every(id => ids.includes(id)) && [...wanted.keys()].every(id => eligible.includes(id));
    const result = async (q, extra) => {
        const byId = new Map(q.records.map(r => [r.studentId, r]));
        return { ...(await lab2SessionReceipt_(book, q.session)), occurrenceId: q.o.occurrenceId, counts: lab2QuickCounts_(q.eligible, id => byId.get(id) && byId.get(id).status), ...extra };
    };
    if (q.completed) {
        // Matching statuses alone do not prove that this request was committed.
        const prior = (await lab2Read_(book, 'AttendanceAudit')).filter(a => a.sessionId === q.session.sessionId && a.id.startsWith(receiptPrefix));
        const audits = prior.filter(a => a.id.startsWith(receiptPrefix + fingerprint + '-'));
        const byId = new Map(q.records.map(r => [r.studentId, r]));
        if (sameRoster(q.eligible) && audits.length === ids.length && q.eligible.every(id => {
            const a = audits.find(a => a.studentId === id), r = byId.get(id);
            return a && r && a.newStatus === r.status;
        }))
            return result(q, { alreadySaved: true, savedAt: Math.max(0, ...audits.map(a => Date.parse(a.changedAt) || 0)) });
        if (prior.length)
            throw Error('ATTENDANCE_ALREADY_FINALIZED');
    }
    if (q.session && q.session.status === 'RESET')
        throw Error('SESSION_CLOSED');
    if (!q.editable)
        throw Error({ CLOSED: 'QUICK_ATTENDANCE_DAY_EXPIRED', NOT_YET: 'OCCURRENCE_NOT_YET', ENDED: 'OCCURRENCE_ENDED', DAY_EXPIRED: 'QUICK_ATTENDANCE_DAY_EXPIRED', TOO_SHORT: 'OCCURRENCE_TOO_SHORT', RESET: 'SESSION_RESET_REQUIRES_DESKTOP' }[q.state] || 'INVALID_OCCURRENCE');
    if (d.expectedRevision !== q.revision)
        throw Error('ATTENDANCE_CONFLICT');
    if (!sameRoster(q.eligible))
        throw Error('ROSTER_CHANGED');
    const now = new Date().toISOString(), byId = new Map(q.records.map(r => [r.studentId, r])), changes = [];
    if (!q.session) {
        // Stage session, captured roster and results in one atomic Firestore transaction.
        const o = q.o, id = randomUUID(), closes = lab2Millis_(o.sessionDate, '00:00') + 86400000;
        q.session = { sessionId: id, classId: o.classId, date: o.sessionDate, slot: String(o.slot),
            startTime: o.scheduledStartTime, endTime: o.scheduledEndTime, status: 'CLOSED',
            currentToken: '', tokenExpiredAt: '', createdBy: actor.entity.lecturerId };
        changes.push({ table: 'Lab2SessionMeta', row: { sessionId: id, title: (o.subjectName || o.subjectId) + ' • Slot ' + o.slot,
                opensAt: q.now, closesAt: closes, lateThresholdAt: '', eligibleStudentIds: JSON.stringify(q.eligible) } });
    }
    const reason = q.completed ? 'Điều chỉnh điểm danh nhanh' : 'Điểm danh nhanh';
    for (const [index, id] of q.eligible.entries()) {
        const old = byId.get(id), provisional = q.provisional && old && old.note === 'Lab2 finalized';
        const status = wanted.get(id) || (old && !provisional ? (old.status === 'LATE' ? 'PRESENT' : old.status === 'EXCUSED' ? 'ABSENT' : old.status) : 'PRESENT');
        // Every confirmed student has a receipt, including unchanged results.
        changes.push({ table: 'AttendanceAudit', row: { id: receiptPrefix + fingerprint + '-' + index,
                sessionId: q.session.sessionId, studentId: id, actorUid, changedAt: now,
                oldStatus: old ? old.status : 'PENDING', newStatus: status, reason } });
        if (old && old.status === status)
            continue;
        changes.push({ table: 'Attendance', row: { ...old, attendanceId: old ? old.attendanceId : randomUUID(),
                sessionId: q.session.sessionId, studentId: id, status, checkInTime: old ? old.checkInTime : '',
                updatedAt: now, note: reason, updatedBy: actor.email } });
    }
    changes.push({ table: 'Lab2AttendanceCompletion', row: { sessionId: q.session.sessionId, status: 'CONFIRMED', confirmedAt: now, confirmedBy: actorUid } });
    changes.push({ table: 'Sessions', row: { ...q.session, status: 'CLOSED', currentToken: '', tokenExpiredAt: '' } });
    lab2Write_(book, changes);
    return result((await lab2QuickState_(book, actor, d)), { alreadySaved: false, savedAt: Date.parse(now) });
}
function portalAudit_(actor, classId, entityId, action, detail) {
    return { table: 'PortalAudit', row: { id: randomUUID(), classId, entityId, actor: actor.uid, action, at: new Date().toISOString(), detail: JSON.stringify(detail) } };
}
function portalTeacher_(actor) { if (actor.role !== 'lecturer')
    throw Error('PERMISSION_DENIED'); }
function portalStudent_(actor) { if (actor.role !== 'student')
    throw Error('PERMISSION_DENIED'); }
function portalKey_(value) {
    if (typeof value !== 'string' || !/^[A-Za-z0-9-]{16,80}$/.test(value))
        throw Error('INVALID_REQUEST_KEY');
    return value;
}
function portalVersion_(row, version) {
    if (!Number.isInteger(version) || Number(row.version) !== version)
        throw Error('VERSION_CONFLICT');
}
async function portalBook_(book, classId) {
    const r = (await sharedRowsWhere_(book, 'PortalGradebooks', 'classId', classId))[0];
    return r || { classId, components: '[]', version: '0', activePublicationId: '', updatedAt: '', updatedBy: '' };
}
async function portalRoster_(book, classId) {
    const ids = (await sharedRowsWhere_(book, 'Enrollments', 'classId', classId)).map(e => e.studentId);
    const students = (await sharedRowsById_(book, 'Students', ids));
    if (students.length > 400)
        throw Error('CLASS_TOO_LARGE');
    return students;
}
async function portalOccurrence_(book, actor, d) {
    const cls = (await lab2Class_(book, actor, String(d.classId || ''), false));
    const owner = { role: 'lecturer', entity: { lecturerId: cls.lecturerId } };
    return (await lab2ResolveOccurrence_(book, owner, d));
}
function portalSameOccurrence_(r, o) {
    return r.occurrenceId === o.occurrenceId && r.sessionDate === o.sessionDate && Number(r.slot) === o.slot && r.startTime === o.scheduledStartTime && r.endTime === o.scheduledEndTime;
}
async function portalLeaveViews_(book, rows) {
    if (!rows.length)
        return [];
    const tables = {};
    for (const name of ['Classes', 'Schedules', 'ScheduleExceptions', 'Students'])
        tables[name] = (await lab2Read_(book, name));
    const cache = new Map(), students = new Map(tables.Students.map(s => [s.studentId, s]));
    return (await mapAsync(rows, async (r) => {
        let scheduleChanged = true;
        const key = r.classId + '|' + r.sessionDate;
        if (!cache.has(key)) {
            const cls = tables.Classes.find(c => c.classId === r.classId);
            try {
                cache.set(key, (await lab2Occurrences_(book, { role: 'lecturer', entity: { lecturerId: cls.lecturerId } }, r.classId, r.sessionDate, tables)));
            }
            catch (_) {
                cache.set(key, []);
            }
        }
        const matches = cache.get(key).filter(o => o.occurrenceId === r.occurrenceId);
        if (matches.length === 1)
            scheduleChanged = !portalSameOccurrence_(r, matches[0]);
        const s = students.get(r.studentId);
        return { ...r, version: Number(r.version), fullName: s ? s.fullName : '', studentCode: s ? s.studentCode : '', scheduleChanged };
    }));
}
async function portalLeaveView_(book, r) { return (await portalLeaveViews_(book, [r]))[0]; }
async function portalApprovedForSession_(book, session) {
    if (!sharedHasTable_(book, 'PortalLeaveRequests'))
        return new Map();
    const candidates = (await lab2Read_(book, 'PortalLeaveRequests')).filter(r => r.classId === session.classId && r.sessionDate === session.date && String(r.slot) === String(session.slot) && r.status === 'APPROVED');
    const result = new Map();
    for (const r of (await portalLeaveViews_(book, candidates))) {
        if (!r.scheduleChanged)
            result.set(r.studentId, r);
    }
    return result;
}
function portalComponents_(values) {
    if (!Array.isArray(values) || values.length < 1 || values.length > 30)
        throw Error('INVALID_COMPONENTS');
    const ids = new Set(), names = new Set();
    return values.map((v, i) => {
        if (!v || typeof v.id !== 'string' || !/^[A-Za-z0-9_-]{1,80}$/.test(v.id) || ['__proto__', 'prototype', 'constructor'].includes(v.id) || ids.has(v.id) || typeof v.name !== 'string' || !v.name.trim() || v.name.trim().length > 100 || names.has(v.name.trim()) || typeof v.maxScore !== 'number' || !Number.isFinite(v.maxScore) || v.maxScore <= 0 || v.maxScore > 1000)
            throw Error('INVALID_COMPONENTS');
        ids.add(v.id);
        names.add(v.name.trim());
        return { id: v.id, name: v.name.trim(), maxScore: v.maxScore, order: i };
    });
}
function portalGrades_(grades, components) {
    if (!grades || typeof grades !== 'object' || Array.isArray(grades) || Object.keys(grades).some(k => !components.some(c => c.id === k)))
        throw Error('INVALID_GRADES');
    const result = {};
    for (const c of components) {
        const v = grades[c.id];
        if (v == null || v === '') {
            result[c.id] = '';
            continue;
        }
        if (typeof v !== 'number' || !Number.isFinite(v) || v < 0 || v > c.maxScore)
            throw Error('INVALID_GRADE_RANGE');
        result[c.id] = v;
    }
    return result;
}
async function portalCall_(book, actor, method, d) {
    if (!d || typeof d !== 'object' || Array.isArray(d))
        throw Error('INVALID_INPUT');
    if (['registerGroupPushDevice', 'unregisterGroupPushDevice'].includes(method))
        return (await groupPushDevice_(book, actor, d, method === 'unregisterGroupPushDevice'));
    if (['getGroupPlan', 'saveGroupPlan', 'getGroupMessages', 'sendGroupMessage', 'downloadGroupFile', 'ackGroupMessages', 'createGroupTask', 'listGroupTasks', 'listMyTaskNotifications', 'readTaskNotification'].includes(method))
        return (await groupCall_(book, actor, method, d));
    if (method === 'listClasses') {
        const enroll = actor.role === 'student' ? new Set((await lab2Read_(book, 'Enrollments')).filter(e => e.studentId === actor.entity.studentId).map(e => e.classId)) : null;
        return (await lab2Read_(book, 'Classes')).filter(c => enroll ? enroll.has(c.classId) : c.lecturerId === actor.entity.lecturerId);
    }
    if (method === 'listMyLeaveRequests') {
        portalStudent_(actor);
        return (await portalLeaveViews_(book, (await lab2Read_(book, 'PortalLeaveRequests')).filter(r => r.studentId === actor.entity.studentId)));
    }
    if (method === 'cancelLeaveRequest') {
        portalStudent_(actor);
        const r = (await lab2Read_(book, 'PortalLeaveRequests')).find(r => r.id === d.id && r.studentId === actor.entity.studentId);
        if (!r)
            throw Error('PERMISSION_DENIED');
        if (r.status === 'CANCELLED')
            return (await portalLeaveView_(book, r));
        portalVersion_(r, d.version);
        if (r.status !== 'PENDING' || Date.now() >= lab2Millis_(r.sessionDate, r.startTime))
            throw Error('LEAVE_TOO_LATE');
        const row = { ...r, status: 'CANCELLED', version: Number(r.version) + 1 };
        lab2Write_(book, [{ table: 'PortalLeaveRequests', row }, portalAudit_(actor, r.classId, r.id, 'CANCEL_LEAVE', { from: r.status, to: row.status })]);
        return (await portalLeaveView_(book, row));
    }
    if (method === 'applyApprovedLeave') {
        portalTeacher_(actor);
        const session = (await lab2Read_(book, 'Sessions')).find(s => s.sessionId === d.sessionId && s.status === 'CLOSED');
        if (!session)
            throw Error('SESSION_CLOSED_REQUIRED');
        (await lab2Class_(book, actor, session.classId, true));
        const eligible = (await lab2Meta_(book, session)).eligibleStudentIds || (await lab2Read_(book, 'Enrollments')).filter(e => e.classId === session.classId).map(e => e.studentId);
        if (!eligible.includes(d.studentId))
            throw Error('NOT_ENROLLED');
        const approved = (await portalApprovedForSession_(book, session)).get(d.studentId);
        if (!approved)
            throw Error('APPROVED_LEAVE_REQUIRED');
        const old = (await lab2Read_(book, 'Attendance')).find(a => a.sessionId === session.sessionId && a.studentId === d.studentId);
        // Do not overwrite attendance confirmed by a student or a manual correction.
        if (old && old.status === 'EXCUSED' && old.note === 'Approved leave: ' + approved.id)
            return { saved: true };
        if (old && !(old.status === 'ABSENT' && old.note === 'Lab2 finalized'))
            throw Error('MANUAL_CORRECTION_REQUIRED');
        (await lab2Correct_(book, actor, session, d.studentId, 'EXCUSED', 'Approved leave: ' + approved.id, old));
        return { saved: true };
    }
    const cls = (await lab2Class_(book, actor, String(d.classId || ''), false));
    if (method === 'listOccurrences') {
        const date = String(d.date || '');
        if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || new Date(lab2Millis_(date, '00:00') + 7 * 3600000).toISOString().slice(0, 10) !== date)
            throw Error('INVALID_SESSION_DATE');
        return (await lab2Occurrences_(book, { role: 'lecturer', entity: { lecturerId: cls.lecturerId } }, cls.classId, date)).filter(o => o.scheduledStartAt > Date.now());
    }
    if (method === 'submitLeaveRequest') {
        portalStudent_(actor);
        const key = portalKey_(d.requestKey);
        const rows = (await lab2Read_(book, 'PortalLeaveRequests'));
        const retry = rows.find(r => r.requestKey === key && r.studentId === actor.entity.studentId);
        if (retry)
            return (await portalLeaveView_(book, retry));
        const o = (await portalOccurrence_(book, actor, d)), reason = String(d.reason || '').trim();
        if (o.scheduledStartAt <= Date.now())
            throw Error('LEAVE_TOO_LATE');
        if (reason.length < 10 || reason.length > 1000)
            throw Error('INVALID_REASON');
        if (rows.some(r => r.studentId === actor.entity.studentId && r.occurrenceId === o.occurrenceId && ['PENDING', 'APPROVED'].includes(r.status)))
            throw Error('LEAVE_DUPLICATE');
        const row = { id: randomUUID(), classId: cls.classId, studentId: actor.entity.studentId, occurrenceId: o.occurrenceId, scheduleId: o.scheduleId, exceptionId: o.exceptionId,
            sessionDate: o.sessionDate, slot: o.slot, startTime: o.scheduledStartTime, endTime: o.scheduledEndTime, reason, status: 'PENDING', submittedAt: new Date().toISOString(), reviewedAt: '', reviewedBy: '', reviewNote: '', version: 1, requestKey: key };
        lab2Write_(book, [{ table: 'PortalLeaveRequests', row }, portalAudit_(actor, cls.classId, row.id, 'SUBMIT_LEAVE', { to: 'PENDING' })]);
        return (await portalLeaveView_(book, row));
    }
    if (method === 'listClassLeaveRequests') {
        portalTeacher_(actor);
        return (await portalLeaveViews_(book, (await lab2Read_(book, 'PortalLeaveRequests')).filter(r => r.classId === cls.classId && (!d.sessionDate || r.sessionDate === d.sessionDate) && (!d.slot || String(r.slot) === String(d.slot)))));
    }
    if (method === 'reviewLeaveRequest') {
        portalTeacher_(actor);
        const r = (await lab2Read_(book, 'PortalLeaveRequests')).find(r => r.id === d.id && r.classId === cls.classId);
        if (!r)
            throw Error('PERMISSION_DENIED');
        portalVersion_(r, d.version);
        if (r.status !== 'PENDING' || !['APPROVED', 'REJECTED'].includes(d.status))
            throw Error('INVALID_LEAVE_TRANSITION');
        const note = String(d.reviewNote || '').trim();
        if (note.length > 500 || (d.status === 'REJECTED' && !note))
            throw Error('INVALID_REASON');
        if (d.status === 'APPROVED' && (await portalLeaveView_(book, r)).scheduleChanged)
            throw Error('OCCURRENCE_CHANGED');
        const row = { ...r, status: d.status, reviewedAt: new Date().toISOString(), reviewedBy: actor.email, reviewNote: note, version: Number(r.version) + 1 };
        lab2Write_(book, [{ table: 'PortalLeaveRequests', row }, portalAudit_(actor, cls.classId, r.id, 'REVIEW_LEAVE', { from: r.status, to: row.status, note })]);
        return (await portalLeaveView_(book, row));
    }
    if (method === 'getMyPublishedGrades') {
        portalStudent_(actor);
        const state = (await portalBook_(book, cls.classId));
        if (!state.activePublicationId)
            return { published: false };
        const p = (await lab2Read_(book, 'PortalPublications')).find(p => p.id === state.activePublicationId && p.classId === cls.classId);
        if (!p)
            throw Error('INVALID_PUBLICATION_STATE');
        const row = (await lab2Read_(book, 'PortalPublishedGrades')).find(r => r.publicationId === p.id && r.studentId === actor.entity.studentId);
        if (!row)
            return { published: false };
        return { published: true, publicationId: p.id, publishedAt: p.publishedAt, version: Number(p.version), components: JSON.parse(p.components), grades: JSON.parse(row.grades), comment: row.comment };
    }
    portalTeacher_(actor);
    const state = (await portalBook_(book, cls.classId)), roster = (await portalRoster_(book, cls.classId));
    if (method === 'getGradebook') {
        const drafts = (await lab2Read_(book, 'PortalGradeDrafts')).filter(r => r.classId === cls.classId);
        return { ...state, version: Number(state.version), components: JSON.parse(state.components), students: roster.map(s => {
                const r = drafts.find(r => r.studentId === s.studentId);
                return { ...s, grades: r ? JSON.parse(r.grades) : {}, comment: r ? r.comment : '' };
            }) };
    }
    if (method === 'saveGradebook') {
        portalVersion_(state, d.version);
        const components = portalComponents_(d.components);
        if (!Array.isArray(d.students) || d.students.length !== roster.length || new Set(d.students.map(s => s.studentId)).size !== roster.length)
            throw Error('ROSTER_CHANGED');
        const changes = d.students.map(s => {
            if (!roster.some(r => r.studentId === s.studentId) || typeof s.comment !== 'string' || s.comment.length > 1000)
                throw Error('INVALID_INPUT');
            return { table: 'PortalGradeDrafts', row: { id: lab2Hash_(cls.classId + '|' + s.studentId), classId: cls.classId, studentId: s.studentId, grades: JSON.stringify(portalGrades_(s.grades, components)), comment: s.comment } };
        });
        changes.push({ table: 'PortalGradebooks', row: { ...state, components: JSON.stringify(components), version: Number(state.version) + 1, updatedAt: new Date().toISOString(), updatedBy: actor.email } }, portalAudit_(actor, cls.classId, cls.classId, 'SAVE_GRADES', { version: Number(state.version) + 1 }));
        lab2Write_(book, changes);
        return { saved: true, version: Number(state.version) + 1 };
    }
    if (method === 'publishGrades') {
        const key = portalKey_(d.requestKey), publications = (await lab2Read_(book, 'PortalPublications'));
        const retry = publications.find(p => p.classId === cls.classId && p.requestKey === key);
        if (retry)
            return { saved: true, publicationId: retry.id };
        portalVersion_(state, d.version);
        if (!Array.isArray(d.studentIds) || d.studentIds.length !== roster.length || new Set(d.studentIds).size !== roster.length || roster.some(s => !d.studentIds.includes(s.studentId)))
            throw Error('ROSTER_CHANGED');
        const components = portalComponents_(JSON.parse(state.components)), drafts = (await lab2Read_(book, 'PortalGradeDrafts')).filter(r => r.classId === cls.classId);
        if (!roster.length)
            throw Error('EMPTY_ROSTER');
        const id = randomUUID(), now = new Date().toISOString();
        const changes = roster.map(s => {
            const r = drafts.find(r => r.studentId === s.studentId);
            return { table: 'PortalPublishedGrades', row: { id: lab2Hash_(id + '|' + s.studentId), publicationId: id, studentId: s.studentId, grades: JSON.stringify(portalGrades_(r ? JSON.parse(r.grades) : {}, components)), comment: r ? r.comment : '' } };
        });
        changes.push({ table: 'PortalPublications', row: { id, classId: cls.classId, version: Number(state.version) + 1, components: JSON.stringify(components), publishedAt: now, publishedBy: actor.email, requestKey: key } }, { table: 'PortalGradebooks', row: { ...state, activePublicationId: id, version: Number(state.version) + 1, updatedAt: now, updatedBy: actor.email } }, portalAudit_(actor, cls.classId, id, 'PUBLISH_GRADES', { students: roster.length, version: Number(state.version) + 1 }));
        lab2Write_(book, changes);
        return { saved: true, publicationId: id };
    }
    if (method === 'revokeGrades') {
        portalVersion_(state, d.version);
        if (!state.activePublicationId)
            return { saved: true };
        lab2Write_(book, [{ table: 'PortalGradebooks', row: { ...state, activePublicationId: '', version: Number(state.version) + 1, updatedAt: new Date().toISOString(), updatedBy: actor.email } }, portalAudit_(actor, cls.classId, state.activePublicationId, 'REVOKE_GRADES', {})]);
        return { saved: true };
    }
    throw Error('UNKNOWN_PORTAL_METHOD');
}
async function lab2Occurrences_(book, actor, classId, date, tables) {
    const cls = tables ? tables.Classes.find(c => c.classId === classId) : (await lab2Class_(book, actor, classId, true)), weekday = lab2Day_(date);
    if (!cls || actor.role !== 'lecturer' || cls.lecturerId !== actor.entity.lecturerId)
        throw Error('PERMISSION_DENIED');
    const bases = (tables ? tables.Schedules : (await lab2Read_(book, 'Schedules'))).filter(s => s.lecturerId === actor.entity.lecturerId && s.semester === cls.semester && s.subjectCode === cls.subjectCode && s.classCode === cls.classCode);
    if (new Set(bases.map(s => s.scheduleId)).size !== bases.length)
        throw Error('OCCURRENCE_DUPLICATE');
    const exceptions = (tables ? tables.ScheduleExceptions : (await lab2Read_(book, 'ScheduleExceptions'))).filter(e => e.classId === cls.classId);
    const result = [];
    for (const base of bases) {
        const overrides = exceptions.filter(e => e.scheduleId === base.scheduleId && e.date === date && e.kind !== 'MAKEUP');
        if (overrides.length > 1)
            throw Error('OCCURRENCE_DUPLICATE');
        const change = overrides[0], rows = [];
        if (Number(base.dayOfWeek) === weekday && !['CANCELLED', 'RESCHEDULED'].includes(change && change.kind))
            rows.push({ row: change || base, exceptionId: change ? change.id : '' });
        for (const e of exceptions.filter(e => e.scheduleId === base.scheduleId && e.targetDate === date && ['RESCHEDULED', 'MAKEUP'].includes(e.kind)))
            rows.push({ row: e, exceptionId: e.id });
        for (const { row, exceptionId } of rows) {
            const slot = String(row.slot), start = String(row.startTime), end = String(row.endTime);
            if (!/^(?:[1-9]|1[0-2])$/.test(slot) || !/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(start) || !/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(end) || start === end)
                throw Error('INVALID_OCCURRENCE');
            const startAt = lab2Millis_(date, start), endAt = lab2Millis_(date, end) + (end < start ? 86400000 : 0);
            result.push({ occurrenceId: lab2Hash_([base.scheduleId, date, exceptionId].join('|')), scheduleId: base.scheduleId, exceptionId,
                classId: cls.classId, subjectId: cls.subjectCode, subjectName: cls.subjectName, classCode: cls.classCode, room: row.room || base.room || '',
                sessionDate: date, slot: Number(slot), scheduledStartTime: start, scheduledEndTime: end, scheduledStartAt: startAt, scheduledEndAt: endAt });
        }
    }
    return result;
}
async function lab2ResolveOccurrence_(book, actor, d) {
    const date = String(d.sessionDate || d.date || '');
    const matches = (await lab2Occurrences_(book, actor, String(d.classId || ''), date)).filter(o => (!d.occurrenceId || o.occurrenceId === d.occurrenceId) && (!d.scheduleId || o.scheduleId === d.scheduleId) && (d.exceptionId == null || o.exceptionId === d.exceptionId) && (!d.slot || o.slot === Number(d.slot)));
    if (matches.length > 1)
        throw Error('OCCURRENCE_DUPLICATE');
    if (!matches.length)
        throw Error('OCCURRENCE_NOT_FOUND');
    return matches[0];
}
async function lab2OccurrenceSession_(book, o) {
    const all = (await lab2Read_(book, 'Sessions')).filter(s => s.classId === o.classId && s.date === o.sessionDate && String(s.slot) === String(o.slot));
    const current = all.filter(s => s.status !== 'RESET');
    if (current.length > 1)
        throw Error('INVALID_DATABASE_IDS');
    let session = current[0];
    if (session && session.status === 'OPEN' && (await lab2Meta_(book, session)).closesAt <= Date.now()) {
        (await lab2Finalize_(book, session, true));
        session = (await lab2Read_(book, 'Sessions')).find(s => s.sessionId === session.sessionId);
    }
    return { session, resetOnly: !session && all.length > 0 };
}
async function lab2SessionReceipt_(book, session) {
    const meta = (await lab2Meta_(book, session));
    return { sessionId: session.sessionId, classSessionId: session.sessionId, attendanceSessionId: session.sessionId, status: session.status,
        opensAt: meta.opensAt, closesAt: meta.closesAt, effectiveDurationMinutes: (meta.closesAt - meta.opensAt) / 60000, serverTime: Date.now() };
}
function lab2OccurrenceState_(o, existing, now) {
    if (existing.session)
        return existing.session.status;
    if (existing.resetOnly)
        return 'RESET';
    const today = vietnamDate(now);
    if (o.sessionDate > today || now < o.scheduledStartAt - 15 * 60000)
        return 'NOT_YET';
    if (now >= o.scheduledEndAt)
        return 'ENDED';
    if (o.scheduledEndAt - now < 60000)
        return 'TOO_SHORT';
    return 'AVAILABLE';
}
async function lab2OccurrenceView_(book, actor, d) {
    {
        let o;
        try {
            o = (await lab2ResolveOccurrence_(book, actor, d));
        }
        catch (error) {
            // Historical sessions remain viewable even if their schedule was removed.
            if (error.message !== 'OCCURRENCE_NOT_FOUND' || !d.sessionId)
                throw error;
            const s = (await lab2Read_(book, 'Sessions')).find(s => s.sessionId === d.sessionId && s.classId === d.classId && s.date === (d.sessionDate || d.date) && String(s.slot) === String(d.slot));
            if (!s)
                throw error;
            const cls = (await lab2Class_(book, actor, s.classId, true));
            o = { classId: s.classId, sessionDate: s.date, slot: Number(s.slot), subjectId: cls.subjectCode, subjectName: cls.subjectName, classCode: cls.classCode,
                scheduledStartTime: s.startTime, scheduledEndTime: s.endTime, scheduledStartAt: lab2Millis_(s.date, s.startTime), scheduledEndAt: lab2Millis_(s.date, s.endTime) + (s.endTime < s.startTime ? 86400000 : 0), historical: true };
        }
        const existing = (await lab2OccurrenceSession_(book, o)), now = Date.now();
        const quickAttendanceAvailable = !existing.resetOnly && o.sessionDate === vietnamDate(now) &&
            (!existing.session || existing.session.status !== 'RESET');
        return { ...o, state: lab2OccurrenceState_(o, existing, now), serverTime: now, earliestOpenAt: o.scheduledStartAt - 15 * 60000,
            quickAttendanceAvailable, remainingMinutes: Math.max(0, (o.scheduledEndAt - now) / 60000), ...(existing.session ? (await lab2SessionReceipt_(book, existing.session)) : {}) };
    }
}
async function lab2CreateFromOccurrence_(book, actor, d, desktop = null, resetOld = null) {
    const duration = Number(d.durationMinutes == null ? 10 : d.durationMinutes);
    if (![5, 10, 15, 20, 30].includes(duration))
        throw Error('INVALID_INPUT');
    const o = (await lab2ResolveOccurrence_(book, actor, d)), existing = (await lab2OccurrenceSession_(book, o)), now = Date.now();
    if (existing.session && !resetOld)
        return { ...(await lab2SessionReceipt_(book, existing.session)), reused: true, occurrenceId: o.occurrenceId };
    const state = lab2OccurrenceState_(o, resetOld ? { session: null, resetOnly: false } : existing, now);
    if (state !== 'AVAILABLE')
        throw Error({ NOT_YET: 'OCCURRENCE_NOT_YET', ENDED: 'OCCURRENCE_ENDED', TOO_SHORT: 'OCCURRENCE_TOO_SHORT', RESET: 'SESSION_RESET_REQUIRES_DESKTOP' }[state] || 'INVALID_OCCURRENCE');
    const eligible = [...new Set((await lab2Read_(book, 'Enrollments')).filter(e => e.classId === o.classId).map(e => e.studentId))];
    if (eligible.length > 400)
        throw Error('CLASS_TOO_LARGE');
    const id = randomUUID(), closes = Math.min(now + duration * 60000, o.scheduledEndAt), token = randomUUID() + randomUUID();
    const row = { sessionId: id, classId: o.classId, date: o.sessionDate, slot: String(o.slot), startTime: o.scheduledStartTime, endTime: o.scheduledEndTime,
        status: 'OPEN', currentToken: desktop ? desktop.token + (desktop.secret ? '#' + desktop.secret : '') : token, tokenExpiredAt: new Date(desktop ? Math.min(closes, desktop.expiresAt) : closes).toISOString(), createdBy: actor.entity.lecturerId };
    const meta = { sessionId: id, title: (o.subjectName || o.subjectId) + ' • Slot ' + o.slot, opensAt: now, closesAt: closes, lateThresholdAt: '', eligibleStudentIds: JSON.stringify(eligible) };
    const changes = [{ table: 'Sessions', row }, { table: 'Lab2SessionMeta', row: meta }];
    if (resetOld)
        changes.unshift({ table: 'Sessions', row: { ...resetOld, status: 'RESET', currentToken: '', tokenExpiredAt: '' } });
    lab2Write_(book, changes);
    return { ...(await lab2SessionReceipt_(book, row)), reused: false, occurrenceId: o.occurrenceId };
}
function lab2Day_(text) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(text) || !Number.isFinite(Date.parse(text)) || new Date(text).toISOString().slice(0, 10) !== text)
        throw Error('INVALID_INPUT');
    return new Date(text).getUTCDay() || 7;
}
async function lab2SaveException_(book, actor, d) {
    if (actor.role !== 'lecturer')
        throw Error('PERMISSION_DENIED');
    const cls = (await lab2Class_(book, actor, d.classId, true));
    const schedules = (await lab2Read_(book, 'Schedules')), base = schedules.find(s => s.scheduleId === d.scheduleId && s.lecturerId === actor.entity.lecturerId && s.classCode === cls.classCode && s.subjectCode === cls.subjectCode && s.semester === cls.semester);
    if (!base)
        throw Error('PERMISSION_DENIED');
    const date = String(d.date || ''), kind = String(d.kind || ''), reason = String(d.reason || '').trim();
    if (lab2Day_(date) !== Number(base.dayOfWeek) || !['CANCELLED', 'RESCHEDULED', 'MAKEUP', 'ROOM_CHANGED', 'RESTORED'].includes(kind) || !reason || reason.length > 500)
        throw Error('INVALID_INPUT');
    const targetDate = ['RESCHEDULED', 'MAKEUP'].includes(kind) ? String(d.targetDate || '') : date;
    lab2Day_(targetDate);
    const slot = ['RESCHEDULED', 'MAKEUP'].includes(kind) ? String(d.slot) : base.slot;
    const start = ['RESCHEDULED', 'MAKEUP'].includes(kind) ? String(d.startTime) : base.startTime;
    const end = ['RESCHEDULED', 'MAKEUP'].includes(kind) ? String(d.endTime) : base.endTime;
    const room = kind === 'RESTORED' ? base.room : String(d.room || base.room).trim();
    if (!/^(?:[1-9]|1[0-2])$/.test(slot) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(start) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(end) || start === end || room.length > 100)
        throw Error('INVALID_INPUT');
    const id = lab2Hash_([base.scheduleId, date, kind === 'MAKEUP' ? targetDate + ':' + slot : 'override'].join('|'));
    const exceptions = (await lab2Read_(book, 'ScheduleExceptions')), previous = exceptions.find(e => e.id === id);
    const row = { id, scheduleId: base.scheduleId, classId: cls.classId, date, kind, targetDate, slot, startTime: start, endTime: end, room, reason, createdBy: actor.entity.lecturerId, updatedAt: new Date().toISOString() };
    const sessions = (await lab2Read_(book, 'Sessions')).filter(s => s.classId === cls.classId && s.status !== 'RESET');
    if (sessions.some(s => (kind !== 'MAKEUP' && s.date === date && s.slot === base.slot) || (s.date === targetDate && s.slot === slot) || (previous && s.date === previous.targetDate && s.slot === previous.slot)))
        throw Error('OCCURRENCE_HAS_SESSION');
    if (kind !== 'CANCELLED') {
        const from = lab2Millis_(targetDate, start), to = lab2Millis_(targetDate, end) + (end < start ? 86400000 : 0);
        const days = [-1, 0, 1].map(delta => new Date(Date.parse(targetDate) + delta * 86400000).toISOString().slice(0, 10));
        for (const otherClass of (await lab2Read_(book, 'Classes')).filter(c => c.lecturerId === actor.entity.lecturerId && c.semester === base.semester)) {
            for (const day of days)
                for (const o of (await lab2Occurrences_(book, actor, otherClass.classId, day))) {
                    if (o.exceptionId === id || (kind !== 'MAKEUP' && o.scheduleId === base.scheduleId && o.sessionDate === date))
                        continue;
                    if (from < o.scheduledEndAt && o.scheduledStartAt < to)
                        throw Error('SCHEDULE_CONFLICT');
                }
        }
    }
    lab2Write_(book, [{ table: 'ScheduleExceptions', row }]);
    return { saved: true, id };
}
async function lab2UpdateStudent_(book, actor, d) {
    const cls = (await lab2Class_(book, actor, d.classId, true)), id = String(d.studentUid || '').replace(/^student-/, '');
    const allowed = ['classId', 'studentUid', 'fullName', 'schoolEmail', 'reason'];
    if (Object.keys(d).some(k => !allowed.includes(k)))
        throw Error('INVALID_INPUT');
    const enrollments = (await lab2Read_(book, 'Enrollments')).filter(e => e.studentId === id), classes = (await lab2Read_(book, 'Classes'));
    if (!enrollments.some(e => e.classId === cls.classId))
        throw Error('NOT_ENROLLED');
    // Students is global, so a lecturer may not silently change another lecturer's shared profile.
    if (enrollments.some(e => !classes.some(c => c.classId === e.classId && c.lecturerId === actor.entity.lecturerId)))
        throw Error('SHARED_STUDENT_ADMIN_REQUIRED');
    const students = (await lab2Read_(book, 'Students')), old = students.find(s => s.studentId === id);
    if (!old)
        throw Error('INVALID_INPUT');
    const fullName = String(d.fullName || '').trim(), email = String(d.schoolEmail || '').trim().toLowerCase(), reason = String(d.reason || '').trim();
    if (!fullName || fullName.length > 200 || email.length > 200 || !reason || reason.length > 500 ||
        (email && (!/^[^\s@]+@[^\s@]+$/.test(email) || !config_().domains.includes(email.split('@')[1]))) ||
        (email && students.some(s => s.studentId !== id && String(s.schoolEmail).trim().toLowerCase() === email)))
        throw Error('INVALID_INPUT');
    if (old.fullName === fullName && old.schoolEmail === email)
        return { updated: true };
    const row = { ...old, fullName, schoolEmail: email };
    lab2Write_(book, [{ table: 'Students', row }, { table: 'RosterAudit', row: { id: randomUUID(), classId: cls.classId, studentId: id,
                actorUid: actor.firebaseUid || actor.uid, changedAt: new Date().toISOString(), oldValue: JSON.stringify(old), newValue: JSON.stringify(row), reason } }]);
    return { updated: true };
}
const CONTENT_SOURCES = [
    { sourceId: 'android', label: 'Android Developers', type: 'RSS', url: 'https://android-developers.googleblog.com/feeds/posts/default?alt=rss', enabled: 'true' },
    { sourceId: 'dotnet', label: '.NET Blog', type: 'RSS', url: 'https://devblogs.microsoft.com/dotnet/feed/', enabled: 'true' },
    { sourceId: 'webdev', label: 'web.dev', type: 'RSS', url: 'https://web.dev/feed.xml', enabled: 'true' },
    { sourceId: 'crossref', label: 'Crossref', type: 'CROSSREF', url: 'https://api.crossref.org/works', enabled: 'true' },
    { sourceId: 'openalex', label: 'OpenAlex', type: 'OPENALEX', url: 'https://api.openalex.org/works', enabled: 'true' },
];
async function contentSubjects_(book, actor) {
    if (actor.role !== 'lecturer')
        throw Error('PERMISSION_DENIED');
    return [...new Set((await lab2Read_(book, 'Classes')).filter(c => c.lecturerId === actor.entity.lecturerId).map(c => c.subjectCode))];
}
function contentList_(raw) {
    const value = JSON.parse(raw || '[]');
    if (!Array.isArray(value) || value.length > 20 || value.some(v => typeof v !== 'string' || v.length > 100))
        throw Error('INVALID_INPUT');
    return value;
}
async function subjectTopics_(book, actor, d) {
    if (!(await contentSubjects_(book, actor)).includes(d.subjectCode))
        throw Error('PERMISSION_DENIED');
    const row = (await lab2Read_(book, 'SubjectContentConfig')).find(r => r.subjectCode === d.subjectCode && r.enabled === 'true');
    return { subjectCode: d.subjectCode, configured: !!row, topics: row ? contentList_(row.topicKeywords) : [] };
}
function contentText_(value, limit = 500) {
    return String(value || '').replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '').replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, '')
        .replace(/<[^>]*>/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'")
        .replace(/\s+/g, ' ').trim().slice(0, limit);
}
function contentUrl_(url) {
    const match = String(url || '').match(/^https:\/\/([a-z0-9.-]+)(\/[^\s]*)?$/i);
    if (!match || match[1].includes('..') || !match[1].includes('.') || /^(localhost|127\.|10\.|192\.168\.|169\.254\.|172\.(1[6-9]|2\d|3[01])\.)/.test(match[1]))
        return null;
    return String(url).split('#')[0].replace(/([?&])utm_[^&]+(&?)/g, (_, a, b) => b ? a : '').replace(/[?&]$/, '');
}
function contentDate_(value) {
    const t = Date.parse(value);
    return Number.isFinite(t) ? new Date(t).toISOString() : null;
}
function contentImageUrl_(value) {
    const url = String(value || '').trim().replace(/&amp;/gi, '&');
    return url.length <= 1000 && /^https:\/\/[a-z0-9.-]+\.[a-z]{2,}(?:\/|$)/i.test(url) ? contentUrl_(url) : null;
}
async function contentFetch_(source, topics) {
    topics = topics.slice(0, 4).map(t => t.slice(0, 80));
    const approved = CONTENT_SOURCES.find(s => s.type === source.type && s.url === source.url);
    if (!approved)
        throw Error('SOURCE_NOT_APPROVED');
    let url = source.url;
    if (source.type === 'CROSSREF')
        url += '?rows=30&sort=published&order=desc&query=' + encodeURIComponent(topics.join(' '));
    if (source.type === 'OPENALEX') {
        const key = configValue('OPENALEX_API_KEY');
        if (!key)
            throw Error('OPENALEX_SETUP_REQUIRED');
        url += '?per-page=30&sort=publication_date:desc&search=' + encodeURIComponent(topics.map(t => '"' + t.replace(/"/g, '') + '"').join(' OR ')) + '&api_key=' + encodeURIComponent(key);
    }
    const response = (await fetchText(url, { muteHttpExceptions: true, followRedirects: false, timeoutSeconds: 10 }));
    if (response.getResponseCode() !== 200)
        throw Error('UPSTREAM_UNAVAILABLE');
    const text = response.getContentText();
    if (text.length > 1000000)
        throw Error('UPSTREAM_UNAVAILABLE');
    if (source.type === 'RSS')
        return contentRss_(text);
    const data = JSON.parse(text), items = source.type === 'CROSSREF' ? (data.message || {}).items : data.results;
    if (!Array.isArray(items))
        throw Error('UPSTREAM_UNAVAILABLE');
    return items.slice(0, 40).map(r => {
        const date = source.type === 'CROSSREF' ? ((r.published || {})['date-parts'] || [])[0] : null;
        const doi = String(r.DOI || r.doi || '').replace(/^https?:\/\/(?:dx\.)?doi.org\//i, '').toLowerCase();
        const image = Array.isArray(r.link) ? r.link.find(l => /^image\//i.test(l?.['content-type']) && contentImageUrl_(l.URL)) : null;
        return { title: Array.isArray(r.title) ? r.title[0] : r.display_name || r.title, doi, url: doi ? 'https://doi.org/' + doi : r.URL,
            imageUrl: image?.URL,
            publishedAt: date ? date.map((v, i) => i ? String(v).padStart(2, '0') : v).join('-') : r.publication_date,
            excerpt: lab2Abstract_(r), authors: source.type === 'CROSSREF' ? (r.author || []).slice(0, 10).map(a => [a.given, a.family].filter(Boolean).join(' ')) :
                (r.authorships || []).slice(0, 10).map(a => (a.author || {}).display_name).filter(Boolean) };
    });
}
function contentNormalize_(raw, source, config, type, now) {
    const title = contentText_(raw.title, 300), excerpt = contentText_(raw.excerpt, 450), url = contentUrl_(raw.url);
    if (!title || !url)
        return null;
    if (type === 'NEWS' && url.match(/^https:\/\/([^/]+)/)[1] !== source.url.match(/^https:\/\/([^/]+)/)[1])
        return null;
    const haystack = (title + ' ' + excerpt).toLowerCase(), topics = contentList_(config.topicKeywords), excludes = contentList_(config.excludeKeywords);
    const matched = topics.filter(t => haystack.includes(t.toLowerCase()));
    if (!matched.length || excludes.some(t => haystack.includes(t.toLowerCase())))
        return null;
    const doi = String(raw.doi || '').toLowerCase();
    const imageUrl = contentImageUrl_(raw.imageUrl);
    return { id: lab2Hash_(doi || url), contentType: type, title, canonicalUrl: url, url, doi, sourceName: source.label, source: source.label,
        ...(imageUrl ? { imageUrl } : {}),
        publishedAt: contentDate_(raw.publishedAt), fetchedAt: new Date(now).toISOString(), excerpt, abstractSnippet: excerpt,
        authors: (raw.authors || []).map(v => contentText_(v, 100)).slice(0, 10), subjectCodes: [config.subjectCode], subjectIds: [config.subjectCode],
        matchedTopics: matched, relevanceScore: matched.length };
}
async function contentFeed_(book, config, type) {
    const key = config.subjectCode + ':' + type, now = Date.now(), configVersion = lab2Hash_(JSON.stringify(config));
    const cacheRow = (await lab2Read_(book, 'SubjectContentCache')).find(r => r.id === key);
    let cached = null;
    try {
        cached = cacheRow ? JSON.parse(cacheRow.feed) : null;
    }
    catch (_) { /* rebuildable cache */ }
    if (cached && cached.configVersion !== configVersion)
        cached = null;
    if (cached && Number(cacheRow.expiresAt) > now)
        return cached;
    const selected = contentList_(config.sourceIds), topics = contentList_(config.topicKeywords);
    const sources = (await lab2Read_(book, 'ContentSourceRegistry')).filter(s => selected.includes(s.sourceId) && s.enabled === 'true' && (type === 'NEWS' ? s.type === 'RSS' : s.type !== 'RSS')).slice(0, 2);
    const failures = [], items = [];
    for (const source of sources) {
        try {
            for (const raw of (await contentFetch_(source, topics))) {
                const item = contentNormalize_(raw, source, config, type, now);
                if (item)
                    items.push(item);
            }
        }
        catch (_) {
            failures.push(source.label);
        }
    }
    if (failures.length === sources.length && sources.length && cached)
        return { ...cached, stale: true, partialSourcesFailed: failures };
    const unique = new Map();
    for (const item of items)
        if (!unique.has(item.id))
            unique.set(item.id, item);
    const normalized = [...unique.values()].sort((a, b) => (Date.parse(b.publishedAt) || 0) - (Date.parse(a.publishedAt) || 0)).slice(0, 24);
    const feed = { items: normalized, configVersion, sources: sources.map(s => s.label), lastUpdatedAt: sources.length && failures.length < sources.length ? new Date(now).toISOString() : null,
        stale: failures.length > 0, partialSourcesFailed: failures, configured: sources.length > 0 };
    while (JSON.stringify(feed).length > 45000 && feed.items.length)
        feed.items.pop();
    try {
        const rows = (await lab2Read_(book, 'SubjectContentCache'));
        if (!rows.some(r => r.id === key) && rows.length >= 400)
            throw Error('ARTICLE_CACHE_FULL');
        lab2Write_(book, [{ table: 'SubjectContentCache', row: { id: key, feed: JSON.stringify(feed), expiresAt: now + (failures.length ? 120000 : type === 'NEWS' ? 21600000 : 86400000) } }]);
    }
    catch (_) {
        return { ...feed, stale: true };
    }
    return feed;
}
async function subjectUpdates_(book, actor, d) {
    const allowed = (await contentSubjects_(book, actor)), code = String(d.subjectCode || '');
    if (!allowed.includes(code))
        throw Error('PERMISSION_DENIED');
    const type = d.type || 'NEWS', sort = d.sort || 'LATEST', limit = Number(d.limit || 20), days = Number(d.days || 0), query = String(d.query || '').trim().toLowerCase();
    if (!['NEWS', 'RESEARCH'].includes(type) || !['LATEST', 'RELEVANCE'].includes(sort) || !Number.isInteger(limit) || limit < 1 || limit > 20 || ![0, 7, 30, 90].includes(days) || query.length > 150)
        throw Error('INVALID_INPUT');
    const config = (await lab2Read_(book, 'SubjectContentConfig')).find(r => r.subjectCode === code && r.enabled === 'true');
    if (!config)
        return { items: [], configured: false, lastUpdatedAt: null, nextCursor: null, stale: false, partialSourcesFailed: [] };
    const feed = (await contentFeed_(book, config, type)), stamp = lab2Hash_(JSON.stringify([code, type, sort, days, query, d.source || '', feed.lastUpdatedAt])).slice(0, 16);
    let offset = 0;
    if (d.cursor) {
        const parts = String(d.cursor).split(':');
        if (parts.length !== 2 || parts[0] !== stamp || !/^\d+$/.test(parts[1]))
            throw Error('CONTENT_CHANGED');
        offset = Number(parts[1]);
        if (offset > 24)
            throw Error('INVALID_INPUT');
    }
    const items = feed.items.filter(i => (!days || (Date.parse(i.publishedAt) || 0) >= Date.now() - days * 86400000) &&
        (!query || (i.title + ' ' + i.excerpt).toLowerCase().includes(query)) && (!d.source || i.sourceName === d.source));
    items.sort((a, b) => sort === 'RELEVANCE' && a.relevanceScore !== b.relevanceScore ? b.relevanceScore - a.relevanceScore :
        (Date.parse(b.publishedAt) || 0) - (Date.parse(a.publishedAt) || 0) || a.id.localeCompare(b.id));
    return { ...feed, subjectCode: code, items: items.slice(offset, offset + limit), nextCursor: offset + limit < items.length ? stamp + ':' + (offset + limit) : null };
}
async function groupPlan_(book, classId) {
    const row = (await sharedRowsWhere_(book, 'PortalGroupPlans', 'classId', classId))[0];
    return row ? { ...row, version: Number(row.version), groups: JSON.parse(row.groups) } : { classId, version: 0, groups: [], requestKey: '' };
}
async function groupAccess_(book, actor, d) {
    (await lab2Class_(book, actor, String(d.classId || ''), false));
    const group = (await groupPlan_(book, d.classId)).groups.find(g => g.id === d.groupId);
    if (!group || actor.role !== 'lecturer' && !group.memberIds.includes(actor.entity.studentId))
        throw Error('GROUP_ACCESS_DENIED');
    return group;
}
async function groupCall_(book, actor, method, d) {
    if (!d || typeof d !== 'object' || Array.isArray(d))
        throw Error('INVALID_INPUT');
    if (['registerGroupPushDevice', 'unregisterGroupPushDevice'].includes(method))
        return (await groupPushDevice_(book, actor, d, method === 'unregisterGroupPushDevice'));
    if (['createGroupTask', 'listGroupTasks', 'listMyTaskNotifications', 'readTaskNotification'].includes(method))
        return (await groupTaskCall_(book, actor, method, d));
    (await lab2Class_(book, actor, String(d.classId || ''), false));
    const plan = (await groupPlan_(book, d.classId)), roster = (await portalRoster_(book, d.classId));
    if (method === 'getGroupPlan') {
        const groups = actor.role === 'lecturer' ? plan.groups : plan.groups.filter(g => g.memberIds.includes(actor.entity.studentId));
        const visible = new Set(groups.flatMap(g => g.memberIds));
        return { classId: d.classId, viewerId: actor.uid, version: plan.version, groups, students: roster.filter(s => actor.role === 'lecturer' || visible.has(s.studentId)).map(s => ({ studentId: s.studentId, studentCode: s.studentCode, fullName: s.fullName })) };
    }
    if (method === 'saveGroupPlan') {
        portalTeacher_(actor);
        const key = portalKey_(d.requestKey);
        if (plan.requestKey === key)
            return { saved: true, version: plan.version };
        if ((await firestoreRows_(book, 'PortalGroupSignups', null, [d.classId]))[0]?.state === 'OPEN')
            throw Error('GROUP_SIGNUP_OPEN');
        portalVersion_(plan, d.version);
        if (!Array.isArray(d.groups) || d.groups.length > 50)
            throw Error('INVALID_GROUPS');
        const used = new Set(), ids = new Set(), names = new Set(), oldIds = new Set(plan.groups.map(g => g.id));
        const history = (await lab2Read_(book, 'PortalGroupMessages'));
        const groups = d.groups.map(g => {
            if (!g || typeof g.id !== 'string' || !/^[A-Za-z0-9-]{16,80}$/.test(g.id) || ids.has(g.id) || typeof g.name !== 'string' || !g.name.trim() || g.name.trim().length > 80 || names.has(g.name.trim()) || !Array.isArray(g.memberIds))
                throw Error('INVALID_GROUPS');
            if (!oldIds.has(g.id) && history.some(m => m.groupId === g.id))
                throw Error('INVALID_GROUPS');
            ids.add(g.id);
            names.add(g.name.trim());
            for (const id of g.memberIds) {
                if (used.has(id) || !roster.some(s => s.studentId === id))
                    throw Error('INVALID_GROUP_MEMBERS');
                used.add(id);
            }
            return { id: g.id, name: g.name.trim(), memberIds: g.memberIds };
        });
        if (used.size !== roster.length)
            throw Error('ROSTER_CHANGED');
        const row = { classId: d.classId, groups: JSON.stringify(groups), version: plan.version + 1, updatedAt: new Date().toISOString(), updatedBy: actor.uid, requestKey: key };
        if (row.groups.length > 45000)
            throw Error('INVALID_GROUPS');
        lab2Write_(book, [{ table: 'PortalGroupPlans', row }, portalAudit_(actor, d.classId, d.classId, 'SAVE_GROUP_PLAN', { version: row.version, groups: groups.length })]);
        return { saved: true, version: row.version };
    }
    const group = (await groupAccess_(book, actor, d));
    const rows = (await sharedRowsWhere_(book, 'PortalGroupMessages', 'groupId', d.groupId)).filter(m => m.classId === d.classId);
    if (method === 'ackGroupMessages') {
        if (!sharedHasTable_(book, 'PortalGroupReceipts'))
            throw Error('GROUP_RECEIPTS_SETUP_REQUIRED');
        const delivered = d.deliveredIds || [], read = d.readIds || [];
        if (!Array.isArray(delivered) || !Array.isArray(read) || delivered.length > 50 || read.length > 50 || [...delivered, ...read].some(id => typeof id !== 'string' || !rows.some(m => m.id === id)))
            throw Error('INVALID_RECEIPTS');
        const id = lab2Hash_(d.classId + '|' + d.groupId + '|' + actor.uid), stored = (await sharedRowsWhere_(book, 'PortalGroupReceipts', 'id', id))[0];
        const receipts = stored ? JSON.parse(stored.receipts) : {}, now = new Date().toISOString();
        let changed = false;
        for (const messageId of new Set([...delivered, ...read])) {
            if (rows.find(m => m.id === messageId).sender === actor.uid)
                continue;
            const old = receipts[messageId] || { deliveredAt: '', readAt: '' };
            const next = { deliveredAt: old.deliveredAt || now, readAt: old.readAt || (read.includes(messageId) ? now : '') };
            if (old.deliveredAt !== next.deliveredAt || old.readAt !== next.readAt) {
                receipts[messageId] = next;
                changed = true;
            }
        }
        // Bound each actor/group record to the most recent 200 messages (one document).
        const kept = {};
        for (const m of rows.slice(-200))
            if (receipts[m.id])
                kept[m.id] = receipts[m.id];
        if (changed)
            lab2Write_(book, [{ table: 'PortalGroupReceipts', row: { id, classId: d.classId, groupId: d.groupId, actor: actor.uid, receipts: JSON.stringify(kept) } }]);
        return { saved: true };
    }
    if (method === 'getGroupMessages') {
        const before = d.before ? rows.findIndex(m => m.id === d.before) : rows.length;
        if (before < 0)
            throw Error('INVALID_CURSOR');
        const start = Math.max(0, before - 50);
        const tracking = sharedHasTable_(book, 'PortalGroupReceipts');
        const members = new Set(group.memberIds.filter(id => roster.some(s => s.studentId === id)).map(id => 'student-' + id));
        const receipts = tracking ? (await sharedRowsWhere_(book, 'PortalGroupReceipts', 'groupId', d.groupId)).filter(r => r.classId === d.classId && members.has(r.actor)).map(r => ({ actor: r.actor, receipts: JSON.parse(r.receipts) })) : [];
        return { viewerId: actor.uid, receiptTracking: tracking, messages: rows.slice(start, before).map(({ requestKey, fileId, ...m }) => {
                const mine = m.sender === actor.uid, result = { ...m, mine, size: Number(m.size), hasFile: !!fileId };
                if (mine) {
                    const received = receipts.filter(r => r.actor !== actor.uid && r.receipts[m.id]?.deliveredAt), seen = received.filter(r => r.receipts[m.id].readAt);
                    result.delivery = { deliveredCount: received.length, readCount: seen.length, recipientCount: [...members].filter(id => id !== actor.uid).length,
                        deliveredAt: received.map(r => r.receipts[m.id].deliveredAt).sort()[0] || null, readAt: seen.map(r => r.receipts[m.id].readAt).sort()[0] || null };
                }
                return result;
            }), older: start > 0 ? rows[start].id : null };
    }
    if (method === 'downloadGroupFile') {
        const message = rows.find(m => m.id === d.messageId && m.fileId);
        if (!message)
            throw Error('GROUP_ACCESS_DENIED');
        const bytes = await book.readAttachment(message.fileId);
        return { name: message.fileName, mimeType: message.mimeType, base64: bytes.toString("base64") };
    }
    if (method === 'sendGroupMessage') {
        const key = portalKey_(d.requestKey), existing = rows.find(m => m.sender === actor.uid && m.requestKey === key);
        if (existing)
            return { saved: true, id: existing.id, createdAt: existing.createdAt };
        const text = typeof d.text === 'string' ? d.text.trim() : '';
        if (text.length > 2000 || (!text && !d.file))
            throw Error('INVALID_MESSAGE');
        let fileId = "", name = '', mime = '', size = 0;
        if (d.file) {
            const f = d.file, allowed = { 'pdf': 'application/pdf', 'txt': 'text/plain', 'png': 'image/png', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'csv': 'text/csv' };
            if (typeof f.name !== 'string' || !f.name || f.name.length > 120 || /[\x00-\x1f\\/]/.test(f.name) || typeof f.base64 !== 'string' || f.base64.length > 682668 || !/^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(f.base64))
                throw Error('INVALID_FILE');
            name = f.name;
            mime = allowed[name.split('.').pop().toLowerCase()];
            if (!mime)
                throw Error('INVALID_FILE');
            const bytes = Buffer.from(f.base64, "base64");
            size = bytes.length;
            if (size < 1 || size > 512000)
                throw Error('FILE_TOO_LARGE');
            fileId = "firebase-" + lab2Hash_(d.classId + "|" + d.groupId + "|" + actor.uid + "|" + key);
            book.storeAttachment(fileId, bytes);
        }
        const row = { id: randomUUID(), classId: d.classId, groupId: d.groupId, sender: actor.uid, senderName: actor.entity.fullName || 'Thành viên', text, fileId, fileName: name, mimeType: mime, size, createdAt: new Date().toISOString(), requestKey: key };
        // Keep file on uncertain batch failure: retry may find committed receipt.
        lab2Write_(book, [{ table: 'PortalGroupMessages', row }]);
        return { saved: true, id: row.id, createdAt: row.createdAt,
            _groupPush: { classId: row.classId, groupId: row.groupId } };
    }
    throw Error('FEATURE_DISABLED');
}
function groupTasksReady_(book) {
    for (const name of ['PortalGroupTasks', 'PortalTaskNotifications']) {
        if (!sharedHasTable_(book, name))
            throw Error('GROUP_TASKS_SETUP_REQUIRED');
    }
}
async function groupTaskVisible_(book, actor, task, notification) {
    if (!task || !notification || notification.studentId !== actor.entity.studentId)
        return false;
    try {
        (await groupAccess_(book, actor, { classId: task.classId, groupId: task.groupId }));
        return true;
    }
    catch (_) {
        return false;
    }
}
async function groupTaskReceipt_(book, task) {
    const rows = (await sharedRowsWhere_(book, 'PortalTaskNotifications', 'taskId', task.id));
    return { id: task.id, recipientCount: rows.length, readCount: rows.filter(n => n.readAt).length,
        emailSentCount: rows.filter(n => n.emailStatus === 'SENT').length,
        emailPendingCount: rows.filter(n => n.emailStatus === 'PENDING').length,
        emailReviewCount: rows.filter(n => ['SENDING', 'UNKNOWN'].includes(n.emailStatus)).length,
        emailSkippedCount: rows.filter(n => n.emailStatus === 'SKIPPED').length };
}
async function groupTaskCall_(book, actor, method, d) {
    groupTasksReady_(book);
    if (method === 'listMyTaskNotifications' || method === 'readTaskNotification') {
        portalStudent_(actor);
        const tasks = (await lab2Read_(book, 'PortalGroupTasks')), mine = (await sharedRowsWhere_(book, 'PortalTaskNotifications', 'studentId', actor.entity.studentId));
        const classes = (await lab2Read_(book, 'Classes'));
        const visible = await filterAsync(mine, n => groupTaskVisible_(book, actor, tasks.find(t => t.id === n.taskId), n));
        if (method === 'readTaskNotification') {
            const row = visible.find(n => n.id === d.notificationId);
            if (!row)
                throw Error('GROUP_ACCESS_DENIED');
            const readAt = row.readAt || new Date().toISOString();
            if (!row.readAt)
                lab2Write_(book, [{ table: 'PortalTaskNotifications', row: { ...row, readAt } }]);
            return { saved: true, readAt };
        }
        const ordered = visible.sort((a, b) => b.createdAt.localeCompare(a.createdAt) || b.id.localeCompare(a.id));
        const start = d.before ? ordered.findIndex(n => n.id === d.before) + 1 : 0;
        if (d.before && start === 0)
            throw Error('INVALID_CURSOR');
        const page = ordered.slice(start, start + 50);
        return { unreadCount: visible.filter(n => !n.readAt).length, older: start + 50 < ordered.length ? page[page.length - 1].id : null,
            notifications: page.map(n => {
                const t = tasks.find(t => t.id === n.taskId), cls = classes.find(c => c.classId === t.classId);
                return { id: n.id, readAt: n.readAt, createdAt: n.createdAt,
                    task: { id: t.id, classId: t.classId, classCode: cls.classCode, subjectCode: cls.subjectCode, groupId: t.groupId, groupName: t.groupName, title: t.title, description: t.description, dueAt: t.dueAt } };
            }) };
    }
    portalTeacher_(actor);
    (await lab2Class_(book, actor, String(d.classId || ''), false));
    const tasks = (await lab2Read_(book, 'PortalGroupTasks')).filter(t => t.classId === d.classId);
    if (method === 'listGroupTasks') {
        return { tasks: await mapAsync(tasks.filter(t => !d.groupId || t.groupId === d.groupId).reverse(), async t => {
                const { requestKey, fingerprint, ...view } = t;
                return { ...view, ...(await groupTaskReceipt_(book, t)) };
            }) };
    }
    const key = portalKey_(d.requestKey);
    const title = typeof d.title === 'string' ? d.title.trim() : '', description = typeof d.description === 'string' ? d.description.trim() : '';
    const fingerprint = lab2Hash_(JSON.stringify([d.groupId, title, description, d.dueAt]));
    const retry = tasks.find(t => t.requestKey === key && t.createdBy === actor.uid);
    if (retry) {
        if (retry.fingerprint !== fingerprint)
            throw Error('REQUEST_KEY_CONFLICT');
        return { saved: true, ...(await groupTaskReceipt_(book, retry)) };
    }
    const plan = (await groupPlan_(book, d.classId));
    portalVersion_(plan, d.version);
    const group = (await groupAccess_(book, actor, d)), roster = (await portalRoster_(book, d.classId));
    if (!title || title.length > 160 || !description || description.length > 4000 || /[\r\n]/.test(title))
        throw Error('INVALID_TASK');
    if (typeof d.dueAt !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(d.dueAt) || !Number.isFinite(Date.parse(d.dueAt)) || new Date(d.dueAt).toISOString() !== d.dueAt || Date.parse(d.dueAt) <= Date.now())
        throw Error('INVALID_TASK_DEADLINE');
    const members = roster.filter(s => group.memberIds.includes(s.studentId));
    if (!members.length)
        throw Error('EMPTY_GROUP');
    if (members.length !== group.memberIds.length)
        throw Error('ROSTER_CHANGED');
    const domains = config_().domains;
    const emails = members.map(s => String(s.schoolEmail || '').trim().toLowerCase());
    if (emails.some(email => !/^[a-z0-9._%+-]+@[a-z0-9.-]+$/.test(email) || !domains.includes(email.split('@')[1])) || new Set(emails).size !== emails.length)
        throw Error('GROUP_MEMBER_EMAIL_INVALID');
    const now = new Date().toISOString(), id = randomUUID();
    const task = { id, classId: d.classId, groupId: group.id, groupName: group.name, title, description, dueAt: d.dueAt, createdAt: now, createdBy: actor.uid, requestKey: key, fingerprint };
    const notifications = members.map((s, i) => ({ table: 'PortalTaskNotifications', row: { id: lab2Hash_(id + '|' + s.studentId), taskId: id, classId: d.classId, groupId: group.id, studentId: s.studentId, email: emails[i], createdAt: now, readAt: '', emailStatus: 'PENDING', emailSentAt: '' } }));
    lab2Write_(book, [{ table: 'PortalGroupTasks', row: task }, ...notifications, portalAudit_(actor, d.classId, id, 'CREATE_GROUP_TASK', { groupId: group.id, recipientCount: members.length })]);
    return { saved: true, id, recipientCount: members.length, readCount: 0, emailSentCount: 0, emailPendingCount: members.length, emailReviewCount: 0, emailSkippedCount: 0 };
}
async function groupPushDevice_(book, actor, d, remove) {
    if (!actor.firebaseUid)
        throw Error('PERMISSION_DENIED');
    if (!['android', 'web'].includes(d.platform) || typeof d.token !== 'string' ||
        !/^[A-Za-z0-9_:\-]{20,4096}$/.test(d.token))
        throw Error('INVALID_FCM_TOKEN');
    if (actor.role !== (d.platform === 'android' ? 'lecturer' : 'student'))
        throw Error('PERMISSION_DENIED');
    if (!sharedHasTable_(book, 'PortalGroupPushDevices')) {
        if (remove)
            return { enabled: false };
        throw Error('GROUP_PUSH_SETUP_REQUIRED');
    }
    const table = 'PortalGroupPushDevices', rows = (await lab2Read_(book, table));
    const id = lab2Hash_(actor.uid + '|' + d.platform);
    const old = rows.find(r => r.id === id);
    if (remove) {
        if (old && old.firebaseUid === actor.firebaseUid && old.token === d.token) {
            lab2Write_(book, [{ table, row: { ...old, token: '' } }]);
        }
        return { enabled: false };
    }
    const changes = rows.filter(r => r.id !== id && r.token === d.token)
        .map(row => ({ table, row: { ...row, token: '' } }));
    changes.push({ table, row: { id, actor: actor.uid, firebaseUid: actor.firebaseUid,
            platform: d.platform, token: d.token, updatedAt: new Date().toISOString() } });
    lab2Write_(book, changes);
    return { enabled: true };
}


async function dispatch(book, request) {
    const action = request.action;
    if (action === "portalCall") {
        let actor;
        if (request.firebaseAuth === true) {
            const matches = await sharedIdentityRows_(book, "Students", book.identity.email);
            if (matches.length !== 1) throw Error("PROFILE_NOT_REGISTERED");
            actor = { ...book.identity, role: "student", entity: matches[0], uid: "student-" + matches[0].studentId };
        } else {
            actor = { ...lab2DesktopActor_(await authenticate_(null, config_(), book)), firebaseUid: book.identity.firebaseUid };
        }
        return book.pushAfterCommit(actor, await portalCall_(book, actor, String(request.method || ""), request.data || {}));
    }
    if (["lab2Health", "lab2Snapshot", "lab2Call"].includes(action)) return lab2Handle_(book, request);
    if (action === "studentCodeSessionInfo" && configValue("ALLOW_VERIFIED_STUDENT_CODE") !== "true")
        throw Error("FEATURE_DISABLED");
    if (action === "studentSessionInfo" || action === "studentCodeSessionInfo") return handleStudentSession_(book, request);
    if (action === "studentCheckIn" || action === "studentCodeCheckIn")
        return handleStudentCheckIn_(book, request, action === "studentCodeCheckIn");
    return handle_(book, request);
}
async function pushRecipients(book, actor, event) {
    const cls = await lab2Class_(book, actor, event.classId, false);
    const group = await groupAccess_(book, actor, event);
    const roster = new Set((await portalRoster_(book, event.classId)).map(row => row.studentId));
    const ids = ["lecturer-" + cls.lecturerId, ...group.memberIds.filter(id => roster.has(id)).map(id => "student-" + id)]
        .filter(id => id !== actor.uid);
    const devices = await sharedRowsWhere_(book, "PortalGroupPushDevices", "actor", ids);
    return devices.filter(row => row.token && Date.parse(row.updatedAt) > Date.now() - 30 * 86400000);
}
async function reconcileTaskMail(book) {
    const pending = (await sharedRowsWhere_(book, "PortalTaskNotifications", "emailStatus", ["PENDING", "SENDING"])).slice(0, 30);
    const tasks = await sharedRowsById_(book, "PortalGroupTasks", pending.map(row => row.taskId));
    const students = await sharedRowsById_(book, "Students", pending.map(row => row.studentId));
    for (const row of pending) {
        const delivery = await book.mailDelivery(row.id);
        let status = row.emailStatus;
        if (delivery) {
            if (delivery.state === "SUCCESS") status = "SENT";
            else if (delivery.state === "ERROR") status = "UNKNOWN";
            else status = "SENDING";
        } else if (row.emailStatus === "SENDING") {
            // A legacy send may have already happened before the old job stopped.
            status = "UNKNOWN";
        } else {
            const task = tasks.find(entry => entry.id === row.taskId);
            const student = students.find(entry => entry.studentId === row.studentId);
            const actor = { role: "student", entity: { studentId: row.studentId }, uid: "student-" + row.studentId };
            if (!student || student.schoolEmail.trim().toLowerCase() !== row.email ||
                !await groupTaskVisible_(book, actor, task, row)) {
                status = "SKIPPED";
            } else {
                const deadline = new Intl.DateTimeFormat("vi-VN", {
                    timeZone: "Asia/Ho_Chi_Minh", dateStyle: "short", timeStyle: "short",
                }).format(new Date(task.dueAt));
                book.queueMail(row.id, row.email, "[FAP] Giao việc: " + task.title,
                    task.groupName + " được giao việc: " + task.title + "\n\n" + task.description +
                    "\n\nHạn hoàn thành (giờ Việt Nam): " + deadline +
                    "\n\nĐăng nhập Student Web → Việc được giao. https://fap-sinhvien.web.app/");
                status = "SENDING";
            }
        }
        if (status !== row.emailStatus) lab2Write_(book, [{
            table: "PortalTaskNotifications",
            row: { ...row, emailStatus: status, emailSentAt: status === "SENT" ? new Date().toISOString() : "" },
        }]);
    }
}

module.exports = { dispatch, reconcileExpiredSessions, reconcileTaskMail, pushRecipients, lab2Health_ };
