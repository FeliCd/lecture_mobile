# Lời thuyết trình - bản 03/11/2026

Phần nói khoảng 7 phút 30 giây; thêm demo 1–2 phút để tổng thời gian khoảng 9 phút. Lời dẫn cũng đã có trong Speaker Notes của PowerPoint.

## Slide 1: Mở đầu (25 giây)

Em xin trình bày FAP Attendance, hệ thống hỗ trợ giảng viên và sinh viên. Phần Lab 3 tập trung vào sáu dịch vụ Firebase, kiến trúc quản lý trạng thái và kiểm thử. Bản cập nhật ngày 3 tháng 11 cải thiện ba luồng chính và khả năng phục hồi khi lỗi.

## Slide 2: Bài toán và phạm vi (30 giây)

Giảng viên dùng mobile hoặc desktop để xem lịch, điểm danh và quản lý lớp. Sinh viên dùng web để xem điểm đã công bố, xin nghỉ và cộng tác nhóm. Các client sử dụng chung backend kiểm quyền, vì vậy dữ liệu điểm danh được giữ nhất quán. Firebase bổ sung xác thực và các dịch vụ cloud cần cho Lab 3.

## Slide 3: Ba luồng chính (40 giây)

Luồng một là chọn đúng buổi và mở hoặc tiếp tục phiên. Nếu mất phản hồi khi mở, app yêu cầu kiểm tra lại server. Luồng hai là sửa điểm danh với lý do: giữ input khi lỗi và không cho lưu trùng. Luồng ba là sổ tay theo buổi, có tự lưu và thử lại. Sổ tay hiện lưu trên thiết bị theo tài khoản, chưa đồng bộ đa thiết bị.

## Slide 4: Kiến trúc MVVM (40 giây)

Widget giữ phần nhập liệu và điều hướng. Riverpod ViewModel giữ trạng thái đang xử lý, lỗi và tác vụ. Repository và service thực hiện I/O. Ba controller tương ứng là SessionOpeningController, AttendanceEditController và NotebookController. Auth và quyền push cũng có controller riêng. Việc tách này cho phép dùng service giả để kiểm tra lỗi mà không ghi dữ liệu lớp thật.

## Slide 5: Authentication (30 giây)

Google cung cấp credential để Firebase xác minh danh tính. Backend tiếp tục kiểm quyền giảng viên và lớp; đăng nhập thành công chưa đồng nghĩa có mọi quyền. AuthActionsController chặn thao tác trùng và cho thử lại sau hủy hoặc lỗi. authStateChanges phối hợp với router guard. Khi nghiệm thu cần quay login, hủy và logout, cùng ảnh Console Users.

## Slide 6: Cloud Storage (30 giây)

Báo cáo Excel được upload vào đường dẫn theo Firebase UID. UI hiển thị tiến độ, kết quả hoặc lỗi. Rules giới hạn chủ sở hữu, loại tệp và kích thước; đã kiểm bằng emulator. Upload trên bucket thật còn cần xác minh cấu hình và bằng chứng Console. Tệp nhóm trên Drive là chức năng riêng, không được tính thay Cloud Storage.

## Slide 7: Cloud Messaging (40 giây)

FCM có ba nhánh: foreground, background và khi ứng dụng đã đóng. Trung tâm thông báo giữ lịch sử theo UID. Cập nhật mới hiển thị quyền hiện tại, chặn mở prompt trùng và kiểm lại khi quay về từ cài đặt Android. Chạm push chỉ điều hướng tới route cho phép. Cần thử gửi Console ở cả ba trạng thái; nhắc lịch local không thay bằng chứng FCM.

## Slide 8: Analytics (30 giây)

Kế hoạch event được viết trước khi tích hợp. Bảng có bảy event vì login và logout là hai sự kiện. Mục tiêu là quan sát bước người dùng hoàn thành, không thu nội dung cá nhân. Event ghi dữ liệu chỉ gửi sau phản hồi server thành công. Cần mở DebugView để kiểm từng event và tham số.

## Slide 9: Crashlytics (30 giây)

Crashlytics ghi lỗi đã xử lý và lỗi toàn cục, kèm Firebase UID cùng operation và app_mode. Nội dung nhạy cảm không được đưa vào raw exception gửi đi. Bản demo có nút non-fatal và crash cần xác nhận. Chỉ thử khi đã lưu dữ liệu, sau đó mở lại app và đối chiếu Console. Hiện chưa có đủ ảnh Console để đánh dấu hoàn tất.

## Slide 10: Remote Config (40 giây)

Hai tham số điều khiển bật trang Cập nhật và số bài mỗi lần tải. Chúng đã được publish và native smoke đã nhận giá trị remote. UI mới cho biết nguồn cấu hình, thời điểm tải thành công theo GMT+7 và lỗi fetch. Khi offline, app dùng cache hoặc default. Demo cần thay giá trị trên Console, tải lại và quan sát UI mà không rebuild.

## Slide 11: Nhóm học tập (30 giây)

