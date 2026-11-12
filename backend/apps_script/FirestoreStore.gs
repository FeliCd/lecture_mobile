/* Shared API persistence. OAuth belongs to the Apps Script owner, never a client. */
const SHARED_TABLE_ROOT = 'sharedApiDatasets';

function firestoreBook_(project,dataset) {
  if(!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project||'')||!/^dataset-[a-f0-9-]{36}$/.test(dataset||''))
    throw Error('INVALID_SHARED_FIRESTORE_CONFIG');
  const database='projects/'+project+'/databases/(default)/documents';
  const root=SHARED_TABLE_ROOT+'/'+dataset;
  const cache=new Map();
  let token;
  function request(path,body) {
    token=token||ScriptApp.getOAuthToken();
    const options={headers:{Authorization:'Bearer '+token},muteHttpExceptions:true};
    if(body!==undefined) Object.assign(options,{method:'post',contentType:'application/json',payload:JSON.stringify(body)});
    const response=UrlFetchApp.fetch('https://firestore.googleapis.com/v1/'+database+path,options);
    const status=response.getResponseCode();
    if(status<200||status>=300) throw Error('FIRESTORE_REQUEST_FAILED_'+status);
    return JSON.parse(response.getContentText());
  }
  return {firestore:true,database,root,request,cache};
}

function firestoreHeader_(table) {
  if(table==='PortalGroupSignups') return ['classId','roundId','state','requestKey','createdAt','updatedAt','closedAt'];
  const header=Object.hasOwn(LAB2_TABLES,table)?LAB2_TABLES[table]:Object.hasOwn(SCHEMA,table)?SCHEMA[table]:null;
  if(!header) throw Error('INVALID_INPUT');
  return header;
}

function firestoreDecodeRow_(table,document) {
  const data=document.fields;
  const values=data?.row?.mapValue?.fields;
  const position=data?.position?.stringValue;
  const header=firestoreHeader_(table);
  if(!values||typeof position!=='string'||header.some(key=>typeof values[key]?.stringValue!=='string'))
    throw Error('INVALID_FIRESTORE_ROW_'+table);
  const row=Object.fromEntries(header.map(key=>[key,values[key].stringValue]));
  if(!row[header[0]]||!document.name.endsWith('/'+lab2Hash_(row[header[0]]))) throw Error('INVALID_FIRESTORE_ID_'+table);
  return {row,position};
}

function firestoreRows_(book,table,filter,ids) {
  firestoreHeader_(table);
  const cacheKey=JSON.stringify([table,filter||null,ids||null]);
  if(!book.cache.has(cacheKey)) {
    const documents=[];
    if(ids) {
      for(let start=0;start<ids.length;start+=300) {
        const names=ids.slice(start,start+300).map(id=>book.database+'/'+book.root+'/'+table+'/'+lab2Hash_(id));
        const response=book.request(':batchGet',{documents:names,...(book.readTime?{readTime:book.readTime}:{})});
        for(const entry of response) if(entry.found) documents.push(entry.found);
      }
    } else if(filter) {
      const [key,value]=filter;
      if(key!=='identityEmail'&&!firestoreHeader_(table).includes(key)) throw Error('INVALID_INPUT');
      const values=Array.isArray(value)?[...new Set(value)]:[value];
      for(let offset=0;offset<values.length;offset+=25) {
        const chunk=values.slice(offset,offset+25).map(item=>({stringValue:String(item)}));
        const structuredQuery={from:[{collectionId:table}],where:{fieldFilter:{
          field:{fieldPath:key==='identityEmail'?key:'row.'+key},
          op:chunk.length===1?'EQUAL':'IN',value:chunk.length===1?chunk[0]:{arrayValue:{values:chunk}}}}};
        const response=book.request('/'+book.root+':runQuery',{structuredQuery,...(book.readTime?{readTime:book.readTime}:{})});
        for(const entry of response) if(entry.document) documents.push(entry.document);
      }
    } else {
      let pageToken='';
      do {
        const query='?pageSize=300'+(pageToken?'&pageToken='+encodeURIComponent(pageToken):'')+
          (book.readTime?'&readTime='+encodeURIComponent(book.readTime):'');
        const page=book.request('/'+book.root+'/'+table+query);
        documents.push(...(page.documents||[]));
        pageToken=page.nextPageToken||'';
      } while(pageToken);
    }
    const entries=documents.map(document=>firestoreDecodeRow_(table,document));
    entries.sort((a,b)=>a.position<b.position?-1:a.position>b.position?1:0);
    book.cache.set(cacheKey,entries);
  }
  return book.cache.get(cacheKey).map(entry=>({...entry.row}));
}

