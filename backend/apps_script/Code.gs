/* Member 1 API. Never trust lecturerId/email supplied by a desktop client. */
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

function config_() {
  const p = PropertiesService.getScriptProperties();
  const id = p.getProperty('SPREADSHEET_ID');
  const audience = p.getProperty('GOOGLE_CLIENT_ID');
  if (!id || !audience) throw new Error('Máy chủ chưa cấu hình SPREADSHEET_ID / GOOGLE_CLIENT_ID.');
  return {id, audience, mobileAudience: p.getProperty('GOOGLE_MOBILE_CLIENT_ID') || '', webAudience: p.getProperty('GOOGLE_WEB_CLIENT_ID') || '', domains: (p.getProperty('SCHOOL_DOMAINS') || 'fpt.edu.vn,fe.edu.vn').split(',').map(s => s.trim().toLowerCase())};
}

/** Run manually as spreadsheet owner, never exposed through doPost. */
function setupSheets() {
  const book = SpreadsheetApp.openById(config_().id);
  Object.keys(SCHEMA).forEach(name => {
    const sheet = book.getSheetByName(name) || book.insertSheet(name);
    if (sheet.getLastRow() === 0) {
      sheet.getRange(1, 1, 1, SCHEMA[name].length).setValues([SCHEMA[name]]).setFontWeight('bold');
      sheet.setFrozenRows(1);
    }
    read_(book, name); // Stop on unexpected header rather than overwriting it.
  });
}

function read_(book, name) {
  if (!Object.prototype.hasOwnProperty.call(SCHEMA, name)) throw new Error('Sheet không được hỗ trợ.');
  const sheet = book.getSheetByName(name);
  if (!sheet) throw new Error('Thiếu sheet ' + name + '. Chạy setupSheets.');
  const range = sheet.getDataRange();
  const values = range.getDisplayValues();
  const raw = typeof range.getValues === 'function' ? range.getValues() : values;
  if (name === 'Sessions') values.slice(1).forEach((row, index) => {
    const date = raw[index + 1][2];
    if (Object.prototype.toString.call(date) === '[object Date]') {
      row[2] = Utilities.formatDate(date, 'Asia/Ho_Chi_Minh', 'yyyy-MM-dd');
    } else {
      const match = String(row[2]).match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
      if (match) row[2] = match[3] + '-' + match[2].padStart(2, '0') + '-' + match[1].padStart(2, '0');
    }
    if (Object.prototype.toString.call(raw[index + 1][8]) === '[object Date]') row[8] = raw[index + 1][8].toISOString();
    row[6] = String(row[6]).trim().toUpperCase();
  });
  const headers = SCHEMA[name];
  if (JSON.stringify(values[0]) !== JSON.stringify(headers)) throw new Error('Sai cấu trúc cột: ' + name);
  const rows = values.slice(1).filter(row => row.some(v => v !== '')).map(row =>
    Object.fromEntries(headers.map((h, i) => [h, row[i] || ''])));
  const ids = rows.map(r => r[headers[0]]);
  if (ids.some(id => !id) || new Set(ids).size !== ids.length) throw new Error('ID trống hoặc trùng trong ' + name);
  return {sheet, rows};
}

function authenticate_(idToken, cfg, book) {
  if (typeof idToken !== 'string' || idToken.length < 20 || idToken.length > 10000) throw new Error('Cần đăng nhập Google.');
  // Google validates the signature. Check audience, issuer, expiry and verified email here.
  const response = UrlFetchApp.fetch('https://oauth2.googleapis.com/tokeninfo?id_token=' + encodeURIComponent(idToken), {muteHttpExceptions: true});
  if (response.getResponseCode() !== 200) throw new Error('Phiên Google không hợp lệ. Đăng nhập lại.');
  const claims = JSON.parse(response.getContentText());
  const email = String(claims.email || '').trim().toLowerCase();
  const parts = email.split('@');
  if (![cfg.audience, cfg.mobileAudience].filter(Boolean).includes(claims.aud) || !['accounts.google.com', 'https://accounts.google.com'].includes(claims.iss) ||
      Number(claims.exp) <= Date.now() / 1000 || !Number.isFinite(Number(claims.exp)) ||
      ![true, 'true'].includes(claims.email_verified) || parts.length !== 2 || !parts[0] || !cfg.domains.includes(parts[1])) {
    throw new Error('Tài khoản Google không được phép truy cập.');
  }
  const matches = read_(book, 'Lecturers').rows.filter(r => r.email.trim().toLowerCase() === email);
  if (matches.length !== 1) throw new Error('Email chưa có trong Lecturers hoặc hồ sơ bị trùng. Liên hệ trưởng nhóm.');
  return matches[0];
}

