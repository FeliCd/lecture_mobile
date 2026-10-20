const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

function fixture(now) {
  let clock=now==null?null:Date.parse(now);
  class ServerDate extends Date {constructor(...args){super(...(args.length?args:[clock==null?Date.now():clock]));} static now(){return clock==null?Date.now():clock;} }
  const c = vm.createContext({Date:ServerDate, console});
  const desktop = path.resolve(__dirname, '../apps_script/Code.gs');
  vm.runInContext(fs.readFileSync(desktop,'utf8'),c);
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../apps_script/Lab2Free.gs'),'utf8'),c);
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../apps_script/AttendanceSafety.gs'),'utf8'),c);
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../apps_script/SubjectInsights.gs'),'utf8'),c);
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../apps_script/ClassTools.gs'),'utf8'),c);
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../apps_script/ScheduleAttendance.gs'),'utf8'),c);
  const schemas = vm.runInContext('({...SCHEMA,...LAB2_TABLES})',c);
  const store = Object.fromEntries(Object.entries(schemas).map(([k,v])=>[k,[Array.from(v)]]));
  const add = (table,row) => store[table].push(Array.from(schemas[table],k=>String(row[k]??'')));
  add('Lecturers',{lecturerId:'l1',fullName:'Teacher',email:'teacher@fpt.edu.vn'});
  add('Lecturers',{lecturerId:'l2',email:'other@fpt.edu.vn'});
  add('Students',{studentId:'s1',studentCode:'SE1',fullName:'Student',schoolEmail:'student@fpt.edu.vn'});
  add('Students',{studentId:'s2',studentCode:'SE2',fullName:'Other',schoolEmail:'other-student@fpt.edu.vn'});
  add('Classes',{classId:'c1',lecturerId:'l1',classCode:'SE1',subjectCode:'PRM393',subjectName:'Mobile'});
  add('Classes',{classId:'c2',lecturerId:'l2',classCode:'SE2',subjectCode:'PRN212'});
  add('Enrollments',{enrollmentId:'e1',classId:'c1',studentId:'s1'});
  add('Enrollments',{enrollmentId:'e2',classId:'c1',studentId:'s2'});
  const sheetNames = Object.keys(store);
  const sheet = name => ({getDataRange:()=>({getDisplayValues:()=>store[name].map(r=>r.slice())}),
    getLastRow:()=>store[name].length,getMaxRows:()=>1000,getSheetId:()=>sheetNames.indexOf(name)});
  const book = {getId:()=> 'book',getSheetByName:sheet};
  const props = {SPREADSHEET_ID:'book',GOOGLE_CLIENT_ID:'desktop',LAB2_FIREBASE_API_KEY:'public-test-key'};
  c.PropertiesService = {getScriptProperties:()=>({getProperty:k=>props[k]??null})};
  c.SpreadsheetApp = {openById:()=>book};
  c.LockService = {getScriptLock:()=>({tryLock:()=>true,releaseLock(){}})};
  const cache = new Map();
  c.CacheService = {getScriptCache:()=>({get:k=>cache.get(k)||null,put:(k,v)=>cache.set(k,v)})};
  c.Utilities = {getUuid:()=>crypto.randomUUID(),formatDate:instant=>new Date(instant.getTime()+7*3600000).toISOString().slice(0,10),
    DigestAlgorithm:{SHA_256:'sha256'},computeDigest:(_,s)=>Array.from(crypto.createHash('sha256').update(s).digest()),
    base64DecodeWebSafe:s=>Buffer.from(s,'base64url'),newBlob:b=>({getDataAsString:()=>b.toString()})};
  let writes = 0;
  c.Sheets = {Spreadsheets:{batchUpdate:({requests})=>{
    writes++;
    for(const req of requests) if(req.updateCells) {
      const u=req.updateCells, name=sheetNames[u.range.sheetId];
      store[name][u.range.startRowIndex]=u.rows[0].values.map(v=>v.userEnteredValue.stringValue);
    }
  }}};
  c.ContentService = {MimeType:{JSON:'json'},createTextOutput:text=>({setMimeType:()=>JSON.parse(text)})};
  const teacher=c.lab2Actor_({email:'teacher@fpt.edu.vn',firebaseUid:'firebase-teacher'},c.config_(),book);
  const student=c.lab2Actor_({email:'student@fpt.edu.vn',firebaseUid:'firebase-student'},c.config_(),book);
  return {c,book,store,props,add,teacher,student,cache,setNow:value=>{clock=Date.parse(value);},writes:()=>writes};
}
function testSchedule(f,slot='1') {
  const date=f.c.Utilities.formatDate(new f.c.Date()),weekday=new Date(date).getUTCDay()||7;
  if(!f.c.lab2Read_(f.book,'Schedules').some(s=>s.lecturerId==='l1'&&s.semester===''&&s.classCode==='SE1'&&s.subjectCode==='PRM393'&&Number(s.dayOfWeek)===weekday&&String(s.slot)===String(slot)))
    f.add('Schedules',{scheduleId:'test-current-'+slot,lecturerId:'l1',semester:'',subjectCode:'PRM393',subjectName:'=literal title',classCode:'SE1',dayOfWeek:weekday,slot,startTime:'00:00',endTime:'23:59'});
  return date;
}
function create(f,extra={}) {
  const date=testSchedule(f,extra.slot||'1');
  return f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',{classId:'c1',sessionDate:date,slot:'1',durationMinutes:10,...extra}).classSessionId;
}

test('public web path validates mobile QR deadline, token rotation and frozen roster before Google/code check-in',()=>{
  const f=fixture(), id=create(f);
  const session=f.c.lab2Read_(f.book,'Sessions').find(s=>s.sessionId===id);
  const request={sessionId:id,token:f.c.sessionView_(session).currentToken};
  assert.doesNotThrow(()=>f.c.assertMobileQrSession_(f.book,session,request,{studentId:'s1'}));
  assert.throws(()=>f.c.handleStudentCodeSession_(request),/MSSV đã tắt/);
  assert.throws(()=>f.c.assertMobileQrSession_(f.book,session,{...request,token:'old-token'}, {studentId:'s1'}),/QR đã thay đổi/);
  assert.throws(()=>f.c.assertMobileQrSession_(f.book,session,request,{studentId:'new-student'}),/thời điểm mở phiên/);
  const header=f.store.Lab2SessionMeta[0], row=f.store.Lab2SessionMeta.find(r=>r[0]===id);
  row[header.indexOf('closesAt')]=String(Date.now()-1);
  assert.throws(()=>f.c.assertMobileQrSession_(f.book,session,request,{studentId:'s1'}),/hết hạn/);
});

