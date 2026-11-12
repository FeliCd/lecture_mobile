/* FCM announces a saved group message. Sheets remains the chat history. */
function groupPushProject_() {
  const project=PropertiesService.getScriptProperties().getProperty('GROUP_FCM_PROJECT_ID');
  return /^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project||'')?project:null;
}

function groupPushDevice_(book,actor,d,remove) {
  if(!actor.firebaseUid) throw Error('PERMISSION_DENIED');
  if(!['android','web'].includes(d.platform)||typeof d.token!=='string'||
      !/^[A-Za-z0-9_:\-]{20,4096}$/.test(d.token)) throw Error('INVALID_FCM_TOKEN');
  if(actor.role!==(d.platform==='android'?'lecturer':'student')) throw Error('PERMISSION_DENIED');
  if(!sharedHasTable_(book,'PortalGroupPushDevices')) {
    if(remove) return {enabled:false};
    throw Error('GROUP_PUSH_SETUP_REQUIRED');
  }
  if(!remove&&!groupPushProject_()) throw Error('GROUP_PUSH_SETUP_REQUIRED');
  const table='PortalGroupPushDevices',rows=lab2Read_(book,table);
  const id=lab2Hash_(actor.uid+'|'+d.platform);
  const old=rows.find(r=>r.id===id);
  if(remove) {
    if(old&&old.firebaseUid===actor.firebaseUid&&old.token===d.token) {
      lab2Write_(book,[{table,row:{...old,token:''}}]);
    }
    return {enabled:false};
  }
  const changes=rows.filter(r=>r.id!==id&&r.token===d.token)
    .map(row=>({table,row:{...row,token:''}}));
  changes.push({table,row:{id,actor:actor.uid,firebaseUid:actor.firebaseUid,
    platform:d.platform,token:d.token,updatedAt:new Date().toISOString()}});
  lab2Write_(book,changes);
  return {enabled:true};
}

function groupPushAfterCommit_(book,actor,result) {
  const event=result?._groupPush;
  if(!event) return result;
  delete result._groupPush;
  try {
    const project=groupPushProject_();
    if(!project||!sharedHasTable_(book,'PortalGroupPushDevices')) return result;
    const cls=lab2Class_(book,actor,event.classId,false), group=groupAccess_(book,actor,event);
    const enrolled=new Set(portalRoster_(book,event.classId).map(s=>s.studentId));
    const recipients=new Set(['lecturer-'+cls.lecturerId,
      ...group.memberIds.filter(id=>enrolled.has(id)).map(id=>'student-'+id)]);
    recipients.delete(actor.uid);
    const fresh=Date.now()-30*86400000;
    const devices=lab2Read_(book,'PortalGroupPushDevices').filter(row=>
      row.token&&recipients.has(row.actor)&&Date.parse(row.updatedAt)>fresh);
    if(!devices.length) return result;
    const authorization='Bearer '+ScriptApp.getOAuthToken();
    const web=PropertiesService.getScriptProperties().getProperty('GROUP_FCM_WEB_URL');
    const link=/^https:\/\/[a-z0-9.-]+\/?$/i.test(web||'')
      ? web.replace(/\/$/,'')+'/?chatClass='+encodeURIComponent(event.classId)
      : null;
    UrlFetchApp.fetchAll(devices.map(device=>({
      url:'https://fcm.googleapis.com/v1/projects/'+project+'/messages:send',
      method:'post',contentType:'application/json',headers:{Authorization:authorization},
      muteHttpExceptions:true,followRedirects:false,timeoutSeconds:10,
      payload:JSON.stringify({message:{
        token:device.token,
        notification:{title:'Tin nhắn nhóm mới',body:'Mở FAP Attendance để xem hội thoại.'},
        data:{screen:'group-chat',classId:event.classId,groupId:event.groupId,
          messageId:result.id,recipientUid:device.firebaseUid},
        android:{ttl:'3600s',notification:{tag:result.id}},
        webpush:{headers:{TTL:'3600'},notification:{tag:result.id},
          ...(link?{fcm_options:{link}}:{})},
      }}),
    })));
  } catch(_) {
    // Push is best effort. A failure must never turn a committed send into a failed send.
  }
  return result;
}
