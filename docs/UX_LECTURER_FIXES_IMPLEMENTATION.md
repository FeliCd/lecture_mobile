# Cải thiện UX sau walkthrough giảng viên

Ngày: 19/10/2026. Phạm vi: xử lý UX01 đến UX07 trong [báo cáo walkthrough](../ux/reviews/2026-10-19-lecturer-walkthrough.md). Đây là cải thiện từ đánh giá mô phỏng, chưa phải kết quả usability với giảng viên thật.

| Mục | Thay đổi trong bản mới | Kiểm chứng |
|---|---|---|
| UX01 Phạm vi điểm danh | Khi đang tìm kiếm hoặc lọc trạng thái, không mở thao tác hàng loạt. Nếu chỉ tìm được một người, hiện Sửa sinh viên này. Khi không lọc, nút nêu Điền cho N sinh viên. Preview giải thích áp dụng cả nhóm còn chờ, số kết quả cũ được giữ và nhắc cuộn để kiểm tra đủ danh sách. | Walkthrough tìm SE1010 không còn nút cả nhóm; mở editor đúng tên/MSSV. Bỏ tìm kiếm mới hiện nút cho 22 người. |
| UX02 Hiển thị QR | Chế độ QR bỏ tiêu đề lặp và số liệu phụ, giữ phòng, thời hạn quét và tiến độ gọn. Có nút Toàn màn hình trước mã và biểu tượng trên app bar. Toàn màn hình tính kích thước theo vùng trống, có nút trở lại và hỗ trợ nút Back. Gỡ snackbar đang hiển thị khi vào để không che thời hạn. | Kiểm tra QR nằm trong viewport ở chữ 1,3 và 1,8; kiểm tra mất quyền khi đang toàn màn hình khiến QR bị gỡ. |
| UX03 Phục hồi lỗi lưu | Lỗi hiển thị ngắn, giữ lý do và danh sách vừa gửi trong phần cuộn. Nút Kiểm tra danh sách cố định ở cuối bảng, đóng bảng và tải lại. Khi tải thành công, nhắc đối chiếu kết quả vừa gửi. Không tự gửi lại hoặc báo kết quả ghi đã thành công. | Walkthrough timeout gọi ghi một lần, nút phục hồi hit-test được và trở về danh sách. Test conflict vẫn giữ lý do. |
| UX04 Hôm nay | Tên giảng viên gọn một dòng, thẻ lớp có nút Mở điểm danh hoặc Tiếp tục điểm danh. Cài đặt nhắc được chuyển xuống phần mở rộng sau lịch. | Ảnh chữ 1,8 cho thấy lớp và nút chính trước khu vực cài đặt nhắc. Luồng mở vẫn kiểm tra occurrence trên server. |
| UX05 Tìm tên | Chuẩn hóa dấu tiếng Việt, chữ hoa/thường, dấu kết hợp Unicode và khoảng trắng khi so khớp. Không sửa tên, mã hoặc dữ liệu lưu. | Nguyen tìm được Nguyễn Minh Anh; unit test NGUYỄN ĐỨC, dạng dấu kết hợp và MSSV. |
| UX06 Câu chữ | Nút Bắt đầu điểm danh, Cho phép quét trong, Còn mm:ss để quét và Kết thúc điểm danh; ngày dd/MM/yyyy. Giữ mã môn/lớp, Slot và thông tin nguồn FAP để tránh tự đổi thuật ngữ trường hoặc tuyên bố tích hợp chưa có. | Test luồng Today, Timetable và Class vẫn dùng cùng kiểm tra buổi và session ID thật do backend trả. |
| UX07 Sổ tay | Giữ dòng lớp, trạng thái lưu và tab Trước buổi/Sau buổi; bỏ banner và diễn giải lặp. Ô Ghi nhớ buổi sau thay nhãn dài; bộ đếm ký tự chỉ hiện khi gần giới hạn. Không đổi khóa dữ liệu next hoặc cơ chế tự lưu. | Walkthrough Sau buổi lưu nội dung vào trường next; kiểm tra lưu và phục hồi sổ tay hiện hành. |

## Bằng chứng hình ảnh

Giữ nguyên ảnh trước sửa tại `artifacts/ux-lecturer-walkthrough`. Ảnh sau sửa nằm ở `artifacts/ux-lecturer-fixes`, gồm:

- [Hôm nay chữ lớn](../artifacts/ux-lecturer-fixes/01-today-1.8.png).
- [QR toàn màn hình chữ lớn](../artifacts/ux-lecturer-fixes/03b-fullscreen-1.8.png).
- [Tìm một người](../artifacts/ux-lecturer-fixes/05-search.png).
- [Phục hồi lỗi lưu](../artifacts/ux-lecturer-fixes/08-save-uncertain.png).
- [Sổ tay sau buổi](../artifacts/ux-lecturer-fixes/11-notebook-after-lesson.png).

Ảnh dùng dữ liệu mô phỏng và widget thật của app; QR trỏ URL thử. Không phải ảnh production, không chứng minh camera quét thành công hoặc người dùng thực hoàn thành nhiệm vụ.

## Giới hạn và sử dụng