function validateSchedule_(input, lecturer) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new Error('Dòng lịch không hợp lệ.');
  const row = {};
  SCHEMA.Schedules.forEach(key => {
    if (typeof input[key] !== 'string' && typeof input[key] !== 'number') throw new Error('Thiếu trường ' + key);
    row[key] = String(input[key]).trim();
    if (!row[key] || row[key].length > 300) throw new Error('Trường trống hoặc quá dài: ' + key);
  });
  if (row.lecturerId !== lecturer.lecturerId) throw new Error('Không được sửa lịch giảng viên khác.');
  ['semester', 'subjectCode', 'classCode'].forEach(k => row[k] = row[k].toUpperCase());
  if (!/^[A-Z]{2,6}\d{3}[A-Z0-9]*$/.test(row.subjectCode)) throw new Error('Mã môn không hợp lệ.');
  if (!/^[1-7]$/.test(row.dayOfWeek) || !/^(?:[1-9]|1[0-2])$/.test(row.slot)) throw new Error('Thứ hoặc slot không hợp lệ.');
  const time = /^(?:[01]\d|2[0-3]):[0-5]\d$/;
  if (!time.test(row.startTime) || !time.test(row.endTime) || row.startTime === row.endTime) throw new Error('Giờ học không hợp lệ.');
  if (!['MANUAL', 'IMAGE'].includes(row.sourceType)) throw new Error('Nguồn lịch không hợp lệ.');
  return row;
}

/** Pure transformation: validates the complete batch before a single atomic write. */
function mutateSchedules_(existing, action, request, lecturer) {
  const result = existing.map(r => ({...r}));
  const index = new Map(result.map((r, i) => [r.scheduleId, i]));
  if (action === 'deleteRow') {
    const i = index.get(request.id);
    if (i === undefined) throw new Error('Không tìm thấy lịch.');
    if (result[i].lecturerId !== lecturer.lecturerId) throw new Error('Không được xóa lịch giảng viên khác.');
    result.splice(i, 1);
    return result;
  }
  const inputs = action === 'batchUpdate' ? request.rows : [request.row];
  if (!Array.isArray(inputs) || inputs.length < 1 || inputs.length > 100) throw new Error('Batch phải có 1–100 dòng.');
  const rows = inputs.map(r => validateSchedule_(r, lecturer));
  if (new Set(rows.map(r => r.scheduleId)).size !== rows.length) throw new Error('Trùng ID trong batch.');
  rows.forEach(row => {
    const i = index.get(row.scheduleId);
    if (i !== undefined && result[i].lecturerId !== lecturer.lecturerId) throw new Error('Không được sửa lịch giảng viên khác.');
    if (action === 'appendRow' && i !== undefined) throw new Error('ID lịch đã tồn tại.');
    if (action === 'updateRow' && (i === undefined || request.id !== row.scheduleId)) throw new Error('ID cập nhật không khớp.');
    if (i === undefined) { index.set(row.scheduleId, result.length); result.push(row); }
    else result[i] = row;
  });
  const signatures = new Set();
  for (const row of result) {
    const signature = [row.lecturerId, row.semester, row.subjectCode, row.classCode, row.dayOfWeek, row.slot, row.startTime, row.endTime].join('|');
    if (signatures.has(signature)) throw new Error('Lịch dạy bị trùng. Kiểm tra lại các dòng trước khi lưu.');
    signatures.add(signature);
  }
  return result;
}

function writeSchedules_(cfg, sheet, rows, lecturer, action) {
  const columns = SCHEMA.Schedules;
  const count = Math.max(sheet.getLastRow(), rows.length + 1);
  const requests = [];
  if (count > sheet.getMaxRows()) requests.push({appendDimension: {sheetId: sheet.getSheetId(), dimension: 'ROWS', length: count - sheet.getMaxRows()}});
  requests.push({updateCells: {
    range: {sheetId: sheet.getSheetId(), startRowIndex: 1, endRowIndex: count, startColumnIndex: 0, endColumnIndex: columns.length},
    rows: rows.map(row => ({values: columns.map(key => ({userEnteredValue: {stringValue: String(row[key])}}))})),
    fields: 'userEnteredValue'
  }});
  // stringValue avoids formulas even when a room/name starts with '='.
  const logs = SpreadsheetApp.openById(cfg.id).getSheetByName('SyncLogs');
  if (!logs) throw new Error('Thiếu SyncLogs. Chạy setupSheets.');
  requests.push({appendCells: {sheetId: logs.getSheetId(), fields: 'userEnteredValue', rows: [{values:
    [Utilities.getUuid(), action, lecturer.email, new Date().toISOString(), 'Schedules: ' + rows.length + ' rows after mutation']
      .map(value => ({userEnteredValue: {stringValue: value}}))}]}});
  Sheets.Spreadsheets.batchUpdate({requests}, cfg.id);
}

