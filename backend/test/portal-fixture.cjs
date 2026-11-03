const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

function fixture(now) {
  let clock=now==null?null:Date.parse(now);
  class ServerDate extends Date {constructor(...args){super(...(args.length?args:[clock==null?Date.now():clock]));} static now(){return clock==null?Date.now():clock;} }
  const c = vm.createContext({Date:ServerDate, console});
  const desktop = path.resolve(__dirname, '../apps_script/Code.gs');
  vm.runInContext(fs.readFileSync(desktop,'utf8'),c);
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../apps_script/Lab2Free.gs'),'utf8'),c);
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../apps_script/AttendanceSafety.gs'),'utf8'),c);
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../apps_script/SubjectInsights.gs'),'utf8'),c);
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../apps_script/ClassTools.gs'),'utf8'),c);
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../apps_script/ScheduleAttendance.gs'),'utf8'),c);
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../apps_script/StudentPortal.gs'),'utf8'),c);
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../apps_script/StudyGroups.gs'),'utf8'),c);
  const schemas = vm.runInContext('({...SCHEMA,...LAB2_TABLES})',c);
  const store = Object.fromEntries(Object.entries(schemas).map(([k,v])=>[k,[Array.from(v)]]));
  const add = (table,row) => store[table].push(Array.from(schemas[table],k=>String(row[k]??'')));
  add('Lecturers',{lecturerId:'l1',fullName:'Teacher',email:'teacher@fpt.edu.vn'});
  add('Lecturers',{lecturerId:'l2',email:'other@fpt.edu.vn'});
  add('Students',{studentId:'s1',studentCode:'SE1',fullName:'Student',schoolEmail:'student@fpt.edu.vn'});
  add('Students',{studentId:'s2',studentCode:'SE2',fullName:'Other',schoolEmail:'other-student@fpt.edu.vn'});
  add('Classes',{classId:'c1',lecturerId:'l1',classCode:'SE1',subjectCode:'PRM393',subjectName:'Mobile'});
  add('Classes',{classId:'c2',lecturerId:'l2',classCode:'SE2',subjectCode:'PRN212'});
  add('Enrollments',{enrollmentId:'e1',classId:'c1',studentId:'s1'});
  add('Enrollments',{enrollmentId:'e2',classId:'c1',studentId:'s2'});
  const sheetNames = Object.keys(store);
  const sheet = name => ({getDataRange:()=>({getDisplayValues:()=>store[name].map(r=>r.slice())}),
    getRange:()=>({setValues:values=>{store[name]=values.map(r=>r.slice());}}),setFrozenRows(){},
    getLastRow:()=>store[name].length,getMaxRows:()=>1000,getSheetId:()=>sheetNames.indexOf(name)});
  const book = {getId:()=> 'book',getSheetByName:name=>store[name]?sheet(name):null,
    insertSheet:name=>{store[name]=[];if(!sheetNames.includes(name))sheetNames.push(name);return sheet(name);}};
  const props = {SPREADSHEET_ID:'book',GOOGLE_CLIENT_ID:'desktop',LAB2_FIREBASE_API_KEY:'public-test-key'};
  c.PropertiesService = {getScriptProperties:()=>({getProperty:k=>props[k]??null})};
  c.SpreadsheetApp = {openById:()=>book};
  c.LockService = {getScriptLock:()=>({tryLock:()=>true,releaseLock(){}})};
  const cache = new Map();
  c.CacheService = {getScriptCache:()=>({get:k=>cache.get(k)||null,put:(k,v)=>cache.set(k,v)})};
  c.Utilities = {getUuid:()=>crypto.randomUUID(),formatDate:instant=>new Date(instant.getTime()+7*3600000).toISOString().slice(0,10),
    DigestAlgorithm:{SHA_256:'sha256'},computeDigest:(_,s)=>Array.from(crypto.createHash('sha256').update(s).digest()),
    base64DecodeWebSafe:s=>Buffer.from(s,'base64url'),newBlob:b=>({getDataAsString:()=>b.toString()})};
  let writes = 0;
  c.Sheets = {Spreadsheets:{batchUpdate:({requests})=>{
    writes++;
    for(const req of requests) if(req.updateCells) {
      const u=req.updateCells, name=sheetNames[u.range.sheetId];
      store[name][u.range.startRowIndex]=u.rows[0].values.map(v=>v.userEnteredValue.stringValue);
    }
  }}};
  c.ContentService = {MimeType:{JSON:'json'},createTextOutput:text=>({setMimeType:()=>JSON.parse(text)})};
  const teacher=c.lab2Actor_({email:'teacher@fpt.edu.vn',firebaseUid:'firebase-teacher'},c.config_(),book);
  const student=c.lab2Actor_({email:'student@fpt.edu.vn',firebaseUid:'firebase-student'},c.config_(),book);
  return {c,book,store,props,add,teacher,student,cache,setNow:value=>{clock=Date.parse(value);},writes:()=>writes};
}
module.exports = {fixture};
