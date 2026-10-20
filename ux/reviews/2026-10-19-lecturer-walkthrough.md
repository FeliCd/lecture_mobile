# Đánh giá UX mô phỏng giảng viên ít quen công nghệ

Ngày đánh giá: 19/10/2026. Đối tượng giả định: giảng viên khoảng 50 tuổi, quen công việc giảng dạy nhưng ít quen thao tác ứng dụng mới. Không suy ra khả năng đọc hay vận động từ độ tuổi; cỡ chữ lớn là một điều kiện thử riêng.

**Kết luận:** các luồng thao tác cơ bản hoạt động trong fixture, nhưng cần sửa phạm vi điểm danh hàng loạt, khả năng hiển thị QR và hành động phục hồi lỗi trước khi mời giảng viên pilot. Có bước xem trước và kiểm tra dữ liệu ở backend không đồng nghĩa người dùng hiểu đúng thao tác.

**Cập nhật sau đánh giá:** đã triển khai bản sửa UX01 đến UX07 trong mã nguồn, xem [báo cáo thực hiện](../../docs/UX_LECTURER_FIXES_IMPLEMENTATION.md). Các quan sát và ảnh bên dưới mô tả bản trước sửa; giữ để đối chiếu, không coi là trạng thái hiện tại.

## Phương pháp và phạm vi

- Walkthrough bằng widget thật của TodayPanel, DesktopSessionDialog, LiveAttendancePage, BulkAttendanceSheet và LessonNotebookPage; repository và phản hồi ghi dữ liệu được mô phỏng. Dữ liệu lớp 32 sinh viên: 10 có mặt, 22 chưa điểm danh. Tên và mã sinh viên trong fixture là dữ liệu thử.
- Khung màn hình 393 × 852 logical pixels, giao diện sáng; luồng mở phiên thử chữ 1,3 và 1,8 lần. Dùng font Be Vietnam Pro thực tế của app. Sổ tay cũng dùng khung điện thoại, không dùng ảnh desktop để kết luận bố cục mobile.
- Không có emulator hoặc điện thoại kết nối trong lượt này. Chưa kiểm thử Google OAuth thật, camera/quét QR, bàn phím hệ điều hành, TalkBack, một tay, ánh sáng lớp học, mạng hoặc notification nền thật. QR trong ảnh là URL thử, không xác nhận sinh viên có thể check-in trên production.
- Khung điều hướng của walkthrough chỉ đưa các màn hình liên quan vào router thử; chưa đánh giá toàn bộ thanh điều hướng CampusShell hoặc mọi tab của app.
- Phân biệt **quan sát** (ảnh và hành vi tái hiện được) với **suy luận UX** (nguy cơ hiểu nhầm cần kiểm chứng với người thật). Không có người tham gia nghiên cứu; không tạo lời trích dẫn, thời gian hoàn thành hoặc tỷ lệ thành công của giảng viên.

## Các nhiệm vụ đã thử

| Nhiệm vụ | Kết quả quan sát | Đánh giá UX |
|---|---|---|
| Tìm lớp đang dạy rồi mở điểm danh | Từ mục Cần xử lý mở được đúng buổi, xem lớp/phòng/thời lượng và chuyển sang LiveAttendancePage; cả hai cỡ chữ chạy được | Cỡ chữ lớn làm phần chào và cài đặt nhắc chiếm nhiều diện tích trước hành động chính |
| Hiển thị QR cho lớp | Có QR, số đã điểm danh, hạn phiên và nút phóng to | QR không nằm trọn màn hình ở chữ 1,8; cần cuộn hoặc tìm nút phóng to |
| Tìm sinh viên và điền điểm danh nhanh | MSSV SE1010 tìm ra đúng một người; tìm Nguyen không ra Nguyễn Minh Anh; mở điểm danh nhanh vẫn lấy 22 sinh viên còn chờ | Phạm vi thao tác rộng hơn kết quả đang lọc, có nguy cơ hiểu nhầm |
| Xử lý mất phản hồi khi lưu | Chỉ gọi lưu một lần; giữ xem trước/lý do, không báo thành công và khóa gửi lại | Thông báo dài, nút đóng nằm dưới màn hình sau khi lỗi, bước tiếp theo chưa đủ thuận tiện |
| Chốt phiên và ghi chú sau buổi | Trước khi ghi có xác nhận rằng 22 người còn chờ sẽ thành vắng; ghi chú ở Sau buổi lưu được đúng trường next trên máy | Cảnh báo chốt vắng rõ; sổ tay có tự lưu nhưng vẫn nhiều tiêu đề và thuật ngữ |

