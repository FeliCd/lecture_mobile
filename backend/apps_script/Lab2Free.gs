/* Shared Desktop/Mobile Lab 2. No Cloud Functions, Firestore attendance writes,
 * service-account keys or client-supplied roles. Existing Sheets are authoritative.
 * Add this file to the existing Desktop Apps Script project and call setupLab2Free.
 */
const LAB2_TABLES = Object.freeze({
  Lab2SessionMeta: ['sessionId','title','opensAt','closesAt','lateThresholdAt','eligibleStudentIds'],
  Lab2SharedArticles: ['id','classId','articleId','article','sharedBy','note','sharedAt'],
  Lab2ArticleCache: ['id','article','subjectIds','expiresAt'],
  Lab2Feeds: ['id','feed','expiresAt'],
  AttendanceAudit: ['id','sessionId','studentId','actorUid','changedAt','oldStatus','newStatus','reason'],
  SubjectContentConfig: ['subjectCode','topicKeywords','excludeKeywords','sourceIds','enabled','updatedAt'],
  ContentSourceRegistry: ['sourceId','label','type','url','enabled'],
  SubjectContentCache: ['id','feed','expiresAt'],
  ScheduleExceptions: ['id','scheduleId','classId','date','kind','targetDate','slot','startTime','endTime','room','reason','createdBy','updatedAt'],
  RosterAudit: ['id','classId','studentId','actorUid','changedAt','oldValue','newValue','reason']
});
function setupLab2Free() {
  setupSheets(); // Existing owner's initializer only adds headers to completely empty tabs.
  const book = SpreadsheetApp.openById(config_().id);
  Object.keys(LAB2_TABLES).forEach(name => {
    const sheet = book.getSheetByName(name) || book.insertSheet(name);
    if (!sheet.getLastRow()) {
      sheet.getRange(1,1,1,LAB2_TABLES[name].length).setValues([LAB2_TABLES[name]]);
      sheet.setFrozenRows(1);
    }
    try {
      // These legacy caches are rebuildable and already tolerate bad IDs at runtime.
      // Setup must use the same policy so cache damage cannot stop new table creation.
      if (['Lab2Feeds','Lab2ArticleCache'].includes(name)) lab2ReadNewsCache_(book,name);
      else lab2Read_(book,name);
    } catch (error) {
      console.log(JSON.stringify({setupError: name, error: error.message,
        idIssues: lab2SheetIdIssues_(sheet.getDataRange().getDisplayValues())}));
      throw error;
    }
  });
  const health = lab2Health_();
  console.log(JSON.stringify(health));
  return health;
}
/** Row numbers only: never log IDs, emails, tokens or row contents. */
function lab2SheetIdIssues_(values) {
  const missing=[],ids=new Map();
  values.slice(1).forEach((row,i)=>{
    if(!row.some(v=>v!=='')) return;
    const physicalRow=i+2;
    if(!row[0]) missing.push(physicalRow);
    else {const group=ids.get(row[0])||[];group.push(physicalRow);ids.set(row[0],group);}
  });
  const duplicates=[...ids.values()].filter(group=>group.length>1);
  return {missingIdCount:missing.length,missingIdRows:missing.slice(0,100),
    duplicateGroupCount:duplicates.length,duplicateIdRows:duplicates.slice(0,100).map(group=>group.slice(0,100))};
}
/** Owner runs from editor. Read-only; not exposed by doPost. */
function diagnoseLab2Sheets() {
  const book=SpreadsheetApp.openById(config_().id),result=[];
  for(const [name,header] of Object.entries({...SCHEMA,...LAB2_TABLES})) {
    const sheet=book.getSheetByName(name);
    if(!sheet) {result.push({table:name,status:'MISSING_TABLE'});continue;}
    const values=sheet.getDataRange().getDisplayValues(),issues=lab2SheetIdIssues_(values);
    const schemaMatches=JSON.stringify(values[0])===JSON.stringify(header);
    result.push({table:name,status:!schemaMatches?'INVALID_SHEET_SCHEMA':
      issues.missingIdCount||issues.duplicateGroupCount?'INVALID_SHEET_IDS':'OK',
      rebuildableLegacyCache:['Lab2Feeds','Lab2ArticleCache'].includes(name),...issues});
  }
  console.log(JSON.stringify({sheetDiagnostics:result}));
  return result;
}
/** Owner-only editor check. Not exposed by doPost; prints counts, never roster or keys. */
function verifyLab2Free() {
  const book=SpreadsheetApp.openById(config_().id), tables={}, counts={};
  for(const name of ['Lecturers','Classes','Students','Enrollments','Sessions','Attendance','Lab2SessionMeta','Lab2SharedArticles']) {
    try { tables[name]=lab2Read_(book,name); counts[name]=tables[name].length; }
    catch(error) {
      console.log(JSON.stringify({schemaError:name,header:book.getSheetByName(name).getDataRange().getDisplayValues()[0]}));
      throw error;
    }
  }
  const cls=tables.Classes.find(c=>tables.Lecturers.some(l=>l.lecturerId===c.lecturerId));
  const news={};
  if(cls) {
    const lecturer=tables.Lecturers.find(l=>l.lecturerId===cls.lecturerId);
    const actor={role:'lecturer',entity:lecturer,uid:'lecturer-'+lecturer.lecturerId,email:lecturer.email};
    const snapshot=lab2SnapshotFrom_(tables,actor);
    counts.visibleClasses=snapshot.collections.classes.length;
    for(const source of ['OpenAlex','Crossref']) {
      try {const feed=lab2Discover_(book,actor,{subjectId:cls.subjectCode,source,page:1,sort:'recent'});
        news[source]={count:feed.articles.length,stale:feed.stale};}
      catch(error) {news[source]={error:error.message};}
    }
  }
  console.log(JSON.stringify({health:lab2Health_(),counts,news}));
}
function lab2Health_() {
  const p = PropertiesService.getScriptProperties();
  return {version: 'lab2-shared-sheets-v2', capabilities:['attendanceSafety','subjectInsights','scheduleExceptions','rosterAudit','scheduleDrivenSessions'], quizEnabled:false,
    firebaseProject:p.getProperty('LAB2_FIREBASE_PROJECT_ID') || 'fap-attendance-88920',
    authConfigured:!!p.getProperty('LAB2_FIREBASE_API_KEY'),
    openAlexConfigured:!!p.getProperty('OPENALEX_API_KEY')};
}
function lab2Read_(book,name) {
  if (!LAB2_TABLES[name]) return read_(book,name).rows;
  const sheet = book.getSheetByName(name);
  if (!sheet) throw Error('SHARED_BACKEND_SETUP_REQUIRED');
  const values = sheet.getDataRange().getDisplayValues(), header = LAB2_TABLES[name];
  if (JSON.stringify(values[0]) !== JSON.stringify(header)) throw Error('INVALID_SHEET_SCHEMA');
  const rows = values.slice(1).filter(r => r.some(v => v !== '')).map(r =>
    Object.fromEntries(header.map((h,i) => [h,r[i] || ''])));
  if (rows.some(r => !r[header[0]]) || new Set(rows.map(r => r[header[0]])).size !== rows.length)
    throw Error('INVALID_SHEET_IDS');
  return rows;
}
// News caches are rebuildable. Ignore invalid cache rows and choose the newest
// valid duplicate; identity, roster, attendance and shared articles stay strict.
function lab2ReadNewsCache_(book,name) {
  if (!['Lab2Feeds','Lab2ArticleCache'].includes(name)) throw Error('INVALID_INPUT');
  const sheet=book.getSheetByName(name);
  if(!sheet) throw Error('SHARED_BACKEND_SETUP_REQUIRED');
  const header=LAB2_TABLES[name], values=sheet.getDataRange().getDisplayValues();
  if(JSON.stringify(values[0])!==JSON.stringify(header)) throw Error('INVALID_SHEET_SCHEMA');
  const unique=new Map();
  for(const valuesRow of values.slice(1)) {
    const row=Object.fromEntries(header.map((h,i)=>[h,valuesRow[i]||'']));
    if(!row.id||!Number.isFinite(Number(row.expiresAt))) continue;
    try {
      const data=JSON.parse(name==='Lab2Feeds'?row.feed:row.article);
      if(name==='Lab2Feeds'?!data||!Array.isArray(data.articles):!data||!data.id||!Array.isArray(JSON.parse(row.subjectIds))) continue;
    } catch(_) {continue;}
    const previous=unique.get(row.id);
    if(!previous||Number(row.expiresAt)>=Number(previous.expiresAt)) unique.set(row.id,row);
  }
  return [...unique.values()];
}
function lab2Hash_(text) {
  return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256,text)
    .map(b => ('0'+((b+256)%256).toString(16)).slice(-2)).join('');
}
function lab2FirebaseIdentity_(token) {
  const p = PropertiesService.getScriptProperties();
  const key = p.getProperty('LAB2_FIREBASE_API_KEY');
  const project = p.getProperty('LAB2_FIREBASE_PROJECT_ID') || 'fap-attendance-88920';
  if (!key) throw Error('SHARED_BACKEND_SETUP_REQUIRED');
  if (typeof token !== 'string' || token.length > 10000 || token.split('.').length !== 3)
    throw Error('UNAUTHENTICATED');
  let claims;
  try { claims = JSON.parse(Utilities.newBlob(Utilities.base64DecodeWebSafe(token.split('.')[1])).getDataAsString()); }
  catch (_) { throw Error('UNAUTHENTICATED'); }
  if (claims.aud !== project || claims.iss !== 'https://securetoken.google.com/'+project ||
      !Number.isFinite(claims.exp) || claims.exp*1000 <= Date.now()) throw Error('UNAUTHENTICATED');
  const cache = CacheService.getScriptCache(), cacheKey = 'lab2auth:'+lab2Hash_(token);
  const cached = cache.get(cacheKey);
  if (cached) return JSON.parse(cached);
  // Google verifies the signature/token using this Firebase project's public API key.
  const response = UrlFetchApp.fetch('https://identitytoolkit.googleapis.com/v1/accounts:lookup?key='+encodeURIComponent(key), {
    method:'post', contentType:'application/json', payload:JSON.stringify({idToken:token}), muteHttpExceptions:true
  });
  if (response.getResponseCode() !== 200) throw Error('UNAUTHENTICATED');
  const users = JSON.parse(response.getContentText()).users || [];
  const user = users[0];
  if (users.length !== 1 || !user || user.localId !== claims.sub || user.disabled) throw Error('UNAUTHENTICATED');
  if (user.emailVerified !== true) throw Error('EMAIL_NOT_VERIFIED');
  const result = {firebaseUid:user.localId,email:String(user.email || '').trim().toLowerCase(),signInProvider:claims.firebase&&claims.firebase.sign_in_provider};
  if (!result.email) throw Error('UNAUTHENTICATED');
  cache.put(cacheKey,JSON.stringify(result),Math.max(1,Math.min(60,Math.floor(claims.exp-Date.now()/1000))));
  return result;
}
function lab2Actor_(identity,cfg,book) {
  if (!cfg.domains.includes(identity.email.split('@')[1])) throw Error('PERMISSION_DENIED');
  const teachers = lab2Read_(book,'Lecturers').filter(r => String(r.email).trim().toLowerCase() === identity.email);
  if (teachers.length > 1) throw Error('DUPLICATE_PROFILE');
  if (teachers.length === 1) return {...identity,role:'lecturer',entity:teachers[0],uid:'lecturer-'+teachers[0].lecturerId};
  const students = lab2Read_(book,'Students').filter(r => String(r.schoolEmail).trim().toLowerCase() === identity.email);
  if (students.length !== 1) throw Error('PROFILE_NOT_REGISTERED');
  return {...identity,role:'student',entity:students[0],uid:'student-'+students[0].studentId};
}
function lab2Limit_(uid,action) {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(15000)) throw Error('RATE_LIMITED');
  try {
    const cache = CacheService.getScriptCache(), key = 'lab2rate:'+lab2Hash_(uid+':'+action);
    const now = Date.now();
    let window = JSON.parse(cache.get(key) || 'null');
    if (!window || now-window.start >= 60000) window = {start:now,count:0};
    if (window.count >= (['discoverArticles','getSubjectUpdates','studentCheckIn'].includes(action) ? 12 : 60)) throw Error('RATE_LIMITED');
    window.count++;
    cache.put(key,JSON.stringify(window),Math.max(1,Math.ceil((window.start+60000-now)/1000)));
  } finally { lock.releaseLock(); }
}
function lab2Class_(book,actor,id,teacherOnly) {
  const cls = lab2Read_(book,'Classes').find(c => c.classId === id);
  if (!cls) throw Error('PERMISSION_DENIED');
  if (actor.role === 'lecturer') {
    if (cls.lecturerId !== actor.entity.lecturerId) throw Error('PERMISSION_DENIED');
  } else if (teacherOnly || !lab2Read_(book,'Enrollments').some(e => e.classId === id && e.studentId === actor.entity.studentId)) {
    throw Error('NOT_ENROLLED');
  }
  return cls;
}
function lab2Write_(book,changes) {
  const requests = [], nextRows = {}, indexes = {}, capacities = {};
  for (const change of changes) {
    const header = LAB2_TABLES[change.table] || SCHEMA[change.table];
    if (!header) throw Error('INVALID_INPUT');
    const sheet = book.getSheetByName(change.table);
    if (!indexes[change.table]) {
      if (['Lab2Feeds','Lab2ArticleCache'].includes(change.table)) lab2ReadNewsCache_(book,change.table);
      else lab2Read_(book,change.table);
      const physicalRows=sheet.getDataRange().getDisplayValues().slice(1);
      indexes[change.table]=new Map(physicalRows.map((r,i)=>[r[0],i]));
      capacities[change.table]=sheet.getMaxRows();
    }
    const existing=indexes[change.table].get(String(change.row[header[0]]));
    const index=existing==null?-1:existing;
    const rowIndex = index < 0 ? (nextRows[change.table] || sheet.getLastRow()) : index+1;
    if (index < 0) nextRows[change.table] = rowIndex+1;
    if (index < 0) indexes[change.table].set(String(change.row[header[0]]),rowIndex-1);
    if (rowIndex+1 > capacities[change.table]) {
      requests.push({appendDimension:{sheetId:sheet.getSheetId(),dimension:'ROWS',length:rowIndex+1-capacities[change.table]}});
      capacities[change.table]=rowIndex+1;
    }
    requests.push({updateCells:{range:{sheetId:sheet.getSheetId(),startRowIndex:rowIndex,endRowIndex:rowIndex+1,
      startColumnIndex:0,endColumnIndex:header.length},rows:[{values:header.map(k =>
        ({userEnteredValue:{stringValue:String(change.row[k] == null ? '' : change.row[k])}}))}],fields:'userEnteredValue'}});
  }
  if (requests.length) Sheets.Spreadsheets.batchUpdate({requests},book.getId());
}
function lab2Millis_(date,time) {
  const value = Date.parse(String(date)+'T'+String(time || '00:00')+':00+07:00');
  if (!Number.isFinite(value)) throw Error('INVALID_SESSION_DATE');
  return value;
}
function lab2Meta_(book,session) {
  const stored = lab2Read_(book,'Lab2SessionMeta').find(m => m.sessionId === session.sessionId);
  if (stored) return {...stored,opensAt:Number(stored.opensAt),closesAt:Number(stored.closesAt),lateThresholdAt:Number(stored.lateThresholdAt),
    eligibleStudentIds:JSON.parse(stored.eligibleStudentIds)};
  // Desktop legacy sessions have no late threshold or historical membership snapshot.
  return {sessionId:session.sessionId,title:'Slot '+session.slot,opensAt:lab2Millis_(session.date,session.startTime),
    closesAt:lab2Millis_(session.date,session.endTime)+(session.endTime<session.startTime?86400000:0),lateThresholdAt:null,eligibleStudentIds:null};
}
function lab2Finalize_(book,session) {
  if (session.status !== 'OPEN') return;
  const meta = lab2Meta_(book,session);
  const eligible = meta.eligibleStudentIds || lab2Read_(book,'Attendance').filter(e => e.sessionId === session.sessionId).map(e => e.studentId);
  if (eligible.length > 400) throw Error('CLASS_TOO_LARGE');
  const attendance = lab2Read_(book,'Attendance').filter(a => a.sessionId === session.sessionId);
  const now = new Date().toISOString();
  const changes = [{table:'Sessions',row:{...session,status:'CLOSED',currentToken:'',tokenExpiredAt:''}}];
  for (const id of new Set(eligible)) if (!attendance.some(a => a.studentId === id)) {
    changes.push({table:'Attendance',row:{attendanceId:Utilities.getUuid(),sessionId:session.sessionId,studentId:id,
      status:'ABSENT',checkInTime:'',updatedAt:now,note:'Lab2 finalized',updatedBy:session.createdBy}});
  }
  lab2Write_(book,changes);
}
function lab2EffectiveRoom_(tables,session,cls) {
  const changes=(tables.ScheduleExceptions||[]).filter(e=>e.classId===cls.classId);
  const exception=changes.filter(e=>e.targetDate===session.date&&String(e.slot)===String(session.slot)&&['MAKEUP','RESCHEDULED'].includes(e.kind));
  if(exception.length===1) return exception[0].room||'';
  const bases=(tables.Schedules||[]).filter(s=>s.lecturerId===cls.lecturerId&&s.semester===cls.semester&&s.classCode===cls.classCode&&s.subjectCode===cls.subjectCode&&String(s.slot)===String(session.slot)&&Number(s.dayOfWeek)===lab2Day_(session.date));
  if(bases.length!==1) return '';
  const overrides=changes.filter(e=>e.scheduleId===bases[0].scheduleId&&e.date===session.date&&['ROOM_CHANGED','RESTORED'].includes(e.kind));
  return overrides.length===1?overrides[0].room||'':bases[0].room||'';
}
function lab2SnapshotFrom_(tables,actor) {
  const classes = tables.Classes.filter(c => actor.role === 'lecturer' ? c.lecturerId === actor.entity.lecturerId :
    tables.Enrollments.some(e => e.classId === c.classId && e.studentId === actor.entity.studentId));
  const ids = new Set(classes.map(c => c.classId));
  const subjects = [...new Set(classes.map(c => c.subjectCode))];
  const c = {classes:[],subjects:subjects.map(id => ({id,code:id,name:classes.find(x=>x.subjectCode===id).subjectName,active:true})),
    schedules:[],classSessions:[],attendanceSessions:[],attendanceRecords:[],sharedArticles:[]};
  if (actor.role === 'lecturer') {
    c.schedules = (tables.Schedules || []).filter(s => s.lecturerId === actor.entity.lecturerId).map(s => {
      const matches = classes.filter(x => x.semester === s.semester && x.subjectCode === s.subjectCode && x.classCode === s.classCode);
      return {id:s.scheduleId,lecturerUid:actor.uid,classId:matches.length === 1 ? matches[0].classId : null,
        term:s.semester,subjectId:s.subjectCode,subjectName:s.subjectName,classCode:s.classCode,
        dayOfWeek:Number(s.dayOfWeek),slot:Number(s.slot),startTime:s.startTime,endTime:s.endTime,room:s.room};
    });
  }
  for (const cls of classes) {
    const students = tables.Students.filter(s => tables.Enrollments.some(e => e.classId===cls.classId && e.studentId===s.studentId));
    c.classes.push({id:cls.classId,classCode:cls.classCode,subjectId:cls.subjectCode,subjectName:cls.subjectName,term:cls.semester,
      lecturerUids:['lecturer-'+cls.lecturerId],studentUids:actor.role==='lecturer'?students.map(s=>'student-'+s.studentId):[actor.uid],
      studentCount:students.length,status:'active'});
    c['classes/'+cls.classId+'/members'] = students.filter(s => actor.role==='lecturer'||s.studentId===actor.entity.studentId)
      .map(s=>({id:'student-'+s.studentId,studentUid:'student-'+s.studentId,studentCode:s.studentCode,displayName:s.fullName,schoolEmail:s.schoolEmail,active:true}));
  }
  for (const s of tables.Sessions.filter(s => ids.has(s.classId) && s.status !== 'RESET')) {
    const cls = classes.find(x => x.classId === s.classId);
    const records = tables.Attendance.filter(a => a.sessionId === s.sessionId);
    const raw = tables.Lab2SessionMeta.find(m => m.sessionId === s.sessionId);
    const eligible = raw ? JSON.parse(raw.eligibleStudentIds) : s.status==='CLOSED' ?
      [...new Set(records.map(a=>a.studentId))] : tables.Enrollments.filter(e=>e.classId===s.classId).map(e=>e.studentId);
    const opens = raw ? Number(raw.opensAt) : lab2Millis_(s.date,s.startTime);
    const closes = raw ? Number(raw.closesAt) : lab2Millis_(s.date,s.endTime)+(s.endTime<s.startTime?86400000:0);
    const room=lab2EffectiveRoom_(tables,s,cls);
    c.classSessions.push({id:s.sessionId,classId:s.classId,subjectId:cls.subjectCode,subjectName:cls.subjectName,classCode:cls.classCode,title:raw?raw.title:'Slot '+s.slot,
      room,lecturerUid:'lecturer-'+cls.lecturerId,slot:Number(s.slot),startsAt:lab2Millis_(s.date,s.startTime),endsAt:lab2Millis_(s.date,s.endTime)+(s.endTime<s.startTime?86400000:0),
      status:s.status==='CLOSED'?'completed':'scheduled'});
    c.attendanceSessions.push({id:s.sessionId,classId:s.classId,classSessionId:s.sessionId,subjectId:cls.subjectCode,subjectName:cls.subjectName,classCode:cls.classCode,room,slot:Number(s.slot),opensAt:opens,closesAt:closes,
      lateThresholdAt:raw?Number(raw.lateThresholdAt):null,status:s.status==='CLOSED'?'finalized':'open',
      eligibleStudentUids:eligible.filter(id=>actor.role==='lecturer'||id===actor.entity.studentId).map(id=>'student-'+id),
      checkedInCount:records.filter(a=>['PRESENT','LATE'].includes(a.status)&&(actor.role==='lecturer'||a.studentId===actor.entity.studentId)).length,
      eligibleCount:eligible.filter(id=>actor.role==='lecturer'||id===actor.entity.studentId).length,
      membershipKnown:!!raw,qrRotationSeconds:null});
    for (const a of records.filter(a => actor.role==='lecturer'||a.studentId===actor.entity.studentId)) {
      if (!['PRESENT','LATE','ABSENT','EXCUSED'].includes(a.status)) continue;
      c.attendanceRecords.push({id:s.sessionId+'_student-'+a.studentId,classId:s.classId,classSessionId:s.sessionId,
        attendanceSessionId:s.sessionId,studentUid:'student-'+a.studentId,subjectId:cls.subjectCode,subjectName:cls.subjectName,slot:Number(s.slot),status:a.status.toLowerCase(),
        checkedInAt:a.checkInTime?Date.parse(a.checkInTime):null,recordedAt:Date.parse(a.updatedAt)||opens,notes:a.note||''});
    }
  }
  c.sharedArticles = tables.Lab2SharedArticles.filter(r=>ids.has(r.classId)).map(r=>
    ({...JSON.parse(r.article),id:r.id,classId:r.classId,articleId:r.articleId,sharedBy:r.sharedBy,note:r.note,sharedAt:Number(r.sharedAt)}));
  c.scheduleExceptions=(tables.ScheduleExceptions||[]).filter(r=>ids.has(r.classId));
  return {version:'lab2-shared-sheets-v1',syncedAt:Date.now(),profile:{uid:actor.uid,firebaseUid:actor.firebaseUid,
    displayName:actor.entity.fullName,email:actor.email,lecturerId:actor.role==='lecturer'?actor.entity.lecturerId:'',department:actor.entity.department||'',role:actor.role,active:true,subjectIds:subjects,attendancePolicy:lab2Policy_()},collections:c};
}
function lab2Snapshot_(book,actor) {
  const tables = {};
  for (const name of ['Schedules','Classes','Students','Enrollments','Sessions','Attendance','Lab2SessionMeta','Lab2SharedArticles','ScheduleExceptions']) tables[name]=lab2Read_(book,name);
  const allowed = new Set(tables.Classes.filter(c => actor.role==='lecturer' ? c.lecturerId===actor.entity.lecturerId :
    tables.Enrollments.some(e=>e.classId===c.classId&&e.studentId===actor.entity.studentId)).map(c=>c.classId));
  const expired = tables.Sessions.filter(s=>s.status==='OPEN'&&allowed.has(s.classId)&&
    tables.Lab2SessionMeta.some(m=>m.sessionId===s.sessionId&&Number(m.closesAt)<=Date.now()));
  if (expired.length) {
    const lock=LockService.getScriptLock();
    if(!lock.tryLock(15000)) throw Error('RATE_LIMITED');
    try {
      for(const old of expired) {
        const current=lab2Read_(book,'Sessions').find(s=>s.sessionId===old.sessionId);
        if(current&&current.status==='OPEN') lab2Finalize_(book,current);
      }
      tables.Sessions=lab2Read_(book,'Sessions');
      tables.Attendance=lab2Read_(book,'Attendance');
    } finally { lock.releaseLock(); }
  }
  return lab2SnapshotFrom_(tables,actor);
}
function lab2ImportTimetable_(book,actor,d) {
  if(actor.role!=='lecturer') throw Error('PERMISSION_DENIED');
  if(!Array.isArray(d.schedules)||!d.schedules.length||d.schedules.length>100) throw Error('INVALID_INPUT');
  const schedules=lab2Read_(book,'Schedules'), classes=lab2Read_(book,'Classes'), changes=[], seen=new Set();
  const owner=actor.entity.lecturerId, time=/^(?:[01]\d|2[0-3]):[0-5]\d$/;
  for(const raw of d.schedules) {
    const row={};
    for(const k of ['semester','subjectCode','subjectName','classCode','startTime','endTime','room']) row[k]=String(raw[k]||'').trim();
    for(const k of ['semester','subjectCode','classCode']) row[k]=row[k].toUpperCase();
    const day=Number(raw.dayOfWeek),slot=Number(raw.slot);
    if(['semester','subjectCode','classCode'].some(k=>!row[k]||row[k].length>100)||row.subjectName.length>200||row.room.length>100||
      !Number.isInteger(day)||day<1||day>7||!Number.isInteger(slot)||slot<1||slot>12||
      !time.test(row.startTime)||!time.test(row.endTime)||row.startTime===row.endTime) throw Error('INVALID_INPUT');
    const match=c=>['semester','subjectCode','classCode'].every(k=>String(c[k]).trim().toUpperCase()===row[k]);
    const key=[row.semester,row.subjectCode,row.classCode,day,slot].join('|');
    if(seen.has(key)) throw Error('INVALID_INPUT');
    seen.add(key);
    const classMatches=classes.filter(match);
    if(classMatches.some(c=>c.lecturerId!==owner)) throw Error('PERMISSION_DENIED');
    if(classMatches.length>1) throw Error('INVALID_SHEET_IDS');
    if(!classMatches.length) {
      const cls={classId:Utilities.getUuid(),semester:row.semester,subjectCode:row.subjectCode,
        subjectName:row.subjectName||row.subjectCode,classCode:row.classCode,lecturerId:owner};
      classes.push(cls);changes.push({table:'Classes',row:cls});
    }
    const matches=schedules.filter(s=>s.lecturerId===owner&&match(s)&&Number(s.dayOfWeek)===day&&Number(s.slot)===slot);
    if(matches.length>1) throw Error('INVALID_SHEET_IDS');
    changes.push({table:'Schedules',row:{...row,scheduleId:matches[0]?matches[0].scheduleId:Utilities.getUuid(),
      lecturerId:owner,dayOfWeek:day,slot,sourceType:'MANUAL'}});
  }
  lab2Write_(book,changes);
  return {saved:d.schedules.length};
}
function lab2ImportStudents_(book,actor,d) {
  if(actor.role!=='lecturer') throw Error('PERMISSION_DENIED');
  const cls=lab2Class_(book,actor,d.classId,true);
  if(!Array.isArray(d.students)||!d.students.length||d.students.length>400) throw Error('INVALID_INPUT');
  const state={classes:lab2Read_(book,'Classes'),students:lab2Read_(book,'Students'),
    enrollments:lab2Read_(book,'Enrollments'),schedules:lab2Read_(book,'Schedules')};
  const next=importRoster_({...cls,students:d.students},state,actor.entity,()=>Utilities.getUuid());
  const size=next.enrollments.filter(e=>e.classId===cls.classId).length;
  if(size>400) throw Error('CLASS_TOO_LARGE');
  const changes=[];
  for(const [table,old,rows] of [['Classes',state.classes,next.classes],['Students',state.students,next.students],['Enrollments',state.enrollments,next.enrollments]])
    for(const row of rows.slice(old.length)) changes.push({table,row});
  lab2Write_(book,changes);
  return {added:next.added,existing:next.existing};
}
function lab2Mutate_(book,actor,name,d) {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(15000)) throw Error('RATE_LIMITED');
  try {
    if(name==='importTimetable') return lab2ImportTimetable_(book,actor,d);
    if(name==='importClassStudents') return lab2ImportStudents_(book,actor,d);
    if(name==='saveScheduleException') return lab2SaveException_(book,actor,d);
    if(name==='updateClassStudent') return lab2UpdateStudent_(book,actor,d);
    if (name==='createClassSession') {
      return lab2CreateFromOccurrence_(book,actor,d);
    }
    if(name==='submitQuickAttendance') return lab2QuickSubmit_(book,actor,d);
    if(name==='checkInWithQr') {
      if(actor.role!=='student') throw Error('PERMISSION_DENIED');
      const text=String(d.token||'');
      if(text.length>2000) throw Error('QR_INVALID');
      const params={};
      text.replace(/[?&]([^=&]+)=([^&]*)/g,(_,k,v)=>{ params[decodeURIComponent(k)]=decodeURIComponent(v); return ''; });
      if(!params.sessionId||!params.token) throw Error('QR_INVALID');
      const s=lab2Read_(book,'Sessions').find(s=>s.sessionId===params.sessionId);
      if(!s) throw Error('QR_INVALID');
      lab2Class_(book,actor,s.classId,false);
      const meta=lab2Meta_(book,s), view=sessionView_(s), now=Date.now();
      if(s.status!=='OPEN'||now>=meta.closesAt) throw Error('SESSION_CLOSED');
      if(meta.eligibleStudentIds&&!meta.eligibleStudentIds.includes(actor.entity.studentId)) throw Error('NOT_ENROLLED');
      if(!Number.isFinite(Date.parse(s.tokenExpiredAt))||now>=Date.parse(s.tokenExpiredAt)) throw Error('QR_EXPIRED');
      if(!view.currentToken||params.token!==view.currentToken) throw Error('QR_INVALID');
      if(view.currentSecretCode) {
        if(!d.secretCode) throw Error('SECRET_REQUIRED');
        if(String(d.secretCode).trim()!==view.currentSecretCode) throw Error('SECRET_INVALID');
      }
      const previous=lab2Read_(book,'Attendance').filter(a=>a.sessionId===s.sessionId&&a.studentId===actor.entity.studentId);
      if(previous.length>1) throw Error('INVALID_SHEET_IDS');
      if(previous.length) { if(!['PRESENT','LATE'].includes(previous[0].status)) throw Error('ATTENDANCE_ADJUSTED'); return {status:previous[0].status.toLowerCase(),checkedInAt:Date.parse(previous[0].checkInTime),alreadyRecorded:true}; }
      const status='PRESENT';
      lab2Write_(book,[{table:'Attendance',row:{attendanceId:Utilities.getUuid(),sessionId:s.sessionId,studentId:actor.entity.studentId,
        status,checkInTime:new Date(now).toISOString(),updatedAt:new Date(now).toISOString(),note:'Firebase verified; Mobile Lab2',updatedBy:actor.email}}]);
      return {status:status.toLowerCase(),checkedInAt:now};
    }
    if(actor.role!=='lecturer') throw Error('PERMISSION_DENIED');
    const sessionId=d.attendanceSessionId||d.classSessionId;
    const s=lab2Read_(book,'Sessions').find(s=>s.sessionId===sessionId);
    if(!s) throw Error('PERMISSION_DENIED');
    lab2Class_(book,actor,s.classId,true);
    if(name==='updateAttendanceRecord') {
      if(s.status==='RESET') throw Error('SESSION_CLOSED');
      const status=String(d.status||'').toUpperCase(), notes=String(d.notes||'').trim();
      const studentId=String(d.studentUid||'').replace(/^student-/, '');
      if(!['PRESENT','LATE','ABSENT','EXCUSED'].includes(status)||notes.length>500||!notes) throw Error('INVALID_INPUT');
      const meta=lab2Meta_(book,s);
      const eligible=meta.eligibleStudentIds || lab2Read_(book,'Enrollments').filter(e=>e.classId===s.classId).map(e=>e.studentId);
      const previous=lab2Read_(book,'Attendance').filter(a=>a.sessionId===s.sessionId&&a.studentId===studentId);
      if(previous.length>1) throw Error('INVALID_SHEET_IDS');
      if(!eligible.includes(studentId)&&!previous.length) throw Error('NOT_ENROLLED');
      const old=previous[0], now=new Date().toISOString();
      lab2Correct_(book,actor,s,studentId,status,notes,old);
      return {updated:true};
    }
    if(name==='closeAttendanceSession') { if(s.status==='RESET') throw Error('SESSION_CLOSED'); lab2Finalize_(book,s); return {closed:true}; }
    const meta=lab2Meta_(book,s), now=Date.now();
    if(s.status!=='OPEN'||now>=meta.closesAt) throw Error('SESSION_CLOSED');
    if(name==='openAttendanceSession') return {attendanceSessionId:s.sessionId};
    if(name==='rotateAttendanceQr') {
      if(d.secretEnabled!=null&&typeof d.secretEnabled!=='boolean') throw Error('INVALID_INPUT');
      const old=sessionView_(s), enabled=d.secretEnabled==null?!!old.currentSecretCode:d.secretEnabled;
      const secret=enabled?(d.secretEnabled==null&&old.currentSecretCode?old.currentSecretCode:String(parseInt(Utilities.getUuid().replace(/-/g,'').slice(0,8),16)%1000000).padStart(6,'0')):'';
      const token=Utilities.getUuid()+Utilities.getUuid(), expiry=Math.min(now+4*60*60000,meta.closesAt);
      lab2Write_(book,[{table:'Sessions',row:{...s,currentToken:token+(secret?'#'+secret:''),tokenExpiredAt:new Date(expiry).toISOString()}}]);
      return {updated:true};
    }
    if(name==='getQrToken') {
      let view=sessionView_(s), expiry=Date.parse(s.tokenExpiredAt);
      if(!view.currentToken||!Number.isFinite(expiry)||now>=expiry) {
        expiry=Math.min(now+4*60*60000,meta.closesAt);
        const value=Utilities.getUuid()+Utilities.getUuid();
        lab2Write_(book,[{table:'Sessions',row:{...s,currentToken:value+(view.currentSecretCode?'#'+view.currentSecretCode:''),tokenExpiredAt:new Date(expiry).toISOString()}}]);
        view={...view,currentToken:value};
      }
      const base=PropertiesService.getScriptProperties().getProperty('LAB2_CHECKIN_URL')||'https://fap-attendance-88920.web.app/checkin';
      return {token:base+(base.includes('?')?'&':'?')+'sessionId='+encodeURIComponent(s.sessionId)+'&token='+encodeURIComponent(view.currentToken)+
        '&mode='+(view.currentSecretCode?'google-secret':'google')+'&v=5',secretEnabled:!!view.currentSecretCode,secretCode:view.currentSecretCode,
        expiresAt:Math.min(expiry,meta.closesAt),serverNow:now};
    }
    throw Error('FEATURE_DISABLED');
  } finally { lock.releaseLock(); }
}
function lab2Abstract_(item) {
  if(typeof item.abstract==='string') return item.abstract.replace(/<[^>]*>/g,' ').replace(/\s+/g,' ').trim().slice(0,12000)||null;
  const index=item.abstract_inverted_index;
  if(!index||typeof index!=='object') return null;
  const words=new Map();
  for(const [word,positions] of Object.entries(index)) if(Array.isArray(positions))
    for(const position of positions) if(Number.isInteger(position)&&position>=0&&position<3000) words.set(position,word);
  return [...words.entries()].sort((a,b)=>a[0]-b[0]).map(e=>e[1]).join(' ').slice(0,12000)||null;
}
function lab2Discover_(book,actor,d) {
  const classes=lab2Read_(book,'Classes').filter(c=>c.subjectCode===d.subjectId);
  if(!classes.some(c=>actor.role==='lecturer'?c.lecturerId===actor.entity.lecturerId:
      lab2Read_(book,'Enrollments').some(e=>e.classId===c.classId&&e.studentId===actor.entity.studentId))) throw Error('PERMISSION_DENIED');
  const source=d.source, page=Number(d.page||1), sort=d.sort||'recent';
  if(!['OpenAlex','Crossref'].includes(source)||!['recent','relevance'].includes(sort)||!Number.isInteger(page)||page<1||page>50) throw Error('INVALID_INPUT');
  const keywords={PRM393:'Flutter Dart mobile development',PRN212:'ASP.NET Core',SWE201c:'software engineering'};
  const query=String(d.query||keywords[d.subjectId]||classes[0].subjectName).trim();
  if(!query||query.length>150||d.fromDate&&!/^\d{4}-\d{2}-\d{2}$/.test(d.fromDate)) throw Error('INVALID_INPUT');
  const hash=lab2Hash_(JSON.stringify([d.subjectId,source,query,page,sort,d.fromDate||'']));
  const cached=lab2ReadNewsCache_(book,'Lab2Feeds').find(r=>r.id===hash), now=Date.now();
  if(cached&&Number(cached.expiresAt)>now) return {...JSON.parse(cached.feed),cached:true,stale:false};
  const props=PropertiesService.getScriptProperties(), headers={};
  let url;
  if(source==='OpenAlex') {
    const key=props.getProperty('OPENALEX_API_KEY'); if(!key) throw Error('OPENALEX_SETUP_REQUIRED');
    headers.Authorization='Bearer '+key;
    url='https://api.openalex.org/works?search='+encodeURIComponent(query)+'&per_page=20&page='+page+
      '&sort='+(sort==='recent'?'publication_date:desc':'relevance_score:desc')+(d.fromDate?'&filter=from_publication_date:'+d.fromDate:'');
  } else {
    url='https://api.crossref.org/works?query='+encodeURIComponent(query)+'&rows=20&offset='+((page-1)*20)+
      '&sort='+(sort==='recent'?'published':'relevance')+'&order=desc'+(d.fromDate?'&filter=from-pub-date:'+d.fromDate:'');
  }
  try {
    const response=UrlFetchApp.fetch(url,{headers,muteHttpExceptions:true});
    if(response.getResponseCode()!==200) throw Error('ARTICLE_SOURCE_UNAVAILABLE');
    const json=JSON.parse(response.getContentText()), items=source==='OpenAlex'?json.results:json.message.items;
    const unique={};
    for(const item of items) {
      const doi=String(item.doi||item.DOI||'').replace(/^https?:\/\/(?:dx\.)?doi.org\//i,'').trim().toLowerCase();
      const rawUrl=doi?'https://doi.org/'+doi:source==='OpenAlex'?((item.primary_location||{}).landing_page_url||item.id):item.URL;
      const title=source==='OpenAlex'?item.display_name:(item.title||[])[0];
      if(!title||!/^https:\/\/[^\s@]+$/i.test(rawUrl||'')) continue;
      const id=lab2Hash_(doi||rawUrl);
      const parts=((item.published||item['published-print']||item['published-online']||{})['date-parts']||[])[0];
      const date=source==='OpenAlex'?item.publication_date:parts?parts.map((n,i)=>i?String(n).padStart(2,'0'):String(n)).join('-'):null;
      unique[id]={id,doi:doi||null,title:String(title).slice(0,500),url:rawUrl,source,
        publisher:String(source==='OpenAlex'?(((item.primary_location||{}).source||{}).display_name||''):item.publisher||'').slice(0,200),
        authors:(source==='OpenAlex'?(item.authorships||[]).map(a=>(a.author||{}).display_name):(item.author||[]).map(a=>[a.given,a.family].filter(Boolean).join(' '))).filter(Boolean).slice(0,12),
        publishedAt:date,abstractSnippet:lab2Abstract_(item),subjectIds:[d.subjectId]};
    }
    const articles=Object.values(unique), feed={articles,nextPage:items.length===20?page+1:null,fetchedAt:now,expiresAt:now+21600000};
    let cacheSaved=true;
    try {
    const lock=LockService.getScriptLock(); if(!lock.tryLock(15000)) throw Error('RATE_LIMITED');
    try {
      const previous=lab2ReadNewsCache_(book,'Lab2ArticleCache');
      if(previous.length>2000) throw Error('ARTICLE_CACHE_FULL');
      lab2Write_(book,[{table:'Lab2Feeds',row:{id:hash,feed:JSON.stringify(feed),expiresAt:feed.expiresAt}},...articles.map(a=>{
        const old=previous.find(r=>r.id===a.id); const subjects=[...new Set([...(old?JSON.parse(old.subjectIds):[]),d.subjectId])];
        return {table:'Lab2ArticleCache',row:{id:a.id,article:JSON.stringify(a),subjectIds:JSON.stringify(subjects),expiresAt:feed.expiresAt}};
      })]);
    } finally { lock.releaseLock(); }
    } catch(_) {cacheSaved=false;}
    return {...feed,articles:cacheSaved?articles:articles.map(a=>({...a,canShare:false})),cached:false,stale:false,cacheSaved};
  } catch(_) { if(cached) return {...JSON.parse(cached.feed),cached:true,stale:true}; throw Error('ARTICLE_SOURCE_UNAVAILABLE'); }
}
function lab2Share_(book,actor,d) {
  const cls=lab2Class_(book,actor,d.classId,true), note=String(d.note||'').trim();
  if(note.length>500) throw Error('INVALID_INPUT');
  const article=lab2ReadNewsCache_(book,'Lab2ArticleCache').find(a=>a.id===d.articleId&&JSON.parse(a.subjectIds).includes(cls.subjectCode));
  if(!article) throw Error('INVALID_INPUT');
  const lock=LockService.getScriptLock(); if(!lock.tryLock(15000)) throw Error('RATE_LIMITED');
  try { lab2Write_(book,[{table:'Lab2SharedArticles',row:{id:d.classId+'_'+article.id,classId:d.classId,
    articleId:article.id,article:article.article,sharedBy:actor.uid,note,sharedAt:Date.now()}}]); return {shared:true}; }
  finally { lock.releaseLock(); }
}
function lab2Handle_(request) {
  if(request.action==='lab2Health') return lab2Health_();
  const cfg=config_(), book=SpreadsheetApp.openById(cfg.id);
  const identity=lab2FirebaseIdentity_(request.idToken), actor=lab2Actor_(identity,cfg,book);
  const name=request.action==='lab2Snapshot'?'snapshot':request.name;
  lab2Limit_(actor.firebaseUid,name);
  if(name==='snapshot') {
    if(request.googleLecturerOnly===true) {
      if(identity.signInProvider!=='google.com') throw Error('GOOGLE_ONLY');
      if(actor.role!=='lecturer') throw Error('LECTURER_REQUIRED');
    }
    return lab2Snapshot_(book,actor);
  }
  const d=request.input;
  if(!d||typeof d!=='object'||Array.isArray(d)) throw Error('INVALID_INPUT');
  if(name==='discoverArticles') return lab2Discover_(book,actor,d);
  if(name==='shareArticle') return lab2Share_(book,actor,d);
  if(name==='getTeachingOccurrence') return lab2OccurrenceView_(book,actor,d);
  if(name==='getAttendanceSessionLive') return lab2Live_(book,actor,d);
  if(name==='getQuickAttendanceContext') return lab2QuickContext_(book,actor,d);
  if(name==='getSubjectUpdates') return subjectUpdates_(book,actor,d);
  if(name==='getSubjectTopics') return subjectTopics_(book,actor,d);
  if(!['createClassSession','openAttendanceSession','getQrToken','checkInWithQr','closeAttendanceSession','rotateAttendanceQr','updateAttendanceRecord','submitQuickAttendance','importTimetable','importClassStudents','saveScheduleException','updateClassStudent'].includes(name)) throw Error('FEATURE_DISABLED');
  return lab2Mutate_(book,actor,name,d);
}



