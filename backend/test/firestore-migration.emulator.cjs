
const test = require('node:test');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {fixture} = require('./portal-fixture.cjs');

const host = process.env.FIRESTORE_EMULATOR_HOST;
const project = 'demo-shared-migration';

function firestoreRequest(route, options = {}) {
  const args = ['-sS', '--max-time', '20', '-w', '\n%{http_code}'];
  if (options.headers?.Authorization) args.push('-H', 'Authorization: '+options.headers.Authorization);
  if (options.payload) args.push('-H', 'Content-Type: application/json', '--data-binary', '@-');
  const result = spawnSync('curl', [...args, 'http://'+host+route], {
    input: options.payload, encoding: 'utf8', maxBuffer: 32*1024*1024,
  });
  assert.equal(result.status, 0, result.stderr || result.error?.message);
  const split = result.stdout.lastIndexOf('\n');
  return {
    getResponseCode: () => Number(result.stdout.slice(split+1)),
    getContentText: () => result.stdout.slice(0,split),
  };
}

function migrationFixture() {
  const f = fixture('2026-10-24T02:02:00Z');
  for (const file of ['FirestoreStore.gs', 'FirestoreMigration.gs']) {
    vm.runInContext(fs.readFileSync(path.join(__dirname,'../apps_script',file),'utf8'),f.c,{filename:file});
  }
  f.book.getSheets = () => Object.keys(f.store).map(name=>({
    getName:()=>name, getLastRow:()=>f.store[name].length,
  }));
  f.c.PropertiesService = {getScriptProperties:()=>({
    getProperty:key=>f.props[key]??null,
    setProperty:(key,value)=>{f.props[key]=value;},
    setProperties:values=>Object.assign(f.props,values),
  })};
  Object.assign(f.props,{
    SHARED_FIRESTORE_PROJECT:project, PORTAL_FIREBASE_PROJECT_ID:project, PORTAL_FIREBASE_API_KEY:'mock',
  });
  f.c.ScriptApp = {getOAuthToken:()=>'owner',getService:()=>({
    getUrl:()=>'https://script.google.com/macros/s/test-deployment/exec',
  })};
  f.c.Utilities.newBlob = value=>({
    getDataAsString:()=>String(value),getBytes:()=>Buffer.from(String(value)),
  });
  f.c.lab2FirebaseIdentity_ = token=>({
    email:token==='mobile'?'teacher@fpt.edu.vn':'student@fpt.edu.vn',
    firebaseUid:token,signInProvider:'google.com',
  });
  f.c.UrlFetchApp = {fetch(url,options) {
    const target = new URL(url);
    if (target.hostname==='firestore.googleapis.com') return firestoreRequest(target.pathname+target.search,options);
    if (target.hostname==='script.google.com') return {
      getResponseCode:()=>200,getContentText:()=>JSON.stringify(f.c.doPost({postData:{contents:options.payload}})),
    };
    assert.equal(target.hostname,'oauth2.googleapis.com');
    return {getResponseCode:()=>200,getContentText:()=>JSON.stringify({
      aud:'desktop',iss:'https://accounts.google.com',exp:f.c.Date.now()/1000+3600,email_verified:true,email:'teacher@fpt.edu.vn',
    })};
  }};
  const post = request=>f.c.doPost({postData:{contents:JSON.stringify(request)}});
  return {...f,post};
}

