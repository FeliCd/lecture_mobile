# Kết nối Google đăng nhập Android

Trạng thái chi tiết: [GOOGLE AUTH CONTINUATION REPORT](GOOGLE_AUTH_SETUP_REPORT.md).

Tài khoản quản trị duy nhất: phucvhla2@gmail.com. Cloud project: natural-nimbus-510805-v3.

Web/server Client ID dùng trong Flutter và GOOGLE_MOBILE_CLIENT_ID:

```text
391831771866-i4vajc479qjuiflghp7ur325383nah5n.apps.googleusercontent.com
```

config/development.json đã trỏ tới Apps Script deployment v1 mới, sở hữu bởi phucvhla2@gmail.com. POST profile với token giả đã bị từ chối đúng cách.

Chạy từ thư mục dự án:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-android.ps1
```

Bảng dữ liệu: https://docs.google.com/spreadsheets/d/1hLM3Lh6TpT_bl1HojpVBMW39CxMDVfgl9LFeh6d_cJs/edit

Đăng nhập giảng viên cần email đã xác minh thuộc fpt.edu.vn hoặc fe.edu.vn và đúng một dòng tương ứng trong Lecturers. Gmail quản trị không có quyền giảng viên. Chưa kiểm thử đăng nhập thật.

Các lần cập nhật code sau: Deploy > Manage deployments > Edit > New version > Deploy trên deployment mới hiện có để giữ URL.
