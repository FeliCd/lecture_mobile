# Điểm danh nhanh trong ngày — 20/10/2026

Thay thế quy tắc thời gian/trạng thái/nhắc trong các báo cáo điểm danh nhanh trước đây theo yêu cầu mới.

## Luồng sử dụng

- Buổi thuộc ngày hiện tại theo giờ Việt Nam, chưa được giảng viên xác nhận, có thể điểm danh nhanh trong ngày, kể cả đã qua giờ học. Cho phép chọn trước giờ bắt đầu trong cùng ngày; không cho ghi trước ngày hoặc ghi lùi sang ngày trước.
- Bản nháp mặc định Có mặt cho người chưa có kết quả. Switch bật = Có mặt, tắt = Vắng. Chỉ hai lựa chọn này xuất hiện trên màn nhanh và bảng điền nhóm còn chờ.
- Giảng viên chỉnh switch → Xem lại và lưu → Xác nhận và lưu. Mở màn hoặc đổi switch không ghi dữ liệu chính thức.
- Hạn lưu là trước 00:00 ngày tiếp theo, theo giờ server tại Việt Nam. 23:59:59 được phép; 00:00 bị từ chối, kể cả đã mở bản nháp từ trước. Buổi qua đêm vẫn theo ngày gốc và cùng hạn này.
- Bản nháp, xung đột revision/roster, write lock, atomic batch, audit và chống gửi trùng tiếp tục áp dụng.
- Kết quả QR/thủ công hiện có được dùng làm baseline. Trong luồng nhanh, Đi trễ cũ được trình bày/xác nhận thành Có mặt; Có phép cũ thành Vắng. Chỉ chuyển dữ liệu khi giảng viên xác nhận lưu. Các luồng QR/điều chỉnh riêng vẫn giữ nghiệp vụ cũ.
- Buổi đã xác nhận vẫn chỉnh sửa được trong cùng ngày trước 00:00. Mở lại giữ nguyên kết quả đã lưu, không đặt lại cả lớp thành Có mặt. Đổi switch → Xem lại và lưu thay đổi → Xác nhận và lưu. Nút lưu chỉ bật khi có thay đổi.

## Phân biệt đóng QR và hoàn tất điểm danh

Thêm bảng `Lab2AttendanceCompletion` với cột `sessionId,status,confirmedAt,confirmedBy`:

- QR hết hạn tự đóng: `PENDING`, chưa coi giảng viên đã hoàn tất. Snapshot lịch vẫn thể hiện chưa hoàn tất và còn nhắc.
- Chốt thủ công hoặc lưu nhanh thành công: `CONFIRMED`.
- Những dòng Vắng do cơ chế tự đóng tạo ra không trở thành mặc định Vắng khi mở bản nháp nhanh: người đó mặc định Có mặt, giảng viên xem lại và lưu.
- Phiên CLOSED cũ không có marker được giữ là đã hoàn tất để tránh tự mở lại kết quả lịch sử. Không suy đoán phiên cũ do ai chốt; các trường hợp lịch sử chưa rõ cần đối soát thủ công.

## Thông báo

- Nhắc lần đầu tại giữa khoảng giờ học theo lịch; 09:00–10:00 → 09:30.
- Nhắc lại lúc 21:00 cho từng buổi đã bắt đầu nhưng chưa hoàn tất. Buổi bắt đầu sau 21:00 dùng mốc giữa buổi nếu còn trong ngày gốc. Không tạo hai thông báo trùng nếu giữa buổi đúng 21:00.
- Bỏ buổi hủy/đã xác nhận; dữ liệu mới thay thế lịch nhắc cũ. Không lập nhắc sau hạn ngày gốc hoặc phát bù các mốc đã trôi qua.
- Nội dung có mã lớp/ngày/slot, nút “Điểm danh nhanh”. Payload có tài khoản và selector chính xác; chạm thông báo/nút mở route `/quick` của buổi đó, tải ngữ cảnh mới từ server trước khi thao tác.
- Mặc định bật cấu hình nhắc trên thiết bị nếu tài khoản chưa có tùy chọn; tôn trọng tùy chọn tắt có sẵn, quyền Android và giờ yên lặng. Có hướng dẫn bật quyền ở Hôm nay.
- Đây là thông báo Android cục bộ dựa trên lịch gần nhất đã tải, chưa phải push từ server/FCM. Cần mở app để tải lịch và cấp quyền. Khi app đóng hoặc offline, việc chốt/đổi lịch trên thiết bị khác chỉ gỡ nhắc cũ khi app kết nối lại. Android có thể phát trễ. Không cam kết kiểm tra server đúng thời điểm phát.

