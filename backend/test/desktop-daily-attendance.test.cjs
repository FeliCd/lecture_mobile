const test=require('node:test');
const assert=require('node:assert/strict');
const {fixture}=require('./portal-fixture.cjs');
function setup(now='2026-10-30T15:00:00Z') {
  const f=fixture(now);
  f.add('Schedules',{scheduleId:'fri',lecturerId:'l1',semester:'',classCode:'SE1',subjectCode:'PRM393',dayOfWeek:5,slot:1,startTime:'09:00',endTime:'10:00',room:'A201'});
  const lecturer=f.teacher.entity;
  const call=(name,input)=>f.c.lab2DesktopAttendance_(f.book,lecturer,{name,input});
  const selector={classId:'c1',sessionDate:'2026-10-30',slot:1,scheduleId:'fri',exceptionId:''};
  const input=(context,extra={})=>({...selector,expectedRevision:context.revision,clientRequestId:'desktop-request-123',studentIds:context.students.map(s=>s.studentId),exceptions:[],...extra});
  return {...f,call,selector,input};
}
test('desktop today exposes ended lessons as editable until midnight, with authoritative ownership',()=>{
  const f=setup();
  const result=f.call('getAttendanceDay',{sessionDate:'2026-10-30'});
  assert.equal(result.lessons.length,1);assert.equal(result.lessons[0].classId,'c1');
  assert.equal(result.lessons[0].qrState,'ENDED');assert.equal(result.lessons[0].editable,true);
  assert.equal(result.lessons[0].completed,false);
  assert.throws(()=>f.c.lab2DesktopAttendance_(f.book,{lecturerId:'l2',email:'other@fpt.edu.vn'},{name:'getQuickAttendanceContext',input:f.selector}),/PERMISSION_DENIED/);
});
test('desktop default PRESENT plus explicit absent uses the same records and completion as mobile',()=>{
  const f=setup(),q=f.call('getQuickAttendanceContext',f.selector);
  assert.ok(q.students.every(s=>s.status===null));assert.equal(f.writes(),0);
  const payload=f.input(q,{exceptions:[{studentId:'s2',status:'ABSENT'}]});
  const saved=f.call('submitQuickAttendance',payload);
  assert.equal(f.writes(),1);assert.equal(saved.status,'CLOSED');
  assert.equal(f.call('submitQuickAttendance',payload).alreadySaved,true);assert.equal(f.writes(),1);
  const mobile=f.c.lab2QuickContext_(f.book,f.teacher,f.selector);
  assert.equal(mobile.attendanceCompleted,true);assert.equal(mobile.students.find(s=>s.studentId==='s1').status,'present');
  assert.equal(mobile.students.find(s=>s.studentId==='s2').status,'absent');
  assert.equal(f.call('getAttendanceDay',{sessionDate:'2026-10-30'}).lessons[0].completed,true);
});
test('mobile concurrent save invalidates desktop draft rather than overwriting',()=>{
  const f=setup(),q=f.call('getQuickAttendanceContext',f.selector);
  f.c.lab2Mutate_(f.book,f.teacher,'submitQuickAttendance',f.input(q,{clientRequestId:'mobile-save-123'}));
  assert.throws(()=>f.call('submitQuickAttendance',f.input(q,{exceptions:[{studentId:'s1',status:'ABSENT'}]})),/ATTENDANCE_CONFLICT/);
  const fresh=f.call('getQuickAttendanceContext',f.selector);
  f.call('submitQuickAttendance',f.input(fresh,{clientRequestId:'desktop-save-fresh',exceptions:[{studentId:'s1',status:'ABSENT'}]}));
  assert.equal(f.c.lab2QuickContext_(f.book,f.teacher,f.selector).students[0].status,'absent');
});
test('23:59:59 accepted, midnight rejects new edits and preserves lost-response retry receipt',()=>{
  const f=setup('2026-10-30T16:59:59Z'),q=f.call('getQuickAttendanceContext',f.selector),payload=f.input(q);
  f.call('submitQuickAttendance',payload);
  f.setNow('2026-10-30T17:00:00Z');
  assert.equal(f.call('submitQuickAttendance',payload).alreadySaved,true);
  const fresh=f.call('getQuickAttendanceContext',f.selector);assert.equal(fresh.editable,false);
  assert.throws(()=>f.call('submitQuickAttendance',f.input(fresh,{clientRequestId:'new-after-midnight',exceptions:[{studentId:'s1',status:'ABSENT'}]})),/QUICK_ATTENDANCE_DAY_EXPIRED/);
});
test('same-day before lesson can be marked quickly without opening a premature QR session',()=>{
  const f=setup('2026-10-29T17:01:00Z');
  assert.equal(f.call('getAttendanceDay',{sessionDate:'2026-10-30'}).lessons[0].qrState,'NOT_YET');
  const q=f.call('getQuickAttendanceContext',f.selector);
  f.call('submitQuickAttendance',f.input(q));
  assert.equal(f.c.lab2Read_(f.book,'Sessions')[0].status,'CLOSED');
});
test('day list follows cancellations and makeup, removes reminders after mobile completion',()=>{
  const f=setup();
  f.add('ScheduleExceptions',{id:'cancel',scheduleId:'fri',classId:'c1',date:'2026-10-30',kind:'CANCELLED'});
  assert.equal(f.call('getAttendanceDay',{sessionDate:'2026-10-30'}).lessons.length,0);
  f.add('ScheduleExceptions',{id:'makeup',scheduleId:'fri',classId:'c1',targetDate:'2026-10-30',kind:'MAKEUP',slot:'3',startTime:'12:00',endTime:'13:00',room:'B301'});
  const day=f.call('getAttendanceDay',{sessionDate:'2026-10-30'}),lesson=day.lessons[0];
  assert.equal(lesson.slot,3);assert.equal(lesson.exceptionId,'makeup');assert.equal(lesson.room,'B301');
});
test('OAuth desktop envelope reaches shared quick logic; malformed input and arbitrary actions are denied',()=>{
  const f=setup();
  f.c.UrlFetchApp={fetch:()=>({getResponseCode:()=>200,getContentText:()=>JSON.stringify({aud:'desktop',iss:'https://accounts.google.com',exp:f.c.Date.now()/1000+3600,email_verified:true,email:'teacher@fpt.edu.vn'})})};
  const response=f.c.doPost({postData:{contents:JSON.stringify({action:'desktopAttendanceCall',name:'getAttendanceDay',input:{sessionDate:'2026-10-30'},idToken:'mock-valid-google-token-123456789'})}});
  assert.equal(response.ok,true);assert.equal(response.data.lessons[0].classId,'c1');
  assert.throws(()=>f.call('deleteRow',{sessionDate:'2026-10-30'}),/FEATURE_DISABLED/);
  assert.throws(()=>f.call('getAttendanceDay',{sessionDate:'2026-02-31'}),/INVALID_SESSION_DATE/);
  assert.throws(()=>f.call('submitQuickAttendance',[]),/INVALID_INPUT/);
});
