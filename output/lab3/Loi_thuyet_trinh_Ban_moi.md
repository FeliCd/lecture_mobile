# Lời thuyết trình Lab 3

Khoảng 8–10 phút; xem kịch bản demo riêng để chuẩn bị thao tác.

## Slide 1 — PRM393  /  LAB 3

Em xin trình bày FAP Attendance, hệ thống ba client. Nội dung tập trung vào công nghệ: nó là gì, nguyên lý hoạt động, chỗ triển khai và demo. Mobile và Desktop dành cho giảng viên, Student Web dành cho sinh viên. Những kiểm tra còn thiếu được nêu đúng phạm vi.

Nguồn: docs/LAB3_COMPLETION_SETUP.md; testing/artemis/README.md; logs local 05/11/2026; ảnh yêu cầu và PDF Lab3 v5.

## Slide 2 — Hệ thống và các công nghệ sử dụng

Flutter dùng widget để dựng giao diện, Riverpod cung cấp state và dependency cho MVVM. React dùng component trên web; Vite build bundle, Firebase Hosting phục vụ bundle qua HTTPS. Apps Script xác thực yêu cầu rồi thao tác Sheets. Triển khai: Mobile lib/lab2, Desktop lib/features, Web src/pages và src/lib/api.js, backend/apps_script. Website demo: https://fap-sinhvien.web.app/; cần xác minh bản deploy trước buổi trình bày.

Nguồn: ảnh yêu cầu demo và lời giải thích của thầy do người dùng cung cấp; PDF Lab3 v5; docs/LAB3_TEACHER_DEMO_ADDENDUM.md; code đã rà soát 05/11/2026.

## Slide 3 — Tám nội dung demo thầy yêu cầu

Theo ảnh yêu cầu thầy, em chuẩn bị Mobile trên điện thoại, web deploy, kiến trúc MVVM, upload ảnh, push, crash, Google Auth và công cụ testing Google. Lần phát triển đã kiểm trên emulator; điện thoại thật cần kiểm trước buổi trình bày. Không dùng thao tác demo để khẳng định mọi tiêu chí đã nghiệm thu.

Nguồn: docs/LAB3_COMPLETION_SETUP.md; testing/artemis/README.md; logs local 05/11/2026; ảnh yêu cầu và PDF Lab3 v5.

## Slide 4 — MVVM + Riverpod: phân tách trách nhiệm

Mô hình MVVM tách giao diện, trạng thái và xử lý dữ liệu. View theo dõi provider, gọi controller khi người dùng thao tác. Controller gọi repository/service rồi phát state để UI dựng lại. Mở lib/lab2/session_view_model.dart, và notebook_view_model.dart; AttendanceEditController cũng nằm trong session_view_model.dart.

Nguồn: ảnh yêu cầu demo và lời giải thích của thầy do người dùng cung cấp; PDF Lab3 v5; docs/LAB3_TEACHER_DEMO_ADDENDUM.md; code đã rà soát 05/11/2026.

## Slide 5 — Authentication: xác thực tài khoản Google

Firebase Auth xác minh Google credential và cấp UID/phiên đăng nhập. Backend vẫn kiểm role và quyền lớp từ token. Triển khai tại repository.dart và AuthActionsController. Cần Google chooser, hủy, logout, guard và Console Users; lỗi cleanup logout đã được nêu trong báo cáo rà soát.

Nguồn: ảnh yêu cầu demo và lời giải thích của thầy do người dùng cung cấp; PDF Lab3 v5; docs/LAB3_TEACHER_DEMO_ADDENDUM.md; code đã rà soát 05/11/2026.

## Slide 6 — Cloud Storage: lưu tệp trong Firebase bucket

Firebase Storage lưu đối tượng trong bucket. View chọn ảnh bằng FilePicker, imageUploadProvider quản lý busy/progress/error, FirebaseReportStorage(image:true) tải bytes theo Firebase UID và lấy URL. Service kiểm header PNG/JPEG, rules kiểm UID/email verified, MIME/kích thước và chống overwrite. Đã upload ảnh cam mẫu không có dữ liệu cá nhân, app báo thành công và Storage API xác nhận một object image/png. Khi demo chọn ảnh đó, chỉ đường dẫn images/{uid}, mở Console để đối chiếu. Không đưa bearer download token vào slide hoặc video công khai.

Nguồn: docs/LAB3_COMPLETION_SETUP.md; testing/artemis/README.md; logs local 05/11/2026; ảnh yêu cầu và PDF Lab3 v5.

## Slide 7 — FCM: nút gửi thử và luồng nhận thông báo

Nút gửi gọi service, callable kiểm Auth/email verified/UID allowlist và rate limit rồi Firebase Admin gửi FCM. Nút trễ 15 giây cho phép về Home hoặc vuốt khỏi Recent trước khi server gửi; backend đã deploy. Đã quan sát banner mới trong app. Background và cold start phải thử thực tế trước buổi demo. Force stop khác vuốt Recent và có thể ngăn nhận. Chạm notification phải mở đúng màn. Không gọi accepted là receipt; không giả lập local notification thay FCM. Cho thầy xem demo_push.dart, demo-push.ts và push_notifications.dart.

