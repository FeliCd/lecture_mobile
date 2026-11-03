# Đối chiếu mức sẵn sàng Lab 3 - 02/11/2026

Ghi chú sau đánh giá: source đã được bổ sung Firebase Lab 3 và nhóm học tập trong cùng ngày. Các nhận định thiếu SDK bên dưới mô tả **thời điểm trước triển khai**, không phải trạng thái source mới. Xem [bàn giao cập nhật](LAB3_GROUPS_IMPLEMENTATION.md); cloud evidence và ARTEMIS vẫn cần thực hiện thật.

## Kết luận và phạm vi

**Chưa đáp ứng đầy đủ hướng dẫn Lab 3.** Mobile có nền nghiệp vụ phong phú và Firebase Authentication; chưa thấy source tích hợp năm dịch vụ bắt buộc còn lại. Không suy ra điểm số vì PDF không cung cấp trọng số chấm.

Nguồn yêu cầu: `C:/Users/ontri/Downloads/PRM393_Lab3_Preparation_Guide_v5_ToiUu.pdf`, đọc đủ 25 trang. Đối tượng kiểm tra chính: `C:/PRM/lecture_mobile`, entry `lib/main.dart` -> `lib/lab2/app.dart`. Desktop và Student Web là hệ thống hỗ trợ; triển khai Firebase Hosting cho web không thay thế tích hợp Firebase trên Flutter Android.

Đây là kiểm tra source và kiểm thử cục bộ. Chưa kiểm Firebase Console, quyền billing, tài liệu ngoài repo, PR trên GitHub, video cá nhân hoặc chạy E2E tài khoản thật trong lần đánh giá này. “Chưa thấy” không đồng nghĩa tài liệu không tồn tại ở nơi khác.

## Ma trận sáu dịch vụ Firebase

| Tiêu chí trong PDF | Bằng chứng hiện có | Khoảng trống để nghiệm thu |
|---|---|---|
| Authentication, trang 5-7 | `main.dart` khởi tạo Firebase; `lab2/repository.dart` theo dõi authStateChanges, Google credential, logout; `lab2/app.dart` chặn route khi chưa có lecturer profile. Logout dừng reminders, reset shared cache, đăng xuất Firebase/Google. Có UI xử lý lỗi. | Có triển khai nền tảng, chưa đánh dấu đạt hoàn toàn: cần demo Android Google login, cancel, offline, logout, mở route riêng khi mất quyền; ảnh trước/sau và Console Users. Xác minh không lộ dữ liệu tài khoản trước khi đổi user. |
| Cloud Storage, trang 8-10 | Có tạo/xuất báo cáo Excel trong `lab2/lecturer_weekly_report.dart`, CSV ở các module khác. | Không có `firebase_storage`, upload, progress, download URL hay `firebase/storage.rules`. Cần upload một báo cáo vào `reports/{FirebaseAuth.uid}/...`, owner-only rules, giao diện tiến độ/thành công/lỗi; thử user khác, anonymous và offline. PDF là ví dụ định dạng, không bắt buộc phải đổi Excel sang PDF. |
| Cloud Messaging, trang 11-13 | `lab2/lecturer_reminders.dart` dùng flutter_local_notifications; có xin quyền Android và điều hướng nhắc. `integration_test/attendance_notifications_test.dart` kiểm local notification. | Không có `firebase_messaging`, nhận push Firebase, lịch sử push hay kiểm thử ba trạng thái. Local reminder không thay FCM. Cần gửi từ Console, đang mở/chạy nền/đã đóng, lịch sử theo user, chạm mở đúng màn và xử lý từ chối quyền. |
| Analytics, trang 14-16 | Có module thống kê chuyên cần và `test/lab2_analytics_test.dart`. | Đây là thống kê nghiệp vụ, không phải Google Analytics. Không có `firebase_analytics`, `docs/analytics-plan.md`, ít nhất 7 event hay DebugView. Cần user ID Firebase sau login, xóa user ID khi logout, không ghi email/tên/MSSV vào event. |
| Crashlytics, trang 17-19 | Có catch lỗi và thông báo UI. | Không có `firebase_crashlytics`, global Flutter/async error handlers, gửi non-fatal, custom key, crash demo hay Console evidence. Catch lỗi không tự gửi Crashlytics. |
| Remote Config, trang 20-22 | Có cấu hình compile-time từ dart-define/config và các hằng tính năng. | Không có `firebase_remote_config`, fetch/activate hay hai tham số thay đổi hành vi khi không build lại. Dart-define không thay Remote Config. Cần defaults, cache/failure behavior và ảnh Console/trước-sau. |

