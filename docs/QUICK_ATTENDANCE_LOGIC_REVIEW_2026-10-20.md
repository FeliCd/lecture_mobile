# Rà soát logic điểm danh nhanh — 20/10/2026

Phạm vi: F01 (`QuickAttendancePage`, bản nháp và API Apps Script), kiểm tra tương tác với bulk trong phiên QR, chốt phiên và chỉnh sửa cá nhân.

## Các lỗi đã sửa

1. **Báo thành công nhầm khi gửi lại:** nhánh CLOSED trước đây chỉ so các ngoại lệ với bản ghi hiện tại. Sinh viên không có trong ngoại lệ được so với chính bản ghi hiện tại, nên yêu cầu “cả lớp Có mặt” có thể được báo đã lưu dù hệ thống vừa tự chốt cả lớp Vắng. Backend nay yêu cầu bằng chứng audit đúng mã yêu cầu, tài khoản, buổi, revision và payload, đồng thời kiểm tra kết quả chưa bị chỉnh sửa tiếp. Buổi do luồng khác chốt bị từ chối, kể cả khi kết quả tình cờ giống nhau.
2. **Ghi dở dang khi buổi chưa có phiên:** trước đây tạo phiên OPEN rồi ghi attendance/chốt bằng batch khác. Nếu batch sau lỗi, phiên OPEN vẫn tồn tại và có thể tự chốt Vắng. Nay tạo phiên CLOSED, frozen roster, attendance và audit trong một Sheets batch dưới write lock. Batch lỗi không để lại phiên hoặc kết quả một phần.
3. **Sửa lựa chọn khi kết quả gửi chưa rõ:** khóa thay đổi và Hoàn tác trong trạng thái chưa xác nhận kết quả; lần thử lại giữ nguyên nội dung và request ID đã được xem lại.
4. **Mất bản nháp khi đối soát lỗi:** không xóa bản nháp trước khi tải dữ liệu mới. Nếu tải thất bại, bản nháp đã lưu trên máy còn nguyên và không thể gửi dựa trên dữ liệu cũ. Nút Tải lại cũng giữ các lựa chọn rõ ràng của giảng viên khi revision thay đổi, yêu cầu xem lại trước khi lưu.
5. **Xác nhận roster rỗng:** vô hiệu nút xác nhận trên app và từ chối ở backend; request ID là bắt buộc khi lưu.
6. Đồng bộ tìm kiếm tên tiếng Việt không dấu/khoảng trắng với các màn quản lý sinh viên khác.

## Quy tắc đã kiểm tra

- Mở bản nháp cho buổi chưa có phiên không tự tạo phiên hoặc ghi attendance. Mặc định Có mặt chỉ nằm trong bản nháp.
- Kết quả QR/thủ công đã có được giữ làm baseline; payload chỉ gửi những thay đổi rõ ràng, kèm roster và revision.
- Cần xem lại rồi xác nhận; chống gửi lặp trong lúc chờ.
- Backend kiểm quyền sở hữu lớp, buổi hợp lệ, roster và revision dưới cùng write lock với QR/chốt phiên. Dữ liệu đồng thời thay đổi buộc tải lại và đối soát.
- Gửi lại yêu cầu đã lưu hợp lệ không ghi thêm; payload/mã yêu cầu khác hoặc kết quả đã bị sửa không được nhận là cùng yêu cầu.
- Buổi đã chốt mở kết quả hiện có; điều chỉnh từng sinh viên tiếp tục qua API có lý do.

Quy tắc nghiệp vụ hiện hành vẫn áp dụng: phiên hết hạn tự chốt và ghi Vắng cho người chưa có kết quả; CLOSED không chứng minh giảng viên đã rà soát. Màn nhanh không cấp quyền mở buổi đã kết thúc nếu chưa có phiên. Đọc ngữ cảnh phiên đã hết hạn có thể kích hoạt cơ chế tự chốt hiện hành.

## Kết quả xác minh

- `flutter analyze --no-pub`: không có vấn đề.
- `flutter test --no-pub --reporter expanded`: **209/209 đạt**.
- `node --test backend/test/*.cjs web_checkin/test/*.cjs`: **81/81 đạt**.
- `git diff --check`: đạt.

Test bổ sung bao gồm tự chốt khi hết hạn, chốt qua luồng khác có kết quả giống/khác, lỗi batch trước commit, retry đúng/sai request ID, kết quả được chỉnh sau khi lưu, roster rỗng, tải lại thất bại, đổi revision, giữ payload khi retry và tìm kiếm không dấu.

Log local: `artifacts/quick-logic-{analyze,all-tests,backend}.log` (ignored).

Các sửa đổi mới nằm trên `develop` local, chưa commit hoặc triển khai cloud. Cần cập nhật `AttendanceSafety.gs` trên deployment Apps Script để logic backend mới có hiệu lực. Audit dùng schema hiện hành; các phiên đã lưu từ bản cũ vẫn xem/điều chỉnh được, nhưng không được coi là receipt của yêu cầu mới. Chưa xác minh thiết bị/tài khoản thật hoặc lỗi mạng thực tế. Các thay đổi có sẵn ở `appsscript.json` và tài liệu handoff được giữ nguyên.

## Bổ sung theo phản hồi nút ba chấm và nút lưu

- Khi không được sửa, thay nhãn chung “Chưa điểm danh” bằng lý do cụ thể theo trạng thái server. Thay menu ba chấm vô hiệu bằng biểu tượng khóa có thể chạm để xem lý do. Không thay đổi cửa sổ cho phép điểm danh ở backend.
- Đổi nút chính thành “Xem lại và lưu”. Buổi chưa được phép sửa vẫn hiện nút “Lưu điểm danh” vô hiệu và hành động “Kiểm tra lại buổi học”; buổi đã hoàn tất có nút chỉnh sửa riêng từng sinh viên.
- Bảng xem lại có vùng danh sách cuộn riêng; “Quay lại sửa” và “Xác nhận và lưu” cố định ở cuối bảng, không bị đẩy xuống dưới danh sách ngoại lệ dài.
- `flutter test --no-pub --reporter expanded test/quick_attendance_test.dart`: 24/24 đạt, gồm test mở menu ba chấm, chọn Đi trễ rồi lưu, khóa trước/sau giờ và xác nhận với 40 ngoại lệ. Analyze không có vấn đề.
- Log cho bổ sung giao diện: `artifacts/quick-save-ui-{tests,analyze,build}.log`.
