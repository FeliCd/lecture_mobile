# Trợ lý giảng dạy — đợt triển khai đầu

Ngày 13/10/2026. Phạm vi: tính năng cá nhân chạy trên máy, theo backlog F01/F02/F04a. Không coi đây là hoàn tất toàn bộ roadmap.

## Đã có

- Hôm nay → Trợ lý giảng dạy: tạo/sửa việc, hạn theo UTC+7, hoàn thành, hoãn một ngày, xóa và hoàn tác. Việc độc lập hoặc liên kết qua sổ tay một buổi có ngày cụ thể.
- Nhắc Android một lần, trước hạn 0/10/15/30 phút; yêu cầu quyền khi người dùng bấm bật. Yên lặng 22:00–07:00 mặc định, bỏ qua thông báo trong khoảng này. Không xin quyền exact alarm. Android có thể trì hoãn thông báo.
- Thông báo có nội dung chung, mở đúng việc trong tài khoản hiện hành. ID ổn định theo tài khoản/việc; tạo lại lịch sau thay đổi; hủy khi hoàn thành, xóa, đăng xuất hoặc đổi tài khoản. Manifest có receiver phục hồi lịch sau reboot/cập nhật ứng dụng.
- Sổ tay mở từ thẻ Hôm nay/Lịch: mục tiêu, checklist chuẩn bị có đánh dấu, link tài liệu, nội dung đã dạy, việc nối tiếp. Tự lưu từng thay đổi; trạng thái đang lưu/đã lưu/lỗi rõ ràng. Sao chép kế hoạch từ sổ tay cùng môn, giữ phần kết quả riêng của buổi đích.
- Khóa sổ tay gồm học kỳ, lớp, môn, ngày, slot và selector lịch/ngoại lệ; mở điểm danh không đổi khóa của buổi có lịch nguồn.
- Xem trước tổng kết tuần, xuất XLSX gồm metadata, phiên điểm danh có dữ liệu, việc trong tuần và việc chưa xong. Đối chiếu mã phiên/lớp nguồn; chỉ lấy phiên do giảng viên hiện hành phụ trách trong lớp được phân công. Không xuất nội dung sổ tay riêng.

## Dữ liệu và giới hạn

- SharedPreferences lưu JSON version 1, khóa riêng theo hash UID; ghi tuần tự trong store để tránh mất cập nhật khi sửa việc và sổ tay cùng lúc. JSON lỗi/phiên bản lạ gây lỗi rõ ràng, không tự ghi đè. Có revision local cho sổ tay; chưa có đồng bộ/xung đột nhiều thiết bị.
- Đây là lưu cá nhân trên thiết bị, không phải kho dữ liệu mã hóa hoặc backup cloud. Gỡ ứng dụng sẽ mất dữ liệu. Không thêm bảng backend, không thay nguồn Sheets của lịch/điểm danh.
- Nhắc theo ngày được chọn, chưa tự theo lịch dời/hủy. UI nhắc người dùng cập nhật hạn. Chưa lập nhắc hàng loạt theo học kỳ hoặc tắt từng lớp; cần khoảng ngày học kỳ chuẩn và reconciliation lịch trước khi bổ sung.
- Báo cáo dùng snapshot hiện có; không khẳng định snapshot mới nhất trên server. Không suy diễn buổi không có phiên thành bỏ dạy, không quy thời gian QR thành giờ giảng, không tính tổng lịch dự kiến khi chưa có khoảng ngày học kỳ xác nhận. Thiếu slot được xuất “Chưa có dữ liệu”.
- Chưa có PDF, đồng bộ Apps Script, mẫu kế hoạch độc lập hoặc thông báo iOS/web/Windows. Các nền tảng khác vẫn dùng được việc và sổ tay.

## Kiểm tra

- Kết quả cuối: `flutter analyze` không có lỗi; `flutter test` qua 124/124; `git diff --check` qua; build APK debug thành công. Log tại `artifacts/lecturer-mvp-analyze.log`, `artifacts/lecturer-mvp-tests.log`, `artifacts/lecturer-mvp-build.log`.
- Test mới: ghi đồng thời, mở lại dữ liệu, tách tài khoản, không ghi đè version lạ; khóa occurrence ổn định; UTC+7/giờ yên lặng/việc hoàn thành; mock Android scheduling, ID ổn định, từ chối quyền, logout chặn reschedule cũ; lọc quyền và biên tuần; đọc lại XLSX; tự lưu sổ tay; lỗi lưu giữ form trên màn hình 360px với chữ 1.8x.
- Đã build APK debug để kiểm tra tích hợp Android/plugin. Chưa kiểm tra thông báo nền, reboot, tiết kiệm pin, thao tác share Excel hoặc Google login trên thiết bị thật.
- Máy hiện thiếu `config/lab2.free.json`. APK build không có define chỉ xác nhận biên dịch; cần cấu hình shared thực tế theo README để đăng nhập/chạy dữ liệu thật. Không đưa cấu hình production giả vào source.

## Thử thủ công

1. Đăng nhập giảng viên, mở Hôm nay → Trợ lý giảng dạy, tạo việc có hạn tương lai và bật quyền thông báo.
2. Thử hoàn thành/xóa/hoãn, từ chối quyền, giờ yên lặng và đăng xuất/đổi tài khoản; kiểm tra không còn nhắc cũ.
3. Mở sổ tay một buổi, nhập nội dung và đánh dấu checklist, đợi “Đã lưu trên máy”; đóng/mở ứng dụng và đối chiếu. Thử lớp song song cùng môn và sao chép kế hoạch.
4. Mở tổng kết tuần, đối chiếu mã phiên với backend, xuất và mở XLSX. Kiểm tra tuần giao ngày theo UTC+7, phiên chưa chốt và dữ liệu thiếu.
5. Trên Android thật, thử app nền, reboot và tiết kiệm pin trước khi pilot với giảng viên.

Tham khảo tích hợp plugin: README đi kèm `flutter_local_notifications` 22.3.2 và [source chính thức](https://github.com/MaikuB/flutter_local_notifications).