`pubspec.yaml` hiện có firebase_core, firebase_auth, cloud_firestore, cloud_functions. Firestore và Cloud Functions không thay thế năm dịch vụ nêu trên; hướng dẫn liệt kê đích danh sáu dịch vụ, không yêu cầu chỉ cần bất kỳ sáu sản phẩm Firebase.

## Kiến trúc và truy vết Lab 2

- Có Riverpod, providers, GoRouter và repository; các tham chiếu Firebase SDK trong `lib/lab2` tập trung ở `repository.dart` và service `article_library.dart`, ngoài bootstrap `main.dart`. Đây là nền tốt nhưng chưa đủ chứng minh toàn bộ MVVM.
- UI nhiều nơi gọi repository và tự quản lý busy/error. Khi bổ sung Lab 3, tạo ViewModel/controller cho auth, upload, notification center và cấu hình; View -> ViewModel -> service -> Firebase SDK. Không cần viết lại toàn bộ ứng dụng để chỉ đổi tên folder.
- `docs/ARCHITECTURE.md` có kiến trúc nhưng chưa có dependency/service/state cho năm dịch vụ mới. Cần cập nhật theo source cuối cùng.
- Có `design/DESIGN.md`, `design/screen-spec.md`, `ux/persona.md`, `ux/user-flow.md`, `design/design-decisions.md`. Không ghi nhầm là thiếu toàn bộ hồ sơ thiết kế.
- Chưa thấy `flutter-handoff.md` và link Figma đã xác minh. Một số link tương đối trong `design/DESIGN.md` như `ux/...` và `ai/ai-design-log.md` chưa khớp cấu trúc thư mục đang có; rà lại link trước khi nộp.
- `ux/user-flow.md` mô tả F01 mở/tiếp tục phiên, F02 sửa điểm danh, F03 sổ tay. `docs/LAB2_ASSESSMENT_PLAN.md` cũ lại đề xuất ba flow điểm danh / theo dõi sinh viên / bài viết. Cần chốt đúng ba flow từ bản Lab 2 đã nộp và tạo ma trận Flow -> màn Figma -> Flutter -> nhánh lỗi -> test -> evidence -> Analytics event. Không tự xem hai bộ flow là cùng một bộ.
- Shared Apps Script/Sheets có thể giữ nguyên để đồng bộ mobile/desktop/web; hướng dẫn không nói phải chuyển toàn bộ database sang Firestore. Các dịch vụ Firebase mới nên bổ sung đúng vai trò, tránh làm hai nguồn dữ liệu điểm danh.

## Hồ sơ bắt buộc ngoài code