Năm test tự động trong [walkthrough](../../test/ux_lecturer_walkthrough_test.dart) chạy qua. Đây là năm test kỹ thuật với hành động được chỉ định sẵn, không phải bằng chứng năm người dùng tự hoàn thành nhiệm vụ. Các ảnh nằm trong artifacts và có thể được tạo lại bằng lệnh ở cuối báo cáo.

## Phát hiện cần ưu tiên

### UX01 Phạm vi điểm danh nhanh khác danh sách đang xem

**Mức cao. Quan sát:** tìm MSSV SE1010 làm danh sách còn 1/32 sinh viên, nhưng nút Điểm danh nhanh mở cả 22 sinh viên còn chờ. Bảng có ghi rõ số 22 và bước xác nhận, tuy nhiên nút trước đó không nói phạm vi toàn nhóm. Hình [kết quả lọc](../../artifacts/ux-lecturer-walkthrough/05-search.png), [bảng điền nhanh](../../artifacts/ux-lecturer-walkthrough/06-bulk-draft.png), [xem trước](../../artifacts/ux-lecturer-walkthrough/07-bulk-preview.png).

**Suy luận:** người dùng định sửa một sinh viên có thể mở nhầm luồng hàng loạt. Đặc biệt, các sinh viên còn chờ đang được đề xuất Có mặt ngay cả khi chưa xem hết danh sách.

**Đề xuất:** khi tìm một sinh viên, ưu tiên nút Sửa điểm danh cho đúng người. Nếu giữ thao tác toàn nhóm, ghi rõ Điền cho 22 sinh viên chưa điểm danh và nêu độc lập với bộ lọc. Bước xem trước cần tách kết quả đã có với số được thêm, làm nổi ngoại lệ Vắng/Đi trễ và cho biết danh sách còn nội dung phải cuộn. Giữ revision check, lý do và audit.

**Kiểm tra lại:** người dùng đọc được phạm vi trước khi mở bảng; một nhiệm vụ sửa một người không dẫn đến gửi cả nhóm ngoài ý muốn. Người dùng giải thích được xác nhận sẽ ảnh hưởng bao nhiêu người trước khi bấm.

### UX02 QR bị đẩy khỏi vùng nhìn thấy khi tăng chữ

**Mức cao đối với nhiệm vụ đưa QR cho lớp. Quan sát:** ở chữ 1,8, phần tiêu đề lặp, thống kê nhiều trạng thái và thanh chế độ chiếm phần lớn màn hình. QR chỉ hiện một phần; nút kết thúc vẫn cố định phía dưới. Hình [QR chữ lớn](../../artifacts/ux-lecturer-walkthrough/03-qr-1.8.png).

**Suy luận:** giảng viên có thể đưa màn hình cho sinh viên khi mã còn bị che, hoặc không biết phải cuộn để phóng to. Chưa thử quét camera nên không kết luận tỷ lệ quét thất bại.

**Đề xuất:** ở chế độ QR, ưu tiên mã hiển thị trọn, một dòng lớp/phòng và tiến độ ngắn. Đưa số liệu phụ vào mục mở rộng. Đặt nút Toàn màn hình cạnh tiêu đề QR, có thể tìm thấy ngay, giữ đường trở lại rõ ràng. Không thu nhỏ chữ để làm đẹp ảnh.

**Kiểm tra lại:** QR nguyên vẹn hoặc hành động Toàn màn hình luôn xuất hiện ngay ở khung 393 × 852 với chữ 1,8; mã không bị footer hoặc snackbar che.

### UX03 Phục hồi lỗi lưu có hướng dẫn nhưng thiếu hành động trực tiếp