Giảng viên chia nhóm; sinh viên chỉ xem nhóm được phân công. Chat có bubble, thời gian gửi từ server và trạng thái nhận, xem dựa trên xác nhận thiết bị. Tệp giới hạn 500 KB và kiểm quyền theo nhóm. Ảnh trên slide dùng dữ liệu mẫu để minh họa bố cục. Chat cập nhật mỗi 10 giây; receipt hiện được phát từ web mới.

## Slide 12: Skeleton và phục hồi (25 giây)

Skeleton được hiển thị theo trạng thái request ở các màn lớp, điểm, xin nghỉ và chat. Khi lỗi, giao diện thoát loading và cho thử lại. Web hỗ trợ reduced motion; phần chat giữ bản gửi khi kết quả chưa xác định. Ảnh này là fixture để minh họa trạng thái chờ, không phải ảnh lỗi hệ thống thật.

## Slide 13: Kết quả kiểm thử (35 giây)

Ngày 3 tháng 11, toàn bộ 251 kiểm thử Flutter pass, analyzer sạch và build APK debug thành công. Các số backend, web, Storage rules và native smoke là kết quả đã chạy ngày 2 tháng 11. Mỗi bộ có phạm vi khác nhau; không cộng chúng thành tỷ lệ đạt Lab. Unit test và native smoke chưa thay thế 30 lượt ARTEMIS hoặc bằng chứng Firebase Console.

## Slide 14: Kết luận (25 giây)

Kết quả chính là tích hợp sáu SDK Firebase, tách tác vụ của ba luồng qua ViewModel và cải thiện phục hồi lỗi. Để chốt nghiệm thu Lab 3, nhóm còn cần Console evidence, ARTEMIS và PR review có commit cùng các link hồ sơ. Sau đây em có thể demo luồng điểm danh, sổ tay và cấu hình cloud. Em xin nhận câu hỏi của thầy và các bạn.

## Demo ngắn 1–2 phút

Chuẩn bị trước: tài khoản và lớp test, một buổi hợp lệ, bản Android mới, mạng ổn định. Không dùng lớp đang vận hành để sửa điểm danh thử. Kiểm tra backend và web đã deploy bản chat mới nếu định demo receipt.

1. Mở buổi test từ Hôm nay: chỉ rõ lớp/slot và mở hoặc tiếp tục phiên (20 giây).
2. Sửa một sinh viên test, nhập lý do, chờ xác nhận rồi đối chiếu trạng thái (25 giây).
3. Nhập sổ tay, đợi “Đã lưu”, quay lại mở đúng buổi (20 giây).
4. Tài khoản → Thông báo: chỉ ra quyền hiện tại; Tài khoản → Dịch vụ đám mây: chỉ nguồn cấu hình và thời gian tải (25 giây).
5. Nếu còn thời gian, mở web nhóm để minh họa chat (20 giây).

FCM/Crashlytics/Storage Console nên chuẩn bị clip riêng sau khi đã kiểm chứng thật. Không gây crash trong demo ngắn. Nếu mạng lỗi, chỉ ra trạng thái lỗi/phục hồi và chuyển sang slide; không tuyên bố thao tác cloud thành công.

## Câu hỏi thường gặp

**Vì sao dùng Firebase nhưng dữ liệu vẫn ở Sheets?** Firebase đảm nhiệm sáu dịch vụ của Lab; Apps Script/Sheets tiếp tục là nguồn nghiệp vụ chung để mobile, desktop và web đồng bộ.

**Riverpod có phải MVVM không?** Riverpod là công cụ quản lý trạng thái/DI. MVVM thể hiện ở việc View chuyển lệnh cho controller, controller quản lý trạng thái và gọi repository/service. Ba luồng đã được tách tác vụ; không khẳng định mọi màn legacy đã refactor.

**251 test pass có nghĩa đạt Lab 3 chưa?** Chưa. Đây là unit/widget tests; còn Console evidence, ARTEMIS, PR review và hồ sơ bắt buộc.

**Đã xem trong chat có chính xác tuyệt đối không?** Hệ thống xác nhận tin đã hiển thị trong viewport của trang đang focus. Không thể chứng minh người dùng đã đọc hiểu. Mobile/desktop cũ chưa phát read receipt.

**Sổ tay có đồng bộ không?** Hiện lưu local theo tài khoản; app ghi rõ giới hạn này.

**Khi mở phiên bị timeout thì sao?** App buộc đọc lại trạng thái server trước lần gửi tiếp. Nếu phiên đã tồn tại, người dùng tiếp tục phiên đó.

## Trước buổi trình bày

- Mở PPTX bằng PowerPoint và thử Presenter View; PDF là bản trình chiếu dự phòng.
- Kiểm tra tên/MSSV trên bìa. Nếu trình bày theo nhóm, thay bằng danh sách nhóm đã xác nhận.
- Bổ sung link Figma và video thật; repo hiện tại: https://github.com/FeliCd/lecture_mobile.
- Các mục Console/ARTEMIS/PR còn thiếu được ghi trung thực. Chỉ cập nhật thành đã hoàn tất sau khi có bằng chứng.
- Báo cáo PDF 02/11 chưa được chỉnh trong lần cập nhật slide này.
