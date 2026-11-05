import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {defineString} from 'firebase-functions/params';
import {getFirestore} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {createHash} from 'node:crypto';
import {demoPushAllowed, demoPushMessage} from './demo-push-policy';

const demoUids = defineString('LAB3_DEMO_UIDS', {default: ''});
// Separate from attendance: no class data or student messages are changed.
export const sendLab3DemoPush = onCall({region:'asia-southeast1', maxInstances:2}, async r => {
  if (!r.auth) throw new HttpsError('unauthenticated', 'Đăng nhập trước khi gửi thử.');
  if (!demoPushAllowed(r.auth.uid, r.auth.token.email_verified === true, demoUids.value())) {
    throw new HttpsError('permission-denied', 'Tài khoản chưa được cấp quyền demo.');
  }
  const token = r.data?.token;
  const delaySeconds = r.data?.delaySeconds ?? 0;
  if (![0,15].includes(delaySeconds)) throw new HttpsError('invalid-argument','Invalid delay');
  if (typeof token !== 'string') throw new HttpsError('invalid-argument', 'Thiếu token thiết bị.');
  let message;
  try { message = demoPushMessage(r.auth.uid, token); }
  catch { throw new HttpsError('invalid-argument', 'Token thiết bị không hợp lệ.'); }
  const db=getFirestore();
  // Limit both the caller and target token, across concurrent requests/instances.
  const refs=[db.doc(`lab3PushLimits/u_${r.auth.uid}`),db.doc(`lab3PushLimits/t_${createHash('sha256').update(token).digest('hex')}`)];
  await db.runTransaction(async tx => {
    const snapshots=await Promise.all(refs.map(ref=>tx.get(ref)));
    const now=Date.now();
    if(snapshots.some(s=>now-Number(s.data()?.at ?? 0)<30000)) {
      throw new HttpsError('resource-exhausted','Chờ 30 giây trước khi gửi lại.');
    }
    refs.forEach(ref=>tx.set(ref,{at:now}));
  });
  try {
    if (delaySeconds) await new Promise(resolve => setTimeout(resolve, delaySeconds * 1000));
    await getMessaging().send(message);
    return {accepted:true}; // FCM acceptance is not a delivery receipt.
  } catch {
    throw new HttpsError('unavailable','FCM chưa nhận yêu cầu. Kiểm tra cấu hình và thử lại sau 30 giây.');
  }
});
