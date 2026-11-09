# ARTEMIS nghiệm thu Lab 3

Runner nhận `--artemis-dir` hoặc biến `ARTEMIS_HOME`. Nếu không truyền, runner tìm `~/.local/share/artemis-lab3` rồi dùng đường dẫn cũ `C:/PRM/tools/artemis`. Đặt API key trong `.env` của ARTEMIS và giữ file này ngoài repository.

Mở app demo và đăng nhập tài khoản test trước. Bộ `cases.json` gồm 10 ca chỉ đọc hoặc hủy thao tác để tránh ghi dữ liệu lớp thật. Đây là phần cơ sở: bổ sung ca lỗi mạng và tương tác Android native có người giám sát trước khi chốt đủ rubric. Các luồng mở phiên/sửa điểm danh thực phải dùng lớp test và có bằng chứng server, không dùng read-only case thay flow ghi.

Chạy bằng Python 3.12+:

```powershell
python testing/artemis/run_cases.py --case T01 --runs 1
python testing/artemis/run_cases.py --runs 3
python testing/artemis/run_cases.py --case T01 --runs 1 --artemis-dir C:/tools/artemis
python testing/artemis/run_cases.py --case T06,T07 --runs 3 --test-class DEMO01
```

Nếu máy không có Python trên PATH, dùng `C:/PRM/tools/artemis/.venv/Scripts/python.exe`. Log và CSV lưu trong `tmp/artemis-evidence/<timestamp>`. Mỗi lượt mặc định REVIEW_REQUIRED; đối chiếu replay/actual với expected rồi mới điền PASS/FAIL/BLOCKED. CLI exit 0 hoặc agent SUCCESS không tự là PASS. Chỉ tính pass rate từ lượt thực tế, ghi riêng blocked/not-run. Ghi thêm phiên khám phá 15–30 phút với giờ bắt đầu/kết thúc, thao tác, lỗi và evidence.

Runner kiểm API key hiện diện mà không in key. Thiếu executable hoặc key thì ghi `NOT_RUN`, không điều khiển máy và không tính lượt đó là thực thi. `RUN_ERROR` là lỗi CLI, `TIMEOUT` là quá thời gian chờ (mặc định 600 giây/lượt), đều cần xem log. Chạy T01 một lượt trước, sau khi xác nhận môi trường mới chạy đủ bộ. Thay `DEMO01` bằng mã lớp được phép dùng để kiểm thử; T06/T07 không chạy nếu thiếu mã lớp.

Mỗi lượt thực thi có ảnh PNG và XML chụp sau khi công cụ kết thúc. Ảnh cuối có thể rơi vào chuyển cảnh: dùng thêm `export_trace_evidence.py <thư-mục-kết-quả>` để xuất ảnh/UI tree đúng từng bước từ database ARTEMIS. Runner chạy standalone và khi timeout trên Windows sẽ dừng đúng cây tiến trình của lượt đó. Không tự ghi PASS; sau đối chiếu, lưu kết quả duyệt thành file riêng để giữ nguyên CSV gốc. Nếu dùng lớp hiện có để kiểm tra, phải có phạm vi người dùng cho phép, chỉ đọc và không gọi dữ liệu đó là dữ liệu giả.

Khi có nhiều thiết bị, đặt `ADB_DEVICE_SERIAL` trong `.env` ARTEMIS hoặc môi trường chạy. Runner dùng cùng cấu hình ADB để chụp ảnh và lấy XML sau lượt kiểm thử.

ARTEMIS gửi ảnh màn hình/ngữ cảnh tới nhà cung cấp mô hình đã cấu hình: chỉ dùng tài khoản/lớp test, đóng dữ liệu sinh viên thật trước khi chạy. Không để agent tự đăng nhập, cấp quyền, xác nhận crash hoặc sửa dữ liệu production.

Nguồn: https://github.com/google/artemis, checkout 351ca84.
