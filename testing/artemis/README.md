# ARTEMIS nghiệm thu Lab 3

Đã clone Google ARTEMIS vào `C:/PRM/tools/artemis`, cài dependencies bằng uv, CLI và doctor chạy được. `.env` tại thư mục đó chứa key local, không đưa vào repository hoặc slide. Dashboard/replay: http://127.0.0.1:8000.

Mở app demo và đăng nhập tài khoản test trước. Bộ `cases.json` gồm 10 ca chỉ đọc hoặc hủy thao tác để tránh ghi dữ liệu lớp thật. Đây là phần cơ sở: bổ sung ca lỗi mạng và tương tác Android native có người giám sát trước khi chốt đủ rubric. Các luồng mở phiên/sửa điểm danh thực phải dùng lớp test và có bằng chứng server, không dùng read-only case thay flow ghi.

Chạy bằng Python 3.12+:

```powershell
python testing/artemis/run_cases.py --case T01 --runs 1
python testing/artemis/run_cases.py --runs 3
```

Nếu máy không có Python trên PATH, dùng `C:/PRM/tools/artemis/.venv/Scripts/python.exe`. Log và CSV lưu trong `tmp/artemis-evidence/<timestamp>`. Mỗi lượt mặc định REVIEW_REQUIRED; đối chiếu replay/actual với expected rồi mới điền PASS/FAIL/BLOCKED. CLI exit 0 hoặc agent SUCCESS không tự là PASS. Chỉ tính pass rate từ lượt thực tế, ghi riêng blocked/not-run. Ghi thêm phiên khám phá 15–30 phút với giờ bắt đầu/kết thúc, thao tác, lỗi và evidence.

ARTEMIS gửi ảnh màn hình/ngữ cảnh tới nhà cung cấp mô hình đã cấu hình: chỉ dùng tài khoản/lớp test, đóng dữ liệu sinh viên thật trước khi chạy. Không để agent tự đăng nhập, cấp quyền, xác nhận crash hoặc sửa dữ liệu production.

Nguồn: https://github.com/google/artemis, checkout 351ca84.
