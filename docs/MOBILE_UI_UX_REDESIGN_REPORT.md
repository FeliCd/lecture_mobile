# Mobile UI/UX redesign — 11/10/2026

Triển khai theo master prompt UI/UX của người dùng, trên Flutter entry `lib/main.dart` → `lib/lab2/app.dart`. Cả sáu phase đã có thay đổi source và kiểm thử tương ứng. Không deploy Apps Script/Firebase, không thay cấu hình cloud hay provider của client khác. Dữ liệu minh họa trong ảnh chỉ đến từ test fixtures, không được đưa vào code production.

## 1. Audit và quyết định

| Khu vực | Trước | Sau |
|---|---|---|
| Theme | Material 3 cam, các khối dashboard lớn, radius không thống nhất, header cũ có gradient | Cam FPT làm accent, navy ở dark mode, nền trung tính, border nhẹ, card phẳng; chung token |
| Đăng nhập | Email/password, đăng ký, xác minh email và Google tùy cấu hình | Google duy nhất; lỗi cấu hình/hủy/mạng/quyền có hướng dẫn |
| Hôm nay | Nhiều khối thông tin, hành động trên thẻ riêng | Chào tên, học kỳ, ba số liệu gọn, các buổi thực tế và hành động theo trạng thái |
| Lịch | Tuần dạng bảy cột nhỏ, phòng chủ yếu trong dialog | Tuần là danh sách theo ngày; mỗi thẻ có giờ, slot, môn, lớp, phòng và trạng thái |
| Lớp | Icon/khối lớn, lịch sử ít thông tin | Thẻ lớp gọn, tìm lớp/mã môn/tên môn, lịch sử thêm giờ/phòng/số check-in |
| Live QR | Metadata và đếm số nằm rải rác; có thể còn QR khi polling lỗi | Đếm số phía trên QR, deadline server, QR ẩn khi stale, nút kết thúc cố định và xác nhận |
| Cập nhật | Thẻ nặng; DTO feed khác DTO của trang bài viết | Kiểu editorial, chuẩn hóa canonicalUrl/sourceName/excerpt/subjectCodes; trạng thái đã lưu |
| Cài đặt | Ít thông tin định danh, đăng xuất ngay | Email server xác minh, LecturerID, department nếu có, theme, nhập dữ liệu, xác nhận logout |

Đã giữ Riverpod, GoRouter, snapshot/polling và các repository hiện có. Không tạo backend attendance mới và không đổi Sheets thành Firestore. Các panel/entry legacy còn lại phục vụ hồi quy, không được gắn thành tab mới trong Mobile chính.

## 2. Phase 1 — Design system

Style: **Material 3 / Modern Campus / Premium Educational Productivity**. Không dùng gradient, glow, ảnh trang trí giả hoặc biểu đồ không có dữ liệu.

| Token | Giá trị |
|---|---|
| Brand / action | `#F37021` / `#B54708` để chữ trắng trên nút sáng dễ đọc |
| Ink / secondary text | `#172033` / `#667085` |
| Light background / border | `#F7F8FA` / `#E7EAF0` |
| Dark background / surface | Navy `#111A29` / `#1B2535` |
| Spacing | 4, 8, 12, 16, 24; page gutter 20 |
| Radius | Control 8, card 12, sheet 16 |
| Typography | Headline 24, title 20/16/14, body theo Material 3; hỗ trợ tiếng Việt và text scaling |
| Touch / navigation | Nút tối thiểu 48px; NavigationBar 72px, safe area theo thiết bị |

Các thành phần dùng lại trong `widgets.dart`: `CampusSectionHeader`, `CampusStatusChip`, `CampusSearchField`, `CampusLoadingState`, `CampusStudentRow`, `CampusRefreshList`, `CampusActionSheet`, `CampusOutlineAction` và `campusConfirm`. Tiếp tục dùng `CampusCard`, `AppPrimaryButton`, `ErrorState`, `EmptyState`, `StatusBadge`, `AttendanceBar`.

Trạng thái có nhãn chữ/icon, không chỉ phân biệt bằng màu. Dropdown được giới hạn theo chiều rộng; nút có icon hỗ trợ nhãn nhiều dòng. Kiểm thử đã phát hiện và sửa overflow ở Settings và nguồn bài viết khi text scale 1.8.