test('Firebase Google web authentication uses verified email, not supplied MSSV or client role',()=>{
  const f=fixture(), id=create(f);
  const s=f.c.lab2Read_(f.book,'Sessions').find(s=>s.sessionId===id);
  f.c.lab2FirebaseIdentity_=token=>{assert.equal(token,'server-verified');return {email:'student@fpt.edu.vn',firebaseUid:'s1'};};
  const info=f.c.handleStudentSession_({sessionId:id,token:s.currentToken,firebaseAuth:true,idToken:'server-verified',studentCode:'forged',role:'lecturer'});
  assert.equal(info.student.studentCode,'SE1');assert.equal(info.session.slot,'1');
  f.c.lab2FirebaseIdentity_=()=>({email:'unregistered@fpt.edu.vn'});
  assert.throws(()=>f.c.handleStudentSession_({sessionId:id,token:s.currentToken,firebaseAuth:true,idToken:'server-verified'}),/Email trường chưa có/);
});
test('timetable import creates owned classes atomically and upserts class/day/slot without deleting other rows',()=>{
  const f=fixture(), row={semester:'FA26',subjectCode:'PRM393',subjectName:'Mobile',classCode:'SE99',dayOfWeek:1,slot:3,startTime:'12:50',endTime:'15:10',room:'A201'};
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.student,'importTimetable',{schedules:[row]}),/PERMISSION_DENIED/);
  f.c.lab2Mutate_(f.book,f.teacher,'importTimetable',{schedules:[row]});
  assert.equal(f.store.Schedules.length,2);
  const id=f.store.Schedules[1][0];
  f.c.lab2Mutate_(f.book,f.teacher,'importTimetable',{schedules:[{...row,room:'B201'}]});
  assert.equal(f.store.Schedules.length,2);
  assert.equal(f.store.Schedules[1][0],id);
  assert.equal(f.store.Schedules[1][10],'B201');
  const before=f.writes();
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'importTimetable',{schedules:[row,{...row,slot:4,endTime:'bad'}]}),/INVALID_INPUT/);
  assert.equal(f.writes(),before);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'importTimetable',{schedules:[{...row,semester:'',classCode:'SE2',subjectCode:'PRN212'}]}),/INVALID_INPUT/);
  assert.equal(f.store.Classes.filter(r=>r[4]==='SE99').length,1);
});
test('student import reuses Desktop roster rules, is idempotent and never changes frozen membership',()=>{
  const f=fixture(), id=create(f), raw={classId:'c1',students:[{classCode:'SE1',studentCode:'SE3',fullName:'New Student',schoolEmail:''}]};
  // Existing fixture term is empty; real Desktop classes must have a term before importing.
  f.store.Classes[1][1]='FA26';
  const meta=f.store.Lab2SessionMeta[1][5];
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.student,'importClassStudents',raw),/PERMISSION_DENIED/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'importClassStudents',{...raw,classId:'c2'}),/PERMISSION_DENIED/);
  const result=f.c.lab2Mutate_(f.book,f.teacher,'importClassStudents',raw);
  assert.equal(result.added,1);
  assert.equal(f.c.lab2Mutate_(f.book,f.teacher,'importClassStudents',raw).existing,1);
  assert.equal(f.store.Lab2SessionMeta[1][5],meta);
  const before=f.writes();
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'importClassStudents',{...raw,students:[{...raw.students[0],fullName:'Different Name'}]}),/Họ tên không khớp/);
  assert.equal(f.writes(),before);
});
test('source summaries preserve word order and remove HTML without generating AI content',()=>{
  const f=fixture();
  assert.equal(f.c.lab2Abstract_({abstract:'<jats:p>Existing <b>abstract</b></jats:p>'}),'Existing abstract');
  assert.equal(f.c.lab2Abstract_({abstract_inverted_index:{world:[1],Hello:[0]}}),'Hello world');
  assert.equal(f.c.lab2Abstract_({}),null);
});
test('damaged news cache does not block feeds; authoritative tables remain strict',()=>{
  const f=fixture();
  const older={articles:[],fetchedAt:1}, newer={articles:[],fetchedAt:2};
  f.add('Lab2Feeds',{id:'duplicate',feed:JSON.stringify(older),expiresAt:100});
  f.add('Lab2Feeds',{id:'duplicate',feed:JSON.stringify(newer),expiresAt:200});
  f.add('Lab2Feeds',{id:'',feed:'broken',expiresAt:300});
  f.add('Lab2Feeds',{id:'invalid-json',feed:'broken',expiresAt:300});
  assert.throws(()=>f.c.lab2Read_(f.book,'Lab2Feeds'),/INVALID_SHEET_IDS/);
  const rows=f.c.lab2ReadNewsCache_(f.book,'Lab2Feeds');
  assert.equal(rows.length,1);
  assert.equal(JSON.parse(rows[0].feed).fetchedAt,2);
  f.c.UrlFetchApp={fetch:()=>({getResponseCode:()=>200,getContentText:()=>JSON.stringify({message:{items:[{DOI:'10.1000/test',title:['Working feed']}]}})})};
  const result=f.c.lab2Discover_(f.book,f.teacher,{subjectId:'PRM393',source:'Crossref',page:1});
  assert.equal(result.articles.length,1);
  assert.equal(result.cacheSaved,true);
  assert.throws(()=>f.c.lab2ReadNewsCache_(f.book,'Attendance'),/INVALID_INPUT/);
  f.add('Lab2SessionMeta',{sessionId:'same'});
  f.add('Lab2SessionMeta',{sessionId:'same'});
  assert.throws(()=>f.c.lab2Read_(f.book,'Lab2SessionMeta'),/INVALID_SHEET_IDS/);
});

test('setup tolerates rebuildable legacy cache IDs; diagnostics identify physical rows without exposing data',()=>{
  const f=fixture(); f.c.setupSheets=()=>{};
  f.c.console={log:()=>{}};
  f.add('Lab2Feeds',{id:'sensitive-id',feed:'broken',expiresAt:100});
  f.store.Lab2Feeds.push(['','','']);
  f.add('Lab2Feeds',{id:'sensitive-id',feed:'broken',expiresAt:200});
  f.add('Lab2Feeds',{id:'',feed:'broken',expiresAt:300});
  const before=JSON.stringify(f.store);
  assert.doesNotThrow(()=>f.c.setupLab2Free());
  const diagnostic=f.c.diagnoseLab2Sheets().find(r=>r.table==='Lab2Feeds');
  assert.equal(diagnostic.status,'INVALID_SHEET_IDS');
  assert.equal(JSON.stringify(diagnostic.duplicateIdRows),'[[2,4]]');
  assert.equal(JSON.stringify(diagnostic.missingIdRows),'[5]');
  assert.equal(JSON.stringify(diagnostic).includes('sensitive-id'),false);
  assert.equal(JSON.stringify(f.store),before);
  f.add('AttendanceAudit',{id:'same'});f.add('AttendanceAudit',{id:'same'});
  assert.throws(()=>f.c.setupLab2Free(),/INVALID_SHEET_IDS/);
  assert.equal(f.c.diagnoseLab2Sheets().find(r=>r.table==='AttendanceAudit').status,'INVALID_SHEET_IDS');
});
test('cache storage failure still returns fetched metadata without claiming sharing works',()=>{
  const f=fixture();
  f.c.UrlFetchApp={fetch:()=>({getResponseCode:()=>200,getContentText:()=>JSON.stringify({message:{items:[{DOI:'10.1000/test',title:['Working feed']}]}})})};
  f.c.Sheets.Spreadsheets.batchUpdate=()=>{throw Error('cache storage failure');};
  const feed=f.c.lab2Discover_(f.book,f.teacher,{subjectId:'PRM393',source:'Crossref'});
  assert.equal(feed.articles.length,1);
  assert.equal(feed.cacheSaved,false);
  assert.equal(feed.articles[0].canShare,false);
});
test('timetable uses only the assigned lecturer and links exact class/subject/semester',()=>{
  const f=fixture();
  f.add('Schedules',{scheduleId:'own',lecturerId:'l1',semester:'',subjectCode:'PRM393',subjectName:'Mobile',classCode:'SE1',dayOfWeek:'5',slot:'3',startTime:'12:50',endTime:'15:10',room:'A201'});
  f.add('Schedules',{scheduleId:'other',lecturerId:'l2',subjectCode:'PRN212',classCode:'SE2',dayOfWeek:'5',slot:'1',startTime:'07:30',endTime:'09:50'});
  f.add('Schedules',{scheduleId:'different-term',lecturerId:'l1',semester:'Spring 2027',subjectCode:'PRM393',classCode:'SE1',dayOfWeek:'1',slot:'2',startTime:'10:00',endTime:'12:00'});
  const snapshot=f.c.lab2Snapshot_(f.book,f.teacher);
  const schedules=snapshot.collections.schedules;
  assert.equal(schedules.length,2);
  const own=schedules.find(s=>s.id==='own');
  assert.equal(own.classId,'c1');
  assert.equal(own.lecturerUid,'lecturer-l1');
  assert.equal(own.slot,3);
  assert.equal(own.subjectName,'Mobile');
  assert.equal(own.room,'A201');
  assert.equal(schedules.find(s=>s.id==='different-term').classId,null);
  assert.equal(f.c.lab2Snapshot_(f.book,f.student).collections.schedules.length,0);
  const id=create(f,{slot:'3'});
  const session=f.c.lab2Snapshot_(f.book,f.teacher).collections.classSessions.find(s=>s.id===id);
  assert.equal(session.slot,3);
});
test('role and class access come from Sheets; student snapshots hide peer records',()=>{
  const f=fixture();
  assert.throws(()=>f.c.lab2Actor_({email:'unknown@fpt.edu.vn'},f.c.config_(),f.book),/PROFILE_NOT_REGISTERED/);
  assert.throws(()=>f.c.lab2Class_(f.book,f.teacher,'c2',true),/PERMISSION_DENIED/);
  assert.throws(()=>create({...f,teacher:f.student}),/NOT_ENROLLED/);
  const s=f.c.lab2Snapshot_(f.book,f.student);
  assert.equal(s.profile.uid,'student-s1');
  assert.equal(s.collections.classes.length,1);
  assert.equal(s.collections['classes/c1/members'].length,1);
  assert.equal(s.collections['classes/c1/members'][0].id,'student-s1');
});

