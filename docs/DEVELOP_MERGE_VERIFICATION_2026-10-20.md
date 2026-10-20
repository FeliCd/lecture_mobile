# Kiểm tra merge develop local — 20/10/2026

Hoàn tất merge đang dang dở từ `feature/FE_uxfold` vào `develop` (HEAD trước merge: `a925509`, gồm F01/F02 từ `feature/attendance-assist`).

## Xử lý và tính năng giữ lại

- Ghép 5 file conflict: `Lab2Free.gs`, `app.dart`, `lecturer_reminders.dart`, `repository.dart`, `today.dart`.
- Giữ route `/quick`, API đọc ngữ cảnh/lưu điểm danh nhanh, bản nháp mặc định Có mặt, ngoại lệ, xem lại và kết quả chính thức.
- Giữ API `bulkUpdatePendingAttendance`, cập nhật sinh viên còn chờ trong phiên QR, revision, lý do và audit. Allowlist backend và ánh xạ lỗi client hỗ trợ cả hai luồng.
- Giữ các cải tiến UX, thống kê lớp, tìm sinh viên, theo dõi/ghi chú sinh viên, sổ tay và nhắc việc từ nhánh nhập vào.
- Giữ danh sách buổi đã hết giờ chưa hoàn tất và nút điểm danh nhanh; không lặp cùng buổi ở bảng Cần xử lý hoặc danh sách buổi khác.
- Dùng coordinator theo dõi lịch trên các route để lập nhắc; bỏ lập nhắc riêng từ màn Hôm nay để tránh hai bộ nhắc cho cùng buổi. Giữ cài đặt bật/tắt theo tài khoản/học kỳ, giờ yên lặng, nhắc trước giờ 10 phút và trước hết buổi/phiên 2 phút của nhánh UX. Vẫn hỗ trợ payload nhắc điểm danh nhanh và payload nhắc việc.
- Đồng bộ nhắc buổi học chỉ thay các nhắc việc/buổi học liên quan, không gọi `cancelAll` làm mất nhắc điểm danh nhanh. Đăng xuất vẫn hủy tất cả. Tránh trùng notification ID và chỉ ghi nhận signature sau khi lập lịch thành công/có quyền thông báo.
- Sửa khóa `ATTENDANCE_CONFLICT` trùng trong const map mà Git tự ghép không đánh dấu conflict; đây là lỗi chặn biên dịch Flutter. Hai luồng dùng cùng thông báo yêu cầu tải lại và đối soát.

## Kiểm chứng trên source đã ghép

| Kiểm tra | Kết quả |
|---|---|
| `flutter analyze --no-pub` | Không có vấn đề |
| `flutter test --no-pub --reporter expanded` | 204/204 đạt |
| `node --test backend/test/*.cjs web_checkin/test/*.cjs` | 78/78 đạt |
| `npm --prefix functions test` | TypeScript build thành công; 5/5 đạt |
| `flutter build apk --debug --no-pub --dart-define-from-file=config/lab2.free.json` | Thành công |
| `git diff --check`, `git diff --cached --check` | Đạt |

Kiểm tra hồi quy bổ sung:

- Qua public API: tải bản nháp nhanh → ghi bulk → từ chối bản nháp cũ → tải lại → chốt nhanh giữ đúng kết quả Có mặt/Vắng và cùng session.
- Mock Android theo dõi danh sách notification thực: nhắc điểm danh nhanh còn nguyên khi buổi học hoàn tất, nhắc buổi học bị gỡ, nhắc việc được giữ và đăng xuất xóa hết.

Log local (ignored): `artifacts/conflict-{analyze,flutter-tests,backend-tests,functions-tests,build}.log`. APK: `build/app/outputs/flutter-apk/app-debug.apk`.

Build có cảnh báo tương thích KGP/native access từ toolchain/plugin hiện hành, không chặn build. Chưa nghiệm thu trên thiết bị thật, notification nền, tài khoản thật hoặc iOS; chưa triển khai Apps Script lên cloud. Để dùng API bulk mới với dữ liệu thật, cập nhật Apps Script theo `ATTENDANCE_ASSISTANT_PHASE1.md`.

Tài liệu untracked có sẵn `docs/LECTURER_ATTENDANCE_FEATURE_HANDOFF.md` được giữ nguyên ngoài merge commit.
