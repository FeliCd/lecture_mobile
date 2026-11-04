/* Shared student portal. Run setupStudentPortal manually; deploy alongside the shared backend. */
function setupStudentPortal() {
  const book=SpreadsheetApp.openById(config_().id),lock=LockService.getScriptLock();
  if(!lock.tryLock(15000)) throw Error('LOCK_BUSY');
  try {
    for(const name of Object.keys(LAB2_TABLES).filter(n=>n.startsWith('Portal'))) {
      const s=book.getSheetByName(name)||book.insertSheet(name);
      if(!s.getLastRow()) {s.getRange(1,1,1,LAB2_TABLES[name].length).setValues([LAB2_TABLES[name]]);s.setFrozenRows(1);}
      lab2Read_(book,name);
    }
    return {ready:true};
  } finally {lock.releaseLock();}
}
function portalHandle_(request) {
  const cfg=config_(),book=SpreadsheetApp.openById(cfg.id),p=PropertiesService.getScriptProperties();
  let actor;
  if(request.firebaseAuth===true) {
    if(!p.getProperty('PORTAL_FIREBASE_PROJECT_ID')||!p.getProperty('PORTAL_FIREBASE_API_KEY')) throw Error('SHARED_BACKEND_SETUP_REQUIRED');
    const identity=lab2FirebaseIdentity_(request.idToken,{project:p.getProperty('PORTAL_FIREBASE_PROJECT_ID'),key:p.getProperty('PORTAL_FIREBASE_API_KEY')});
    // Membership, rather than a caller-provided roll or email, establishes student identity.
    const matches=lab2Read_(book,'Students').filter(s=>String(s.schoolEmail).trim().toLowerCase()===identity.email);
    if(matches.length!==1) throw Error('PROFILE_NOT_REGISTERED');
    actor={...identity,role:'student',entity:matches[0],uid:'student-'+matches[0].studentId};
  } else actor=lab2DesktopActor_(authenticate_(request.idToken,cfg,book));
  lab2Limit_(actor.uid, 'portal:'+String(request.method));
  const lock=LockService.getScriptLock();
  if(!lock.tryLock(15000)) throw Error('LOCK_BUSY');
  try {return portalCall_(book,actor,String(request.method||''),request.data||{});}
  finally {lock.releaseLock();}
}
function portalAudit_(actor,classId,entityId,action,detail) {
  return {table:'PortalAudit',row:{id:Utilities.getUuid(),classId,entityId,actor:actor.uid,action,at:new Date().toISOString(),detail:JSON.stringify(detail)}};
}
function portalTeacher_(actor) {if(actor.role!=='lecturer') throw Error('PERMISSION_DENIED');}
function portalStudent_(actor) {if(actor.role!=='student') throw Error('PERMISSION_DENIED');}
function portalKey_(value) {
  if(typeof value!=='string'||!/^[A-Za-z0-9-]{16,80}$/.test(value)) throw Error('INVALID_REQUEST_KEY');
  return value;
}
function portalVersion_(row,version) {
  if(!Number.isInteger(version)||Number(row.version)!==version) throw Error('VERSION_CONFLICT');
}
function portalBook_(book,classId) {
  const r=lab2Read_(book,'PortalGradebooks').find(r=>r.classId===classId);
  return r||{classId,components:'[]',version:'0',activePublicationId:'',updatedAt:'',updatedBy:''};
}
function portalRoster_(book,classId) {
  const ids=new Set(lab2Read_(book,'Enrollments').filter(e=>e.classId===classId).map(e=>e.studentId));
  const students=lab2Read_(book,'Students').filter(s=>ids.has(s.studentId));
  if(students.length>400) throw Error('CLASS_TOO_LARGE');
  return students;
}
function portalOccurrence_(book,actor,d) {
  const cls=lab2Class_(book,actor,String(d.classId||''),false);
  const owner={role:'lecturer',entity:{lecturerId:cls.lecturerId}};
  return lab2ResolveOccurrence_(book,owner,d);
}
function portalSameOccurrence_(r,o) {
  return r.occurrenceId===o.occurrenceId&&r.sessionDate===o.sessionDate&&Number(r.slot)===o.slot&&r.startTime===o.scheduledStartTime&&r.endTime===o.scheduledEndTime;
}
function portalLeaveViews_(book,rows) {
  if(!rows.length) return [];
  const tables={};
  for(const name of ['Classes','Schedules','ScheduleExceptions','Students']) tables[name]=lab2Read_(book,name);
  const cache=new Map(),students=new Map(tables.Students.map(s=>[s.studentId,s]));
  return rows.map(r=>{
    let scheduleChanged=true;
    const key=r.classId+'|'+r.sessionDate;
    if(!cache.has(key)) {
      const cls=tables.Classes.find(c=>c.classId===r.classId);
      try {cache.set(key,lab2Occurrences_(book,{role:'lecturer',entity:{lecturerId:cls.lecturerId}},r.classId,r.sessionDate,tables));}
      catch(_) {cache.set(key,[]);}
    }
    const matches=cache.get(key).filter(o=>o.occurrenceId===r.occurrenceId);
    if(matches.length===1) scheduleChanged=!portalSameOccurrence_(r,matches[0]);
    const s=students.get(r.studentId);
    return {...r,version:Number(r.version),fullName:s?s.fullName:'',studentCode:s?s.studentCode:'',scheduleChanged};
  });
}
function portalLeaveView_(book,r) {return portalLeaveViews_(book,[r])[0];}
// Optional for old deployments: never create tables while reading/finalizing attendance.
function portalApprovedForSession_(book,session) {
  if(!book.getSheetByName('PortalLeaveRequests')) return new Map();
  const candidates=lab2Read_(book,'PortalLeaveRequests').filter(r=>r.classId===session.classId&&r.sessionDate===session.date&&String(r.slot)===String(session.slot)&&r.status==='APPROVED');
  const result=new Map();
  for(const r of portalLeaveViews_(book,candidates)) {
    if(!r.scheduleChanged) result.set(r.studentId,r);
  }
  return result;
}
function portalComponents_(values) {
  if(!Array.isArray(values)||values.length<1||values.length>30) throw Error('INVALID_COMPONENTS');
  const ids=new Set(),names=new Set();
  return values.map((v,i)=>{
    if(!v||typeof v.id!=='string'||!/^[A-Za-z0-9_-]{1,80}$/.test(v.id)||['__proto__','prototype','constructor'].includes(v.id)||ids.has(v.id)||typeof v.name!=='string'||!v.name.trim()||v.name.trim().length>100||names.has(v.name.trim())||typeof v.maxScore!=='number'||!Number.isFinite(v.maxScore)||v.maxScore<=0||v.maxScore>1000) throw Error('INVALID_COMPONENTS');
    ids.add(v.id);names.add(v.name.trim());return {id:v.id,name:v.name.trim(),maxScore:v.maxScore,order:i};
  });
}
function portalGrades_(grades,components) {
  if(!grades||typeof grades!=='object'||Array.isArray(grades)||Object.keys(grades).some(k=>!components.some(c=>c.id===k))) throw Error('INVALID_GRADES');
  const result={};
  for(const c of components) {
    const v=grades[c.id];
    if(v==null||v==='') {result[c.id]='';continue;}
    if(typeof v!=='number'||!Number.isFinite(v)||v<0||v>c.maxScore) throw Error('INVALID_GRADE_RANGE');
    result[c.id]=v;
  }
  return result;
}
function portalCall_(book,actor,method,d) {
  if(!d||typeof d!=='object'||Array.isArray(d)) throw Error('INVALID_INPUT');
  if(['getGroupSignupSheet','createGroupSignupSheet','resumeGroupSignupSheet','syncGroupSignupSheet','closeGroupSignupSheet'].includes(method)) return groupCall_(book,actor,method,d);
  if(['getGroupPlan','saveGroupPlan','getGroupMessages','sendGroupMessage','downloadGroupFile','ackGroupMessages','createGroupTask','listGroupTasks','listMyTaskNotifications','readTaskNotification'].includes(method)) return groupCall_(book,actor,method,d);
  if(method==='listClasses') {
    const enroll=actor.role==='student'?new Set(lab2Read_(book,'Enrollments').filter(e=>e.studentId===actor.entity.studentId).map(e=>e.classId)):null;
    return lab2Read_(book,'Classes').filter(c=>enroll?enroll.has(c.classId):c.lecturerId===actor.entity.lecturerId);
  }
  if(method==='listMyLeaveRequests') {
    portalStudent_(actor);
    return portalLeaveViews_(book,lab2Read_(book,'PortalLeaveRequests').filter(r=>r.studentId===actor.entity.studentId));
  }
  if(method==='cancelLeaveRequest') {
    portalStudent_(actor);
    const r=lab2Read_(book,'PortalLeaveRequests').find(r=>r.id===d.id&&r.studentId===actor.entity.studentId);
    if(!r) throw Error('PERMISSION_DENIED');
    if(r.status==='CANCELLED') return portalLeaveView_(book,r);
    portalVersion_(r,d.version);
    if(r.status!=='PENDING'||Date.now()>=lab2Millis_(r.sessionDate,r.startTime)) throw Error('LEAVE_TOO_LATE');
    const row={...r,status:'CANCELLED',version:Number(r.version)+1};
    lab2Write_(book,[{table:'PortalLeaveRequests',row},portalAudit_(actor,r.classId,r.id,'CANCEL_LEAVE',{from:r.status,to:row.status})]);
    return portalLeaveView_(book,row);
  }
  if(method==='applyApprovedLeave') {
    portalTeacher_(actor);
    const session=lab2Read_(book,'Sessions').find(s=>s.sessionId===d.sessionId&&s.status==='CLOSED');
    if(!session) throw Error('SESSION_CLOSED_REQUIRED');
    lab2Class_(book,actor,session.classId,true);
    const eligible=lab2Meta_(book,session).eligibleStudentIds||lab2Read_(book,'Enrollments').filter(e=>e.classId===session.classId).map(e=>e.studentId);
    if(!eligible.includes(d.studentId)) throw Error('NOT_ENROLLED');
    const approved=portalApprovedForSession_(book,session).get(d.studentId);
    if(!approved) throw Error('APPROVED_LEAVE_REQUIRED');
    const old=lab2Read_(book,'Attendance').find(a=>a.sessionId===session.sessionId&&a.studentId===d.studentId);
    // Do not overwrite attendance confirmed by a student or a manual correction.
    if(old&&old.status==='EXCUSED'&&old.note==='Approved leave: '+approved.id) return {saved:true};
    if(old&&!(old.status==='ABSENT'&&old.note==='Lab2 finalized')) throw Error('MANUAL_CORRECTION_REQUIRED');
    lab2Correct_(book,actor,session,d.studentId,'EXCUSED','Approved leave: '+approved.id,old);
    return {saved:true};
  }
  const cls=lab2Class_(book,actor,String(d.classId||''),false);
  if(method==='listOccurrences') {
    const date=String(d.date||'');
    if(!/^\d{4}-\d{2}-\d{2}$/.test(date)||new Date(lab2Millis_(date,'00:00')+7*3600000).toISOString().slice(0,10)!==date) throw Error('INVALID_SESSION_DATE');
    return lab2Occurrences_(book,{role:'lecturer',entity:{lecturerId:cls.lecturerId}},cls.classId,date).filter(o=>o.scheduledStartAt>Date.now());
  }
  if(method==='submitLeaveRequest') {
    portalStudent_(actor);const key=portalKey_(d.requestKey);
    const rows=lab2Read_(book,'PortalLeaveRequests');
    const retry=rows.find(r=>r.requestKey===key&&r.studentId===actor.entity.studentId);
    if(retry) return portalLeaveView_(book,retry);
    const o=portalOccurrence_(book,actor,d),reason=String(d.reason||'').trim();
    if(o.scheduledStartAt<=Date.now()) throw Error('LEAVE_TOO_LATE');
    if(reason.length<10||reason.length>1000) throw Error('INVALID_REASON');
    if(rows.some(r=>r.studentId===actor.entity.studentId&&r.occurrenceId===o.occurrenceId&&['PENDING','APPROVED'].includes(r.status))) throw Error('LEAVE_DUPLICATE');
    const row={id:Utilities.getUuid(),classId:cls.classId,studentId:actor.entity.studentId,occurrenceId:o.occurrenceId,scheduleId:o.scheduleId,exceptionId:o.exceptionId,
      sessionDate:o.sessionDate,slot:o.slot,startTime:o.scheduledStartTime,endTime:o.scheduledEndTime,reason,status:'PENDING',submittedAt:new Date().toISOString(),reviewedAt:'',reviewedBy:'',reviewNote:'',version:1,requestKey:key};
    lab2Write_(book,[{table:'PortalLeaveRequests',row},portalAudit_(actor,cls.classId,row.id,'SUBMIT_LEAVE',{to:'PENDING'})]);
    return portalLeaveView_(book,row);
  }
  if(method==='listClassLeaveRequests') {
    portalTeacher_(actor);
    return portalLeaveViews_(book,lab2Read_(book,'PortalLeaveRequests').filter(r=>r.classId===cls.classId&&(!d.sessionDate||r.sessionDate===d.sessionDate)&&(!d.slot||String(r.slot)===String(d.slot))));
  }
  if(method==='reviewLeaveRequest') {
    portalTeacher_(actor);
    const r=lab2Read_(book,'PortalLeaveRequests').find(r=>r.id===d.id&&r.classId===cls.classId);
    if(!r) throw Error('PERMISSION_DENIED');
    portalVersion_(r,d.version);
    if(r.status!=='PENDING'||!['APPROVED','REJECTED'].includes(d.status)) throw Error('INVALID_LEAVE_TRANSITION');
    const note=String(d.reviewNote||'').trim();
    if(note.length>500||(d.status==='REJECTED'&&!note)) throw Error('INVALID_REASON');
    if(d.status==='APPROVED'&&portalLeaveView_(book,r).scheduleChanged) throw Error('OCCURRENCE_CHANGED');
    const row={...r,status:d.status,reviewedAt:new Date().toISOString(),reviewedBy:actor.email,reviewNote:note,version:Number(r.version)+1};
    lab2Write_(book,[{table:'PortalLeaveRequests',row},portalAudit_(actor,cls.classId,r.id,'REVIEW_LEAVE',{from:r.status,to:row.status,note})]);
    return portalLeaveView_(book,row);
  }
  if(method==='getMyPublishedGrades') {
    portalStudent_(actor);
    const state=portalBook_(book,cls.classId);
    if(!state.activePublicationId) return {published:false};
    const p=lab2Read_(book,'PortalPublications').find(p=>p.id===state.activePublicationId&&p.classId===cls.classId);
    if(!p) throw Error('INVALID_PUBLICATION_STATE');
    const row=lab2Read_(book,'PortalPublishedGrades').find(r=>r.publicationId===p.id&&r.studentId===actor.entity.studentId);
    if(!row) return {published:false};
    return {published:true,publicationId:p.id,publishedAt:p.publishedAt,version:Number(p.version),components:JSON.parse(p.components),grades:JSON.parse(row.grades),comment:row.comment};
  }
  portalTeacher_(actor);
  const state=portalBook_(book,cls.classId),roster=portalRoster_(book,cls.classId);
  if(method==='getGradebook') {
    const drafts=lab2Read_(book,'PortalGradeDrafts').filter(r=>r.classId===cls.classId);
    return {...state,version:Number(state.version),components:JSON.parse(state.components),students:roster.map(s=>{
      const r=drafts.find(r=>r.studentId===s.studentId);return {...s,grades:r?JSON.parse(r.grades):{},comment:r?r.comment:''};})};
  }
  if(method==='saveGradebook') {
    portalVersion_(state,d.version);
    const components=portalComponents_(d.components);
    if(!Array.isArray(d.students)||d.students.length!==roster.length||new Set(d.students.map(s=>s.studentId)).size!==roster.length) throw Error('ROSTER_CHANGED');
    const changes=d.students.map(s=>{
      if(!roster.some(r=>r.studentId===s.studentId)||typeof s.comment!=='string'||s.comment.length>1000) throw Error('INVALID_INPUT');
      return {table:'PortalGradeDrafts',row:{id:lab2Hash_(cls.classId+'|'+s.studentId),classId:cls.classId,studentId:s.studentId,grades:JSON.stringify(portalGrades_(s.grades,components)),comment:s.comment}};
    });
    changes.push({table:'PortalGradebooks',row:{...state,components:JSON.stringify(components),version:Number(state.version)+1,updatedAt:new Date().toISOString(),updatedBy:actor.email}},portalAudit_(actor,cls.classId,cls.classId,'SAVE_GRADES',{version:Number(state.version)+1}));
    lab2Write_(book,changes);return {saved:true,version:Number(state.version)+1};
  }
  if(method==='publishGrades') {
    const key=portalKey_(d.requestKey),publications=lab2Read_(book,'PortalPublications');
    const retry=publications.find(p=>p.classId===cls.classId&&p.requestKey===key);
    if(retry) return {saved:true,publicationId:retry.id};
    portalVersion_(state,d.version);
    if(!Array.isArray(d.studentIds)||d.studentIds.length!==roster.length||new Set(d.studentIds).size!==roster.length||roster.some(s=>!d.studentIds.includes(s.studentId))) throw Error('ROSTER_CHANGED');
    const components=portalComponents_(JSON.parse(state.components)),drafts=lab2Read_(book,'PortalGradeDrafts').filter(r=>r.classId===cls.classId);
    if(!roster.length) throw Error('EMPTY_ROSTER');
    const id=Utilities.getUuid(),now=new Date().toISOString();
    const changes=roster.map(s=>{const r=drafts.find(r=>r.studentId===s.studentId);
      return {table:'PortalPublishedGrades',row:{id:lab2Hash_(id+'|'+s.studentId),publicationId:id,studentId:s.studentId,grades:JSON.stringify(portalGrades_(r?JSON.parse(r.grades):{},components)),comment:r?r.comment:''}};});
    changes.push({table:'PortalPublications',row:{id,classId:cls.classId,version:Number(state.version)+1,components:JSON.stringify(components),publishedAt:now,publishedBy:actor.email,requestKey:key}},
      {table:'PortalGradebooks',row:{...state,activePublicationId:id,version:Number(state.version)+1,updatedAt:now,updatedBy:actor.email}},
      portalAudit_(actor,cls.classId,id,'PUBLISH_GRADES',{students:roster.length,version:Number(state.version)+1}));
    lab2Write_(book,changes);return {saved:true,publicationId:id};
  }
  if(method==='revokeGrades') {
    portalVersion_(state,d.version);
    if(!state.activePublicationId) return {saved:true};
    lab2Write_(book,[{table:'PortalGradebooks',row:{...state,activePublicationId:'',version:Number(state.version)+1,updatedAt:new Date().toISOString(),updatedBy:actor.email}},portalAudit_(actor,cls.classId,state.activePublicationId,'REVOKE_GRADES',{})]);
    return {saved:true};
  }
  throw Error('UNKNOWN_PORTAL_METHOD');
}
