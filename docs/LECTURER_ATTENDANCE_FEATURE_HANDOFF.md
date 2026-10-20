# Đặc tả tính năng và luồng — Hỗ trợ giảng viên điểm danh

Ngày soạn: 19/10/2026  
Người thực hiện: Thành viên được giao module hỗ trợ điểm danh  
Nguồn: Bản tóm tắt phỏng vấn giảng viên do nhóm cung cấp.

## 1. Mục tiêu và cách đọc

Giúp giảng viên hoàn tất điểm danh với ít thao tác, tránh bỏ quên và nhớ được các trường hợp sinh viên cần theo dõi.

Tài liệu mô tả hành vi sản phẩm để thành viên trong nhóm thiết kế và triển khai; chưa khẳng định các chức năng đã tồn tại trong ứng dụng. Không phụ thuộc cấu trúc code hiện tại.

Phân biệt nguồn yêu cầu:

- **Nhu cầu từ phỏng vấn:** hạn chế gian lận; thống kê nghỉ nhiều/nghỉ liên tục; ghi chú từng sinh viên; nhắc điểm danh qua kênh dễ chú ý; xác nhận hàng loạt khi lớp đi đủ.
- **Đề xuất triển khai trong bản tóm tắt:** FCM, Zalo/Telegram, QR đổi mỗi 5–10 giây, GPS/Wi-Fi, bán kính 30 m, mốc nhắc 10–15 phút và cách tổ chức API. Đây là phương án tham khảo, chưa phải quyết định kỹ thuật hoặc quy định nhà trường.
- **Quyết định thiết kế đề xuất trong tài liệu này:** mặc định Có mặt chỉ áp dụng cho bản nháp điểm danh nhanh; cần xác nhận trước khi ghi chính thức; phân biệt rõ điểm danh chưa làm, đang làm và đã hoàn tất.

Thông tin bị chế tài khi quên điểm danh là phản ánh trong phỏng vấn, chưa được nhóm xác minh bằng quy định chính thức.

## 2. Phạm vi giao việc

Thành viên phụ trách UI, trạng thái và luồng của ba nhóm chức năng đầu tiên. API, thông báo nền và kiểm soát QR phối hợp với người phụ trách backend; không yêu cầu một người tự xây mọi tích hợp.

| Mã | Nhóm tính năng | Ưu tiên | Kết quả cần bàn giao |
|---|---|---|---|
| F01 | Điểm danh nhanh theo ngoại lệ | P0 — làm trước | Mở đúng buổi, mặc định bản nháp Có mặt, đánh dấu ngoại lệ, xem lại và lưu |
| F02 | Nhắc tránh quên điểm danh | P0 — làm trước | Nhìn thấy buổi chưa hoàn tất, mở đúng buổi từ lời nhắc, dừng nhắc khi hoàn tất |
| F03 | Theo dõi và ghi chú sinh viên | P1 — làm sau P0 | Xem lịch sử vắng, cảnh báo có giải thích, tạo/xem ghi chú và lời nhắc kiểm tra bài |
| F04 | QR có kiểm soát | P1 — phối hợp backend | Mở phiên, quét QR, đối soát, xử lý ngoại lệ và chốt |
| F05 | Trợ lý qua chat | P2 — mở rộng | Nhắc lịch/điểm danh, hỏi số liệu, dẫn vào app; xác nhận hàng loạt có bước xem lại |

**Mốc bàn giao đầu tiên:** F01 + F02 trong app. Chưa cần tích hợp đồng thời nhiều nền tảng chat hoặc định vị phòng học.

## 3. Vai trò và dữ liệu chung

- **Giảng viên:** chỉ xem và cập nhật các lớp/buổi được phân công.
- **Sinh viên:** tự check-in khi dùng QR; không có quyền xác nhận thay cả lớp.
- **Hệ thống:** cung cấp lịch, danh sách sinh viên, trạng thái lưu và quy định tính cảnh báo.

Mỗi buổi phải được nhận diện bằng lớp + ngày + slot/mã buổi. Không chỉ dùng mã lớp vì một lớp có thể học nhiều buổi.

Trạng thái buổi:

| Trạng thái | Ý nghĩa |
|---|---|
| Chưa điểm danh | Chưa có kết quả chính thức cho buổi đó |
| Bản nháp | Giảng viên đang chọn trạng thái; chưa hoàn tất |
| Đang gửi | Yêu cầu lưu đang xử lý |
| Đã hoàn tất | Backend xác nhận đã lưu đủ kết quả theo danh sách hợp lệ |
| Lưu chưa thành công | Bản nháp còn giữ, cần thử lại hoặc đối soát |

