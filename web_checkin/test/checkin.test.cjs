const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {JSDOM} = require('jsdom');
const html = fs.readFileSync(path.join(__dirname,'../public/index.html'),'utf8');
const script = fs.readFileSync(path.join(__dirname,'../public/checkin.js'),'utf8');
const flush = () => new Promise(resolve=>setImmediate(resolve));
async function fixture(t, secretEnabled, error) {
  const dom = new JSDOM(html,{url:'https://example.com/checkin?sessionId=s1&token=qr&mode=student-code',runScripts:'outside-only'});
  t.after(()=>dom.window.close());
  const w=dom.window, $=id=>w.document.getElementById(id), calls=[];
  w.FAP_CONFIG={firebaseApiUrl:'https://example.com/api'};
  w.fetch=async (_,options)=>{
    const req=JSON.parse(options.body); calls.push(req);
    return {ok:true,json:async()=>error ? {ok:false,error} : {ok:true,data:req.action==='studentCodeSessionInfo' ? {
      checkInMode:'student-code-v2',session:{classCode:'SE1917',subjectCode:'PRN232',date:'2026-09-25',slot:1,startTime:'07:00',endTime:'09:15',secretEnabled}
    } : {fullName:'Student',studentCode:'SE123456'}}};
  };
  w.eval(script); await flush(); return {w,$,calls};
}
test('legacy code URL requires Google and exposes no code fallback',async t=>{
  const {$,calls}=await fixture(t,false);
  assert.equal($('switch-mode').hidden,true);
  assert.equal($('lesson').hidden,true);
  assert.equal($('google-button').hidden,false);
  assert.equal(calls.length,0);
  assert.match($('message').textContent,/Đăng nhập Google/);
});

test('Firebase Google popup passes a verified Firebase token to backend without navigating away', async t => {
  const dom = new JSDOM(html,{url:'https://example.com/checkin?sessionId=s1&token=qr&mode=google',runScripts:'outside-only'});
  t.after(()=>dom.window.close());
  const w=dom.window, $=id=>w.document.getElementById(id), calls=[];
  w.FAP_CONFIG={firebaseApiUrl:'https://example.com/api',firebase:{projectId:'mobile'}};
  let signins=0;
  const authentication={setPersistence:async()=>{},signInWithPopup:async()=>{signins++;return {user:{getIdToken:async()=> 'firebase-id-token'}};},signOut:async()=>{}};
  const auth=()=>authentication;
  auth.Auth={Persistence:{SESSION:'session'}};
  auth.GoogleAuthProvider=class {setCustomParameters(){}};
  w.firebase={initializeApp(){},auth};
  w.fetch=async (_,options)=>{
    const request=JSON.parse(options.body);calls.push({request, authorization:options.headers.Authorization});
    return {ok:true,json:async()=>({ok:true,data:{student:{fullName:'Student',studentCode:'SE123456',email:'s@fpt.edu.vn'},session:{subjectCode:'PRM393',classCode:'SE1928',date:'2026-10-09',slot:1,startTime:'07:00',endTime:'09:15',secretEnabled:false}}})};
  };
  w.eval(script); await new Promise(resolve=>setTimeout(resolve,180));
  $('google-button').querySelector('button').click(); await flush(); await flush();
  assert.equal(signins,1); assert.equal(calls[0].authorization,'Bearer firebase-id-token');
  assert.equal(calls[0].request.idToken,undefined);assert.equal(calls[0].request.token,'qr');
  assert.equal($('lesson').hidden,false);assert.equal($('identity').hidden,false);
  assert.equal(w.location.pathname,'/checkin');
  $('presence').checked=true;
  $('checkin-form').dispatchEvent(new w.Event('submit',{cancelable:true}));
  await flush();
  assert.equal(calls[1].request.action,'studentCheckIn');
  assert.equal(calls[1].authorization,'Bearer firebase-id-token');
});

test('blocked Firebase popup is actionable and leaves Google button usable', async t => {
  const dom = new JSDOM(html,{url:'https://example.com/checkin?sessionId=s1&token=qr&mode=google',runScripts:'outside-only'});
  t.after(()=>dom.window.close());
  const w=dom.window, $=id=>w.document.getElementById(id);
  w.FAP_CONFIG={firebaseApiUrl:'https://example.com/api',firebase:{projectId:'mobile'}};
  const auth=()=>({setPersistence:async()=>{},signInWithPopup:async()=>{throw {code:'auth/popup-blocked'};}});
  auth.Auth={Persistence:{SESSION:'session'}};auth.GoogleAuthProvider=class {setCustomParameters(){}};
  w.firebase={initializeApp(){},auth};
  w.eval(script);await new Promise(resolve=>setTimeout(resolve,180));
  const button=$('google-button').querySelector('button');button.click();await flush();
  assert.match($('message').textContent,/chặn cửa sổ Google/);assert.equal(button.disabled,false);
  assert.equal($('authentication').hidden,false);assert.equal(w.location.pathname,'/checkin');
});

