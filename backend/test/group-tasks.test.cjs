const {test}=require('node:test');
const assert=require('node:assert/strict');
const {fixture}=require('./portal-fixture.cjs');
const groupId='group-task-12345678';
function setup() {
  const f=fixture('2026-11-04T03:00:00Z');
  const call=(actor,method,data={})=>f.c.portalCall_(f.book,actor,method,data);
  call(f.teacher,'saveGroupPlan',{classId:'c1',version:0,requestKey:'save-task-plan-1234',groups:[{id:groupId,name:'Nhóm 1',memberIds:['s1']},{id:'group-other-123456',name:'Nhóm 2',memberIds:['s2']}]});
  const data={classId:'c1',groupId,version:1,title:'Làm bài lab',description:'Hoàn thành bài lab nhóm.',dueAt:'2026-11-05T16:59:00.000Z',requestKey:'create-task-1234567'};
  const create=(extra={})=>call(f.teacher,'createGroupTask',{...data,...extra});
  const sent=[];
  f.c.MailApp={getRemainingDailyQuota:()=>100,sendEmail:m=>sent.push(m)};
  return {...f,call,data,create,sent};
}
test('task + per-member inbox + email outbox are atomic, with verified recipients',()=>{
  const f=setup(),before=f.writes(),r=f.create({email:'attacker@gmail.com',studentIds:['s2']});
  assert.equal(f.writes(),before+1);assert.equal(r.recipientCount,1);assert.equal(r.emailPendingCount,1);assert.equal(f.sent.length,0);
  const inbox=f.call(f.student,'listMyTaskNotifications');assert.equal(inbox.unreadCount,1);assert.equal(inbox.notifications[0].task.title,'Làm bài lab');assert.equal(inbox.notifications[0].email,undefined);
  const other={...f.student,entity:{studentId:'s2'},uid:'student-s2'};
  assert.equal(f.call(other,'listMyTaskNotifications').notifications.length,0);
});
test('idempotent retry after deadline or group changes returns existing receipt, conflicting payload rejected',()=>{
  const f=setup(),r=f.create();f.setNow('2026-11-06T00:00:00Z');
  assert.equal(f.create().id,r.id);assert.equal(f.c.lab2Read_(f.book,'PortalGroupTasks').length,1);
  assert.throws(()=>f.create({title:'Changed'}),/REQUEST_KEY_CONFLICT/);
});
test('student, foreign lecturer, stale plan, invalid input and missing setup rejected',()=>{
  const f=setup();
  assert.throws(()=>f.call(f.student,'createGroupTask',f.data),/PERMISSION_DENIED/);
  assert.throws(()=>f.create({classId:'c2'}),/PERMISSION_DENIED/);
  assert.throws(()=>f.create({version:0}),/VERSION_CONFLICT/);
  for(const extra of [{title:''},{description:''},{title:'Hi\nBcc: other@example.com'},{title:'x'.repeat(161)}]) assert.throws(()=>f.create(extra),/INVALID_TASK/);
  for(const dueAt of ['',null,'2020-01-01T00:00:00.000Z','2026-99-05T16:59:00.000Z']) assert.throws(()=>f.create({dueAt}),/INVALID_TASK_DEADLINE/);
  delete f.store.PortalGroupTasks;assert.throws(()=>f.create(),/GROUP_TASKS_SETUP_REQUIRED/);
});
test('school email validation fails atomically before creating task',()=>{
  const f=setup();f.store.Students[1][f.store.Students[0].indexOf('schoolEmail')]='outside@gmail.com';
  assert.throws(()=>f.create(),/GROUP_MEMBER_EMAIL_INVALID/);
  assert.equal(f.c.lab2Read_(f.book,'PortalGroupTasks').length,0);
});
test('mark read requires recipient and current membership; mere listing never marks read',()=>{
  const f=setup();f.create();const n=f.call(f.student,'listMyTaskNotifications').notifications[0];
  assert.equal(n.readAt,'');
  const other={...f.student,entity:{studentId:'s2'},uid:'student-s2'};
  assert.throws(()=>f.call(other,'readTaskNotification',{notificationId:n.id}),/GROUP_ACCESS_DENIED/);
  f.call(f.student,'readTaskNotification',{notificationId:n.id});
  assert.equal(f.call(f.student,'listMyTaskNotifications').unreadCount,0);
  assert.equal(f.call(f.teacher,'listGroupTasks',{classId:'c1'}).tasks[0].readCount,1);
  assert.throws(()=>f.call(f.student,'listGroupTasks',{classId:'c1'}),/PERMISSION_DENIED/);
});
test('worker sends only once, to school address, then records acceptance separately from read',()=>{
  const f=setup();f.create();f.c.sendGroupTaskEmails();f.c.sendGroupTaskEmails();
  assert.equal(f.sent.length,1);assert.equal(f.sent[0].to,'student@fpt.edu.vn');
  const task=f.call(f.teacher,'listGroupTasks',{classId:'c1'}).tasks[0];
  assert.equal(task.emailSentCount,1);assert.equal(task.readCount,0);
});
test('quota defers; uncertain mail failure never retries automatically',()=>{
  const f=setup();f.create();f.c.MailApp.getRemainingDailyQuota=()=>0;
  f.c.sendGroupTaskEmails();assert.equal(f.sent.length,0);
  f.c.MailApp.getRemainingDailyQuota=()=>10;
  let attempts=0;f.c.MailApp.sendEmail=()=>{attempts++;throw Error('uncertain');};
  assert.throws(()=>f.c.sendGroupTaskEmails(),/uncertain/);
  f.c.sendGroupTaskEmails();assert.equal(attempts,1);
  assert.equal(f.call(f.teacher,'listGroupTasks',{classId:'c1'}).tasks[0].emailReviewCount,1);
});
test('removed enrollment revokes inbox and skips queued email',()=>{
  const f=setup();f.create();f.store.Enrollments=f.store.Enrollments.filter(r=>!r.includes('s1'));
  assert.equal(f.call(f.student,'listMyTaskNotifications').notifications.length,0);
  f.c.sendGroupTaskEmails();assert.equal(f.sent.length,0);
  assert.equal(f.call(f.teacher,'listGroupTasks',{classId:'c1'}).tasks[0].emailSkippedCount,1);
});
test('new members do not inherit tasks; moved members lose inbox and pending email',()=>{
  const f=setup();f.create();
  f.call(f.teacher,'saveGroupPlan',{classId:'c1',version:1,requestKey:'move-task-plan-1234',groups:[{id:groupId,name:'Nhóm 1',memberIds:['s2']},{id:'group-other-123456',name:'Nhóm 2',memberIds:['s1']}]});
  assert.equal(f.call(f.student,'listMyTaskNotifications').notifications.length,0);
  const other={...f.student,entity:{studentId:'s2'},uid:'student-s2'};
  assert.equal(f.call(other,'listMyTaskNotifications').notifications.length,0);
  f.c.sendGroupTaskEmails();assert.equal(f.sent.length,0);
});
test('a failed task batch leaves no partial notifications and can be retried',()=>{
  const f=setup(),batch=f.c.Sheets.Spreadsheets.batchUpdate;
  f.c.Sheets.Spreadsheets.batchUpdate=()=>{throw Error('network');};
  assert.throws(()=>f.create(),/network/);
  assert.equal(f.c.lab2Read_(f.book,'PortalGroupTasks').length,0);
  assert.equal(f.c.lab2Read_(f.book,'PortalTaskNotifications').length,0);
  f.c.Sheets.Spreadsheets.batchUpdate=batch;
  f.create();f.create();assert.equal(f.call(f.student,'listMyTaskNotifications').notifications.length,1);
});
test('send accepted but receipt write lost stays claimed and is never blindly sent twice',()=>{
  const f=setup();f.create();const batch=f.c.Sheets.Spreadsheets.batchUpdate;
  f.c.MailApp.sendEmail=m=>{f.sent.push(m);f.c.Sheets.Spreadsheets.batchUpdate=()=>{throw Error('lost-write');};};
  assert.throws(()=>f.c.sendGroupTaskEmails(),/lost-write/);
  f.c.Sheets.Spreadsheets.batchUpdate=batch;f.c.sendGroupTaskEmails();assert.equal(f.sent.length,1);
  assert.equal(f.call(f.teacher,'listGroupTasks',{classId:'c1'}).tasks[0].emailReviewCount,1);
});
test('notification pagination counts all unread and read time remains idempotent',()=>{
  const f=setup();for(let i=0;i<52;i++)f.create({requestKey:'task-page-'+String(i).padStart(8,'0')});
  const first=f.call(f.student,'listMyTaskNotifications');assert.equal(first.notifications.length,50);assert.equal(first.unreadCount,52);assert.ok(first.older);
  const old=f.call(f.student,'listMyTaskNotifications',{before:first.older});assert.equal(old.notifications.length,2);assert.equal(old.older,null);
  const id=first.notifications[0].id,read=f.call(f.student,'readTaskNotification',{notificationId:id});
  f.setNow('2026-11-04T04:00:00Z');assert.equal(f.call(f.student,'readTaskNotification',{notificationId:id}).readAt,read.readAt);
  assert.equal(f.call(f.student,'listMyTaskNotifications').unreadCount,51);
});
