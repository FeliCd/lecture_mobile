# Nghiên cứu UI đợt 2 — 15/10/2026

Trạng thái: hai mục P1 đã triển khai trong [UI_PHASE2_IMPLEMENTATION.md](UI_PHASE2_IMPLEMENTATION.md); P2/P3 vẫn là đề xuất. Đây là nghiên cứu từ source và ảnh render, không phải kết quả khảo sát giảng viên hoặc đo usability trên thiết bị thật. Đợt Hôm nay/Sổ tay đã được mô tả riêng trong ASSISTANT_UI_UPDATE.md.

## Phát hiện và thứ tự ưu tiên

| Ưu tiên | Bằng chứng hiện tại | Thay đổi đề xuất | Cách nghiệm thu |
|---|---|---|---|
| P1 | ClassPage dùng AppBar “Chi tiết lớp”; nội dung lớp không được nhận diện đồng nhất giữa các tab. Tab Sinh viên đặt hai công cụ import/quản trị trước tổng quan. | AppBar hiện mã lớp; khối ngắn môn/học kỳ/sĩ số từ dữ liệu đã tải. Chuyển import và sửa dữ liệu vào menu có nhãn Công cụ lớp. Giữ bốn tab hiện có. | Đổi tab vẫn nhận ra lớp/môn/kỳ. Một lần chạm mở công cụ; mất quyền/lỗi tải không hiện dữ liệu lớp cũ. Sĩ số thiếu hiển thị chưa có dữ liệu. |
| P1 | LiveAttendance có QR lớn phía trên danh sách; trên điện thoại, tìm và sửa sinh viên cần cuộn. Nút chốt phiên cố định và xác nhận đã có. | Hai chế độ “Mã QR” và “Sinh viên”, dùng chung header môn/lớp/slot/phòng, trạng thái phiên và số đã điểm danh/tổng đủ điều kiện. Giữ thanh chốt phiên cố định. Có thể mở QR lớn bằng thao tác rõ ràng. | Đổi chế độ một lần chạm; nhập tìm kiếm giữ nguyên khi đổi chế độ. QR hết hạn/dữ liệu lỗi vẫn bị ẩn theo logic hiện có. Không coi đã hết QR là đã chốt phiên. Sửa attendance giữ lý do/audit. |
| P2 | Lịch dạy đặt nút Nhập thời khóa biểu trước tiêu đề/ngày; có bộ lọc thu gọn, chọn ngày/tuần và cảnh báo trùng giờ. | Đưa ngày/tuần đang xem lên trước; gom điều hướng tuần, Hôm nay và lịch ngày thành một khối. Import là thao tác phụ. Hiển thị bộ lọc đang áp dụng và nút xóa khi có lọc môn. | Chọn ngày và trở về Hôm nay dễ tìm, không đổi học kỳ ngầm. Lọc không làm mất trạng thái hủy/trùng giờ. Ngày trống khác với lỗi tải. |
| P2 | ClassAttendanceOverview đã có tìm kiếm, bộ lọc ngưỡng và trạng thái thiếu dữ liệu; thẻ từng sinh viên hiển thị toàn bộ số đếm, tỷ lệ và cảnh báo. Có chữ phụ 10–12. | Danh sách gọn gồm tên, MSSV, tỷ lệ/trạng thái; mở rộng để xem số lượt và cơ sở tính. Tăng độ đọc chữ phụ, giữ chữ lớn theo hệ thống. Nhãn cảnh báo phải khớp policy thực tế. | Không dùng màu làm dấu hiệu duy nhất; thiếu policy vẫn là chưa đủ cấu hình. Không biến cảnh báo chuyên cần thành kết luận học yếu/cấm thi. |
| P3 | Layout chính và các trang vẫn thiên về một cột điện thoại. | Theo chiều rộng khả dụng: điện thoại một cột; cửa sổ rộng dùng navigation rail và có thể chia danh sách/chi tiết. Chọn breakpoint sau thử nội dung thực tế. | Không kéo thẻ rộng hết màn hình tablet. Xoay/ngắt cửa sổ vẫn giữ lớp, tab, ngày và tìm kiếm. Không thêm destination chỉ vì còn khoảng trống. |

## Phác thảo cấu trúc

Trang lớp:

```
← SE1928                         Công cụ lớp
PRM393 · Fall 2026 · 32 sinh viên
[Sinh viên] [Điểm danh] [Buổi học] [Thống kê]
Nội dung tab hiện hành
```

Phiên điểm danh:

```
← PRM393 · SE1928 · Slot 1
Phòng A201     Đang mở · Còn 08:15
27/32 đã điểm danh · 5 còn chờ
[Mã QR] [Sinh viên]
Nội dung chế độ hiện hành
              [Kết thúc và chốt điểm danh]
```

Các số trên là minh họa bố cục, không phải dữ liệu thật. Không lấy số liệu của một phiên để hiển thị thành tỷ lệ cả học kỳ. Phân biệt số phiên đã chốt, số lượt điểm danh và sĩ số roster.

## Nguyên tắc giữ xuyên suốt

- Cam làm nổi bật hành động chính/đối tượng đang chọn; đỏ dành cho lỗi và thao tác chốt/xóa có hậu quả. Trạng thái luôn có chữ/icon.
- Mỗi màn hình ưu tiên một tác vụ; công cụ ít dùng vẫn có nhãn dễ tìm và có thể mở bằng một lần chạm, không giấu toàn bộ vào icon không nhãn.
- Giữ trạng thái đang tải, dữ liệu cũ, lỗi, chưa có dữ liệu và không có kết quả lọc riêng biệt. Không đặt số 0 vào dữ liệu chưa tải được.
- Giữ các bảo vệ hiện hành: QR expiry, lỗi mạng khi ghi, xác nhận chốt, audit/lý do chỉnh sửa, bản nháp và phân quyền backend.
- Thử ít nhất 360/393/800 logical px; sáng/tối; chữ 1.0/1.8/2.0; bàn phím mở; tên dài; 0/1/nhiều sinh viên; mất mạng và QR hết hạn. Kiểm tra vùng chạm, nhãn semantics và tương phản bằng Flutter Accessibility Guideline API, kết hợp TalkBack trên máy thật.

## Cơ sở tham khảo

- Flutter: https://docs.flutter.dev/ui/accessibility/ui-design-and-styling — vùng chạm Android tối thiểu 48×48 dp; thiết kế cho chữ lớn và tương phản.
- Flutter: https://docs.flutter.dev/ui/accessibility/accessibility-testing — kiểm tra vùng chạm, nhãn thao tác và tương phản tự động.
- Flutter: https://docs.flutter.dev/ui/adaptive-responsive/general — chọn bố cục theo chiều rộng cửa sổ; navigation bar/rail là các phương án theo không gian khả dụng.

Đây là hướng dẫn nền tảng. Thứ tự ưu tiên và thiết kế cụ thể phía trên là đánh giá từ source của dự án, cần xác nhận bằng tác vụ thực tế với giảng viên.

## Phạm vi đợt tiếp theo đề xuất

Làm P1 trước: ngữ cảnh lớp + hai chế độ QR/Sinh viên. Chưa thêm dashboard điểm, assignment, AI hay chỉ số chưa có dữ liệu. Rà các tệp classes.dart, live_attendance.dart, class_attendance_overview.dart và kiểm thử hiện hành trước khi sửa; sau đó render lại các màn liên quan, chạy analyze/regression và thử Android thật. Đợt nghiên cứu này chỉ thêm tài liệu, không chạy lại build/test vì chưa đổi source.