test('Mobile Google-only snapshots require verified Google provider and unique lecturer; legacy student snapshot remains available',()=>{
  const f=fixture();
  const request={action:'lab2Snapshot',idToken:'verified',googleLecturerOnly:true};
  let identity={email:'teacher@fpt.edu.vn',firebaseUid:'teacher',signInProvider:'google.com'};
  f.c.lab2FirebaseIdentity_=()=>identity;
  const result=f.c.lab2Handle_(request);
  assert.equal(result.profile.lecturerId,'l1');
  assert.equal(result.profile.email,'teacher@fpt.edu.vn');
  identity={...identity,signInProvider:'password'};
  assert.throws(()=>f.c.lab2Handle_(request),/GOOGLE_ONLY/);
  identity={...identity,email:'student@fpt.edu.vn',signInProvider:'google.com'};
  assert.throws(()=>f.c.lab2Handle_(request),/LECTURER_REQUIRED/);
  assert.equal(f.c.lab2Handle_({...request,googleLecturerOnly:false}).profile.role,'student');
  identity={...identity,email:'unknown@fpt.edu.vn'};
  assert.throws(()=>f.c.lab2Handle_(request),/PROFILE_NOT_REGISTERED/);
  identity={...identity,email:'teacher@fpt.edu.vn'};
  f.add('Lecturers',{lecturerId:'duplicate',email:' Teacher@fpt.edu.vn '});
  assert.throws(()=>f.c.lab2Handle_(request),/DUPLICATE_PROFILE/);
});

test('effective room follows recurring, room override, makeup and ambiguous/missing data without inventing a room',()=>{
  const f=fixture('2026-10-12T01:00:00Z');
  const cls=f.c.lab2Read_(f.book,'Classes')[0];
  const base={scheduleId:'r',lecturerId:'l1',semester:'',classCode:'SE1',subjectCode:'PRM393',dayOfWeek:1,slot:1,room:'A201'};
  const session={date:'2026-10-12',slot:'1'};
  const tables={Schedules:[base],ScheduleExceptions:[]};
  assert.equal(f.c.lab2EffectiveRoom_(tables,session,cls),'A201');
  tables.ScheduleExceptions=[{classId:'c1',scheduleId:'r',date:session.date,kind:'ROOM_CHANGED',room:'B301'}];
  assert.equal(f.c.lab2EffectiveRoom_(tables,session,cls),'B301');
  tables.ScheduleExceptions=[{classId:'c1',targetDate:session.date,slot:1,kind:'MAKEUP',room:'C401'}];
  assert.equal(f.c.lab2EffectiveRoom_(tables,session,cls),'C401');
  tables.ScheduleExceptions=[];
  tables.Schedules=[base,{...base,scheduleId:'ambiguous'}];
  assert.equal(f.c.lab2EffectiveRoom_(tables,session,cls),'');
  tables.Schedules=[];
  assert.equal(f.c.lab2EffectiveRoom_(tables,session,cls),'');
});

test('snapshot and live session expose effective room and attendance counts consistently',()=>{
  const f=fixture('2026-10-12T01:00:00Z');
  f.add('Schedules',{scheduleId:'room',lecturerId:'l1',semester:'',classCode:'SE1',subjectCode:'PRM393',dayOfWeek:1,slot:1,startTime:'00:00',endTime:'23:59',room:'A201'});
  const id=create(f);
  const snapshot=f.c.lab2Snapshot_(f.book,f.teacher);
  const attendance=snapshot.collections.attendanceSessions.find(s=>s.id===id);
  assert.equal(attendance.room,'A201');
  assert.equal(attendance.checkedInCount,0);
  assert.equal(attendance.eligibleCount,2);
  assert.equal(snapshot.collections.classSessions.find(s=>s.id===id).room,'A201');
  assert.equal(f.c.lab2Live_(f.book,f.teacher,{sessionId:id}).room,'A201');
});
test('create is atomic, uses literal text, and repeated class/date/slot cannot extend expiry',()=>{
  const f=fixture(), id=create(f), meta=f.store.Lab2SessionMeta[1].slice();
  assert.equal(f.writes(),1);
  assert.equal(meta[1],'Mobile • Slot 1');
  assert.equal(create(f,{durationMinutes:30}),id);
  assert.deepEqual(f.store.Lab2SessionMeta[1],meta);
  assert.equal(f.writes(),1);
});
test('QR check-in rejects duplicates, bad tokens and enrollment; close creates absent once',()=>{
  const f=fixture(), id=create(f);
  const qr=f.c.lab2Mutate_(f.book,f.teacher,'getQrToken',{attendanceSessionId:id});
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.student,'checkInWithQr',{token:qr.token.replace(/token=([^&]+)/, 'token=wrong')}),/QR_INVALID/);
  const r=f.c.lab2Mutate_(f.book,f.student,'checkInWithQr',{token:qr.token});
  assert.equal(r.status,'present');
  assert.equal(f.c.lab2Mutate_(f.book,f.student,'checkInWithQr',{token:qr.token}).alreadyRecorded,true);
  f.c.lab2Mutate_(f.book,f.teacher,'closeAttendanceSession',{attendanceSessionId:id});
  assert.equal(f.store.Attendance.length,3);
  assert.equal(f.store.Attendance[2][3],'ABSENT');
  const writes=f.writes();
  f.c.lab2Mutate_(f.book,f.teacher,'closeAttendanceSession',{attendanceSessionId:id});
  assert.equal(f.writes(),writes);
  assert.equal(f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',{classId:'c1',sessionDate:testSchedule(f),slot:'1',durationMinutes:10}).status,'CLOSED');
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.student,'checkInWithQr',{token:qr.token}),/SESSION_CLOSED/);
});
test('deadline finalization on read uses frozen membership, without changing other classes',()=>{
  const f=fixture(), id=create(f);
  f.store.Lab2SessionMeta[1][3]=String(Date.now()-1);
  f.add('Enrollments',{enrollmentId:'late',classId:'c1',studentId:'s3'});
  const snapshot=f.c.lab2Snapshot_(f.book,f.student);
  assert.equal(snapshot.collections.attendanceSessions[0].status,'finalized');
  assert.equal(f.store.Attendance.length,3);
  assert.equal(f.store.Attendance.some(r=>r[2]==='s3'),false);
  assert.equal(snapshot.collections.attendanceRecords.length,1);
  assert.equal(snapshot.collections.attendanceRecords[0].studentUid,'student-s1');
});
test('Desktop secret code is required separately and never embedded into projected QR',()=>{
  const f=fixture(), id=create(f);
  f.store.Sessions[1][7]+='#123456';
  const qr=f.c.lab2Mutate_(f.book,f.teacher,'getQrToken',{attendanceSessionId:id});
  assert.ok(qr.token.includes('mode=google-secret'));
  assert.equal(qr.token.includes('123456'),false);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.student,'checkInWithQr',{token:qr.token}),/SECRET_REQUIRED/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.student,'checkInWithQr',{token:qr.token,secretCode:'wrong'}),/SECRET_INVALID/);
  assert.equal(f.c.lab2Mutate_(f.book,f.student,'checkInWithQr',{token:qr.token,secretCode:'123456'}).status,'present');
});
test('mobile rotates Desktop QR, toggles secret, and rejects unauthorized or closed changes',()=>{
  const f=fixture(), id=create(f), input={attendanceSessionId:id};
  const first=f.c.lab2Mutate_(f.book,f.teacher,'getQrToken',input);
  assert.equal(f.c.lab2Mutate_(f.book,f.teacher,'getQrToken',input).token,first.token);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.student,'rotateAttendanceQr',input),/PERMISSION_DENIED/);
  f.c.lab2Mutate_(f.book,f.teacher,'rotateAttendanceQr',{...input,secretEnabled:true});
  const secret=f.c.lab2Mutate_(f.book,f.teacher,'getQrToken',input);
  assert.match(secret.secretCode,/^\d{6}$/);
  assert.equal(secret.secretEnabled,true);
  assert.equal(secret.token.includes(secret.secretCode),false);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.student,'checkInWithQr',{token:first.token}),/QR_INVALID/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.student,'checkInWithQr',{token:secret.token}),/SECRET_REQUIRED/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.student,'checkInWithQr',{token:secret.token,secretCode:'wrong'}),/SECRET_INVALID/);
  f.c.lab2Mutate_(f.book,f.teacher,'rotateAttendanceQr',input);
  const rotated=f.c.lab2Mutate_(f.book,f.teacher,'getQrToken',input);
  assert.notEqual(rotated.token,secret.token);
  assert.equal(rotated.secretCode,secret.secretCode);
  f.c.lab2Mutate_(f.book,f.teacher,'rotateAttendanceQr',{...input,secretEnabled:false});
  const plain=f.c.lab2Mutate_(f.book,f.teacher,'getQrToken',input);
  assert.equal(plain.secretEnabled,false);
  assert.equal(plain.secretCode,'');
  assert.equal(f.c.lab2Mutate_(f.book,f.student,'checkInWithQr',{token:plain.token}).status,'present');
  f.c.lab2Mutate_(f.book,f.teacher,'closeAttendanceSession',input);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'rotateAttendanceQr',input),/SESSION_CLOSED/);
});
test('lecturer corrections preserve check-in time, finalize missing roster, validate notes and ownership',()=>{
  const f=fixture(), id=create(f), input={attendanceSessionId:id,studentUid:'student-s1',status:'absent',notes:'Medical leave'};
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.student,'updateAttendanceRecord',input),/PERMISSION_DENIED/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'updateAttendanceRecord',{...input,studentUid:'student-missing'}),/NOT_ENROLLED/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'updateAttendanceRecord',{...input,notes:''}),/INVALID_INPUT/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'updateAttendanceRecord',{...input,status:'unknown'}),/INVALID_INPUT/);
  const qr=f.c.lab2Mutate_(f.book,f.teacher,'getQrToken',{attendanceSessionId:id});
  f.c.lab2Mutate_(f.book,f.student,'checkInWithQr',{token:qr.token});
  const checkIn=f.store.Attendance[1][4];
  f.c.lab2Mutate_(f.book,f.teacher,'updateAttendanceRecord',input);
  assert.equal(f.store.Attendance[1][3],'ABSENT');
  assert.equal(f.store.Attendance[1][4],checkIn);
  assert.equal(f.store.Attendance[1][7],f.teacher.email);
  f.c.lab2Mutate_(f.book,f.teacher,'closeAttendanceSession',{attendanceSessionId:id});
  f.c.lab2Mutate_(f.book,f.teacher,'updateAttendanceRecord',{...input,studentUid:'student-s2',status:'present'});
  assert.equal(f.store.Attendance.length,3);
  const snapshot=f.c.lab2Snapshot_(f.book,f.teacher);
  assert.equal(snapshot.collections.attendanceRecords.find(r=>r.studentUid==='student-s2').status,'present');
});
test('Firebase REST lookup is authoritative; audience, verification and disabled accounts enforced',()=>{
  const f=fixture();
  const claims={aud:'fap-attendance-88920',iss:'https://securetoken.google.com/fap-attendance-88920',exp:Date.now()/1000+3600,sub:'uid'};
  const token='header.'+Buffer.from(JSON.stringify(claims)).toString('base64url')+'.signature';
  let account={localId:'uid',email:'student@fpt.edu.vn',emailVerified:false};
  f.c.UrlFetchApp={fetch:(url,options)=>{
    assert.ok(url.startsWith('https://identitytoolkit.googleapis.com/v1/accounts:lookup?key='));
    assert.equal(JSON.parse(options.payload).idToken,token);
    return {getResponseCode:()=>200,getContentText:()=>JSON.stringify({users:[account]})};
  }};
  assert.throws(()=>f.c.lab2FirebaseIdentity_(token),/EMAIL_NOT_VERIFIED/);
  account={...account,emailVerified:true,disabled:true};
  assert.throws(()=>f.c.lab2FirebaseIdentity_(token),/UNAUTHENTICATED/);
  account.disabled=false;
  assert.equal(f.c.lab2FirebaseIdentity_(token).firebaseUid,'uid');
  assert.throws(()=>f.c.lab2FirebaseIdentity_('x.y.z'),/UNAUTHENTICATED/);
});
test('routing preserves legacy API and refuses unauthenticated shared actions',()=>{
  const f=fixture();
  assert.equal(f.c.doPost({postData:{contents:'{"action":"lab2Health"}'}}).data.quizEnabled,false);
  assert.equal(f.c.doPost({postData:{contents:'{"action":"lab2Snapshot"}'}}).error,'UNAUTHENTICATED');
  let legacy=0;
  f.c.handle_=()=>{legacy++;return {old:true};};
  assert.equal(f.c.doPost({postData:{contents:'{"action":"login"}'}}).data.old,true);
  assert.equal(legacy,1);
});
test('rate-limit fixed window can reset even with continuous requests',()=>{
  const f=fixture();
  for(let i=0;i<12;i++)f.c.lab2Limit_('uid','discoverArticles');
  assert.throws(()=>f.c.lab2Limit_('uid','discoverArticles'),/RATE_LIMITED/);
  for(const [key,value] of f.cache) {const window=JSON.parse(value);window.start-=61000;f.cache.set(key,JSON.stringify(window));}
  assert.doesNotThrow(()=>f.c.lab2Limit_('uid','discoverArticles'));
});