| Hạng mục | Đánh giá hiện tại | Cần hoàn thiện |
|---|---|---|
| ARTEMIS, trang 23 | Có nhiều unit/widget/integration tests Flutter. Chưa tìm thấy bộ ARTEMIS và run logs đáp ứng yêu cầu. | Ít nhất 10 test có precondition/steps/expected; mỗi test ít nhất 3 lần (tối thiểu 30 lượt); ghi kết quả quan sát, pass rate và log. Bao phủ ba flow, nhánh lỗi và tương tác Android gốc. Ghi exploratory session 15-30 phút. Không thay bằng số lượng unit test. |
| AI Code Review, trang 24 | Có tài liệu UX review, chưa thấy hồ sơ PR review đáp ứng đủ yêu cầu kỹ thuật Lab 3. | Review PR bằng công cụ tương đương yêu cầu; ít nhất 5 phát hiện gắn file/dòng, >=2 nhóm; quyết định accept/adjust/reject và lý do; sửa >=3 phát hiện accepted, có commit truy vết. Không tạo issue hoặc commit giả để đủ số. |
| Evidence Firebase | Có ảnh Apps Script và UI từ các đợt trước, chưa thấy đủ bộ Console cho sáu dịch vụ Lab 3. | Auth Users; Storage file/progress/URL/rules denial; FCM ba trạng thái; DebugView từng event; Crashlytics non-fatal + crash + UID/key; Remote Config hai giá trị và UI trước/sau. Mỗi dịch vụ có ca lỗi. |
| Sản phẩm nộp, trang 25 | Có repo Git và báo cáo DOCX tiến độ; chưa xác minh bộ nộp cuối Lab 3. | GitHub truy cập được; báo cáo PDF 8-12 trang; slide PDF 12-15 trang; video 5-10 phút. README dẫn đến đúng tài liệu/evidence, ghi build/commit/thiết bị/ngày test. |

## Thứ tự bổ sung đề xuất

1. Chốt ba flow Lab 2 và lập checklist evidence; tạo analytics-plan trước khi viết event. Xác minh Firebase project Android và quyền bật dịch vụ.
2. Bổ sung service interfaces + Riverpod ViewModels; thêm Analytics/Crashlytics vào các điểm nghiệp vụ và lỗi thực tế. Chỉ đặt crash chủ đích ở trang demo riêng.
3. Thêm Remote Config với hai tham số có thay đổi nhìn thấy, ví dụ `subject_updates_enabled` và `subject_updates_page_size` có clamp. Không dùng remote config để bỏ kiểm tra quyền/expiry/quy tắc điểm danh trên server.
4. Tận dụng báo cáo Excel hiện có để upload Cloud Storage, có progress, retry và URL. Dùng UID Firebase trong đường dẫn, không dùng Lecturer ID của Sheets. Viết và kiểm thử owner-only Storage rules.
5. Bổ sung FCM cùng local reminders đang có; thêm trung tâm thông báo, lịch sử gắn user, route whitelist và kiểm quyền lại khi chạm. Không tạo attendance hoặc sửa trạng thái chỉ vì nhận push.
6. Chạy ARTEMIS/Android thật, chụp Console evidence, thực hiện PR review + commit sửa, rồi chốt báo cáo/slide/video theo source đã kiểm thử.

Gợi ý kế hoạch event (cần định nghĩa thời điểm và kiểu tham số trước khi code): `login`, `logout`, `view_teaching_day`, `attendance_session_opened`, `attendance_session_closed`, `attendance_record_updated`, `weekly_report_exported`, `report_upload_completed`, `notification_opened`. Chỉ ghi event thành công sau khi nhận kết quả xác nhận; không coi timeout ghi là thất bại chắc chắn. Tham số enum/count/status, không tên/email/MSSV/nội dung ghi chú hay URL có token.

## Điều kiện môi trường cần biết

Cloud Storage for Firebase hiện yêu cầu project Blaze; đây là điều kiện triển khai thực tế cần kiểm tra, không suy ra project đã bật billing. Nếu không thể bật Blaze, cần thống nhất với giảng viên phương án thay thế; lưu file ở Sheets/Drive không được tự ghi là đã tích hợp Firebase Storage.

Nguồn chính thức đã kiểm ngày 02/11/2026:
- https://firebase.google.com/docs/storage/flutter/start
- https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages

## Kiểm tra cục bộ lần đánh giá này

- `flutter analyze --no-pub`: PASS, No issues found, 77,9 giây.
- `flutter test --no-pub --reporter compact`: PASS, 241 tests, khoảng 54 giây.
- Chưa chạy Android E2E/ARTEMIS hay ghi dữ liệu cloud trong lần đánh giá này. Unit/widget tests không chứng minh SDK/Console hoạt động trên thiết bị.
- Các kiểm thử cũ trong TEST_REPORT là lịch sử, không được dùng để tuyên bố năm SDK Firebase chưa có đã chạy thành công.
