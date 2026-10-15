# Áp dụng proto-persona vào UI

Ngày 15/10/2026. Căn cứ [persona](../ux/persona.md) và [ma trận thiết kế](../design/design-decisions.md). Đây là triển khai giả thuyết thiết kế; không biến proto-persona thành persona đã xác thực.

## Thay đổi

| Luồng | Thay đổi | Mục đích |
|---|---|---|
| P01 / F01–F02 | Gộp QR/Sinh viên, tìm kiếm và bộ lọc thành header tự đo chiều cao; ghim khi cửa sổ cao ≥600dp và bàn phím đóng. Trạng thái có số đếm; hiển thị số kết quả/tổng roster | Tìm người khi cuộn lớp đông và đối chiếu bộ lọc |
| P02 / F02 | Form có tên, MSSV, lớp/slot khi caller có dữ liệu; lựa chọn trực tiếp bốn trạng thái; lý do bắt buộc, lỗi giữ input, submit khóa khi ghi | Tránh sửa nhầm và hiểu kết quả |
| N04 / F02 | Khi lỗi tải giữ nhãn Dữ liệu cũ cạnh controls; mất quyền vẫn gỡ dữ liệu phiên theo xử lý hiện hành | Không nhầm số liệu cũ là vừa đồng bộ |
| P03 / F03 | Tìm sổ tay theo nhãn/lớp/môn/học kỳ/ngày ISO hoặc dd/MM; xếp cập nhật mới trước; empty/clear search và mở đúng khóa sổ tay | Tìm lại đúng buổi cùng môn |
| P03 / N04 | Thu gọn header sổ tay, giữ trạng thái lưu; trợ giúp về lưu local trong app bar; bổ sung scroll padding khi nhập | Dễ tiếp cận nội dung, hiểu giới hạn thiết bị |

Header có GlobalKey để giữ State/focus của tìm kiếm khi bàn phím mở/đóng và chuyển giữa pinned/scrolling. Không giữ QR cũ khi expiry/denial. Tên/MSSV/bối cảnh chỉ để hiển thị; request sửa attendance vẫn gửi sessionId, studentUid, status, notes qua API hiện hành.

## Kiểm tra

Test mới trong persona_ui_test.dart kiểm form ở 360dp, chữ 200%, ngang và bàn phím; payload không thêm trường nhận diện; roster 60 người giữ tìm kiếm và focus; mở editor đúng người; tìm ngày dd/MM và mở lại đúng ghi chú. Regression hiện có kiểm QR expiry/denial, chốt phiên, write failure và autosave.

Ảnh fixture tại build/phase2-ui, build/assistant-ui và build/ui-previews. Không dùng fixture làm bằng chứng nghiên cứu người dùng. Kết quả kiểm tra cuối được ghi bên dưới sau khi chạy xong.

## Giới hạn

Chưa thực hiện T01–T03 với giảng viên, chưa nghiệm thu TalkBack và hiệu năng trên thiết bị thật. Build không xác nhận OAuth đã sửa hoặc backend production chạy E2E. Sổ tay vẫn lưu riêng trên máy; không có đồng bộ đa thiết bị.

Kết quả cuối: flutter analyze sạch; flutter test qua 157/157; build APK debug với config/lab2.free.json thành công; bộ render UI 23 test và render form 9 test qua; git diff --check qua. Đã xem ảnh phiên Sinh viên và form lỗi có tên/MSSV/lớp/slot.
