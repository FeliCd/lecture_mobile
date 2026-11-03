# Rà soát Lab 3 sau cải tiến chat/skeleton - 02/11/2026

## Kết luận

Chưa thể đánh dấu đạt toàn bộ Lab 3. Source có đủ sáu SDK Firebase và các luồng sản phẩm; nhiều kiểm thử local đã pass, Remote Config đã publish và được Android native SDK tải thật. Còn thiếu bằng chứng Console, E2E ARTEMIS, PR review có commit, Figma xác minh và video. Không có bảng trọng số trong tài liệu để dự đoán điểm.

Nguồn tiêu chí: `C:/Users/ontri/Downloads/PRM393_Lab3_Preparation_Guide_v5_ToiUu.pdf` (25 trang).

| Yêu cầu | Mức hiện tại | Còn phải thực hiện |
|---|---|---|
| 3 flow Lab 2 + MVVM/Riverpod | Có flow/code; thêm flutter-handoff.md; cloud controllers/services có DI | Đối chiếu 3 flow với Figma đã nộp; một số màn cũ còn UI state thay vì ViewModel riêng |
| Authentication | Google auth, guard, logout/reset cache | Video login/hủy/offline/logout và ảnh Console Users |
| Storage | Upload Excel/progress/URL, owner rules; rules emulator pass | Xác nhận Blaze/bucket/rules cloud; upload thật, denial và ảnh Console |
| Messaging | Code foreground/background/terminated, history, permission, route whitelist | Gửi Console đủ ba trạng thái; quyền bị từ chối; không coi local reminder là FCM |
| Analytics | Kế hoạch trước code, hơn 7 event, UID và không PII | DebugView cho từng event và lỗi flow thực tế |
| Crashlytics | Error handlers, non-fatal, UID/key và crash demo riêng | Non-fatal + fatal và UID/key thật trên Console |
| Remote Config | Hai tham số publish thành công; Android smoke nhận valueRemote | Quay UI trước/sau không build lại, offline/cache và ảnh Console |
| ARTEMIS | 16 ca nghiệm thu đã viết; tìm được nguồn google/artemis | Chưa cài/chạy ARTEMIS hoặc cung cấp key model; cần >=10 ca x3, khám phá 15-30 phút |
| AI Code Review | Có thể rà diff local; không có bằng chứng PR/commit hoàn chỉnh | >=5 finding, >=2 nhóm, quyết định và >=3 sửa accepted có commit trong PR |
| Hồ sơ nộp | Bộ slide 14 trang, báo cáo 10 trang và lời thuyết trình được chuẩn bị | Bổ sung link GitHub/Figma và video 5-10 phút; cập nhật evidence thật trước nộp |

## Kết quả đã thực thi trong lần này

- Flutter Mobile: analyzer sạch, 247 unit/widget tests pass.
- Apps Script VM: 116 tests pass, trong đó 12 ca nhóm gồm receipt, thời gian server, quyền và không tự suy ra read.
- Web: 13 UI tests + 4 migration tests pass; production build pass.
- Storage rules emulator: owner/other/anonymous/unverified, MIME, size, overwrite/delete pass.
- Native Android 13 emulator-5554: 1 integration smoke pass. Khởi tạo SDK, remote fetch có source valueRemote cho hai tham số; đọc notification permission/Crashlytics collection state; giữ nguyên UID, không sửa điểm danh.
- Desktop: 66 tests và release build đã pass ở đợt triển khai trước; source desktop không đổi trong lần cải tiến web này.
- UI web kiểm tra bằng fixture 1280x1000 và 390x844; không tràn ngang. Fixture chỉ để kiểm bố cục, không là cloud evidence.

Logs gốc: `tmp/lab3-mobile-final.log`, `tmp/lab3-backend-final.log`, `tmp/lab3-storage-final.log`, `tmp/lab3-native-smoke.log`; web `.visual-qa/ui-tests-current.log`. Các thư mục này ignored, không tự tính là hồ sơ ARTEMIS.

## Chat mới

- Tin mình/phía khác dựa viewerId/mine do backend suy từ actor đã xác minh. Không đoán từ tên hiển thị hoặc email.
- Giờ gửi từ createdAt server, hiển thị Asia/Ho_Chi_Minh; chia ngày. Không dùng giờ máy sinh viên làm thời gian gửi đã xác nhận.
- Delivery chỉ khi client xác nhận response đã về; read khi phần tin nằm trong viewport, trang visible và focus. Receipt timestamp do server cấp; retry giữ timestamp đầu tiên.
- Bảng mới PortalGroupReceipts, mỗi actor/group lưu tối đa 200 message receipt gần nhất. Chỉ tóm tắt receipt của thành viên hiện tại; tin cũ không có receipt vẫn là Đã gửi. Không suy ra trạng thái đã xem từ truy vấn getGroupMessages.
- API ackGroupMessages kiểm lớp, enrollment, nhóm, ID thuộc nhóm, max50 IDs/lượt; không nhận caller-provided actor/time. Chat vẫn polling 10 giây, không socket; mobile/desktop cũ chưa phát read receipt.
- UI có giờ, bubble, date separator, số thành viên, xem trước/bỏ tệp, Enter/Shift+Enter, trạng thái sending/uncertain, retry cùng request key và không giật xuống cuối khi đọc tin cũ.
- Skeleton theo request ở bootstrap, lớp, điểm, xin nghỉ, nhóm và chat; lỗi thoát loading; reduced-motion và aria-busy/status.

## Cập nhật để dùng trên web đã deploy

1. Cập nhật Code.gs, Lab2Free.gs, StudentPortal.gs, StudyGroups.gs và các source tương thích trong gói backend mới; chạy setupStudyGroups() lại để thêm PortalGroupReceipts (không xóa dữ liệu cũ).
2. Deploy Apps Script new version trên URL cũ.
3. Tại `C:/PRM/fu-grade-web`, chạy `npm run deploy`. Target student đã map sang fap-sinhvien, không deploy site QR mặc định.
4. Test hai tài khoản sinh viên trong cùng nhóm: gửi -> người kia tải -> mở đúng tin; kiểm nhận/xem thật. Không tick read nếu API cũ chưa trả receiptTracking.

Remote Config đã được publish trong lần này với true/20 sau khi kiểm template live trống; không thay rules/billing cloud hoặc dữ liệu nghiệp vụ. Mọi thử nghiệm tiếp theo dùng lớp và user test riêng.

## Thứ tự chốt bài

1. Bật/xác minh Storage và thu Console evidence cho sáu dịch vụ.
2. Cấu hình ARTEMIS theo nguồn chính thức, chạy ít nhất 30 lượt có logs gốc; không gửi dữ liệu sinh viên thật tới model khi chưa có phạm vi đồng thuận phù hợp.
3. Tạo PR review thật, lưu quyết định và commit sửa; bản local review không tự thay bằng chứng này.
4. Điền link Figma/GitHub, quay video và cập nhật trạng thái trong báo cáo/slide.

Nguồn ARTEMIS: https://github.com/google/artemis. Không dùng chỉ số benchmark của công cụ như kết quả test của dự án.
