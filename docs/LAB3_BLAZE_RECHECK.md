# Kiểm tra sau khi nâng Blaze — 05/11/2026

## Kết luận

Cloud Functions API đã truy cập được và `sendLab3DemoPush` đã ACTIVE tại asia-southeast1. Lỗi SERVICE_DISABLED ở lần trước không còn là trạng thái hiện tại. Có cấu hình allowlist demo trên hàm live, khớp việc người dùng đã triển khai. Không thay đổi billing, IAM, rules hay deployment trong đợt kiểm tra này.

Chưa xác nhận đủ toàn bộ Lab 3. Nâng Blaze không tự triển khai luồng upload hình ảnh và ARTEMIS. Theo lựa chọn người dùng, kiểm trên emulator trước; điện thoại thật do người dùng demo sau.

## Những gì đã kiểm thực tế

| Kiểm tra | Kết quả | Giới hạn |
|---|---|---|
| Firebase CLI functions:list | sendLab3DemoPush ACTIVE, Node 22, đúng region, allowlist có giá trị | Không chứng minh điện thoại đã nhận push |
| POST callable không đăng nhập | HTTP 401 UNAUTHENTICATED | Không gửi push và không sửa dữ liệu lớp |
| https://fap-sinhvien.web.app/ | HTTP 200, Content-Type HTML | Chưa E2E toàn bộ nghiệp vụ SV |
| Cloud config preflight | Cấu hình khớp | Không tự chứng minh mọi Console service hoạt động |
| Nút Gửi thông báo thử trên emulator | UI loading rồi báo FCM đã nhận yêu cầu; thử lại sau khi người dùng đăng nhập/cấp quyền lúc khoảng 22:16 | Trung tâm thông báo vẫn trống sau lần gửi mới; chưa chứng minh delivery |
| Lịch sử thông báo | Có tin demo cũ, chạm chuyển đến Tài khoản và cài đặt | Tin cũ không tính là receipt của lần gửi mới |
| Native SDK + Remote Config | 1 integration test pass, source remote, true / 20 | Chưa demo publish giá trị khác rồi thay đổi UI/offline |
| Flutter demo controller tests | 2 pass | Kiểm chống nhấn trùng và lỗi quyền bằng fake service |
| Functions tests | 7 pass, TypeScript build pass | Bao gồm allowlist/payload; không thay live delivery |
| Live FCM integration | Lần đầu dừng tại điều kiện phiên Auth không tồn tại | Chưa gửi từ test, chưa tới assertion delivery; không kết luận transport FCM hỏng |

Log Functions cho thấy request Auth hợp lệ nhưng App Check token không hợp lệ; enforcement hiện tắt nên request vẫn được cho qua. Không bật enforce App Check khi chưa tích hợp client tương ứng. Không đưa token FCM, UID allowlist hoặc dữ liệu tài khoản vào slide.

Test mới `integration_test/lab3_push_live_test.dart` dành cho chạy live có chủ đích, yêu cầu ENABLE_LAB3_DEMO và tài khoản demo. Test đợi Auth khôi phục, đăng ký onMessage trước khi gọi hàm, kiểm recipientUid, thời điểm mới, messageId và route. Không dùng tin cũ làm bằng chứng. Cần giữ phiên đăng nhập trong bản test trước khi chạy lại; công cụ cài bản integration có thể làm mất phiên. Không gắn trạng thái PASS khi điều kiện chưa đủ.

Đã khôi phục app demo bình thường bằng flutter run --no-resident, người dùng tự đăng nhập và cấp lại quyền thông báo. Không cài lại test thêm sau đó để giữ phiên hiện tại. Analyzer cho test mới sạch. Lần bấm mới trên app được server chấp nhận nhưng lịch sử vẫn trống; chưa đủ bằng chứng để quy nguyên nhân cho backend, quyền hay đường truyền FCM của emulator. Cần tiếp tục kiểm thiết bị thật hoặc log nhận SDK trước khi kết luận.

## Đối chiếu 8 mục thầy yêu cầu

