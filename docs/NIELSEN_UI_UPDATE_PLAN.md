# Kế hoạch cập nhật UI theo 10 nguyên tắc Nielsen

Ngày: 13/10/2026. Baseline: commit 86cb8dd, ứng dụng lib/main.dart → lib/lab2/app.dart.

Nguồn: Jakob Nielsen, Nielsen Norman Group — https://www.nngroup.com/articles/ten-usability-heuristics/

## Phạm vi và bằng chứng

Đây là kế hoạch, chưa triển khai UI. Audit sơ bộ dựa trên source và MOBILE_UI_UX_REDESIGN_REPORT.md; chưa quan sát app chạy thật hoặc kiểm thử người dùng. Các mục bên dưới là đề xuất/cần xác minh, không phải kết luận mọi màn hình đang lỗi.

Giữ bốn tab Hôm nay / Lịch dạy / Lớp học / Cập nhật và Settings qua avatar. Tái sử dụng theme.dart, widgets.dart, repository, Riverpod/GoRouter. Có sẵn Material 3 sáng/tối, xác nhận thao tác, giữ tab, loading/error state và QR ẩn khi dữ liệu stale: kiểm tra rồi bổ sung, không xây trùng. Backend vẫn quyết định quyền, thời gian và trạng thái phiên.

## Ma trận 10 nguyên tắc

| # | Nguyên tắc | Thay đổi dự kiến | Tiêu chí nghiệm thu |
|---|---|---|---|
| 1 | Hiển thị trạng thái hệ thống | Chuẩn hóa đang tải/làm mới/đang lưu/lưu thành công; Live có thời điểm cập nhật, kết nối và thời hạn theo server | Không báo thành công trước phản hồi; khi stale/mất mạng có nhãn rõ, QR và hành động phụ thuộc freshness xử lý theo guard hiện có |
| 2 | Phù hợp ngôn ngữ thực tế | Nhãn tiếng Việt thống nhất: Buổi học, Phiên điểm danh, Có mặt, Đi muộn, Vắng, Có phép, Chưa điểm danh; ngữ cảnh lớp/môn/phòng/ngày luôn rõ | Không lộ OPEN/CLOSED/EXCUSED, UID hoặc mã lỗi trong luồng chính; giờ hiển thị theo UTC+7; không gộp PENDING thành ABSENT |
| 3 | Quyền kiểm soát và thoát | Hủy rõ trong dialog/sheet, Back nhất quán, cảnh báo bỏ dữ liệu nhập; giữ bản nhập khi lỗi | Thoát form không mất dữ liệu im lặng; xác nhận kết thúc nêu ảnh hưởng; hoàn tác chỉ dùng cho thao tác backend thực sự hỗ trợ |
| 4 | Nhất quán và quy ước | Dùng chung button, field, status chip, error/empty, confirm sheet; chuẩn hóa vị trí hành động và thứ tự trạng thái | Cùng thao tác có cùng nhãn/icon/màu/hành vi giữa Today, Lịch, Lớp và Live; thông tin không chỉ dựa vào màu |
| 5 | Ngăn lỗi | Kiểm dữ liệu tại trường; import có preview và lỗi theo dòng; sheet mở phiên chỉ đọc ngữ cảnh, duration là lựa chọn hợp lệ | Chặn submit lặp; lý do bắt buộc khi chỉnh sửa; server vẫn kiểm tra lại; kết quả timeout không tự retry mutation |
| 6 | Nhận biết thay vì ghi nhớ | Bộ lọc đang áp dụng luôn nhìn thấy; nhãn trên field; nhắc lớp/môn/buổi trong dialog; empty state phân biệt chưa có dữ liệu và không khớp lọc | Có Xóa bộ lọc hoặc CTA phù hợp; không bắt nhớ mã lớp hay định dạng CSV từ màn khác |
| 7 | Linh hoạt và hiệu quả | Nút Tiếp tục phiên trên Today; tìm kiếm/lọc roster; giữ scroll và bộ lọc; lối tắt tới nhập dữ liệu khi có quyền | Buổi hợp lệ mở sheet trong một lần chạm; phiên đang mở tiếp tục trong một lần chạm; không thêm xác nhận thừa cho hành động đọc |
| 8 | Thẩm mỹ và tối giản | Một hành động chính mỗi màn; thông tin trọng tâm trước; công cụ ít dùng vào menu; thẻ thống nhất theo token hiện có | Không thêm số liệu/biểu đồ giả; màn nhỏ và chữ lớn không tràn; có trạng thái/icon bên cạnh màu |
| 9 | Nhận biết và khắc phục lỗi | Thông báo nêu vấn đề và việc cần làm; tách lỗi mạng, hết phiên đăng nhập, chưa được cấp quyền, cấu hình và dữ liệu nhập | CTA đúng lỗi: Thử lại/Đăng nhập lại/Xóa lọc/Sửa dữ liệu; giữ form và dữ liệu cũ an toàn; timeout ghi cần tải lại để xác định kết quả |
| 10 | Trợ giúp và tài liệu | Trợ giúp theo ngữ cảnh tại QR, mở phiên, import, thống kê; mẫu CSV và hướng dẫn liên hệ quản trị | Từ màn hiện tại có thể mở trợ giúp liên quan; giải thích giới hạn giờ, QR hết hạn và tỷ lệ chưa đủ policy; không ép xem tutorial |

