# FAP Smart Lecturer Lab 2 — thiết lập

**Source Mobile hiện hành 11/10/2026:** chỉ có đăng nhập Google; không còn form email/password, đăng ký hoặc xác minh email trong Mobile. Cấu hình Firebase Google provider, Android OAuth package/SHA và `GOOGLE_SERVER_CLIENT_ID` đúng Firebase project; iOS cần client ID/URL scheme tương ứng. Không tắt provider đang được Desktop/Student Web sử dụng. Apps Script phải được cập nhật từ cả 6 file canonical trước khi xác nhận tích hợp thật. Xem [MOBILE_UI_UX_REDESIGN_REPORT](MOBILE_UI_UX_REDESIGN_REPORT.md). Các chỉ dẫn email/password/Blaze bên dưới là lịch sử của nhánh cloud/emulator, không phải phương thức đăng nhập của Mobile hiện tại.

**Cập nhật 09/10/2026:** chủ dự án chọn dữ liệu thật dùng chung Desktop và không trả phí. Đọc [FREE_DESKTOP_SYNC](FREE_DESKTOP_SYNC.md) để chạy chế độ mặc định mới. Các mục Firebase Functions/Blaze bên dưới mô tả bản cloud đầy đủ tùy chọn, không cần làm cho bản free.

Ứng dụng chính là `lib/main.dart`. Mã Apps Script cũ còn nguyên, chạy riêng bằng `lib/main_legacy.dart`. Không có API FAP chính thức hoặc đồng bộ FAP tự động.

## Firebase Emulator trên Windows

Yêu cầu Flutter/Dart theo `pubspec.yaml`, Node 22 khuyến nghị, Java 21+, Firebase CLI. Máy hiện có Node 24; emulator đã chạy được nhưng CLI cảnh báo khác runtime deployment Node 22.

Terminal 1 tại thư mục dự án:

```powershell
.\scripts\start-lab2-backend.ps1
```

Script cài dependency theo lockfile, build TypeScript, tạo `functions/.secret.local` nếu chưa có và chạy Auth/Firestore/Functions. File secret local bị Git ignore. Không gọi Cloud Secret Manager cho demo signing key. `OPENALEX_API_KEY=emulator-public-access` là sentinel chỉ dùng ở emulator để gọi public access không gửi API key giả; muốn dùng key của bạn thì thay sentinel bằng key thật trong file đó. Không gửi key vào chat hoặc đưa vào mobile. Chỉ copy các settings không bí mật từ `.env.example` vào `functions/.env.local`; không khai báo trùng secret names trong `.env`.

Terminal 2, sau khi emulator sẵn sàng:

```powershell
.\scripts\run-android.ps1 -EmulatorId Pixel_7 -Config config/lab2.emulator.json
```

Tài khoản tổng hợp: `lecturer.a@example.test`, `lecturer.b@example.test`, `student.0@example.test` đến `student.9@example.test`, `outsider@example.test`. Mật khẩu emulator-only mặc định `EmulatorOnly123!`; có thể đặt `DEMO_PASSWORD` lúc seed và dùng cùng giá trị khi chạy test. Seeder từ chối chạy khi thiếu cả hai emulator env, không tạo tài khoản demo ở production.

Chủ dự án chọn Emulator miễn phí. Lệnh backend mặc định tự nạp dữ liệu rồi giữ dịch vụ chạy; giữ terminal đó mở, Ctrl+C để dừng. Dữ liệu demo được tạo lại mỗi lần khởi động, không lưu lâu dài. Dùng `-NoSeed` nếu cần khởi động dịch vụ mà không tự seed. Pixel_7 hiện đã có trên máy. Khi kết nối điện thoại USB, `run-android.ps1` tự adb reverse và chọn host 127.0.0.1; máy ảo dùng 10.0.2.2. UI dữ liệu tại http://127.0.0.1:4000.

