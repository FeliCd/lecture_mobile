# Sinh viên chọn nhóm bằng Google Sheets

## Luồng sử dụng

1. Giảng viên mở lớp → Nhóm học tập → **Tạo Sheet chọn nhóm**.
2. Nếu lớp đã có nhóm, giữ ID, tên, thành viên và phòng chat hiện tại. Nếu chưa có nhóm, dùng số nhóm đang chọn để tạo các nhóm trống.
3. Xác nhận tạo một file riêng và cấp quyền cho email trường trong roster. Chỉ email được cấp quyền mở được link; sinh viên sửa ô Chọn nhóm của mình, giảng viên sửa được toàn bảng. Thành viên trong lớp xem được tên/MSSV của nhau trên Sheet.
4. **Sao chép link** để gửi cho sinh viên. Student Web cũng hiện nút **Chọn nhóm trên Google Sheets** ở màn Nhóm học tập khi đợt đăng ký đang mở. Tính năng không gửi email mời Drive.
5. Sinh viên mở đúng tài khoản email trường, tìm dòng MSSV và chọn nhóm trong dropdown. Chờ cột Đồng bộ xác nhận. Chọn trống nghĩa là chưa có nhóm.
6. Một clock trigger dùng chung quét các đợt đang mở khoảng mỗi phút. Giảng viên có nút **Đồng bộ ngay**. Kết quả ghi vào `PortalGroupPlans`, cùng dữ liệu desktop/mobile/web đang đọc; không cần nhập lại danh sách.
7. Màn nhóm desktop/mobile kiểm phiên bản mỗi 15 giây và tự tải danh sách mới khi không có thay đổi/bản nháp. Đang nhập tin nhắn, chọn file hoặc sửa nhóm sẽ giữ bản nháp và chờ lần tải tiếp theo. Student Web hiện cần bấm Tải lại nhóm sau khi Sheet xác nhận.
8. **Chốt đăng ký** khóa cột chọn nhóm, đồng bộ lần cuối và giữ kết quả đã ghi nhận. Sinh viên còn trống chưa được tự xếp nhóm; giảng viên xử lý bằng chỉnh thủ công sau khi chốt.

Sheet không phải realtime tức thì; trigger Google và mạng có thể làm thời gian cập nhật dài hơn chu kỳ dự kiến. Khi app desktop đóng, lần mở màn nhóm tiếp theo tải dữ liệu hiện hành.

## Bảng đăng ký

Mỗi lớp có một Spreadsheet riêng, một tab **Chọn nhóm**:

| Cột | Nội dung | Quyền sửa |
| --- | --- | --- |
| A | MSSV | Owner/giảng viên |
| B | Họ tên | Owner/giảng viên |
| C | Chọn nhóm, dropdown | Từng sinh viên ở ô của mình và owner/giảng viên |
| D | Đồng bộ | Backend/owner/giảng viên |
| E | Cập nhật theo giờ Việt Nam | Backend/owner/giảng viên |

Header cố định, ô chọn nhóm có nền vàng nhạt. Dropdown có nhãn số và tên nhóm để tránh dùng tên nhóm như công thức. Tên/MSSV đưa vào sheet dưới dạng text. Không đưa bảng điểm, attendance, API token hoặc backend spreadsheet ID vào bảng đăng ký.

## Nguồn code và triển khai

- Backend chuẩn: `C:/Users/ADMIN/Desktop/FPT-Lecturer-Mobile-App/backend/apps_script`.
- Mobile: repo hiện tại, `lib/groups/group_signup_panel.dart`, `study_groups.dart`.
- Desktop: worktree **`C:/Users/ADMIN/Desktop/FAP-Desktop-Group-Signup`**, nhánh **`codex/group-sheet-sync`**, từ `origin/main` commit `3263f63`. Nhánh `feature/extension` và hai file backend đang sửa trong checkout desktop gốc được giữ nguyên.
- Student Web: `C:/Users/ADMIN/Desktop/FapAttendanceWeb`.

Owner Apps Script thực hiện:

