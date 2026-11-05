const {test}=require('node:test');
const assert=require('node:assert/strict');
const {demoPushAllowed,demoPushMessage}=require('../lib/demo-push-policy');
test('demo is closed by default and requires verified allowlisted account',()=>{
  assert.equal(demoPushAllowed('a',true,''),false);
  assert.equal(demoPushAllowed('a',false,'a'),false);
  assert.equal(demoPushAllowed('b',true,'a'),false);
  assert.equal(demoPushAllowed('a',true,' a, b '),true);
});
test('fixed demo content carries recipient guard and allowed destination',()=>{
  const m=demoPushMessage('uid','token');
  assert.deepEqual(m.data,{screen:'settings',recipientUid:'uid'});
  assert.equal(m.android.ttl,60000);
  for(const token of ['', 'bad token','x'.repeat(4097)]) assert.throws(()=>demoPushMessage('uid',token));
});
