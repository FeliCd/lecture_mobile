/* Schedule-driven attendance. No production columns are changed.
 * Every helper which reconciles/writes is called while holding the script lock. */
function lab2Occurrences_(book,actor,classId,date) {
  const cls=lab2Class_(book,actor,classId,true),weekday=lab2Day_(date);
  const bases=lab2Read_(book,'Schedules').filter(s=>s.lecturerId===actor.entity.lecturerId&&s.semester===cls.semester&&s.subjectCode===cls.subjectCode&&s.classCode===cls.classCode);
  if(new Set(bases.map(s=>s.scheduleId)).size!==bases.length) throw Error('OCCURRENCE_DUPLICATE');
  const exceptions=lab2Read_(book,'ScheduleExceptions').filter(e=>e.classId===cls.classId);
  const result=[];
  for(const base of bases) {
    const overrides=exceptions.filter(e=>e.scheduleId===base.scheduleId&&e.date===date&&e.kind!=='MAKEUP');
    if(overrides.length>1) throw Error('OCCURRENCE_DUPLICATE');
    const change=overrides[0],rows=[];
    if(Number(base.dayOfWeek)===weekday&&!['CANCELLED','RESCHEDULED'].includes(change&&change.kind)) rows.push({row:change||base,exceptionId:change?change.id:''});
    for(const e of exceptions.filter(e=>e.scheduleId===base.scheduleId&&e.targetDate===date&&['RESCHEDULED','MAKEUP'].includes(e.kind))) rows.push({row:e,exceptionId:e.id});
    for(const {row,exceptionId} of rows) {
      const slot=String(row.slot),start=String(row.startTime),end=String(row.endTime);
      if(!/^(?:[1-9]|1[0-2])$/.test(slot)||! /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(start)||! /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(end)||start===end) throw Error('INVALID_OCCURRENCE');
      const startAt=lab2Millis_(date,start),endAt=lab2Millis_(date,end)+(end<start?86400000:0);
      result.push({occurrenceId:lab2Hash_([base.scheduleId,date,exceptionId].join('|')),scheduleId:base.scheduleId,exceptionId,
        classId:cls.classId,subjectId:cls.subjectCode,subjectName:cls.subjectName,classCode:cls.classCode,room:row.room||base.room||'',
        sessionDate:date,slot:Number(slot),scheduledStartTime:start,scheduledEndTime:end,scheduledStartAt:startAt,scheduledEndAt:endAt});
    }
  }
  return result;
}
function lab2ResolveOccurrence_(book,actor,d) {
  const date=String(d.sessionDate||d.date||'');
  const matches=lab2Occurrences_(book,actor,String(d.classId||''),date).filter(o=>
    (!d.occurrenceId||o.occurrenceId===d.occurrenceId)&&(!d.scheduleId||o.scheduleId===d.scheduleId)&&(d.exceptionId==null||o.exceptionId===d.exceptionId)&&(!d.slot||o.slot===Number(d.slot)));
  if(matches.length>1) throw Error('OCCURRENCE_DUPLICATE');
  if(!matches.length) throw Error('OCCURRENCE_NOT_FOUND');
  return matches[0];
}
function lab2OccurrenceSession_(book,o) {
  const all=lab2Read_(book,'Sessions').filter(s=>s.classId===o.classId&&s.date===o.sessionDate&&String(s.slot)===String(o.slot));
  const current=all.filter(s=>s.status!=='RESET');
  if(current.length>1) throw Error('INVALID_SHEET_IDS');
  let session=current[0];
  if(session&&session.status==='OPEN'&&lab2Meta_(book,session).closesAt<=Date.now()) {
    lab2Finalize_(book,session,true);session=lab2Read_(book,'Sessions').find(s=>s.sessionId===session.sessionId);
  }
  return {session,resetOnly:!session&&all.length>0};
}
function lab2SessionReceipt_(book,session) {
  const meta=lab2Meta_(book,session);
  return {sessionId:session.sessionId,classSessionId:session.sessionId,attendanceSessionId:session.sessionId,status:session.status,
    opensAt:meta.opensAt,closesAt:meta.closesAt,effectiveDurationMinutes:(meta.closesAt-meta.opensAt)/60000,serverTime:Date.now()};
}
function lab2OccurrenceState_(o,existing,now) {
  if(existing.session) return existing.session.status;
  if(existing.resetOnly) return 'RESET';
  const today=Utilities.formatDate(new Date(now),'Asia/Ho_Chi_Minh','yyyy-MM-dd');
  if(o.sessionDate>today||now<o.scheduledStartAt-15*60000) return 'NOT_YET';
  if(now>=o.scheduledEndAt) return 'ENDED';
  if(o.scheduledEndAt-now<60000) return 'TOO_SHORT';
  return 'AVAILABLE';
}
function lab2OccurrenceView_(book,actor,d) {
  const lock=LockService.getScriptLock();if(!lock.tryLock(15000)) throw Error('LOCK_BUSY');
  try {
    let o;
    try {o=lab2ResolveOccurrence_(book,actor,d);}
    catch(error) {
      // Historical sessions remain viewable even if their schedule was removed.
      if(error.message!=='OCCURRENCE_NOT_FOUND'||!d.sessionId) throw error;
      const s=lab2Read_(book,'Sessions').find(s=>s.sessionId===d.sessionId&&s.classId===d.classId&&s.date===(d.sessionDate||d.date)&&String(s.slot)===String(d.slot));
      if(!s) throw error;
      const cls=lab2Class_(book,actor,s.classId,true);
      o={classId:s.classId,sessionDate:s.date,slot:Number(s.slot),subjectId:cls.subjectCode,subjectName:cls.subjectName,classCode:cls.classCode,
        scheduledStartTime:s.startTime,scheduledEndTime:s.endTime,scheduledStartAt:lab2Millis_(s.date,s.startTime),scheduledEndAt:lab2Millis_(s.date,s.endTime)+(s.endTime<s.startTime?86400000:0),historical:true};
    }
    const existing=lab2OccurrenceSession_(book,o),now=Date.now();
    const quickAttendanceAvailable=!existing.resetOnly&&o.sessionDate===Utilities.formatDate(new Date(now),'Asia/Ho_Chi_Minh','yyyy-MM-dd')&&
      (!existing.session||existing.session.status!=='RESET');
    return {...o,state:lab2OccurrenceState_(o,existing,now),serverTime:now,earliestOpenAt:o.scheduledStartAt-15*60000,
      quickAttendanceAvailable,remainingMinutes:Math.max(0,(o.scheduledEndAt-now)/60000),...(existing.session?lab2SessionReceipt_(book,existing.session):{})};
  } finally {lock.releaseLock();}
}
function lab2CreateFromOccurrence_(book,actor,d,desktop=null,resetOld=null) {
  const duration=Number(d.durationMinutes==null?10:d.durationMinutes);
  if(![5,10,15,20,30].includes(duration)) throw Error('INVALID_INPUT');
  const o=lab2ResolveOccurrence_(book,actor,d),existing=lab2OccurrenceSession_(book,o),now=Date.now();
  if(existing.session&&!resetOld) return {...lab2SessionReceipt_(book,existing.session),reused:true,occurrenceId:o.occurrenceId};
  const state=lab2OccurrenceState_(o,resetOld?{session:null,resetOnly:false}:existing,now);
  if(state!=='AVAILABLE') throw Error({NOT_YET:'OCCURRENCE_NOT_YET',ENDED:'OCCURRENCE_ENDED',TOO_SHORT:'OCCURRENCE_TOO_SHORT',RESET:'SESSION_RESET_REQUIRES_DESKTOP'}[state]||'INVALID_OCCURRENCE');
  const eligible=[...new Set(lab2Read_(book,'Enrollments').filter(e=>e.classId===o.classId).map(e=>e.studentId))];
  if(eligible.length>400) throw Error('CLASS_TOO_LARGE');
  const id=Utilities.getUuid(),closes=Math.min(now+duration*60000,o.scheduledEndAt),token=Utilities.getUuid()+Utilities.getUuid();
  const row={sessionId:id,classId:o.classId,date:o.sessionDate,slot:String(o.slot),startTime:o.scheduledStartTime,endTime:o.scheduledEndTime,
    status:'OPEN',currentToken:desktop?desktop.token+(desktop.secret?'#'+desktop.secret:''):token,tokenExpiredAt:new Date(desktop?Math.min(closes,desktop.expiresAt):closes).toISOString(),createdBy:actor.entity.lecturerId};
  const meta={sessionId:id,title:(o.subjectName||o.subjectId)+' • Slot '+o.slot,opensAt:now,closesAt:closes,lateThresholdAt:'',eligibleStudentIds:JSON.stringify(eligible)};
  const changes=[{table:'Sessions',row},{table:'Lab2SessionMeta',row:meta}];
  if(resetOld) changes.unshift({table:'Sessions',row:{...resetOld,status:'RESET',currentToken:'',tokenExpiredAt:''}});
  lab2Write_(book,changes);
  return {...lab2SessionReceipt_(book,row),reused:false,occurrenceId:o.occurrenceId};
}