function handleSession_(book, cfg, lecturer, request) {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(15000)) throw new Error('Máy chủ đang bận. Thử lại sau.');
  try {
    const sessions = read_(book, 'Sessions');
    if(request.classId) lab2Class_(book,lab2DesktopActor_(lecturer),String(request.classId).trim(),true);
    if(request.sessionId) {
      const target=sessions.rows.find(s=>s.sessionId===request.sessionId);
      if(!target) throw new Error('PERMISSION_DENIED');
      lab2Class_(book,lab2DesktopActor_(lecturer),target.classId,true);
    }
    if (request.action === 'resetSession') {
      const oldIndex = sessions.rows.findIndex(row => row.sessionId === request.sessionId);
      const old = sessions.rows[oldIndex];
      if (!old || old.createdBy !== lecturer.lecturerId) throw new Error('Không có quyền reset phiên này.');
      const successors = sessions.rows.filter(row => row.sessionId !== old.sessionId && row.classId === old.classId && row.date === old.date && row.slot === old.slot && row.status !== 'RESET');
      if(successors.length>1) throw Error('INVALID_SHEET_IDS');
      const successor=successors[0];
      if (old.status === 'RESET' && successor) {
        if(successor.status==='OPEN'&&lab2Meta_(book,successor).closesAt<=Date.now()) lab2Finalize_(book,successor,true);
        const current=lab2Read_(book,'Sessions').find(s=>s.sessionId===successor.sessionId);
        return {...sessionView_(current),...lab2SessionReceipt_(book,current)};
      }
      if (old.status === 'RESET') throw new Error('Phiên đã reset. Tải lại danh sách phiên.');
      if (successor) throw new Error('Buổi học đang có nhiều phiên. Kiểm tra trước khi reset.');
      const receipt=lab2CreateFromOccurrence_(book,lab2DesktopActor_(lecturer),{classId:old.classId,sessionDate:old.date,slot:old.slot,durationMinutes:10},
        {token:Utilities.getUuid(),secret:'',expiresAt:Date.now()+120000},old);
      return {...sessionView_(lab2Read_(book,'Sessions').find(s=>s.sessionId===receipt.sessionId)),...receipt};
    }

    if (request.action === 'createSession') {
      const classId = String(request.classId || '').trim();
      const slot = String(request.slot || '').trim();
      const date = String(request.date || '').trim();
      const token = String(request.currentToken || '').trim();
      const secret = String(request.currentSecretCode || '').trim();
      const expiredAt = String(request.tokenExpiredAt || '').trim();

      if(!classId||!date||!slot||!token||token.length>256||(secret&&!/^\d{6}$/.test(secret))||!Number.isFinite(Date.parse(expiredAt))||Date.parse(expiredAt)<=Date.now()) throw Error('INVALID_INPUT');
      const receipt=lab2CreateFromOccurrence_(book,lab2DesktopActor_(lecturer),{classId,sessionDate:date,slot,durationMinutes:request.durationMinutes==null?10:request.durationMinutes},
        {token,secret,expiresAt:Date.parse(expiredAt)});
      return {...sessionView_(lab2Read_(book,'Sessions').find(s=>s.sessionId===receipt.sessionId)),
        opensAt:receipt.opensAt,closesAt:receipt.closesAt,effectiveDurationMinutes:receipt.effectiveDurationMinutes};
    }

    if (request.action === 'rotateToken') {
      const sessionId = String(request.sessionId || '').trim();
      const token = String(request.currentToken || '').trim();
      const secret = String(request.currentSecretCode || '').trim();
      const expiredAt = String(request.tokenExpiredAt || '').trim();

      const index = sessions.rows.findIndex(r => r.sessionId === sessionId);
      if (index === -1) throw new Error('Không tìm thấy phiên điểm danh.');
      if (sessions.rows[index].createdBy !== lecturer.lecturerId) throw new Error('Không có quyền sửa phiên điểm danh này.');
      if (sessions.rows[index].status !== 'OPEN') throw new Error('Phiên không còn mở.');
      lab2Class_(book,lab2DesktopActor_(lecturer),sessions.rows[index].classId,true);
      const meta=lab2Meta_(book,sessions.rows[index]);
      if(Date.now()>=meta.closesAt||!token||token.length>256||(secret&&!/^\d{6}$/.test(secret))||
        !Number.isFinite(Date.parse(expiredAt))||Date.parse(expiredAt)<=Date.now()) throw new Error('INVALID_INPUT');

      const combinedToken = secret ? (token + '#' + secret) : token;
      lab2Write_(book,[{table:'Sessions',row:{...sessions.rows[index],currentToken:combinedToken,
        tokenExpiredAt:new Date(Math.min(Date.parse(expiredAt),meta.closesAt)).toISOString()}}]);
      return {saved: true};
    }

    if (request.action === 'closeSession') {
      const sessionId = String(request.sessionId || '').trim();
      const index = sessions.rows.findIndex(r => r.sessionId === sessionId);
      if (index === -1) throw new Error('Không tìm thấy phiên điểm danh.');
      if (sessions.rows[index].createdBy !== lecturer.lecturerId) throw new Error('Không có quyền kết thúc phiên điểm danh này.');
      if (sessions.rows[index].status === 'RESET') throw new Error('Phiên này đã được thay thế. Tải lại phiên hiện tại.');

      if(typeof lab2Finalize_ !== 'function') throw new Error('SHARED_BACKEND_SETUP_REQUIRED');
      lab2Class_(book,lab2DesktopActor_(lecturer),sessions.rows[index].classId,true);
      lab2Finalize_(book,sessions.rows[index]);
      return {closed: true};
    }

    if (request.action === 'getSessionAttendance') {
      const sessionId = String(request.sessionId || '').trim();
      if (!sessions.rows.some(s => s.sessionId === sessionId && s.createdBy === lecturer.lecturerId)) throw new Error('Không có quyền đọc phiên.');
      const attendance = read_(book, 'Attendance').rows.filter(r => r.sessionId === sessionId);
      const students = read_(book, 'Students').rows;
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
      if (!targetId) return [];
      for(const s of sessions.rows.filter(r=>String(r.classId).trim().toUpperCase()===targetId&&r.status==='OPEN')) {
        if(lab2Meta_(book,s).closesAt<=Date.now()) lab2Finalize_(book,s,true);
      }
      return lab2Read_(book,'Sessions').filter(r => {
        const rowClassId = String(r.classId || '').trim().toUpperCase();
        if (!rowClassId) return false;
        const matchesLecturer = (r.createdBy === lecturer.lecturerId || !r.createdBy);
        const matchesClass = rowClassId === targetId && r.status !== 'RESET';
        return matchesLecturer && matchesClass;
      }).map(r=>({...r,...lab2SessionReceipt_(book,r)}));
    }

    if (request.action === 'getClassHistory') {
      const classId = String(request.classId || '').trim();
      const classSessions = sessions.rows.filter(r => r.classId === classId && r.createdBy === lecturer.lecturerId && r.status !== 'RESET');
      const sessionIds = new Set(classSessions.map(s => s.sessionId));
      const attendance = read_(book, 'Attendance').rows.filter(r => sessionIds.has(r.sessionId));
      const students = read_(book, 'Students').rows;
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
      return read_(book, 'Classes').rows.filter(r => r.lecturerId === lecturerId);
    }

    if (request.action === 'updateAttendance') {
      const attendanceId = String(request.attendanceId || '').trim();
      const status = String(request.status || '').trim().toUpperCase();
      const note = String(request.note || '').trim();
      const updatedBy = lecturer.email;
      const nowIso = new Date().toISOString();

      const attendance = read_(book, 'Attendance');
      const index = attendance.rows.findIndex(r => r.attendanceId === attendanceId);
      if (index === -1) throw new Error('Không tìm thấy bản ghi điểm danh.');

      const owned = sessions.rows.find(s => s.sessionId === attendance.rows[index].sessionId && s.createdBy === lecturer.lecturerId && s.status !== 'RESET');
      if (!owned || !['PRESENT', 'LATE', 'ABSENT', 'EXCUSED'].includes(status)) throw new Error('Không có quyền sửa bản ghi hoặc trạng thái không hợp lệ.');
      if(typeof lab2Correct_ !== 'function') throw new Error('SHARED_BACKEND_SETUP_REQUIRED');
      lab2Correct_(book,lab2DesktopActor_(lecturer),owned,attendance.rows[index].studentId,status,note,attendance.rows[index]);
      return {saved: true};
    }

    if (request.action === 'markAbsent') {
      const sessionId = String(request.sessionId || '').trim();
      const studentCodes = Array.isArray(request.studentCodes) ? request.studentCodes : [];
      const markedBy = lecturer.email;
      const owned = sessions.rows.find(s => s.sessionId === sessionId && s.createdBy === lecturer.lecturerId && s.status === 'CLOSED');
      if (!owned) throw new Error('Chỉ chốt vắng cho phiên đã đóng của bạn.');
      lab2Class_(book,lab2DesktopActor_(lecturer),owned.classId,true);
      const frozen=lab2Meta_(book,owned).eligibleStudentIds;
      const enrollmentIds = new Set(frozen||read_(book, 'Attendance').rows.filter(e=>e.sessionId===owned.sessionId).map(e=>e.studentId));
      const nowIso = new Date().toISOString();

      const attendance = read_(book, 'Attendance');
      const students = read_(book, 'Students').rows;
      const studentMap = new Map(students.map(s => [s.studentCode, s]));

      const newRows = [];
      studentCodes.forEach(code => {
        const student = studentMap.get(code);
        if (student && enrollmentIds.has(student.studentId)) {
          const already = attendance.rows.some(a => a.sessionId === sessionId && a.studentId === student.studentId);
          if (!already) {
            const newRecord = {
              attendanceId: Utilities.getUuid(),
              sessionId: sessionId,
              studentId: student.studentId,
              status: 'ABSENT',
              checkInTime: '',
              updatedAt: nowIso,
              note: 'Chốt vắng tự động khi kết thúc phiên',
              updatedBy: markedBy
            };
            newRows.push(SCHEMA.Attendance.map(k => String(newRecord[k] || '')));
          }
        }
      });

      if (newRows.length > 0) {
        attendance.sheet.getRange(attendance.sheet.getLastRow() + 1, 1, newRows.length, SCHEMA.Attendance.length).setValues(newRows);
      }
      return {saved: true, count: newRows.length};
    }

    throw new Error('Thao tác session chưa được hỗ trợ.');
  } finally { lock.releaseLock(); }
}

