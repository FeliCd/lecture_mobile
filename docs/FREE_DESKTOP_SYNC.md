> Refactor 11/10/2026: source mới đã có trigger reconciliation, 4 trạng thái, Subject Insights và ngoại lệ lịch. Deployment v29 ghi dưới đây là lịch sử, chưa chứa bản refactor này. Xem [IMPLEMENTATION_REPORT](IMPLEMENTATION_REPORT.md) và [ARCHITECTURE](ARCHITECTURE.md) cho luồng/migration hiện hành.

> Source Mobile hiện hành 11/10/2026: Google-only, 4 tab Hôm nay/Lịch dạy/Lớp học/Cập nhật, phiên từ lịch với duration 5/10/15/20/30 phút và phòng hiệu lực. Xem [MOBILE_UI_UX_REDESIGN_REPORT](MOBILE_UI_UX_REDESIGN_REPORT.md). Mô tả email/password, form phiên thủ công và deployment cũ trong tài liệu này là lịch sử, không chứng minh source mới đã được triển khai cloud.

# Đồng bộ Desktop và Mobile giảng viên

Mobile dùng `config/lab2.free.json`, Firebase Authentication project `fap-attendance-88920` và cùng workbook Sheets với Desktop cho lớp, lịch, roster và điểm danh. Apps Script xác minh Firebase token/email và đối chiếu hồ sơ Lecturers. Mobile chỉ cho giảng viên đăng nhập.

Thư viện bài báo cá nhân dùng Firestore thật trong cùng project; giảng viên lưu và sửa tóm tắt nguồn có sẵn. Quyền thư viện độc lập theo Firebase UID. Không sao chép dữ liệu lớp vào Firestore.

## Chạy

```powershell
flutter run --dart-define-from-file=config/lab2.free.json
```

Không cần emulator. Đăng nhập tài khoản Firebase có email đã xác minh, trùng email giảng viên trong dữ liệu Desktop. Trên máy khác, copy `config/lab2.free.example.json` sang `config/lab2.free.json` và điền Firebase Android public config cùng URL deployment. OpenAlex key chỉ lưu tại Script Properties.

## Triển khai hiện tại

Ngày 09/10/2026: Firestore rules thư viện đã triển khai và xác minh; Apps Script deployment hiện tại đã cập nhật **v29**, giữ nguyên URL. Trang QR mobile dùng Hosting tại https://fap-attendance-88920.web.app/checkin, Google provider đã bật trong Firebase Authentication. Các mã nguồn backend cũ được sao lưu trong artifacts/backend-backup trước khi cập nhật.

Apps Script dùng hook doPost cho lab2Health, lab2Snapshot, lab2Call; các action Desktop hiện có tiếp tục dùng mã Mã.gs. API mobile mới có importTimetable/importClassStudents và thao tác phiên QR/secret/điều chỉnh điểm danh. Nhập liệu xác minh quyền lớp và ghi atomic; không xóa dữ liệu hiện có. Functions trong repo chỉ được kiểm thử với emulator, chưa deploy cloud thật.

## Cách sử dụng

Xem [ATTENDANCE_MOBILE.md](ATTENDANCE_MOBILE.md) cho thao tác, mẫu nhập và kết quả kiểm thử.

- Mobile đọc snapshot dùng chung, cache tối đa 30 giây và làm mới sau thao tác. Desktop bấm tải lại để thấy thay đổi từ cùng Sheet.
- Phiên dùng classId/date/slot chung. Tạo lại phiên OPEN tiếp tục phiên hiện có; phiên CLOSED không được mở lại hoặc kéo dài hạn.
- Phiên mobile đóng theo thời lượng chọn, tối đa 240 phút. Snapshot phát hiện phiên hết hạn sẽ chốt vắng theo danh sách ghi danh lúc mở; không dùng scheduler.
- QR mở trang web điểm danh Desktop, token ngẫu nhiên tại Sessions. Secret sáu chữ số tách khỏi QR; chỉ giảng viên phụ trách nhận được secret. Đổi QR hoặc đóng/reset phiên vô hiệu token cũ.
- Chỉ hai trạng thái Có mặt/Không có mặt. Lịch sử chưa có snapshot ghi danh chỉ dùng bản ghi sẵn có, tránh đánh vắng sinh viên mới thêm sau đó.
- OpenAlex/Crossref trả metadata và abstract nếu nguồn có. Cache 6 giờ; Crossref công khai là đường dự phòng cho lỗi nguồn/cache, không gửi token hoặc dữ liệu lớp.

## Emulator

```powershell
.\scripts\start-lab2-backend.ps1
.\scripts\run-android.ps1 -EmulatorId Pixel_7 -Config config/lab2.emulator.json
```

Hai chế độ chọn bằng config khi build. APK cần build lại khi đổi chế độ.
