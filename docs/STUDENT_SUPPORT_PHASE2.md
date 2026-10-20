# Theo dõi và hỗ trợ sinh viên — đợt 2

Ngày 19/10/2026. Tiếp nối mục “Đợt 2 Theo dõi và hỗ trợ sinh viên” trong báo cáo tiến độ Word. Hoàn thành phần mã nguồn dưới đây trong lúc chờ quyền vào backend để triển khai đợt 1. Không đánh dấu P0 hoặc nghiệm thu thật đã hoàn thành.

## Cách dùng

1. Mở **Lớp học → Chi tiết lớp → Sinh viên**.
2. Chọn **Cần theo dõi** để xem sinh viên có cảnh báo từ điểm danh hoặc được giảng viên đánh dấu cần trao đổi.
3. Chạm một sinh viên để xem dữ liệu giải thích, gồm ngày và slot của chuỗi vắng gần nhất.
4. Bấm **Ghi chú riêng**, nhập ghi chú và **Trao đổi buổi sau**, bật **Cần trao đổi** nếu cần rồi **Lưu ghi chú**.
5. Sau trao đổi, bỏ đánh dấu và cập nhật nội dung. Xóa hết cả hai ô và bỏ đánh dấu rồi lưu để xóa ghi chú của sinh viên trong lớp này.

## Quy tắc đã triển khai

- Cần theo dõi khi: vắng từ **hai buổi liên tiếp đã chốt gần nhất**, có cảnh báo chuyên cần theo cấu hình hiện hành, hoặc giảng viên chủ động đánh dấu. Hai buổi là gợi ý hỗ trợ ban đầu để thử nghiệm, không phải quy định học vụ đã xác minh.
- Chuỗi dùng thứ tự `opensAt` của phiên; chỉ đếm trạng thái `absent` từ bản ghi đã chốt. Không lấy thời gian sửa attendance làm ngày học. Phiên mở/hủy không được đếm; các buổi có roster không chứa sinh viên được bỏ qua.
- Có mặt, đi trễ, có phép, thiếu bản ghi hoặc bản ghi trùng ngắt chuỗi. Không suy diễn bản ghi chưa có là vắng. Thiếu thời gian phiên thì không hiển thị cảnh báo chuỗi; thời gian trùng nhau ngắt tại vị trí không xác định được thứ tự.
- Không đổi cách tính tỷ lệ, ngưỡng 15/20 hiện có, dữ liệu điểm danh hay quyền dự thi. Không tự phát tin nhắn cho sinh viên.
- Ghi chú lưu riêng bằng khóa tài khoản, lớp và UID sinh viên, không dùng tên/MSSV làm định danh. Tách khỏi sổ tay buổi học và báo cáo xuất tuần. Đây là dữ liệu cục bộ trên thiết bị, chưa có đồng bộ/khôi phục cloud hoặc chia sẻ cho tài khoản khác. Xóa dữ liệu app/gỡ app có thể làm mất ghi chú.
- Lưu tuần tự để hai ghi chú đồng thời không làm mất nhau. Chỉ đóng form sau khi lưu thành công; lỗi giữ nội dung để thử lại. Không cho sửa nếu ghi chú cũ chưa tải được. Dữ liệu lưu hỏng hoặc khác phiên bản bị từ chối, không bị tự ghi đè.
- Hủy/Back khi nội dung thay đổi có bước xác nhận. Nút lưu chỉ hoạt động khi profile giảng viên đúng tài khoản của form.

## Kiểm chứng

- Toàn bộ Flutter: **181/181 test qua**, gồm bảy kiểm tra mới về thứ tự/ngắt chuỗi, roster, tài khoản/lớp, lưu đồng thời, dữ liệu hỏng, bộ lọc và form ghi chú.
- `flutter analyze --no-pub`: không có vấn đề.
- APK debug với `config/lab2.free.json`: build thành công. Cảnh báo KGP hiện hành không chặn build.
- Đã xem ảnh widget thật với dữ liệu mô phỏng: [Cần theo dõi](../artifacts/student-support-ui/01-follow-up.png), [Dữ liệu giải thích](../artifacts/student-support-ui/02-evidence.png), [Ghi chú chữ lớn](../artifacts/student-support-ui/03-private-note-large.png). Form được kiểm tra chữ 1,8 lần trên khung 393 × 852. Chưa phải kiểm thử với giảng viên hoặc thiết bị thật.
- Log local: `artifacts/student-support-{tests,all-tests,analyze,visual,build}.log`.

## Phần còn chờ trong tài liệu gốc

Kiểm tra API thật ngày 19/10/2026 bằng `lab2Health` cho thấy project `fap-attendance-88920`, đã có cấu hình auth nhưng **chưa công bố `bulkPendingAttendance`**. Kết quả tại `artifacts/backend-live-health.json`. Đây chỉ là health công khai, không chứng minh đăng nhập hoặc ghi dữ liệu thành công.

Apps Script hiện mở dưới tài khoản khác tài khoản quản lý đã xác định trước đó và không có project trong danh sách. Chưa sao lưu/cập nhật deployment, chưa sửa IAM, chưa ghi dữ liệu cloud. Cần đăng nhập tài khoản quản lý đúng backend rồi làm tiếp các mục P0 trong báo cáo Word: sao lưu, cập nhật hai file, đổi phiên bản deployment trên URL cũ, xác nhận capability và chạy T01–T08 bằng dữ liệu thử được phép.

Sau đó pilot với giảng viên để xác nhận tiêu chí hai buổi, cách xử lý buổi bù/hủy và phạm vi ghi chú. Đồng bộ ghi chú/việc cá nhân, nhắc từ backend, QR luân phiên và tích hợp chat vẫn thuộc các đợt sau; chưa triển khai trong đợt này.
