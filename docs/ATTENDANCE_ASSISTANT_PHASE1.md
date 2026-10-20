# Hỗ trợ hoàn thành điểm danh — đợt 1

Ngày: 19/10/2026. Căn cứ: bản tóm tắt phỏng vấn do chủ dự án cung cấp trong cuộc trao đổi. Đây là nguồn thuật lại, chưa có bản ghi gốc, ngày phỏng vấn hoặc kiểm chứng quy định FPT. Không coi các gợi ý kỹ thuật trong tài liệu là yêu cầu đã được xác nhận.

## Hành vi đã triển khai

- **Hôm nay → Cần xử lý**: buổi đã bắt đầu chưa có phiên, buổi đã qua giờ chưa có phiên và phiên sắp hết hạn (hai phút cuối). Bỏ qua buổi hủy, đã hoàn tất, chưa bắt đầu hoặc không liên kết được lớp. Chạm mở đúng luồng kiểm tra occurrence trên server. Không tạo phiên ngoài cửa sổ cho phép. Không lặp lại thẻ đang cần xử lý ở danh sách buổi khác.
- **Nhắc điểm danh**: người dùng bật chủ động, theo một học kỳ được chọn, riêng từng tài khoản trên thiết bị. Nhắc trước giờ 10 phút khi chưa có phiên; nhắc trước khi hết buổi/phiên 2 phút. Chỉ lập lịch hôm nay/ngày mai (bao gồm phiên qua đêm). Tôn trọng giờ yên lặng hiện hành và quyền Android. Thông báo mở đúng thông tin lớp/ngày/slot, người dùng mở buổi để lấy trạng thái mới nhất trước khi thao tác.
- Coordinator nằm trên các route nên vẫn đối chiếu khi giảng viên đang xem lớp hoặc điểm danh. Lịch/snapshot mới sẽ thay thế nhắc cũ; hoàn tất/hủy/dời/đổi phòng được phản ánh từ dữ liệu backend. Lỗi nguồn dữ liệu gỡ các nhắc buổi đã lập trong phiên ứng dụng hiện tại. Nhắc việc cá nhân vẫn được giữ; đăng xuất hủy tất cả nhắc của tài khoản.
- **Sinh viên → Điểm danh nhanh**: chỉ với phiên mở, dữ liệu tải thành công và có revision. Bảng lấy tất cả sinh viên còn chờ, mặc định đề xuất Có mặt; giảng viên chọn lại Vắng/Đi trễ/Có phép, nhập lý do, xem trước danh sách và tổng số rồi xác nhận. Không ghi dữ liệu ở bước chọn hoặc xem trước.
- API `bulkUpdatePendingAttendance`: kiểm giảng viên sở hữu lớp, roster cố định, phiên mở/chưa hết hạn và revision khớp. Từ chối toàn bộ nếu một sinh viên vừa quét QR hoặc đã được điều chỉnh. Attendance và audit từng sinh viên ghi chung một Sheets batch trong write lock. Request ID được lưu qua ID audit để nhận diện yêu cầu lặp, không ghi đè lần nữa. Không dùng vòng lặp API sửa từng người.
- Lỗi ghi giữ phần xem trước/lý do, khóa gửi lại trong bảng hiện tại và yêu cầu đóng, tải lại, đối chiếu. Không tự gửi lại khi timeout; không tô thành công trước khi server xác nhận.

## Giới hạn cần hiểu đúng

- “Đã hoàn tất” hiện dựa vào trạng thái phiên backend, bao gồm phiên được tự động chốt khi hết hạn. Chưa có trường xác nhận giảng viên đã rà soát riêng.
- Tất cả trạng thái thuộc hệ thống nhóm. Chưa có xác nhận gửi điểm danh lên FAP chính thức; không tuyên bố tránh được chế tài của trường.
- Đây là nhắc Android cục bộ, không phải FCM/server worker. Khi app tắt, thông báo dùng lịch gần nhất đã tải; không kiểm tra server tại thời điểm phát. Android có thể trì hoãn. Thay đổi trên thiết bị khác không thể gỡ nhắc trên máy offline; chưa có chống trùng giữa nhiều thiết bị. Cần mở app để cập nhật các ngày tiếp theo. Không có chatbot hoặc báo cáo nhắc cuối ngày trong đợt này.
- Khi mở phiên, lịch nhắc cuối buổi chuyển sang hạn hiệu lực của phiên. Nhắc quá thời điểm hiện tại được bỏ qua; không bắn bù hàng loạt.
- Phiên legacy chưa chụp roster phải sửa từng sinh viên. API mới chỉ điền trạng thái còn chờ; sửa kết quả có sẵn tiếp tục dùng luồng sửa cá nhân có lý do.
- Chưa triển khai QR luân phiên tự động, GPS/Wi-Fi, ghi chú riêng theo sinh viên, đồng bộ sổ tay, thay ngưỡng cảnh báo vắng hoặc tích hợp chat.

## Cập nhật backend

Mobile mới cần cập nhật `backend/apps_script/Lab2Free.gs` và `backend/apps_script/AttendanceSafety.gs` cùng nhau, sau đó cập nhật phiên bản deployment **trên URL đang dùng**. Giữ các file `.gs` còn lại, script properties và manifest hiện hành. Dùng schema AttendanceAudit hiện có; không tạo bảng nghiệp vụ mới, không xóa dữ liệu cũ. Health thêm capability `bulkPendingAttendance`.

Nếu chỉ cập nhật mobile, backend cũ sẽ báo cần cập nhật khi bấm lưu nhanh; không chuyển sang gửi nhiều lệnh sửa riêng để giả lập batch.

Rollback: quay lại phiên bản mobile/backend trước. Không xóa các audit hoặc attendance đã được ghi hợp lệ bởi bản mới.

## Kiểm tra và nghiệm thu

Kết quả kiểm tra tự động được ghi ở cuối tài liệu sau khi hoàn tất. Cần nghiệm thu thêm bằng tài khoản thật: hai thiết bị cùng cập nhật, mạng mất sau khi gửi, Android nền/tiết kiệm pin/reboot, mở từ notification, dời/hủy lịch và đổi tài khoản. Mock test hoặc build thành công không thay thế các bước này.

Kết quả ngày 19/10/2026:

- `flutter analyze --no-pub`: không có vấn đề.
- `flutter test --no-pub --reporter expanded`: 164/164 qua. Bảy kiểm tra mới gồm trạng thái cần xử lý, thời điểm/giờ yên lặng/qua đêm, đối chiếu nhắc với nhắc việc và đăng xuất, bước xem trước/lý do/thất bại ghi và layout chữ lớn có bàn phím ở 360×800, 844×390.
- `node --test backend/test/*.cjs web_checkin/test/*.cjs`: 72/72 qua. Bốn kiểm tra mới cho batch/audit/idempotency, quét QR đồng thời, kiểm quyền và roster/đầu vào, đóng/reset/hết hạn. Sửa một fixture Desktop trước đây dùng ngày cố định khác ngày lịch tạo trong test; dùng cùng ngày nguồn thay vì nới validation.
- `flutter build apk --debug --no-pub --dart-define-from-file=config/lab2.free.json`: thành công. Có cảnh báo KGP từ plugin hiện hành; không chặn build.
- `git diff --check`: qua.

Log tại `artifacts/attendance-phase1-{analyze,all-tests,backend,build}.log` (không commit). Chưa cập nhật deployment cloud và chưa nghiệm thu thông báo nền/đăng nhập thật trong đợt này.
