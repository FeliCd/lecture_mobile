# Rà soát nghiêm ngặt Lab 3 — 05/11/2026

## Kết luận

**Chưa đủ cơ sở xác nhận đạt toàn bộ Lab 3.** Ba client hiện build được, bộ kiểm thử local pass và Mobile có source tích hợp sáu dịch vụ Firebase. Những điều này chưa thay thế minh chứng vận hành Android/Console, ARTEMIS, review PR và hồ sơ nộp. Không quy đổi thành điểm hay phần trăm vì hướng dẫn không cung cấp trọng số chấm.

Nguồn tiêu chí: `C:/Users/ontri/Downloads/PRM393_Lab3_Preparation_Guide_v5_ToiUu.pdf`, 25 trang, đặc biệt trang 1–4 và 23–25. Áp dụng `.cursor/rules/platform-roles.mdc`: Mobile + Desktop dành cho giảng viên; Web dành cho sinh viên; backend dùng chung. Yêu cầu sáu Firebase SDK của bài Flutter cần chứng minh trên Android; không yêu cầu ép Desktop/Web có mọi SDK Android để gọi là đồng bộ nghiệp vụ.

Snapshot đã kiểm tra:

| Client | Repository | HEAD |
|---|---|---|
| Mobile | C:/PRM/lecture_mobile | 0f0f313 |
| Desktop | C:/PRM/FAP-Attendance-Desktop-System | 521e2e2 |
| Student Web | C:/PRM/fu-grade-web | 976b1c5 |

Phạm vi: đọc source, cấu hình local không xuất khóa, tài liệu, test, analyzer, build. Chưa đăng nhập Console, chưa thay backend/Hosting deployment, chưa gửi email/push hoặc ghi dữ liệu lớp thật; chưa chạy lại UI E2E trên thiết bị. Đây không phải xác nhận phiên bản production trùng HEAD local.

## Kết quả thực thi mới

| Kiểm tra | Kết quả ngày 05/11 | Ý nghĩa / giới hạn |
|---|---|---|
| Mobile `flutter analyze --no-pub` | Không có issue | Phân tích tĩnh |
| Mobile `flutter test --no-pub --reporter expanded` | 285 pass | Unit/widget, không thay Android E2E |
| Mobile `flutter build apk --debug --no-pub --dart-define-from-file=config/lab2.free.json` | Pass | APK debug; có cảnh báo công cụ Kotlin/SDK XML, không làm fail build |
| Desktop `flutter analyze --no-pub` | Không có issue | Phân tích tĩnh |
| Desktop `flutter test --no-pub --reporter expanded` | 96 pass | Unit/widget |
| Desktop `flutter build windows --release --no-pub --dart-define-from-file=config/local.json` | Pass | Windows release |
| Web `npm test` | 55 Vitest + 4 migration = 59 pass | UI/logic và migration |
| Web `npm run build` | Pass | Production bundle local |
| Mobile backend `node --test backend/test/*.test.cjs` | 141 pass | Apps Script mô phỏng VM; không xác minh quyền Google live |
| Storage emulator với `functions/test/storage-rules.cjs` | 1 suite pass | Có các nhánh owner/other/anonymous, validation; không phải 1 lượt upload cloud |
| `node scripts/check-cloud-config.cjs` | Cấu hình khớp | Không xác minh SHA/OAuth, billing, rules hoặc Console |

Logs Mobile: `tmp/lab3-review-analyze.log`, `tmp/lab3-review-tests.log`, `tmp/lab3-review-build.log`, `tmp/lab3-review-backend.log`, `tmp/lab3-review-storage.log`. Logs Desktop được lưu trong `tmp/lab3-audit-evidence/desktop-*.log`; logs Web gốc trong `C:/PRM/fu-grade-web/.visual-qa/lab3-review-*.log`. Đây là logs local, không tự coi là hồ sơ ARTEMIS.

## Ma trận yêu cầu của thầy

