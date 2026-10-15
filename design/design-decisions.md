# Persona → Need → Design → Test

Ngày 15/10/2026. Đây là truy vết bổ sung sau triển khai; không khẳng định persona đã dẫn dắt các thay đổi lịch sử. Accept/Modify/Reject dưới đây là trạng thái quyết định thiết kế, không phải kết quả usability.

## Needs

| ID | Nhu cầu kết quả cần kiểm chứng | Persona |
|---|---|---|
| N01 | Nhận ra đúng buổi và tới đúng phiên nhanh | P01 |
| N02 | Hiểu kết quả thay đổi, đối chiếu và phục hồi không mất input | P02; có thể áp dụng mọi persona |
| N03 | Tìm lại đúng phần cần tiếp nối | P03 |
| N04 | Phân biệt dữ liệu mới/cũ và lưu local | P01/P02/P03 |

## Ma trận quyết định

| ID / trạng thái | Chuỗi truy vết | Quyết định và lý do | Tình trạng / đánh đổi | Kiểm chứng |
|---|---|---|---|---|
| D01 Accept để thử | E02/E07 → P01 → N01 → F01 → S01/S02 | Rút mô tả lặp thành keyword, giữ môn/lớp/slot/phòng | Đã có trong source; tên ngắn có thể khó hiểu với P02; cần trợ giúp đúng chỗ | T01; hỏi nghĩa nhãn sau task |
| D02 Accept | E03 + A01 → P01 → N01 → F01 → S03 | Hai chế độ QR/Sinh viên, giữ tìm kiếm/bộ lọc | Source đã có; giảm cuộn cần đo bằng người dùng | T01/T02; Q02 |
| D03 Accept | E04 + A02 → P02 → N02 → F02 → S03E | Giữ lý do khi lỗi, chặn submit lặp, không đóng sớm | Source đã có; phản hồi timeout phải nêu kết quả chưa chắc chắn | T02; Q01 |
| D04 Reject | E03/E04 → P02 → N02 → F02 → S03/S03E | Không bỏ lý do/audit hoặc xác nhận chốt để giảm số chạm | Ràng buộc nghiệp vụ; không lấy số chạm làm mục tiêu duy nhất | T02; Q01/Q03 |
| D05 Accept để thử | E05 + A03 → P03 → N03 → F03 → S06 | Sổ tay gắn buổi, Before/After, giữ nội dung buổi đích khi tiếp nối | Đã có; thuật ngữ và cách tìm lại chưa được xác thực | T03; Q05/Q06 |
| D06 Modify | E05 + A03 → P03 → N04 → F03 → S06/S07 | Nêu lưu trên máy ở nơi lưu/trợ giúp, không hứa cloud | Đã có nhãn lưu; rút chữ ở Home có thể làm người dùng bỏ sót giới hạn | T03, câu hỏi đa thiết bị |
| D07 Reject trong scope | E01 → P01/P03 → N01/N03 | Không thêm livestream/bảng viết/chat từ ví dụ Teacher Station | Chưa có nhu cầu được ghi nhận trong dự án | Review scope sau nghiên cứu, không thêm chỉ để giống ví dụ |
| D08 Accept để thử | E02/E06 + A05 → P01/P02 → N01/N02 → S01–S07 | Chữ lớn, icon kèm chữ trạng thái, giảm chuyển động theo hệ thống | Có xử lý trong source; TalkBack/thiết bị thật cần nghiệm thu | T01–T03 và checklist screen-spec; Q07 |
| D09 Accept để thử | E05 + A03 → P03 → N03 → F03 → S07/S06 | Tìm sổ tay theo lớp/môn/ngày, ưu tiên cập nhật gần nhất; header ghi chú gọn và trợ giúp lưu local | Đã triển khai sau hồ sơ; chưa đo thời gian tìm lại với giảng viên | T03; Q08 |
| D10 Accept để thử | E03/E04 + A01/A02 → P01/P02 → N01/N02 → F02 → S03/S03E | Giữ thanh tìm/lọc khi đủ chiều cao; thêm số đếm, tên/MSSV và bối cảnh trong form; trạng thái chọn trực tiếp | Đã triển khai; bàn phím/màn thấp dùng controls cuộn, giữ focus; payload nghiệp vụ giữ nguyên | T02; Q08 và Q01–Q03 |

Các nhu cầu do A hỗ trợ vẫn là giả thuyết. E03/E04 có thể buộc giữ cơ chế an toàn dù nhu cầu phân khúc chưa được xác thực.

## Đối chiếu kiểm tra kỹ thuật hiện có

Chỉ đọc source test để lập mapping, không chạy lại trong đợt hồ sơ. Không chuyển kết quả này vào cột kết quả người dùng.

| ID | File và tên test / tình huống | Phạm vi |
|---|---|---|
| Q01 | [nielsen_ui_test.dart](../test/nielsen_ui_test.dart): `failed attendance write keeps reason; pending write cannot be submitted twice` | Input và submit, không đo mức hiểu của giảng viên |
| Q02 | [phase2_ui_test.dart](../test/phase2_ui_test.dart): `live modes preserve search and filter; stale data cannot expose QR or editing` | Trạng thái qua đổi chế độ, stale và QR |
| Q03 | [refactor_live_test.dart](../test/refactor_live_test.dart): `ownership denial clears cached roster and stops automatic requests`; [Nielsen](../test/nielsen_ui_test.dart): `expired QR is hidden even when session is still open` | Denial và expiry ở fixture |
| Q04 | [refactor_live_test.dart](../test/refactor_live_test.dart): `opening Today never creates an attendance session` | Side effect khi chỉ mở màn |
| Q05 | [assistant_ui_test.dart](../test/assistant_ui_test.dart): `carry forward appends once, preserves target and enforces same class/term` | Ràng buộc tiếp nối nội dung |
| Q06 | [lecturer_workspace_test.dart](../test/lecturer_workspace_test.dart): `notebook autosaves edits and restores on reopen` | Lưu/đọc local trong test |
| Q07 | [motion_test.dart](../test/motion_test.dart): reduced motion, giữ input/scroll, bỏ nội dung thay thế ngay; [assistant](../test/assistant_ui_test.dart): layout sáng/tối/chữ lớn | Các bất biến UI kỹ thuật, không thay TalkBack/performance thật |
| Q08 | [persona_ui_test.dart](../test/persona_ui_test.dart): danh sách 60 sinh viên, định danh trong form, payload, chữ lớn/bàn phím, tìm và mở lại sổ tay | Fixture kỹ thuật; không thay T01–T03 với người tham gia |

## Revision log

| Phiên bản | Cơ sở thay đổi | Việc còn mở |
|---|---|---|
| v0.1, 15/10/2026 | Rà source, phản hồi chủ dự án và tài liệu môn | Thực hiện T01–T03, thêm E thực tế, sửa persona/D khi bị phản bác |
| v0.2, 15/10/2026 | Áp dụng D09/D10 vào source; xem báo cáo triển khai | Các phép thử người dùng vẫn chưa thực hiện |