test('Firestore migration preserves data and permissions across all three API transports', {skip:!host}, () => {
  const f = migrationFixture();
  f.store.Students[1][3]=' Student@FPT.EDU.VN ';
  f.add('Sessions',{sessionId:'session',classId:'c1',date:'24/10/2026',slot:'1',startTime:'09:00',endTime:'10:30',
    status:'open',currentToken:'test-qr-token',tokenExpiredAt:'2026-10-24T02:10:00Z',createdBy:'l1'});
  f.add('Lab2SessionMeta',{sessionId:'session',opensAt:Date.parse('2026-10-24T02:00:00Z'),
    closesAt:Date.parse('2026-10-24T02:10:00Z'),eligibleStudentIds:'["s1","s2"]'});
  f.add('Attendance',{attendanceId:'zzz-first',sessionId:'session',studentId:'s2',status:'LATE',note:'=giữ nguyên'});
  f.add('Schedules',{scheduleId:'schedule',lecturerId:'l1',classCode:'SE1',subjectCode:'PRM393',
    dayOfWeek:'6',slot:'1',startTime:'09:00',endTime:'10:30',room:'A201'});
  f.add('Sessions',{sessionId:'history',classId:'c1',date:'2026-10-23',slot:'1',startTime:'09:00',endTime:'10:30',
    status:'CLOSED',createdBy:'l1'});
  delete f.store.PortalGroupPushDevices;
  const preflight=f.c.inspectSharedDatabaseMigration();
  assert.equal(preflight.firestoreReadable,true);
  assert.equal(preflight.tables.PortalGroupPushDevices,0);
  const result = f.c.migrateSharedDatabaseToFirestore();
  assert.equal(result.database,'firestore');
  assert.equal(result.counts.Attendance,1);
  assert.equal(f.c.migrateSharedDatabaseToFirestore().alreadyActive,true);
  assert.throws(()=>f.c.lab2Write_(f.book,[{table:'Attendance',row:{attendanceId:'stale'}}]),/DATABASE_MAINTENANCE/);
  f.c.SpreadsheetApp.openById=()=>{throw Error('unexpected Sheets database access');};

  const checkIn={action:'studentCheckIn',idToken:'student',firebaseAuth:true,
    sessionId:'session',confirmPresent:true,token:'test-qr-token'};
  const first=f.post(checkIn);
  assert.equal(first.ok,true,JSON.stringify(first));
  assert.equal(first.data.status,'PRESENT');
  assert.equal(f.post(checkIn).data.alreadyRecorded,true);

  const live=f.post({action:'lab2Call',idToken:'mobile',name:'getAttendanceSessionLive',input:{sessionId:'session'}});
  assert.equal(live.ok,true,JSON.stringify(live));
  assert.equal(live.data.counts.present,1);
  assert.equal(live.data.counts.late,1);
  const desktop=f.post({action:'getSessionsByClass',idToken:'mock-google-token-for-unit-tests',classId:'c1'});
  assert.equal(desktop.ok,true,JSON.stringify(desktop));
  assert.equal(desktop.data.find(row=>row.sessionId==='session').date,'2026-10-24');
  const snapshot=f.post({action:'lab2Snapshot',idToken:'mobile',googleLecturerOnly:true});
  assert.equal(snapshot.ok,true,JSON.stringify(snapshot));
  assert.deepEqual(snapshot.data.collections.classes.map(row=>row.id),['c1']);
  assert.deepEqual(snapshot.data.collections.attendanceRecords.map(row=>row.status),['late','present']);

  const mobile=(method,data)=>f.post({action:'lab2Call',idToken:'mobile',name:'portalCall',input:{method,data}});
  const student=(method,data)=>f.post({action:'portalCall',firebaseAuth:true,idToken:'student',method,data});
  const draft=mobile('saveGradebook',{classId:'c1',version:0,components:[{id:'p',name:'Practical',maxScore:10}],
    students:[{studentId:'s1',grades:{p:0},comment:''},{studentId:'s2',grades:{p:9},comment:''}]});
  assert.equal(draft.ok,true,JSON.stringify(draft));
  assert.equal(student('getMyPublishedGrades',{classId:'c1'}).data.published,false);
  const publication=mobile('publishGrades',{classId:'c1',version:1,studentIds:['s1','s2'],requestKey:'migration-publish-12345'});
  assert.equal(publication.ok,true,JSON.stringify(publication));
  assert.equal(student('getMyPublishedGrades',{classId:'c1'}).data.grades.p,0);
  assert.equal(student('getGradebook',{classId:'c1'}).ok,false);
  assert.equal(student('getMyPublishedGrades',{classId:'c2'}).ok,false);

  const lecturer=(method,data)=>f.post({action:'portalCall',idToken:'mock-google-token-for-unit-tests',method,data});
  const groupId='migration-group-123456';
  const plan=lecturer('saveGroupPlan',{classId:'c1',version:0,requestKey:'migration-plan-123456',groups:[
    {id:groupId,name:'Nhóm 1',memberIds:['s1']},{id:'migration-group-other',name:'Nhóm 2',memberIds:['s2']},
  ]});
  assert.equal(plan.ok,true,JSON.stringify(plan));
  const task=lecturer('createGroupTask',{classId:'c1',groupId,version:1,title:'Làm bài lab',description:'Bài tập nhóm',
    dueAt:'2026-10-25T16:00:00.000Z',requestKey:'migration-task-123456'});
  assert.equal(task.ok,true,JSON.stringify(task));
  const inbox=student('listMyTaskNotifications',{});
  assert.equal(inbox.data.notifications[0].task.title,'Làm bài lab');

  const book=f.c.openSharedBook_();
  assert.equal(f.c.lab2Read_(book,'Attendance')[0].note,'=giữ nguyên');
  const direct=firestoreRequest('/v1/'+book.database+'/'+book.root);
  assert.equal(direct.getResponseCode(),403);
  const directWrite=firestoreRequest('/v1/'+book.database+':commit',{payload:JSON.stringify({
    writes:[{delete:book.database+'/'+book.root}],
  })});
  assert.equal(directWrite.getResponseCode(),403);

  const bulk=Array.from({length:400},(_,i)=>[
    {table:'Attendance',row:{attendanceId:'bulk-'+i,sessionId:'history',studentId:'student-'+i,status:'ABSENT'}},
    {table:'AttendanceAudit',row:{id:'audit-'+i,sessionId:'history',studentId:'student-'+i,newStatus:'ABSENT'}},
  ]).flat();
  f.c.lab2Write_(book,bulk);
  assert.equal(f.c.lab2Read_(book,'AttendanceAudit').length,400);
  assert.equal(f.c.lab2Read_(book,'Attendance').length,402);
  assert.equal(f.c.lab2Read_(book,'Attendance')[2].attendanceId,'bulk-0');
});

test('failed source validation leaves Sheets selected', {skip:!host}, () => {
  const f=migrationFixture();
  f.add('Students',{studentId:'s1',studentCode:'SE999'});
  assert.throws(()=>f.c.migrateSharedDatabaseToFirestore(),/INVALID_SOURCE_TABLE_Students/);
  assert.equal(f.c.sharedMode_(),'sheets');
  assert.equal(f.props.SHARED_FIRESTORE_DATASET,undefined);
});

test('migration rejects an old deployment before it writes to Firestore', {skip:!host}, () => {
  const f=migrationFixture();
  f.c.UrlFetchApp.fetch=()=>({
    getResponseCode:()=>200,getContentText:()=>'{"ok":true,"data":{"version":"lab2-shared-sheets-v2"}}',
  });
  assert.throws(()=>f.c.migrateSharedDatabaseToFirestore(),/SHARED_EXEC_DEPLOYMENT_NOT_READY/);
  assert.equal(f.c.sharedMode_(),'sheets');
});
