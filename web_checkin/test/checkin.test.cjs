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
  w.FAP_CONFIG={appsScriptUrl:'https://example.com/api'};
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

test('Google popup callback retains QR, shows lesson on the same page and records presence once', async t => {
  const dom = new JSDOM(html,{url:'https://example.com/checkin?sessionId=s1&token=qr',runScripts:'outside-only'});
  t.after(()=>dom.window.close());
  const w=dom.window, $=id=>w.document.getElementById(id), calls=[];
  let config;
  w.FAP_CONFIG={appsScriptUrl:'https://example.com/api',googleWebClientId:'web-client'};
  w.google={accounts:{id:{initialize:c=>config=c,renderButton(){},disableAutoSelect(){}}}};
  w.fetch=async (_,options)=>{
    const request=JSON.parse(options.body); calls.push(request);
    return {ok:true,json:async()=>({ok:true,data:request.action==='studentSessionInfo' ? {
      student:{fullName:'Student',studentCode:'SE123456',email:'student@fpt.edu.vn'},
      session:{subjectName:'Mobile',subjectCode:'PRM393',classCode:'SE1928',date:'2026-10-09',slot:1,startTime:'07:00',endTime:'09:15',secretEnabled:true}
    } : {fullName:'Student',studentCode:'SE123456'}})};
  };
  w.eval(script); await new Promise(resolve=>setTimeout(resolve,180));
  assert.equal(config.ux_mode,'popup'); assert.equal(config.use_fedcm_for_button,false);
  await config.callback({credential:'verified-by-backend-token'}); await flush();
  assert.equal(w.location.href,'https://example.com/checkin?sessionId=s1&token=qr');
  assert.equal($('lesson').hidden,false); assert.equal($('identity').hidden,false);
  assert.equal($('code-field').hidden,true); assert.equal($('course').textContent,'Mobile · SE1928');
  assert.equal(calls[0].token,'qr'); assert.equal(calls[0].idToken,'verified-by-backend-token');
  $('presence').checked=true; $('presence').dispatchEvent(new w.Event('change'));
  assert.equal($('submit').disabled,true);
  $('secret').value='123456'; $('secret').dispatchEvent(new w.Event('input'));
  $('checkin-form').dispatchEvent(new w.Event('submit',{cancelable:true}));
  $('checkin-form').dispatchEvent(new w.Event('submit',{cancelable:true})); await flush();
  assert.equal(calls.length,2); assert.equal(calls[1].action,'studentCheckIn');
  assert.equal(calls[1].token,'qr'); assert.equal(calls[1].secretCode,'123456');
  assert.equal($('success').hidden,false); assert.equal($('authentication').hidden,true);
});

test('Google verification failure keeps visible UI and permits retry without an unauthenticated fallback', async t => {
  const dom = new JSDOM(html,{url:'https://example.com/checkin?sessionId=s1&token=qr',runScripts:'outside-only'});
  t.after(()=>dom.window.close());
  const w=dom.window, $=id=>w.document.getElementById(id); let config;
  w.FAP_CONFIG={appsScriptUrl:'https://example.com/api',googleWebClientId:'web-client'};
  w.google={accounts:{id:{initialize:c=>config=c,renderButton(){},disableAutoSelect(){}}}};
  w.fetch=async()=>({ok:true,json:async()=>({ok:false,error:'Email chưa có trong danh sách lớp.'})});
  w.eval(script); await new Promise(resolve=>setTimeout(resolve,180));
  await config.callback({credential:'token'}); await flush();
  assert.match($('message').textContent,/Email chưa có/);
  assert.equal($('authentication').hidden,false); assert.equal($('retry').hidden,false);
  assert.equal($('submit').disabled,true); assert.equal(w.location.pathname,'/checkin');
  assert.equal($('switch-mode').hidden,true);
});

test('Firebase Google popup passes a verified Firebase token to backend without navigating away', async t => {
  const dom = new JSDOM(html,{url:'https://example.com/checkin?sessionId=s1&token=qr&mode=google',runScripts:'outside-only'});
  t.after(()=>dom.window.close());
  const w=dom.window, $=id=>w.document.getElementById(id), calls=[];
  w.FAP_CONFIG={appsScriptUrl:'https://example.com/api',firebase:{projectId:'mobile'}};
  let signins=0;
  const authentication={setPersistence:async()=>{},signInWithPopup:async()=>{signins++;return {user:{getIdToken:async()=> 'firebase-id-token'}};},signOut:async()=>{}};
  const auth=()=>authentication;
  auth.Auth={Persistence:{SESSION:'session'}};
  auth.GoogleAuthProvider=class {setCustomParameters(){}};
  w.firebase={initializeApp(){},auth};
  w.fetch=async (_,options)=>{
    const request=JSON.parse(options.body);calls.push(request);
    return {ok:true,json:async()=>({ok:true,data:{student:{fullName:'Student',studentCode:'SE123456',email:'s@fpt.edu.vn'},session:{subjectCode:'PRM393',classCode:'SE1928',date:'2026-10-09',slot:1,startTime:'07:00',endTime:'09:15',secretEnabled:false}}})};
  };
  w.eval(script); await new Promise(resolve=>setTimeout(resolve,180));
  $('google-button').querySelector('button').click(); await flush(); await flush();
  assert.equal(signins,1); assert.equal(calls[0].firebaseAuth,true);
  assert.equal(calls[0].idToken,'firebase-id-token');assert.equal(calls[0].token,'qr');
  assert.equal($('lesson').hidden,false);assert.equal($('identity').hidden,false);
  assert.equal(w.location.pathname,'/checkin');
});

test('blocked Firebase popup is actionable and leaves Google button usable', async t => {
  const dom = new JSDOM(html,{url:'https://example.com/checkin?sessionId=s1&token=qr&mode=google',runScripts:'outside-only'});
  t.after(()=>dom.window.close());
  const w=dom.window, $=id=>w.document.getElementById(id);
  w.FAP_CONFIG={appsScriptUrl:'https://example.com/api',firebase:{projectId:'mobile'}};
  const auth=()=>({setPersistence:async()=>{},signInWithPopup:async()=>{throw {code:'auth/popup-blocked'};}});
  auth.Auth={Persistence:{SESSION:'session'}};auth.GoogleAuthProvider=class {setCustomParameters(){}};
  w.firebase={initializeApp(){},auth};
  w.eval(script);await new Promise(resolve=>setTimeout(resolve,180));
  const button=$('google-button').querySelector('button');button.click();await flush();
  assert.match($('message').textContent,/chặn cửa sổ Google/);assert.equal(button.disabled,false);
  assert.equal($('authentication').hidden,false);assert.equal(w.location.pathname,'/checkin');
});