function sessionView_(session) {
  const [currentToken, currentSecretCode = ''] = String(session.currentToken || '').split('#');
  return {...session, currentToken, currentSecretCode};
}

function authenticateStudent_(idToken, cfg, book) {
  if (!cfg.webAudience) throw new Error('Máy chủ chưa cấu hình GOOGLE_WEB_CLIENT_ID.');
  if (typeof idToken !== 'string' || idToken.length < 20 || idToken.length > 10000) throw new Error('Vui lòng đăng nhập email trường.');
  const response = UrlFetchApp.fetch('https://oauth2.googleapis.com/tokeninfo?id_token=' + encodeURIComponent(idToken), {muteHttpExceptions: true});
  if (response.getResponseCode() !== 200) throw new Error('Phiên Google không hợp lệ. Đăng nhập lại.');
  const claims = JSON.parse(response.getContentText());
  const email = String(claims.email || '').trim().toLowerCase();
  // `hd` is the Google Workspace primary domain, which can differ from the
  // domain of a verified alias used by a student (for example an FPT alias).
  // Requiring both domains to match rejects legitimate roster accounts. The
  // verified email domain and the exact, unique roster match below are the
  // authoritative checks for student access.
  if (claims.aud !== cfg.webAudience || !['accounts.google.com', 'https://accounts.google.com'].includes(claims.iss) ||
      !Number.isFinite(Number(claims.exp)) || Number(claims.exp) <= Date.now()/1000 ||
      ![true, 'true'].includes(claims.email_verified) || !cfg.domains.includes(email.split('@')[1])) throw new Error('Chỉ tài khoản Google email trường đã xác minh được phép điểm danh.');
  const matches = read_(book, 'Students').rows.filter(s => String(s.schoolEmail).trim().toLowerCase() === email);
  if (matches.length !== 1) throw new Error('Email trường chưa có trong danh sách sinh viên hoặc đang bị trùng. Liên hệ giảng viên.');
  return matches[0];
}
// Mobile-created sessions keep an explicit deadline and frozen roster.
// Apply these checks on the public web path too, before showing or recording a lesson.
function assertMobileQrSession_(book, session, request, student) {
  const sheet = book.getSheetByName('Lab2SessionMeta');
  if (!sheet) return;
  const values = sheet.getDataRange().getDisplayValues();
  const header = values[0] || [], id = header.indexOf('sessionId');
  const row = values.slice(1).find(r => r[id] === session.sessionId);
  if (!row) return; // Desktop legacy behavior stays in its own handler.
  const deadline = Number(row[header.indexOf('closesAt')]);
  const expiry = Date.parse(session.tokenExpiredAt), view = sessionView_(session);
  if (!Number.isFinite(deadline) || Date.now() >= deadline || !Number.isFinite(expiry) || Date.now() >= expiry)
    throw new Error('Phiên điểm danh đã hết hạn. Quét mã của phiên mới.');
  if (!view.currentToken || String(request.token || '') !== view.currentToken)
    throw new Error('Mã QR đã thay đổi. Quét mã mới đang hiển thị.');
  if (student) {
    let eligible;
    try { eligible = JSON.parse(row[header.indexOf('eligibleStudentIds')]); } catch (_) { throw new Error('Không đọc được danh sách phiên. Liên hệ giảng viên.'); }
    if (!Array.isArray(eligible) || !eligible.includes(student.studentId))
      throw new Error('Sinh viên không thuộc danh sách lớp tại thời điểm mở phiên.');
  }
}
function authenticateFirebaseStudent_(idToken, cfg, book) {
  if (typeof lab2FirebaseIdentity_ !== 'function') throw new Error('Máy chủ chưa cập nhật xác thực Firebase.');
  const identity = lab2FirebaseIdentity_(idToken);
  if (!cfg.domains.includes(identity.email.split('@')[1])) throw new Error('Chỉ tài khoản Google email trường được phép điểm danh.');
  const matches = read_(book, 'Students').rows.filter(s => String(s.schoolEmail).trim().toLowerCase() === identity.email);
  if (matches.length !== 1) throw new Error('Email trường chưa có trong danh sách sinh viên hoặc đang bị trùng. Liên hệ giảng viên.');
  return matches[0];
}
function studentContext_(request, cfg, book, byCode = false, verifiedStudent = null) {
  let student;
  if (byCode) {
    // Legacy route can only be used with verified Google identity, even when enabled.
    if(PropertiesService.getScriptProperties().getProperty('ALLOW_VERIFIED_STUDENT_CODE')!=='true')
      throw new Error('Điểm danh bằng MSSV đã tắt. Đăng nhập Google hoặc liên hệ giảng viên.');
    const verified=verifiedStudent||(request.firebaseAuth===true?authenticateFirebaseStudent_(request.idToken,cfg,book):authenticateStudent_(request.idToken,cfg,book));
    const code = String(request.studentCode || '').trim().toUpperCase();
    if (!/^[A-Z0-9]{5,20}$/.test(code)) throw new Error('Vui lòng nhập MSSV hợp lệ.');
    const matches = read_(book, 'Students').rows.filter(s => String(s.studentCode).trim().toUpperCase() === code);
    if (matches.length !== 1) throw new Error('MSSV chưa có hoặc bị trùng trong danh sách sinh viên.');
    student = matches[0];
    if(student.studentId!==verified.studentId) throw new Error('MSSV không thuộc tài khoản đã xác minh.');
  } else student = verifiedStudent || (request.firebaseAuth === true ? authenticateFirebaseStudent_(request.idToken, cfg, book) : authenticateStudent_(request.idToken, cfg, book));
  const session = read_(book, 'Sessions').rows.find(s => s.sessionId === request.sessionId);
  if (!session) throw new Error('Phiên điểm danh không tồn tại.');
  if (session.status !== 'OPEN') throw new Error('Phiên đã kết thúc hoặc được reset. Quét mã mới.');
  assertMobileQrSession_(book, session, request, student);
  if (!read_(book, 'Enrollments').rows.some(e => e.classId === session.classId && e.studentId === student.studentId)) throw new Error('Sinh viên không thuộc danh sách lớp của buổi học này.');
  const cls = read_(book, 'Classes').rows.find(c => c.classId === session.classId);
  if (!cls) throw new Error('Không tìm thấy lớp học.');
  return {student, session, cls};
}
function handleStudentSession_(request) {
  const cfg = config_(), book = SpreadsheetApp.openById(cfg.id);
  const {student, session, cls} = studentContext_(request, cfg, book);
  return {student: {fullName: student.fullName, studentCode: student.studentCode, email: student.schoolEmail},
    session: {sessionId: session.sessionId, classCode: cls.classCode, subjectCode: cls.subjectCode,
      date: session.date, slot: session.slot, startTime: session.startTime, endTime: session.endTime,
      secretEnabled: !!sessionView_(session).currentSecretCode}};
}
function handleStudentCodeSession_(request) {
  if(PropertiesService.getScriptProperties().getProperty('ALLOW_VERIFIED_STUDENT_CODE')!=='true')
    throw new Error('Điểm danh bằng MSSV đã tắt. Đăng nhập Google hoặc liên hệ giảng viên.');
  return handleStudentSession_(request);
}
function legacyStudentCodeSessionView_(request) {
  const book = SpreadsheetApp.openById(config_().id);
  const session = read_(book, 'Sessions').rows.find(s => s.sessionId === request.sessionId);
  if (!session) throw new Error('Phiên điểm danh không tồn tại.');
  if (session.status !== 'OPEN') throw new Error('Phiên đã kết thúc hoặc được reset. Quét mã mới.');
  assertMobileQrSession_(book, session, request);
  const view = sessionView_(session);
  
  
  const cls = read_(book, 'Classes').rows.find(c => c.classId === session.classId);
  if (!cls) throw new Error('Không tìm thấy lớp học.');
  return {session: {classCode: cls.classCode, subjectCode: cls.subjectCode, date: session.date,
    slot: session.slot, startTime: session.startTime, endTime: session.endTime,
    secretEnabled: !!view.currentSecretCode}, checkInMode: 'student-code-v2'};
}
function handleStudentCheckIn_(request, byCode = false) {
  if (request.confirmPresent !== true) throw new Error('Bạn phải xác nhận đang có mặt trong lớp để điểm danh.');
  const cfg = config_(), book = SpreadsheetApp.openById(cfg.id);
  if(byCode&&PropertiesService.getScriptProperties().getProperty('ALLOW_VERIFIED_STUDENT_CODE')!=='true')
    throw new Error('Điểm danh bằng MSSV đã tắt. Đăng nhập Google hoặc liên hệ giảng viên.');
  // Verify over the network before acquiring the write lock; reread session/roster inside it.
  const verified=request.firebaseAuth===true?authenticateFirebaseStudent_(request.idToken,cfg,book):authenticateStudent_(request.idToken,cfg,book);
  lab2Limit_(verified.studentId,'studentCheckIn');
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(15000)) throw new Error('Hệ thống đang bận. Thử lại.');
  try {
    const {student, session} = studentContext_(request, cfg, book, byCode, verified);
    const view = sessionView_(session);
    const expires = new Date(session.tokenExpiredAt).getTime();
    if (!byCode && (!Number.isFinite(expires) || Date.now() >= expires)) throw new Error('Mã điểm danh đã hết hạn. Quét mã mới hoặc nhập Secret Code hiện tại.');
    if (view.currentSecretCode) {
      if (String(request.secretCode || '') !== view.currentSecretCode) throw new Error('Giảng viên đang bật Secret Code. Nhập mã hiện tại hoặc quét lại QR.');
    } else if (!byCode) {
      if (request.useSecret === true) throw new Error('Secret Code chưa được bật. Quét lại mã QR.');
      if (!view.currentToken || String(request.token || '') !== view.currentToken) throw new Error('Mã QR không hợp lệ hoặc đã thay đổi. Quét mã mới.');
    }
    const attendance = read_(book, 'Attendance');
    const previous=attendance.rows.filter(a=>a.sessionId===session.sessionId&&a.studentId===student.studentId);
    if(previous.length>1) throw new Error('INVALID_SHEET_IDS');
    if(previous.length) {
      if(!['PRESENT','LATE'].includes(previous[0].status)) throw new Error('Điểm danh đã được giảng viên điều chỉnh. Liên hệ giảng viên.');
      return {status:previous[0].status,checkInTime:previous[0].checkInTime,studentCode:student.studentCode,fullName:student.fullName,alreadyRecorded:true};
    }
    const nowIso = new Date().toISOString();
    const record = {attendanceId: Utilities.getUuid(), sessionId: session.sessionId, studentId: student.studentId,
      status: 'PRESENT', checkInTime: nowIso, updatedAt: nowIso,
      note: byCode ? 'Student code; presence confirmed' : 'Google verified; presence confirmed',
      updatedBy: byCode ? student.studentCode : student.schoolEmail};
    lab2Write_(book,[{table:'Attendance',row:record}]);
    return {status: record.status, checkInTime: nowIso, studentCode: student.studentCode, fullName: student.fullName};
  } finally { lock.releaseLock(); }
}