| Yêu cầu | Bằng chứng source/test hiện tại | Kết luận nghiêm ngặt và việc còn lại |
|---|---|---|
| Ba luồng Lab 2 và nhánh lỗi | SessionOpeningController, AttendanceEditController, NotebookController; kiểm thử phục hồi lỗi | Có triển khai. Cần đối chiếu với Figma đã nộp và quay thao tác thực. Sổ tay local không phải dữ liệu đồng bộ ba client |
| MVVM + Provider/Riverpod; View không gọi Firebase SDK | Repository, cloud services/viewmodels; grep SDK instance nằm ở service/repository/bootstrap | Có cấu trúc phù hợp cho các luồng xét. Không chứng nhận mọi màn cũ đã MVVM hoàn toàn chỉ nhờ analyzer |
| Authentication | Google credential, authStateChanges, guard, AuthActionsController | Chưa đủ nghiệm thu: cần ảnh Users và login/hủy/offline/logout. Có rủi ro cleanup logout R01 bên dưới |
| Storage | Export Excel, reports/{uid}, progress, URL, rules, xử lý UID đổi giữa upload; emulator pass | Chưa đủ: upload thật, URL hoạt động, file trên Console, denial và mất mạng. Metadata probe không chứng minh quyền ghi |
| FCM | Permission Android 13+, foreground/background/initial message, lịch sử theo UID, điều hướng giới hạn | Chưa đủ: Console gửi đến thiết bị ở ba trạng thái, chạm đúng màn, thử từ chối quyền. Local reminder/email/web polling không thay FCM |
| Analytics ≥7 events | Plan và instrumentation; login/logout, view_teaching_day, attendance_session_opened/closed, attendance_record_updated, report_upload_completed | Cần DebugView thực cho event/parameter và UID; không lấy source làm bằng chứng server đã nhận |
| Crashlytics | Global/non-fatal, UID/custom keys, demo crash có xác nhận | Cần fatal + non-fatal hiện trên Console sau relaunch; thử trên tài khoản test |
| Remote Config ≥2 tham số | subject_updates_enabled, subject_updates_page_size; default/cache, nguồn và thời điểm fetch | Có code; native smoke ngày 02/11 là lịch sử. Cần quay bản mới trước/sau publish không rebuild và offline/cache |
| ARTEMIS | Có kế hoạch 16 ca trong docs/LAB3_ACCEPTANCE_CASES.md | Chưa thấy logs ≥10 ca ×3 lần với giá trị quan sát thật và phiên khám phá 15–30 phút cho bản hiện tại |
| AI PR review | Có docs/LAB3_CODE_REVIEW_LOCAL.md | Chưa thấy bộ bằng chứng PR URL, ≥5 finding gắn dòng thuộc ≥2 nhóm, quyết định từng finding, ≥3 accepted fix có commit. Báo cáo local này không tự thay tiêu chí PR |
| Hồ sơ thiết kế / kiến trúc | DESIGN, flutter-handoff, architecture và Analytics plan trong repo | Cần link Figma/GitHub truy cập được và trace đúng ba luồng Lab 2 |
| Hồ sơ nộp | PPTX/PDF slide cập nhật 14 trang + lời thuyết trình | Báo cáo PDF 10 trang cũ chưa cập nhật theo bản pull; cần bản báo cáo 8–12 trang đúng trạng thái mới, video 5–10 phút, minh chứng thật |

## Đối chiếu ba nền tảng

APPS_SCRIPT_URL Mobile và Desktop khớp; VITE_PORTAL_API_URL trong .env và .env.local Web khớp cùng endpoint. Không in giá trị endpoint/khóa trong hồ sơ. Sự khớp này không chứng minh URL đang phục vụ bản script mới nhất.

| Nghiệp vụ | Mobile giảng viên | Desktop giảng viên | Web sinh viên | Lưu ý |
|---|---|---|---|---|
| Điểm danh / lớp | Có | Có | Vai trò SV: xin nghỉ, xem thông tin được phép | Không nhân bản quyền giảng viên sang web; cần test hai thiết bị cùng lớp |
| Điểm công bố | Quản lý theo API | Quản lý / công bố | Chỉ đọc publication của SV | StudentPortal.gs:186–194 kiểm publication; không trả bản nháp qua API sinh viên |
| Nhóm, chat, tệp | Có | Có | Có, bubble/receipt/skeleton | Receipt của web không chứng minh mọi client phát read ACK; chat polling, không socket |
| Tự đăng ký nhóm qua Sheets | Quản lý | Quản lý | Chọn qua Sheet rồi tải lại web | Backend cần setup/trigger/Drive API; kiểm quyền từng sinh viên thực chưa được chạy đợt này |
| Giao việc nhóm | Có màn tạo/xem | **Chưa có màn tương ứng** | Nhận/read ACK/poll 30 giây | Khoảng thiếu parity so với quy ước giảng viên Mobile/Desktop; là nghiệp vụ mở rộng, không tự thay yêu cầu Firebase |
| FE/PE forecast | Có | Có | Có | Nhập tay; không ghi điểm thật, không tự bảo đảm qua môn theo mọi đề cương |

## Phát hiện cần xử lý trước khi tuyên bố hoàn tất

### R01 — P1: lỗi một bước có thể ngắt cleanup đăng xuất

Nguồn: `lib/lab2/repository.dart:263–271`. `LecturerReminders.activate(null)`, Firebase signOut, Google signOut, push logout, telemetry chạy await nối tiếp. Nếu reminders lỗi, chưa đến signOut; nếu Google signOut lỗi sau Firebase signOut, không đến xóa token/history/telemetry. Đây là rủi ro suy ra trực tiếp từ control flow, chưa tái hiện lỗi SDK thật. Cần cleanup độc lập hoặc try/finally, vẫn trả lỗi thích hợp, và test fault injection cho từng bước. Không khẳng định đã có rò dữ liệu thực tế.

### R02 — P2: Desktop thiếu giao việc dù quy ước hai client đều phục vụ giảng viên