## Cập nhật backend bắt buộc

1. Cập nhật cùng bộ Apps Script, ít nhất `Lab2Free.gs`, `AttendanceSafety.gs`, `ScheduleAttendance.gs`, `Code.gs`; giữ các file còn lại và cấu hình hiện hành.
2. Owner chạy `setupLab2Free()` để tạo bảng completion mới. Không xóa các bảng/dòng lịch sử. Giữ trigger reconciliation hiện có.
3. Tạo version deployment mới trên URL đang dùng; health có capability `quickAttendanceDaily`.
4. Cài APK mới và tải lại dữ liệu. Source local hoặc APK mới không tự cập nhật deployment Apps Script.

## Kiểm chứng

- Flutter analyze: không có vấn đề.
- Toàn bộ Flutter tests sau bổ sung chỉnh sửa: 216/216 đạt.
- Backend/Student Web sau bổ sung chỉnh sửa: 86/86 đạt.
- APK debug build thành công; analyze không có vấn đề.
- Kiểm tra thêm: lưu sau giờ học, ranh giới 23:59:59/00:00, phiên QR tự đóng vẫn chưa xác nhận, mặc định Có mặt khi rà soát lại, từ chối LATE/EXCUSED trong submit nhanh, switch → review → lưu, nhắc 09:30/21:00 và selector chính xác, chống nhắc trùng tại 21:00, hủy nhắc khi hoàn tất, giữ nhắc việc và phân tách tài khoản.
- Log local: `artifacts/quick-day-{analyze,tests,backend,build}.log` (ignored).

Chưa triển khai cloud hoặc nghiệm thu thông báo nền trên điện thoại thật. Các thay đổi có sẵn của người dùng trong manifest Apps Script và tài liệu handoff được giữ nguyên.

## Bổ sung: chỉnh sửa sau khi đã xác nhận

- Backend trả `editable=true` cho buổi đã chốt trong ngày, đồng thời giữ `attendanceCompleted=true`; hai trường có ý nghĩa riêng: quyền chỉnh sửa và trạng thái hoàn tất.
- Mỗi lần điều chỉnh phải dùng revision mới nhất, đúng roster và request ID mới. Audit ghi rõ “Điều chỉnh điểm danh nhanh”, trạng thái cũ/mới và người thực hiện. Cập nhật chung một batch, giữ session và kết quả của sinh viên khác.
- Yêu cầu gửi lại chỉ được công nhận đã lưu khi có receipt đúng và kết quả chưa bị sửa tiếp. Không sử dụng retry cũ để ghi đè lần điều chỉnh sau. Sau 00:00 từ chối mọi điều chỉnh mới trong luồng nhanh.
- Mở buổi từ lịch cũng có nút Điểm danh nhanh cho buổi đã chốt trong ngày. Khi chỉnh sửa chưa lưu hoặc lưu lỗi, trạng thái hoàn tất của bản chính thức vẫn giữ nguyên; không đưa buổi đó trở lại danh sách nhắc.
- Test bổ sung: mở lại/chỉnh switch/review/lưu, không đổi sinh viên khác hoặc tạo session khác, audit điều chỉnh, lỗi lưu giữ bản cũ/bản nháp, hai thiết bị sửa đồng thời và khóa điều chỉnh từ 00:00.
- Log kiểm tra bổ sung: `artifacts/quick-edit-{tests,screen-tests,backend,analyze,build}.log`.

Cần cập nhật `AttendanceSafety.gs` và `ScheduleAttendance.gs` trong deployment bên cạnh bản mobile mới. Bộ source tổng thể vẫn cần bảng `Lab2AttendanceCompletion` được tạo bằng `setupLab2Free()` như hướng dẫn ở trên. Ảnh màn Hôm nay chỉ thể hiện Slot 1 đang được đánh dấu chưa hoàn tất, không đủ xác minh đó là phiên tự đóng hay snapshot/cloud còn cũ. Backend test xác nhận lưu nhanh thành công và lưu điều chỉnh đều giữ `classSessions.status=completed` để buổi không nằm trong danh sách chưa hoàn tất.
