// Read-only deployment smoke check. No user accounts, tokens or attendance writes.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const cfg=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../config/lab2.free.json'),'utf8'));
async function call(action, data={}) {
  let r=await fetch(cfg.APPS_SCRIPT_URL,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action,...data}),redirect:'manual',signal:AbortSignal.timeout(40000)});
  if([302,303].includes(r.status)) {
    const target=new URL(r.headers.get('location'));
    assert.equal(target.protocol,'https:');assert.equal(target.hostname,'script.googleusercontent.com');
    r=await fetch(target,{redirect:'error',signal:AbortSignal.timeout(40000)});
  }
  assert.equal(r.status,200);return r.json();
}
(async()=>{
  const health=await call('lab2Health');
  assert.equal(health.ok,true);assert.equal(health.data.version,'lab2-shared-sheets-v2');
  for(const capability of ['attendanceSafety','subjectInsights','scheduleExceptions','rosterAudit','scheduleDrivenSessions'])
    assert.ok(health.data.capabilities.includes(capability));
  assert.equal(health.data.firebaseProject,'fap-attendance-88920');
  assert.equal(health.data.authConfigured,true);assert.equal(health.data.quizEnabled,false);
  const privateRequest=await call('lab2Snapshot');
  assert.equal(privateRequest.ok,false);assert.equal(privateRequest.error,'UNAUTHENTICATED');
  const legacyRequest=await call('login');
  assert.equal(legacyRequest.ok,false);
  const googleRequest=await call('studentSessionInfo',{firebaseAuth:true,idToken:'invalid',sessionId:'verification-only',token:'verification-only'});
  assert.equal(googleRequest.ok,false);assert.equal(googleRequest.error,'UNAUTHENTICATED');
  console.log(JSON.stringify({health:health.data,unauthenticatedAccessDenied:true,legacyAuthenticationGuard:true,firebaseGoogleWebGuard:true},null,2));
})().catch(()=>{console.error('Shared backend smoke check failed. Inspect deployment version/configuration.');process.exitCode=1;});
