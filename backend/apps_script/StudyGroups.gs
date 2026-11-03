/* Shared groups: identity supplied only by authenticated portal/lab2 handlers. */
function setupStudyGroups() {
  setupStudentPortal();
  const props=PropertiesService.getScriptProperties();
  if(!props.getProperty('GROUP_FILES_FOLDER_ID')) {
    const folder=DriveApp.createFolder('FAP Study Group Files');
    if(folder.getSharingAccess()!==DriveApp.Access.PRIVATE) throw Error('GROUP_FOLDER_MUST_BE_PRIVATE');
    props.setProperty('GROUP_FILES_FOLDER_ID',folder.getId());
  }
  return {ready:true};
}
function groupPlan_(book,classId) {
  const row=lab2Read_(book,'PortalGroupPlans').find(r=>r.classId===classId);
  return row?{...row,version:Number(row.version),groups:JSON.parse(row.groups)}:{classId,version:0,groups:[],requestKey:''};
}
function groupAccess_(book,actor,d) {
  lab2Class_(book,actor,String(d.classId||''),false);
  const group=groupPlan_(book,d.classId).groups.find(g=>g.id===d.groupId);
  if(!group||actor.role!=='lecturer'&&!group.memberIds.includes(actor.entity.studentId)) throw Error('GROUP_ACCESS_DENIED');
  return group;
}
function groupCall_(book,actor,method,d) {
  if(!d||typeof d!=='object'||Array.isArray(d)) throw Error('INVALID_INPUT');
  lab2Class_(book,actor,String(d.classId||''),false);
  const plan=groupPlan_(book,d.classId),roster=portalRoster_(book,d.classId);
  if(method==='getGroupPlan') {
    const groups=actor.role==='lecturer'?plan.groups:plan.groups.filter(g=>g.memberIds.includes(actor.entity.studentId));
    const visible=new Set(groups.flatMap(g=>g.memberIds));
    return {classId:d.classId,viewerId:actor.uid,version:plan.version,groups,students:roster.filter(s=>actor.role==='lecturer'||visible.has(s.studentId)).map(s=>({studentId:s.studentId,studentCode:s.studentCode,fullName:s.fullName}))};
  }
  if(method==='saveGroupPlan') {
    portalTeacher_(actor);const key=portalKey_(d.requestKey);
    if(plan.requestKey===key) return {saved:true,version:plan.version};
    portalVersion_(plan,d.version);
    if(!Array.isArray(d.groups)||d.groups.length>50) throw Error('INVALID_GROUPS');
    const used=new Set(),ids=new Set(),names=new Set(),oldIds=new Set(plan.groups.map(g=>g.id));
    const history=lab2Read_(book,'PortalGroupMessages');
    const groups=d.groups.map(g=>{
      if(!g||typeof g.id!=='string'||!/^[A-Za-z0-9-]{16,80}$/.test(g.id)||ids.has(g.id)||typeof g.name!=='string'||!g.name.trim()||g.name.trim().length>80||names.has(g.name.trim())||!Array.isArray(g.memberIds)) throw Error('INVALID_GROUPS');
      if(!oldIds.has(g.id)&&history.some(m=>m.groupId===g.id)) throw Error('INVALID_GROUPS');
      ids.add(g.id);names.add(g.name.trim());
      for(const id of g.memberIds) {if(used.has(id)||!roster.some(s=>s.studentId===id)) throw Error('INVALID_GROUP_MEMBERS');used.add(id);}
      return {id:g.id,name:g.name.trim(),memberIds:g.memberIds};
    });
    if(used.size!==roster.length) throw Error('ROSTER_CHANGED');
    const row={classId:d.classId,groups:JSON.stringify(groups),version:plan.version+1,updatedAt:new Date().toISOString(),updatedBy:actor.uid,requestKey:key};
    if(row.groups.length>45000) throw Error('INVALID_GROUPS');
    lab2Write_(book,[{table:'PortalGroupPlans',row},portalAudit_(actor,d.classId,d.classId,'SAVE_GROUP_PLAN',{version:row.version,groups:groups.length})]);
    return {saved:true,version:row.version};
  }
  const group=groupAccess_(book,actor,d);
  const rows=lab2Read_(book,'PortalGroupMessages').filter(m=>m.classId===d.classId&&m.groupId===d.groupId);
  if(method==='ackGroupMessages') {
    if(!book.getSheetByName('PortalGroupReceipts')) throw Error('GROUP_RECEIPTS_SETUP_REQUIRED');
    const delivered=d.deliveredIds||[],read=d.readIds||[];
    if(!Array.isArray(delivered)||!Array.isArray(read)||delivered.length>50||read.length>50||[...delivered,...read].some(id=>typeof id!=='string'||!rows.some(m=>m.id===id))) throw Error('INVALID_RECEIPTS');
    const id=lab2Hash_(d.classId+'|'+d.groupId+'|'+actor.uid),stored=lab2Read_(book,'PortalGroupReceipts').find(r=>r.id===id);
    const receipts=stored?JSON.parse(stored.receipts):{},now=new Date().toISOString();let changed=false;
    for(const messageId of new Set([...delivered,...read])) {
      if(rows.find(m=>m.id===messageId).sender===actor.uid) continue;
      const old=receipts[messageId]||{deliveredAt:'',readAt:''};
      const next={deliveredAt:old.deliveredAt||now,readAt:old.readAt||(read.includes(messageId)?now:'')};
      if(old.deliveredAt!==next.deliveredAt||old.readAt!==next.readAt) {receipts[messageId]=next;changed=true;}
    }
    // Bound each actor/group record to the most recent 200 messages (one cell).
    const kept={};for(const m of rows.slice(-200)) if(receipts[m.id]) kept[m.id]=receipts[m.id];
    if(changed) lab2Write_(book,[{table:'PortalGroupReceipts',row:{id,classId:d.classId,groupId:d.groupId,actor:actor.uid,receipts:JSON.stringify(kept)}}]);
    return {saved:true};
  }
  if(method==='getGroupMessages') {
    const before=d.before?rows.findIndex(m=>m.id===d.before):rows.length;
    if(before<0) throw Error('INVALID_CURSOR');
    const start=Math.max(0,before-50);
    const tracking=!!book.getSheetByName('PortalGroupReceipts');
    const members=new Set(group.memberIds.filter(id=>roster.some(s=>s.studentId===id)).map(id=>'student-'+id));
    const receipts=tracking?lab2Read_(book,'PortalGroupReceipts').filter(r=>r.classId===d.classId&&r.groupId===d.groupId&&members.has(r.actor)).map(r=>({actor:r.actor,receipts:JSON.parse(r.receipts)})):[];
    return {viewerId:actor.uid,receiptTracking:tracking,messages:rows.slice(start,before).map(({requestKey,fileId,...m})=>{
      const mine=m.sender===actor.uid,result={...m,mine,size:Number(m.size),hasFile:!!fileId};
      if(mine) {
        const received=receipts.filter(r=>r.actor!==actor.uid&&r.receipts[m.id]?.deliveredAt),seen=received.filter(r=>r.receipts[m.id].readAt);
        result.delivery={deliveredCount:received.length,readCount:seen.length,recipientCount:[...members].filter(id=>id!==actor.uid).length,
          deliveredAt:received.map(r=>r.receipts[m.id].deliveredAt).sort()[0]||null,readAt:seen.map(r=>r.receipts[m.id].readAt).sort()[0]||null};
      }
      return result;
    }),older:start>0?rows[start].id:null};
  }
  if(method==='downloadGroupFile') {
    const message=rows.find(m=>m.id===d.messageId&&m.fileId);
    if(!message) throw Error('GROUP_ACCESS_DENIED');
    const folderId=PropertiesService.getScriptProperties().getProperty('GROUP_FILES_FOLDER_ID');
    if(!folderId) throw Error('GROUP_FILES_NOT_CONFIGURED');
    const file=DriveApp.getFileById(message.fileId),parents=file.getParents();
    let inside=false;while(parents.hasNext()) if(parents.next().getId()===folderId) inside=true;
    if(!inside) throw Error('GROUP_ACCESS_DENIED');
    const blob=file.getBlob();if(blob.getBytes().length>512000) throw Error('FILE_TOO_LARGE');
    return {name:message.fileName,mimeType:message.mimeType,base64:Utilities.base64Encode(blob.getBytes())};
  }
  if(method==='sendGroupMessage') {
    const key=portalKey_(d.requestKey),existing=rows.find(m=>m.sender===actor.uid&&m.requestKey===key);
    if(existing) return {saved:true,id:existing.id,createdAt:existing.createdAt};
    const text=typeof d.text==='string'?d.text.trim():'';
    if(text.length>2000||(!text&&!d.file)) throw Error('INVALID_MESSAGE');
    let file=null,name='',mime='',size=0;
    if(d.file) {
      const f=d.file,allowed={'pdf':'application/pdf','txt':'text/plain','png':'image/png','jpg':'image/jpeg','jpeg':'image/jpeg','xlsx':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','docx':'application/vnd.openxmlformats-officedocument.wordprocessingml.document','csv':'text/csv'};
      if(typeof f.name!=='string'||!f.name||f.name.length>120||/[\x00-\x1f\\/]/.test(f.name)||typeof f.base64!=='string'||f.base64.length>682668||!/^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(f.base64)) throw Error('INVALID_FILE');
      name=f.name;mime=allowed[name.split('.').pop().toLowerCase()];if(!mime) throw Error('INVALID_FILE');
      const bytes=Utilities.base64Decode(f.base64);size=bytes.length;if(size<1||size>512000) throw Error('FILE_TOO_LARGE');
      const folderId=PropertiesService.getScriptProperties().getProperty('GROUP_FILES_FOLDER_ID');if(!folderId) throw Error('GROUP_FILES_NOT_CONFIGURED');
      const folder=DriveApp.getFolderById(folderId);
      if(folder.getSharingAccess()!==DriveApp.Access.PRIVATE||folder.getEditors().length||folder.getViewers().length) throw Error('GROUP_FOLDER_MUST_BE_PRIVATE');
      file=folder.createFile(Utilities.newBlob(bytes,mime,name));
      if(file.getSharingAccess()!==DriveApp.Access.PRIVATE) {file.setTrashed(true);throw Error('GROUP_FOLDER_MUST_BE_PRIVATE');}
    }
    const row={id:Utilities.getUuid(),classId:d.classId,groupId:d.groupId,sender:actor.uid,senderName:actor.entity.fullName||'Thành viên',text,fileId:file?file.getId():'',fileName:name,mimeType:mime,size,createdAt:new Date().toISOString(),requestKey:key};
    // Keep file on uncertain batch failure: retry may find committed receipt.
    lab2Write_(book,[{table:'PortalGroupMessages',row}]);return {saved:true,id:row.id,createdAt:row.createdAt};
  }
  throw Error('FEATURE_DISABLED');
}