function handle_(request) {
  const cfg = config_();
  const book = SpreadsheetApp.openById(cfg.id);
  const lecturer = authenticate_(request.idToken, cfg, book);
  if (request.action === 'profile') return lecturer;
  if (['getRoster', 'importRoster'].includes(request.action)) {
    return handleRoster_(book, cfg, lecturer, request);
  }
  if (['resetSession', 'createSession', 'rotateToken', 'closeSession', 'getSessionAttendance', 'getSessionsByClass', 'getClassHistory', 'updateAttendance', 'markAbsent', 'getLecturerClasses'].includes(request.action)) {
    return handleSession_(book, cfg, lecturer, request);
  }
  if (request.action === 'getRows') {
    if (!['Lecturers', 'Schedules', 'Classes', 'Sessions', 'Attendance'].includes(request.sheet)) throw new Error('Module này chưa được cấp quyền đọc.');
    return read_(book, request.sheet).rows.filter(r => r.lecturerId === lecturer.lecturerId || r.createdBy === lecturer.lecturerId);
  }
  if (request.sheet !== 'Schedules' || !['appendRow', 'updateRow', 'deleteRow', 'batchUpdate'].includes(request.action)) {
    throw new Error('Thao tác chưa được hỗ trợ. Không có generic write cho sheet khác.');
  }
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(15000)) throw new Error('Máy chủ đang bận. Thử lại sau.');
  try {
    const current = read_(book, 'Schedules');
    const rows = mutateSchedules_(current.rows, request.action, request, lecturer);
    writeSchedules_(cfg, current.sheet, rows, lecturer, request.action);
    return {saved: true};
  } finally { lock.releaseLock(); }
}

