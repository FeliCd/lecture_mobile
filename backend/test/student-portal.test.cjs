const test=require('node:test');
const assert=require('node:assert/strict');
const {fixture}=require('./portal-fixture.cjs');
function setup() {
  const f=fixture('2026-10-24T01:00:00Z');
  f.add('Schedules',{scheduleId:'sched-1',lecturerId:'l1',semester:'',subjectCode:'PRM393',classCode:'SE1',dayOfWeek:6,slot:1,startTime:'09:00',endTime:'10:30'});
  const call=(a,m,d={})=>f.c.portalCall_(f.book,a,m,d);
  const slots=call(f.student,'listOccurrences',{classId:'c1',date:'2026-10-24'});
  return {...f,call,occurrenceId:slots[0].occurrenceId};
}
function submit(f,extra={}) {
  return f.call(f.student,'submitLeaveRequest',{classId:'c1',sessionDate:'2026-10-24',occurrenceId:f.occurrenceId,reason:'Khám bệnh theo lịch hẹn',requestKey:'request-leave-123456',...extra});
}
function review(f,r,status='APPROVED',extra={}) {
  return f.call(f.teacher,'reviewLeaveRequest',{classId:'c1',id:r.id,version:r.version,status,reviewNote:'',...extra});
}
function save(f,version=0,grades={p:0},extra={}) {
  return f.call(f.teacher,'saveGradebook',{classId:'c1',version,components:[{id:'p',name:'Practical',maxScore:10}],students:[{studentId:'s1',grades,comment:'Good'},{studentId:'s2',grades:{p:9},comment:''}],...extra});
}
function publish(f,version=1,key='request-publish-12345') {
  return f.call(f.teacher,'publishGrades',{classId:'c1',version,studentIds:['s1','s2'],requestKey:key});
}
test('leave exists before session; duplicates and retries never create extra rows',()=>{
  const f=setup(),r=submit(f);
  assert.equal(r.status,'PENDING');assert.equal(f.c.lab2Read_(f.book,'Sessions').length,0);
  assert.equal(submit(f).id,r.id);
  assert.throws(()=>submit(f,{requestKey:'request-leave-other1'}),/LEAVE_DUPLICATE/);
  assert.equal(f.call(f.teacher,'listClassLeaveRequests',{classId:'c1',sessionDate:'2026-10-24',slot:1}).length,1);
  assert.equal(f.call(f.teacher,'listClassLeaveRequests',{classId:'c1',slot:2}).length,0);
  assert.equal(f.c.lab2Read_(f.book,'PortalLeaveRequests').length,1);
});
test('membership, identity and ownership cannot be supplied by a client',()=>{
  const f=setup();
  assert.throws(()=>submit(f,{classId:'c2'}),/NOT_ENROLLED/);
  const r=submit(f,{studentId:'s2',email:'other-student@fpt.edu.vn',status:'APPROVED'});
  assert.equal(r.studentId,'s1');assert.equal(r.status,'PENDING');
  assert.throws(()=>f.call(f.student,'reviewLeaveRequest',{classId:'c1',id:r.id,version:1,status:'APPROVED'}),/PERMISSION_DENIED/);
  assert.throws(()=>f.call(f.teacher,'listClassLeaveRequests',{classId:'c2'}),/PERMISSION_DENIED/);
  const other={...f.student,entity:{studentId:'s2'}};
  assert.equal(f.call(other,'listMyLeaveRequests').length,0);
  assert.throws(()=>f.call(other,'cancelLeaveRequest',{id:r.id,version:1}),/PERMISSION_DENIED/);
});
test('reject/cancel/version transitions and deadline are enforced by server',()=>{
  const f=setup(),r=submit(f);
  assert.throws(()=>review(f,r,'REJECTED'),/INVALID_REASON/);
  assert.throws(()=>review(f,{...r,version:0}),/VERSION_CONFLICT/);
  const rejected=review(f,r,'REJECTED',{reviewNote:'Thiếu thông tin'});
  assert.equal(rejected.status,'REJECTED');
  const next=submit(f,{requestKey:'request-leave-second'});
  const cancelled=f.call(f.student,'cancelLeaveRequest',{id:next.id,version:next.version});
  assert.equal(cancelled.status,'CANCELLED');
  assert.equal(f.call(f.student,'cancelLeaveRequest',{id:next.id,version:next.version}).status,'CANCELLED');
  f.setNow('2026-10-24T02:00:00Z');
  assert.throws(()=>submit(f,{requestKey:'request-leave-third1'}),/LEAVE_TOO_LATE/);
});
test('changed schedule is flagged and cannot be approved/applied',()=>{
  const f=setup(),r=submit(f);
  // Same occurrence hash, changed time: compare captured times too.
  f.store.Schedules[1][9]='09:15';
  assert.equal(f.call(f.student,'listMyLeaveRequests')[0].scheduleChanged,true);
  assert.throws(()=>review(f,r),/OCCURRENCE_CHANGED/);
  f.add('Sessions',{sessionId:'sess',classId:'c1',date:'2026-10-24',slot:1,status:'OPEN'});
  assert.equal(f.c.portalApprovedForSession_(f.book,f.c.lab2Read_(f.book,'Sessions')[0]).size,0);
});
test('approved leaves survive session reset and finalize as EXCUSED without overriding attendance',()=>{
  const f=setup(),r=submit(f);review(f,r);
  for(const id of ['old','fresh']) {
    f.add('Sessions',{sessionId:id,classId:'c1',date:'2026-10-24',slot:1,startTime:'09:00',endTime:'10:30',status:id==='old'?'RESET':'OPEN',createdBy:'l1'});
  }
  f.add('Lab2SessionMeta',{sessionId:'fresh',opensAt:Date.parse('2026-10-24T02:00:00Z'),closesAt:Date.parse('2026-10-24T02:10:00Z'),eligibleStudentIds:'["s1","s2"]'});
  f.add('Attendance',{attendanceId:'a2',sessionId:'fresh',studentId:'s2',status:'PRESENT',note:'QR'});
  const s=f.c.lab2Read_(f.book,'Sessions').find(s=>s.sessionId==='fresh');
  f.c.lab2Finalize_(f.book,s);
  const rows=f.c.lab2Read_(f.book,'Attendance');
  assert.equal(rows.find(r=>r.studentId==='s1').status,'EXCUSED');
  assert.equal(rows.find(r=>r.studentId==='s2').status,'PRESENT');
});
test('pending leave finalizes as absent; late approval requires explicit audited correction',()=>{
  const f=setup(),r=submit(f);
  const s={sessionId:'sess',classId:'c1',date:'2026-10-24',slot:1,status:'OPEN',createdBy:'l1'};
  f.add('Sessions',s);f.add('Lab2SessionMeta',{sessionId:'sess',opensAt:0,closesAt:9999999999999,eligibleStudentIds:'["s1","s2"]'});
  f.c.lab2Finalize_(f.book,s);
  assert.equal(f.c.lab2Read_(f.book,'Attendance')[0].status,'ABSENT');
  review(f,r);
  assert.equal(f.c.lab2Read_(f.book,'Attendance')[0].status,'ABSENT');
  f.call(f.teacher,'applyApprovedLeave',{sessionId:'sess',studentId:'s1'});
  assert.equal(f.c.lab2Read_(f.book,'Attendance')[0].status,'EXCUSED');
  assert.equal(f.c.lab2Read_(f.book,'AttendanceAudit').length,1);
});
test('published grades are own immutable snapshots, including zero; revoke hides publication',()=>{
  const f=setup();save(f);
  assert.equal(f.call(f.student,'getMyPublishedGrades',{classId:'c1'}).published,false);
  const p=publish(f);assert.equal(publish(f).publicationId,p.publicationId);
  let g=f.call(f.student,'getMyPublishedGrades',{classId:'c1',studentId:'s2'});
  assert.equal(g.grades.p,0);assert.equal(g.comment,'Good');
  save(f,2,{p:7});
  g=f.call(f.student,'getMyPublishedGrades',{classId:'c1'});assert.equal(g.grades.p,0);
  publish(f,3,'request-publish-second');
  assert.equal(f.call(f.student,'getMyPublishedGrades',{classId:'c1'}).grades.p,7);
  f.call(f.teacher,'revokeGrades',{classId:'c1',version:4});
  assert.equal(f.call(f.student,'getMyPublishedGrades',{classId:'c1'}).published,false);
  assert.equal(f.c.lab2Read_(f.book,'PortalPublications').length,2);
});
test('grades validate ownership, range, finite values, full roster and optimistic versions',()=>{
  const f=setup();
  for(const value of [-1,11,NaN,Infinity,'5']) assert.throws(()=>save(f,0,{p:value}),/INVALID_GRADE_RANGE/);
  assert.equal(f.c.lab2Read_(f.book,'PortalGradeDrafts').length,0);
  save(f);
  assert.throws(()=>save(f),/VERSION_CONFLICT/);
  assert.throws(()=>save(f,1,{p:4},{students:[]}),/ROSTER_CHANGED/);
  assert.throws(()=>f.call(f.student,'getGradebook',{classId:'c1'}),/PERMISSION_DENIED/);
  assert.throws(()=>f.call(f.student,'getMyPublishedGrades',{classId:'c2'}),/NOT_ENROLLED/);
  assert.throws(()=>f.call(f.teacher,'getGradebook',{classId:'c2'}),/PERMISSION_DENIED/);
});
test('publication is atomic and rejects roster changes since teacher preview',()=>{
  const f=setup();save(f);const before=f.writes();
  f.add('Students',{studentId:'s3',studentCode:'SE3',schoolEmail:'new@fpt.edu.vn'});
  f.add('Enrollments',{enrollmentId:'e3',classId:'c1',studentId:'s3'});
  assert.throws(()=>publish(f),/ROSTER_CHANGED/);assert.equal(f.writes(),before);
  f.store.Enrollments.pop();publish(f);assert.equal(f.writes(),before+1);
  assert.equal(f.c.lab2Read_(f.book,'PortalPublishedGrades').length,2);
});
test('failed publication batch leaves no active pointer; retry publishes once',()=>{
  const f=setup();save(f);
  const original=f.c.Sheets.Spreadsheets.batchUpdate;
  f.c.Sheets.Spreadsheets.batchUpdate=()=>{throw Error('simulated outage');};
  assert.throws(()=>publish(f),/simulated outage/);
  assert.equal(f.call(f.student,'getMyPublishedGrades',{classId:'c1'}).published,false);
  assert.equal(f.c.lab2Read_(f.book,'PortalPublications').length,0);
  f.c.Sheets.Spreadsheets.batchUpdate=original;
  publish(f);publish(f);
  assert.equal(f.c.lab2Read_(f.book,'PortalPublications').length,1);
});
test('separate portal Firebase project is verified; mobile project tokens are rejected',()=>{
  const f=setup();f.props.PORTAL_FIREBASE_PROJECT_ID='fu-grade-fptu';f.props.PORTAL_FIREBASE_API_KEY='portal-key';
  function token(project){return 'header.'+Buffer.from(JSON.stringify({aud:project,iss:'https://securetoken.google.com/'+project,sub:'uid',exp:Math.floor(f.c.Date.now()/1000)+3600})).toString('base64url')+'.signature';}
  f.c.UrlFetchApp={fetch:(url,opts)=>{
    assert.ok(url.includes('portal-key'));assert.ok(JSON.parse(opts.payload).idToken);
    return {getResponseCode:()=>200,getContentText:()=>JSON.stringify({users:[{localId:'uid',email:'student@fpt.edu.vn',emailVerified:true}]})};
  }};
  const result=f.c.portalHandle_({firebaseAuth:true,idToken:token('fu-grade-fptu'),method:'listClasses'});
  assert.equal(result.length,1);assert.equal(result[0].classId,'c1');
  assert.throws(()=>f.c.portalHandle_({firebaseAuth:true,idToken:token('fap-attendance-88920'),method:'listClasses'}),/UNAUTHENTICATED/);
});
