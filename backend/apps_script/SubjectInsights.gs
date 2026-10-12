/* Owner-editable config, bounded metadata cache. No external feed is executable content. */
const CONTENT_SOURCES = [
  {sourceId:'android',label:'Android Developers',type:'RSS',url:'https://android-developers.googleblog.com/feeds/posts/default?alt=rss',enabled:'true'},
  {sourceId:'dotnet',label:'.NET Blog',type:'RSS',url:'https://devblogs.microsoft.com/dotnet/feed/',enabled:'true'},
  {sourceId:'webdev',label:'web.dev',type:'RSS',url:'https://web.dev/feed.xml',enabled:'true'},
  {sourceId:'crossref',label:'Crossref',type:'CROSSREF',url:'https://api.crossref.org/works',enabled:'true'},
  {sourceId:'openalex',label:'OpenAlex',type:'OPENALEX',url:'https://api.openalex.org/works',enabled:'true'},
];
/** Run after setupLab2Free. Adds defaults only for subjects actually present; never overwrites admin edits. */
function seedSubjectInsights() {
  const book=SpreadsheetApp.openById(config_().id),lock=LockService.getScriptLock();
  if(!lock.tryLock(15000)) throw Error('LOCK_BUSY');
  try {
    const defaults={PRM393:[['Flutter','Dart','Android','Firebase'],['android','crossref']],
      PRN212:[['.NET','C#','ASP.NET','Entity Framework'],['dotnet','crossref']],
      WDP301:[['React','JavaScript','TypeScript','Web Performance'],['webdev','crossref']]};
    const existing=lab2Read_(book,'SubjectContentConfig'),registry=lab2Read_(book,'ContentSourceRegistry');
    const changes=CONTENT_SOURCES.filter(s=>!registry.some(r=>r.sourceId===s.sourceId)).map(row=>({table:'ContentSourceRegistry',row}));
    for(const code of new Set(lab2Read_(book,'Classes').map(c=>c.subjectCode))) {
      if(!defaults[code]||existing.some(c=>c.subjectCode===code)) continue;
      changes.push({table:'SubjectContentConfig',row:{subjectCode:code,topicKeywords:JSON.stringify(defaults[code][0]),
        excludeKeywords:'[]',sourceIds:JSON.stringify(defaults[code][1]),enabled:'true',updatedAt:new Date().toISOString()}});
    }
    lab2Write_(book,changes);return {added:changes.length};
  } finally {lock.releaseLock();}
}
function contentSubjects_(book,actor) {
  if(actor.role!=='lecturer') throw Error('PERMISSION_DENIED');
  return [...new Set(lab2Read_(book,'Classes').filter(c=>c.lecturerId===actor.entity.lecturerId).map(c=>c.subjectCode))];
}
function contentList_(raw) {
  const value=JSON.parse(raw||'[]');
  if(!Array.isArray(value)||value.length>20||value.some(v=>typeof v!=='string'||v.length>100)) throw Error('INVALID_INPUT');
  return value;
}
function subjectTopics_(book,actor,d) {
  if(!contentSubjects_(book,actor).includes(d.subjectCode)) throw Error('PERMISSION_DENIED');
  const row=lab2Read_(book,'SubjectContentConfig').find(r=>r.subjectCode===d.subjectCode&&r.enabled==='true');
  return {subjectCode:d.subjectCode,configured:!!row,topics:row?contentList_(row.topicKeywords):[]};
}
function contentText_(value,limit=500) {
  return String(value||'').replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'').replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi,'')
    .replace(/<[^>]*>/g,' ').replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&quot;/g,'"').replace(/&#39;/g,"'")
    .replace(/\s+/g,' ').trim().slice(0,limit);
}
function contentUrl_(url) {
  const match=String(url||'').match(/^https:\/\/([a-z0-9.-]+)(\/[^\s]*)?$/i);
  if(!match||match[1].includes('..')||!match[1].includes('.')||/^(localhost|127\.|10\.|192\.168\.|169\.254\.|172\.(1[6-9]|2\d|3[01])\.)/.test(match[1])) return null;
  return String(url).split('#')[0].replace(/([?&])utm_[^&]+(&?)/g,(_,a,b)=>b?a:'').replace(/[?&]$/,'');
}
function contentDate_(value) {
  const t=Date.parse(value);return Number.isFinite(t)?new Date(t).toISOString():null;
}
function contentRss_(xml) {
  if(xml.length>1000000||/<!DOCTYPE|<!ENTITY/i.test(xml)) throw Error('UPSTREAM_UNAVAILABLE');
  const root=XmlService.parse(xml).getRootElement(), entries=[];
  function walk(n) {if(['item','entry'].includes(n.getName())) entries.push(n);else n.getChildren().forEach(walk);}
  walk(root);
  return entries.slice(0,40).map(e=>{
    const child=name=>e.getChildren().find(c=>c.getName()===name),text=name=>child(name)?child(name).getText():'';
    const link=e.getChildren().find(c=>c.getName()==='link'&&(!c.getAttribute('rel')||c.getAttribute('rel').getValue()==='alternate'));
    return {title:text('title'),url:link?(link.getAttribute('href')?link.getAttribute('href').getValue():link.getText()):'',
      publishedAt:text('pubDate')||text('published')||text('updated'),excerpt:text('description')||text('summary')};
  });
}
function contentFetch_(source,topics) {
  topics=topics.slice(0,4).map(t=>t.slice(0,80));
  const approved=CONTENT_SOURCES.find(s=>s.type===source.type&&s.url===source.url);
  if(!approved) throw Error('SOURCE_NOT_APPROVED');
  let url=source.url;
  if(source.type==='CROSSREF') url+='?rows=30&sort=published&order=desc&query='+encodeURIComponent(topics.join(' '));
  if(source.type==='OPENALEX') {
    const key=PropertiesService.getScriptProperties().getProperty('OPENALEX_API_KEY');
    if(!key) throw Error('OPENALEX_SETUP_REQUIRED');
    url+='?per-page=30&sort=publication_date:desc&search='+encodeURIComponent(topics.map(t=>'"'+t.replace(/"/g,'')+'"').join(' OR '))+'&api_key='+encodeURIComponent(key);
  }
  const response=UrlFetchApp.fetch(url,{muteHttpExceptions:true,followRedirects:false,timeoutSeconds:10});
  if(response.getResponseCode()!==200) throw Error('UPSTREAM_UNAVAILABLE');
  const text=response.getContentText();if(text.length>1000000) throw Error('UPSTREAM_UNAVAILABLE');
  if(source.type==='RSS') return contentRss_(text);
  const data=JSON.parse(text), items=source.type==='CROSSREF'?(data.message||{}).items:data.results;
  if(!Array.isArray(items)) throw Error('UPSTREAM_UNAVAILABLE');
  return items.slice(0,40).map(r=>{
    const date=source.type==='CROSSREF'?((r.published||{})['date-parts']||[])[0]:null;
    const doi=String(r.DOI||r.doi||'').replace(/^https?:\/\/(?:dx\.)?doi.org\//i,'').toLowerCase();
    return {title:Array.isArray(r.title)?r.title[0]:r.display_name||r.title,doi,url:doi?'https://doi.org/'+doi:r.URL,
      publishedAt:date?date.map((v,i)=>i?String(v).padStart(2,'0'):v).join('-'):r.publication_date,
      excerpt:lab2Abstract_(r),authors:source.type==='CROSSREF'?(r.author||[]).slice(0,10).map(a=>[a.given,a.family].filter(Boolean).join(' ')):
        (r.authorships||[]).slice(0,10).map(a=>(a.author||{}).display_name).filter(Boolean)};
  });
}
function contentNormalize_(raw,source,config,type,now) {
  const title=contentText_(raw.title,300),excerpt=contentText_(raw.excerpt,450),url=contentUrl_(raw.url);
  if(!title||!url) return null;
  if(type==='NEWS'&&url.match(/^https:\/\/([^/]+)/)[1]!==source.url.match(/^https:\/\/([^/]+)/)[1]) return null;
  const haystack=(title+' '+excerpt).toLowerCase(),topics=contentList_(config.topicKeywords),excludes=contentList_(config.excludeKeywords);
  const matched=topics.filter(t=>haystack.includes(t.toLowerCase()));
  if(!matched.length||excludes.some(t=>haystack.includes(t.toLowerCase()))) return null;
  const doi=String(raw.doi||'').toLowerCase();
  return {id:lab2Hash_(doi||url),contentType:type,title,canonicalUrl:url,url,doi,sourceName:source.label,source:source.label,
    publishedAt:contentDate_(raw.publishedAt),fetchedAt:new Date(now).toISOString(),excerpt,abstractSnippet:excerpt,
    authors:(raw.authors||[]).map(v=>contentText_(v,100)).slice(0,10),subjectCodes:[config.subjectCode],subjectIds:[config.subjectCode],
    matchedTopics:matched,relevanceScore:matched.length};
}
function contentFeed_(book,config,type) {
  const key=config.subjectCode+':'+type,now=Date.now(),configVersion=lab2Hash_(JSON.stringify(config));
  const cacheRow=lab2Read_(book,'SubjectContentCache').find(r=>r.id===key);
  let cached=null;try{cached=cacheRow?JSON.parse(cacheRow.feed):null;}catch(_){/* rebuildable cache */}
  if(cached&&cached.configVersion!==configVersion) cached=null;
  if(cached&&Number(cacheRow.expiresAt)>now) return cached;
  const lock=LockService.getScriptLock(),cache=CacheService.getScriptCache(),lease='content:'+key;
  const stale=()=>({...cached,items:cached?cached.items:[],stale:true,lastUpdatedAt:cached?cached.lastUpdatedAt:null,partialSourcesFailed:['Đang chờ nguồn / giới hạn làm mới']});
  if(!lock.tryLock(500)) return stale();
  try {
    if(cache.get(lease)) return stale();
    cache.put(lease,'1',120); // Distributed cooldown, including failed fetches.
  } finally {lock.releaseLock();}
  const selected=contentList_(config.sourceIds),topics=contentList_(config.topicKeywords);
  const sources=lab2Read_(book,'ContentSourceRegistry').filter(s=>selected.includes(s.sourceId)&&s.enabled==='true'&&(type==='NEWS'?s.type==='RSS':s.type!=='RSS')).slice(0,2);
  const failures=[],items=[];
  for(const source of sources) {
    try {for(const raw of contentFetch_(source,topics)) {const item=contentNormalize_(raw,source,config,type,now);if(item)items.push(item);}}
    catch(_){failures.push(source.label);}
  }
  if(failures.length===sources.length&&sources.length&&cached) return {...cached,stale:true,partialSourcesFailed:failures};
  const unique=new Map();for(const item of items) if(!unique.has(item.id)) unique.set(item.id,item);
  const normalized=[...unique.values()].sort((a,b)=>(Date.parse(b.publishedAt)||0)-(Date.parse(a.publishedAt)||0)).slice(0,24);
  const feed={items:normalized,configVersion,sources:sources.map(s=>s.label),lastUpdatedAt:sources.length&&failures.length<sources.length?new Date(now).toISOString():null,
    stale:failures.length>0,partialSourcesFailed:failures,configured:sources.length>0};
  while(JSON.stringify(feed).length>45000&&feed.items.length) feed.items.pop();
  if(!lock.tryLock(500)) return {...feed,stale:true};
  try {
    const rows=lab2Read_(book,'SubjectContentCache');
    if(!rows.some(r=>r.id===key)&&rows.length>=400) throw Error('ARTICLE_CACHE_FULL');
    lab2Write_(book,[{table:'SubjectContentCache',row:{id:key,feed:JSON.stringify(feed),expiresAt:now+(failures.length?120000:type==='NEWS'?21600000:86400000)}}]);
  }
  catch(_){return {...feed,stale:true};}finally{lock.releaseLock();}
  return feed;
}

/** Editor maintenance only; only rebuildable expired feed metadata is removed. */
function pruneSubjectContentCache() {
  const book=SpreadsheetApp.openById(config_().id),lock=LockService.getScriptLock();
  if(!lock.tryLock(15000)) throw Error('LOCK_BUSY');
  try {
    lab2Read_(book,'SubjectContentCache'); // Validate before removing any rebuildable rows.
    const sheet=book.getSheetByName('SubjectContentCache'),values=sheet.getDataRange().getDisplayValues();
    const expired=values.slice(1).map((r,i)=>({row:i+2,expiry:r[2]===''?NaN:Number(r[2])})).filter(r=>Number.isFinite(r.expiry)&&r.expiry<Date.now()-7*86400000).slice(-100);
    for(const r of expired.reverse()) sheet.deleteRow(r.row);
    return {removed:expired.length};
  } finally {lock.releaseLock();}
}
function subjectUpdates_(book,actor,d) {
  const allowed=contentSubjects_(book,actor),code=String(d.subjectCode||'');
  if(!allowed.includes(code)) throw Error('PERMISSION_DENIED');
  const type=d.type||'NEWS',sort=d.sort||'LATEST',limit=Number(d.limit||20),days=Number(d.days||0),query=String(d.query||'').trim().toLowerCase();
  if(!['NEWS','RESEARCH'].includes(type)||!['LATEST','RELEVANCE'].includes(sort)||!Number.isInteger(limit)||limit<1||limit>20||![0,7,30,90].includes(days)||query.length>150) throw Error('INVALID_INPUT');
  const config=lab2Read_(book,'SubjectContentConfig').find(r=>r.subjectCode===code&&r.enabled==='true');
  if(!config) return {items:[],configured:false,lastUpdatedAt:null,nextCursor:null,stale:false,partialSourcesFailed:[]};
  const feed=contentFeed_(book,config,type),stamp=lab2Hash_(JSON.stringify([code,type,sort,days,query,d.source||'',feed.lastUpdatedAt])).slice(0,16);
  let offset=0;
  if(d.cursor) {
    const parts=String(d.cursor).split(':');if(parts.length!==2||parts[0]!==stamp||!/^\d+$/.test(parts[1])) throw Error('CONTENT_CHANGED');
    offset=Number(parts[1]);if(offset>24) throw Error('INVALID_INPUT');
  }
  const items=feed.items.filter(i=>(!days||(Date.parse(i.publishedAt)||0)>=Date.now()-days*86400000)&&
    (!query||(i.title+' '+i.excerpt).toLowerCase().includes(query))&&(!d.source||i.sourceName===d.source));
  items.sort((a,b)=>sort==='RELEVANCE'&&a.relevanceScore!==b.relevanceScore?b.relevanceScore-a.relevanceScore:
    (Date.parse(b.publishedAt)||0)-(Date.parse(a.publishedAt)||0)||a.id.localeCompare(b.id));
  return {...feed,subjectCode:code,items:items.slice(offset,offset+limit),nextCursor:offset+limit<items.length?stamp+':'+(offset+limit):null};
}
