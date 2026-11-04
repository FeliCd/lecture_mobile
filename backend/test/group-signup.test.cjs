const {test}=require('node:test');
const assert=require('node:assert/strict');
const {fixture}=require('./portal-fixture.cjs');
function setup() {
 const f=fixture('2026-11-04T03:00:00Z'),files=new Map(),permissions=new Map(),triggers=[];
 const owner='owner@gmail.com';
 class Protection {
  constructor(kind,range){this.kind=kind;this.range=range;this.editors=new Set([owner]);this.domain=true;this.description='';}
  setDescription(v){this.description=v;return this;} getDescription(){return this.description;}
  setWarningOnly(v){this.warning=v;return this;}addEditors(v){v.forEach(e=>this.editors.add(e));return this;}
  getEditors(){return [...this.editors].map(email=>({getEmail:()=>email}));}removeEditors(v){v.forEach(e=>this.editors.delete(e));return this;}
  canDomainEdit(){return this.domain;}setDomainEdit(v){this.domain=v;return this;}
  setUnprotectedRanges(v){this.unprotected=v;return this;}remove(){this.removed=true;}
 }
 class Sheet {
  constructor(id){this.id=id;this.values=[];this.protections=[];}
  getSheetId(){return this.id;}setName(){return this;}clear(){this.values=[];return this;}
  setFrozenRows(){return this;}setColumnWidth(){return this;}setRowHeight(){return this;}
  protect(){const p=new Protection('SHEET');this.protections.push(p);return p;}
  getProtections(kind){return this.protections.filter(p=>p.kind===kind&&!p.removed);}
  getRange(row,col,numRows=1,numCols=1){
   const sheet=this;
   const range={row,col,numRows,numCols,setValue(v){return this.setValues([[v]]);},setValues(rows){rows.forEach((r,i)=>r.forEach((v,j)=>{sheet.values[row+i-1]??=[];sheet.values[row+i-1][col+j-1]=String(v);}));return this;},
    getDisplayValues(){return Array.from({length:numRows},(_,i)=>Array.from({length:numCols},(_,j)=>String(sheet.values[row+i-1]?.[col+j-1]??'').replace(/^'/,'')));},
    getFormulas(){return this.getDisplayValues().map(r=>r.map(v=>v.startsWith('=')?v:''));},
    protect(){const p=new Protection('RANGE',{row,col,numRows,numCols});sheet.protections.push(p);return p;},
    setDataValidation(v){sheet.validation=v;return this;}};
   for(const name of ['merge','setBackground','setFontColor','setFontWeight','setFontSize','setWrap','setVerticalAlignment'])range[name]=()=>range;
   return range;
  }
 }
 f.c.SpreadsheetApp={...f.c.SpreadsheetApp,ProtectionType:{SHEET:'SHEET',RANGE:'RANGE'},flush(){},
  create(){const id='doc-'+(files.size+1),sheet=new Sheet(100+files.size),file={getId:()=>id,getSheets:()=>[sheet]};files.set(id,file);permissions.set(id,[{type:'user',role:'owner',emailAddress:owner}]);return file;},
  openById:id=>id==='book'?f.book:files.get(id),newDataValidation:()=>{const rule={requireValueInList(v){this.choices=v;return this;},setAllowInvalid(v){this.allowInvalid=v;return this;},build(){return this;}};return rule;}};
 f.c.Session={getEffectiveUser:()=>({getEmail:()=>owner})};
 f.c.ScriptApp={getProjectTriggers:()=>triggers,newTrigger:name=>{const t={getHandlerFunction:()=>name,timeBased(){return this;},everyMinutes(n){this.minutes=n;return this;},create(){triggers.push(this);return this;}};return t;}};
 f.c.Drive={Files:{update:(resource,id)=>{files.get(id).writersCanShare=resource.writersCanShare;}},Permissions:{
  list:id=>({permissions:permissions.get(id)}),create:(p,id,options)=>{assert.equal(options.sendNotificationEmail,false);assert.equal(p.type,'user');permissions.get(id).push(p);return{id:p.emailAddress};}}};
 const call=(actor,method,data={})=>f.c.portalCall_(f.book,actor,method,{classId:'c1',...data});
 const create=(extra={})=>call(f.teacher,'createGroupSignupSheet',{version:0,groupCount:2,requestKey:'create-signup-1234567',...extra});
 const sheet=()=>[...files.values()].at(-1).getSheets()[0];
 return {...f,call,create,files,permissions,triggers,sheet};
}
test('private separate sheet has dropdowns and row-specific editing, never shares backend book',()=>{
 const f=setup(),created=f.create();assert.equal(created.state,'OPEN');assert.equal(created.assignedCount,0);
 assert.ok(created.url.includes('/doc-1/'));assert.equal(f.files.size,1);assert.equal([...f.files.values()][0].writersCanShare,false);
 assert.deepEqual([...f.permissions.values()][0].filter(p=>p.role==='writer').map(p=>p.emailAddress),['teacher@fpt.edu.vn','student@fpt.edu.vn','other-student@fpt.edu.vn']);
 const s=f.sheet(),whole=s.getProtections('SHEET')[0];assert.equal(whole.unprotected[0].col,3);assert.equal(whole.domain,false);
 const rows=s.getProtections('RANGE');assert.equal(rows.length,2);assert.ok(rows[0].editors.has('student@fpt.edu.vn'));assert.ok(!rows[0].editors.has('other-student@fpt.edu.vn'));
 assert.equal(rows[0].range.row,5);assert.equal(s.validation.allowInvalid,false);assert.equal(f.triggers.length,1);assert.equal(f.triggers[0].minutes,1);
 assert.equal(created.roster,undefined);assert.equal(created.spreadsheetId,undefined);
});
test('student choices sync atomically into the same plan read by desktop and student web',()=>{
 const f=setup();f.create();f.sheet().getRange(5,3,2,1).setValues([['1. Nhóm 1'],['2. Nhóm 2']]);
 f.c.syncGroupSignupSheets();const plan=f.call(f.teacher,'getGroupPlan');
 assert.deepEqual(Array.from(plan.groups[0].memberIds),['s1']);assert.deepEqual(Array.from(plan.groups[1].memberIds),['s2']);
 assert.equal(f.call(f.student,'getGroupPlan').groups[0].id,plan.groups[0].id);
 assert.equal(f.call(f.teacher,'getGroupSignupSheet').assignedCount,2);
 const version=plan.version;f.c.syncGroupSignupSheets();assert.equal(f.call(f.teacher,'getGroupPlan').version,version);
});
test('retry reuses a registered file even after lost commit response',()=>{
 const f=setup(),batch=f.c.Sheets.Spreadsheets.batchUpdate;let failed=false;
 f.c.Sheets.Spreadsheets.batchUpdate=arg=>{batch(arg);if(!failed){failed=true;throw Error('lost response');}};
 assert.throws(()=>f.create(),/lost response/);assert.equal(f.files.size,1);
 f.create();f.create();assert.equal(f.files.size,1);assert.equal(f.triggers.length,1);
});
test('partial sharing failure can resume without erasing student edits or duplicating permissions',()=>{
 const f=setup(),share=f.c.Drive.Permissions.create;let failed=false;
 f.c.Drive.Permissions.create=(p,id,o)=>{const result=share(p,id,o);if(p.emailAddress==='student@fpt.edu.vn'&&!failed){failed=true;throw Error('uncertain sharing');}return result;};
 assert.throws(()=>f.create(),/uncertain sharing/);
 f.sheet().getRange(5,3).setValue('2. Nhóm 2');f.create();
 assert.equal(f.sheet().getRange(5,3).getDisplayValues()[0][0],'2. Nhóm 2');
 assert.equal([...f.permissions.values()][0].filter(p=>p.emailAddress==='student@fpt.edu.vn').length,1);
 f.c.syncGroupSignupSheets();assert.equal(f.call(f.student,'getGroupPlan').groups[0].name,'Nhóm 2');
});
test('invalid selection or formula blocks entire batch until corrected',()=>{
 const f=setup();f.create();const version=f.call(f.teacher,'getGroupPlan').version;
 f.sheet().getRange(5,3,2,1).setValues([['1. Nhóm 1'],['=IMPORTDATA("https://evil.test")']]);
 f.call(f.teacher,'syncGroupSignupSheet');assert.equal(f.call(f.teacher,'getGroupPlan').version,version);
 assert.equal(f.call(f.teacher,'getGroupSignupSheet').lastError,'INVALID_GROUP_SELECTION');
 f.sheet().getRange(6,3).setValue('2. Nhóm 2');f.c.syncGroupSignupSheets();assert.equal(f.call(f.teacher,'getGroupSignupSheet').assignedCount,2);
});
test('manual writes cannot overwrite an open registration; close keeps latest choices and blanks unassigned',()=>{
 const f=setup();f.create();f.sheet().getRange(5,3).setValue('1. Nhóm 1');
 assert.throws(()=>f.call(f.teacher,'saveGroupPlan',{version:1,groups:[],requestKey:'manual-save-1234567'}),/GROUP_SIGNUP_OPEN/);
 const closed=f.call(f.teacher,'closeGroupSignupSheet');assert.equal(closed.state,'CLOSED');assert.equal(closed.assignedCount,1);
 assert.equal(f.sheet().getProtections('SHEET')[0].unprotected.length,0);
 f.sheet().getRange(6,3).setValue('2. Nhóm 2');f.c.syncGroupSignupSheets();assert.equal(f.call(f.teacher,'getGroupSignupSheet').assignedCount,1);
});
test('roster, ownership and out-of-band plan changes pause registration instead of overwriting',()=>{
 for(const mutate of [f=>{f.store.Enrollments=f.store.Enrollments.filter(r=>!r.includes('s2'));},f=>{f.store.Classes[1][f.store.Classes[0].indexOf('lecturerId')]='l2';},f=>{const row=f.c.lab2Read_(f.book,'PortalGroupPlans')[0];f.c.lab2Write_(f.book,[{table:'PortalGroupPlans',row:{...row,version:Number(row.version)+1}}]);}]){
  const f=setup();f.create();mutate(f);f.c.syncGroupSignupSheets();
  assert.equal(f.c.groupSignupRecord_(f.book,'c1').state,'CONFLICT');assert.equal(f.sheet().getProtections('SHEET')[0].unprotected.length,0);
 }
});
test('role, class ownership, registration version and setup are enforced before file creation',()=>{
 const f=setup();assert.throws(()=>f.call(f.student,'createGroupSignupSheet',{requestKey:'student-create-1234'}),/PERMISSION_DENIED/);
 assert.throws(()=>f.create({classId:'c2'}),/PERMISSION_DENIED/);assert.throws(()=>f.create({version:3}),/VERSION_CONFLICT/);assert.equal(f.files.size,0);
 delete f.store.PortalGroupSignupSheets;assert.throws(()=>f.create(),/GROUP_SIGNUP_SETUP_REQUIRED/);
});
test('opening registration preserves saved group IDs, chat access and existing selections',()=>{
 const f=setup(),groups=[{id:'existing-group-12345',name:'Dự án',memberIds:['s1','s2']}];
 f.call(f.teacher,'saveGroupPlan',{version:0,groups,requestKey:'existing-plan-12345'});
 f.create({version:1});f.c.syncGroupSignupSheets();const plan=f.call(f.teacher,'getGroupPlan');
 assert.equal(plan.groups[0].id,groups[0].id);assert.equal(plan.groups[0].memberIds.length,2);
 assert.equal(f.sheet().getRange(5,3).getDisplayValues()[0][0],'1. Dự án');
});
test('unexpected public or domain access blocks populating a newly created sheet',()=>{
 const f=setup(),create=f.c.SpreadsheetApp.create;
 f.c.SpreadsheetApp.create=()=>{const file=create();f.permissions.get(file.getId()).push({type:'domain',role:'reader',domain:'example.com'});return file;};
 assert.throws(()=>f.create(),/GROUP_SIGNUP_SHEET_MUST_BE_PRIVATE/);
 assert.equal(f.sheet().values.length,0);
 assert.equal(f.c.groupSignupRecord_(f.book,'c1').state,'PREPARING');
});
test('a new client session can resume a preparing sheet without knowing the original request key',()=>{
 const f=setup(),share=f.c.Drive.Permissions.create;let failed=false;
 f.c.Drive.Permissions.create=(p,id,o)=>{if(!failed){failed=true;throw Error('sharing interrupted');}return share(p,id,o);};
 assert.throws(()=>f.create(),/sharing interrupted/);
 const resumed=f.call(f.teacher,'resumeGroupSignupSheet');assert.equal(resumed.state,'OPEN');assert.equal(f.files.size,1);
 assert.equal(f.call(f.teacher,'resumeGroupSignupSheet').state,'OPEN');
});
