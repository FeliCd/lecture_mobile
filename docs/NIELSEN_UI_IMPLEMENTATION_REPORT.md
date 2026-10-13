# Cập nhật UI theo Nielsen — 13/10/2026

Baseline: 86cb8dd. Kế hoạch: [NIELSEN_UI_UPDATE_PLAN.md](NIELSEN_UI_UPDATE_PLAN.md).

## Kết quả

Đã triển khai thay đổi UI trong source Flutter: component trạng thái, bảo vệ bản nháp, phản hồi lưu dữ liệu, bộ lọc và trợ giúp theo ngữ cảnh. Giữ bốn tab, Material 3 sáng/tối và API nghiệp vụ hiện hành. Không deploy cloud hoặc ghi dữ liệu thật.

## Audit và xử lý

| Vấn đề xác nhận từ source | Trước | Sau |
|---|---|---|
| Điều chỉnh điểm danh mất nội dung nếu API lỗi | Dialog trả input rồi đóng; API chạy bên ngoài | API chạy trong dialog, khóa submit, chỉ đóng sau thành công; lỗi giữ trạng thái và lý do |
| Bản nháp bị bỏ khi Back | Các màn nhập và chỉnh sửa không có guard chung | CampusDraftGuard hỏi bỏ thay đổi và chặn thoát khi đang xử lý |
| QR hết hạn vẫn có thể render trong phiên OPEN | Điều kiện render chưa kiểm hạn riêng của QR | Kiểm expiresAt của QR trước khi render, kèm hướng dẫn lấy mã mới |
| Không có kết quả lọc thiếu đường phục hồi | Chỉ có thông báo trống | Xóa tìm kiếm/bộ lọc trong Lớp, Live, thống kê sinh viên và thư viện |
| Nút retry mang nghĩa sai ở chi tiết lớp | Callback về Home nhưng nhãn Thử lại | Nhãn Về Hôm nay khớp hành động |
| Thông báo lỗi ghi chưa giải thích kết quả không chắc chắn | Lỗi mạng thường khuyên thử lại | mutationErrorMessage yêu cầu kiểm tra dữ liệu trước khi gửi lại; không retry tự động |
| Nhãn kỹ thuật trong công cụ lớp/QR | Kind code trong xác nhận, Secret Code trong tùy chọn | Nhãn thao tác tiếng Việt, mã xác nhận và giải thích ngay tại chỗ |

## Đối chiếu 10 nguyên tắc

| Nguyên tắc | Thay đổi / bằng chứng |
|---|---|
| 1. Hiển thị trạng thái | AppPrimaryButton có nhãn khi busy; loading có mô tả; editor chỉ đóng sau response; Live giữ thời gian server và freshness hiện có |
| 2. Gần ngôn ngữ thực tế | Nhãn mã xác nhận, thao tác lịch trong confirm; hiển thị đúng thứ trong công cụ lớp; giữ các trạng thái điểm danh riêng |
| 3. Kiểm soát và thoát | Guard tại import thủ công/file, OCR, gán roster, sửa điểm danh, công cụ lớp và ghi chú bài viết; có Hủy để tiếp tục nhập |
| 4. Nhất quán | Tái sử dụng CampusSearchField, CampusLoadingState, EmptyState, ErrorState, CampusHelpButton, CampusDraftGuard; không thêm theme cạnh tranh |
| 5. Ngăn lỗi | Khóa form/submit khi ghi; thêm kiểm hạn QR; xác nhận bỏ lưu bài viết; giữ preview/validation import có sẵn |
| 6. Nhận biết | Lỗi giữ nội dung đang sửa; empty state phân biệt thư viện rỗng và không khớp tìm kiếm; CTA xóa lọc |
| 7. Hiệu quả | Xóa tìm kiếm tại field, đặt lại bộ lọc feed; giữ các lối tắt Today/tiếp tục phiên và IndexedStack sẵn có |
| 8. Tối giản | Giữ token và phân cấp hiện có, trợ giúp nằm trong sheet mở theo yêu cầu; không thêm tab/biểu đồ trang trí |
| 9. Khắc phục lỗi | Phản hồi lỗi inline trong editor, thông báo write timeout an toàn, sửa nhãn hành động sai, không báo thành công sớm |
| 10. Trợ giúp | QR/điểm danh, OCR, import file, gán sinh viên, feed; giải thích policy khi xem tỷ lệ vắng |

Nguyên tắc 7 và 8 chủ yếu được giữ từ thiết kế hiện có; không phải mọi nguyên tắc đều đòi hỏi một màn hình mới. Đây là đánh giá heuristic và kiểm thử kỹ thuật, không phải chứng nhận Nielsen.

## Kiểm thử

- flutter pub get --enforce-lockfile: thành công; dependencies sau pull được tải đúng lockfile, không nâng phiên bản.
- flutter analyze --no-pub: không có issue.
- flutter test --no-pub: 115/115 đạt, gồm 9 test mới trong nielsen_ui_test.dart.
- Test mới kiểm: write timeout, reset feed, QR hết hạn, giữ lý do khi ghi thất bại, ngăn submit lặp, chỉ đóng khi thành công, xóa tìm kiếm, bảo vệ bản nháp khi Back và trợ giúp/chữ lớn ở sáng/tối.
- Bộ layout hiện có kiểm màn nhỏ 360px và text scale 1.0/1.8, sáng/tối; các test responsive hiện có tiếp tục đạt.
- Render 6 màn sáng/tối bằng fixture, tổng 12 ảnh; đã xem ảnh Live sáng và Lớp tối. Đã xem ảnh editor ở trạng thái lỗi. Không phải ảnh dữ liệu production.
- git diff --check: đạt.

Log local: artifacts/nielsen-analyze.log, artifacts/nielsen-regression.log, artifacts/nielsen-focused-tests.log, artifacts/nielsen-visual-tests.log.
Ảnh local (ignored): build/ui-previews/live-light.png, classes-dark.png, attendance-error.png và các màn còn lại.

## Giới hạn cần nghiệm thu thật

- Chưa thử TalkBack, keyboard/hardware Back, mạng thật hoặc camera trên thiết bị thật; chưa có khảo sát giảng viên trước/sau.
- Chưa build/cài APK cho thay đổi này. Máy hiện thiếu config/lab2.free.json; muốn thử cloud cần cấu hình Firebase và backend refactor phù hợp. Unit/widget test dùng adapter giả lập, không chứng minh cloud E2E.
- Guard bảo vệ khi rời màn; không lưu bản nháp xuống disk để phục hồi sau app bị hệ điều hành đóng.
- UI không cung cấp undo cho sửa/chốt điểm danh. Backend hiện hành vẫn là nguồn xác thực và quyết định dữ liệu.

## File thay đổi

lib/lab2/widgets.dart, attendance_actions.dart, live_attendance.dart, classes.dart, class_attendance_overview.dart, desktop_session_dialog.dart, import_page.dart, ocr_import_page.dart, roster_assignment.dart, class_tools.dart, article_library.dart, subject_updates.dart, domain.dart; test/nielsen_ui_test.dart; tài liệu kế hoạch và báo cáo này.
