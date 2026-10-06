/** Run manually once as the backend owner. Never routed from doPost. */
function setupNewMobileBackend() {
  const p = PropertiesService.getScriptProperties();
  const webClient = '391831771866-i4vajc479qjuiflghp7ur325383nah5n.apps.googleusercontent.com';
  const lock = LockService.getScriptLock();
  lock.waitLock(15000);
  try {
    if (!p.getProperty('SPREADSHEET_ID')) {
      const book = SpreadsheetApp.create('FPT Lecturer Mobile - Data');
      p.setProperty('SPREADSHEET_ID', book.getId());
    }
    if (!p.getProperty('GOOGLE_CLIENT_ID')) p.setProperty('GOOGLE_CLIENT_ID', webClient);
    p.setProperty('GOOGLE_MOBILE_CLIENT_ID', webClient);
    if (!p.getProperty('SCHOOL_DOMAINS')) p.setProperty('SCHOOL_DOMAINS', 'fpt.edu.vn,fe.edu.vn');
    setupSheets();
    console.log('Backend ready. Data spreadsheet: https://docs.google.com/spreadsheets/d/' + p.getProperty('SPREADSHEET_ID') + '/edit');
    console.log('Lecturers must be registered by the administrator before they can sign in. No lecturer was added automatically.');
  } finally {
    lock.releaseLock();
  }
}