**Mức cao. Quan sát:** khi mô phỏng timeout, bảng giữ dữ liệu và khóa gửi lại đúng yêu cầu. Tuy nhiên hai đoạn chữ đỏ giải thích gần trùng ý làm bảng cao hơn; ở vị trí ảnh chụp chỉ thấy nút xác nhận vô hiệu hóa, các nút đóng phải cuộn xuống mới tới. Hình [lỗi lưu](../../artifacts/ux-lecturer-walkthrough/08-save-uncertain.png).

**Suy luận:** người ít quen công nghệ có thể nghĩ app bị kẹt hoặc không rõ đã lưu chưa. Đây là vấn đề về việc tìm bước tiếp theo; không quan sát thấy backend ghi trùng trong lượt mô phỏng.

**Đề xuất:** rút thông báo thành Chưa xác nhận được kết quả lưu. Kiểm tra danh sách trước khi thao tác tiếp. Giữ nút Đóng và kiểm tra danh sách trong vùng hành động cố định; tải dữ liệu và nêu kết quả đối chiếu. Giữ cơ chế không tự gửi lại và không báo thành công giả.

**Kiểm tra lại:** ngay khi lỗi hiện ra, có một hành động có thể bấm trong viewport để đi kiểm tra kết quả mà không phải tìm nút ở cuối bảng.

### UX04 Nội dung phụ đứng trước việc cần làm

**Mức vừa. Quan sát:** phần chào lớn, chọn học kỳ và switch nhắc nằm trước thẻ Cần xử lý. Ở chữ 1,8, phần này đẩy thẻ lớp xuống gần đáy vùng nhìn đầu tiên. Thẻ chỉ có chevron, chưa có nút Mở điểm danh trực tiếp. Hình [Hôm nay chữ lớn](../../artifacts/ux-lecturer-walkthrough/01-today-1.8.png).

**Đề xuất:** đưa lớp cần xử lý lên trước; rút chào thành một dòng; đưa cài đặt nhắc vào khu vực phụ hoặc Cài đặt. Giữ một nút chính Mở điểm danh hoặc Tiếp tục điểm danh ngay trên thẻ. Có thể giữ lựa chọn học kỳ nhưng giảm diện tích và nhớ lựa chọn hợp lệ.

**Kiểm tra lại:** khi mở Hôm nay, người dùng thấy lớp đang cần thao tác và nút hành động đầu tiên mà không cần biết chevron có thể bấm.

### UX05 Tìm tên không dấu không hỗ trợ cách nhập phổ biến

**Mức vừa. Quan sát:** Nguyen không khớp Nguyễn Minh Anh và trả 0/32. Tìm bằng MSSV vẫn đúng. Source dùng lowercase và contains, chưa chuẩn hóa dấu. Hình [tìm không dấu](../../artifacts/ux-lecturer-walkthrough/04b-search-without-accents.png).

**Đề xuất:** hỗ trợ tên có hoặc không dấu, chữ hoa/thường và khoảng trắng thừa; giữ tìm theo MSSV. Khi không tìm được, ghi rõ Không tìm thấy và cung cấp Xóa tìm kiếm, tránh khiến giảng viên tưởng sinh viên không có trong lớp.

**Kiểm tra lại:** Nguyen, nguyễn và MSSV đều tìm đúng người; kết quả không phụ thuộc bật bàn phím tiếng Việt.

### UX06 Thuật ngữ và mốc thời gian đòi hỏi người dùng tự diễn giải

**Mức vừa. Quan sát:** có Slot, FA26, máy chủ UTC+7, ngày dạng 2026-10-19, Mở phiên, Chốt và đồng hồ chỉ ghi Còn 9:59. Hình [mở phiên](../../artifacts/ux-lecturer-walkthrough/02-open-session-1.3.png), [phiên đang mở](../../artifacts/ux-lecturer-walkthrough/03-qr-1.3.png).

**Suy luận:** một số thuật ngữ có thể đã quen với giảng viên FPT, cần hỏi trước khi thay. Đồng hồ cần phân biệt thời gian sinh viên được quét với giờ kết thúc buổi học. Dòng Chưa xác nhận cập nhật FAP có thể tạo băn khoăn về nghĩa vụ điểm danh chính thức.

