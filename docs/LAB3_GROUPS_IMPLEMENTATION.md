# Lab 3 và nhóm học tập - 02/11/2026

> Tài liệu triển khai ban đầu. Bản rà soát mới nhất: [LAB3_FINAL_REVIEW_2026-11-02.md](LAB3_FINAL_REVIEW_2026-11-02.md), có chat receipt, skeleton và kết quả native smoke. Web hiện dùng cùng project `fap-attendance-88920`; các kết quả kiểm thử bên dưới là mốc trước lần cải tiến chat.

## Đã triển khai trong source

Mobile vẫn là ứng dụng giảng viên, Student Web là phía sinh viên. Không thay nguồn điểm danh Sheets hiện tại. Bổ sung năm SDK còn thiếu: Storage, Messaging, Analytics, Crashlytics, Remote Config. Authentication hiện có được nối user ID và sự kiện login/logout. Chưa coi source/build pass là bằng chứng Firebase Console hoặc ARTEMIS đã đạt.

### Firebase trong mobile

- `lib/cloud/cloud_services.dart`: telemetry đã giới hạn dữ liệu, lỗi non-fatal có mã nghiệp vụ; Flutter/async global handlers; Remote Config defaults/fetch/cache/clamp; upload Excel vào `reports/{FirebaseAuth.uid}/...`, tối đa 10 MB.
- `lib/cloud/cloud_view_model.dart`: service injection, Riverpod settings/upload state; UI upload tiến độ, lỗi, kết quả, không gọi Firebase SDK trực tiếp.
- `lib/cloud/push_notifications.dart`: FCM foreground/background/terminated tap, xin quyền Android 13+, route allowlist, lịch sử local tối đa 100 tin mỗi UID Firebase; tách khóa message để tránh ghi đè cả danh sách giữa hai isolate. Logout xóa lịch sử user và token thiết bị (best effort khi SDK/network lỗi). Gửi tự động nên có `recipientUid`; tin sai UID bị bỏ. Token chỉ hiển thị trong vùng demo, không log.
- `lib/cloud/cloud_pages.dart`: trung tâm thông báo và trang cấu hình, mở từ Tài khoản. Foreground có thông báo trong app và lịch sử. Vùng thử non-fatal/crash/token chỉ có khi `ENABLE_LAB3_DEMO=true`; crash có xác nhận.
- `docs/analytics-plan.md`: kế hoạch hơn 7 event trước khi viết instrumentation. Các thao tác server chỉ log sau response thành công. Không gửi email/tên/MSSV/nội dung chat/ghi chú/URL-token vào Analytics hoặc lỗi handled.
- Nút “Lưu báo cáo lên Firebase” trong Tổng kết tuần tái sử dụng Excel hiện có. Khi đổi tài khoản trong lúc upload, hủy task; receipt không hiển thị cho tài khoản mới. Download URL chứa bearer token: không đưa vào repo/log/video công khai. Rules bảo vệ SDK access theo UID; người được chia sẻ URL có token vẫn mở được URL.
- Hai tham số Remote Config: `subject_updates_enabled` bật/tắt trang Cập nhật; `subject_updates_page_size` giới hạn số bài mỗi request, clamp 5-30. Mặc định true/20. Chế độ thường cache tối thiểu 15 phút; demo fetch interval 0 để trình diễn. Tham số page size áp dụng ở lần tải feed kế tiếp. Offline dùng giá trị activated cache/default, không chặn điểm danh.
- Telemetry/FCM cloud chỉ khởi động trên Android thật (không emulator mode Firebase). Không tự xin quyền push khi vừa mở app; người dùng chọn Cho phép trong Thông báo. Emulator config không gửi telemetry sang project production.

### Nhóm học tập dùng chung ba client