test('MSSV legacy routes fail closed; enabling route still requires verified matching identity',()=>{
  const f=fixture(), id=create(f), s=f.c.lab2Read_(f.book,'Sessions')[0];
  const request={sessionId:id,token:s.currentToken,confirmPresent:true,studentCode:'SE00001'};
  assert.throws(()=>f.c.handleStudentCheckIn_(request,true),/MSSV đã tắt/);
  f.props.ALLOW_VERIFIED_STUDENT_CODE='true';
  assert.throws(()=>f.c.handleStudentCheckIn_(request,true),/Google|GOOGLE/);
  f.c.authenticateStudent_=()=>({studentId:'s2'});
  f.store.Students[1][1]='SE00001';
  assert.throws(()=>f.c.handleStudentCheckIn_(request,true),/không thuộc tài khoản/);
  assert.equal(f.store.Attendance.length,1);
});

test('web retries return original receipt; close and check-in serialize without duplicates',()=>{
  const f=fixture(), id=create(f), s=f.c.lab2Read_(f.book,'Sessions')[0];
  f.c.authenticateFirebaseStudent_=()=>f.c.lab2Read_(f.book,'Students')[0];
  const request={sessionId:id,token:s.currentToken,confirmPresent:true,firebaseAuth:true,idToken:'verified'};
  const first=f.c.handleStudentCheckIn_(request);
  const second=f.c.handleStudentCheckIn_(request);
  assert.equal(second.alreadyRecorded,true);assert.equal(second.checkInTime,first.checkInTime);
  f.c.lab2Mutate_(f.book,f.teacher,'closeAttendanceSession',{attendanceSessionId:id});
  assert.throws(()=>f.c.handleStudentCheckIn_(request),/kết thúc/);
  assert.equal(f.store.Attendance.length,3);
  assert.equal(f.store.Attendance[1][3],'PRESENT');assert.equal(f.store.Attendance[2][3],'ABSENT');
});

test('fifty serialized writers and retries create exactly one record per enrolled student',()=>{
  const f=fixture();
  for(let i=3;i<=50;i++) {f.add('Students',{studentId:'s'+i,studentCode:'SE'+i});f.add('Enrollments',{enrollmentId:'e'+i,classId:'c1',studentId:'s'+i});}
  const id=create(f), s=f.c.lab2Read_(f.book,'Sessions')[0];
  for(let i=1;i<=50;i++) {
    f.c.authenticateFirebaseStudent_=()=>f.c.lab2Read_(f.book,'Students').find(s=>s.studentId==='s'+i);
    const r={sessionId:id,token:s.currentToken,confirmPresent:true,firebaseAuth:true};
    f.c.handleStudentCheckIn_(r);f.c.handleStudentCheckIn_(r);
  }
  assert.equal(f.store.Attendance.length,51);
  f.c.LockService={getScriptLock:()=>({tryLock:()=>false})};
  assert.throws(()=>f.c.lab2Live_(f.book,f.teacher,{sessionId:id}),/LOCK_BUSY/);
});

test('reconciliation works without snapshot, is idempotent, and failed atomic batch can retry',()=>{
  const f=fixture(), id=create(f); f.store.Lab2SessionMeta[1][3]=String(Date.now()-1);
  const commit=f.c.Sheets.Spreadsheets.batchUpdate;
  f.c.Sheets.Spreadsheets.batchUpdate=()=>{throw Error('unavailable');};
  assert.throws(()=>f.c.reconcileExpiredSessions(),/unavailable/);
  assert.equal(f.store.Sessions[1][6],'OPEN');assert.equal(f.store.Attendance.length,1);
  f.c.Sheets.Spreadsheets.batchUpdate=commit;
  assert.equal(f.c.reconcileExpiredSessions().closed,1);
  assert.equal(f.c.reconcileExpiredSessions().closed,0);
  assert.equal(f.store.Attendance.length,3);
  assert.equal(f.c.lab2Live_(f.book,f.teacher,{sessionId:id}).status,'CLOSED');
});

