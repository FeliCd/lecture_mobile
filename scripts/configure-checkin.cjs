// Generate public Firebase web config from the same config used to build mobile.
const fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '..');
const config = JSON.parse(fs.readFileSync(path.join(root, 'config/lab2.free.json'), 'utf8'));
if (!config.FIREBASE_PROJECT_ID || !config.FIREBASE_API_KEY) {
  throw new Error('Missing Firebase config in config/lab2.free.json.');
}
const web = {
  firebaseApiUrl: config.FIREBASE_SHARED_API_URL || 'https://asia-southeast1-' + config.FIREBASE_PROJECT_ID + '.cloudfunctions.net/sharedApi',
  firebase: {
    apiKey: config.FIREBASE_API_KEY,
    authDomain: `${config.FIREBASE_PROJECT_ID}.firebaseapp.com`,
    projectId: config.FIREBASE_PROJECT_ID,
    appId: config.FIREBASE_APP_ID,
    messagingSenderId: config.FIREBASE_MESSAGING_SENDER_ID,
  },
};
fs.writeFileSync(path.join(root, 'web_checkin/public/config.js'),
  'window.FAP_CONFIG = Object.freeze(' + JSON.stringify(web, null, 2) + ');\n');
console.log('Configured check-in portal for ' + config.FIREBASE_PROJECT_ID);
