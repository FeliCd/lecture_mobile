const {test}=require('node:test');
const assert=require('node:assert/strict');
const {fixture}=require('./portal-fixture.cjs');
const g1='group-one-12345678',g2='group-two-12345678';
function setup() {
 const f=fixture('2026-11-02T03:00:00Z');
 const call=(actor,method,data={})=>f.c.portalCall_(f.book,actor,method,{classId:'c1',...data});
 const groups=[{id:g1,name:'Nhóm 1',memberIds:['s1']},{id:g2,name:'Nhóm 2',memberIds:['s2']}];
 const save=(extra={})=>call(f.teacher,'saveGroupPlan',{version:0,groups,requestKey:'save-plan-123456789',...extra});
 return {...f,call,groups,save};
}
test('only lecturer owner can assign; student sees only own group and limited roster',()=>{
 const f=setup();f.save();
 const p=f.call(f.student,'getGroupPlan');assert.equal(p.groups.length,1);assert.equal(p.groups[0].id,g1);assert.equal(p.students.length,1);assert.equal(p.students[0].studentId,'s1');assert.equal(p.students[0].schoolEmail,undefined);
 assert.throws(()=>f.call(f.student,'saveGroupPlan',{version:1,groups:f.groups,requestKey:'student-save-12345'}),/PERMISSION_DENIED/);
 assert.throws(()=>f.call(f.teacher,'getGroupPlan',{classId:'c2'}),/PERMISSION_DENIED/);
});
test('full roster, unique memberships, names and ids validated atomically',()=>{
 const f=setup();
 assert.throws(()=>f.save({groups:[{...f.groups[0],memberIds:['s1','s2']},f.groups[1]]}),/INVALID_GROUP_MEMBERS/);
 assert.throws(()=>f.save({groups:[f.groups[0]]}),/ROSTER_CHANGED/);
 assert.throws(()=>f.save({groups:[{...f.groups[0],memberIds:['outsider']},f.groups[1]]}),/INVALID_GROUP_MEMBERS/);
 assert.throws(()=>f.save({groups:[f.groups[0],{...f.groups[1],name:'Nhóm 1'}]}),/INVALID_GROUPS/);
 assert.equal(f.call(f.teacher,'getGroupPlan').version,0);
});
test('optimistic version rejects stale writes; retry does not change saved version',()=>{
 const f=setup();f.save();assert.equal(f.save().version,1);
 assert.throws(()=>f.save({requestKey:'different-key-12345'}),/VERSION_CONFLICT/);
 assert.equal(f.call(f.teacher,'getGroupPlan').version,1);
});
test('messages enforce membership, derive sender, limit payload and deduplicate retry',()=>{
 const f=setup();f.save();const data={groupId:g1,text:'Hello',requestKey:'message-key-1234567',sender:'student-s2'};
 const m=f.call(f.student,'sendGroupMessage',data);
 assert.equal(f.call(f.student,'sendGroupMessage',data).id,m.id);
 const rows=f.call(f.student,'getGroupMessages',{groupId:g1}).messages;
 assert.equal(rows.length,1);assert.equal(rows[0].sender,'student-s1');assert.equal(rows[0].fileId,undefined);assert.equal(rows[0].requestKey,undefined);
 assert.throws(()=>f.call(f.student,'getGroupMessages',{groupId:g2}),/GROUP_ACCESS_DENIED/);
 assert.throws(()=>f.call(f.student,'sendGroupMessage',{...data,text:'a'.repeat(2001),requestKey:'long-message-12345'}),/INVALID_MESSAGE/);
 assert.throws(()=>f.call(f.student,'sendGroupMessage',{...data,text:'',requestKey:'other-message-key1'}),/INVALID_MESSAGE/);
});
test('moving member revokes old chat and attachment access on next server request',()=>{
 const f=setup();f.save();f.call(f.student,'sendGroupMessage',{groupId:g1,text:'before move',requestKey:'before-move-123456'});
 f.save({version:1,requestKey:'move-plan-12345678',groups:[{...f.groups[0],memberIds:[]},{...f.groups[1],memberIds:['s1','s2']}]});
 for(const method of ['getGroupMessages','sendGroupMessage','downloadGroupFile']) assert.throws(()=>f.call(f.student,method,{groupId:g1}),/GROUP_ACCESS_DENIED/);
 assert.equal(f.call(f.teacher,'getGroupMessages',{groupId:g1}).messages.length,1);
});
test('current enrollment checked even when group plan still contains removed student',()=>{
 const f=setup();f.save();f.store.Enrollments=f.store.Enrollments.filter(r=>!r.includes('s1'));
 assert.throws(()=>f.call(f.student,'getGroupMessages',{groupId:g1}),/NOT_ENROLLED/);
});
test('messages page by stable row id without leaking another group',()=>{
 const f=setup();f.save();for(let i=0;i<55;i++)f.call(f.student,'sendGroupMessage',{groupId:g1,text:'message '+i,requestKey:'request-message-'+String(i).padStart(4,'0')});
 const page=f.call(f.student,'getGroupMessages',{groupId:g1});assert.equal(page.messages.length,50);assert.ok(page.older);
 const old=f.call(f.student,'getGroupMessages',{groupId:g1,before:page.older});assert.equal(old.messages.length,5);assert.equal(old.older,null);
});
test('deleted group id cannot be resurrected to expose history',()=>{
 const f=setup();f.save();f.call(f.student,'sendGroupMessage',{groupId:g1,text:'history',requestKey:'history-message-1234'});
 f.save({version:1,requestKey:'new-plan-123456789',groups:[{id:'new-group-12345678',name:'New group',memberIds:['s1','s2']}]});
 assert.throws(()=>f.save({version:2,requestKey:'resurrect-123456789'}),/INVALID_GROUPS/);
});
test('private attachments downloaded only via member-authorized message, never arbitrary file id',()=>{
 const f=setup();f.save();f.props.GROUP_FILES_FOLDER_ID='private-folder';let uploaded=0;
 f.c.Utilities.base64Decode=s=>Buffer.from(s,'base64');f.c.Utilities.base64Encode=b=>Buffer.from(b).toString('base64');f.c.Utilities.newBlob=b=>({getBytes:()=>b});
 const file={getId:()=> 'file-id',getSharingAccess:()=> 'PRIVATE',getBlob:()=>({getBytes:()=>Buffer.from('abc')}),getParents:()=>{let more=true;return{hasNext:()=>more,next:()=>{more=false;return{getId:()=> 'private-folder'};}};}};
 f.c.DriveApp={Access:{PRIVATE:'PRIVATE'},getFolderById:()=>({getSharingAccess:()=> 'PRIVATE',getEditors:()=>[],getViewers:()=>[],createFile:()=>{uploaded++;return file;}}),getFileById:()=>file};
 const input={groupId:g1,text:'',file:{name:'test.txt',base64:'YWJj'},requestKey:'file-message-1234567'};
 const m=f.call(f.student,'sendGroupMessage',input);f.call(f.student,'sendGroupMessage',input);assert.equal(uploaded,1);
 assert.equal(f.call(f.student,'downloadGroupFile',{groupId:g1,messageId:m.id}).base64,'YWJj');
 assert.throws(()=>f.call(f.student,'downloadGroupFile',{groupId:g2,messageId:m.id}),/GROUP_ACCESS_DENIED/);
 assert.throws(()=>f.call(f.student,'downloadGroupFile',{groupId:g1,messageId:'arbitrary-file-id'}),/GROUP_ACCESS_DENIED/);
 assert.throws(()=>f.call(f.student,'sendGroupMessage',{...input,requestKey:'different-file-1234',file:{name:'bad.exe',base64:'YWJj'}}),/INVALID_FILE/);
});
test('delivery/read acknowledgements use verified actor and server time, never a read request alone',()=>{
 const f=setup();f.save({groups:[{id:g1,name:'Together',memberIds:['s1','s2']}]});
 const sent=f.call(f.student,'sendGroupMessage',{groupId:g1,text:'Hello',requestKey:'receipt-message-123'});
 assert.equal(sent.createdAt,'2026-11-02T03:00:00.000Z');
 const other={...f.student,uid:'student-s2',entity:{studentId:'s2'}};
 f.call(other,'getGroupMessages',{groupId:g1});
 let own=f.call(f.student,'getGroupMessages',{groupId:g1}).messages[0];assert.equal(own.mine,true);assert.equal(own.delivery.deliveredCount,0);
 f.setNow('2026-11-02T03:01:00Z');f.call(other,'ackGroupMessages',{groupId:g1,deliveredIds:[sent.id],readIds:[],actor:'student-s1',deliveredAt:'2000-01-01'});
 own=f.call(f.student,'getGroupMessages',{groupId:g1}).messages[0];assert.equal(own.delivery.deliveredCount,1);assert.equal(own.delivery.readCount,0);assert.equal(own.delivery.deliveredAt,'2026-11-02T03:01:00.000Z');
 f.setNow('2026-11-02T03:02:00Z');f.call(other,'ackGroupMessages',{groupId:g1,deliveredIds:[sent.id],readIds:[sent.id]});
 own=f.call(f.student,'getGroupMessages',{groupId:g1}).messages[0];assert.equal(own.delivery.readCount,1);assert.equal(own.delivery.readAt,'2026-11-02T03:02:00.000Z');
 f.setNow('2026-11-02T03:03:00Z');f.call(other,'ackGroupMessages',{groupId:g1,deliveredIds:[sent.id],readIds:[sent.id]});
 own=f.call(f.student,'getGroupMessages',{groupId:g1}).messages[0];assert.equal(own.delivery.deliveredAt,'2026-11-02T03:01:00.000Z');assert.equal(own.delivery.readAt,'2026-11-02T03:02:00.000Z');
 assert.equal(f.call(other,'getGroupMessages',{groupId:g1}).messages[0].delivery,undefined);
});
test('receipt permissions, foreign message IDs and bounded payload are enforced',()=>{
 const f=setup();f.save();const m=f.call(f.student,'sendGroupMessage',{groupId:g1,text:'Hi',requestKey:'ack-denial-message1'});
 assert.throws(()=>f.call(f.student,'ackGroupMessages',{groupId:g2,deliveredIds:[m.id]}),/GROUP_ACCESS_DENIED/);
 assert.throws(()=>f.call(f.student,'ackGroupMessages',{groupId:g1,deliveredIds:['other-message']}),/INVALID_RECEIPTS/);
 assert.throws(()=>f.call(f.student,'ackGroupMessages',{groupId:g1,deliveredIds:Array(51).fill(m.id)}),/INVALID_RECEIPTS/);
 f.call(f.student,'ackGroupMessages',{groupId:g1,deliveredIds:[m.id],readIds:[m.id]});assert.equal(f.call(f.student,'getGroupMessages',{groupId:g1}).messages[0].delivery.readCount,0);
});
test('older deployments without receipt table still display saved messages honestly',()=>{
 const f=setup();f.save();f.call(f.student,'sendGroupMessage',{groupId:g1,text:'Hi',requestKey:'old-deploy-message1'});delete f.store.PortalGroupReceipts;
 const view=f.call(f.student,'getGroupMessages',{groupId:g1});assert.equal(view.receiptTracking,false);assert.equal(view.messages[0].delivery.readCount,0);
 assert.throws(()=>f.call(f.student,'ackGroupMessages',{groupId:g1,deliveredIds:[]}),/GROUP_RECEIPTS_SETUP_REQUIRED/);
});
test('attachment validation rejects empty, oversized, unsafe names and malformed base64 before Drive access',()=>{
 const f=setup();f.save();f.c.Utilities.base64Decode=s=>Buffer.from(s,'base64');
 const send=file=>f.call(f.student,'sendGroupMessage',{groupId:g1,text:'',file,requestKey:'file-validation-1234'});
 for(const file of [{name:'../a.pdf',base64:'YWJj'},{name:'a.exe',base64:'YWJj'},{name:'a'.repeat(121)+'.txt',base64:'YWJj'},{name:'a.txt',base64:'%%%'}])assert.throws(()=>send(file),/INVALID_FILE/);
 assert.throws(()=>send({name:'empty.txt',base64:''}),/FILE_TOO_LARGE/);
 assert.throws(()=>send({name:'big.pdf',base64:Buffer.alloc(512001).toString('base64')}),/FILE_TOO_LARGE/);
 assert.equal(f.call(f.teacher,'getGroupMessages',{groupId:g1}).messages.length,0);
});