- Mobile: Lớp học -> mở lớp -> biểu tượng Nhóm học tập trên app bar.
- Desktop: thanh điều hướng -> Nhóm học tập -> chọn lớp.
- Student Web: chọn lớp -> tab Nhóm học tập.
- Giảng viên chọn 1-50 nhóm; hệ thống chia ngẫu nhiên cân bằng. Có thể đổi tên nhóm, chuyển từng sinh viên bằng dropdown rồi lưu. Toàn roster hiện tại phải được chia đúng một lần. Chia ngẫu nhiên lần nữa tạo ID/phòng mới; nội dung phòng cũ vẫn lưu trong sheet nhưng không có giao diện kho lưu trữ.
- Lưu group plan có optimistic version, audit và request key. Student chỉ nhận nhóm mình cùng tên/MSSV thành viên nhóm; không nhận email và roster toàn lớp. Chưa có giao diện để sinh viên tự chọn/chuyển nhóm.
- Chat cập nhật mỗi 10 giây; không phải socket realtime. Mỗi trang 50 tin, có xem tin cũ. Nội dung tối đa 2000 ký tự. Người gửi lấy từ danh tính đã xác minh, không từ input.
- Gửi lại sau timeout dùng cùng request key trong màn đang mở. Có nút bỏ bản gửi đang chờ và tải lại; cần kiểm tra lịch sử trước khi gửi mới. Không có outbox bền vững qua khởi động lại ứng dụng/trình duyệt.
- Tệp nhóm: PDF/TXT/PNG/JPEG/XLSX/DOCX/CSV, tối đa **500 KB/tệp**. Dữ liệu lưu trong thư mục Drive riêng tư của chủ Apps Script; backend kiểm quyền nhóm trước cả upload/download. Không tạo link Drive công khai. Download luôn tải tệp, không render HTML/tệp trong app. Chưa có antivirus, sửa/xóa tin, reactions, mentions hoặc bài tập/chấm bài như một LMS đầy đủ.
- Quyền được kiểm lại theo enrollment và group plan ở mọi request; chuyển nhóm/mất enrollment chặn đọc/tải từ nhóm cũ. Client xóa tin đang hiển thị khi nhận lỗi quyền. Nội dung người dùng đã tải về trước đó không thể thu hồi.
- Mobile và web hiện dùng project Firebase `fap-attendance-88920`. Nhóm dùng Apps Script, không có service account nhúng client. Report Storage phục vụ Lab 3, không giả định tệp nhóm Drive là Firebase Storage.

## Bật tính năng trên Apps Script

1. Dùng source chung trong `C:/PRM/lecture_mobile/backend/apps_script`. Cập nhật `Code.gs`, `Lab2Free.gs`, `StudentPortal.gs`, thêm `StudyGroups.gs` và manifest `appsscript.json`. Nên dùng toàn bộ file trong gói backend mới để không trộn phiên bản với AttendanceSafety/ScheduleAttendance/ClassTools/SubjectInsights/Setup.
2. Giữ nguyên Script Properties Firebase mobile/portal, Spreadsheet ID và OAuth audiences hiện có. Không đổi Firebase project web sang mobile.
3. Chủ project chạy thủ công **setupStudyGroups()**. Hàm thêm hai bảng `PortalGroupPlans`, `PortalGroupMessages` qua initializer additive và tạo thư mục Drive riêng tư nếu chưa có. Lưu ID vào Script Property `GROUP_FILES_FOLDER_ID`. Manifest có scope Drive bổ sung; owner cần cấp quyền khi chạy. Không mở chia sẻ thư mục cho domain/anyone/cộng tác viên.
4. Deploy -> Manage deployments -> Edit -> New version -> Deploy, giữ URL `/exec` hiện tại. Source trên máy không tự cập nhật deployment.
5. Thử bằng lớp/tài khoản test: giảng viên chia nhóm -> sinh viên refresh -> gửi tin -> thành viên cùng nhóm đọc -> thành viên khác nhóm bị chặn -> chuyển nhóm và kiểm lại tệp cũ. Không dùng dữ liệu/lớp thật để gây lỗi demo.

`setupStudyGroups()` có thể chạy lại. Không xóa hoặc ghi đè dữ liệu điểm danh, điểm số, xin nghỉ. Drive và Sheets không có distributed transaction: nếu tạo file xong mà batch ghi Sheets không rõ kết quả, có thể có file mồ côi; không tự xóa khi chưa biết batch đã commit. Owner rà file mồ côi khi bảo trì. Apps Script/Sheets có quota và đọc chat tuyến tính; cần đo với lớp thật trước khi triển khai cho quy mô lớn.

## Bật Firebase Lab 3

Cấu hình Android chính thức đã tải về `android/app/google-services.json` từ project mobile hiện hành; file ignored. Đã bổ sung `FIREBASE_STORAGE_BUCKET` trong config local theo giá trị chính thức. File mẫu cũng có trường này. Khi đổi máy:

```powershell
cd C:\PRM\lecture_mobile
flutter pub get
$cfg = Get-Content config/lab2.free.json -Raw | ConvertFrom-Json
firebase login
firebase apps:sdkconfig ANDROID $cfg.FIREBASE_APP_ID --project $cfg.FIREBASE_PROJECT_ID --out android/app/google-services.json
```

Native Google Services và Crashlytics Gradle plugins được áp dụng khi có file native và không dùng USE_EMULATORS=true. Main vẫn dùng FirebaseOptions từ config local. Cấu hình native và dart-define phải trùng app/project; real build thiếu native config sẽ báo lỗi rõ ràng. Emulator dùng build-id resource cục bộ cho SDK native và tắt cloud collection, không coi marker này là dữ liệu đã upload Console. Cloud SDK được tắt collection mặc định bằng manifest, sau đó bật trong bootstrap Android real mode.

