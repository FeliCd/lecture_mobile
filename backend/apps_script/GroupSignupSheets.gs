/* A separate, restricted Google Sheet for self-selection. Never share the backend book. */
function setupGroupSignupSheets() {
  setupStudentPortal();
  groupSignupTrigger_();
  return {ready:true};
}
function groupSignupTrigger_() {
  if(!ScriptApp.getProjectTriggers().some(t=>t.getHandlerFunction()==='syncGroupSignupSheets')) {
    ScriptApp.newTrigger('syncGroupSignupSheets').timeBased().everyMinutes(1).create();
  }
}
function groupSignupRecord_(book,classId) {
  if(!book.getSheetByName('PortalGroupSignupSheets')) return null;
  return lab2Read_(book,'PortalGroupSignupSheets').find(r=>r.classId===classId)||null;
}
function groupSignupRoster_(book,classId) {
  const rows=portalRoster_(book,classId);
  const emails=new Set();
  return rows.map(s=>{
    const email=String(s.schoolEmail||'').trim().toLowerCase();
    if(!/^[a-z0-9._%+-]+@[a-z0-9.-]+$/.test(email)||!config_().domains.includes(email.split('@')[1])||emails.has(email)) throw Error('GROUP_MEMBER_EMAIL_INVALID');
    emails.add(email);
    return {studentId:s.studentId,studentCode:s.studentCode,fullName:s.fullName,email};
  }).sort((a,b)=>a.studentId.localeCompare(b.studentId));
}
function groupSignupView_(book,row) {
  const version=groupPlan_(book,row.classId).version;
  const groups=groupPlan_(book,row.classId).groups;
  return {state:row.state,url:'https://docs.google.com/spreadsheets/d/'+row.spreadsheetId+'/edit#gid='+row.sheetId,
    currentPlanVersion:version,groupCount:JSON.parse(row.groups).length,studentCount:JSON.parse(row.roster).length,
    assignedCount:new Set(groups.flatMap(g=>g.memberIds)).size,lastSyncedAt:row.lastSyncedAt,lastError:row.lastError};
}
function groupSignupCall_(book,actor,method,d) {
  const cls=lab2Class_(book,actor,String(d.classId||''),false);
  let row=groupSignupRecord_(book,cls.classId);
  if(method==='getGroupSignupSheet') {
    // Do not expose rosters, emails, request keys or backend sheet IDs to clients.
    if(!row) return {state:'NONE',currentPlanVersion:groupPlan_(book,cls.classId).version};
    if(actor.role!=='lecturer'&&row.state!=='OPEN') return {state:'NONE'};
    return groupSignupView_(book,row);
  }
  portalTeacher_(actor);
  if(!book.getSheetByName('PortalGroupSignupSheets')) throw Error('GROUP_SIGNUP_SETUP_REQUIRED');
  if(method==='resumeGroupSignupSheet') {
    if(row?.state==='OPEN') return groupSignupView_(book,row);
    if(row?.state!=='PREPARING') throw Error('GROUP_SIGNUP_NOT_OPEN');
    return groupSignupFinishCreate_(book,actor,row);
  }
  if(method==='createGroupSignupSheet') {
    const key=portalKey_(d.requestKey),plan=groupPlan_(book,cls.classId);
    if(row&&row.requestKey===key) {
      if(row.createdBy!==actor.uid) throw Error('PERMISSION_DENIED');
      if(row.state!=='PREPARING') return groupSignupView_(book,row);
    } else {
      if(row&&['PREPARING','OPEN','CONFLICT'].includes(row.state)) throw Error('GROUP_SIGNUP_OPEN');
      portalVersion_(plan,d.version);
      const roster=groupSignupRoster_(book,cls.classId);
      if(!roster.length) throw Error('EMPTY_ROSTER');
      if(JSON.stringify(roster).length>45000) throw Error('CLASS_TOO_LARGE');
      if(!Number.isInteger(d.groupCount)||d.groupCount<1||d.groupCount>50) throw Error('INVALID_GROUPS');
      const groups=(plan.groups.length?plan.groups:Array.from({length:d.groupCount},(_,i)=>({id:Utilities.getUuid(),name:'Nhóm '+(i+1),memberIds:[]}))).map((g,i)=>({...g,label:(i+1)+'. '+g.name}));
      const teacher=String(actor.entity.email||actor.email||'').trim().toLowerCase();
      if(!teacher) throw Error('PERMISSION_DENIED');
      const file=SpreadsheetApp.create('Đăng ký nhóm - '+cls.classCode+' - '+cls.subjectCode);
      row={classId:cls.classId,spreadsheetId:file.getId(),sheetId:file.getSheets()[0].getSheetId(),state:'PREPARING',planVersion:plan.version,
        groups:JSON.stringify(groups),roster:JSON.stringify(roster),prepared:'',createdBy:actor.uid,lecturerId:cls.lecturerId,lecturerEmail:teacher,
        createdAt:new Date().toISOString(),lastSyncedAt:'',lastError:'',requestKey:key};
      // Persist immediately so an uncertain response can reuse this private file.
      lab2Write_(book,[{table:'PortalGroupSignupSheets',row}]);
    }
    return groupSignupFinishCreate_(book,actor,row);
  }
  if(!row) throw Error('GROUP_SIGNUP_NOT_FOUND');
  if(method==='syncGroupSignupSheet') {
    if(row.state!=='OPEN') throw Error('GROUP_SIGNUP_NOT_OPEN');
    groupSignupSync_(book,row);
    return groupSignupView_(book,groupSignupRecord_(book,cls.classId));
  }
  if(method==='closeGroupSignupSheet') {
    groupSignupLock_({...row,state:'CLOSED'});
    if(row.state==='CLOSED') return groupSignupView_(book,row);
    // Close even an invalid/preparing round: preserve the last committed group plan.
    if(row.state==='OPEN') {groupSignupSync_(book,row);row=groupSignupRecord_(book,cls.classId);}
    const next={...row,state:'CLOSED'};
    groupSignupLock_(next);
    lab2Write_(book,[{table:'PortalGroupSignupSheets',row:next},portalAudit_(actor,cls.classId,row.spreadsheetId,'CLOSE_GROUP_SIGNUP',{})]);
    return groupSignupView_(book,next);
  }
  throw Error('UNKNOWN_PORTAL_METHOD');
}
function groupSignupSheet_(row) {
  const sheet=SpreadsheetApp.openById(row.spreadsheetId).getSheets().find(s=>String(s.getSheetId())===String(row.sheetId));
  if(!sheet) throw Error('GROUP_SIGNUP_SHEET_MISSING');
  return sheet;
}
function groupSignupProtection_(protection,teacher,student) {
  const owner=Session.getEffectiveUser().getEmail();
  if(!owner) throw Error('GROUP_SIGNUP_OWNER_REQUIRED');
  const allowed=[owner,teacher,...(student?[student]:[])];
  protection.setWarningOnly(false).addEditors(allowed);
  const extra=protection.getEditors().filter(u=>!allowed.includes(u.getEmail())).map(u=>u.getEmail());
  if(extra.length) protection.removeEditors(extra);
  if(protection.canDomainEdit()) protection.setDomainEdit(false);
  return protection;
}
function groupSignupLiteral_(value) {
  const text=String(value||'');return /^[=+@-]/.test(text)?"'"+text:text;
}
function groupSignupPrepare_(row) {
  const sheet=groupSignupSheet_(row),roster=JSON.parse(row.roster),groups=JSON.parse(row.groups);
  // This phase runs before students are granted file access.
  for(const type of [SpreadsheetApp.ProtectionType.SHEET,SpreadsheetApp.ProtectionType.RANGE]) {
    for(const p of sheet.getProtections(type)) if(String(p.getDescription()||'').startsWith('FAP_GROUP_SIGNUP')) p.remove();
  }
  sheet.setName('Chọn nhóm');sheet.clear();
  sheet.getRange(1,1,1,5).merge().setValue('ĐĂNG KÝ NHÓM HỌC TẬP').setBackground('#C4510A').setFontColor('#FFFFFF').setFontWeight('bold').setFontSize(16);
  sheet.getRange(2,1,1,5).merge().setValue('Chỉ sửa ô Chọn nhóm của bạn. Đồng bộ tự động khoảng mỗi phút; chờ cột Đồng bộ xác nhận.').setWrap(true);
  sheet.getRange(3,1,1,5).merge().setValue('Đang chuẩn bị quyền truy cập…').setWrap(true);
  sheet.getRange(4,1,1,5).setValues([['MSSV','Họ tên','Chọn nhóm','Đồng bộ','Cập nhật (giờ VN)']]).setBackground('#FFF0E2').setFontWeight('bold');
  sheet.getRange(5,1,roster.length,5).setValues(roster.map(s=>{
    const group=groups.find(g=>g.memberIds.includes(s.studentId));
    return [groupSignupLiteral_(s.studentCode),groupSignupLiteral_(s.fullName),group?group.label:'','Chờ đồng bộ',''];
  }));
  sheet.setFrozenRows(4);sheet.setColumnWidth(1,125);sheet.setColumnWidth(2,240);sheet.setColumnWidth(3,220);sheet.setColumnWidth(4,260);sheet.setColumnWidth(5,180);
  sheet.setRowHeight(1,36);sheet.setRowHeight(2,48);sheet.getRange(4,1,roster.length+1,5).setWrap(true).setVerticalAlignment('middle');
  const choices=sheet.getRange(5,3,roster.length,1);
  choices.setBackground('#FFF8E7').setDataValidation(SpreadsheetApp.newDataValidation().requireValueInList(groups.map(g=>g.label),true).setAllowInvalid(false).build());
  groupSignupProtection_(sheet.protect().setDescription('FAP_GROUP_SIGNUP_SHEET'),row.lecturerEmail).setUnprotectedRanges([choices]);
  roster.forEach((s,i)=>groupSignupProtection_(sheet.getRange(i+5,3,1,1).protect().setDescription('FAP_GROUP_SIGNUP_ROW_'+s.studentId),row.lecturerEmail,s.email));
  SpreadsheetApp.flush();
}
function groupSignupPermissions_(row) {
  let permissions=[],pageToken;
  do {
    const page=Drive.Permissions.list(row.spreadsheetId,{fields:'nextPageToken,permissions(id,type,role,emailAddress)',pageSize:100,...(pageToken?{pageToken}:{})});
    permissions.push(...(page.permissions||[]));pageToken=page.nextPageToken;
  } while(pageToken);
  return permissions;
}
function groupSignupRequirePrivate_(row) {
  const allowed=new Set([row.lecturerEmail,...JSON.parse(row.roster).map(s=>s.email)]);
  const permissions=groupSignupPermissions_(row);
  if(permissions.some(p=>p.role!=='owner'&&(p.type!=='user'||!allowed.has(String(p.emailAddress||'').toLowerCase())))) throw Error('GROUP_SIGNUP_SHEET_MUST_BE_PRIVATE');
  return permissions;
}
function groupSignupShare_(row) {
  // Restricted named users, no invitation emails or public link-edit permission.
  Drive.Files.update({writersCanShare:false},row.spreadsheetId);
  const permissions=groupSignupRequirePrivate_(row);
  const existing=new Set(permissions.filter(p=>['owner','writer'].includes(p.role)).map(p=>String(p.emailAddress||'').toLowerCase()));
  for(const email of new Set([row.lecturerEmail,...JSON.parse(row.roster).map(s=>s.email)])) {
    if(!existing.has(email)) Drive.Permissions.create({type:'user',role:'writer',emailAddress:email},row.spreadsheetId,{sendNotificationEmail:false,fields:'id'});
  }
}
function groupSignupFinishCreate_(book,actor,row) {
  const cls=lab2Read_(book,'Classes').find(c=>c.classId===row.classId);
  if(!cls||cls.lecturerId!==row.lecturerId) {groupSignupConflict_(book,row,'PERMISSION_DENIED');throw Error('PERMISSION_DENIED');}
  if(groupPlan_(book,row.classId).version!==Number(row.planVersion)) {groupSignupConflict_(book,row,'VERSION_CONFLICT');throw Error('VERSION_CONFLICT');}
  if(JSON.stringify(groupSignupRoster_(book,row.classId))!==row.roster) {groupSignupConflict_(book,row,'ROSTER_CHANGED');throw Error('ROSTER_CHANGED');}
  groupSignupRequirePrivate_(row);
  if(!row.prepared) {
    groupSignupPrepare_(row);row={...row,prepared:'yes'};
    lab2Write_(book,[{table:'PortalGroupSignupSheets',row}]);
  }
  groupSignupShare_(row);groupSignupTrigger_();
  if(groupPlan_(book,row.classId).version!==Number(row.planVersion)) throw Error('VERSION_CONFLICT');
  const groups=JSON.parse(row.groups).map(({label,...g})=>g),now=new Date().toISOString();
  const plan={classId:row.classId,groups:JSON.stringify(groups),version:Number(row.planVersion)+1,updatedAt:now,updatedBy:actor.uid,requestKey:'signup-'+row.requestKey};
  row={...row,state:'OPEN',planVersion:plan.version,lastError:''};
  lab2Write_(book,[{table:'PortalGroupPlans',row:plan},{table:'PortalGroupSignupSheets',row},portalAudit_(actor,row.classId,row.spreadsheetId,'OPEN_GROUP_SIGNUP',{groups:groups.length,students:JSON.parse(row.roster).length})]);
  groupSignupSheet_(row).getRange(3,1).setValue('ĐANG MỞ ĐĂNG KÝ · Chỉ tài khoản email trường trong danh sách được chọn nhóm.');
  return groupSignupView_(book,row);
}
function groupSignupLock_(row) {
  const sheet=groupSignupSheet_(row);
  const protections=sheet.getProtections(SpreadsheetApp.ProtectionType.SHEET);
  if(!protections.some(p=>p.getDescription()==='FAP_GROUP_SIGNUP_SHEET')) protections.push(sheet.protect().setDescription('FAP_GROUP_SIGNUP_SHEET'));
  for(const p of protections) {
    if(p.getDescription()==='FAP_GROUP_SIGNUP_SHEET') groupSignupProtection_(p,row.lecturerEmail).setUnprotectedRanges([]);
  }
  sheet.getRange(3,1).setValue('ĐĂNG KÝ ĐÃ DỪNG · '+(row.state==='CONFLICT'?'Giảng viên cần kiểm tra danh sách lớp/nhóm.':'Liên hệ giảng viên nếu cần đổi nhóm.'));
}
function groupSignupConflict_(book,row,code) {
  const next={...row,state:'CONFLICT',lastError:code};
  lab2Write_(book,[{table:'PortalGroupSignupSheets',row:next}]);
  groupSignupLock_(next);
}
function groupSignupSync_(book,row) {
  const plan=groupPlan_(book,row.classId),roster=JSON.parse(row.roster),definitions=JSON.parse(row.groups);
  const cls=lab2Read_(book,'Classes').find(c=>c.classId===row.classId);
  if(!cls||cls.lecturerId!==row.lecturerId) {groupSignupConflict_(book,row,'PERMISSION_DENIED');return;}
  if(plan.version!==Number(row.planVersion)) {groupSignupConflict_(book,row,'VERSION_CONFLICT');return;}
  let currentRoster;
  try {currentRoster=groupSignupRoster_(book,row.classId);} catch(_) {groupSignupConflict_(book,row,'ROSTER_CHANGED');return;}
  if(JSON.stringify(currentRoster)!==row.roster) {groupSignupConflict_(book,row,'ROSTER_CHANGED');return;}
  const sheet=groupSignupSheet_(row),cells=sheet.getRange(5,1,roster.length,3).getDisplayValues(),formulas=sheet.getRange(5,3,roster.length,1).getFormulas();
  const identitiesMatch=cells.every((r,i)=>r[0]===String(roster[i].studentCode)&&r[1]===String(roster[i].fullName));
  if(!identitiesMatch) {groupSignupConflict_(book,row,'ROSTER_CHANGED');return;}
  const invalid=cells.map((r,i)=>!!formulas[i][0]||!!r[2]&&!definitions.some(g=>g.label===r[2]));
  if(invalid.some(Boolean)) {
    sheet.getRange(5,4,roster.length,1).setValues(invalid.map(b=>[b?'Nhóm không hợp lệ; chọn lại từ danh sách.':'Chưa đồng bộ: có ô chọn nhóm không hợp lệ.']));
    lab2Write_(book,[{table:'PortalGroupSignupSheets',row:{...row,lastError:'INVALID_GROUP_SELECTION'}}]);return;
  }
  const groups=definitions.map(g=>({id:g.id,name:g.name,memberIds:roster.filter((_,i)=>cells[i][2]===g.label).map(s=>s.studentId)}));
  const normalize=gs=>JSON.stringify(gs.map(g=>({...g,memberIds:[...g.memberIds].sort()})));
  const now=new Date().toISOString(),changed=normalize(groups)!==normalize(plan.groups),version=plan.version+(changed?1:0);
  const next={...row,planVersion:version,lastSyncedAt:now,lastError:''};
  const changes=[{table:'PortalGroupSignupSheets',row:next}];
  if(changed) {
    changes.push({table:'PortalGroupPlans',row:{classId:row.classId,groups:JSON.stringify(groups),version,updatedAt:now,updatedBy:'sheet:'+row.spreadsheetId,requestKey:'signup-sync-'+Utilities.getUuid()}},
      portalAudit_({uid:'sheet:'+row.spreadsheetId},row.classId,row.spreadsheetId,'SYNC_GROUP_SIGNUP',{version,assigned:groups.reduce((n,g)=>n+g.memberIds.length,0)}));
  }
  lab2Write_(book,changes);
  // Never rewrite students' choices: they may have edited again after our snapshot.
  const latest=sheet.getRange(5,3,roster.length,1).getDisplayValues();
  sheet.getRange(5,4,roster.length,2).setValues(cells.map((r,i)=>[latest[i][0]!==r[2]?'Đang chờ lần đồng bộ tiếp theo':r[2]?'Đã đồng bộ':'Chưa chọn nhóm',Utilities.formatDate(new Date(now),'Asia/Ho_Chi_Minh','dd/MM/yyyy HH:mm')]));
}
// One clock trigger for all classes, not one trigger for every student/file.
function syncGroupSignupSheets() {
  const started=Date.now(),book=SpreadsheetApp.openById(config_().id),lock=LockService.getScriptLock();
  if(!lock.tryLock(1000)) return {busy:true};
  let checked=0;
  try {
    if(!book.getSheetByName('PortalGroupSignupSheets')) return {checked};
    for(const row of lab2Read_(book,'PortalGroupSignupSheets').filter(r=>r.state==='OPEN').sort((a,b)=>a.lastSyncedAt.localeCompare(b.lastSyncedAt))) {
      if(Date.now()-started>45000) break;
      try {groupSignupSync_(book,row);checked++;}
      catch(_) {lab2Write_(book,[{table:'PortalGroupSignupSheets',row:{...groupSignupRecord_(book,row.classId),lastError:'GROUP_SIGNUP_SYNC_FAILED'}}]);}
    }
    return {checked};
  } finally {lock.releaseLock();}
}
