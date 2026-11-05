# Lời thuyết trình Lab 3 sau kiểm tra cloud

Thời lượng gợi ý 8–10 phút. Mỗi công nghệ: khái niệm → nguyên lý → file/class → demo.

## Slide 1 — PRM393  /  LAB 3

Em trình bày các công nghệ của FAP Attendance theo bốn phần: là gì, nguyên lý hoạt động, vị trí implement và thao tác demo. Bản này cập nhật sau khi project đã nâng Blaze theo thông tin chủ project; em chỉ kết luận các dịch vụ thực sự đã kiểm tra.

Nguồn: docs/LAB3_BLAZE_RECHECK.md; logs tmp/blaze-*.log; ảnh thầy và PDF Lab3 v5.

## Slide 2 — Hệ thống và các công nghệ sử dụng

Flutter dùng widget để dựng giao diện, Riverpod cung cấp state và dependency cho MVVM. React dùng component trên web; Vite build bundle, Firebase Hosting phục vụ bundle qua HTTPS. Apps Script xác thực yêu cầu rồi thao tác Sheets. Triển khai: Mobile lib/lab2, Desktop lib/features, Web src/pages và src/lib/api.js, backend/apps_script. Website demo: https://fap-sinhvien.web.app/; cần xác minh bản deploy trước buổi trình bày.

Nguồn: ảnh yêu cầu demo và lời giải thích của thầy do người dùng cung cấp; PDF Lab3 v5; docs/LAB3_TEACHER_DEMO_ADDENDUM.md; code đã rà soát 05/11/2026.

## Slide 3 — Tám nội dung demo thầy yêu cầu

Chúng em đã kiểm emulator theo lựa chọn của người dùng. Điện thoại thật chưa kết nối nên chưa đánh dấu hoàn tất mục một. Web live trả HTTP 200. Cloud Function đã ACTIVE và cấp allowlist. Image Storage hiện vẫn chỉ có luồng Excel, chưa đạt yêu cầu upload ảnh. ARTEMIS chưa đủ log. Không tự bỏ yêu cầu Analytics/Remote Config trong PDF vì ảnh demo mới không nói loại bỏ chúng.

Nguồn: docs/LAB3_BLAZE_RECHECK.md; logs tmp/blaze-*.log; ảnh thầy và PDF Lab3 v5.

## Slide 4 — MVVM + Riverpod: phân tách trách nhiệm

Mô hình MVVM tách giao diện, trạng thái và xử lý dữ liệu. View theo dõi provider, gọi controller khi người dùng thao tác. Controller gọi repository/service rồi phát state để UI dựng lại. Mở lib/lab2/session_view_model.dart, và notebook_view_model.dart; AttendanceEditController cũng nằm trong session_view_model.dart.

Nguồn: ảnh yêu cầu demo và lời giải thích của thầy do người dùng cung cấp; PDF Lab3 v5; docs/LAB3_TEACHER_DEMO_ADDENDUM.md; code đã rà soát 05/11/2026.

## Slide 5 — Authentication: xác thực tài khoản Google

Firebase Auth xác minh Google credential và cấp UID/phiên đăng nhập. Backend vẫn kiểm role và quyền lớp từ token. Triển khai tại repository.dart và AuthActionsController. Cần Google chooser, hủy, logout, guard và Console Users; lỗi cleanup logout đã được nêu trong báo cáo rà soát.

Nguồn: ảnh yêu cầu demo và lời giải thích của thầy do người dùng cung cấp; PDF Lab3 v5; docs/LAB3_TEACHER_DEMO_ADDENDUM.md; code đã rà soát 05/11/2026.

## Slide 6 — Cloud Storage: lưu tệp trong Firebase bucket

Điểm mới quan trọng: ảnh yêu cầu upload hình. Source hiện tại FirebaseReportStorage chỉ chấp nhận tên .xlsx; rules cũng chỉ cho MIME Excel, còn đường dẫn khác bị deny. Vì vậy demo Excel không đủ mục Image Storage mới. Cần service upload JPEG/PNG riêng, UI chọn ảnh/progress/URL, rules theo UID với giới hạn dung lượng và kiểm thử owner/other/anonymous/offline. Tệp ảnh trong chat qua Drive không thay demo ảnh trong Firebase Storage. Đây là phần đề xuất, chưa triển khai trong lần sửa slide.

