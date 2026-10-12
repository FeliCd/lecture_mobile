/* Caller holds script lock. Dated overrides never change recurring Desktop rows. */
function lab2Day_(text) {
  if(!/^\d{4}-\d{2}-\d{2}$/.test(text)||!Number.isFinite(Date.parse(text))||new Date(text).toISOString().slice(0,10)!==text) throw Error('INVALID_INPUT');
  return new Date(text).getUTCDay()||7;
}
function lab2SaveException_(book,actor,d) {
  if(actor.role!=='lecturer') throw Error('PERMISSION_DENIED');
  const cls=lab2Class_(book,actor,d.classId,true);
  const schedules=lab2Read_(book,'Schedules'),base=schedules.find(s=>s.scheduleId===d.scheduleId&&s.lecturerId===actor.entity.lecturerId&&s.classCode===cls.classCode&&s.subjectCode===cls.subjectCode&&s.semester===cls.semester);
  if(!base) throw Error('PERMISSION_DENIED');
  const date=String(d.date||''),kind=String(d.kind||''),reason=String(d.reason||'').trim();
  if(lab2Day_(date)!==Number(base.dayOfWeek)||!['CANCELLED','RESCHEDULED','MAKEUP','ROOM_CHANGED','RESTORED'].includes(kind)||!reason||reason.length>500) throw Error('INVALID_INPUT');
  const targetDate=['RESCHEDULED','MAKEUP'].includes(kind)?String(d.targetDate||''):date;
  lab2Day_(targetDate);
  const slot=['RESCHEDULED','MAKEUP'].includes(kind)?String(d.slot):base.slot;
  const start=['RESCHEDULED','MAKEUP'].includes(kind)?String(d.startTime):base.startTime;
  const end=['RESCHEDULED','MAKEUP'].includes(kind)?String(d.endTime):base.endTime;
  const room=kind==='RESTORED'?base.room:String(d.room||base.room).trim();
  if(!/^(?:[1-9]|1[0-2])$/.test(slot)||!/^([01]\d|2[0-3]):[0-5]\d$/.test(start)||!/^([01]\d|2[0-3]):[0-5]\d$/.test(end)||start===end||room.length>100) throw Error('INVALID_INPUT');
  const id=lab2Hash_([base.scheduleId,date,kind==='MAKEUP'?targetDate+':'+slot:'override'].join('|'));
  const exceptions=lab2Read_(book,'ScheduleExceptions'),previous=exceptions.find(e=>e.id===id);
  const row={id,scheduleId:base.scheduleId,classId:cls.classId,date,kind,targetDate,slot,startTime:start,endTime:end,room,reason,createdBy:actor.entity.lecturerId,updatedAt:new Date().toISOString()};
  const sessions=lab2Read_(book,'Sessions').filter(s=>s.classId===cls.classId&&s.status!=='RESET');
  if(sessions.some(s=>(kind!=='MAKEUP'&&s.date===date&&s.slot===base.slot)||(s.date===targetDate&&s.slot===slot)||(previous&&s.date===previous.targetDate&&s.slot===previous.slot))) throw Error('OCCURRENCE_HAS_SESSION');
  if(kind!=='CANCELLED') {
    const from=lab2Millis_(targetDate,start),to=lab2Millis_(targetDate,end)+(end<start?86400000:0);
    const days=[-1,0,1].map(delta=>new Date(Date.parse(targetDate)+delta*86400000).toISOString().slice(0,10));
    for(const otherClass of lab2Read_(book,'Classes').filter(c=>c.lecturerId===actor.entity.lecturerId&&c.semester===base.semester)) {
      for(const day of days) for(const o of lab2Occurrences_(book,actor,otherClass.classId,day)) {
        if(o.exceptionId===id||(kind!=='MAKEUP'&&o.scheduleId===base.scheduleId&&o.sessionDate===date)) continue;
        if(from<o.scheduledEndAt&&o.scheduledStartAt<to) throw Error('SCHEDULE_CONFLICT');
      }
    }
  }
  lab2Write_(book,[{table:'ScheduleExceptions',row}]);return {saved:true,id};
}
function lab2UpdateStudent_(book,actor,d) {
  const cls=lab2Class_(book,actor,d.classId,true),id=String(d.studentUid||'').replace(/^student-/,'');
  const allowed=['classId','studentUid','fullName','schoolEmail','reason'];
  if(Object.keys(d).some(k=>!allowed.includes(k))) throw Error('INVALID_INPUT');
  const enrollments=lab2Read_(book,'Enrollments').filter(e=>e.studentId===id),classes=lab2Read_(book,'Classes');
  if(!enrollments.some(e=>e.classId===cls.classId)) throw Error('NOT_ENROLLED');
  // Students is global, so a lecturer may not silently change another lecturer's shared profile.
  if(enrollments.some(e=>!classes.some(c=>c.classId===e.classId&&c.lecturerId===actor.entity.lecturerId))) throw Error('SHARED_STUDENT_ADMIN_REQUIRED');
  const students=lab2Read_(book,'Students'),old=students.find(s=>s.studentId===id);
  if(!old) throw Error('INVALID_INPUT');
  const fullName=String(d.fullName||'').trim(),email=String(d.schoolEmail||'').trim().toLowerCase(),reason=String(d.reason||'').trim();
  if(!fullName||fullName.length>200||email.length>200||!reason||reason.length>500||
    (email&&(!/^[^\s@]+@[^\s@]+$/.test(email)||!config_().domains.includes(email.split('@')[1])))||
    (email&&students.some(s=>s.studentId!==id&&String(s.schoolEmail).trim().toLowerCase()===email))) throw Error('INVALID_INPUT');
  if(old.fullName===fullName&&old.schoolEmail===email) return {updated:true};
  const row={...old,fullName,schoolEmail:email};
  lab2Write_(book,[{table:'Students',row},{table:'RosterAudit',row:{id:Utilities.getUuid(),classId:cls.classId,studentId:id,
    actorUid:actor.firebaseUid||actor.uid,changedAt:new Date().toISOString(),oldValue:JSON.stringify(old),newValue:JSON.stringify(row),reason}}]);
  return {updated:true};
}
