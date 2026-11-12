/* Owner-only editor functions. No migration action is exposed by doPost. */
function inspectSharedDatabaseMigration() {
  if(sharedMode_()!=='sheets') throw Error('SOURCE_IS_NOT_ACTIVE');
  const source=SpreadsheetApp.openById(config_().id);
  const tables=Object.fromEntries(firestoreMigrationTables_(source).map(table=>[table,migrationRows_(source,table).length]));
  const project=firestoreMigrationProject_();
  const book=firestoreBook_(project,'dataset-'+Utilities.getUuid());
  book.request('/'+SHARED_TABLE_ROOT+'?pageSize=1');
  const result={tables,project,firestoreReadable:true};
  console.log(JSON.stringify(result));
  return result;
}

function firestoreMigrationProject_() {
  const properties=PropertiesService.getScriptProperties();
  return properties.getProperty('SHARED_FIRESTORE_PROJECT')||properties.getProperty('LAB2_FIREBASE_PROJECT_ID')||'fap-attendance-88920';
}

function firestoreMigrationTables_(source) {
  const tables=Object.keys({...SCHEMA,...LAB2_TABLES});
  const unknown=source.getSheets().filter(sheet=>!tables.includes(sheet.getName())&&sheet.getLastRow()>0);
  if(unknown.length) throw Error('UNMAPPED_SOURCE_TABS: '+unknown.map(sheet=>sheet.getName()).join(', '));
  return tables;
}

function migrationRows_(source,table) {
  if(!source.getSheetByName(table)) {
    // Earlier releases do not register chat push devices.
    if(table==='PortalGroupPushDevices') return [];
    throw Error('MISSING_SOURCE_TABLE_'+table);
  }
  try {
    // Preserve exactly what the active backend reads, including legacy date formatting
    // and the existing recovery policy for the two rebuildable news caches.
    return ['Lab2Feeds','Lab2ArticleCache'].includes(table)?lab2ReadNewsCache_(source,table):lab2Read_(source,table);
  } catch(_) {
    throw Error('INVALID_SOURCE_TABLE_'+table);
  }
}

function migrationFingerprint_(rows) {
  return {count:rows.length,hash:lab2Hash_(JSON.stringify(rows))};
}

function verifyMigrationDeployment_(properties) {
  const url=properties.getProperty('SHARED_API_EXEC_URL')||ScriptApp.getService().getUrl();
  if(!/^https:\/\/script\.google\.com\/macros\/s\/[\w-]+\/exec$/.test(url||'')) throw Error('SHARED_EXEC_URL_REQUIRED');
  try {
    const response=UrlFetchApp.fetch(url,{method:'post',contentType:'application/json',
      payload:JSON.stringify({action:'lab2Health'}),muteHttpExceptions:true});
    if(response.getResponseCode()===200) {
      const health=JSON.parse(response.getContentText());
      if(health.ok===true&&health.data?.database==='sheets'&&health.data.firestoreMigrationVersion===1) return;
    }
  } catch(_) {
    // The error below avoids exposing deployment redirect URLs.
  }
  throw Error('SHARED_EXEC_DEPLOYMENT_NOT_READY');
}

/** Install the compatible backend version on the shared /exec URL before running. */
function migrateSharedDatabaseToFirestore() {
  const lock=LockService.getScriptLock();
  if(!lock.tryLock(15000)) throw Error('LOCK_BUSY');
  try {
    if(sharedMode_()==='firestore') return {database:'firestore',alreadyActive:true};
    if(sharedMode_()!=='sheets') throw Error('SOURCE_IS_NOT_ACTIVE');
    const properties=PropertiesService.getScriptProperties();
    verifyMigrationDeployment_(properties);
    const project=firestoreMigrationProject_();
    const dataset='dataset-'+Utilities.getUuid();
    const book=firestoreBook_(project,dataset);
    const source=SpreadsheetApp.openById(config_().id);
    const tables=firestoreMigrationTables_(source);
    const start=Date.now();
    const checkTime=()=>{
      if(Date.now()-start>240000) throw Error('MIGRATION_TIME_LIMIT');
    };
    // Validate all source tables before storing the first row.
    const sourceRows=new Map();
    for(const table of tables) {
      checkTime();
      sourceRows.set(table,migrationRows_(source,table));
    }
    const verified={};
    for(const table of tables) {
      checkTime();
      const rows=sourceRows.get(table);
      sourceRows.delete(table);
      const expected=migrationFingerprint_(rows);
      // Small chunks stay below the REST request limit even for wide legacy rows.
      for(let offset=0;offset<rows.length;) {
        checkTime();
        const changes=[];
        let size=0;
        while(offset<rows.length&&changes.length<200) {
          const row=rows[offset], estimate=JSON.stringify(row).length*3+1024;
          if(changes.length&&size+estimate>4*1024*1024) break;
          changes.push({table,row,position:'0'+String(offset).padStart(12,'0')});
          size+=estimate;
          offset++;
        }
        firestoreWrite_(book,changes,true);
      }
      const actual=migrationFingerprint_(firestoreRows_(book,table));
      if(JSON.stringify(actual)!==JSON.stringify(expected)) throw Error('MIGRATION_VERIFICATION_FAILED_'+table);
      book.cache.clear();
      verified[table]=actual;
    }
    // Direct spreadsheet edits bypass Apps Script's lock. Check the source again
    // before switching. Keep the workbook closed to direct edits during cutover.
    for(const table of tables) {
      checkTime();
      if(JSON.stringify(migrationFingerprint_(migrationRows_(source,table)))!==JSON.stringify(verified[table]))
        throw Error('MIGRATION_SOURCE_CHANGED_'+table);
    }
    const fields={state:{stringValue:'ready'},sequence:{integerValue:'0'},verifiedAt:{stringValue:new Date().toISOString()},
      counts:{mapValue:{fields:Object.fromEntries(tables.map(table=>[table,{integerValue:String(verified[table].count)}]))}}};
    book.request(':commit',{writes:[{update:{name:book.database+'/'+book.root,fields},currentDocument:{exists:false}}]});
    // Write the target first. The mode property is the final switch.
    properties.setProperties({SHARED_FIRESTORE_PROJECT:project,SHARED_FIRESTORE_DATASET:dataset});
    properties.setProperty('SHARED_DATABASE_MODE','firestore');
    const counts=Object.fromEntries(tables.map(table=>[table,verified[table].count]));
    console.log(JSON.stringify({database:'firestore',counts}));
    return {database:'firestore',counts};
  } finally {
    lock.releaseLock();
  }
}
