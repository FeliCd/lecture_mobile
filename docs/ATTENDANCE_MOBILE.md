# Mobile giảng viên — 09/10/2026

Mobile chỉ hỗ trợ giảng viên có hồ sơ duy nhất trong dữ liệu Desktop, đăng nhập bằng Google. Thanh điều hướng gồm Hôm nay, Lịch dạy, Lớp học và Cập nhật; mở cài đặt qua avatar. Chi tiết lớp có Sinh viên, Điểm danh, Buổi học và Thống kê. Lịch giữ cả buổi đã qua để xem kết quả, hiển thị phòng hiệu lực và ngoại lệ hủy/dời/bù/đổi phòng. Xem [báo cáo UI/UX hiện hành](MOBILE_UI_UX_REDESIGN_REPORT.md); thông tin deployment bên dưới là lịch sử, không xác nhận source mới đã được deploy.

- **Lớp học → Tạo phiên điểm danh**: chọn slot và thời lượng 5–240 phút, tạo phiên và mở QR. Hiển thị tên môn, slot, thời hạn; bật/tắt Secret Code và đổi QR. Sinh viên quét QR bằng điện thoại để mở trang điểm danh Firebase mobile, đăng nhập Google email trường hoặc nhập MSSV, và nhập secret khi phiên yêu cầu.
- **Điểm danh** giữ riêng Có mặt, Đi trễ, Vắng và Vắng có phép; trong phiên mở, chưa check-in là Đang chờ. Sửa lịch sử bắt buộc lý do/audit, giữ giờ check-in gốc. Kết thúc cần xác nhận và chốt vắng theo frozen roster. Phiên chỉ mở từ buổi học server đã xác minh, duration 5/10/15/20/30 phút, mặc định 10 và giới hạn bởi giờ kết thúc buổi học.
- **Lịch dạy → Nhập thời khóa biểu**: nhập học kỳ, chọn ảnh PNG/JPG (tối đa 20 MB), OCR local trên Android/iOS, chỉnh văn bản, phân tích và duyệt từng dòng lịch. Quy tắc lịch tuần và A/P giống desktop; giờ NVH được điền chỉ khi giảng viên chọn, kèm cảnh báo. Bổ sung lớp/phòng thiếu, đối chiếu ảnh và xác nhận trước khi lưu.
- **Sau khi lưu lịch → Gán sinh viên từ Excel**: chọn XLSX/CSV/TSV, sheet và lớp tương ứng. Hỗ trợ markbook có Class/RollNumber/FullName/Email, hàng tiêu đề ở giữa sheet, nhiều lớp trong một sheet và cột điểm/công thức không liên quan. Chỉ nhập hàng thuộc lớp đã chọn; sheet khác hoặc lớp không xác định cần giảng viên chọn rõ ràng. Có thể nhập từng lớp từ **Lớp → Sinh viên → Nhập sinh viên**. Giới hạn 100 dòng lịch hoặc 400 sinh viên mỗi lần, Excel tối đa 5 MB. Không xóa dữ liệu khác hoặc thay danh sách phiên đang mở.
- **Cập nhật → Tin tức/Nghiên cứu/Đã lưu**: lọc theo môn được phân công, nguồn, thời gian và từ khóa; lưu metadata/ghi chú vào thư viện Firestore cá nhân. Hiển thị đúng trạng thái đã lưu và provenance nguồn. Bài không có abstract giữ trạng thái thiếu mô tả; không sinh tóm tắt giả.

## Mẫu nhập

Lịch: `semester,subjectCode,subjectName,classCode,dayOfWeek,slot,startTime,endTime,room`. Thứ dùng 1=Thứ hai đến 7=Chủ nhật, giờ `HH:mm`.

Sinh viên: `studentCode,fullName,schoolEmail` (email tùy chọn). Lớp được chọn từ màn hình đang mở. Chấp nhận các tiêu đề tiếng Việt tương đương; giao diện có mẫu để sao chép.

## Backend đã triển khai

Firebase Authentication và Firestore dùng project `fap-attendance-88920`. Thư viện nằm tại `articleLibraries/{firebaseUid}/articles`; chỉ chủ tài khoản có email đã xác minh được đọc/ghi thư viện của mình. Firestore rules mới đã triển khai và đối chiếu với mã local, giữ các rules hiện có.

Lịch, lớp, sinh viên, phiên và điểm danh vẫn dùng cùng Sheets/Apps Script với Desktop. Apps Script đã cập nhật deployment hiện tại lên **phiên bản 29**, giữ nguyên URL. Thêm xác thực Firebase Google cho trang quét QR; hạn phiên, QR cũ và danh sách ghi danh lúc mở phiên được kiểm tra cả khi xem thông tin và khi ghi điểm danh. Functions trong repo dành cho chế độ Firebase Emulator, chưa triển khai Cloud Functions lên project thật.

Trang QR mới: https://fap-attendance-88920.web.app/checkin. QR mobile dùng trang này theo lựa chọn của người dùng, thay URL project cũ không có quyền deploy. Google dùng Firebase Authentication popup, không chuyển trang điểm danh sang callback trắng. Sau đăng nhập thành công, backend đối chiếu email trường với Students.schoolEmail rồi hiển thị lớp/slot. Khi popup bị chặn/không phản hồi, giữ trang hiện tại, hiển thị hướng dẫn Chrome/Safari và cho thử lại hoặc dùng MSSV. Email của sinh viên phải có trong roster nếu dùng Google. Không gửi ID token trong URL hoặc lưu vào mã QR.

## Xác minh

- Flutter: 74 kiểm thử đạt; `flutter analyze` không có lỗi.
- Android ML Kit: một kiểm thử native đạt trên emulator, đối chiếu mã môn, lớp, giờ 07:30–09:00 và phòng AL-201 từ ảnh thật.
- Apps Script: 18 kiểm thử đạt; portal: 7 kiểm thử đạt, gồm callback Google/Firebase, giữ QR, không gửi trùng, popup bị chặn và lỗi xác thực. Luồng Google popup được mô phỏng trong kiểm thử; chưa xác nhận một lượt đăng nhập và điểm danh hoàn chỉnh bằng tài khoản sinh viên thật.
- Functions: 5 kiểm thử đạt và TypeScript build thành công trong lần cập nhật trước.
- Firebase Emulator: 7 kiểm thử tích hợp đạt, gồm quyền thư viện riêng, nhập liệu và phiên có thời hạn.
- Android debug APK build thành công với `--dart-define-from-file=config/lab2.free.json`.

UI đã kiểm tra ở màn hình nhỏ, chữ lớn và dark mode. Danh sách điểm danh phân trang, thư viện dùng lazy list. Chưa đo hiệu năng trên điện thoại thật.