1. Cập nhật gói backend dùng chung đầy đủ, gồm `GroupSignupSheets.gs`, `StudyGroups.gs`, `StudentPortal.gs`, `Lab2Free.gs` và manifest hiện tại. Các tính năng giao việc/file trước đó tiếp tục cần các module tương ứng trong cùng gói.
2. Manifest bổ sung Advanced Drive v3 (`Drive`) cùng scope `userinfo.email`; giữ Sheets v4, Drive và script.scriptapp đã có. Bật Drive API nếu Console yêu cầu; owner cấp lại các scope cần thiết. Backend chạy dưới owner như deployment hiện hành.
3. Chạy **`setupGroupSignupSheets()`** một lần để thêm bảng `PortalGroupSignupSheets` và tạo clock trigger `syncGroupSignupSheets`. Dùng một owner cài trigger để tránh các tài khoản tạo nhiều bản trigger.
4. Deploy new version trên URL `/exec` cũ. Giữ Spreadsheet ID, Google audiences và cấu hình Firebase hiện hành.
5. Chạy desktop từ worktree/merge thay đổi UI vào branch triển khai; sử dụng `config/local.json` của desktop hiện tại. Worktree chưa tự sao chép config local hoặc thay checkout gốc.
6. Triển khai Student Web nếu muốn sinh viên thấy nút mở Sheet; link sao chép từ app vẫn dùng được trực tiếp trong Google Sheets.

Hiện các thay đổi chỉ ở local, chưa commit/push/deploy; chưa tạo hoặc chia sẻ Sheet thật. Không cần quyền Firebase Console để tạo bảng Google, nhưng cần owner có quyền cập nhật Apps Script/backend và tạo/chia sẻ file Drive.

## Đồng bộ và phục hồi

- `createGroupSignupSheet`: classId, version, groupCount, requestKey; chỉ chủ nhiệm lớp có role giảng viên. Student không gọi được thao tác quản trị.
- `getGroupSignupSheet`: giảng viên xem trạng thái; sinh viên có enrollment chỉ nhận link khi đang mở. Không trả email/roster nội bộ hoặc request key.
- `resumeGroupSignupSheet`: tiếp tục file PREPARING sau lỗi mạng/cấp quyền hoặc mở lại app; tái sử dụng file đã được ghi nhận, không yêu cầu client giữ request key cũ.
- `syncGroupSignupSheet`: đồng bộ ngay; kiểm lại version, owner, roster và nội dung các ô.
- `closeGroupSignupSheet`: khóa chỉnh sửa và đồng bộ lần cuối; có thể chốt cả đợt đang lỗi/đang chuẩn bị để mở lại sau khi xử lý.
- `syncGroupSignupSheets`: clock trigger; dùng ScriptLock chung với API. Một batch ghi group plan, phiên bản đăng ký và audit.

Sai nhóm hoặc có công thức trong cột C: không ghi bất kỳ lựa chọn mới nào trong lượt đó, báo tại cột D và app để sửa. Đổi roster, người phụ trách hoặc version nhóm ngoài luồng: chuyển CONFLICT, khóa đăng ký và giữ bản nhóm đã commit; giảng viên chốt rồi mở lượt mới với dữ liệu mới.

Trong lúc đang mở/PREPARING/CONFLICT, thao tác lưu/chia lại nhóm trực tiếp bị khóa để tránh hai nguồn ghi đè nhau. Chat và giao việc vẫn dùng ID nhóm hiện hành và kiểm quyền theo membership hiện tại. File đã tải xuống trước khi chuyển nhóm không thể bị thu hồi.

Quyền file restricted theo người, không anyone/domain/group; `writersCanShare=false`. Nếu file mới có quyền bất ngờ ngoài roster, backend dừng trước khi điền roster. Tạo file/thiết lập quyền Drive và ghi backend không có một giao dịch chung: lỗi trước khi lưu được ID có thể để lại file trống riêng tư; owner kiểm tra khi bảo trì. Lỗi sau khi đã lưu ID có thể tiếp tục bằng cùng file. Chưa có giới hạn sĩ số từng nhóm hoặc deadline tự chốt.

## Kiểm chứng trước khi dùng với lớp thật

Các test local dùng Apps Script VM và widget mocks; chưa chứng minh quyền trên tài khoản Google thật. Owner dùng lớp test và hai tài khoản sinh viên để xác nhận: mở link đúng email → chỉ sửa được ô riêng → người ngoài lớp không truy cập → chọn nhóm → cột D xác nhận → desktop cập nhật → đang có bản nháp không bị mất → chốt → sinh viên không đổi được nữa. Thử đổi nhóm và kiểm quyền chat/tệp cũ bằng API.

Kết quả local: 142 test backend, 273 test mobile, 68 test desktop và 29 test web pass; analyzer phần nhóm mobile/desktop sạch; web production build thành công. Các ca mới gồm phục hồi PREPARING, chống ghi đè roster/version, quyền từng dòng và tự tải desktop khi không có bản nháp.

Nguồn chính thức: [Protection/range permissions](https://developers.google.com/apps-script/reference/spreadsheet/protection), [installable triggers](https://developers.google.com/apps-script/guides/triggers/installable), [Advanced Drive](https://developers.google.com/apps-script/advanced/drive), [Session/effective user](https://developers.google.com/apps-script/reference/base/session).