## 3. Phase 2 — Google-only và authorization

Luồng hiện hành:

1. `CampusLogin` gọi `CampusRepository.loginWithGoogle()`; khóa nút khi đang chờ.
2. `google_sign_in` khởi tạo với `GOOGLE_SERVER_CLIENT_ID`, nhận Google ID token rồi đổi thành Firebase credential.
3. Firebase Auth SDK quản lý đăng nhập và refresh ID token. Snapshot lấy token hiện hành qua `getIdToken()`; không lưu token vào URL/QR.
4. Shared Mobile kiểm provider Google ở phía client và gửi `googleLecturerOnly: true` trong `lab2Snapshot`.
5. Apps Script kiểm token audience, issuer, expiry; Firebase `accounts:lookup` xác minh token, UID, emailVerified và tài khoản disabled. Chỉ sau bước xác minh mới dùng `firebase.sign_in_provider`.
6. Email đã xác minh được trim/lowercase và đối chiếu bảng `Lecturers`: đúng một dòng → lecturer; nhiều dòng → `DUPLICATE_PROFILE`; không có hồ sơ → từ chối. Email thuộc `Students` không được vào Mobile giảng viên. Chỉ đúng domain cũng chưa đủ quyền.
7. Snapshot trả hồ sơ và dữ liệu thuộc giảng viên. GoRouter/Profile guard chặn các route riêng khi mất quyền.

Google-only là yêu cầu của snapshot Mobile, không thay quy tắc provider toàn Firebase project. Student Web vẫn được dùng snapshot/đường check-in của nó; Desktop vẫn có Google OAuth và các API cũ. Không bật đăng ký giảng viên tự động.

`UserProfile` bổ sung email, LecturerID và department tùy dữ liệu. Schema Lecturers hiện không có cột active/department chuẩn: department thiếu thì không hiển thị; disabled được kiểm qua Firebase, không tự tạo cờ active mới trong Sheets. Muốn thu hồi quyền giảng viên cần thao tác theo quy trình quản lý hồ sơ/Firebase hiện hữu.

Logout cần xác nhận; xóa snapshot cache trong bộ nhớ, sign out Firebase và Google nếu đã initialize. `savedArticlesProvider` theo dõi auth để đổi subscription thư viện cá nhân khi đổi tài khoản. Không tuyên bố đã xóa toàn bộ disk cache nội bộ của Firebase SDK. Identity cache backend tối đa 60 giây; thu hồi tài khoản có thể chịu khoảng trễ này.

Chưa xác minh đăng nhập Google bằng người dùng thật. Test UI sử dụng mock repository; backend test stub Firebase REST lookup, không phải giao dịch OAuth production.

## 4. Phase 3 — Hôm nay, lịch và phòng

Mobile chính giữ **đúng bốn tab**: Hôm nay, Lịch dạy, Lớp học, Cập nhật. Settings mở từ avatar. `IndexedStack` giữ trạng thái tab, tìm kiếm/lọc/scroll. Back từ tab khác đưa về Hôm nay. Hôm nay/Lịch/Lớp có kéo để tải lại snapshot; Cập nhật có nút làm mới; Live có kéo để tải lại và nút refresh.

Hôm nay dùng occurrence từ lịch thật, gồm trường hợp buổi qua nửa đêm còn hiệu lực. Thẻ có slot, giờ, môn, lớp, phòng và hành động Bắt đầu/Tiếp tục/Xem kết quả/Chưa đến giờ/Đã qua giờ/Đã hủy. Nhãn phía client là gợi ý; thao tác mở luôn hỏi backend. Chỉ mở Today không tạo phiên.

Lịch ngày/tuần giữ lọc học kỳ/môn, chuyển ngày/tuần và về hôm nay. Tuần dùng danh sách ngày dễ đọc thay cho bảy cột nhỏ. Buổi hủy được hiển thị rõ khi UI yêu cầu `includeCancelled`; bấm vào chỉ xem thông báo, không mở phiên.

Nguồn phòng:

