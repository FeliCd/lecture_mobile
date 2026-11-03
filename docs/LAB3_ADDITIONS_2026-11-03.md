# Bổ sung Lab 3 - 03/11/2026

## Chức năng và kiến trúc

- AuthActionsController + AuthSessionService: tách đăng nhập/đăng xuất khỏi widget, khóa thao tác trùng, lỗi/hủy có thể thử lại; chỉ invalidates profile khi thao tác thành công.
- SessionOpeningController: đọc buổi và mở phiên qua repository. Sau timeout tạo phiên, bắt buộc Kiểm tra lại trước khi gửi tiếp để có thể tiếp tục phiên server đã tạo.
- AttendanceEditController: kiểm trạng thái/lý do, khóa lưu trùng, giữ nội dung trong dialog khi lỗi. Chỉ đóng sau response thành công.
- NotebookController: tách tải/lưu tự động khỏi widget, có thử mở lại khi đọc lỗi; lỗi ghi mới nhất không bị response cũ xóa; sao chép checklist trước khi đưa vào hàng đợi ghi. WorkspaceStore tiếp tục ghi tuần tự và phân vùng UID.
- PushPermissionController: trạng thái chưa cấp/từ chối/đã cấp/yên lặng/không hỗ trợ; không mở nhiều prompt đồng thời; refresh quyền và lịch sử khi resume từ cài đặt Android.
- Remote Config: UI cho biết đang dùng mặc định hay giá trị đã kích hoạt, lỗi fetch và thời điểm fetch thành công theo GMT+7. Không coi giá trị cache là một lần tải mạng mới.

ViewModel dùng Riverpod đang có, dịch vụ Firebase giữ ở tầng service/repository. Ba luồng chính F01/F02/F03 đã tách các tác vụ trên; không tuyên bố mọi màn legacy đã được viết lại MVVM.

## Chạy bản mới

Kiểm chứng ngày 03/11: 251 Flutter tests pass, `flutter analyze --no-pub` không có issue. Logs ở `tmp/lab3-additions-verified.log` và `tmp/lab3-additions-analyze.log`; đây là unit/widget tests, không thay ARTEMIS hoặc Console evidence.

```powershell
cd C:\PRM\lecture_mobile
flutter run --dart-define-from-file=config/lab2.free.json
```

Khi trình diễn các nút Lab 3, thêm `--dart-define=ENABLE_LAB3_DEMO=true`. Vùng demo có token test, lỗi non-fatal và crash có xác nhận. Dùng tài khoản/lớp test.

## Điều kiện còn cần hoàn tất ngoài source

Đã có đủ sáu SDK Auth, Storage, Messaging, Analytics, Crashlytics, Remote Config. Bổ sung SDK khác không thay thế các bằng chứng còn thiếu:

1. Xác minh bucket/billing/rules Storage thật; upload báo cáo và kiểm quyền khác UID.
2. Firebase Console: Auth Users, FCM ba trạng thái, DebugView ít nhất 7 event, non-fatal/fatal với UID/key; Remote Config thay UI không rebuild và offline/cache.
3. ARTEMIS: dùng bộ 16 ca ở LAB3_ACCEPTANCE_CASES.md, tối thiểu 10 ca ×3 lượt và phiên exploratory 15–30 phút. Chưa chạy ARTEMIS trong đợt này; cần môi trường/model được cấu hình và thiết bị có dữ liệu test.
4. PR review thật >=5 finding, >=2 nhóm, >=3 sửa accepted có commit; bổ sung link Figma/GitHub/video. Không thay bằng danh sách review local.

Nguồn setup ARTEMIS: https://github.com/google/artemis. Không tự cài global rules/MCP hoặc lấy số benchmark của công cụ làm kết quả dự án.

Slide/báo cáo ngày 02/11 là bản trước đợt cải tiến này; khi nộp cần cập nhật bằng chứng thực tế và số kiểm thử mới.