Trên Firebase Console project **mobile**:

1. Kiểm tra Google provider/SHA như hiện có; bật Google Analytics, Crashlytics và Cloud Messaging API khi được yêu cầu.
2. Tạo Storage bucket đúng `FIREBASE_STORAGE_BUCKET`. Storage yêu cầu Blaze: chủ project cần tự quyết định billing. Chưa bật billing hoặc triển khai rules thay bạn trong lần này.
3. Kiểm tra bucket không có dữ liệu ứng dụng khác trước khi thay rules: file rules mới chỉ cho `reports/{uid}/...`, mọi đường dẫn khác bị chặn. Khi sẵn sàng:

```powershell
firebase deploy --project fap-attendance-88920 --config firebase.cloud.json --only storage
```

4. Remote Config: thêm/publish hai tham số theo `firebase/remoteconfig.template.json` qua Console. File là template tham khảo; không ghi đè toàn bộ remote template nếu project đang có tham số khác.
5. Chạy Android demo:

```powershell
flutter run --dart-define-from-file=config/lab2.free.json --dart-define=ENABLE_LAB3_DEMO=true
```

6. Mở Tài khoản -> Thông báo -> Cho phép. Trong Dịch vụ đám mây -> lấy token test -> gửi Console test. Custom data cho điều hướng: `screen=class`, `classId=<id lớp thật của tài khoản test>`; hoặc `screen=settings`. Có thể thêm `recipientUid=<UID Firebase tài khoản test>`. URL/route tùy ý bị bỏ; màn lớp vẫn chịu quyền backend hiện hành. Không cần tự tạo server gửi push để chạy Console demo.
7. Analytics DebugView:

```powershell
adb shell setprop debug.firebase.analytics.app vn.edu.fpt.lecturer_companion
# Sau buổi demo:
adb shell setprop debug.firebase.analytics.app .none.
```

8. Non-fatal/crash thử: chỉ vùng demo; khởi động lại app sau crash và chờ Console. Thử lỗi thực như upload bị từ chối/mất mạng: UI vẫn phải báo lỗi và Crashlytics có operation key/user ID. Không bật demo crash trong bản sử dụng thường.

## Build và web

```powershell
cd C:\PRM\lecture_mobile
flutter build apk --debug --dart-define-from-file=config/lab2.free.json

cd C:\PRM\FAP-Attendance-Desktop-System
flutter build windows --release --dart-define-from-file=config/local.json

cd C:\PRM\fu-grade-web
npm run build
npm run deploy
```

Web group không yêu cầu mở thêm Firestore rules. Cần deploy backend mới trước khi dùng tab nhóm. Desktop gửi OAuth Google và mobile gửi Firebase token hiện có; cả hai chỉ được chia/chat lớp thuộc giảng viên đó. Demo desktop offline cũ chưa mô phỏng module nhóm; không fallback sang dữ liệu giả khi API thật thất bại.

## Kiểm thử và giới hạn xác nhận

Kết quả kiểm tra cục bộ:

- Mobile analyzer: sạch. Flutter unit/widget: **247 pass**.
- Desktop unit/widget: **66 pass**, analyzer sạch, Windows release build thành công.
- Backend Apps Script VM: **113 pass**, gồm 9 ca nhóm/quyền/tệp/retry/phân trang.
- Web: **9 UI tests + 4 migration tests pass**; Vite production build thành công.
- Storage rules: emulator thực thi test owner/khác user/anonymous/unverified/MIME/size/overwrite/delete thành công.
- Android debug build cấu hình Firebase thật thành công; APK `artifacts/lab3-groups-debug.apk`.
- UI web nhóm kiểm tra bằng dữ liệu mẫu ở viewport thường và điện thoại, không tràn ngang. Ảnh local `C:/PRM/fu-grade-web/.visual-qa/groups-preview.png`; không phải minh chứng cloud.

Chưa có thiết bị trong `adb devices`; chưa xác nhận Google login/FCM ba trạng thái/Console Analytics/Crashlytics/Remote Config trên Android thật. Chưa deploy Apps Script, Firebase Hosting hoặc Storage rules cloud trong lần này.

Hồ sơ còn cần thực hiện với bằng chứng thật: ARTEMIS >=10 ca x3 lần, exploratory 15-30 phút, PR AI review >=5 phát hiện thuộc >=2 nhóm và >=3 sửa có commit; ảnh Console; báo cáo/slide/video. Xem `LAB3_ACCEPTANCE_CASES.md` để thực hiện. Không được tick đạt chỉ vì SDK đã thêm và build đã pass.

Nguồn SDK chính thức:
- https://firebase.google.com/docs/flutter/setup
- https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages
- https://firebase.google.com/docs/storage/flutter/upload-files
- https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports
- https://firebase.google.com/docs/remote-config/flutter/get-started
