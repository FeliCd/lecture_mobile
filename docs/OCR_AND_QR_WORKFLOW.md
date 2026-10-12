# Lịch từ ảnh và trang QR mobile

## Nhập dữ liệu

1. Lịch dạy → Nhập thời khóa biểu: nhập học kỳ và chọn ảnh.
2. OCR chạy local bằng ML Kit trên Android/iOS; giữ vị trí chữ để ghép lịch theo thứ và slot. Có thể chỉnh hoặc dán văn bản OCR trước khi phân tích.
3. Duyệt lịch tạo ra: mã môn, tên môn, lớp, thứ, slot, giờ và phòng. Mã A/P dùng quy ước desktop, giờ NVH chỉ điền khi lựa chọn được bật. Thông tin còn thiếu không được tự suy đoán. Xác nhận đã đối chiếu ảnh rồi lưu.
4. Chọn Excel/CSV danh sách sinh viên, chọn sheet và lớp nhận. Nếu tên sheet và nội dung chỉ khớp một lớp/môn thì chọn sẵn; trường hợp không rõ cần chọn lớp thủ công.
5. Xem trước sinh viên thuộc lớp đã chọn, xác nhận nhập. Tiếp tục chọn sheet/lớp khác trong cùng file hoặc hoàn tất.

Markbook hỗ trợ Class/RollNumber/FullName/Email, hàng tiêu đề có thể nằm dưới các dòng mô tả. Cột điểm không được nhập. Dòng sinh viên trùng cùng thông tin được gộp; trùng MSSV nhưng khác thông tin bị chặn. Nhập lại không tạo enrollment trùng. File .xls cần lưu thành .xlsx; chưa hỗ trợ ODS trên mobile.

## Lịch trong lớp

Mở lớp sẽ vào tab Lịch dạy, hiển thị slot chưa kết thúc theo giờ Việt Nam, phân nhóm ngày trong tuần. Có thể chuyển đến tuần tương lai. Đây là lịch định kỳ của học kỳ lớp, cần kiểm tra ngày nghỉ/thay đổi ngoài lịch.

## Google sau quét QR

QR mới của mobile mở https://fap-attendance-88920.web.app/checkin. Google dùng Firebase Authentication popup, trả Firebase ID token cho backend trong POST body. Backend xác minh token với Google, email đã xác minh, domain trường và email duy nhất trong Students.schoolEmail. Không tin MSSV/role do client gửi ở luồng Google.

Trang giữ sessionId/token trên URL gốc, hiển thị lớp/slot khi backend xác nhận. Cần xác nhận có mặt và nhập Secret Code khi phiên yêu cầu. Không ghi điểm danh tự động sau đăng nhập. Phiên mobile hết hạn, QR đã đổi, tài khoản ngoài lớp hoặc sinh viên thêm sau khi mở phiên đều bị từ chối. Cửa sổ Google không phản hồi sau 45 giây hiển thị hướng dẫn thử lại bằng Chrome/Safari; không chuyển trang chính sang trang trắng.

Apps Script v29 đã triển khai giữ nguyên URL. Portal Hosting đã deploy vào Firebase project mobile theo lựa chọn của người dùng; project cũ fap-attendance-cba45 không có quyền deploy từ tài khoản hiện tại. Cần cài APK mới và quét QR mới.

## Kiểm thử và triển khai lại

```powershell
flutter analyze
flutter test
adb push test/fixtures/ocr/native.png /data/local/tmp/fap_schedule.png
flutter test integration_test/ocr_native_test.dart -d emulator-5554
node --test backend/test/lab2-free.test.cjs
npm --prefix web_checkin ci
npm --prefix web_checkin test
node scripts/configure-checkin.cjs
firebase deploy --only hosting --project fap-attendance-88920 --config firebase.checkin.json
flutter build apk --debug --dart-define-from-file=config/lab2.free.json
```

74 Flutter kiểm thử đạt, một native OCR test đạt trên Android emulator, 18 Apps Script test và 7 portal test đạt. Portal đã đối chiếu mã live và cấu hình Google provider/authorized domains. Chưa xác nhận một lượt Google đăng nhập và ghi điểm danh hoàn chỉnh bằng tài khoản sinh viên thật. iOS chưa build trên máy Windows; OCR plugin yêu cầu iOS tối thiểu 15.5.
