# Kịch bản kiểm thử ARTEMIS cho Lab 3

Ứng dụng: `vn.edu.fpt.lecturer_companion` trên Android. Bộ chính thức gồm 10 ca, dự kiến 3 lượt mỗi ca. Nội dung ca và các bước thực thi nằm trong `cases.json`.

| Mã | Thao tác | Kết quả cần đối chiếu |
|---|---|---|
| T01 | Mở Trung tâm thông báo | Có tiêu đề, trạng thái quyền, tin mới và thời gian hoặc trạng thái trống rõ ràng |
| T02 | Mở Dịch vụ đám mây | Có các trạng thái Firebase, Storage, Analytics, Crashlytics |
| T03 | Xem Remote Config | Có nguồn cấu hình, trạng thái bật/tắt và số bài trong khoảng 5–30 |
| T04 | Mở Hôm nay | Có ngày và ca dạy hoặc trạng thái trống; không mở phiên điểm danh |
| T05 | Mở Lịch dạy rồi quay lại | Giữ tài khoản và học kỳ đã chọn |
| T06 | Mở danh sách lớp thử | Có danh sách hoặc trạng thái trống/lỗi; không sửa điểm danh |
| T07 | Mở Sổ tay buổi học | Tiêu đề Sổ tay và thông tin buổi học thuộc lớp truyền qua `--test-class` |
| T08 | Mở chọn ảnh Firebase Storage rồi hủy | Đúng Dịch vụ đám mây và nút Chọn và upload ảnh; không dùng màn OCR |
| T09 | Xem giới hạn upload | Hiện định dạng PNG/JPEG và giới hạn 5 MB |
| T10 | Mở hộp thoại crash rồi hủy | Có xác nhận, bấm Hủy trở về và app vẫn chạy |

## Điều kiện thực hiện

- Máy ảo đã kết nối ADB và app đã có phiên tài khoản thử nghiệm.
- ARTEMIS đã cài dependencies và cấu hình API key cho mô hình.
- T06 và T07 chỉ chạy khi có lớp/buổi thử được xác định rõ. Thiếu điều kiện thì ghi BLOCKED, không tự chọn lớp thật.
- Không tự đăng nhập, cấp quyền, gửi tin, xác nhận crash hoặc lưu dữ liệu lớp trong bộ này. Lượt crash thật và upload thật ở các slide minh chứng là kiểm tra có người điều khiển riêng, không cộng thành kết quả ARTEMIS.

## Chạy và xét kết quả

Chạy T01 một lượt để kiểm tra môi trường, sau đó mới chạy `--runs 3` cho toàn bộ bộ ca. Mỗi lượt phải đối chiếu expected với ảnh/replay và log. CLI exit 0 hoặc agent báo SUCCESS chưa đủ để kết luận PASS.

- PASS: quan sát đủ kết quả mong đợi, không có thay đổi ngoài phạm vi.
- FAIL: đã thực thi và quan sát hành vi trái expected.
- BLOCKED: thiếu điều kiện để thực hiện ca, ví dụ chưa có lớp thử.
- NOT_RUN: runner chưa khởi chạy ca do thiếu cài đặt hoặc key.
- RUN_ERROR / TIMEOUT: lỗi thực thi công cụ, cần xem log và trạng thái thiết bị.

CSV kết quả và log nằm trong `tmp/artemis-evidence/<timestamp>`. Chỉ tổng hợp kết quả các lượt thực sự đã chạy; không chuyển kiểm thử ADB thủ công thành kết quả ARTEMIS.

## Kết quả đối chiếu ngày 06/11/2026

Bộ chốt gồm 30 lượt kiểm tra UI (10 ca × 3 lượt), đã đạt các điều kiện quan sát sau khi đối chiếu ảnh/UI tree đúng bước và các thao tác ghi trong trace. Kết quả đối chiếu được lưu cục bộ tại `tmp/artemis-evidence/LAB3-OFFICIAL-20261106/results-reviewed.csv`; CSV gốc giữ nguyên trạng thái REVIEW_REQUIRED. Các lượt chỉ quan sát màn đang mở được ghi đúng là kiểm tra UI, không coi là đã thực hiện lại toàn bộ điều hướng từ đăng nhập.

Trong lịch sử đã có T08 đi nhầm màn OCR và T07 nhận nhầm Nhóm học tập là notebook dù agent báo completed. Các lượt đó không đạt; một lượt T08 bị dừng khi đi vào form, phần nhập chưa lưu đã được bỏ. Sau khi bổ sung tên màn/nút tiếng Việt chính xác và cấm nhập trường, các ca được chạy xác nhận lại. Giữ nguyên các log cũ và ghi nhận này, không lấy bộ chốt 30 lượt để mô tả mọi lần thử ban đầu đều thành công.

ARTEMIS checkout `351ca84`, profile `flash`, model thực `gemini-3.5-flash-lite`. Có điều chỉnh cấu hình model và warmup cục bộ vì model mặc định trả 503/quota; không dùng chế độ LLM giả. Thiếu scrcpy nên không có video replay; ảnh từng bước và UI tree được xuất từ database ARTEMIS. Bộ này không thay thế kiểm thử ghi điểm danh, email, đồng bộ ba nền tảng hoặc đối chiếu Firebase Console.