Android emulator dùng host `10.0.2.2`. Với điện thoại USB, script Android tự reverse các cổng 9099/8080/5001 và thêm `--dart-define=EMULATOR_HOST=127.0.0.1`. Debug manifest cho phép HTTP đến emulator; release manifest giữ HTTPS. Máy đã có AVD Pixel_7; kiểm tra quét camera thực tế vẫn cần điện thoại hoặc nguồn camera được cấu hình trong AVD.

Scheduler không tự chạy trong bộ emulator hiện tại. Demo cần giảng viên bấm kết thúc để materialize vắng/công bố quiz; mọi submission quá hạn vẫn bị server từ chối ngay. Production có scheduled Function mỗi phút. Không cần mở QR đủ hai phút để kiểm thử expiry: backend test có clock hook chỉ đọc trong Emulator từ `testClock/control` do Admin test harness ghi, client không có quyền đọc/ghi, production bỏ qua.

## Firebase thật — thông tin cần từ chủ project

### Cấu hình đã nhận 08/10/2026

- Project: `fap-attendance-88920`, sender/project number `952479874829`.
- Android App ID: `1:952479874829:android:8f83069308795248413a44`, package khớp `vn.edu.fpt.lecturer_companion`.
- `config/lab2.production.json` đã được tạo từ google-services.json của bạn; không được Git theo dõi. Main sử dụng FirebaseOptions từ file này, không cần thêm Google Services Gradle plugin cho luồng hiện tại.
- OpenAlex key đã lưu vào `functions/.secret.local` và kiểm tra HTTP 200 với một metadata result. Chưa lưu vào Secret Manager cloud vì project chưa sẵn sàng/quyền deploy chưa được xác minh.
- Mobile luôn hiển thị Google Sign-In; cần bật Google provider, đăng ký SHA debug/release và cấu hình server client ID đúng Firebase project. Khi cấu hình thiếu, ứng dụng báo lỗi rõ ràng; không chuyển sang email/password.
- Probe Auth trả `CONFIGURATION_NOT_FOUND`; cần khởi tạo Authentication và bật Email/Password.
- `firebase firestore:databases:list --project fap-attendance-88920 --json` trả 403: Firestore API chưa dùng hoặc bị tắt. Cần tạo Firestore database trong Console (production mode) và đợi API propagation.
- `firebase projects:list --json` hiện chỉ liệt kê `fap-attendance-cba45`. Cần đăng nhập CLI tài khoản có quyền project mới hoặc cấp IAM phù hợp trước deploy. Không chọn project cũ làm thay thế.

Cập nhật sau khi chủ project tạo dịch vụ: Auth probe đã thành công; Firestore hiện trả `The caller does not have permission`. Các lỗi khởi tạo phía trên là kết quả kiểm tra trước đó. Chạy `firebase login --reauth` bằng tài khoản có quyền project mới; xác nhận Email/Password và Blaze trước deploy. Backend emulator đã kiểm thử thành công cả OpenAlex với key được cung cấp và Crossref.

Cập nhật mới nhất: CLI đã có quyền project đúng, database `(default)` ở `nam5` đã đọc được. Rules và hai chỉ mục trong repo đã deploy thành công. Tạo OpenAlex secret bị Firebase từ chối vì project chưa ở Blaze; Functions, scheduler và cloud secrets chưa deploy. Chủ project cần kiểm tra billing tại https://console.firebase.google.com/project/fap-attendance-88920/usage/details. Tài khoản/role/lớp thật vẫn cần được cấp theo bước 6; không dùng seed emulator trên cloud.

Chạy build/local Firebase config sau khi các dịch vụ được bật:

```powershell
flutter run --dart-define-from-file=config/lab2.production.json
```

Cloud chưa có backend/Rules/profiles của Lab 2 được triển khai; config app không tự tạo những tài nguyên này. Mật khẩu/UID demo chỉ tồn tại ở emulator, không dùng để đăng nhập project thật.

Gửi project ID và file cấu hình công khai Android `google-services.json`, hoặc các trường `projectId`, `apiKey`, `appId`, `messagingSenderId`. Package Android hiện tại: `vn.edu.fpt.lecturer_companion`. Không gửi service account private key, password hoặc OAuth client secret.