Trạng thái sinh viên gồm Có mặt, Vắng, Đi trễ, Vắng có phép nếu nghiệp vụ hỗ trợ. Ghi chú “Có phép” không tự chuyển trạng thái điểm danh; giảng viên phải chọn trạng thái tương ứng.

## 4. F01 — Điểm danh nhanh theo ngoại lệ

### Vấn đề cần giải quyết

Lớp có 40 sinh viên, chỉ 2 người vắng nhưng mặc định Vắng khiến giảng viên phải xác nhận 38 người Có mặt. Giảng viên cần thao tác theo số ngoại lệ.

### Luồng chính

1. Giảng viên chọn một buổi và bấm **Điểm danh nhanh**.
2. Màn hình hiển thị rõ môn, mã lớp, ngày, slot, phòng và sĩ số.
3. Nếu buổi chưa có kết quả, tạo **bản nháp** với toàn bộ sinh viên Có mặt; hiện dòng “Đang chọn Có mặt cho toàn bộ lớp — chưa lưu”. Việc mở màn hình không tự ghi kết quả.
4. Giảng viên tìm theo tên/MSSV và đánh dấu những người Vắng; có thể đổi sang Đi trễ hoặc Vắng có phép.
5. Phía trên luôn có tổng số theo trạng thái và bộ lọc **Tất cả / Ngoại lệ**. Không tự đổi thứ tự danh sách ngay sau mỗi lần chạm để tránh mất vị trí.
6. Giảng viên bấm **Xem lại**.
7. Hiện tổng số, danh sách ngoại lệ và đúng buổi đang thao tác. Ví dụ: “40 sinh viên: 38 Có mặt, 2 Vắng”.
8. Giảng viên bấm **Xác nhận và lưu**. Trong lúc gửi, ngăn gửi lặp.
9. Khi backend xác nhận thành công, hiển thị **Đã hoàn tất** và thời gian lưu. Cập nhật danh sách buổi chưa điểm danh.

### Luồng lớp đi đủ

Mở buổi → Điểm danh nhanh → Xem lại “40/40 Có mặt” → Xác nhận và lưu. Không cần bấm lần lượt từng người.

### Luồng bấm nhầm, bị gián đoạn và đến muộn

- Bấm nhầm: cho đổi lại ngay; phản hồi rõ dòng vừa thay đổi và có Hoàn tác cho thao tác bản nháp.
- Ngẩng lên gọi tên hoặc tạm chuyển app: giữ bộ lọc, vị trí cuộn và bản nháp theo đúng buổi.
- Rời màn khi chưa lưu: cho chọn tiếp tục chỉnh, giữ bản nháp hoặc bỏ bản nháp; không báo đã hoàn tất.
- Sinh viên đến muộn sau khi buổi đã lưu: mở kết quả hiện có → tìm sinh viên → chỉnh trạng thái → nhập lý do nếu quy định yêu cầu → lưu điều chỉnh. Không khởi tạo lại toàn bộ lớp thành Có mặt.

### Quy tắc bắt buộc

- Nếu đã có kết quả từ QR hoặc nhập thủ công, hiển thị kết quả hiện có; không âm thầm ghi đè bằng mặc định Có mặt.
- Chỉ áp dụng hàng loạt cho danh sách sinh viên hợp lệ mà giảng viên đang xem. Backend phải kiểm tra lại quyền, buổi, danh sách và thời hạn được phép sửa.
- Khi danh sách thay đổi hoặc người khác cập nhật trong lúc đang sửa, yêu cầu tải/đối soát thay đổi trước khi xác nhận lại.
- Mất mạng hoặc lỗi lưu: giữ lựa chọn, báo chưa hoàn tất, cho thử lại. Nếu kết quả yêu cầu trước chưa rõ, kiểm tra lại máy chủ trước khi gửi tiếp; backend cần chống xử lý trùng.
- Không tự đánh dấu một buổi đã điểm danh chỉ vì đã mở màn hình hoặc đã tạo bản nháp.

### Tiêu chí nghiệm thu