## Thứ tự thực hiện

### Đợt 0 — Audit trực quan và chốt backlog (0,5–1 ngày công)

- Chạy bản hiện tại với dữ liệu fixture có kiểm soát, chụp các luồng đăng nhập, Today, lịch, lớp, Live, import, feed và Settings.
- Bao phủ loading, empty, lỗi, mất kết nối, stale, hết hạn và thiếu quyền.
- Ghi từng issue: màn hình, bằng chứng, nguyên tắc liên quan, ảnh hưởng, đề xuất và tiêu chí nghiệm thu. Ưu tiên trong kế hoạch là dự kiến đến khi audit xác nhận.
- P0: sai/nguy hiểm với dữ liệu hoặc chặn tác vụ; P1: làm khó hoàn thành tác vụ; P2: cải thiện độ rõ và hiệu quả.

### Đợt 1 — Thành phần và ngôn ngữ chung (1–2 ngày công)

- File trọng tâm: lib/lab2/theme.dart, widgets.dart, app.dart.
- Chuẩn hóa status/loading/error/empty, nhãn tiếng Việt, nút chính/phụ, semantics và thông báo tác vụ.
- Chốt mockup cho Today, Live, import trước khi nhân rộng. Duyệt trạng thái và phân cấp thông tin, không chỉ ảnh màn hình đẹp.

### Đợt 2 — Luồng quan trọng P0/P1 (2–3 ngày công)

- Today/Lịch → sheet buổi học → Live → kết thúc → kết quả.
- File: today.dart, timetable_card.dart, desktop_session_dialog.dart, live_attendance.dart, attendance_actions.dart, classes.dart.
- Ưu tiên phản hồi đang ghi, deadline/freshness, lỗi kết nối, xác nhận tác động và chống nhấn lặp.
- Không đổi business rules, tự đóng/mở phiên từ UI hoặc bổ sung undo giả.

### Đợt 3 — Quản lý dữ liệu và nội dung (1–2 ngày công)

- File: import_page.dart, ocr_import_page.dart, class_tools.dart, timetable.dart, subject_updates.dart, article_library.dart.
- Import theo Chọn nguồn → Kiểm tra → Xác nhận → Kết quả; lỗi có dòng/cột và hướng sửa.
- Rà tìm kiếm/lọc, thoát khi đang sửa, trạng thái lưu bài, trợ giúp và trường hợp không có kết quả.
- Undo bỏ lưu chỉ triển khai nếu API hiện có đáp ứng; nếu không, cung cấp thao tác lưu lại rõ ràng.

### Đợt 4 — Kiểm thử và đánh giá lại (1–2 ngày công)

- Widget test cho hành vi: giữ form khi lỗi, ngăn submit lặp, phản hồi freshness, Back/thoát form và CTA đúng trạng thái.
- Kiểm hồi quy mở phiên, QR, sửa/chốt điểm danh, import, lọc và lưu bài.
- Kiểm dark/light, màn rộng 360/390/430 logical px, text scale 1.0/1.3/1.8, TalkBack và mục tiêu chạm 48 logical px. Đây là tiêu chí kỹ thuật dự án, bổ sung cho Nielsen.
- flutter analyze, flutter test; thử thiết bị thật cho Back, bàn phím, TalkBack, foreground/background và mạng chậm.
- Nếu tuyển được người dùng, thử 3–5 giảng viên trên cùng bộ tác vụ trước/sau; ghi tỷ lệ hoàn thành, lỗi, thời gian và số lần cần trợ giúp. Không tuyên bố usability đạt chỉ từ unit test.

## Điều kiện hoàn tất và đầu ra

- Không còn issue P0/P1 đã xác nhận mà chưa xử lý hoặc có quyết định rõ ràng; P2 có backlog.
- Không làm suy yếu quyền giảng viên, server deadline, token freshness hay audit.
- Không có overflow trong ma trận màn hình/chữ đã chọn; các nút icon có nhãn hỗ trợ đọc màn hình.
- Có checklist liên kết cả 10 nguyên tắc với màn hình, ảnh trước/sau và kết quả kiểm thử. Không tuyên bố chứng nhận Nielsen.
- Đầu ra: audit backlog, mockup luồng chính, component cập nhật, source, test hành vi và báo cáo UI trước/sau.

Ước lượng sơ bộ: 6,5–11 ngày công, tùy audit, dữ liệu chạy và vòng phản hồi. Không bao gồm nâng cấp API, triển khai cloud hoặc bổ sung nghiệp vụ mới. Vấn đề phụ thuộc backend phải tách ticket và nêu rõ giới hạn UI.