function rosterTarget_(request, classes, schedules, lecturer) {
  const fields = ['semester', 'subjectCode', 'classCode'];
  const target = Object.fromEntries(fields.map(k => [k, String(request[k] || '').trim().toUpperCase()]));
  if (fields.some(k => !target[k] || target[k].length > 100)) throw new Error('Thiếu học kỳ, môn hoặc mã lớp.');
  const matches = r => r.lecturerId === lecturer.lecturerId && fields.every(k => String(r[k]).trim().toUpperCase() === target[k]);
  const found = classes.filter(matches);
  if (found.length > 1) throw new Error('Trùng khóa lớp. Cần xử lý trước khi nhập sinh viên.');
  const schedule = schedules.find(matches);
  if (!found.length && !schedule) throw new Error('Lớp không thuộc lịch dạy của bạn.');
  return {...target, lecturerId: lecturer.lecturerId, classId: found[0]?.classId || '', subjectName: found[0]?.subjectName || schedule?.subjectName || ''};
}

/** Pure, idempotent roster import. Never removes enrollments or overwrites a shared student. */
function importRoster_(request, state, lecturer, uuid) {
  const target = rosterTarget_(request, state.classes, state.schedules, lecturer);
  if (!Array.isArray(request.students) || !request.students.length || request.students.length > 1000) throw new Error('Nhập từ 1 đến 1.000 sinh viên mỗi lần.');
  const students = state.students.map(s => ({...s}));
  const classes = state.classes.map(c => ({...c}));
  const enrollments = state.enrollments.map(e => ({...e}));
  const codes = new Map();
  for (const s of students) {
    const code = String(s.studentCode).trim().toUpperCase();
    if (codes.has(code)) throw new Error('Mã sinh viên trùng trong hệ thống. Cần xử lý trước khi nhập.');
    codes.set(code, s);
  }
  if (!target.classId) {
    target.classId = uuid();
    classes.push({...target});
  }
  const enrolled = new Set(enrollments.filter(e => e.classId === target.classId).map(e => e.studentId));
  let added = 0, existing = 0;
  const seen = new Map();
  for (const input of request.students) {
    if (!input || typeof input !== 'object') throw new Error('Dòng sinh viên không hợp lệ.');
    const code = String(input.studentCode || '').trim().toUpperCase();
    const fullName = String(input.fullName || '').trim();
    const schoolEmail = String(input.schoolEmail || '').trim().toLowerCase();
    if (String(input.classCode || '').trim().toUpperCase() !== target.classCode) throw new Error('Mã lớp trong file không khớp lớp đích.');
    if (!/^[A-Z0-9][A-Z0-9._-]{1,39}$/.test(code) || !fullName || fullName.length > 200 || schoolEmail.length > 254 ||
        (schoolEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(schoolEmail))) throw new Error('Mã sinh viên, họ tên hoặc email không hợp lệ.');
    const signature = JSON.stringify([fullName, schoolEmail]);
    if (seen.has(code) && seen.get(code) !== signature) throw new Error('Một mã sinh viên có nhiều thông tin khác nhau trong file.');
    seen.set(code, signature);
    let student = codes.get(code);
    if (student && String(student.fullName).trim().toLowerCase().replace(/\s+/g, ' ') !== fullName.toLowerCase().replace(/\s+/g, ' ')) {
      throw new Error('Họ tên không khớp mã sinh viên ' + code + ' đã có. Kiểm tra lại file.');
    }
    if (!student) {
      student = {studentId: uuid(), studentCode: code, fullName, schoolEmail};
      students.push(student); codes.set(code, student);
    }
    if (enrolled.has(student.studentId)) { existing++; continue; }
    enrollments.push({enrollmentId: uuid(), classId: target.classId, studentId: student.studentId});
    enrolled.add(student.studentId); added++;
  }
  return {classes, students, enrollments, added, existing, classId: target.classId};
}