- [ ] Lớp 40 người, 2 người vắng: chỉ cần sửa 2 sinh viên rồi xem lại/xác nhận; không cần chọn 38 người Có mặt.
- [ ] Mở màn hình rồi thoát không phát sinh kết quả chính thức.
- [ ] Tìm kiếm/lọc không làm mất lựa chọn ở những dòng đang bị ẩn.
- [ ] Lỗi lưu không làm mất bản nháp hoặc hiển thị thành công giả.
- [ ] Mở lại buổi đã hoàn tất giữ nguyên kết quả cũ.
- [ ] Đổi một sinh viên không làm thay đổi trạng thái của những người khác.
- [ ] Nút và dòng trạng thái dễ chạm khi cầm một tay; trạng thái có chữ, không chỉ phân biệt bằng màu.

## 5. F02 — Nhắc tránh quên điểm danh

### Luồng chính

1. Hệ thống lấy lịch dạy và đối chiếu kết quả từng buổi.
2. Trước giờ học, gửi lời nhắc lịch có lớp, phòng và giờ. Đây là nhắc lịch, chưa kết luận giảng viên quên điểm danh.
3. Khi gần kết thúc buổi, nếu chưa hoàn tất điểm danh, gửi lời nhắc có hành động **Mở buổi điểm danh**.
4. Giảng viên chạm lời nhắc → xác thực nếu cần → mở đúng lớp/ngày/slot.
5. Giảng viên hoàn tất qua F01 hoặc F04. Hệ thống cập nhật trạng thái và hủy các lời nhắc chưa gửi cho buổi đó.
6. Cuối ngày, nếu còn buổi chưa hoàn tất, hiển thị danh sách để giảng viên xử lý theo quyền và thời hạn cho phép.

### Nội dung mẫu

“Lớp SExxxx · Slot 2 · Phòng A201 sắp kết thúc. Điểm danh chưa hoàn tất.”

### Quy tắc và ngoại lệ

- Mốc nhắc phải cấu hình được; các con số 10–15 phút trong bản tóm tắt chưa được chốt. Phải phân biệt rõ trước giờ bắt đầu và trước giờ kết thúc.
- Buổi hủy/nghỉ hoặc đổi lịch phải cập nhật lời nhắc; không tiếp tục gửi theo lịch cũ.
- Không nhắc lặp cùng một sự kiện trên cùng kênh; kiểm tra lại trạng thái trước lúc gửi khi có thể.
- Nếu lời nhắc đã gửi nhưng buổi vừa được hoàn tất, chạm vào sẽ mở kết quả hiện tại, không yêu cầu điểm danh lại.
- Nếu tắt quyền thông báo, vẫn có mục **Buổi chưa hoàn tất** trong app và hướng dẫn bật lại quyền. Không cam kết thông báo luôn phát âm thanh hoặc vượt chế độ im lặng của thiết bị.
- Nhắc sau hạn chỉ dẫn đến luồng xử lý được nhà trường cho phép; không tự mở quyền ghi lùi giờ.

### Tiêu chí nghiệm thu

- [ ] Chạm lời nhắc mở đúng buổi, kể cả khi có hai ca cùng một lớp trong ngày.
- [ ] Buổi đã hoàn tất không tiếp tục phát sinh lời nhắc mới.
- [ ] Đổi/hủy lịch không để lại lời nhắc sai.
- [ ] Trạng thái chưa hoàn tất vẫn nhìn thấy trong app khi quyền thông báo bị tắt.

## 6. F03 — Theo dõi và ghi chú sinh viên

### Luồng xem cảnh báo

Mở lớp → xem danh sách sinh viên → lọc Vắng nhiều / Nghỉ liên tục / Có ghi chú → chọn sinh viên → xem lịch sử các buổi và cách tính cảnh báo.

Mỗi cảnh báo cần có bằng chứng: số buổi vắng, mẫu số sử dụng, các ngày liên quan, ngưỡng đang áp dụng và thời điểm cập nhật. Chỉ dùng kết quả đã hoàn tất; không tính bản nháp hoặc buổi chưa diễn ra thành Vắng.

**Chưa chốt công thức:** bản tóm tắt đồng thời đề cập “vượt 20%” và “≥20%”, đồng thời chưa làm rõ mẫu số là buổi đã học hay tổng buổi dự kiến. Người thực hiện không tự chọn một công thức. Nhóm phải xác nhận quy định và cấu hình trước khi gắn cảnh báo chính thức.