test('corrections append atomic audit with server actor, preserve status, and do not repeat on retry',()=>{
  const f=fixture(), id=create(f), request={attendanceSessionId:id,studentUid:'student-s1',status:'excused',notes:'Approved leave',actorUid:'forged'};
  f.c.lab2Mutate_(f.book,f.teacher,'updateAttendanceRecord',request);
  f.c.lab2Mutate_(f.book,f.teacher,'updateAttendanceRecord',request);
  assert.equal(f.store.AttendanceAudit.length,2);
  const audit=f.c.lab2Read_(f.book,'AttendanceAudit')[0];
  assert.equal(audit.actorUid,'firebase-teacher');assert.equal(audit.oldStatus,'PENDING');assert.equal(audit.newStatus,'EXCUSED');
  assert.equal(f.c.lab2Snapshot_(f.book,f.teacher).collections.attendanceRecords[0].status,'excused');
  const teacher2=f.c.lab2Actor_({email:'other@fpt.edu.vn',firebaseUid:'other'},f.c.config_(),f.book);
  assert.throws(()=>f.c.lab2Live_(f.book,teacher2,{sessionId:id}),/PERMISSION_DENIED/);
  const live=f.c.lab2Live_(f.book,f.teacher,{sessionId:id});
  assert.equal(live.counts.excused,1);assert.equal(live.counts.pending,1);
  assert.ok(live.serverTime);assert.equal(JSON.stringify(live).includes('currentToken'),false);
});

test('Desktop create captures roster; close and correction reuse shared rules and original envelope',()=>{
  const f=fixture(), lecturer=f.teacher.entity;
  testSchedule(f);
  const request={action:'createSession',classId:'c1',date:'2026-10-11',slot:'1',startTime:'08:00',endTime:'09:00',currentToken:'qr-desktop',tokenExpiredAt:new Date(Date.now()+600000).toISOString()};
  const s=f.c.handleSession_(f.book,f.c.config_(),lecturer,request);
  assert.equal(f.c.handleSession_(f.book,f.c.config_(),lecturer,request).sessionId,s.sessionId);
  assert.equal(f.store.Lab2SessionMeta.length,2);
  const deadline=Number(f.c.lab2Read_(f.book,'Lab2SessionMeta')[0].closesAt);
  assert.ok(deadline<=Date.now()+10*60000);
  const rotated=f.c.handleSession_(f.book,f.c.config_(),lecturer,{action:'rotateToken',sessionId:s.sessionId,currentToken:'rotated',tokenExpiredAt:new Date(Date.now()+20*60000).toISOString()});
  assert.equal(rotated.saved,true);
  assert.equal(f.c.lab2Read_(f.book,'Sessions')[0].currentToken,'rotated');
  assert.equal(Number(f.c.lab2Read_(f.book,'Lab2SessionMeta')[0].closesAt),deadline);
  f.add('Enrollments',{enrollmentId:'new',classId:'c1',studentId:'new'});
  assert.equal(f.c.handleSession_(f.book,f.c.config_(),lecturer,{action:'closeSession',sessionId:s.sessionId}).closed,true);
  assert.equal(f.store.Attendance.length,3);
  const attendance=f.c.lab2Read_(f.book,'Attendance')[0];
  assert.equal(f.c.handleSession_(f.book,f.c.config_(),lecturer,{action:'updateAttendance',attendanceId:attendance.attendanceId,status:'LATE',note:'Verified arrival'}).saved,true);
  assert.equal(f.store.AttendanceAudit.length,2);
});

function contentFixture() {
  const f=fixture();
  f.add('SubjectContentConfig',{subjectCode:'PRM393',topicKeywords:'["Flutter","Android"]',excludeKeywords:'["medical"]',sourceIds:'["android","crossref"]',enabled:'true'});
  f.add('ContentSourceRegistry',{sourceId:'android',type:'RSS',label:'Android Developers',url:'https://android-developers.googleblog.com/feeds/posts/default?alt=rss',enabled:'true'});
  f.add('ContentSourceRegistry',{sourceId:'crossref',type:'CROSSREF',label:'Crossref',url:'https://api.crossref.org/works',enabled:'true'});
  return f;
}