Nguồn: docs/LAB3_COMPLETION_SETUP.md; testing/artemis/README.md; logs local 05/11/2026; ảnh yêu cầu và PDF Lab3 v5.

## Slide 8 — Analytics: ghi nhận sự kiện sử dụng

Analytics ghi sự kiện để đo thao tác người dùng. CloudTelemetry.event gọi SDK; xem tên sự kiện và tham số ở DebugView. Bảng có bảy sự kiện vì login/logout là hai sự kiện. Không đưa tên/email/MSSV hay nội dung chat vào event.

Nguồn: ảnh yêu cầu demo và lời giải thích của thầy do người dùng cung cấp; PDF Lab3 v5; docs/LAB3_TEACHER_DEMO_ADDENDUM.md; code đã rà soát 05/11/2026.

## Slide 9 — Crashlytics: thu thập và chẩn đoán lỗi

Crashlytics gom lỗi và stack trace để chẩn đoán. Nút fatal đã có trong cloud_pages.dart, gọi CloudTelemetry.demoCrash; chỉ hiện khi ENABLE_LAB3_DEMO bật. Xác nhận crash sau khi lưu dữ liệu rồi mở lại app để gửi báo cáo. Cần kiểm Console đã nhận, không chỉ quay cảnh ứng dụng đóng.

Nguồn: ảnh yêu cầu demo và lời giải thích của thầy do người dùng cung cấp; PDF Lab3 v5; docs/LAB3_TEACHER_DEMO_ADDENDUM.md; code đã rà soát 05/11/2026.

## Slide 10 — Remote Config: đổi hành vi mà không rebuild

Native smoke chạy lại trong lần này đã pass: SDK Firebase khởi tạo và hai tham số trả nguồn valueRemote, values true và 20. Điều này chứng minh fetch native, chưa thay video publish thay đổi giá trị rồi thấy UI cập nhật mà không rebuild hoặc kiểm cache khi offline.

Nguồn: docs/LAB3_BLAZE_RECHECK.md; logs tmp/blaze-*.log; ảnh thầy và PDF Lab3 v5.

## Slide 11 — Cộng tác nhóm: gửi, nhận và xem có xác nhận

Giảng viên chia nhóm; sinh viên chỉ xem nhóm được phân công. Chat có bubble, thời gian gửi từ server và trạng thái nhận, xem dựa trên xác nhận thiết bị. Tệp giới hạn 500 KB và kiểm quyền theo nhóm. Ảnh trên slide dùng dữ liệu mẫu để minh họa bố cục. Chat cập nhật mỗi 10 giây; receipt hiện được phát từ web mới.

Nguồn: ảnh yêu cầu demo và lời giải thích của thầy do người dùng cung cấp; PDF Lab3 v5; docs/LAB3_TEACHER_DEMO_ADDENDUM.md; code đã rà soát 05/11/2026.

## Slide 12 — ARTEMIS: kiểm thử Android từ yêu cầu mô tả

ARTEMIS là công cụ tự động hóa Android của Google, dùng mô hình để đọc ảnh/UI và thực hiện mục tiêu mô tả. Workflow là goal, quan sát, thao tác, kiểm actual, lưu trace/replay. Đã cài tại C:/PRM/tools/artemis; project có 10 ca và runner chạy mỗi ca ba lần. Cần bổ sung nhánh lỗi, Android native và khám phá 15–30 phút để phủ rubric. Key mới được API models chấp nhận, chưa chứng minh đủ các lượt đã pass. Lượt trước gặp quá tải/quota. Hình bên trái là fixture skeleton của web dùng minh họa kiểm trạng thái loading, không là screenshot ARTEMIS.

Nguồn: docs/LAB3_COMPLETION_SETUP.md; testing/artemis/README.md; logs local 05/11/2026; ảnh yêu cầu và PDF Lab3 v5.

## Slide 13 — Kết quả kiểm chứng và phạm vi còn lại

Kết quả mới: upload ảnh thật thành công, Functions ACTIVE, banner push foreground đã quan sát. Native Firebase/Remote Config một test pass. Ba test controller Flutter, bảy test Functions, rules emulator, analyzer và APK build pass. ARTEMIS đã tích hợp nhưng chưa đủ 30 lượt/logs và phiên khám phá. Giữ nguyên trạng thái chưa đủ bằng chứng thay vì tự báo đạt 100%.

Nguồn: docs/LAB3_COMPLETION_SETUP.md; testing/artemis/README.md; logs local 05/11/2026; ảnh yêu cầu và PDF Lab3 v5.

## Slide 14 — Demo công nghệ và điều kiện nghiệm thu

Sau phần công nghệ, em demo theo thứ tự: Google login và MVVM, upload ảnh/Console, push, Remote Config/Analytics, crash cuối, ARTEMIS và logs. Crash chỉ thực hiện khi đã lưu dữ liệu, mở lại app để gửi report. Chỉ nói hoàn tất các phần thực sự đã chứng minh; điện thoại thật, background/closed, Console evidence và ARTEMIS đủ lượt vẫn phải chốt trước khi nộp. Em xin nhận câu hỏi của thầy.

Nguồn: docs/LAB3_COMPLETION_SETUP.md; testing/artemis/README.md; logs local 05/11/2026; ảnh yêu cầu và PDF Lab3 v5.