1. Bật Authentication Google và Firestore trên project đúng; đăng ký SHA-1/SHA-256 debug/release. Google server client ID phải thuộc Firebase project này, không tự dùng client ID Apps Script cũ. Giữ provider khác nếu client khác vẫn cần chúng.
2. Copy `config/lab2.production.example.json` sang `config/lab2.production.json`, điền cấu hình. Flutter sử dụng FirebaseOptions từ dart-defines; không bịa `firebase_options.dart` cho project thật. Khi cần iOS, dùng FlutterFire CLI tạo cấu hình iOS đúng và kiểm tra trên macOS.
3. Chuẩn bị billing Cloud Functions/Cloud Scheduler theo project và budget alerts. Chưa deploy hoặc thay đổi dữ liệu cloud trong lượt triển khai này.
4. Đặt hai secret bằng CLI:

```powershell
firebase functions:secrets:set QR_SIGNING_SECRET --project <project-id>
firebase functions:secrets:set OPENALEX_API_KEY --project <project-id>
```

QR_SIGNING_SECRET cần giá trị ngẫu nhiên mạnh, giữ ở Secret Manager. Optional `CROSSREF_MAILTO` đặt trong `functions/.env.<project-id>` để dùng polite pool. Cấu hình `.env` chỉ ở backend, không đưa secret vào `config/*.json` của Flutter.

5. Khi project và quyền deploy sẵn sàng, operator triển khai:

```powershell
cd functions
npm ci
npm run build
cd ..
firebase deploy --only firestore,functions --project <project-id>
flutter run --dart-define-from-file=config/lab2.production.json
```

6. Operator tạo Auth users và profile `users/{uid}` với role/active/subjectIds; tạo subjects/classes/members theo DATA_DICTIONARY. Student UID là Firebase Auth UID, MSSV ở `studentCode`. Client không tự tạo hoặc sửa role. Giảng viên có `lecturerUids`, sinh viên có member active và `studentUids` server-managed nhất quán. Không chạy seed demo lên cloud.

App Check enforcement là tùy chọn: chưa cấu hình App Check client trong bản này; không bật `ENFORCE_APP_CHECK=true` trước khi bổ sung provider client và đăng ký ứng dụng. Không tuyên bố production đã được harden đầy đủ.

## CSV và Google Sheets

CSV import là operator tool với preview trước:

```powershell
node scripts/import-roster.cjs roster.csv
# Chỉ emulator, sau khi sửa hết row errors:
node scripts/import-roster.cjs roster.csv --apply
```

Header: `classCode,studentCode,fullName,email`. Email tùy chọn. UID chưa có được lưu ở `pendingEnrollments` và phải operator resolve; không suy ra role từ email. Tool báo lỗi trùng MSSV/lớp, thiếu cột, email sai, lớp không unique. Giữ `enrolledAt` khi import lại. Áp dụng production cần quy trình operator được review; bản tool này từ chối cloud.

Xuất CSV trong Lớp → Thống kê → Xuất CSV; dữ liệu normalized, BOM UTF-8, CRLF, quoting, phòng formula injection. Share sheet Android cho lưu/chia sẻ tệp; không tự ghi vào FAP. Google Sheets live sync chưa triển khai P1; cần spreadsheet ID, mapping columns và quyền backend khi bạn muốn làm tiếp.

## Kiểm thử và build

```powershell
flutter analyze
flutter test
cd functions
npm test
cd ..
.\scripts\start-lab2-backend.ps1 -Test
flutter build apk --debug --dart-define-from-file=config/lab2.emulator.json
flutter test integration_test/lab2_smoke_test.dart -d <android-device-id> --dart-define-from-file=config/lab2.emulator.json
```

External smoke (opt-in, emulator đã seed và đang chạy): `cd functions; node --test test/news-live.cjs`. Không nằm trong test offline mặc định vì phụ thuộc mạng/quota. Production release yêu cầu signing config riêng và smoke test project thật.