function firestoreReadSnapshot_(book,read) {
  const response=book.request(':batchGet',{documents:[book.database+'/'+book.root],mask:{fieldPaths:['state']}});
  const marker=response.find(entry=>entry.found);
  if(marker?.found.fields?.state?.stringValue!=='ready'||!marker.readTime) throw Error('DATABASE_NOT_READY');
  book.cache.clear();
  book.readTime=marker.readTime;
  try { return read(); }
  finally {
    book.readTime=null;
    book.cache.clear();
  }
}

function firestoreWrite_(book,changes,migrating=false) {
  if(!migrating) assertSharedWritable_(book);
  const writes=new Map();
  changes.forEach(change=>{
    const header=firestoreHeader_(change.table);
    const id=String(change.id??change.row?.[header[0]]??'');
    if(!id) throw Error('INVALID_INPUT');
    const name=book.database+'/'+book.root+'/'+change.table+'/'+lab2Hash_(id);
    if(change.delete) {
      writes.set(name,{delete:name});
      return;
    }
    const values=Object.fromEntries(header.map(key=>[key,{stringValue:String(change.row[key]??'')}]));
    // Preserve the original row order on updates without reading an entire table.
    const update={name,fields:{row:{mapValue:{fields:values}}}};
    if(migrating) update.fields.position={stringValue:change.position};
    const identityKey={Lecturers:'email',Students:'schoolEmail'}[change.table];
    if(identityKey) update.fields.identityEmail={stringValue:values[identityKey].stringValue.trim().toLowerCase()};
    writes.set(name,{update,...(migrating?{}:{updateMask:{fieldPaths:Object.keys(update.fields)}})});
  });
  if(!writes.size) return;
  if(!migrating) {
    // Read only the affected document IDs. New documents need an ordering field.
    // These calls and the commit run under the existing Apps Script write lock.
    const marker=book.request('/'+book.root);
    if(marker.fields?.backendWriter?.stringValue==='firebase') throw Error('BACKEND_MOVED_TO_FIREBASE');
    const sequence=Number(marker.fields?.sequence?.integerValue);
    if(marker.fields?.state?.stringValue!=='ready'||!marker.updateTime||!Number.isSafeInteger(sequence)||sequence<0||sequence>=Number.MAX_SAFE_INTEGER)
      throw Error('DATABASE_NOT_READY');
    const stamp=String(sequence+1).padStart(16,'0');
    const candidates=[...writes.values()].filter(write=>write.update);
    for(let start=0;start<candidates.length;start+=300) {
      const chunk=candidates.slice(start,start+300);
      const response=book.request(':batchGet',{documents:chunk.map(write=>write.update.name),mask:{fieldPaths:['position']}});
      const missing=new Set(response.filter(entry=>entry.missing).map(entry=>entry.missing));
      const found=new Set(response.filter(entry=>entry.found?.fields?.position?.stringValue).map(entry=>entry.found.name));
      chunk.forEach((write,index)=>{
        const name=write.update.name;
        if(missing.has(name)) {
          write.update.fields.position={stringValue:'1'+stamp+String(start+index).padStart(7,'0')};
          delete write.updateMask;
          write.currentDocument={exists:false};
        } else if(found.has(name)) write.currentDocument={exists:true};
        else throw Error('INVALID_FIRESTORE_WRITE_LOOKUP');
      });
    }
    // The metadata precondition rejects a commit racing with another writer.
    writes.set(marker.name,{update:{name:marker.name,fields:{sequence:{integerValue:String(sequence+1)}}},
      updateMask:{fieldPaths:['sequence']},currentDocument:{updateTime:marker.updateTime}});
  }
  const payload={writes:[...writes.values()]};
  if(Utilities.newBlob(JSON.stringify(payload)).getBytes().length>9*1024*1024) throw Error('DATABASE_BATCH_TOO_LARGE');
  try { book.request(':commit',payload); }
  finally { book.cache.clear(); }
}
