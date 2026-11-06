const test=require('node:test');
const assert=require('node:assert/strict');
const {fixture}=require('./portal-fixture.cjs');
function setup(email='teacher@fpt.edu.vn',provider='google.com') {
  const f=fixture();
  f.c.lab2FirebaseIdentity_=()=>({email,firebaseUid:'verified-device',signInProvider:provider,emailVerified:true});
  const call=(method,data={classId:'c1'})=>f.c.lab2Handle_({action:'lab2Call',idToken:'verified-test-token',name:'portalCall',input:{method,data}});
  return {...f,call};
}
test('mobile lecturer uses the same draft and immutable publication as desktop/student web',()=>{
  const f=setup();
  const book=f.call('getGradebook'); assert.equal(book.version,0);
  const rows=book.students.map(s=>({studentId:s.studentId,grades:{quiz:s.studentId==='s1'?0:8.5},comment:''}));
  f.call('saveGradebook',{classId:'c1',version:0,components:[{id:'quiz',name:'Quiz',maxScore:10}],students:rows});
  assert.equal(f.c.portalCall_(f.book,f.student,'getMyPublishedGrades',{classId:'c1'}).published,false);
  const payload={classId:'c1',version:1,requestKey:'mobile-publication-123456',studentIds:rows.map(s=>s.studentId)};
  const first=f.call('publishGrades',payload);
  assert.equal(f.call('publishGrades',payload).publicationId,first.publicationId);
  assert.equal(f.c.portalCall_(f.book,f.student,'getMyPublishedGrades',{classId:'c1'}).grades.quiz,0);
  f.call('saveGradebook',{classId:'c1',version:2,components:[{id:'quiz',name:'Quiz',maxScore:10}],students:rows.map(s=>({...s,grades:{quiz:9}}))});
  assert.equal(f.c.portalCall_(f.book,f.student,'getMyPublishedGrades',{classId:'c1'}).grades.quiz,0);
  f.call('revokeGrades',{classId:'c1',version:3});
  assert.equal(f.c.portalCall_(f.book,f.student,'getMyPublishedGrades',{classId:'c1'}).published,false);
});
test('mobile grade route rejects student, wrong class, non-Google provider and unrelated APIs',()=>{
  assert.throws(()=>setup('student@fpt.edu.vn').call('getGradebook'),/PERMISSION_DENIED/);
  assert.throws(()=>setup().call('getGradebook',{classId:'c2'}),/PERMISSION_DENIED/);
  assert.throws(()=>setup('teacher@fpt.edu.vn','password').call('getGradebook'),/GOOGLE_ONLY/);
  assert.throws(()=>setup().call('getMyPublishedGrades'),/UNKNOWN_PORTAL_METHOD/);
});
test('HTTP envelope permits bounded full-gradebook requests but retains global payload limit',()=>{
  const f=setup();
  const request={action:'lab2Call',idToken:'test',name:'portalCall',input:{method:'getGradebook',data:{classId:'c1'}},padding:'x'.repeat(210000)};
  assert.equal(f.c.doPost({postData:{contents:JSON.stringify(request)}}).ok,true);
  request.padding='x'.repeat(2000001);
  assert.equal(f.c.doPost({postData:{contents:JSON.stringify(request)}}).ok,false);
});
