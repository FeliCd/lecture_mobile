# Nút Gửi thông báo thử

Mobile giảng viên → **Dịch vụ đám mây** → Khu vực trình diễn Lab 3 → **Gửi thông báo thử**. Nút dùng FCM thật, không tạo local notification giả. Hiển thị loading, khóa nhấn trùng, xử lý lỗi và phân biệt FCM nhận yêu cầu với điện thoại đã nhận thông báo.

## Chạy bản demo

```powershell
cd C:\PRM\lecture_mobile
flutter run --dart-define-from-file=config/lab2.free.json --dart-define=ENABLE_LAB3_DEMO=true
```

Đăng nhập tài khoản giảng viên test và cấp quyền thông báo. Nút **Crash thử nghiệm…** có sẵn bên dưới, yêu cầu xác nhận. Nút lấy token cũ vẫn giữ để kiểm Console khi cần.

## Backend bắt buộc

Cập nhật kiểm tra sau khi người dùng nâng Blaze ngày 05/11/2026: hàm đã ACTIVE, allowlist đã cấu hình, endpoint chưa đăng nhập trả 401. App emulator đã gọi và hiển thị FCM accepted; chưa xác nhận delivery của tin mới. Lỗi 403 SERVICE_DISABLED thuộc lần kiểm tra trước, không còn hiện tại. Xem `LAB3_BLAZE_RECHECK.md` để biết phạm vi minh chứng.

Hàm mới `sendLab3DemoPush` thuộc Firebase Cloud Functions region `asia-southeast1`, không phải Apps Script. Cần project hỗ trợ triển khai Functions (billing/Blaze), Firestore mặc định hoạt động để lưu giới hạn lượt, FCM API và quyền service account gửi FCM. Không tự bật billing bằng code.

1. Lấy **Firebase UID** của tài khoản demo từ Authentication → Users.
2. Tạo/cập nhật `functions/.env.fap-attendance-88920`, thêm `LAB3_DEMO_UIDS=UID_THAT` (nhiều UID ngăn bằng dấu phẩy). Chỉ cấp tài khoản giảng viên demo tin cậy. Không dùng email thay UID.
3. Build và triển khai riêng hàm:

```powershell
cd C:\PRM\lecture_mobile\functions
npm run build
cd ..
firebase deploy --only functions:sendLab3DemoPush --project fap-attendance-88920
```

Allowlist rỗng sẽ từ chối tất cả. Hàm yêu cầu Firebase Auth và email verified, nội dung/đích màn hình cố định, giới hạn mỗi UID và token 1 lần/30 giây. Token do SDK app cung cấp; server không có bằng chứng mật mã token thuộc UID, nên endpoint chỉ dành cho allowlist demo tin cậy. Không dùng endpoint này để gửi hàng loạt hoặc thay hệ thống đăng ký thiết bị production. Payload có recipientUid để receiver trong app bỏ qua tài khoản không khớp. Không ghi token vào logs hay gửi nội dung lớp/sinh viên.

Firestore rules hiện deny collection lab3PushLimits đối với client; Admin SDK ghi server-side. Không cần mở rules. Giới hạn gửi vẫn giữ khi FCM thất bại, nên chờ 30 giây trước retry. Không tự retry khi timeout tránh gửi trùng.

## Kiểm chứng trên điện thoại

- App đang mở: bấm nút → thấy thông báo trong ứng dụng/Trung tâm thông báo.
- Để kiểm background/terminated, dùng Console gửi đến token sau khi đưa app nền/đóng; nút trong app không tự chứng minh cả ba trạng thái.
- Chạm thông báo → cấu hình qua route được cho phép.
- Tắt quyền → UI hướng dẫn bật lại; tài khoản không allowlist → permission-denied; bấm liên tiếp → không tạo request trùng, server rate limit.
- Crash: lưu dữ liệu → xác nhận crash → mở app lại → kiểm Crashlytics Console.

Source: `lib/cloud/demo_push.dart`, `lib/cloud/cloud_pages.dart`, `functions/src/demo-push.ts`. Unit tests kiểm khóa thao tác, lỗi quyền, allowlist và payload. Chưa được coi là delivery test trước khi deploy và nhận FCM trên điện thoại thật.
