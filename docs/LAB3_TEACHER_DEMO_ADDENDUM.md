# Bổ sung theo yêu cầu demo và lời giải thích của thầy

Nguồn: ảnh “Yêu cầu Lab 3 – Demo ứng dụng” và lời thầy do người dùng cung cấp: “mô tả các công nghệ sử dụng: nó là gì – nguyên lý hoạt động – chỗ nào implement”. Đối chiếu source ngày 05/11/2026 và PDF hướng dẫn v5 trước đó.

## Cách trình bày

Mỗi công nghệ cần bốn phần: định nghĩa ngắn; luồng hoạt động; đường dẫn/class triển khai thật; thao tác demo và kết quả quan sát. Không chỉ liệt kê package hoặc tính năng. Slide 14 trang đã bổ sung nội dung này, giữ six Firebase services của PDF gốc; ảnh mới không có lời xác nhận bỏ Analytics/Remote Config hay các hồ sơ cũ.

## Tám mục trong ảnh

| Mục | Hiện tại | Demo / bổ sung |
|---|---|---|
| 1. Mobile trực tiếp trên điện thoại | APK build pass | Cài và chạy trên điện thoại thật; build/emulator không thay mục này |
| 2. Web qua link deploy | Có link https://fap-sinhvien.web.app/ theo ngữ cảnh dự án | Mở link, đăng nhập SV test; xác nhận phiên bản deploy, không dùng localhost |
| 3. MVVM | ViewModel Riverpod, repository/services | Mở session_view_model.dart (SessionOpeningController, AttendanceEditController), notebook_view_model.dart và View gọi controller; giải thích state/busy/error |
| 4. Image Storage | FirebaseReportStorage chỉ upload .xlsx; rules chỉ MIME Excel | Chưa đạt mục hình ảnh: cần chọn ảnh JPEG/PNG → progress → URL/preview → đường dẫn Firebase Console. Tệp Drive/chat không tự thay bằng chứng Firebase Storage |
| 5. Bấm kích hoạt push | Có receiver FCM; cloud_pages.dart:341 chỉ gọi testToken | Chưa có nút gửi push trực tiếp. Cần button gọi backend được xác thực → FCM → thiết bị; quay banner/tray, lịch sử và tap route |
| 6. Nút mô phỏng crash | Có cloud_pages.dart:368–395, CloudTelemetry.demoCrash | Bật ENABLE_LAB3_DEMO, xác nhận crash, mở lại, đối chiếu Crashlytics Console |
| 7. Google Authentication | Firebase Google credential trong repository.dart | Google chooser → Auth Users → logout/guard; kiểm quyền giảng viên riêng, Gmail không tự có quyền lớp |
| 8. Công cụ testing Google | PDF trước chỉ rõ ARTEMIS; có kế hoạch ca test | Chưa đủ bằng chứng tích hợp/chạy. Cần setup công cụ, thiết bị, thực thi và logs; unit/widget test không tự thay ARTEMIS |

## Phần công nghệ cần triển khai tiếp

1. **Ảnh:** service riêng + ViewModel; path theo UID, MIME/dung lượng/đuôi hợp lệ; rules owner-only; test user khác/anonymous/offline; hiển thị tiến độ, lỗi, URL và ảnh sau upload. Không nới rules báo cáo thành cho phép mọi tệp.
2. **Push tự thử:** backend đáng tin cậy giữ credential Firebase Admin, xác thực caller và giới hạn token của chính caller; chống spam; button hiển thị gửi/thất bại. Không nhúng service-account key trong Flutter/Web. Phản hồi gửi thành công chưa chứng minh thiết bị đã nhận; cần kiểm nhận thật.
3. **ARTEMIS:** chạy ca trên tài khoản/lớp test, giữ giá trị actual và log; ≥10 ca ×3 lượt và khám phá 15–30 phút theo PDF. Không dùng benchmark của ARTEMIS làm pass rate dự án.

Nguồn kỹ thuật chính thức đã đối chiếu: [Google ARTEMIS](https://github.com/google/artemis), [FCM trusted server environment](https://firebase.google.com/docs/cloud-messaging/server-environment).

Lần cập nhật này sửa slide, lời thuyết trình và checklist; **chưa thêm các chức năng ứng dụng nêu trên**, chưa deploy, chưa gây crash hoặc gửi push/email. Kết quả test trong slide là kết quả rà soát 05/11, không phải lần chạy mới do sửa tài liệu.