Nguồn: ảnh yêu cầu demo và lời giải thích của thầy do người dùng cung cấp; PDF Lab3 v5; docs/LAB3_TEACHER_DEMO_ADDENDUM.md; code đã rà soát 05/11/2026.

## Slide 7 — FCM: nút gửi thử và luồng nhận thông báo

Nút Gửi thông báo thử gọi FirebaseDemoPush qua DemoPushController. Service lấy token từ SDK rồi gọi callable sendLab3DemoPush. Server kiểm Firebase Auth, email verified, UID allowlist và giới hạn 30 giây cho UID/token. Firebase Admin gửi payload cố định. Hàm đã ACTIVE, request không đăng nhập trả 401 và app đã hiển thị accepted. Integration test chưa xác nhận được thông báo mới đến emulator; không lấy tin lịch sử cũ hay accepted làm bằng chứng delivery. Chưa kiểm đủ foreground/background/terminated trên điện thoại thật. Server tin token do tài khoản demo cung cấp; allowlist chỉ dùng cho người demo tin cậy, không phải dịch vụ gửi tùy ý cho sinh viên. App Check hiện chưa enforce; cảnh báo App Check trong log không đồng nghĩa request bị chặn. Backend nghiệp vụ Apps Script vẫn giữ nguyên.

Nguồn: docs/LAB3_BLAZE_RECHECK.md; logs tmp/blaze-*.log; ảnh thầy và PDF Lab3 v5.

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

## Slide 12 — Các thay đổi mới và phạm vi đồng bộ

Ba bổ sung mới: đăng ký nhóm qua Google Sheets có kiểm phiên bản; mobile và desktop đọc kế hoạch chung, web cần tải lại sau đồng bộ. Mobile có màn giao việc và thống kê; web có hộp thông báo, đánh dấu đọc, polling 30 giây. Desktop chưa có màn giao việc. Email cần setup và trigger chủ script; thông báo web và email không thay FCM. Dự tính FE/PE có trên cả ba client, dùng điểm nhập tay và trọng số để tìm tổng lớn hơn 5; không tự ghi điểm, không bảo đảm điều kiện qua môn theo mọi đề cương. Ảnh bên trái chỉ minh họa skeleton bằng dữ liệu mẫu.

Nguồn: ảnh yêu cầu demo và lời giải thích của thầy do người dùng cung cấp; PDF Lab3 v5; docs/LAB3_TEACHER_DEMO_ADDENDUM.md; code đã rà soát 05/11/2026.

## Slide 13 — Kết quả kiểm chứng sau nâng cấp Firebase

Các số trên slide là kết quả kiểm mới, không trộn với toàn bộ unit test cũ. Hai test controller Flutter và bảy test Functions pass. Native SDK/Remote Config pass một test. Live FCM chưa pass khâu nhận tin mới; phải xem lỗi trong báo cáo. Source vẫn có ARTEMIS acceptance plan nhưng chưa ≥10 ca ×3 lần và khám phá 15–30 phút. Các bộ đầy đủ Mobile 285, Desktop 96, Web 59, backend 141 là kết quả audit trước cùng ngày, không chạy lại toàn bộ trong lần sửa slide này.

Nguồn: docs/LAB3_BLAZE_RECHECK.md; logs tmp/blaze-*.log; ảnh thầy và PDF Lab3 v5.

## Slide 14 — Demo công nghệ và điều kiện nghiệm thu

Thứ tự demo đề xuất: điện thoại thật và link web; giải thích MVVM; Google login; Storage khi hoàn thành upload ảnh; bấm push; mô phỏng crash và kiểm Console; trình bày công cụ testing. Không gây crash khi còn dữ liệu chưa lưu. Cần bổ sung upload ảnh, ARTEMIS và Console evidence trước khi nói đạt đủ. Slide là tài liệu trình bày trạng thái thật, không thay minh chứng ứng dụng chạy.

Nguồn: docs/LAB3_BLAZE_RECHECK.md; logs tmp/blaze-*.log; ảnh thầy và PDF Lab3 v5.
