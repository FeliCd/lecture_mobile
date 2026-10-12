# Demo Lab 2 — hai tài khoản / hai máy

Chạy emulator, seed và app theo SETUP. Phone/emulator phải truy cập cùng Auth/Firestore/Functions host. Tài khoản/roster hoàn toàn tổng hợp.

## A. Smart QR Attendance

1. Lecturer A đăng nhập → Trang chủ/Lớp học → SE1928 / PRM393. Có hai lớp đúng phân công, không có lớp lecturer B.
2. Buổi học → Tạo buổi → nhập tên → Mở điểm danh, chọn 10 phút/ngưỡng muộn 5 phút. Hoặc xem phiên QR fixture đã mở sau seed.
3. Host hiển thị QR trắng, countdown, counters, stream sinh viên. Student 0 ở thiết bị thứ hai → Điểm danh → Quét QR, cấp camera permission.
4. Student nhận trạng thái Có mặt/Đi muộn từ server; host thấy tên/MSSV và counter cập nhật.
5. Quét lại không tăng count. Outsider quét bị từ chối. Mã bị sửa/hết hạn bị reject.
6. Lecturer kết thúc, các member trong snapshot còn thiếu được ghi absent. Quay Thống kê xem dữ liệu finalized.

QR không chứng minh vị trí tại phòng học. Test camera permission denied/flash/scan trên thiết bị cần chạy khi có Android. Nhập token thủ công chỉ xuất hiện khi build USE_EMULATORS=true để hỗ trợ emulator không có camera.

## B. Attendance Analytics

1. Lớp → Thống kê: seed có 5 buổi lịch sử/lớp; dashboard có finalized count, attendance rate, absence today/total, Cần theo dõi.
2. Chọn 30/90 ngày hoặc toàn kỳ; tìm tên/MSSV; lọc trạng thái; sắp vắng nhiều/tên. Tap chart buổi hoặc sinh viên xem lịch sử.
3. late tính attended, excused loại denominator, cancelled/open không tính. N/A khi không có eligible records.
4. Xuất CSV → Android share sheet → lưu/mở Excel. Kiểm tra tiếng Việt/quotes/columns. Import CLI preview dành cho operator, không có màn admin.

## C. Subject News

1. Lecturer → Khám phá → PRM393/OpenAlex, nhập từ khóa. Chuyển PRN212 và Crossref để đổi taxonomy/provider.
2. Metadata thật có source/publisher/date/author nếu nguồn cung cấp; không có abstract hiển thị Chưa có tóm tắt.
3. Tap bài → Mở nguồn external browser; Chia sẻ cho lớp cùng môn, ghi chú optional.
4. Student → Tài liệu → lớp → bài được chia sẻ. Fixtures seed có nhãn [DEMO FIXTURE] và không đi vào real discovery feed.
5. API nguồn lỗi và cache tồn tại → trả cache + cập nhật lần cuối/stale label; không có cache → error/retry. Cache server không thay thế khả năng gọi callable khi điện thoại hoàn toàn offline; tài liệu lớp có thể đọc từ Firestore cache đã tải.

## D. Quiz/Poll

1. Lecturer → Tương tác → Tạo Quiz/Poll, chọn lớp, câu hỏi, 2–5 lựa chọn; quiz chọn đáp án private, poll không chọn.
2. Lưu (scheduled) → Mở hoạt động, thời lượng 1–15 phút. Student cùng lớp → Hoạt động → chọn bài đang mở.
3. Student chọn đáp án, confirm gửi một lần. Trước reveal chỉ thấy đã gửi; lecturer thấy phân bố thật theo stats stream.
4. Lecturer đóng/công bố → student thấy correct option và aggregate, có lựa chọn riêng để đối chiếu. Poll chỉ distribution.
5. Duplicate/outside/expired submission bị từ chối. Emulator demo bấm đóng thủ công vì scheduler không tự chạy tại đây.

Ghi hình trên hai thiết bị là phần còn cần môi trường Android. Backend E2E và widget test không được xem là video demo hoặc camera QA.
