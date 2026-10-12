const {test}=require('node:test');
const fs=require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,deleteDoc,serverTimestamp}=require('firebase/firestore');
for(const file of ['articles.rules','firestore.rules']) test('bookmark ownership, legacy schema, content type and delete: '+file,async()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Firestore emulator required');
  const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(':');
  const env=await initializeTestEnvironment({projectId:'demo-refactor-rules',firestore:{host,port:Number(port),rules:fs.readFileSync('firebase/'+file,'utf8')}});
  try {
    await env.clearFirestore();
    const owner=env.authenticatedContext('owner',{email_verified:true}).firestore();
    const other=env.authenticatedContext('other',{email_verified:true}).firestore();
    const unverified=env.authenticatedContext('owner',{email_verified:false}).firestore();
    const path='articleLibraries/owner/articles/a',ref=doc(owner,path);
    const legacy={title:'Source title',url:'https://example.com/a',doi:'',source:'Source',publisher:'',authors:[],publishedAt:'',subjectIds:['PRM393'],sourceSummary:'',summary:'note',savedAt:serverTimestamp(),updatedAt:serverTimestamp()};
    await assertSucceeds(setDoc(ref,legacy));
    await assertSucceeds(getDoc(ref));
    await assertFails(getDoc(doc(other,path)));
    await assertFails(getDoc(doc(unverified,path)));
    await assertFails(setDoc(doc(other,path),legacy));
    await assertSucceeds(updateDoc(ref,{contentType:'NEWS',updatedAt:serverTimestamp()}));
    await assertFails(updateDoc(ref,{contentType:'UNTRUSTED',updatedAt:serverTimestamp()}));
    await assertFails(updateDoc(ref,{role:'lecturer',updatedAt:serverTimestamp()}));
    await assertFails(deleteDoc(doc(other,path)));
    await assertSucceeds(deleteDoc(ref));
  } finally {await env.cleanup();}
});
