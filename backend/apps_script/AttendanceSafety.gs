/* Additive attendance migration. Public Sessions/Attendance schemas stay unchanged. */
function lab2Policy_() {
  const p=PropertiesService.getScriptProperties();
  const tri=k=>p.getProperty(k)==='true'?true:p.getProperty(k)==='false'?false:null;
  return {lateCountsAsPresent:tri('ATTENDANCE_LATE_COUNTS_PRESENT'),
    excusedInDenominator:tri('ATTENDANCE_EXCUSED_IN_DENOMINATOR'),warningPercent:15,limitPercent:20};
}

// Caller holds the script lock. Both record and audit are committed in one batch.
function lab2Correct_(book,actor,session,studentId,status,reason,old) {
  if(!['PRESENT','LATE','ABSENT','EXCUSED'].includes(status)||!reason||reason.length>500) throw Error('INVALID_INPUT');
  lab2Class_(book,actor,session.classId,true);
  if(session.status==='RESET') throw Error('SESSION_CLOSED');
  if(old&&old.status===status&&old.note===reason) return; // Retry after lost response.
  const now=new Date().toISOString();
  const audit={id:Utilities.getUuid(),sessionId:session.sessionId,studentId,
    actorUid:actor.firebaseUid||actor.uid,changedAt:now,oldStatus:old?old.status:'PENDING',newStatus:status,reason};
  lab2Write_(book,[{table:'Attendance',row:{...old,attendanceId:old?old.attendanceId:Utilities.getUuid(),
    sessionId:session.sessionId,studentId,status,checkInTime:old?old.checkInTime:'',updatedAt:now,note:reason,updatedBy:actor.email}},
    {table:'AttendanceAudit',row:audit}]);
}

// Caller holds the same script lock as QR check-in and closing the session.
// Only pending students may be filled; an explicit correction stays separate.
function lab2BulkPending_(book,actor,session,d) {
  const entries=d.changes, reason=String(d.notes||'').trim(), requestId=String(d.requestId||'');
  if(!Array.isArray(entries)||!entries.length||entries.length>400||!reason||reason.length>500||
      !/^[a-zA-Z0-9-]{16,80}$/.test(requestId)||typeof d.expectedRevision!=='string') throw Error('INVALID_INPUT');
  const seen=new Set(), changes=entries.map(e=>{
    if(!e||typeof e!=='object'||Array.isArray(e)) throw Error('INVALID_INPUT');
    const id=String(e.studentUid||'').replace(/^student-/,''), status=String(e.status||'').toUpperCase();
    if(!id||seen.has(id)||!['PRESENT','LATE','ABSENT','EXCUSED'].includes(status)) throw Error('INVALID_INPUT');
    seen.add(id); return {id,status};
  });
  const actorUid=actor.firebaseUid||actor.uid;
  const prefix='bulk-'+lab2Hash_(JSON.stringify([session.sessionId,actorUid,requestId]))+'-';
  const audits=lab2Read_(book,'AttendanceAudit').filter(a=>a.id.startsWith(prefix));
  if(audits.length) {
    if(audits.length!==changes.length||changes.some((e,i)=>!audits.some(a=>a.id===prefix+i&&
        a.studentId===e.id&&a.newStatus===e.status&&a.reason===reason))) throw Error('INVALID_INPUT');
    return {updated:changes.length,alreadyApplied:true};
  }
  const meta=lab2Meta_(book,session);
  if(session.status!=='OPEN'||Date.now()>=meta.closesAt) throw Error('SESSION_CLOSED');
  // Legacy sessions without captured membership must use individual corrections.
  if(!meta.eligibleStudentIds) throw Error('BULK_ROSTER_REQUIRED');
  const records=lab2Read_(book,'Attendance').filter(a=>a.sessionId===session.sessionId);
  if(new Set(records.map(a=>a.studentId)).size!==records.length) throw Error('INVALID_SHEET_IDS');
  if(d.expectedRevision!==lab2Hash_(JSON.stringify([session.status,records]))) throw Error('ATTENDANCE_CONFLICT');
  if(changes.some(e=>!meta.eligibleStudentIds.includes(e.id))) throw Error('NOT_ENROLLED');
  if(changes.some(e=>records.some(a=>a.studentId===e.id))) throw Error('ATTENDANCE_CONFLICT');
  const now=new Date().toISOString(), writes=[];
  changes.forEach((e,i)=>{
    writes.push({table:'Attendance',row:{attendanceId:Utilities.getUuid(),sessionId:session.sessionId,
      studentId:e.id,status:e.status,checkInTime:'',updatedAt:now,note:reason,updatedBy:actor.email}});
    writes.push({table:'AttendanceAudit',row:{id:prefix+i,sessionId:session.sessionId,studentId:e.id,
      actorUid,changedAt:now,oldStatus:'PENDING',newStatus:e.status,reason}});
  });
  lab2Write_(book,writes);
  return {updated:changes.length,alreadyApplied:false};
}

