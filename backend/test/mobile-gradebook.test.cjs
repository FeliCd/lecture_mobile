const test=require('node:test');
const assert=require('node:assert/strict');
const {fixture}=require('./portal-fixture.cjs');
function setup(email='teacher@fpt.edu.vn',provider='google.com',now) {
  const f=fixture(now);
  f.c.lab2FirebaseIdentity_=()=>({email,firebaseUid:'verified-device',signInProvider:provider,emailVerified:true});
  const call=(method,data={classId:'c1'})=>f.c.lab2Handle_({action:'lab2Call',idToken:'verified-test-token',name:'portalCall',input:{method,data}});
  return {...f,call};
}
test('mobile lecturer uses the same draft and immutable publication as desktop/student web',()=>{
  const f=setup();
  const book=f.call('getGradebook'); assert.equal(book.version,0);
  const rows=book.students.map(s=>({studentId:s.studentId,grades:{quiz:s.studentId==='s1'?0:8.5},comment:''}));
  f.call('saveGradebook',{classId:'c1',version:0,components:[{id:'quiz',name:'Quiz',maxScore:10}],students:rows});
  assert.equal(f.c.portalCall_(f.book,f.student,'getMyPublishedGrades',{classId:'c1'}).published,false);
  const payload={classId:'c1',version:1,requestKey:'mobile-publication-123456',studentIds:rows.map(s=>s.studentId)};
  const first=f.call('publishGrades',payload);
  assert.equal(f.call('publishGrades',payload).publicationId,first.publicationId);
  assert.equal(f.c.portalCall_(f.book,f.student,'getMyPublishedGrades',{classId:'c1'}).grades.quiz,0);
  f.call('saveGradebook',{classId:'c1',version:2,
    components:[{id:'quiz',name:'Quiz',maxScore:10},{id:'lab',name:'Lab',maxScore:10}],
    students:rows.map(s=>({...s,grades:{quiz:9,lab:''}}))});
  const desktopDraft=f.c.portalCall_(f.book,f.teacher,'getGradebook',{classId:'c1'});
  assert.equal(desktopDraft.components[1].name,'Lab');
  assert.equal(desktopDraft.students[0].grades.lab,'');
  const published=f.c.portalCall_(f.book,f.student,'getMyPublishedGrades',{classId:'c1'});
  assert.equal(published.grades.quiz,0);
  assert.equal(published.components.length,1);
  f.call('revokeGrades',{classId:'c1',version:3});
  assert.equal(f.c.portalCall_(f.book,f.student,'getMyPublishedGrades',{classId:'c1'}).published,false);
});
test('mobile grade route rejects student, wrong class, non-Google provider and unrelated APIs',()=>{
  assert.throws(()=>setup('student@fpt.edu.vn').call('getGradebook'),/PERMISSION_DENIED/);
  assert.throws(()=>setup().call('getGradebook',{classId:'c2'}),/PERMISSION_DENIED/);
  assert.throws(()=>setup('teacher@fpt.edu.vn','password').call('getGradebook'),/GOOGLE_ONLY/);
  assert.throws(()=>setup().call('getMyPublishedGrades'),/UNKNOWN_PORTAL_METHOD/);
});
test('mobile reviews the same leave request visible to Desktop and Student Web',()=>{
  const f=setup(undefined,undefined,'2026-10-24T01:00:00Z');
  const portal=(actor,method,data)=>f.c.portalCall_(f.book,actor,method,data);
  f.add('Schedules',{scheduleId:'sched-1',lecturerId:'l1',subjectCode:'PRM393',classCode:'SE1',dayOfWeek:6,slot:1,startTime:'09:00',endTime:'10:30'});
  const [lesson]=portal(f.student,'listOccurrences',{classId:'c1',date:'2026-10-24'});
  const request=portal(f.student,'submitLeaveRequest',{
    classId:'c1',sessionDate:'2026-10-24',occurrenceId:lesson.occurrenceId,
    reason:'Khám bệnh theo lịch hẹn',requestKey:'request-leave-mobile-123',
  });
  const scope={classId:'c1',sessionDate:'2026-10-24',slot:1};
  assert.equal(f.call('listClassLeaveRequests',scope).requests[0].id,request.id);
  assert.equal(f.call('listClassLeaveRequests',{...scope,slot:2}).requests.length,0);
  assert.equal(portal(f.teacher,'listClassLeaveRequests',scope).length,1);
  assert.throws(()=>f.call('listClassLeaveRequests',{classId:'c2'}),/PERMISSION_DENIED/);
  assert.throws(()=>setup('student@fpt.edu.vn').call('listClassLeaveRequests'),/PERMISSION_DENIED/);
  assert.throws(()=>f.call('submitLeaveRequest',scope),/UNKNOWN_PORTAL_METHOD/);
  const decision={classId:'c1',id:request.id,version:request.version,status:'APPROVED'};
  f.call('reviewLeaveRequest',decision);
  assert.throws(()=>f.call('reviewLeaveRequest',decision),/VERSION_CONFLICT/);
  assert.equal(portal(f.student,'listMyLeaveRequests',{})[0].status,'APPROVED');
  assert.equal(portal(f.teacher,'listClassLeaveRequests',scope)[0].status,'APPROVED');
  f.add('Sessions',{sessionId:'closed',classId:'c1',date:scope.sessionDate,slot:scope.slot,status:'CLOSED',createdBy:'l1'});
  f.add('Attendance',{attendanceId:'a1',sessionId:'closed',studentId:'s1',status:'ABSENT',note:'Lab2 finalized'});
  f.call('applyApprovedLeave',{sessionId:'closed',studentId:'s1'});
  assert.equal(f.c.lab2Read_(f.book,'Attendance')[0].status,'EXCUSED');
});
test('HTTP envelope permits bounded full-gradebook requests but retains global payload limit',()=>{
  const f=setup();
  const request={action:'lab2Call',idToken:'test',name:'portalCall',input:{method:'getGradebook',data:{classId:'c1'}},padding:'x'.repeat(210000)};
  assert.equal(f.c.doPost({postData:{contents:JSON.stringify(request)}}).ok,true);
  request.padding='x'.repeat(2000001);
  assert.equal(f.c.doPost({postData:{contents:JSON.stringify(request)}}).ok,false);
});
