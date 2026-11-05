# Lời thuyết trình — cập nhật 05/11/2026

Khoảng 8 phút; dùng lớp và tài khoản test. Chỉ trình diễn thao tác cloud đã kiểm tra trước.

## Slide 1 — Mở đầu (25 giây)

Em trình bày FAP Attendance, hệ thống ba client: mobile và desktop cho giảng viên, web cho sinh viên. Bản rà soát ngày 5 tháng 11 dựa trên code vừa pull. Em phân biệt phần đã triển khai, kiểm thử local đã chạy và phần còn cần bằng chứng vận hành.

## Slide 2 — Bài toán và phạm vi (30 giây)

Ba client hiện cấu hình cùng URL Apps Script. Backend kiểm vai trò, lớp và thành viên; sinh viên chỉ đọc điểm đã công bố. Đây là bằng chứng cấu hình và source, chưa chứng minh phiên bản đang deploy đã đồng bộ. Các bộ Apps Script mở rộng nằm trong repository mobile; bản backend desktop chỉ có bộ nền cũ nên không dùng riêng bộ đó để thay toàn bộ deployment.

## Slide 3 — Ba luồng chính (40 giây)

Luồng một là chọn đúng buổi và mở hoặc tiếp tục phiên. Nếu mất phản hồi khi mở, app yêu cầu kiểm tra lại server. Luồng hai là sửa điểm danh với lý do: giữ input khi lỗi và không cho lưu trùng. Luồng ba là sổ tay theo buổi, có tự lưu và thử lại. Sổ tay hiện lưu trên thiết bị theo tài khoản, chưa đồng bộ đa thiết bị.

## Slide 4 — Kiến trúc MVVM (40 giây)

Widget giữ phần nhập liệu và điều hướng. Riverpod ViewModel giữ trạng thái đang xử lý, lỗi và tác vụ. Repository và service thực hiện I/O. Ba controller tương ứng là SessionOpeningController, AttendanceEditController và NotebookController. Auth và quyền push cũng có controller riêng. Việc tách này cho phép dùng service giả để kiểm tra lỗi mà không ghi dữ liệu lớp thật.

## Slide 5 — Authentication (30 giây)

AuthActionsController chặn thao tác trùng và router theo authStateChanges. Backend kiểm quyền sau xác thực. Rà soát hiện thấy chuỗi logout await tuần tự: nếu reminders hoặc Google signOut lỗi, bước xóa token và telemetry phía sau có thể không chạy. Cần sửa cleanup độc lập và test lỗi từng bước trước khi khẳng định logout hoàn chỉnh. Console Users và video login, hủy, offline, logout vẫn cần bổ sung.

## Slide 6 — Cloud Storage (30 giây)

Báo cáo Excel upload theo Firebase UID, hiển thị tiến độ và URL. Preflight hiện đã xác nhận cấu hình Android khớp; nhận định cũ thiếu google-services.json không còn đúng trên máy này. Storage rules emulator pass một suite gồm các nhánh quyền và validation. Metadata probe chỉ cho biết phản hồi dịch vụ, không chứng minh quyền upload. Chưa chạy upload cloud thật hoặc xác minh billing/rules deploy trong đợt này.

## Slide 7 — Cloud Messaging (40 giây)

FCM có ba nhánh: foreground, background và khi ứng dụng đã đóng. Trung tâm thông báo giữ lịch sử theo UID. Cập nhật mới hiển thị quyền hiện tại, chặn mở prompt trùng và kiểm lại khi quay về từ cài đặt Android. Chạm push chỉ điều hướng tới route cho phép. Cần thử gửi Console ở cả ba trạng thái; nhắc lịch local không thay bằng chứng FCM.

## Slide 8 — Analytics (30 giây)

Kế hoạch event được viết trước khi tích hợp. Bảng có bảy event vì login và logout là hai sự kiện. Mục tiêu là quan sát bước người dùng hoàn thành, không thu nội dung cá nhân. Event ghi dữ liệu chỉ gửi sau phản hồi server thành công. Cần mở DebugView để kiểm từng event và tham số.