function scheduleFixture() {
  const f=fixture('2026-10-11T08:00:00+07:00');
  f.add('Schedules',{scheduleId:'sch1',lecturerId:'l1',semester:'',subjectCode:'PRM393',classCode:'SE1',dayOfWeek:7,slot:'1',startTime:'08:00',endTime:'09:30',room:'A1'});
  return f;
}
test('dated overrides preserve Desktop schedule; cancellation blocks both writers and restores idempotently',()=>{
  const f=scheduleFixture(), input={classId:'c1',scheduleId:'sch1',date:'2026-10-11',kind:'CANCELLED',reason:'Holiday'};
  const original=JSON.stringify(f.store.Schedules);
  f.c.lab2Mutate_(f.book,f.teacher,'saveScheduleException',input);
  f.c.lab2Mutate_(f.book,f.teacher,'saveScheduleException',input);
  assert.equal(f.store.ScheduleExceptions.length,2);assert.equal(JSON.stringify(f.store.Schedules),original);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',occurrenceInput()),/OCCURRENCE_NOT_FOUND/);
  assert.throws(()=>f.c.handleSession_(f.book,f.c.config_(),f.teacher.entity,{action:'createSession',classId:'c1',date:input.date,slot:1,currentToken:'desktop',tokenExpiredAt:'2026-10-11T09:00:00+07:00'}),/OCCURRENCE_NOT_FOUND/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.student,'saveScheduleException',input),/PERMISSION_DENIED/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'saveScheduleException',{...input,date:'2026-02-30'}),/INVALID_INPUT/);
  f.c.lab2Mutate_(f.book,f.teacher,'saveScheduleException',{...input,kind:'RESTORED',reason:'Resumed'});
  assert.doesNotThrow(()=>f.c.lab2ResolveOccurrence_(f.book,f.teacher,occurrenceInput()));
  create(f);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'saveScheduleException',input),/OCCURRENCE_HAS_SESSION/);
});
test('reschedule checks conflicts and closes original occurrence while permitting target',()=>{
  const f=scheduleFixture(),input={classId:'c1',scheduleId:'sch1',date:'2026-10-11',kind:'RESCHEDULED',targetDate:'2026-10-12',slot:'2',startTime:'10:00',endTime:'11:00',reason:'Move'};
  f.add('Schedules',{scheduleId:'sch2',lecturerId:'l1',semester:'',subjectCode:'PRM393',classCode:'SE1',dayOfWeek:1,slot:'3',startTime:'10:30',endTime:'12:00'});
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'saveScheduleException',input),/SCHEDULE_CONFLICT/);
  f.c.lab2Mutate_(f.book,f.teacher,'saveScheduleException',{...input,startTime:'08:00',endTime:'09:00'});
  assert.throws(()=>f.c.lab2ResolveOccurrence_(f.book,f.teacher,occurrenceInput()),/OCCURRENCE_NOT_FOUND/);
  assert.doesNotThrow(()=>f.c.lab2ResolveOccurrence_(f.book,f.teacher,occurrenceInput({sessionDate:input.targetDate,slot:2})));
});
test('roster correction retains MSSV, audits server identity and rejects cross-lecturer changes',()=>{
  const f=fixture(), input={classId:'c1',studentUid:'student-s1',fullName:'Updated name',schoolEmail:'student@fpt.edu.vn',reason:'Correct typo'};
  f.c.lab2Mutate_(f.book,f.teacher,'updateClassStudent',input);
  f.c.lab2Mutate_(f.book,f.teacher,'updateClassStudent',input);
  assert.equal(f.store.RosterAudit.length,2);
  assert.equal(f.c.lab2Read_(f.book,'Students')[0].studentCode,'SE1');
  assert.equal(f.c.lab2Read_(f.book,'RosterAudit')[0].actorUid,'firebase-teacher');
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'updateClassStudent',{...input,studentCode:'SE99'}),/INVALID_INPUT/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'updateClassStudent',{...input,schoolEmail:'other-student@fpt.edu.vn'}),/INVALID_INPUT/);
  f.add('Enrollments',{enrollmentId:'shared',classId:'c2',studentId:'s1'});
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'updateClassStudent',input),/SHARED_STUDENT_ADMIN_REQUIRED/);
});
test('subject ownership is checked before reading cached content or making upstream requests',()=>{
  const f=contentFixture();let calls=0;f.c.contentFetch_=()=>{calls++;return [];};
  assert.throws(()=>f.c.subjectUpdates_(f.book,f.teacher,{subjectCode:'PRN212',type:'NEWS'}),/PERMISSION_DENIED/);
  assert.throws(()=>f.c.subjectUpdates_(f.book,f.student,{subjectCode:'PRM393',type:'NEWS'}),/PERMISSION_DENIED/);
  assert.throws(()=>f.c.subjectTopics_(f.book,f.teacher,{subjectCode:'PRN212'}),/PERMISSION_DENIED/);
  assert.equal(calls,0);
  assert.equal(f.c.subjectTopics_(f.book,f.teacher,{subjectCode:'PRM393'}).topics.length,2);
});
test('content normalization sanitizes metadata, validates URLs, excludes irrelevant items and explains topics',()=>{
  const f=contentFixture(), config=f.c.lab2Read_(f.book,'SubjectContentConfig')[0],source=f.c.lab2Read_(f.book,'ContentSourceRegistry')[0];
  const raw={title:'<b>Flutter update</b>',excerpt:'<script>alert(1)</script>Android release',url:'https://android-developers.googleblog.com/update?utm_source=test',publishedAt:'2026-10-10'};
  const item=f.c.contentNormalize_(raw,source,config,'NEWS',Date.now());
  assert.equal(item.title,'Flutter update');assert.equal(item.excerpt,'Android release');assert.equal(item.matchedTopics.length,2);
  assert.equal(item.url,'https://android-developers.googleblog.com/update');
  for(const url of ['javascript:alert(1)','https://127.0.0.1/x','https://user:pass@example.com/x','https://evil.example/x'])
    assert.equal(f.c.contentNormalize_({...raw,url},source,config,'NEWS',Date.now()),null);
  assert.equal(f.c.contentNormalize_({...raw,title:'medical Android'},source,config,'NEWS',Date.now()),null);
  assert.equal(f.c.contentNormalize_({...raw,title:'Unrelated',excerpt:''},source,config,'NEWS',Date.now()),null);
});
test('feed cache is bounded, dedupes DOI, paginates consistently and does not fetch under lock',()=>{
  const f=contentFixture();let held=false,calls=0;
  f.c.LockService={getScriptLock:()=>({tryLock:()=>{assert.equal(held,false);held=true;return true;},releaseLock:()=>{held=false;}})};
  f.c.contentFetch_=()=>{assert.equal(held,false);calls++;return [
    ...Array.from({length:30},(_,i)=>({title:'Flutter paper '+i,doi:'10.1/'+i,url:'https://doi.org/10.1/'+i,publishedAt:'2026-10-10'})),
    {title:'Flutter duplicate',doi:'10.1/0',url:'https://doi.org/10.1/0'}];};
  const input={subjectCode:'PRM393',type:'RESEARCH',limit:20};
  const first=f.c.subjectUpdates_(f.book,f.teacher,input);
  const second=f.c.subjectUpdates_(f.book,f.teacher,{...input,cursor:first.nextCursor});
  assert.equal(calls,1);assert.equal(first.items.length,20);assert.equal(second.items.length,4);
  assert.equal(new Set([...first.items,...second.items].map(i=>i.id)).size,24);
  assert.equal(f.store.SubjectContentCache.length,2);
  assert.throws(()=>f.c.subjectUpdates_(f.book,f.teacher,{...input,query:'other',cursor:first.nextCursor}),/CONTENT_CHANGED/);
});
test('source outage retains dated stale cache, and cooldown prevents unbounded failed refreshes',()=>{
  const f=contentFixture();let calls=0;
  f.c.contentFetch_=()=>{calls++;return [{title:'Android update',url:'https://android-developers.googleblog.com/a',publishedAt:'2026-10-10'}];};
  const input={subjectCode:'PRM393',type:'NEWS'},first=f.c.subjectUpdates_(f.book,f.teacher,input);
  f.store.SubjectContentCache[1][2]='0';f.cache.clear();
  f.c.contentFetch_=()=>{calls++;throw Error('offline');};
  const stale=f.c.subjectUpdates_(f.book,f.teacher,input),again=f.c.subjectUpdates_(f.book,f.teacher,input);
  assert.equal(stale.items.length,1);assert.equal(stale.stale,true);assert.equal(stale.lastUpdatedAt,first.lastUpdatedAt);
  assert.equal(again.stale,true);assert.equal(calls,2);
});
test('RSS and Atom parse source dates; DTD is rejected before XML parsing',()=>{
  const f=contentFixture(),{JSDOM}=require('../../web_checkin/node_modules/jsdom');
  const wrap=n=>({getName:()=>n.localName,getText:()=>n.textContent,getChildren:()=>[...n.children].map(wrap),
    getAttribute:k=>n.hasAttribute(k)?{getValue:()=>n.getAttribute(k)}:null});
  f.c.XmlService={parse:xml=>({getRootElement:()=>wrap(new JSDOM(xml,{contentType:'text/xml'}).window.document.documentElement)})};
  assert.equal(f.c.contentRss_('<rss><channel><item><title>Android</title><link>https://example.com/a</link><pubDate>2026-10-10</pubDate><description><![CDATA[<p>Source text</p>]]></description></item></channel></rss>')[0].excerpt,'<p>Source text</p>');
  assert.equal(f.c.contentRss_('<feed xmlns="http://www.w3.org/2005/Atom"><entry><title>Flutter</title><link rel="alternate" href="https://example.com/b"/><published>2026-10-10</published></entry></feed>')[0].url,'https://example.com/b');
  assert.throws(()=>f.c.contentRss_('<!DOCTYPE rss><rss/>'),/UPSTREAM_UNAVAILABLE/);
});

test('upstream fetch uses exact allowlist and ten second timeout; cleanup only deletes expired cache rows',()=>{
  const f=contentFixture();let calls=0;
  f.c.UrlFetchApp={fetch:(url,options)=>{calls++;assert.equal(options.timeoutSeconds,10);assert.equal(options.followRedirects,false);return {getResponseCode:()=>200,getContentText:()=>JSON.stringify({message:{items:[]}})};}};
  f.c.contentFetch_(f.c.lab2Read_(f.book,'ContentSourceRegistry')[1],['Flutter']);
  assert.throws(()=>f.c.contentFetch_({type:'RSS',url:'https://evil.example/feed'},['Flutter']),/SOURCE_NOT_APPROVED/);
  assert.equal(calls,1);
  f.add('SubjectContentCache',{id:'old',feed:'{}',expiresAt:Date.now()-8*86400000});
  f.store.SubjectContentCache.push(['','','']);
  f.add('SubjectContentCache',{id:'current',feed:'{}',expiresAt:Date.now()+600000});
  f.add('SubjectContentCache',{id:'expired',feed:'{}',expiresAt:Date.now()-9*86400000});
  const original=f.book.getSheetByName;
  f.book.getSheetByName=name=>({...original(name),deleteRow:i=>{assert.equal(name,'SubjectContentCache');f.store[name].splice(i-1,1);}});
  assert.equal(f.c.pruneSubjectContentCache().removed,2);
  assert.equal(f.c.lab2Read_(f.book,'SubjectContentCache')[0].id,'current');
});