Nhãn **Nguy cơ vượt ngưỡng vắng** là thông tin hỗ trợ. Không tự kết luận **Cấm thi** nếu chưa có quy định và thẩm quyền xác nhận.

### Luồng tạo ghi chú và nhắc kiểm tra bài

1. Giảng viên mở một sinh viên trong lớp.
2. Bấm **Thêm ghi chú**, nhập nội dung; có thể chọn nhãn như “Cần theo dõi đi trễ” hoặc “Hỏi bài buổi sau”.
3. Nếu chọn nhắc buổi sau, liên kết với buổi kế tiếp có trong lịch hoặc yêu cầu chọn buổi; không đoán khi lịch chưa có.
4. Lưu và hiển thị trạng thái Đã lưu hoặc Chưa đồng bộ.
5. Khi mở buổi được nhắc, hiển thị sinh viên và nội dung cần lưu ý; giảng viên có thể đánh dấu Đã xử lý.

Ghi chú phải gắn đúng giảng viên + lớp + sinh viên. Ghi chú chỉ dành cho giảng viên có quyền, không hiển thị công khai cho cả lớp. Ghi chú nhận xét không tự trở thành trạng thái điểm danh hoặc kết luận kỷ luật.

### Tiêu chí nghiệm thu

- [ ] Mỗi cảnh báo giải thích được vì sao sinh viên nằm trong danh sách.
- [ ] Phân biệt thiếu dữ liệu với không có buổi vắng; không suy diễn thiếu dữ liệu thành Vắng.
- [ ] Ghi chú đúng sinh viên/lớp, lưu và mở lại được; có sửa/xóa theo quyền.
- [ ] Ghi chú “Hỏi bài buổi sau” xuất hiện ở buổi đã liên kết và đánh dấu xử lý được.
- [ ] Nếu cho ghi chú offline, hiển thị rõ chưa đồng bộ và giữ dữ liệu khi gửi lỗi.

## 7. F04 — QR có kiểm soát

### Luồng chính

Giảng viên chọn buổi → mở phiên → hiển thị QR có hạn → sinh viên đăng nhập và quét → backend kiểm tra quyền đăng ký lớp, phiên, token và hạn dùng → ghi nhận → giảng viên xem danh sách đã nhận/còn chờ → đối soát ngoại lệ → xem lại và chốt.

### Quy tắc

- Token được backend tạo hoặc ký và kiểm tra; không nhúng khóa bí mật có thể đọc được vào QR hoặc app sinh viên.
- Backend từ chối QR hết hạn, sai buổi, tài khoản không thuộc lớp; một sinh viên không phát sinh nhiều kết quả trùng cho cùng buổi.
- QR thay đổi định kỳ giúp hạn chế tái sử dụng nhưng không tự chứng minh sinh viên đang ở trong phòng.
- GPS trong nhà và IP Wi-Fi không đủ để khẳng định chính xác phòng học. Chỉ bổ sung sau khi khảo sát hạ tầng, độ chính xác, quyền riêng tư và cách xử lý người hợp lệ bị từ chối.
- Sinh viên không quét được phải có đường xử lý thủ công của giảng viên.
- Danh sách Còn chờ chưa đồng nghĩa Vắng trước khi kết thúc và chốt theo quy định.
- Phân biệt F01: không mặc định chính thức mọi người Có mặt khi chỉ mới mở phiên QR.

### Tiêu chí nghiệm thu

- [ ] Quét hợp lệ cập nhật đúng sinh viên và buổi.
- [ ] QR hết hạn/sai lớp bị từ chối với thông báo cụ thể.
- [ ] Quét lặp không tạo bản ghi trùng.
- [ ] Giảng viên đối soát ngoại lệ trước khi xác nhận kết quả cuối cùng.

## 8. F05 — Trợ lý qua chat, phạm vi mở rộng

Tách ba ý định để tránh trợ lý cập nhật dữ liệu ngoài ý muốn:

| Ý định | Luồng |
|---|---|
| Nhắc lịch/điểm danh | Tin nhắc có lớp, giờ, phòng → nút mở đúng buổi trong app |
| Hỏi số liệu | Xác định lớp/buổi → kiểm tra quyền → trả số liệu kèm thời điểm cập nhật |
| “Lớp đi đủ” | Xác định đúng buổi → hiển thị sĩ số và kết quả hiện có → giảng viên xem lại/xác nhận → backend lưu → báo kết quả |

