# Kết nối Google đăng nhập Android

Đã tìm thấy endpoint và Google Web Client ID trong cấu hình công khai của reference, rồi điền vào `config/development.json` của mobile. Không sao chép client secret. Không sửa repository desktop hoặc triển khai backend.

## 1. Đăng ký Android OAuth client

Trong Google Cloud project đang sở hữu Web Client ID của hệ thống, tạo hoặc kiểm tra OAuth client loại **Android**:

- Package: `vn.edu.fpt.lecturer_companion`
- SHA-1 debug của máy này: `82:C5:37:A8:8B:AB:43:E8:64:32:44:B7:89:D0:EB:70:3F:61:A8:69`
- Web/server Client ID mobile đang dùng: `673290516613-h1o52ha4hu2ej2cm7es0em10mhu7uj0d.apps.googleusercontent.com`

Không thay GOOGLE_SERVER_CLIENT_ID trong app bằng Android Client ID. Android client liên kết package/chứng chỉ; serverClientId phải là web client. Kiểm tra OAuth audience/test users nếu project đang ở chế độ testing. Chứng chỉ release phải được đăng ký riêng khi phát hành.

Lấy lại SHA-1 khi đổi máy/keystore:

```powershell
.\android\gradlew.bat -p android signingReport
```

Nguồn chính thức: [google_sign_in_android integration/troubleshooting](https://pub.dev/packages/google_sign_in_android).

## 2. Backend phải chấp nhận đúng audience

Source reference `authenticate_` hiện kiểm tra `claims.aud !== cfg.audience`; config desktop dùng Client ID khác web client trên. Vì vậy, nếu deployment giống source, chỉ điền mobile config chưa đủ để đăng nhập hoàn chỉnh.

**Đề xuất thay đổi để quản trị viên xem xét, chưa áp dụng:** giữ nguyên GOOGLE_CLIENT_ID cho desktop, thêm Script Property `GOOGLE_MOBILE_CLIENT_ID` bằng Web Client ID trên; thêm thuộc tính `mobileAudience` vào object trả về của `config_()`:

```javascript
mobileAudience: p.getProperty('GOOGLE_MOBILE_CLIENT_ID') || ''
```

Trong `authenticate_`, thay riêng biểu thức kiểm tra audience:

```javascript
// Trước:
claims.aud !== cfg.audience

// Sau:
![cfg.audience, cfg.mobileAudience].filter(Boolean).includes(claims.aud)
```

Giữ nguyên mọi kiểm tra Google signature/tokeninfo, issuer, expiry, email_verified, school domains và unique Lecturers lookup. Không sửa student authentication và không bỏ audience validation. Quản trị viên cần test desktop/mobile, rồi cập nhật deployment /exec. Không đổi desktop audience để tránh làm hỏng đăng nhập desktop.

## 3. Thử đăng nhập

Chạy `powershell -ExecutionPolicy Bypass -File .\scripts\run-android.ps1`, bấm Sign in with Google và tự chọn/đăng nhập tài khoản trường trên giao diện Google. Email phải tồn tại duy nhất trong Lecturers. Không gửi mật khẩu hoặc token vào chat.

Nút sáng chỉ xác nhận app đã được cấu hình. Thành công thực sự là nhận được profile đã xác minh từ backend và mở Home. Hiện chưa xác minh được quyền Google Cloud hoặc deployment đang chạy có hỗ trợ mobile audience hay không.
