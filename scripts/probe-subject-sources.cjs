// Read-only public-feed probe, executing the same RSS parser as Apps Script.
const fs=require('node:fs'),vm=require('node:vm');
const {JSDOM}=require('../web_checkin/node_modules/jsdom');
const wrap=n=>({getName:()=>n.localName,getText:()=>n.textContent,getChildren:()=>[...n.children].map(wrap),getAttribute:k=>n.hasAttribute(k)?{getValue:()=>n.getAttribute(k)}:null});
const c=vm.createContext({Date,console,XmlService:{parse:xml=>({getRootElement:()=>wrap(new JSDOM(xml,{contentType:'text/xml'}).window.document.documentElement)})}});
vm.runInContext(fs.readFileSync('backend/apps_script/SubjectInsights.gs','utf8'),c);
(async()=>{
  for(const s of vm.runInContext('CONTENT_SOURCES.filter(s=>s.type==="RSS")',c)) {
    const r=await fetch(s.url,{signal:AbortSignal.timeout(20000)});
    if(!r.ok) throw Error(s.sourceId+': HTTP '+r.status);
    const rows=c.contentRss_(await r.text());
    if(!rows.length||!rows.some(i=>c.contentUrl_(i.url))) throw Error(s.sourceId+': invalid metadata');
    console.log(JSON.stringify({source:s.sourceId,http:r.status,parsed:rows.length,validDates:rows.filter(i=>c.contentDate_(i.publishedAt)).length}));
  }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
