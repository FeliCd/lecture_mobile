const {test}=require('node:test');
const assert=require('node:assert/strict');
const {validateCloudConfig}=require('../../scripts/check-cloud-config.cjs');
const config={FIREBASE_PROJECT_ID:'test-project',FIREBASE_API_KEY:'test-public-key',FIREBASE_APP_ID:'android-app',FIREBASE_MESSAGING_SENDER_ID:'123',FIREBASE_STORAGE_BUCKET:'test-project.firebasestorage.app'};
const native={project_info:{project_id:'test-project',project_number:'123',storage_bucket:config.FIREBASE_STORAGE_BUCKET},client:[{client_info:{mobilesdk_app_id:'android-app',android_client_info:{package_name:'vn.edu.fpt.lecturer_companion'}}}]};
test('preflight requires native config and bucket, never reveals values',()=>{
  const errors=validateCloudConfig({...config,FIREBASE_STORAGE_BUCKET:''},null);
  assert.ok(errors.some(e=>e.includes('google-services.json')));assert.ok(errors.some(e=>e.includes('FIREBASE_STORAGE_BUCKET')));
  assert.ok(!errors.join().includes('test-public-key'));
});
test('preflight rejects mismatched project, sender, package, app and bucket',()=>{
  assert.deepEqual(validateCloudConfig(config,native),[]);
  for(const extra of [{FIREBASE_PROJECT_ID:'wrong'},{FIREBASE_APP_ID:'wrong'},{FIREBASE_MESSAGING_SENDER_ID:'456'},{FIREBASE_STORAGE_BUCKET:'wrong'}])assert.ok(validateCloudConfig({...config,...extra},native).length);
  assert.ok(validateCloudConfig(config,{...native,client:[]}).length);
});