## Slide 9 — Crashlytics (30 giây)

Crashlytics ghi lỗi đã xử lý và lỗi toàn cục, kèm Firebase UID cùng operation và app_mode. Nội dung nhạy cảm không được đưa vào raw exception gửi đi. Bản demo có nút non-fatal và crash cần xác nhận. Chỉ thử khi đã lưu dữ liệu, sau đó mở lại app và đối chiếu Console. Hiện chưa có đủ ảnh Console để đánh dấu hoàn tất.

## Slide 10 — Remote Config (40 giây)

Hai tham số là subject_updates_enabled và subject_updates_page_size. UI hiển thị nguồn và thời điểm fetch; khi lỗi giữ cache/default. Native smoke nhận remote là kết quả lịch sử ngày 2 tháng 11, không phải kiểm thử bản pull hôm nay. Cần quay thay giá trị trên Console và quan sát UI không rebuild, sau đó kiểm offline/cache.

## Slide 11 — Nhóm học tập (30 giây)

Giảng viên chia nhóm; sinh viên chỉ xem nhóm được phân công. Chat có bubble, thời gian gửi từ server và trạng thái nhận, xem dựa trên xác nhận thiết bị. Tệp giới hạn 500 KB và kiểm quyền theo nhóm. Ảnh trên slide dùng dữ liệu mẫu để minh họa bố cục. Chat cập nhật mỗi 10 giây; receipt hiện được phát từ web mới.

## Slide 12 — Thay đổi mới và đồng bộ (45 giây)

Ba bổ sung mới: đăng ký nhóm qua Google Sheets có kiểm phiên bản; mobile và desktop đọc kế hoạch chung, web cần tải lại sau đồng bộ. Mobile có màn giao việc và thống kê; web có hộp thông báo, đánh dấu đọc, polling 30 giây. Desktop chưa có màn giao việc. Email cần setup và trigger chủ script; thông báo web và email không thay FCM. Dự tính FE/PE có trên cả ba client, dùng điểm nhập tay và trọng số để tìm tổng lớn hơn 5; không tự ghi điểm, không bảo đảm điều kiện qua môn theo mọi đề cương. Ảnh bên trái chỉ minh họa skeleton bằng dữ liệu mẫu.

## Slide 13 — Kết quả kiểm thử (35 giây)

Kiểm tra ngày 5 tháng 11: mobile 285 test, desktop 96, web 59 gồm 55 Vitest và 4 migration, backend 141. Analyzer Flutter sạch; build APK debug, Windows release và web production thành công. Storage emulator một suite pass. Không cộng các số khác loại thành tỷ lệ đạt Lab. Chưa chạy lại native smoke, chưa có đủ 30 lượt ARTEMIS và bằng chứng Console cho bản mới.

## Slide 14 — Kết luận (25 giây)

Kết luận: source có sáu SDK Firebase, ba luồng chính có ViewModel và các client build thành công. Chưa thể tuyên bố hoàn thành toàn bộ Lab 3. Còn phải thu Console evidence, chạy ít nhất 10 ca ARTEMIS ba lần cùng phiên khám phá 15–30 phút, và review PR với ít nhất 5 phát hiện thuộc hai nhóm, sửa ít nhất ba có commit. Hồ sơ cần GitHub, Figma, báo cáo PDF 8–12 trang, slide PDF 12–15 trang và video 5–10 phút. Em xin demo bằng lớp test và nhận góp ý.

## Chuẩn bị trước buổi trình bày

- Mở sẵn Mobile, Desktop, web và lớp test; kiểm cùng lớp/nhóm.
- Demo mở phiên → sửa điểm danh có lý do → sổ tay; không ghi dữ liệu lớp thật.
- Với nhóm: SV chọn nhóm → chủ script sync → giảng viên xem → SV tải lại → chat/giao việc.
- Console: chuẩn bị Auth Users, Storage upload, FCM 3 trạng thái, DebugView ≥7 event, Crashlytics, Remote Config trước/sau và offline.
- Báo cáo PDF cũ chưa cập nhật cùng bản code; không nộp như hồ sơ nghiệm thu mới.
