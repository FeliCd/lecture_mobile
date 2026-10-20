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


/* Quick attendance (F01): lecturer marks exceptions on a draft where everyone defaults to PRESENT.
 * Reading the context never creates a session or a record. Saving applies only to the roster the
 * lecturer confirmed, never silently overwrites QR/manual records and closes the session in one batch. */
function lab2QuickRevision_(session,records) {
  return session?lab2Hash_(JSON.stringify([session.status,records])):'';
}
// Caller holds the script lock.
function lab2QuickState_(book,actor,d) {
  if(actor.role!=='lecturer') throw Error('PERMISSION_DENIED');
  const o=lab2ResolveOccurrence_(book,actor,d), existing=lab2OccurrenceSession_(book,o), now=Date.now();
  const state=lab2OccurrenceState_(o,existing,now), session=existing.session||null;
  const records=session?lab2Read_(book,'Attendance').filter(r=>r.sessionId===session.sessionId):[];
  if(new Set(records.map(r=>r.studentId)).size!==records.length) throw Error('INVALID_SHEET_IDS');
  let eligible;
  if(session) {
    const meta=lab2Meta_(book,session);
    eligible=meta.eligibleStudentIds||(session.status==='CLOSED'?records.map(r=>r.studentId):
      lab2Read_(book,'Enrollments').filter(e=>e.classId===session.classId).map(e=>e.studentId));
  } else eligible=lab2Read_(book,'Enrollments').filter(e=>e.classId===o.classId).map(e=>e.studentId);
  eligible=[...new Set([...eligible,...records.map(r=>r.studentId)])];
  if(eligible.length>400) throw Error('CLASS_TOO_LARGE');
  return {o,session,state,records,eligible,revision:lab2QuickRevision_(session,records),now};
}
function lab2QuickCounts_(eligible,statusOf) {
  const counts={eligible:eligible.length,present:0,late:0,absent:0,excused:0,pending:0};
  for(const id of eligible) {const s=String(statusOf(id)||'pending').toLowerCase(); if(s in counts) counts[s]++;}
  return counts;
}
function lab2QuickContext_(book,actor,d) {
  const lock=LockService.getScriptLock(); if(!lock.tryLock(15000)) throw Error('LOCK_BUSY');
  try {
    const q=lab2QuickState_(book,actor,d), roster=lab2Read_(book,'Students'), byId=new Map(q.records.map(r=>[r.studentId,r]));
    const students=q.eligible.map(id=>{
      const s=roster.find(x=>x.studentId===id)||{}, r=byId.get(id);
      return {studentId:id,studentUid:'student-'+id,studentCode:s.studentCode||'',displayName:s.fullName||'',
        status:r?r.status.toLowerCase():null,notes:r?r.note:'',updatedAt:r?r.updatedAt:''};
    }).sort((a,b)=>String(a.studentCode).localeCompare(String(b.studentCode)));
    const savedAt=q.session&&q.session.status==='CLOSED'?Math.max(0,...q.records.map(r=>Date.parse(r.updatedAt)||0)):null;
    return {...q.o,state:q.state,editable:q.state==='AVAILABLE'||q.state==='OPEN',serverTime:q.now,revision:q.revision,
      ...(q.session?lab2SessionReceipt_(book,q.session):{}),savedAt,students,
      counts:lab2QuickCounts_(q.eligible,id=>byId.get(id)&&byId.get(id).status)};
  } finally {lock.releaseLock();}
}
// Caller (lab2Mutate_) holds the script lock.
function lab2QuickSubmit_(book,actor,d) {
  const ids=Array.isArray(d.studentIds)?d.studentIds.map(String):null, list=Array.isArray(d.exceptions)?d.exceptions:null;
  if(!ids||!list||ids.length>400||list.length>400||typeof d.expectedRevision!=='string'||new Set(ids).size!==ids.length) throw Error('INVALID_INPUT');
  const wanted=new Map();
  for(const e of list) {
    const id=String(e&&(e.studentId||e.studentUid)||'').replace(/^student-/,''), status=String(e&&e.status||'').toUpperCase();
    if(!id||wanted.has(id)||!['PRESENT','LATE','ABSENT','EXCUSED'].includes(status)) throw Error('INVALID_INPUT');
    wanted.set(id,status);
  }
  let q=lab2QuickState_(book,actor,d);
  const sameRoster=eligible=>eligible.length===ids.length&&eligible.every(id=>ids.includes(id))&&[...wanted.keys()].every(id=>eligible.includes(id));
  const result=(q,extra)=>{
    const byId=new Map(q.records.map(r=>[r.studentId,r]));
    return {...lab2SessionReceipt_(book,q.session),occurrenceId:q.o.occurrenceId,counts:lab2QuickCounts_(q.eligible,id=>byId.get(id)&&byId.get(id).status),...extra};
  };
  if(q.session&&q.session.status==='CLOSED') {
    // Retry after a lost response: identical outcome is acknowledged, anything else needs per-student adjustment.
    const byId=new Map(q.records.map(r=>[r.studentId,r]));
    if(sameRoster(q.eligible)&&q.eligible.every(id=>byId.get(id)&&byId.get(id).status===(wanted.get(id)||byId.get(id).status))) {
      return result(q,{alreadySaved:true,savedAt:Math.max(0,...q.records.map(r=>Date.parse(r.updatedAt)||0))});
    }
    throw Error('ATTENDANCE_ALREADY_FINALIZED');
  }
  if(q.session&&q.session.status!=='OPEN') throw Error('SESSION_CLOSED');
  if(!q.session&&q.state!=='AVAILABLE') throw Error({NOT_YET:'OCCURRENCE_NOT_YET',ENDED:'OCCURRENCE_ENDED',TOO_SHORT:'OCCURRENCE_TOO_SHORT',RESET:'SESSION_RESET_REQUIRES_DESKTOP'}[q.state]||'INVALID_OCCURRENCE');
  if(d.expectedRevision!==q.revision) throw Error('ATTENDANCE_CONFLICT');
  if(!sameRoster(q.eligible)) throw Error('ROSTER_CHANGED');
  if(!q.session) {
    lab2CreateFromOccurrence_(book,actor,{...d,durationMinutes:5});
    q=lab2QuickState_(book,actor,d);
    if(!q.session||q.session.status!=='OPEN'||!sameRoster(q.eligible)) throw Error('ROSTER_CHANGED');
  }
  const now=new Date().toISOString(), byId=new Map(q.records.map(r=>[r.studentId,r])), changes=[];
  const reason='Điểm danh nhanh';
  for(const id of q.eligible) {
    const old=byId.get(id), status=wanted.get(id)||(old?old.status:'PRESENT');
    if(old&&old.status===status) continue;
    if(old) {
      changes.push({table:'Attendance',row:{...old,status,updatedAt:now,note:reason,updatedBy:actor.email}});
      changes.push({table:'AttendanceAudit',row:{id:Utilities.getUuid(),sessionId:q.session.sessionId,studentId:id,
        actorUid:actor.firebaseUid||actor.uid,changedAt:now,oldStatus:old.status,newStatus:status,reason}});
    } else {
      changes.push({table:'Attendance',row:{attendanceId:Utilities.getUuid(),sessionId:q.session.sessionId,studentId:id,
        status,checkInTime:'',updatedAt:now,note:reason,updatedBy:actor.email}});
    }
  }
  changes.push({table:'Sessions',row:{...q.session,status:'CLOSED',currentToken:'',tokenExpiredAt:''}});
  lab2Write_(book,changes);
  const saved=lab2QuickState_(book,actor,d);
  return result(saved,{alreadySaved:false,savedAt:Date.parse(now)});
}