function occurrenceInput(extra={}) {return {classId:'c1',scheduleId:'sch1',sessionDate:'2026-10-11',slot:1,durationMinutes:10,...extra};}
for(const [time,expected] of [
  ['07:44:00','OCCURRENCE_NOT_YET'],['07:45:00','OPEN'],['07:50:00','OPEN'],['08:15:00','OPEN'],
  ['09:30:00','OCCURRENCE_ENDED'],['09:35:00','OCCURRENCE_ENDED'],['09:29:01','OCCURRENCE_TOO_SHORT']]) {
  test('schedule-driven opening boundary '+time+' -> '+expected,()=>{
    const f=scheduleFixture();f.setNow('2026-10-11T'+time+'+07:00');
    const open=()=>f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',occurrenceInput());
    if(expected==='OPEN') {const r=open();assert.equal(r.status,'OPEN');assert.equal(r.opensAt,f.c.Date.now());assert.ok(r.closesAt<=Date.parse('2026-10-11T09:30:00+07:00'));}
    else {assert.throws(open,new RegExp(expected));assert.equal(f.store.Sessions.length,1);}
  });
}
test('authoritative schedule ignores forged times/title and caps thirty minutes to five; expired OPEN reconciles without reopening',()=>{
  const f=scheduleFixture();f.setNow('2026-10-11T09:25:00+07:00');
  const r=f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',occurrenceInput({durationMinutes:30,startTime:'00:00',endTime:'23:59',title:'forged'}));
  assert.equal(r.effectiveDurationMinutes,5);assert.equal(r.closesAt,Date.parse('2026-10-11T09:30:00+07:00'));
  const row=f.c.lab2Read_(f.book,'Sessions')[0];assert.equal(row.startTime,'08:00');assert.equal(row.endTime,'09:30');
  assert.equal(f.c.lab2Read_(f.book,'Lab2SessionMeta')[0].title,'Mobile • Slot 1');
  const previous=JSON.stringify(f.store.Lab2SessionMeta);
  const reused=f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',occurrenceInput({durationMinutes:5}));
  assert.equal(reused.sessionId,r.sessionId);assert.equal(reused.opensAt,r.opensAt);assert.equal(JSON.stringify(f.store.Lab2SessionMeta),previous);
  const qr=f.c.lab2Mutate_(f.book,f.teacher,'getQrToken',{attendanceSessionId:r.sessionId});
  f.setNow('2026-10-11T09:30:00+07:00');
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.student,'checkInWithQr',{token:qr.token}),/SESSION_CLOSED/);
  const settled=f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',occurrenceInput());
  assert.equal(settled.status,'CLOSED');assert.equal(settled.sessionId,r.sessionId);assert.equal(f.store.Sessions.length,2);
  assert.equal(f.store.Attendance.length,3);f.c.reconcileExpiredSessions();assert.equal(f.store.Attendance.length,3);
});
test('past/future/fabricated/ambiguous occurrences and wrong ownership cannot create sessions',()=>{
  const f=scheduleFixture();
  for(const date of ['2026-10-04','2026-10-18']) assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',occurrenceInput({sessionDate:date})),/OCCURRENCE_(ENDED|NOT_YET)/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',occurrenceInput({scheduleId:'fake'})),/OCCURRENCE_NOT_FOUND/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',occurrenceInput({classId:'c2'})),/PERMISSION_DENIED/);
  f.add('Schedules',{...f.c.lab2Read_(f.book,'Schedules')[0],scheduleId:'duplicate'});
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',{classId:'c1',sessionDate:'2026-10-11',slot:1,durationMinutes:10}),/OCCURRENCE_DUPLICATE/);
  assert.equal(f.store.Sessions.length,1);
});
test('cancelled/rescheduled original occurrence is rejected; makeup is resolved by server with its own deadline',()=>{
  const f=scheduleFixture();
  f.c.lab2Mutate_(f.book,f.teacher,'saveScheduleException',{classId:'c1',scheduleId:'sch1',date:'2026-10-11',kind:'RESCHEDULED',targetDate:'2026-10-12',slot:2,startTime:'10:00',endTime:'11:00',reason:'Approved move'});
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',occurrenceInput()),/OCCURRENCE_NOT_FOUND/);
  f.c.lab2Mutate_(f.book,f.teacher,'saveScheduleException',{classId:'c1',scheduleId:'sch1',date:'2026-10-11',kind:'MAKEUP',targetDate:'2026-10-11',slot:3,startTime:'10:00',endTime:'10:30',reason:'Approved makeup'});
  f.setNow('2026-10-11T10:25:00+07:00');
  const input=occurrenceInput({slot:3,durationMinutes:30}),view=f.c.lab2OccurrenceView_(f.book,f.teacher,input);
  assert.equal(view.state,'AVAILABLE');assert.ok(view.exceptionId);
  const receipt=f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',{...input,occurrenceId:view.occurrenceId});
  assert.equal(receipt.effectiveDurationMinutes,5);
});
test('overnight occurrence remains attached to original date; backend caps at next-day end and denies future creation',()=>{
  const f=scheduleFixture();f.store.Schedules[1][8]='23:30';f.store.Schedules[1][9]='00:30';
  f.setNow('2026-10-12T00:25:00+07:00');
  const receipt=f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',occurrenceInput({durationMinutes:30}));
  assert.equal(receipt.effectiveDurationMinutes,5);assert.equal(f.c.lab2Read_(f.book,'Sessions')[0].date,'2026-10-11');
  assert.equal(f.c.lab2Snapshot_(f.book,f.teacher).collections.classSessions[0].endsAt,Date.parse('2026-10-12T00:30:00+07:00'));
  const next=scheduleFixture();next.store.Schedules[1][8]='00:05';next.store.Schedules[1][9]='01:00';next.setNow('2026-10-10T23:55:00+07:00');
  assert.throws(()=>next.c.lab2Mutate_(next.book,next.teacher,'createClassSession',occurrenceInput()),/OCCURRENCE_NOT_YET/);
});
test('create lock excludes overlapping request; lost-response retry and failed batch preserve one session+meta',()=>{
  const f=scheduleFixture();let held=false,overlappingError;
  f.c.LockService={getScriptLock:()=>({tryLock:()=>{if(held)return false;held=true;return true;},releaseLock:()=>{held=false;}})};
  const commit=f.c.Sheets.Spreadsheets.batchUpdate;
  f.c.Sheets.Spreadsheets.batchUpdate=(...args)=>{try{f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',occurrenceInput());}catch(e){overlappingError=e.message;}commit(...args);};
  const first=f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',occurrenceInput());
  assert.equal(overlappingError,'RATE_LIMITED');
  const retry=f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',occurrenceInput());assert.equal(retry.sessionId,first.sessionId);
  assert.equal(f.store.Sessions.length,2);assert.equal(f.store.Lab2SessionMeta.length,2);
  const broken=scheduleFixture();broken.c.Sheets.Spreadsheets.batchUpdate=()=>{throw Error('batch rejected');};
  assert.throws(()=>broken.c.lab2Mutate_(broken.book,broken.teacher,'createClassSession',occurrenceInput()),/batch rejected/);
  assert.equal(broken.store.Sessions.length,1);assert.equal(broken.store.Lab2SessionMeta.length,1);
});
test('Desktop cannot bypass opening window or schedule; reset is explicit, atomic and Mobile never recreates reset-only',()=>{
  const f=scheduleFixture(),request={action:'createSession',classId:'c1',date:'2026-10-11',slot:1,startTime:'00:00',endTime:'23:59',currentToken:'desktop',tokenExpiredAt:'2026-10-11T10:00:00+07:00'};
  f.setNow('2026-10-11T07:44:00+07:00');assert.throws(()=>f.c.handleSession_(f.book,f.c.config_(),f.teacher.entity,request),/OCCURRENCE_NOT_YET/);
  f.setNow('2026-10-11T08:00:00+07:00');const first=f.c.handleSession_(f.book,f.c.config_(),f.teacher.entity,request);
  assert.equal(first.startTime,'08:00');assert.equal(first.endTime,'09:30');assert.equal(first.closesAt,Date.parse('2026-10-11T08:10:00+07:00'));
  const reset=f.c.handleSession_(f.book,f.c.config_(),f.teacher.entity,{action:'resetSession',sessionId:first.sessionId});
  assert.notEqual(reset.sessionId,first.sessionId);assert.equal(f.c.lab2Read_(f.book,'Sessions')[0].status,'RESET');
  const oldRetry=f.c.handleSession_(f.book,f.c.config_(),f.teacher.entity,{action:'resetSession',sessionId:first.sessionId});assert.equal(oldRetry.sessionId,reset.sessionId);
  const only=scheduleFixture();only.add('Sessions',{sessionId:'old',classId:'c1',date:'2026-10-11',slot:1,status:'RESET'});
  assert.throws(()=>only.c.lab2Mutate_(only.book,only.teacher,'createClassSession',occurrenceInput()),/SESSION_RESET_REQUIRES_DESKTOP/);
  const duplicate=scheduleFixture();duplicate.add('Sessions',{sessionId:'a',classId:'c1',date:'2026-10-11',slot:1,status:'CLOSED'});duplicate.add('Sessions',{sessionId:'b',classId:'c1',date:'2026-10-11',slot:1,status:'CLOSED'});
  assert.throws(()=>duplicate.c.lab2OccurrenceView_(duplicate.book,duplicate.teacher,occurrenceInput()),/INVALID_SHEET_IDS/);
});


test('schedule session Web check-in and close share one lock in either order',()=>{
  for(const closeFirst of [false,true]) {
    const f=scheduleFixture();const r=f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',occurrenceInput());
    const s=f.c.lab2Read_(f.book,'Sessions')[0];f.c.authenticateFirebaseStudent_=()=>f.c.lab2Read_(f.book,'Students')[0];
    const request={sessionId:r.sessionId,token:s.currentToken,confirmPresent:true,firebaseAuth:true,idToken:'verified'};
    let held=false,blocked=false;const commit=f.c.Sheets.Spreadsheets.batchUpdate;
    f.c.LockService={getScriptLock:()=>({tryLock:()=>{if(held)return false;held=true;return true;},releaseLock:()=>held=false})};
    const close=()=>f.c.lab2Mutate_(f.book,f.teacher,'closeAttendanceSession',{attendanceSessionId:r.sessionId});
    const check=()=>f.c.handleStudentCheckIn_(request);
    f.c.Sheets.Spreadsheets.batchUpdate=(...args)=>{
      try {if(closeFirst)check();else close();}catch(e){blocked=/bận|RATE_LIMITED/.test(e.message);}
      commit(...args);
    };
    if(closeFirst)close();else check();assert.equal(blocked,true);
    f.c.Sheets.Spreadsheets.batchUpdate=commit;
    if(closeFirst)assert.throws(check,/kết thúc/);else close();
    const rows=f.c.lab2Read_(f.book,'Attendance');assert.equal(rows.length,2);
    assert.equal(rows.find(a=>a.studentId==='s1').status,closeFirst?'ABSENT':'PRESENT');
    close();assert.equal(f.c.lab2Read_(f.book,'Attendance').length,2);
  }
});

test('Desktop list reconciles elapsed server deadline and preserves authoritative receipt',()=>{
  const f=scheduleFixture(),r=f.c.lab2Mutate_(f.book,f.teacher,'createClassSession',occurrenceInput());
  f.setNow('2026-10-11T08:10:00+07:00');
  const rows=f.c.handleSession_(f.book,f.c.config_(),f.teacher.entity,{action:'getSessionsByClass',classId:'c1'});
  assert.equal(rows[0].status,'CLOSED');assert.equal(rows[0].closesAt,r.closesAt);assert.equal(rows[0].effectiveDurationMinutes,10);
  assert.equal(f.c.lab2Read_(f.book,'Attendance').length,2);
});

test('overnight exception conflicts are checked across adjacent campus dates',()=>{
  const f=scheduleFixture();
  f.add('Schedules',{scheduleId:'night',lecturerId:'l1',semester:'',subjectCode:'PRM393',classCode:'SE1',dayOfWeek:7,slot:4,startTime:'23:30',endTime:'00:30'});
  const move={classId:'c1',scheduleId:'sch1',date:'2026-10-11',kind:'MAKEUP',targetDate:'2026-10-12',slot:5,startTime:'00:15',endTime:'01:00',reason:'Makeup'};
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'saveScheduleException',move),/SCHEDULE_CONFLICT/);
  assert.doesNotThrow(()=>f.c.lab2Mutate_(f.book,f.teacher,'saveScheduleException',{...move,startTime:'00:30'}));
});