Trong bản đầu, nút **Xác nhận đủ lớp** trên chat dẫn đến bước xem lại trong app. Chưa thực hiện cập nhật hàng loạt chỉ dựa vào một câu chat.

Chọn một kênh để thử nghiệm trước; phải có liên kết an toàn giữa tài khoản chat và giảng viên. Không đưa danh sách hoặc thông tin sinh viên vào nhóm chat chưa được cấp quyền.

## 9. Gợi ý hợp đồng dữ liệu với backend

Tên endpoint và cấu trúc cụ thể do nhóm thống nhất. Các thao tác tối thiểu cần có:

| Thao tác | Dữ liệu vào chính | Kết quả cần trả |
|---|---|---|
| Lấy ngữ cảnh buổi | Mã buổi | Lớp/ngày/slot/phòng, roster hợp lệ, kết quả hiện có, phiên bản dữ liệu, quyền sửa |
| Lưu điểm danh nhanh | Mã buổi, phiên bản roster/kết quả, mã yêu cầu chống trùng, trạng thái mặc định và ngoại lệ | Đã lưu hoặc lý do từ chối/xung đột; tổng số chính thức và thời gian lưu |
| Lấy buổi chưa hoàn tất | Khoảng ngày | Các buổi được phân công và trạng thái hoàn tất |
| Lấy theo dõi sinh viên | Lớp, sinh viên | Lịch sử, số liệu, quy định/ngưỡng và cảnh báo có căn cứ |
| Lưu ghi chú | Lớp, sinh viên, nội dung, buổi cần nhắc nếu có | Ghi chú đã lưu, phiên bản và thời gian cập nhật |

Backend không tin `lecturerId` hoặc sĩ số do client gửi để quyết định quyền. Nếu dùng payload “mặc định Có mặt + danh sách ngoại lệ”, backend phải áp dụng trên đúng roster đã được xác nhận, không lấy danh sách mới và tự thêm người vào kết quả.

## 10. Thứ tự làm và checklist bàn giao

1. Thống nhất định danh buổi, các trạng thái, quyền sửa và dữ liệu mock với backend.
2. Làm trọn F01: chọn buổi → bản nháp → ngoại lệ → xem lại → lưu → khôi phục khi lỗi.
3. Làm F02 trong app, sau đó kết nối cơ chế gửi lời nhắc.
4. Làm F03 sau khi chốt cách tính cảnh báo.
5. Phối hợp F04; thử nghiệm F05 sau khi luồng trong app ổn định.

Thành viên cần bàn giao:

- [ ] Màn hình/luồng có thể chạy thử bằng dữ liệu mẫu, có mô tả cách chạy.
- [ ] Trạng thái tải, trống, đang gửi, thành công, lỗi và xung đột dữ liệu.
- [ ] Kiểm tra lớp đi đủ, 1–2 người vắng, đến muộn, bấm nhầm, gián đoạn và mất mạng.
- [ ] Kiểm tra buổi đã có kết quả, thao tác gửi lặp và sửa đồng thời.
- [ ] Kiểm tra một tay, danh sách dài, chữ lớn và bàn phím tìm kiếm.
- [ ] Demo F01 + F02 và liệt kê rõ phần thật/giả lập/phụ thuộc backend.

## 11. Những câu hỏi nhóm cần chốt

| Câu hỏi | Ảnh hưởng |
|---|---|
| Điểm danh được mở/chốt/sửa trong khoảng thời gian nào? | F01, F02, F04 |
| Đi trễ và Vắng có phép được tính thế nào? | Trạng thái và tỷ lệ vắng |
| Ngưỡng là >20% hay ≥20%; mẫu số là gì? | Cảnh báo F03 |
| Nghỉ liên tục bao nhiêu buổi thì cảnh báo? Buổi hủy có ngắt chuỗi không? | F03 |
| Nhắc trước giờ học và trước cuối buổi bao lâu? | F02 |
| Ai được xem ghi chú; có chia sẻ giữa giảng viên không? | F03 và đồng bộ dữ liệu |
| Có bắt buộc kênh chat cụ thể hoặc điều kiện vị trí/mạng không? | Phạm vi tích hợp F04/F05 |

Trong lúc chờ xác nhận, có thể làm UI và dữ liệu mock có ghi rõ giả định. Không bật quy tắc đánh giá chính thức hoặc thông báo đến tài khoản thật bằng giá trị tự suy đoán.