- Nhập CSV/Excel/OCR giữ trường `room` → `Schedules.room`.
- Recurring occurrence lấy phòng từ lịch; đổi phòng dùng `ROOM_CHANGED`; buổi bù/dời lấy phòng của exception tương ứng.
- `lab2EffectiveRoom_` bổ sung phòng cho `classSessions`, `attendanceSessions` trong snapshot và `getAttendanceSessionLive`.
- Flutter dùng một `roomLabel` chung trên Today, lịch ngày/tuần, buổi học của lớp, duration sheet, lịch sử và Live.
- Thiếu/không xác định duy nhất → **Chưa cập nhật phòng**, không bịa phòng.

Không thêm cột vào schema Sessions. Phòng của lịch sử được suy ra từ lịch/exception đang có, không phải bản ghi phòng bất biến tại thời điểm mở phiên. Backend hiện chặn sửa exception đã có session; nếu người quản trị sửa/xóa trực tiếp dữ liệu gốc, lịch sử có thể không còn xác định được phòng. Cần migration lưu phòng riêng nếu muốn lịch sử bất biến trong trường hợp đó.

## 5. Phase 4 — Lớp, mở phiên và Live

Class detail giữ bốn tab **Sinh viên / Điểm danh / Buổi học / Thống kê**. Roster giữ tìm tên/MSSV, thống kê và xem lịch sử sinh viên; bỏ avatar trang trí từng dòng. Class tools sửa tên/email với lý do, preview trước/sau và xác nhận; MSSV không được thay. Sửa ngoại lệ lịch ở công cụ riêng, bắt buộc lý do/xác nhận, không ghi đè lịch định kỳ.

Lịch sử phiên hiển thị môn/slot, thời gian mở–kết thúc, phòng, trạng thái và số present+late/eligible. API bổ sung `checkedInCount`, `eligibleCount`; thiếu dữ liệu cũ hiển thị `—`, không tạo con số giả. Xuất CSV và thống kê theo attendance policy vẫn giữ nguyên. PRESENT/LATE/ABSENT/EXCUSED tách riêng; chưa chốt là pending.

Mở phiên từ Today/Lịch/Buổi học dùng chung bottom sheet:

- Thông tin buổi học chỉ đọc; duration 5/10/15/20/30, mặc định 10.
- Đọc `getTeachingOccurrence` để lấy trạng thái server; tương lai/đã qua/còn dưới một phút không mở.
- Xác nhận mở gửi selector + occurrenceId; backend xác minh lại trong write lock, mở theo giờ server và cap khi hết giờ học.
- OPEN tiếp tục nguyên phiên, CLOSED xem kết quả; double tap/network retry không tạo phiên trùng hoặc kéo dài deadline.
- Polling dialog dừng khi app vào background, đọc lại khi resume. Quy tắc UTC+7, overnight và Desktop reset hiện hữu giữ nguyên.

Live: header gọn có phòng/trạng thái; số có mặt/trễ/còn chờ phía trên QR; QR đen trên trắng với quiet zone; secret/đổi mã nằm trong phần tùy chọn; server countdown, thời điểm sync, tìm kiếm/filter và sửa có lý do. Nút kết thúc cố định phía dưới, xác nhận số đã check-in/còn chờ trước khi chốt. Lỗi polling ẩn QR, đánh dấu dữ liệu có thể cũ và khóa sửa. Ownership denial xóa roster cache và dừng tự gọi. Poll 8 giây foreground/backoff và frozen roster vẫn được giữ.

## 6. Phase 5 — Cập nhật, thư viện, Settings, nhập liệu

News/Research giữ môn được phân công, nguồn/ngày/từ khóa, cursor, provenance, cache stale và lỗi từng nguồn. Thẻ tập trung tiêu đề, nguồn/ngày, môn, tóm tắt thật và hành động. `normalizedUpdate` chuyển đúng DTO API sang DTO bài viết/thư viện, giữ NEWS/RESEARCH. Feed đọc saved stream để ghi “Đã lưu / ghi chú” theo DOI/URL hash.

Thư viện vẫn `articleLibraries/{firebaseUid}/articles`: lưu, ghi chú, bỏ lưu do chủ tài khoản, không copy attendance sang Firestore. Không có ảnh minh họa giả hoặc AI summary khi nguồn thiếu excerpt.

