# FAP Attendance — Mobile giảng viên

Flutter Android/iOS, entry `lib/main.dart` → `lib/lab2/app.dart`. Bản shared hiện hành dành cho giảng viên; sinh viên điểm danh bằng Google trên Student Web. Lớp, lịch, roster, phiên và attendance dùng chung Apps Script/Google Sheets với Desktop. Firebase Auth xác thực; Firestore lưu thư viện bài viết riêng. Quiz đang tắt.

## Chức năng

- **Hôm nay:** lịch thật theo học kỳ, tạo hoặc tiếp tục phiên từ buổi học.
- **Trợ lý giảng dạy:** việc cá nhân, nhắc Android theo ngày, sổ tay buổi dạy tự lưu trên máy và tổng kết tuần xuất Excel. Mở từ Hôm nay hoặc thẻ buổi học; chưa đồng bộ dữ liệu cá nhân. [Phạm vi và kiểm thử](docs/LECTURER_MVP1_IMPLEMENTATION.md).
- **Lịch dạy:** xem ngày/tuần, môn, lịch định kỳ và ngoại lệ theo ngày.
- **Lớp học:** roster, QR/secret, live polling, chốt phiên, điều chỉnh có lý do/audit, thống kê và CSV. Giữ OCR/Excel/CSV; sửa tên/email có kiểm soát; hủy/dời/bù/đổi phòng.
- **Cập nhật:** NEWS từ RSS chính thức, RESEARCH Crossref/OpenAlex theo môn được phân công; lọc nguồn/ngày/từ khóa, provenance, lưu/ghi chú/bỏ lưu.

Backend kiểm identity, ownership, enrollment/frozen roster, expiry và token trong write lock. Mobile chọn 5/10/15/20/30 phút; Desktop mặc định 10 phút. Backend mở ngay theo giờ server, giới hạn bởi giờ kết thúc buổi học và chặn cả hai client ngoài cửa sổ hợp lệ. PRESENT/LATE/ABSENT/EXCUSED riêng; nếu chưa cấu hình quy định late/excused, tỷ lệ liên quan hiển thị chưa đủ cấu hình. Không suy diễn trạng thái lịch sử.

## Chạy shared mode

Mobile hiện đăng nhập **Google duy nhất**. Firebase xác minh tài khoản; Apps Script đối chiếu email đã xác minh với đúng một giảng viên trong `Lecturers`. Tài khoản sinh viên, chưa được cấp quyền, bị vô hiệu hóa hoặc hồ sơ trùng bị từ chối. Giữ nguyên provider của Desktop/Student Web. Thiết kế Material 3 sáng/tối, luồng màn hình và checklist Android/iOS: [MOBILE_UI_UX_REDESIGN_REPORT](docs/MOBILE_UI_UX_REDESIGN_REPORT.md).

Copy `config/lab2.free.example.json` sang `config/lab2.free.json` (ignored), điền public Firebase config và URL Apps Script hiện hành. Private keys/OAuth secret/OpenAlex key chỉ ở backend.

```powershell
flutter run --dart-define-from-file=config/lab2.free.json
flutter build apk --debug --dart-define-from-file=config/lab2.free.json
```

Backend refactor cần cập nhật 6 file `.gs` (bao gồm `ScheduleAttendance.gs`), manifest, thêm bảng bằng owner initializer, cài trigger và deploy trên URL cũ. Quy trình migration/rollback/acceptance thật trong [IMPLEMENTATION_REPORT](docs/IMPLEMENTATION_REPORT.md). Source local mới không tự thay deployment trước đây. Luồng slot hiện hành, API và checklist triển khai: [ATTENDANCE_SLOT_REFACTOR_REPORT](docs/ATTENDANCE_SLOT_REFACTOR_REPORT.md).

## Kiểm thử

```powershell
flutter analyze --no-pub
flutter test
node --test backend/test/*.cjs web_checkin/test/*.cjs
npm --prefix functions test
.\scripts\start-lab2-backend.ps1 -Test -SkipInstall
firebase emulators:exec --only firestore --project demo-refactor-rules --config firebase.articles.json "node --test functions/test/articles-rules.cjs"
```

Functions/emulator giữ source nghiệp vụ cũ để regression, không phải backend chính bản shared. Demo dùng `scripts/start-lab2-backend.ps1` và config emulator. `lib/main_legacy.dart` là entry cũ.

## Tài liệu và giới hạn

- [Hồ sơ persona và nghiên cứu UX](ux/README.md): ba proto-persona, evidence/coverage matrix, stakeholder/affinity, ba user flow và kế hoạch usability. Chưa có nghiên cứu giảng viên thực tế; các giả định được gắn nhãn riêng.
- [Kiến trúc và luồng backend](docs/ARCHITECTURE.md), [blueprint](docs/REFACTOR_BLUEPRINT.md), [báo cáo từng phase](docs/IMPLEMENTATION_REPORT.md).
- Live polling8s foreground, backoff khi lỗi; full snapshot30s. Class cap400; không có Firestore mirror attendance.
- Desktop calendar cũ chưa render exceptions nhưng backend chặn mở occurrence đã hủy/dời. FAP bridge Desktop chưa ánh xạ EXCUSED; cần chốt quy định, không tự đổi thành ABSENT.
- Chưa xác minh cloud E2E với tài khoản thật, tải50 người đồng thời, iOS và camera thật cho refactor. Báo cáo deployment trước đây là lịch sử.

Hướng dẫn cũ: [LEGACY_README](docs/LEGACY_README.md), [SETUP](docs/SETUP.md), [FREE_DESKTOP_SYNC](docs/FREE_DESKTOP_SYNC.md). Khi khác mô tả cũ, báo cáo refactor11/10/2026 là mô tả source hiện hành.
