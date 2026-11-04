// Read-only preflight. Never prints API keys, tokens or full config contents.
const fs = require('node:fs');
const path = require('node:path');

function validateCloudConfig(config, native) {
  const issues = [];
  if (String(config.USE_EMULATORS) === 'true') issues.push('Cloud thật đang tắt: USE_EMULATORS=true.');
  for (const key of ['FIREBASE_PROJECT_ID', 'FIREBASE_API_KEY', 'FIREBASE_APP_ID', 'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_STORAGE_BUCKET']) {
    if (typeof config[key] !== 'string' || !config[key].trim()) issues.push(`Thiếu ${key}.`);
  }
  if (!native) issues.push('Thiếu android/app/google-services.json. Tải file chính thức từ Firebase Console cho app vn.edu.fpt.lecturer_companion.');
  else {
    const project = native.project_info || {};
    if (project.project_id !== config.FIREBASE_PROJECT_ID) issues.push('Project trong google-services.json khác cấu hình Dart.');
    if (String(project.project_number) !== String(config.FIREBASE_MESSAGING_SENDER_ID)) issues.push('Sender ID khác project number trong google-services.json.');
    if (project.storage_bucket && project.storage_bucket !== config.FIREBASE_STORAGE_BUCKET) issues.push('Storage bucket khác file cấu hình Firebase chính thức.');
    const client = (native.client || []).find(c => c.client_info?.android_client_info?.package_name === 'vn.edu.fpt.lecturer_companion');
    if (!client) issues.push('google-services.json không chứa đúng package Android.');
    else if (client.client_info?.mobilesdk_app_id !== config.FIREBASE_APP_ID) issues.push('Android App ID khác cấu hình Dart.');
  }
  return issues;
}

if (require.main === module) {
  const root = path.resolve(__dirname, '..');
  try {
    const config = JSON.parse(fs.readFileSync(path.resolve(root, process.argv[2] || 'config/lab2.free.json'), 'utf8').replace(/^\uFEFF/, ''));
    const nativePath = path.join(root, 'android/app/google-services.json');
    const native = fs.existsSync(nativePath) ? JSON.parse(fs.readFileSync(nativePath, 'utf8')) : null;
    const issues = validateCloudConfig(config, native);
    console.log(`Cloud preflight: ${issues.length ? 'CHƯA ĐỦ CẤU HÌNH' : 'CẤU HÌNH KHỚP'}`);
    for (const issue of issues) console.log('- ' + issue);
    if (!issues.length) console.log('Chưa xác minh bucket tồn tại, quyền Storage, FCM hoặc dữ liệu Analytics/Crashlytics trên cloud.');
    process.exitCode = issues.length ? 1 : 0;
  } catch (_) {
    console.error('Chưa đọc được cấu hình JSON. Kiểm tra file local; không dán API key hoặc token vào log.');
    process.exitCode = 1;
  }
}
module.exports = { validateCloudConfig };