function quickSelector(f) {
  return {classId:'c1',sessionDate:testSchedule(f,'1'),slot:'1'};
}
function quickRecords(f,sessionId) {
  return Object.fromEntries(f.c.lab2Read_(f.book,'Attendance').filter(r=>r.sessionId===sessionId).map(r=>[r.studentId,r.status]));
}

test('quick attendance context is read-only and lists the roster without creating a session',()=>{
  const f=fixture(), sel=quickSelector(f), sessionsBefore=f.store.Sessions.length, writes=f.writes();
  const ctx=f.c.lab2QuickContext_(f.book,f.teacher,sel);
  assert.equal(ctx.state,'AVAILABLE');
  assert.equal(ctx.editable,true);
  assert.equal(ctx.revision,'');
  assert.deepEqual(Array.from(ctx.students,s=>[s.studentId,s.status]),[['s1',null],['s2',null]]);
  assert.equal(f.store.Sessions.length,sessionsBefore);
  assert.equal(f.writes(),writes);
});

test('quick attendance saves default PRESENT plus exceptions, closes the session and marks the lesson completed',()=>{
  const f=fixture(), sel=quickSelector(f);
  const out=f.c.lab2Mutate_(f.book,f.teacher,'submitQuickAttendance',{...sel,expectedRevision:'',studentIds:['s1','s2'],
    clientRequestId:'r1',exceptions:[{studentUid:'student-s2',status:'absent'}]});
  assert.equal(out.status,'CLOSED');
  assert.equal(out.alreadySaved,false);
  assert.equal(out.counts.present,1);
  assert.equal(out.counts.absent,1);
  assert.deepEqual(quickRecords(f,out.sessionId),{s1:'PRESENT',s2:'ABSENT'});
  const snap=f.c.lab2Snapshot_(f.book,f.teacher);
  assert.equal(snap.collections.classSessions.find(s=>s.id===out.sessionId).status,'completed');
});

test('quick attendance retry after a lost response is acknowledged without new writes; a different payload is refused',()=>{
  const f=fixture(), sel=quickSelector(f);
  const payload={...sel,expectedRevision:'',studentIds:['s1','s2'],exceptions:[{studentId:'s2',status:'LATE'}]};
  const first=f.c.lab2Mutate_(f.book,f.teacher,'submitQuickAttendance',payload), writes=f.writes();
  const again=f.c.lab2Mutate_(f.book,f.teacher,'submitQuickAttendance',payload);
  assert.equal(again.alreadySaved,true);
  assert.equal(again.sessionId,first.sessionId);
  assert.equal(f.writes(),writes);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'submitQuickAttendance',{...payload,exceptions:[{studentId:'s2',status:'ABSENT'}]}),/ATTENDANCE_ALREADY_FINALIZED/);
  assert.deepEqual(quickRecords(f,first.sessionId),{s1:'PRESENT',s2:'LATE'});
});

test('quick attendance keeps existing QR/manual results and rejects stale revisions or a changed roster',()=>{
  const f=fixture(), sel=quickSelector(f), id=create(f);
  f.c.lab2Mutate_(f.book,f.teacher,'updateAttendanceRecord',{attendanceSessionId:id,studentUid:'student-s1',status:'late',notes:'Đến muộn'});
  const ctx=f.c.lab2QuickContext_(f.book,f.teacher,sel);
  assert.equal(ctx.state,'OPEN');
  assert.equal(ctx.students.find(s=>s.studentId==='s1').status,'late');
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'submitQuickAttendance',{...sel,expectedRevision:'',studentIds:['s1','s2'],exceptions:[]}),/ATTENDANCE_CONFLICT/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'submitQuickAttendance',{...sel,expectedRevision:ctx.revision,studentIds:['s1'],exceptions:[]}),/ROSTER_CHANGED/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'submitQuickAttendance',{...sel,expectedRevision:ctx.revision,studentIds:['s1','s2'],exceptions:[{studentId:'s9',status:'ABSENT'}]}),/ROSTER_CHANGED/);
  const out=f.c.lab2Mutate_(f.book,f.teacher,'submitQuickAttendance',{...sel,expectedRevision:ctx.revision,studentIds:['s1','s2'],exceptions:[]});
  assert.equal(out.sessionId,id);
  assert.deepEqual(quickRecords(f,id),{s1:'LATE',s2:'PRESENT'});
});

test('quick attendance changing an existing record writes an audit row; other lecturers and bad input are refused',()=>{
  const f=fixture(), sel=quickSelector(f), id=create(f);
  f.c.lab2Mutate_(f.book,f.teacher,'updateAttendanceRecord',{attendanceSessionId:id,studentUid:'student-s1',status:'present',notes:'QR lỗi'});
  const auditsBefore=f.c.lab2Read_(f.book,'AttendanceAudit').length;
  const ctx=f.c.lab2QuickContext_(f.book,f.teacher,sel);
  f.c.lab2Mutate_(f.book,f.teacher,'submitQuickAttendance',{...sel,expectedRevision:ctx.revision,studentIds:['s1','s2'],exceptions:[{studentId:'s1',status:'EXCUSED'}]});
  const audits=f.c.lab2Read_(f.book,'AttendanceAudit');
  assert.equal(audits.length,auditsBefore+1);
  assert.equal(audits.at(-1).newStatus,'EXCUSED');
  const other=f.c.lab2Actor_({email:'other@fpt.edu.vn',firebaseUid:'firebase-other'},f.c.config_(),f.book);
  assert.throws(()=>f.c.lab2QuickContext_(f.book,other,sel),/PERMISSION_DENIED|OCCURRENCE/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.student,'submitQuickAttendance',{...sel,expectedRevision:'',studentIds:['s1'],exceptions:[]}),/PERMISSION_DENIED/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'submitQuickAttendance',{...sel,expectedRevision:'',studentIds:['s1','s1'],exceptions:[]}),/INVALID_INPUT/);
  assert.throws(()=>f.c.lab2Mutate_(f.book,f.teacher,'submitQuickAttendance',{...sel,expectedRevision:'',studentIds:['s1','s2'],exceptions:[{studentId:'s1',status:'MAYBE'}]}),/INVALID_INPUT/);
});
