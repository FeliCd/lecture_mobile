# Dịch vụ đám mây — 04/11/2026

## Thay đổi local

- Trang Dịch vụ đám mây hiển thị riêng Firebase, lưu báo cáo, Analytics, Crashlytics và quyền thông báo. Chỉ báo SDK/thiết bị đã bật khi khởi tạo thành công; không suy ra dữ liệu đã tới máy chủ.
- Nút **Kiểm tra lưu báo cáo** chỉ đọc metadata một đường dẫn thuộc UID hiện tại, timeout 15 giây. Không upload báo cáo, không gửi push hoặc gây crash. Phản hồi object-not-found chỉ chứng minh dịch vụ đã trả lời, không xác nhận quyền upload.
- Remote Config giữ giá trị đã đọc khi refresh lỗi; không bật lại Cập nhật môn học chỉ vì mất mạng. Khóa các request refresh trùng nhau.
- Upload báo cáo có thông báo riêng cho thiếu bucket, thiếu quyền, hết phiên, hết quota và kết nối chậm. Đổi tài khoản hủy upload SDK; kết quả/progress từ phiên cũ không được ghi vào state mới. Kiểm UID trước khi trả download URL.
- Analytics/Crashlytics khởi tạo độc lập. Push không phụ thuộc trạng thái bật telemetry. Khu demo vẫn chỉ mở bằng ENABLE_LAB3_DEMO=true; lấy token yêu cầu quyền thông báo, không ghi token vào log.
- Đã bổ sung FIREBASE_STORAGE_BUCKET trong config/lab2.free.json theo cấu hình Student Web cùng project; chưa coi giá trị cấu hình là bằng chứng bucket tồn tại hoặc quyền Storage đã triển khai.

## Kiểm tra trước khi build

```powershell
node scripts/check-cloud-config.cjs
```

Script chỉ đọc cấu hình; kiểm file native, package Android, App ID, project number/sender ID và bucket. Không in API key/token. Có thể truyền đường dẫn config khác sau tên script.

Hiện máy thiếu `android/app/google-services.json`. Tải file chính thức của Android app `vn.edu.fpt.lecturer_companion` trong Firebase project `fap-attendance-88920`, đặt đúng đường dẫn và chạy lại preflight. Không tự tạo JSON thay cho bản tải từ Firebase. File này và config local được ignore; không commit thông tin đăng nhập hoặc keystore.

## Xác nhận cloud thật

1. Chủ project đăng nhập Firebase Console. Kiểm project/app/bucket trước khi tải file Android. Giữ nguyên project Auth/OAuth hiện tại.
2. Chạy preflight rồi build bằng `flutter run --dart-define-from-file=config/lab2.free.json`.
3. Mở Dịch vụ đám mây → Kiểm tra lại dịch vụ → Kiểm tra lưu báo cáo. Nếu chưa có quyền hoặc bucket chưa sẵn sàng, xử lý đúng thông báo; không tự mở quyền công khai hoặc bật billing.
4. Muốn kiểm chứng ghi Storage, người dùng chọn Lưu báo cáo lên Firebase trong Tổng kết tuần. Download URL chứa bearer token; không đưa vào log, ảnh công khai hoặc Analytics.
5. Mở Thông báo → cho phép nhận. Gửi một test từ Firebase Console tới đúng thiết bị/tài khoản test và kiểm foreground/background/tap. SDK nhận FCM đã có; chưa bổ sung server tự động đăng ký token/gửi theo tài khoản trong thay đổi này.
6. Remote Config: xem nguồn giá trị, giá trị đã kích hoạt và lần fetch trên thiết bị. Cache mặc định 15 phút. Analytics/Crashlytics: xác nhận trong Console; trạng thái đã bật trên thiết bị không chứng minh Console đã nhận dữ liệu.

Chưa có thiết bị kết nối và Console đang yêu cầu đăng nhập lại. Chưa upload file thật, gửi push, gây crash, publish Remote Config, đổi rules/billing hoặc deploy trong lần này.

Kiểm thử local: analyzer sạch; 270 Flutter tests toàn bộ pass trước khi thêm ca màn nhỏ/chữ lớn; sau đó cả 7 ca cloud-readiness (gồm màn 320 px, chữ 200%) pass. Backend 131 ca pass. Preflight hiện chỉ còn báo thiếu google-services.json; điều này chưa cho phép build hoặc xác nhận cloud thật.

Tài liệu chính thức: [Android getConfig](https://firebase.google.com/docs/reference/firebase-management/rest/v1beta1/projects.androidApps/getConfig), [Flutter Storage](https://firebase.google.com/docs/storage/flutter/start), [Flutter FCM](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).
