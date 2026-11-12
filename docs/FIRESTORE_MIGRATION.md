# Chuyển dữ liệu dùng chung sang Cloud Firestore

Mobile và Desktop tiếp tục dùng API giảng viên. Student Web tiếp tục dùng API sinh viên. Cập nhật bản triển khai Apps Script hiện có để cả ba client giữ nguyên URL, đăng nhập và quy tắc phân quyền.

Firestore lưu từng dòng nghiệp vụ dưới `sharedApiDatasets/{dataset}/{table}/{document}`. Bộ chuyển dữ liệu giữ ID nghiệp vụ, thứ tự dòng, giá trị rỗng và các trạng thái lịch sử. Phiên cũ được đọc theo quy tắc chuẩn hóa ngày, giờ và trạng thái hiện có. Hai bảng cache tin bài dùng lại quy tắc lọc bản ghi lỗi và chọn bản mới nhất hiện có. Quy tắc truy cập Firebase trong repo chỉ cho backend dùng bộ dữ liệu này. Firestore nhận yêu cầu từ OAuth của chủ deployment Apps Script.

Bảng tính đăng ký nhóm vẫn là giao diện nhập lựa chọn theo luồng hiện có. Kết quả nhóm, trạng thái đăng ký, chat, nhiệm vụ và thông báo nằm trong Firestore sau khi chuyển. Tệp chat vẫn ở thư mục Drive riêng.

## Kiểm tra tại máy

```powershell
node --test backend/test/*.test.cjs
firebase emulators:exec --only firestore --project demo-shared-migration "node --test backend/test/firestore-migration.emulator.cjs"
```

Bài kiểm thử emulator sao chép dữ liệu mẫu rồi gửi yêu cầu qua API Mobile, Desktop và Student Web. Nó kiểm tra điểm danh có thể gửi lại, ngày phiên cũ, điểm nháp và điểm đã công bố, nhiệm vụ theo nhóm, batch điểm danh cùng audit, và từ chối truy cập Firestore trực tiếp.

## Triển khai trên dự án hiện có