function handleRoster_(book, cfg, lecturer, request) {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(15000)) throw new Error('Máy chủ đang bận. Thử lại sau.');
  try {
    const classes = read_(book, 'Classes'), students = read_(book, 'Students'), enrollments = read_(book, 'Enrollments');
    const schedules = read_(book, 'Schedules').rows;
    const target = rosterTarget_(request, classes.rows, schedules, lecturer);
    if (request.action === 'getRoster') {
      const ids = new Set(enrollments.rows.filter(e => e.classId === target.classId).map(e => e.studentId));
      return students.rows.filter(s => ids.has(s.studentId)).map(s => ({...s, classCode: target.classCode}));
    }
    const next = importRoster_(request, {classes: classes.rows, students: students.rows, enrollments: enrollments.rows, schedules}, lecturer, () => Utilities.getUuid());
    const requests = [];
    for (const [name, current, rows] of [['Classes', classes, next.classes], ['Students', students, next.students], ['Enrollments', enrollments, next.enrollments]]) {
      const appended = rows.slice(current.rows.length);
      if (!appended.length) continue;
      // Preserve existing rows, formulas and other lecturers' data.
      requests.push({appendCells: {sheetId: current.sheet.getSheetId(), fields: 'userEnteredValue', rows: appended.map(row => ({values:
        SCHEMA[name].map(k => ({userEnteredValue: {stringValue: String(row[k] || '')}}))}))}});
    }
    const logs = book.getSheetByName('SyncLogs');
    if (!logs) throw new Error('Thiếu SyncLogs. Chạy setupSheets.');
    requests.push({appendCells: {sheetId: logs.getSheetId(), fields: 'userEnteredValue', rows: [{values:
      [Utilities.getUuid(), 'importRoster', lecturer.email, new Date().toISOString(), 'Added enrollments: ' + next.added]
        .map(v => ({userEnteredValue: {stringValue: v}}))}]}});
    Sheets.Spreadsheets.batchUpdate({requests}, cfg.id);
    return {added: next.added, existing: next.existing, classId: next.classId};
  } finally { lock.releaseLock(); }
}

