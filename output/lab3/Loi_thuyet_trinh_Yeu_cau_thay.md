# Thuyết trình công nghệ và demo Lab 3

Mỗi công nghệ: là gì — nguyên lý — implement ở đâu — demo. Phần còn thiếu phải nêu là kế hoạch, không phải kết quả.

## Slide 1: PRM393  /  LAB 3

Em trình bày FAP Attendance, hệ thống ba client: mobile và desktop cho giảng viên, web cho sinh viên. Bản rà soát ngày 5 tháng 11 dựa trên code vừa pull. Em phân biệt phần đã triển khai, kiểm thử local đã chạy và phần còn cần bằng chứng vận hành.

## Slide 2: Hệ thống và các công nghệ sử dụng

Flutter dùng widget để dựng giao diện, Riverpod cung cấp state và dependency cho MVVM. React dùng component trên web; Vite build bundle, Firebase Hosting phục vụ bundle qua HTTPS. Apps Script xác thực yêu cầu rồi thao tác Sheets. Triển khai: Mobile lib/lab2, Desktop lib/features, Web src/pages và src/lib/api.js, backend/apps_script. Website demo: https://fap-sinhvien.web.app/; cần xác minh bản deploy trước buổi trình bày.

## Slide 3: Tám nội dung demo thầy yêu cầu

Ảnh thầy yêu cầu demo Mobile trực tiếp trên điện thoại, web qua link deploy, chứng minh MVVM, upload hình và nơi lưu, bấm kích hoạt push, nút crash, Google Authentication và công cụ testing Google. Theo PDF v5 đã cung cấp, phần testing chỉ rõ ARTEMIS. Không lấy các test Flutter local thay cho nhật ký ARTEMIS.

## Slide 4: MVVM + Riverpod: phân tách trách nhiệm

Mô hình MVVM tách giao diện, trạng thái và xử lý dữ liệu. View theo dõi provider, gọi controller khi người dùng thao tác. Controller gọi repository/service rồi phát state để UI dựng lại. Mở lib/lab2/session_view_model.dart, và notebook_view_model.dart; AttendanceEditController cũng nằm trong session_view_model.dart.

## Slide 5: Authentication: xác thực tài khoản Google

Firebase Auth xác minh Google credential và cấp UID/phiên đăng nhập. Backend vẫn kiểm role và quyền lớp từ token. Triển khai tại repository.dart và AuthActionsController. Cần Google chooser, hủy, logout, guard và Console Users; lỗi cleanup logout đã được nêu trong báo cáo rà soát.

## Slide 6: Cloud Storage: lưu tệp trong Firebase bucket

Điểm mới quan trọng: ảnh yêu cầu upload hình. Source hiện tại FirebaseReportStorage chỉ chấp nhận tên .xlsx; rules cũng chỉ cho MIME Excel, còn đường dẫn khác bị deny. Vì vậy demo Excel không đủ mục Image Storage mới. Cần service upload JPEG/PNG riêng, UI chọn ảnh/progress/URL, rules theo UID với giới hạn dung lượng và kiểm thử owner/other/anonymous/offline. Tệp ảnh trong chat qua Drive không thay demo ảnh trong Firebase Storage. Đây là phần đề xuất, chưa triển khai trong lần sửa slide.

## Slide 7: FCM: thông báo đẩy tới thiết bị

FCM là push từ máy chủ hoặc Firebase Console tới token thiết bị, khác local notification. App đã có permission, nhận foreground/background/cold start và lịch sử. Nút ở cloud_pages.dart chỉ gọi testToken, không gửi push. Để khớp cách demo bấm nút của thầy, cần endpoint backend xác thực, giới hạn token chính người dùng và rate limit, dùng Firebase Admin phía server; app chỉ gọi endpoint, không nhúng khóa service account. Console Send test message có thể dùng để xác minh cơ chế nhưng chưa thay nút gửi trong app nếu thầy yêu cầu nút đó.

## Slide 8: Analytics: ghi nhận sự kiện sử dụng

Analytics ghi sự kiện để đo thao tác người dùng. CloudTelemetry.event gọi SDK; xem tên sự kiện và tham số ở DebugView. Bảng có bảy sự kiện vì login/logout là hai sự kiện. Không đưa tên/email/MSSV hay nội dung chat vào event.

## Slide 9: Crashlytics: thu thập và chẩn đoán lỗi

Crashlytics gom lỗi và stack trace để chẩn đoán. Nút fatal đã có trong cloud_pages.dart, gọi CloudTelemetry.demoCrash; chỉ hiện khi ENABLE_LAB3_DEMO bật. Xác nhận crash sau khi lưu dữ liệu rồi mở lại app để gửi báo cáo. Cần kiểm Console đã nhận, không chỉ quay cảnh ứng dụng đóng.

## Slide 10: Remote Config: đổi hành vi mà không rebuild

Remote Config phân phối tham số từ server. Service fetch/activate, ViewModel đưa state vào UI; khi offline dùng cache/default. Chỉ ra hai tham số trong code và Console, thay giá trị rồi tải lại không rebuild. Native smoke trước đây không thay lần demo mới.

## Slide 11: Cộng tác nhóm: gửi, nhận và xem có xác nhận

Giảng viên chia nhóm; sinh viên chỉ xem nhóm được phân công. Chat có bubble, thời gian gửi từ server và trạng thái nhận, xem dựa trên xác nhận thiết bị. Tệp giới hạn 500 KB và kiểm quyền theo nhóm. Ảnh trên slide dùng dữ liệu mẫu để minh họa bố cục. Chat cập nhật mỗi 10 giây; receipt hiện được phát từ web mới.

## Slide 12: Các thay đổi mới và phạm vi đồng bộ

Ba bổ sung mới: đăng ký nhóm qua Google Sheets có kiểm phiên bản; mobile và desktop đọc kế hoạch chung, web cần tải lại sau đồng bộ. Mobile có màn giao việc và thống kê; web có hộp thông báo, đánh dấu đọc, polling 30 giây. Desktop chưa có màn giao việc. Email cần setup và trigger chủ script; thông báo web và email không thay FCM. Dự tính FE/PE có trên cả ba client, dùng điểm nhập tay và trọng số để tìm tổng lớn hơn 5; không tự ghi điểm, không bảo đảm điều kiện qua môn theo mọi đề cương. Ảnh bên trái chỉ minh họa skeleton bằng dữ liệu mẫu.

## Slide 13: Testing: kiểm thử tự động và ARTEMIS

Flutter test dùng fake/service để kiểm logic và widget; backend test mô phỏng Apps Script; Storage emulator kiểm rules. ARTEMIS là phần kiểm thử đầu cuối Android được chỉ rõ trong tài liệu Google của thầy: chuẩn bị ca, chạy trên thiết bị, kiểm giá trị quan sát và lưu logs. Dự án có kế hoạch nghiệm thu nhưng chưa có đủ kết quả ≥10 ca mỗi ca ≥3 lần và khám phá 15–30 phút. Không gọi 285 unit/widget tests là 285 lượt ARTEMIS.

## Slide 14: Kế hoạch demo và các phần cần bổ sung

Tóm tắt đúng phạm vi: đã có source Auth, Crashlytics, FCM nhận, Analytics, Remote Config và Storage báo cáo. Theo ảnh mới còn cần upload hình, nút gửi push và ARTEMIS tích hợp/chạy. Sau đó thu Console evidence. Slide trình bày công nghệ và vị trí implement; demo thực chứng minh các thao tác. Không tuyên bố phần đề xuất là đã hoàn thành.