- Giữ các kiểm tra backend từ đợt 1: ownership, roster, revision, deadline, audit và chống lặp yêu cầu. Không đổi API hoặc triển khai cloud trong đợt UX này.
- Chức năng ghi nhanh vẫn cần backend của đợt 1 đã được cập nhật, xem [hướng dẫn](ATTENDANCE_ASSISTANT_PHASE1.md).
- Chưa có emulator/điện thoại kết nối; cần thử camera, bàn phím hệ điều hành, TalkBack, thao tác một tay và notification nền thật. Chưa có kết quả người dùng để khẳng định giảm thời gian thao tác.
- Chạy app bằng `flutter run --dart-define-from-file=config/lab2.free.json`. Dùng hot reload để xem thay đổi nếu app đang chạy.

## Kiểm tra

Kết quả cuối và log được ghi sau khi hoàn tất kiểm tra hồi quy. Có thể tái tạo ảnh bằng:

- `flutter test --no-pub --reporter expanded`: 171/171 qua, gồm kiểm tra QR toàn màn hình bị gỡ khi mất quyền và tìm tên có dấu/dấu kết hợp.
- `flutter analyze --no-pub`: không có vấn đề.
- `flutter build apk --debug --no-pub --dart-define-from-file=config/lab2.free.json`: thành công. Cảnh báo KGP từ plugin hiện hành không chặn build.
- Walkthrough có capture: 5/5 test qua; đã xem ảnh màn Hôm nay, mở điểm danh, QR bình thường/toàn màn hình chữ lớn, tìm kiếm, phục hồi lỗi và sổ tay sau sửa.
- `git diff --check`: qua. Log ở `artifacts/ux-fixes-{all-tests,analyze,build,visual}.log`.

Lệnh tái tạo ảnh:

```powershell
$env:FLUTTER_PREVIEW_FONTS='C:\Users\ADMIN\Downloads\flutter_windows_3.47.3-stable\flutter\bin\cache\artifacts\material_fonts'
flutter test --no-pub test/ux_lecturer_walkthrough_test.dart --dart-define=CAPTURE_UI=true --dart-define=UX_CAPTURE_DIR=artifacts/ux-lecturer-fixes --reporter expanded
```

## Đợt tiếp theo: Lịch dạy, lớp và sinh viên

Thực hiện tiếp ngày 19/10/2026:

- Lịch dạy: bỏ banner lặp ở đầu; giữ bộ chọn ngày/tuần và học kỳ. Nút lọc có chữ **Lọc / Ẩn lọc**. Khi môn đang lọc không có buổi học, thông báo nêu rõ môn và có nút **Xem tất cả môn** cho cả ngày và tuần. Chuyển **Nhập thời khóa biểu** xuống cuối để ưu tiên lịch. Vẫn yêu cầu chọn học kỳ rõ ràng nếu có nhiều kỳ.
- Lớp học: tìm kiếm hiện ngay đầu danh sách; tìm tên môn không cần dấu, không phân biệt chữ hoa và khoảng trắng thừa. Nút **Chọn buổi điểm danh** nói rõ bước tiếp theo và vẫn mở đúng tab Buổi học. Hai nút chuyển thành cột trên màn hẹp hoặc chữ lớn. Khi dữ liệu không còn học kỳ đang lọc, danh sách trở về phạm vi tất cả kỳ hiện có.
- Sinh viên: đưa thống kê vào mục mở rộng **Chuyên cần**, giữ số cảnh báo ngoài mục để nhận biết nhanh. Bỏ tiêu đề và mô tả lặp để ô tìm tên/MSSV xuất hiện sớm; hỗ trợ tên không dấu. Giữ nguyên cách tính, ngưỡng và lịch sử điểm danh; mở Chuyên cần để xem chi tiết và cách tính.

Kiểm tra: **174/174 Flutter test qua**, `flutter analyze --no-pub` sạch. Ba test mới kiểm tra tìm kiếm và xóa lọc lớp, điều hướng chọn buổi, tìm sinh viên không dấu và phục hồi lịch trống do lọc môn. Test thống kê cũ được cập nhật để mở Chuyên cần trước khi đối chiếu số liệu. Đã kiểm tra ảnh widget thật ở 393 × 852, cỡ chữ 1,8; không phải thử nghiệm với giảng viên thật.

Ảnh dữ liệu mô phỏng: [Lớp học](../artifacts/ux-schedule-classes/01-classes-large.png), [Sinh viên](../artifacts/ux-schedule-classes/02-students-large.png), [Lịch dạy](../artifacts/ux-schedule-classes/03-timetable-large.png), [Lịch trống do lọc](../artifacts/ux-schedule-classes/04-filter-empty.png). Log: `artifacts/ux-next-{all-tests,analyze,behavior,visual,build}.log`.

APK debug với `config/lab2.free.json` build thành công; `git diff --check` qua. Cảnh báo KGP hiện hành không chặn build. Chưa chạy kiểm tra tương tác trên thiết bị thật trong đợt này.

Tái tạo ảnh bằng lệnh sau khi đặt `FLUTTER_PREVIEW_FONTS` như trên:

```powershell
flutter test --no-pub test/ux_schedule_classes_test.dart --dart-define=CAPTURE_UI=true
```