function doPost(e) {
  let result;
  try {
    const text = e && e.postData && e.postData.contents;
    if (!text || text.length > 200000) throw new Error('Yêu cầu trống hoặc quá lớn.');
    const request = JSON.parse(text);
    if (!request || typeof request !== 'object' || Array.isArray(request)) throw new Error('Yêu cầu không hợp lệ.');
    if (['lab2Health', 'lab2Snapshot', 'lab2Call'].includes(request.action)) {
      result = {ok: true, data: lab2Handle_(request)};
    } else if (request.action === 'studentCodeSessionInfo') {
      result = {ok: true, data: handleStudentCodeSession_(request)};
    } else if (request.action === 'studentCodeCheckIn') {
      result = {ok: true, data: handleStudentCheckIn_(request, true)};
    } else if (request.action === 'studentSessionInfo') {
      result = {ok: true, data: handleStudentSession_(request)};
    } else if (request.action === 'studentCheckIn') {
      result = {ok: true, data: handleStudentCheckIn_(request)};
    } else {
      result = {ok: true, data: handle_(request)};
    }
  } catch (error) {
    // Do not log tokens, requests or upstream exception details containing URLs.
    const message = String(error.message || 'Yêu cầu thất bại.');
    result = {ok: false, error: /https?:|tokeninfo|id_token|Exception|Service /i.test(message) ? 'Lỗi máy chủ hoặc kết nối Google. Kiểm tra cấu hình và thử lại.' : message};
  }
  return ContentService.createTextOutput(JSON.stringify(result)).setMimeType(ContentService.MimeType.JSON);
}