/** Editor/time-trigger only. Only sessions with captured roster/deadline are reconciled. */
function reconcileExpiredSessions() {
  const book=SpreadsheetApp.openById(config_().id), lock=LockService.getScriptLock();
  if(!lock.tryLock(15000)) throw Error('LOCK_BUSY');
  try {
    const meta=lab2Read_(book,'Lab2SessionMeta'), now=Date.now();
    const sessions=lab2Read_(book,'Sessions').filter(s=>s.status==='OPEN'&&meta.some(m=>m.sessionId===s.sessionId&&Number(m.closesAt)<=now));
    for(const s of sessions.slice(0,25)) lab2Finalize_(book,s);
    if(SpreadsheetApp.flush) SpreadsheetApp.flush();
    return {closed:Math.min(sessions.length,25),remaining:Math.max(0,sessions.length-25)};
  } finally {lock.releaseLock();}
}

/** Run after setupLab2Free. Idempotent installer; never exposed through dispatcher. */
function installAttendanceReconciliation() {
  if(!ScriptApp.getProjectTriggers().some(t=>t.getHandlerFunction()==='reconcileExpiredSessions')) {
    ScriptApp.newTrigger('reconcileExpiredSessions').timeBased().everyMinutes(1).create();
  }
}

function lab2Live_(book,actor,d) {
  if(actor.role!=='lecturer') throw Error('PERMISSION_DENIED');
  const lock=LockService.getScriptLock();
  if(!lock.tryLock(15000)) throw Error('LOCK_BUSY');
  try {
    let session=lab2Read_(book,'Sessions').find(s=>s.sessionId===d.sessionId);
    if(!session) throw Error('PERMISSION_DENIED');
    const cls=lab2Class_(book,actor,session.classId,true), meta=lab2Meta_(book,session);
    if(session.status==='OPEN'&&meta.eligibleStudentIds&&meta.closesAt<=Date.now()) {
      lab2Finalize_(book,session);
      session=lab2Read_(book,'Sessions').find(s=>s.sessionId===d.sessionId);
    }
    const records=lab2Read_(book,'Attendance').filter(r=>r.sessionId===session.sessionId);
    if(new Set(records.map(r=>r.studentId)).size!==records.length) throw Error('INVALID_SHEET_IDS');
    const eligible=meta.eligibleStudentIds||(session.status==='CLOSED'?records.map(r=>r.studentId):
      lab2Read_(book,'Enrollments').filter(e=>e.classId===session.classId).map(e=>e.studentId));
    const byId=new Map(records.map(r=>[r.studentId,r])), roster=lab2Read_(book,'Students');
    const students=[...new Set([...eligible,...byId.keys()])].map(id=>{
      const student=roster.find(s=>s.studentId===id)||{}, record=byId.get(id);
      return {studentUid:'student-'+id,studentCode:student.studentCode||'',displayName:student.fullName||'',
        status:record?record.status.toLowerCase():'pending',notes:record?record.note:'',checkedInAt:record?record.checkInTime:null};
    });
    const counts={eligible:eligible.length,present:0,late:0,absent:0,excused:0,pending:0};
    students.forEach(s=>{if(s.status in counts) counts[s.status]++;});
    const updated=Math.max(meta.opensAt,...records.map(r=>Date.parse(r.updatedAt)||0));
    return {sessionId:session.sessionId,classId:session.classId,classCode:cls.classCode,subjectId:cls.subjectCode,
      subjectName:cls.subjectName,room:lab2EffectiveRoom_({Schedules:lab2Read_(book,'Schedules'),ScheduleExceptions:lab2Read_(book,'ScheduleExceptions')},session,cls),slot:Number(session.slot),status:session.status,serverTime:new Date().toISOString(),
      opensAt:meta.opensAt,closesAt:meta.closesAt,effectiveDurationMinutes:(meta.closesAt-meta.opensAt)/60000,expiresAt:new Date(meta.closesAt).toISOString(),lastUpdatedAt:new Date(updated).toISOString(),
      revision:lab2Hash_(JSON.stringify([session.status,records])),counts,students};
  } finally {lock.releaseLock();}
}

// Existing Desktop clients retain their action/envelope; validated identity is authoritative.
function lab2DesktopActor_(lecturer) {
  return {role:'lecturer',entity:lecturer,uid:'lecturer-'+lecturer.lecturerId,email:lecturer.email};
}

