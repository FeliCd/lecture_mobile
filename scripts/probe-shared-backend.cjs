const assert = require('node:assert/strict');
const endpoint = 'https://asia-southeast1-fap-attendance-88920.cloudfunctions.net/sharedApi';
const student = 'https://fap-sinhvien.web.app/';
const checkin = 'https://fap-attendance-88920.web.app/';
async function get(url, options = {}) {
  const response = await fetch(url, { signal: AbortSignal.timeout(30000), ...options });
  assert.ok(response.ok, 'Unexpected HTTP ' + response.status);
  return response;
}
const call = (action, origin) => get(endpoint, {
  method: 'POST', headers: { 'Content-Type': 'application/json', Origin: origin },
  body: JSON.stringify({ action }),
});
(async () => {
  const health = await (await call('lab2Health', student)).json();
  assert.equal(health.ok, true);
  assert.equal(health.data.version, 'shared-firebase-v1');
  assert.equal(health.data.database, 'firestore');
  assert.equal(health.data.writesEnabled, true);
  assert.equal(health.data.openAlexConfigured, true);
  const anonymous = await (await call('lab2Snapshot', student)).json();
  assert.equal(anonymous.error, 'UNAUTHENTICATED');
  const html = await (await get(student)).text();
  const bundle = html.match(/src="([^"]*assets\/index-[^"]+\.js)"/)?.[1];
  assert.ok(bundle, 'Student bundle URL missing');
  const code = await (await get(new URL(bundle, student))).text();
  assert.ok(code.includes(endpoint) && code.includes('sharedGroupSignup'));
  assert.ok(!code.includes('script.google.com'));
  const qr = await (await get(new URL('checkin', checkin))).text();
  assert.ok(qr.includes('checkin.js'));
  const [qrConfig, qrCode] = await Promise.all(['config.js', 'checkin.js'].map(async (name) =>
    (await get(new URL(name, checkin))).text()));
  assert.ok(qrConfig.includes(endpoint) && qrCode.includes('firebaseApiUrl'));
  assert.ok(!qrConfig.includes('script.google.com'));
  for (const origin of [student, checkin]) {
    const cors = await get(endpoint, {
      method: 'OPTIONS',
      headers: { Origin: new URL(origin).origin, 'Access-Control-Request-Method': 'POST',
        'Access-Control-Request-Headers': 'authorization,content-type' },
    });
    assert.ok(cors.headers.get('Access-Control-Allow-Origin'));
    assert.match(cors.headers.get('Access-Control-Allow-Headers'), /authorization/i);
  }
  console.log(JSON.stringify({ firebaseWriter: true, openAlexConfigured: true,
    unauthenticatedAccessDenied: true, studentHosting: 'verified', qrHosting: 'verified' }));
})().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
