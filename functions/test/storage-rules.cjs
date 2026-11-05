const {test}=require('node:test');
const fs=require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {ref,uploadBytes,getBytes,deleteObject}=require('firebase/storage');
test('report Storage enforces owner, verified email, MIME, size and immutable uploads',async()=>{
 if(!process.env.FIREBASE_STORAGE_EMULATOR_HOST)throw Error('Storage emulator required');
 const [host,port]=process.env.FIREBASE_STORAGE_EMULATOR_HOST.split(':');
 const env=await initializeTestEnvironment({projectId:'demo-lab3-cloud',storage:{host,port:Number(port),rules:fs.readFileSync('firebase/storage.rules','utf8')}});
 try {
  const owner=env.authenticatedContext('owner',{email_verified:true}).storage();
  const other=env.authenticatedContext('other',{email_verified:true}).storage();
  const unverified=env.authenticatedContext('owner',{email_verified:false}).storage();
  const anonymous=env.unauthenticatedContext().storage();
  const image='images/owner/123.png', png={contentType:'image/png'};
  await assertSucceeds(uploadBytes(ref(owner,image),new Uint8Array([137,80,78,71]),png));
  await assertFails(getBytes(ref(other,image)));
  await assertFails(getBytes(ref(anonymous,image)));
  await assertFails(uploadBytes(ref(unverified,'images/owner/124.png'),new Uint8Array([1]),png));
  await assertFails(uploadBytes(ref(owner,'images/owner/125.png'),new Uint8Array(5*1024*1024+1),png));
  await assertFails(uploadBytes(ref(owner,'images/owner/126.png'),new Uint8Array([1]),{contentType:'text/html'}));
  const p='reports/owner/test.xlsx',meta={contentType:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'};
  await assertSucceeds(uploadBytes(ref(owner,p),new Uint8Array([1,2,3]),meta));
  await assertSucceeds(getBytes(ref(owner,p)));
  await assertFails(getBytes(ref(other,p)));
  await assertFails(getBytes(ref(anonymous,p)));
  await assertFails(uploadBytes(ref(other,'reports/owner/other.xlsx'),new Uint8Array([1]),meta));
  await assertFails(uploadBytes(ref(unverified,'reports/owner/unverified.xlsx'),new Uint8Array([1]),meta));
  await assertFails(uploadBytes(ref(owner,p),new Uint8Array([4]),meta));
  await assertFails(uploadBytes(ref(owner,'reports/owner/bad.xlsx'),new Uint8Array([1]),{contentType:'text/html'}));
  await assertFails(uploadBytes(ref(owner,'reports/owner/large.xlsx'),new Uint8Array(10*1024*1024+1),meta));
  await assertFails(deleteObject(ref(other,p)));
  await assertSucceeds(deleteObject(ref(owner,p)));
 } finally {await env.cleanup();}
});
