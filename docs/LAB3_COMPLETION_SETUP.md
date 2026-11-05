# Bổ sung Image Storage, FCM nền/đóng, ARTEMIS và Console

## Đã thêm và kiểm tra

- Mobile → Dịch vụ đám mây → Khu vực trình diễn Lab 3: **Chọn và upload ảnh** PNG/JPEG, giới hạn 5 MB, đọc stream có giới hạn, preview, progress, đường dẫn và URL sau thành công. Service kiểm header PNG/JPEG; rules kiểm UID/email verified, MIME/kích thước và không cho ghi đè. Rules không kiểm bytes nội dung ảnh; không coi MIME là chứng minh toàn bộ tệp hợp lệ.
- View gọi `imageUploadProvider`, controller gọi service Storage; không gọi Firebase SDK từ widget. Ảnh đi vào `images/{uid}/{timestamp}.png|jpg`, không thay báo cáo Excel hay tệp chat Drive.
- Nút **Gửi sau 15 giây · thử nền/đóng** gọi backend delay 15 giây. Backend đã deploy. Client timeout 45 giây, server giữ giới hạn UID/token 30 giây và allowlist. Dùng demo ít lượt; request chờ cũng tính thời gian chạy Functions.
- Flutter analyzer sạch; APK debug có ENABLE_LAB3_DEMO đã build. Ba test controller và bảy test Functions pass. Storage emulator pass với test ảnh và báo cáo, owner/other/anonymous/unverified/MIME/size.
- Google ARTEMIS checkout 351ca84 đã cài tại C:/PRM/tools/artemis. CLI --help và doctor chạy được. Có cases/runner trong testing/artemis.

## Chưa hoàn tất cloud và bằng chứng

Ban đầu deploy rules bị chặn vì chưa có bucket. Sau khi người dùng tạo bucket, **rules đã deploy thành công**. Đã upload ảnh mẫu PNG 667 bytes từ app, UI hiển thị success/path/URL, Storage API xác nhận một object image/png. Bucket khớp cấu hình. Các bước tạo bucket sau chỉ là tham khảo: vào https://console.firebase.google.com/project/fap-attendance-88920/storage → Get started để tạo bucket. Không coi nâng Blaze/bật API là đã có bucket. Sau khi tạo, chạy:

```powershell
firebase deploy --only storage --config firebase.cloud.emulators.json --project fap-attendance-88920
```

Bucket phải khớp FIREBASE_STORAGE_BUCKET trong config. Nếu Console tạo tên khác, cập nhật cấu hình từ Firebase thực tế rồi build lại; không tự đoán tên bucket. Chọn một ảnh mẫu không có dữ liệu cá nhân, upload rồi đối chiếu đường dẫn trong Console.

ARTEMIS đã chạy một session thử, nhưng provider trả 503 quá tải rồi 429 RESOURCE_EXHAUSTED (free-tier request limit). Đã dừng task retry và lưu logs vào tmp/artemis-first*.json/log. **Không có PASS ARTEMIS**. Key lưu trong .env local ngoài repository; không đưa vào slide. Chờ quota khả dụng hoặc cấu hình model/quota phù hợp rồi chạy 10 ca ×3 và đối chiếu actual, thêm nhánh lỗi và khám phá 15–30 phút. Runner không tự biến exit 0 thành PASS.

## Demo FCM nền và đóng

1. Đăng nhập tài khoản demo allowlisted và cho phép notifications.
2. Bấm gửi trễ 15 giây, về Android Home ngay; chờ notification tray. Chạm tin → Settings. Ghi giờ gửi/nhận và video.
3. Chờ cooldown ít nhất 30 giây; gửi trễ lần nữa, vuốt app khỏi Recent, chờ rồi chạm push để cold start. **Không Force stop**: Android có thể chặn app nhận push cho tới khi người dùng mở lại.
4. Đối chiếu Trung tâm thông báo theo đúng UID và tin mới. Accepted chưa là delivery. Trong đợt kiểm trước, emulator accepted nhưng chưa thấy tin mới; chưa khẳng định lỗi đó đã hết chỉ nhờ thêm delay.
5. Chụp/video ba trạng thái foreground/background/closed; không đưa token FCM lên hồ sơ chia sẻ. Nếu emulator không nhận, thử điện thoại có Google Play services trước khi chốt nguyên nhân.

## Firebase Console cần mở và thu minh chứng

| Dịch vụ | Link | Minh chứng |
|---|---|---|
| Authentication | https://console.firebase.google.com/project/fap-attendance-88920/authentication/users | User test và login/hủy/logout/guard |
| Storage | https://console.firebase.google.com/project/fap-attendance-88920/storage | Ảnh thật, đường dẫn theo UID, progress/URL, denied/offline |
| Functions | https://console.firebase.google.com/project/fap-attendance-88920/functions | Hàm sendLab3DemoPush ACTIVE và log gọi; che identifiers |
| Messaging | https://console.firebase.google.com/project/fap-attendance-88920/notification | Push 3 trạng thái và tap route; địa chỉ Console có thể redirect |
| Analytics | https://console.firebase.google.com/project/fap-attendance-88920/analytics | DebugView ≥7 events/parameters, UID, không PII |
| Crashlytics | https://console.firebase.google.com/project/fap-attendance-88920/crashlytics | Fatal/non-fatal, stack trace, UID/custom key sau mở lại |
| Remote Config | https://console.firebase.google.com/project/fap-attendance-88920/config | Publish thay giá trị → UI đổi không rebuild; cache/offline |

Console là công cụ quản trị hiện có của Firebase, không phải package cần tích hợp thêm vào app. Mỗi ảnh/video phải ghi ngày, build và thao tác thực tế; không dùng ảnh UI fixture hoặc status “đã bật” để khẳng định Console đã nhận dữ liệu.

Mobile/Desktop là giảng viên, Web là sinh viên; thay đổi demo chỉ cho Mobile Android. Không gửi tới sinh viên, không sửa dữ liệu điểm danh/nhóm/điểm.

Khi gửi trễ lần thử trên emulator, app xuất hiện banner “Có thông báo mới trong trung tâm thông báo”. Đây là quan sát nhận ở foreground; chưa ghi đầy đủ video/background/closed/tap. Trong lúc thử, cửa sổ emulator bị thay đổi vị trí/kích thước nên chưa hoàn tất hai trạng thái còn lại. Không gán PASS background/terminated từ banner foreground.