1. **Mobile trên điện thoại:** emulator chạy được; chưa kiểm điện thoại thật theo lựa chọn người dùng.
2. **Web deploy:** link hoạt động; cần demo login sinh viên và một luồng thật trước thầy.
3. **MVVM:** View → Riverpod controller → repository/service; chỉ class/file cụ thể khi trình bày. Ba luồng chính và nhánh lỗi giữ như audit trước.
4. **Image Storage:** chưa đạt. FirebaseReportStorage và rules chỉ nhận Excel. Cần UI chọn ảnh, service upload, progress/URL, rules JPEG/PNG theo UID và minh chứng ảnh trên Firebase Console.
5. **Push:** nút và backend đã có, hàm live ACTIVE, thao tác UI accepted. Còn xác nhận tin mới nhận được và các trạng thái nền/đóng/tap trên thiết bị.
6. **Crash:** có nút xác nhận crash và non-fatal; chưa gây crash hoặc xác minh Console trong lần này. Không lấy dòng UI “đã gửi nếu bật” làm bằng chứng Console đã nhận.
7. **Authentication:** emulator có phiên Google dùng được khi thao tác nút; live unauth request bị từ chối. Chưa quay lại chooser/hủy/logout/guard và Console Users trong đợt này. Rủi ro cleanup logout của audit trước chưa sửa.
8. **Testing Google:** PDF v5 nêu ARTEMIS. Chưa có ≥10 ca ×3 lần cùng actual/log và phiên khám phá 15–30 phút. Integration test Flutter mới không thay ARTEMIS.

Các yêu cầu PDF trước vẫn còn: Analytics DebugView ≥7 events; Crashlytics fatal/non-fatal UID/key; Remote Config thay đổi UI không rebuild/offline; PR review ≥5 finding/≥2 nhóm và ≥3 fix có commit; GitHub/Figma, báo cáo 8–12 trang, slide 12–15 trang, video 5–10 phút. Ảnh demo mới không nói bỏ những yêu cầu này.

## Các việc không thay đổi

Mobile/Desktop tiếp tục dành cho giảng viên, Student Web dành cho sinh viên. Backend Apps Script dùng chung không bị thay đổi. Desktop chưa có màn giao việc như Mobile; Web tải lại để nhận plan mới sau Sheets; đây là giới hạn đã ghi audit trước. Không sửa điểm danh, điểm, nhóm hay gửi thông báo tới sinh viên trong lần này.

## Kịch bản trình bày 8–10 phút

- 0:00–1:00: hệ thống ba client, vai trò và kiến trúc MVVM; mở file controller/service.
- 1:00–2:00: Google Authentication; token/UID và quyền backend khác nhau.
- 2:00–3:00: Storage, đường dẫn theo UID, progress và rules. Nói rõ hiện Excel; chỉ demo ảnh khi chức năng đã hoàn thiện.
- 3:00–4:30: nút FCM → callable → Admin SDK → thiết bị. Chỉ xác nhận nhận khi có tin mới, không dùng accepted thay receipt.
- 4:30–5:30: Crashlytics; nút non-fatal/fatal và Console nếu đã chuẩn bị.
- 5:30–6:30: Analytics và Remote Config; sự kiện, fetch/activate, cache/default.
- 6:30–7:30: web deploy và chức năng sinh viên; chat fixture trên slide chỉ minh họa.
- 7:30–9:00: kết quả test, ARTEMIS còn thiếu, tổng kết và câu hỏi.

## Nhật ký riêng

`tmp/lab3-blaze-functions.log`, `tmp/blaze-function-logs.log`, `tmp/blaze-push-live.log`, `tmp/blaze-config.log`, `tmp/blaze-push-tests.log`, `tmp/blaze-functions-tests.log`, `tmp/blaze-native-smoke.log`, `tmp/blaze-push-live-test.log`, `tmp/blaze-restore-app.log`. Logs riêng có thể có thông tin tài khoản, không đưa nguyên văn vào deck công khai.