1. Mở dự án Apps Script sở hữu URL `/exec` đang dùng. Lưu lại số phiên bản đang chạy. So sánh mã hiện tại với [backend dùng chung](../backend/apps_script) và tích hợp các khác biệt đang có trên cloud trước khi cập nhật. Thêm `FirestoreStore.gs`, `FirestoreMigration.gs` và cập nhật manifest để thêm quyền OAuth `datastore`. Chủ deployment cần cấp lại quyền Apps Script và có quyền đọc/ghi dữ liệu Firestore trong dự án Firebase.
2. Dùng database `(default)` của `fap-attendance-88920`. Nếu cần diễn tập ở dự án thử nghiệm, đặt Script Property `SHARED_FIRESTORE_PROJECT` trong **bản sao** của dự án Apps Script. Kiểm tra rules đang chạy từ chối client ở `/sharedApiDatasets/**`. Các file rules trong repo đã từ chối đường dẫn này. [Xác thực REST Firestore](https://firebase.google.com/docs/firestore/use-rest-api).
3. Cập nhật **deployment hiện có** lên phiên bản tương thích, giữ nguyên chế độ chạy dưới tài khoản chủ deployment và URL. Chạy `node scripts/probe-shared-backend.cjs` tại repo. Trường `health.database` phải là `sheets` ở bước này. Nếu dự án có nhiều deployment, đặt Script Property `SHARED_API_EXEC_URL` bằng đúng URL `/exec` của cả ba client. Bộ chuyển gọi URL này để xác minh phiên bản trước khi sao chép. Bảo đảm các trigger và writer đang cập nhật workbook đều thuộc backend chung. [Quản lý deployment Apps Script](https://developers.google.com/apps-script/api/how-tos/manage-deployments).
4. Từ trình chỉnh sửa Apps Script, chạy `inspectSharedDatabaseMigration`. Hàm chỉ đọc, báo số dòng mỗi bảng và kiểm tra tài khoản chạy script có đọc được Firestore. Bản cũ chưa có bảng thiết bị nhận thông báo nhóm sẽ bắt đầu với bảng này rỗng. Nếu có tab chưa ánh xạ, cấu trúc cột sai, ID trùng hoặc bảng nguồn còn thiếu, kiểm tra bảng được nêu trước khi chạy bước tiếp theo.
5. Chọn lúc ít người dùng và tạm dừng các chỉnh sửa trực tiếp vào workbook nguồn. Chạy `migrateSharedDatabaseToFirestore` một lần từ trình chỉnh sửa. Hàm giữ cùng khóa với các API ghi, sao chép 33 bảng vào dataset mới, đọc lại để so sánh số dòng và mã băm rồi đối chiếu nguồn lần cuối. Sau khi tất cả khớp, hàm đánh dấu dataset sẵn sàng và tự chuyển backend. Trong lúc sao chép, thao tác ghi từ client có thể báo bận và cần thử lại. Hàm dừng nếu vượt ngân sách thực thi bốn phút hoặc nếu có lỗi dữ liệu. Khi đó chế độ vẫn là Sheets và lần chạy tiếp theo tạo dataset mới.
6. Chạy `node scripts/probe-shared-backend.cjs --expect-firestore`. Dùng tài khoản nghiệm thu kiểm tra Mobile mở phiên, Student Web điểm danh, Desktop thấy cùng bản ghi. Kiểm tra thêm Mobile lưu điểm nháp, Desktop công bố và Student Web chỉ thấy điểm đã công bố của chính sinh viên. Chạy thử luồng giao nhiệm vụ nhóm để đối chiếu thông báo. Đo thời gian phản hồi với các lớp có sĩ số thật.
7. Giữ workbook nguồn làm bản sao trước thời điểm chuyển. Nếu phải khôi phục sau khi hệ thống đã ghi lên Firestore, đối soát các thay đổi sau chuyển trước khi đưa Sheets trở lại làm nguồn chính.

`lab2Health` trả về `database: firestore` khi URL đang dùng bộ dữ liệu Firestore đã sẵn sàng. Hàm chạy lại sau khi chuyển sẽ trả về `alreadyActive: true`.

## Chuyển API đăng ký nhóm sang Firebase

`sharedGroupSignup` là Cloud Function callable ở `asia-southeast1`. Hàm xác thực bằng Firebase Auth, mở/chốt đợt cho giảng viên sở hữu lớp và cho sinh viên có tên trong lớp chọn nhóm trực tiếp. Hàm ghi Firestore trong transaction và dùng lại `PortalGroupPlans` để giữ ID nhóm, thành viên và quyền truy cập lịch sử chat. Mỗi sinh viên chỉ xem được danh sách thành viên trong nhóm của mình. Dữ liệu của đợt đang mở qua Sheet cần được chốt trước khi mở đợt mới.

Chạy kiểm thử trong project demo với hai tham số sau trong `functions/.env.local`:

```dotenv
SHARED_DATASET_ID=dataset-11111111-1111-4111-8111-111111111111
SHARED_GROUP_SIGNUP_ENABLED=true
```

```powershell
npm.cmd --prefix functions run build
firebase.cmd emulators:exec --only auth,firestore,functions --project demo-fap-lab2 "node --test functions/test/shared-group-signup.emulator.cjs"
```

Công tắc thử nghiệm của client là `FIREBASE_GROUP_SIGNUP=true` (Dart define trên Mobile và Desktop) và `VITE_FIREBASE_GROUP_SIGNUP=true` (Student Web). Desktop dùng Google OAuth client đã đăng ký ở Cloud Functions. Công tắc đã được bật trong bản Mobile, Desktop và Student Web dùng cho lần chuyển đổi. Kiểm tra trạng thái trên API trước khi đổi quyền ghi trong các môi trường khác.


## Trạng thái chuyển đổi production

- Cloud Functions `sharedApi` và `sharedGroupSignup` phục vụ ba nền tảng trên `fap-attendance-88920`. API mới xác minh Firebase Auth cho Mobile, Student Web và trang quét QR. Desktop giữ đăng nhập Google OAuth và Cloud Functions xác minh token theo client ID đã cấu hình.
- Firestore vẫn dùng chung 33 bảng và 2.365 bản ghi tại thời điểm kiểm tra. Cả 3 tệp đính kèm cũ đã được sao chép và đối chiếu. Nội dung tệp lưu riêng trong Firestore, chỉ đọc qua kiểm tra tư cách thành viên nhóm.
- Marker `backendWriter=firebase` trao quyền ghi cho Cloud Functions. Phiên bản 51 của API cũ chặn ghi cùng precondition Firestore. Phiên bản 52 đã ngừng phục vụ API cũ và các hàm tác vụ định kỳ cũ trả về ngay. URL cũ đã trả BACKEND_MOVED_TO_FIREBASE trong kiểm tra production.
- Student Web và trang quét QR đã phát hành trên Firebase Hosting. Chạy `node scripts/probe-shared-backend.cjs` để kiểm tra URL thật, quyền ghi, xác thực và hai bản Hosting.
- Tác vụ tự chốt điểm danh đã triển khai lên Cloud Scheduler. Email giao việc có hàng đợi `sharedTaskMail`. Cần Firebase Trigger Email với SMTP của dự án và bật `SHARED_TASK_MAIL_ENABLED=true` trước khi gửi email. Thông báo trong Student Web vẫn đọc Firestore qua API.
- Desktop đã có Windows Release. Mobile có APK debug và cần khóa ký Android của dự án để build Release. Kiểm thử quyền và nghiệp vụ đã chạy trên emulator. Cần đăng nhập tài khoản thật trên thiết bị để xác nhận hoàn chỉnh luồng thiết bị đầu cuối.
