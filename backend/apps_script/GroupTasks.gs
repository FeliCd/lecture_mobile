/* Group tasks and a durable, per-student notification/email outbox. */
function setupGroupTasks() {
  setupStudentPortal(); // Additive schema initialization only, never sends mail.
  return {ready:true};
}
// Owner runs once after authorizing send_mail. Not exposed by either API router.
function installGroupTaskEmailTrigger() {
  setupGroupTasks();
  if(!ScriptApp.getProjectTriggers().some(t=>t.getHandlerFunction()==='sendGroupTaskEmails')) {
    ScriptApp.newTrigger('sendGroupTaskEmails').timeBased().everyMinutes(5).create();
  }
  return {ready:true};
}
function groupTasksReady_(book) {
  for(const name of ['PortalGroupTasks','PortalTaskNotifications']) {
    if(!sharedHasTable_(book,name)) throw Error('GROUP_TASKS_SETUP_REQUIRED');
  }
}
function groupTaskVisible_(book,actor,task,notification) {
  if(!task||!notification||notification.studentId!==actor.entity.studentId) return false;
  try {
    groupAccess_(book,actor,{classId:task.classId,groupId:task.groupId});
    return true;
  } catch(_) {return false;}
}
function groupTaskReceipt_(book,task) {
  const rows=sharedRowsWhere_(book,'PortalTaskNotifications','taskId',task.id);
  return {id:task.id,recipientCount:rows.length,readCount:rows.filter(n=>n.readAt).length,
    emailSentCount:rows.filter(n=>n.emailStatus==='SENT').length,
    emailPendingCount:rows.filter(n=>n.emailStatus==='PENDING').length,
    emailReviewCount:rows.filter(n=>['SENDING','UNKNOWN'].includes(n.emailStatus)).length,
    emailSkippedCount:rows.filter(n=>n.emailStatus==='SKIPPED').length};
}
function groupTaskCall_(book,actor,method,d) {
  groupTasksReady_(book);
  if(method==='listMyTaskNotifications'||method==='readTaskNotification') {
    portalStudent_(actor);
    const tasks=lab2Read_(book,'PortalGroupTasks'),mine=sharedRowsWhere_(book,'PortalTaskNotifications','studentId',actor.entity.studentId);
    const classes=lab2Read_(book,'Classes');
    const visible=mine.filter(n=>groupTaskVisible_(book,actor,tasks.find(t=>t.id===n.taskId),n));
    if(method==='readTaskNotification') {
      const row=visible.find(n=>n.id===d.notificationId);
      if(!row) throw Error('GROUP_ACCESS_DENIED');
      const readAt=row.readAt||new Date().toISOString();
      if(!row.readAt) lab2Write_(book,[{table:'PortalTaskNotifications',row:{...row,readAt}}]);
      return {saved:true,readAt};
    }
    const ordered=visible.sort((a,b)=>b.createdAt.localeCompare(a.createdAt)||b.id.localeCompare(a.id));
    const start=d.before?ordered.findIndex(n=>n.id===d.before)+1:0;
    if(d.before&&start===0) throw Error('INVALID_CURSOR');
    const page=ordered.slice(start,start+50);
    return {unreadCount:visible.filter(n=>!n.readAt).length,older:start+50<ordered.length?page[page.length-1].id:null,
      notifications:page.map(n=>{const t=tasks.find(t=>t.id===n.taskId),cls=classes.find(c=>c.classId===t.classId);return {id:n.id,readAt:n.readAt,createdAt:n.createdAt,
        task:{id:t.id,classId:t.classId,classCode:cls.classCode,subjectCode:cls.subjectCode,groupId:t.groupId,groupName:t.groupName,title:t.title,description:t.description,dueAt:t.dueAt}};})};
  }
  portalTeacher_(actor);
  lab2Class_(book,actor,String(d.classId||''),false);
  const tasks=lab2Read_(book,'PortalGroupTasks').filter(t=>t.classId===d.classId);
  if(method==='listGroupTasks') {
    return {tasks:tasks.filter(t=>!d.groupId||t.groupId===d.groupId).reverse().map(t=>{
      const {requestKey,fingerprint,...view}=t;return {...view,...groupTaskReceipt_(book,t)};
    })};
  }
  const key=portalKey_(d.requestKey);
  const title=typeof d.title==='string'?d.title.trim():'',description=typeof d.description==='string'?d.description.trim():'';
  const fingerprint=lab2Hash_(JSON.stringify([d.groupId,title,description,d.dueAt]));
  const retry=tasks.find(t=>t.requestKey===key&&t.createdBy===actor.uid);
  if(retry) {
    if(retry.fingerprint!==fingerprint) throw Error('REQUEST_KEY_CONFLICT');
    return {saved:true,...groupTaskReceipt_(book,retry)};
  }
  const plan=groupPlan_(book,d.classId);
  portalVersion_(plan,d.version);
  const group=groupAccess_(book,actor,d),roster=portalRoster_(book,d.classId);
  if(!title||title.length>160||!description||description.length>4000||/[\r\n]/.test(title)) throw Error('INVALID_TASK');
  if(typeof d.dueAt!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(d.dueAt)||!Number.isFinite(Date.parse(d.dueAt))||new Date(d.dueAt).toISOString()!==d.dueAt||Date.parse(d.dueAt)<=Date.now()) throw Error('INVALID_TASK_DEADLINE');
  const members=roster.filter(s=>group.memberIds.includes(s.studentId));
  if(!members.length) throw Error('EMPTY_GROUP');
  if(members.length!==group.memberIds.length) throw Error('ROSTER_CHANGED');
  const domains=config_().domains;
  const emails=members.map(s=>String(s.schoolEmail||'').trim().toLowerCase());
  if(emails.some(email=>! /^[a-z0-9._%+-]+@[a-z0-9.-]+$/.test(email)||!domains.includes(email.split('@')[1]))||new Set(emails).size!==emails.length) throw Error('GROUP_MEMBER_EMAIL_INVALID');
  const now=new Date().toISOString(),id=Utilities.getUuid();
  const task={id,classId:d.classId,groupId:group.id,groupName:group.name,title,description,dueAt:d.dueAt,createdAt:now,createdBy:actor.uid,requestKey:key,fingerprint};
  const notifications=members.map((s,i)=>({table:'PortalTaskNotifications',row:{id:lab2Hash_(id+'|'+s.studentId),taskId:id,classId:d.classId,groupId:group.id,studentId:s.studentId,email:emails[i],createdAt:now,readAt:'',emailStatus:'PENDING',emailSentAt:''}}));
  lab2Write_(book,[{table:'PortalGroupTasks',row:task},...notifications,portalAudit_(actor,d.classId,id,'CREATE_GROUP_TASK',{groupId:group.id,recipientCount:members.length})]);
  return {saved:true,id,recipientCount:members.length,readCount:0,emailSentCount:0,emailPendingCount:members.length,emailReviewCount:0,emailSkippedCount:0};
}
// Deliberately separate from request handling: a slow mail service cannot duplicate tasks.
function sendGroupTaskEmails() {
  const started=Date.now(),book=openSharedBook_(),lock=sharedLock_();
  if(!lock.tryLock(1000)) return {busy:true};
  let sent=0,skipped=0;
  try {
    groupTasksReady_(book);
    const tasks=lab2Read_(book,'PortalGroupTasks');
    for(const row of lab2Read_(book,'PortalTaskNotifications').filter(n=>n.emailStatus==='PENDING').slice(0,30)) {
      if(Date.now()-started>45000||MailApp.getRemainingDailyQuota()<1) break;
      const task=tasks.find(t=>t.id===row.taskId),student=lab2Read_(book,'Students').find(s=>s.studentId===row.studentId);
      const actor={role:'student',entity:{studentId:row.studentId},uid:'student-'+row.studentId};
      // A removed member, changed email, or deleted group must not receive queued content.
      if(!student||String(student.schoolEmail||'').trim().toLowerCase()!==row.email||!groupTaskVisible_(book,actor,task,row)) {
        lab2Write_(book,[{table:'PortalTaskNotifications',row:{...row,emailStatus:'SKIPPED'}}]);skipped++;continue;
      }
      const claimed={...row,emailStatus:'SENDING'};
      const configuredUrl=PropertiesService.getScriptProperties().getProperty('STUDENT_WEB_TASKS_URL')||'';
      const taskUrl=/^https:\/\/[^\s]+$/.test(configuredUrl)?'\n'+configuredUrl:'';
      lab2Write_(book,[{table:'PortalTaskNotifications',row:claimed}]);
      // A crash after claiming or send failure is ambiguous. Never automatically resend.
      let accepted=false;
      try {
        MailApp.sendEmail({to:row.email,subject:'[FAP] Giao việc: '+task.title,
          body:task.groupName+' được giao việc: '+task.title+'\n\n'+task.description+'\n\nHạn hoàn thành (giờ Việt Nam): '+Utilities.formatDate(new Date(task.dueAt),'Asia/Ho_Chi_Minh','dd/MM/yyyy HH:mm')+'\n\nĐăng nhập Student Web → Việc được giao để xem công việc.'+taskUrl,name:'FAP Lecturer Companion'});
        accepted=true;
      } finally {
        lab2Write_(book,[{table:'PortalTaskNotifications',row:{...claimed,emailStatus:accepted?'SENT':'UNKNOWN',emailSentAt:accepted?new Date().toISOString():''}}]);
      }
      sent++;
    }
    return {sent,skipped};
  } finally {lock.releaseLock();}
}