Settings hiển thị hồ sơ server, theme system/light/dark được lưu, nhập lịch ảnh, nhập sinh viên Excel/CSV và logout confirm. Giữ quy trình OCR local → chỉnh văn bản → kiểm tra dòng → duyệt trước khi lưu. CSV/manual import thêm xác nhận số dòng; preview lịch có phòng và phản hồi thành công/lỗi. Các form cùng dùng theme và control co giãn.

## 7. API và file thay đổi

Thay đổi additive, không đổi action names, envelope hay cột Sheets:

- `lab2Snapshot.googleLecturerOnly`, identity `signInProvider`, profile email/LecturerID/department.
- Snapshot session/live `room`; attendance history `checkedInCount`, `eligibleCount`.
- Các action tạo/chốt/sửa điểm danh, khóa ghi, ownership và Student Web vẫn giữ.

File chính:

- Theme/components: `lib/lab2/theme.dart`, `widgets.dart`, `dashboard_widgets.dart`.
- Auth/navigation/settings: `app.dart`, `domain.dart`, `repository.dart`, `desktop_sync.dart`.
- Schedule: `today.dart`, `timetable.dart`, `timetable_card.dart`, `timetable_domain.dart`, `class_timetable.dart`, `desktop_session_dialog.dart`.
- Class/live/import: `classes.dart`, `class_attendance_overview.dart`, `live_attendance.dart`, `class_tools.dart`, `import_page.dart`; các dropdown trên form liên quan được giới hạn chiều rộng.
- Feed/library: `subject_updates.dart`, `article_library.dart`.
- Backend: `backend/apps_script/Lab2Free.gs`, `AttendanceSafety.gs`.
- Tests: `mobile_redesign_test.dart` mới; cập nhật `redesign_layout_test.dart`, `lab2_navigation_test.dart`, `subject_updates_test.dart`, `lecturer_workflows_test.dart`, `class_tools_test.dart`, `backend/test/lab2-free.test.cjs`.
- Docs: README, SETUP, ATTENDANCE_MOBILE, IMPLEMENTATION_REPORT; thêm chú thích hiện hành vào LAB2_SPEC, REFACTOR_BLUEPRINT, IMPLEMENTATION_PROGRESS, FREE_DESKTOP_SYNC, GOOGLE_AUTH_SETUP_REPORT.

Repo đã có nhiều thay đổi từ các đợt trước; danh sách trên không đồng nghĩa mọi file dirty trong Git được tạo bởi đợt UI này. Không reset thay đổi của người dùng.

## 8. Phase 6 — Kiểm thử thực tế

| Kiểm tra | Kết quả | Bằng chứng local |
|---|---|---|
| `flutter analyze --no-pub` | Không có issue | `artifacts/ui-analyze.log` |
| `flutter test` | 106/106 pass | `artifacts/ui-flutter.log` |
| Backend + Student Web Node tests | 68/68 pass | `artifacts/ui-backend-web.log` |
| Functions compatibility tests | 5/5 pass | `artifacts/ui-functions.log` |
| Render previews light/dark | 4/4 test pass | `artifacts/ui-preview.log`, `build/ui-previews/` |
| Android debug APK, shared local config | Build thành công | `artifacts/ui-apk.log`, `build/app/outputs/flutter-apk/app-debug.apk` |

Các kiểm tra bao phủ phase: design system/light-dark/large text (1), Google-only mock/denial/backend provider+profile+disabled (2), day/week/cancel/room/import (3), opening states/retry/double tap/deadline/polling/audit (4), feed/filter/normalization/settings/import confirm (5), toàn bộ suite/build (6). Kiểm thử ban đầu tìm ra compile regression và overflow dropdown; tất cả đã sửa trước lần chạy cuối.

Layout mới kiểm Login, Today, Live, Settings, Cập nhật ở **360×900, 393×852, 430×932, 844×390 landscape, 800×1000 tablet**, cả sáng/tối, scale **1.8**. Bộ layout bổ sung lớp/roster/timetable ở 360px, scale 1.0 và 1.8, cả sáng/tối. Không ghi nhận RenderFlex overflow trong các ca này. Không suy rộng thành đã kiểm mọi text scale/thiết bị.

