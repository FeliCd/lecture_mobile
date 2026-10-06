const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../apps_script/Code.gs'), 'utf8');

function fixture(overrides = {}, rows = [['l1', 'GV1', 'Teacher', 'teacher@fpt.edu.vn', 'IT']], status = 200) {
  const claims = {aud: 'mobile-web', iss: 'https://accounts.google.com', exp: Date.now() / 1000 + 3600, email_verified: true, email: 'teacher@fpt.edu.vn', ...overrides};
  const context = vm.createContext({UrlFetchApp: {fetch: () => ({getResponseCode: () => status, getContentText: () => JSON.stringify(claims)})}});
  vm.runInContext(source, context);
  const cfg = {audience: 'desktop', mobileAudience: 'mobile-web', domains: ['fpt.edu.vn', 'fe.edu.vn']};
  const book = {getSheetByName: () => ({getDataRange: () => ({getDisplayValues: () => [['lecturerId', 'lecturerCode', 'fullName', 'email', 'department'], ...rows]})})};
  return () => context.authenticate_('mock-google-token-for-unit-tests', cfg, book);
}

test('registered lecturer accepted for mobile and existing desktop audiences', () => {
  assert.equal(fixture()().lecturerId, 'l1');
  assert.equal(fixture({aud: 'desktop'})().lecturerId, 'l1');
});
test('Google rejected credential never grants access', () => {
  assert.throws(fixture({}, undefined, 400), /Phiên Google/);
});
for (const [name, claims] of [
  ['wrong audience', {aud: 'other-project'}],
  ['expired token', {exp: 1}],
  ['missing expiry', {exp: undefined}],
  ['invalid issuer', {iss: 'https://attacker.invalid'}],
  ['unverified email', {email_verified: false}],
  ['developer Gmail', {email: 'phucvhla2@gmail.com'}],
  ['domain spoof', {email: 'teacher@fpt.edu.vn.attacker.invalid'}],
]) {
  test(`reject ${name}`, () => assert.throws(fixture(claims), /không được phép/));
}
test('verified school email still needs one registered lecturer record', () => {
  assert.throws(fixture({}, []), /Lecturers/);
  assert.throws(fixture({}, [['l1', 'GV1', 'One', 'teacher@fpt.edu.vn', 'IT'], ['l2', 'GV2', 'Two', 'teacher@fpt.edu.vn', 'IT']]), /Lecturers/);
});
