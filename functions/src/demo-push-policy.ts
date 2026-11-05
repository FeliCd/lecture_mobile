export function demoPushAllowed(uid: string, verified: boolean, allowlist: string): boolean {
  return verified && allowlist.split(',').map(s => s.trim()).filter(Boolean).includes(uid);
}
export function demoPushMessage(uid: string, token: string) {
  if (!token || token.length > 4096 || /\s/.test(token)) throw new Error('INVALID_TOKEN');
  return {
    token,
    notification: {title: 'Thông báo thử Lab 3', body: 'FCM đã chuyển thông báo tới thiết bị. Chạm để mở cấu hình.'},
    data: {screen: 'settings', recipientUid: uid},
    android: {priority: 'high' as const, ttl: 60000},
  };
}