Previews: Login, Today, Classes, Students, Timetable và Live sáng/tối. Đã xem ảnh Today sáng, Login sáng và Live tối để kiểm tra bố cục/QR/độ tương phản; đây là render widget với fixture, không phải screenshot thiết bị production.

Không chạy lại Desktop test suite hay Firestore rules emulator trong đợt UI vì không đổi source Desktop/rules; bằng chứng đợt slot trước trong ATTENDANCE_SLOT_REFACTOR_REPORT không được tính thành kết quả mới.

## 9. Giới hạn và các bước triển khai cần thiết

1. Chưa production E2E, Google login thật, camera thật, tải đồng thời nhiều sinh viên hay quét QR từ thiết bị thứ hai. Build APK không chứng minh OAuth hay backend cloud đang khớp source.
2. Windows không có Xcode/iOS simulator: chưa build/test native iOS, Dynamic Type/VoiceOver/Google callback trên iPhone.
3. Tài khoản/endpoint trong config ignored được giữ; không xuất credentials vào docs. Không thay đổi project/provider/OAuth cloud.
4. Khi chủ dự án cho phép triển khai: backup Sheets/script; cập nhật **cả 6 file canonical** từ `backend/apps_script` gồm Code, Lab2Free, AttendanceSafety, SubjectInsights, ClassTools, ScheduleAttendance, giữ manifest/Advanced Sheets service; chạy initializer/triggers theo báo cáo triển khai, rồi cập nhật deployment đang dùng với cùng URL. Không dùng Code.gs standalone cũ của Desktop để thay bộ canonical.
5. Firebase Google provider cần được bật ở project đúng. Android client phải khớp package `vn.edu.fpt.lecturer_companion` và SHA-1/SHA-256 của đúng debug/release key. Server client ID là Web OAuth client của Firebase project, không tự lấy client ID Desktop cũ.
6. iOS cần Firebase app/bundle ID tương ứng, client ID trong cấu hình iOS được Google Sign-In nhận diện, và `GOOGLE_REVERSED_CLIENT_ID` đúng URL scheme hiện có trong Info.plist. Source hiện truyền serverClientId; không tự điền client ID iOS nếu chưa có cấu hình hợp lệ.
7. Giữ Firestore rules thư viện cá nhân; không cần deploy Cloud Functions cho shared mode. Không tắt Email/Password hoặc provider khác chỉ vì Mobile đã bỏ UI đó.
8. Sau cập nhật backend, smoke test health/capabilities, Google lecturer snapshot, Student Web check-in và cùng session ID trên Desktop/Mobile. Health v2 lịch sử không đủ chứng minh backend mới được deploy.

## 10. Checklist Android/iOS thủ công

- Cài bản đúng config và fingerprint; Google thành công/hủy/mất mạng; tài khoản unknown/student/duplicate/disabled bị chặn; chuyển account và logout không lộ dữ liệu người trước.
- Kiểm profile name/email/LecturerID; foreground/background/token refresh; bị thu hồi quyền chuyển về login.
- Bốn tab giữ tìm kiếm/filter; Android back, safe areas, bàn phím, landscape/tablet; tăng chữ và thử screen reader/focus.
- Kiểm phòng recurring, đổi phòng, dời/bù, hủy và phòng trống; OCR/CSV preview → confirm → reload dữ liệu Desktop.
- Mở từ Today/Lịch/Lớp, duration mặc định 10, OPEN resume, CLOSED history, tương lai/quá giờ/overnight; hai client không tạo phiên trùng.
- Quét QR thật từ Student Web; token rotation/secret/expiry; mất mạng ẩn QR; resume sync; close confirm chốt absent đúng frozen roster; sửa có lý do tạo audit.
- News/Research theo môn, link gốc, nguồn thiếu/cache cũ, lưu/ghi chú/bỏ lưu; chuyển tài khoản và kiểm Firestore isolation.
- iOS: callback URL, native Google picker, camera/OCR permission, safe-area/home indicator và Accessibility. Release signing/build chỉ thực hiện sau khi cấu hình được xác nhận.