**Đề xuất:** dùng Điểm danh trong 10 phút, Sinh viên còn 09:59 để quét, Kết thúc điểm danh; trình bày ngày dd/MM/yyyy. Giữ mã môn/lớp cần thiết, đưa UTC+7 và giải thích kỹ thuật vào trợ giúp. Nêu rõ trạng thái trong app và quy trình cập nhật FAP nếu có tích hợp được xác nhận.

### UX07 Sổ tay vẫn có thể gọn hơn cho một ghi chú nhanh

**Mức vừa đến thấp. Quan sát:** chuyển Trước buổi/Sau buổi rõ và ghi chú next được lưu đúng. Nhưng phần đầu có thẻ thông tin, dòng lưu, tab, tiêu đề lớn và đoạn mô tả trước ô nhập; bộ đếm 0/10000 và nhãn Việc nối tiếp / ghi chú lần sau còn dài. Hình [ghi chú sau buổi](../../artifacts/ux-lecturer-walkthrough/11-notebook-after-lesson.png).

**Đề xuất:** giữ lớp/ngày và Đã lưu trên máy ngắn gọn; ưu tiên ô Ghi nhớ buổi sau, giảm mô tả lặp, chỉ hiện giới hạn ký tự khi gần đầy. Với ghi chú cá nhân, giải thích dùng thiết bị khác chưa thấy dữ liệu bằng ngôn ngữ thông thường.

## Những điểm đang làm tốt

- Hộp mở điểm danh có lớp, phòng, ngày và thời lượng trước khi tạo phiên.
- Tìm bằng MSSV trả đúng tên và trạng thái; tên/MSSV vẫn được giữ cùng nhau trên màn hình.
- Preview tách khỏi thao tác ghi; có tổng số theo trạng thái và nút Chỉnh lại.
- Trước khi chốt, thông báo nêu rõ số người còn chờ sẽ chuyển sang vắng, chưa ghi dữ liệu khi chỉ mở xác nhận. Hình [xác nhận kết thúc](../../artifacts/ux-lecturer-walkthrough/09-close-confirmation.png).
- Lỗi ghi không xóa lý do, không tự gửi lặp, không báo thành công giả. Sổ tay nêu rõ lưu trên máy.

## Thứ tự sửa đề xuất

1. Làm rõ phạm vi thao tác hàng loạt và lối sửa một sinh viên khi đang tìm kiếm.
2. Làm hành động phục hồi lỗi luôn nhìn thấy; rút thông báo lỗi.
3. Ưu tiên QR trọn màn hình ở chữ lớn; rút thống kê và tiêu đề lặp.
4. Đưa lớp cần xử lý lên đầu, có nút chính; hỗ trợ tìm tên không dấu.
5. Rà lại thuật ngữ, ngày giờ và sổ tay; thử lại với người dùng thật trước khi đổi thuật ngữ quen thuộc của trường.

Chưa sửa mã ứng dụng trong lượt đánh giá này. Chỉ thêm test walkthrough, ảnh bằng chứng và báo cáo. Không mở rộng chatbot/GPS trong khi các vấn đề về hiểu phạm vi và phục hồi lỗi còn tồn tại.

## Buổi thử với giảng viên thật tiếp theo

Mời giảng viên tự làm mà không chỉ vị trí nút trước: mở điểm danh lớp hiện tại; tìm sinh viên theo tên không dấu; ghi nhận một người vắng; giải thích phạm vi trước khi xác nhận nhanh; xử lý thông báo chưa xác nhận lưu; ghi nhớ việc cho buổi sau. Hỏi họ hiểu đồng hồ và Chốt nghĩa là gì. Quan sát lựa chọn đầu tiên, chỗ dừng tìm và nhu cầu được giúp; chỉ đo thời gian/số lỗi/tỷ lệ hoàn thành khi thực sự thu thập từ người tham gia và có đồng thuận.

## Tái hiện

```powershell
$env:FLUTTER_PREVIEW_FONTS='C:\Users\ADMIN\Downloads\flutter_windows_3.47.3-stable\flutter\bin\cache\artifacts\material_fonts'
flutter test --no-pub test/ux_lecturer_walkthrough_test.dart --dart-define=CAPTURE_UI=true --reporter expanded
```

Log: `artifacts/ux-lecturer-walkthrough.log`. Font và các ảnh test là bằng chứng layout của lần chạy này, không phải ảnh production hoặc ghi hình người dùng thật.