Nguồn: `lib/groups/group_tasks.dart:50,143`, `backend/apps_script/GroupTasks.gs:36–91`, Web `src/pages/TaskNotifications.jsx:21,55`; không tìm thấy createGroupTask/listGroupTasks hoặc màn giao việc trong Desktop lib. Cần bổ sung UI/service dùng API chung hoặc công bố rõ tính năng chỉ có Mobile trong phiên bản demo. Không gọi đây là thiếu một trong sáu Firebase SDK.

### R03 — P2: web chưa tự cập nhật plan sau thay đổi nhóm ở Sheets

Nguồn: Web `src/pages/StudyGroups.jsx:15–21,45`. loadPlan chạy khi mount/đổi lớp/tải lại; timer 10 giây chỉ đọc chat, không đọc plan. Người dùng cần tải lại để thấy nhóm mới, như tài liệu đã nêu. Cần test hai tài khoản với trigger thật; nếu muốn tự cập nhật, thêm refresh/version check có bảo vệ nháp/tệp chưa gửi. Không khẳng định backend bỏ kiểm quyền: groupAccess_ vẫn kiểm membership hiện hành.

### R04 — P2: rủi ro dùng nhầm gói backend khi deploy

Desktop `backend/apps_script` chỉ có Code.gs, Lab2Free.gs, appsscript.json; gói Mobile có StudentPortal/StudyGroups/GroupTasks/GroupSignupSheets cùng module liên quan. Không dùng riêng bộ Desktop để thay toàn bộ backend đang phục vụ ba client. Cần deploy đủ gói canonical Mobile, giữ Spreadsheet/project/deployment URL, chạy setup phù hợp và kiểm quyền owner/trigger. Chưa xác minh deployment hiện tại có thiếu file hay không.

### R05 — P2 hồ sơ: tài liệu build/cloud đã lỗi thời

`docs/GROUP_TASK_NOTIFICATIONS.md:63` còn nói thiếu google-services.json và bị chặn build. Trên máy này preflight và build Android hiện pass. Cần dùng kết quả 05/11 khi trình bày, nhưng không suy diễn cloud upload/FCM/Console đã pass. Các con số test ngày 02–04/11 và screenshot fixture không được dùng như E2E của HEAD mới.

### Giới hạn sản phẩm phải nói đúng

- Forecast dùng giả định tổng >5 và bước điểm 0,1, không bao trùm ngưỡng FE/PE tối thiểu hay quy chế từng môn. Không công bố “chắc chắn đậu”.
- MailApp xác nhận chấp nhận gửi, không chứng minh sinh viên nhận/đọc email. PENDING/SENDING/UNKNOWN cần đối chiếu; không retry mù gây trùng.
- Chưa có outbox giao việc Mobile bền vững sau đóng app. Sau timeout + restart cần xem danh sách đã tạo trước khi tạo lại.
- Đăng ký nhóm qua Sheets chưa giới hạn sĩ số/deadline tự đóng theo tài liệu; đây là giới hạn mở rộng, không phải yêu cầu Firebase mặc định.

## Trình tự hoàn thiện để nộp

1. Sửa và test R01; quyết định bổ sung Desktop giao việc hoặc công khai phạm vi demo. Tránh deploy nhầm bộ backend.
2. Xác minh backend setup/trigger bằng lớp test. Thử SV chọn nhóm → Mobile/Desktop đọc cùng plan → Web tải lại; tạo việc → đúng SV nhận → người ngoài nhóm bị từ chối; công bố/thu hồi điểm.
3. Thu minh chứng Android + Console cho cả sáu dịch vụ và nhánh lỗi, ghi phiên bản APK và ngày thực thi. Không dùng cảnh báo/config status như minh chứng vận hành.
4. Chạy ≥10 ca ARTEMIS mỗi ca ≥3 lần; lưu actual/assertion/log từng lượt; thêm khám phá 15–30 phút. Tính pass rate từ các lượt thực tế, không từ unit test.
5. Hoàn thiện review trên PR thật với ≥5 finding/≥2 nhóm, accept-adjust-reject có lý do và ≥3 commit fix được truy vết. Rà soát này có thể làm đầu vào, không được giả lập commit hay kết quả đã sửa.
6. Cập nhật báo cáo 8–12 trang, kiểm link GitHub/Figma, quay video 5–10 phút. Dùng slide 05/11 và speaker notes; sửa trạng thái chỉ khi có evidence mới.

## Bản trình bày

`output/lab3/FAP_Attendance_Lab3_2026-11-05.pptx`: 14 slide, giữ thiết kế cam/nâu, cập nhật số test, bổ sung Sheets/giao việc/FE-PE, nêu rõ giới hạn đồng bộ và bằng chứng còn thiếu. Bản PDF slide cùng ngày phù hợp yêu cầu 12–15 trang. Speaker notes và file lời thuyết trình dành khoảng 8 phút. Chưa kiểm trực tiếp trong Microsoft PowerPoint; đã render và kiểm bố cục bằng công cụ tạo slide.
