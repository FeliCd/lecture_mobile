# Kế hoạch nghiên cứu và usability

**Chưa tổ chức, chưa có người tham gia hay kết quả.** Đây là protocol có thể dùng ngay để thu dữ liệu thật. Các mốc thời gian và mục tiêu đo là đề xuất của nhóm, cần điều chỉnh sau pilot.

## Trách nhiệm và đầu ra

| Việc | Người phụ trách | Trạng thái |
|---|---|---|
| Xin phép và tuyển mẫu | Chưa phân công | Chưa bắt đầu |
| Điều phối phỏng vấn/usability | Chưa phân công | Chưa bắt đầu |
| Ghi chép, ẩn danh và mã hóa | Chưa phân công | Chưa bắt đầu |
| Tổng hợp, phản biện persona | Chưa phân công | Chưa bắt đầu |

Đầu ra: ghi chú đã ẩn danh có evidence IDs, board cập nhật, bảng kết quả task, persona revision, quyết định Accept/Modify/Reject. Không điền số liệu thay người tham gia.

## Tuyển mẫu theo hành vi

Vòng đầu đề xuất 6 giảng viên FPT, nhằm tìm biến thiên và ca đối lập; không dùng để ước lượng tỷ lệ dân số hay bảo đảm bão hòa. Chia vòng 3 người → tổng hợp → 3 người; có thể tăng/đổi mẫu theo phát hiện. Một người có thể phù hợp nhiều giả thuyết P01–P03.

Câu sàng lọc: gần đây dạy bao nhiêu lớp/buổi; lần cuối chuyển phòng/lớp; cách điểm danh đang dùng; cách ghi phần cần tiếp nối; mức quen với app này; thiết bị thường dùng và tùy chọn hỗ trợ cần thiết. Không loại người ít kỹ năng chỉ để demo trơn tru. Không yêu cầu người tham gia cung cấp mật khẩu, token hoặc danh sách sinh viên thật.

Giảng viên điều phối môn/chủ dự án có thể phản biện hồ sơ; ghi đúng vai trò, không mặc nhiên tính là người dùng giảng dạy mục tiêu.

## Đồng thuận và ghi nhận

Giải thích mục đích đánh giá thiết kế; người tham gia có thể bỏ câu hỏi hoặc dừng. Xin phép riêng cho ghi âm/chụp ảnh; ghi chép là đủ nếu họ không đồng ý ghi hình. Dùng R01…; bảng liên hệ và ghi âm để ngoài Git, giới hạn người được xem, thống nhất ngày xóa trước buổi. Tài liệu nộp chỉ chứa phần đã ẩn danh và được phép sử dụng.

Mở app đã đăng nhập sẵn trong môi trường thử được kiểm soát. Không ghi lại luồng mật khẩu/OAuth cá nhân. Nếu OAuth/backend chưa sẵn sàng, ghi là blocker, hoặc dùng prototype/fixture có nhãn rõ; kết quả prototype không chứng minh hoạt động backend thật. Hiện có lỗi cấu hình OAuth được ghi nhận trong phiên làm việc, cần giải quyết trước buổi thử app live.

## Phỏng vấn 15–20 phút

1. Kể lần gần nhất thầy/cô bắt đầu một buổi dạy: đã xem những thông tin gì, ở đâu?
2. Khi hai lớp có cùng môn, thầy/cô đối chiếu để tránh chọn nhầm thế nào?
3. Lần gần nhất có ngoại lệ điểm danh, quá trình xử lý và xác nhận kết quả ra sao?
4. Khi mạng chậm hoặc báo lỗi, thầy/cô làm gì tiếp theo? Xin một ví dụ cụ thể nếu có.
5. Nội dung chưa dạy xong được ghi và tìm lại ở buổi sau thế nào?
6. Hiện dùng công cụ gì để nhớ hạn? Điều gì khiến thầy/cô tiếp tục hoặc bỏ công cụ đó?
7. Thường dùng thiết bị nào ở lớp và ở nhà? Có nhu cầu chuyển ghi chú giữa các thiết bị không?
8. Có cỡ chữ, cách chạm hoặc hỗ trợ truy cập nào cần điều chỉnh để thao tác thuận tiện không?

Không hỏi dẫn dắt như “app gọn hơn có tốt không?”. Xin diễn giải từ lần sử dụng thật; chỉ xin artefact nếu đã được phép và không chứa dữ liệu sinh viên. Tách lời tự báo cáo khỏi hành vi quan sát.

## Usability — ba nhiệm vụ

Không chỉ vị trí nút trong đề bài. Chuẩn bị dữ liệu thử đã ẩn danh: ít nhất hai lớp cùng môn và một lớp khác; một phiên đúng cửa sổ hợp lệ; đủ sinh viên để phải tìm; một ghi chú buổi trước và buổi đích. Xác nhận các thao tác chỉ ghi vào dữ liệu test. Chạy pilot với thành viên nhóm để sửa đề, không tính pilot vào kết quả giảng viên.

### T01 — Vào đúng buổi

**Đề đọc:** “Thầy/cô sắp dạy buổi [môn/lớp/slot/phòng mục tiêu]. Hãy tìm buổi đó và đi tới nơi quản lý điểm danh.”

- Start: S01 đã tải dữ liệu; giảng viên nghe xong đề và bắt đầu.
- Stop: tới đúng phiên hoặc tới bước xác nhận mở đúng buổi. Đo mạng/tạo phiên riêng, không gộp vào thời gian tìm buổi.
- Ghi: giây, số chạm, chọn nhầm, quay lại, cần trợ giúp; có nhận ra môn/lớp/slot/phòng không.
- Mục tiêu dự kiến: ≤30 giây, không chọn nhầm và không cần chỉ vị trí. Hết 120 giây dừng hoặc xin phép tiếp tục, ghi incomplete.

### T02 — Sửa và phục hồi

**Đề đọc:** “Trạng thái của sinh viên [mã test] cần đổi thành [trạng thái test] với lý do [lý do test]. Hãy xử lý và cho biết kết quả đã được xác nhận chưa.”

- Môi trường test trả lỗi ghi có kiểm soát ở lần lưu đầu. Chuẩn bị trạng thái backend đã biết; không ngắt mạng rồi đoán dữ liệu chưa ghi.
- Start: S03 đang hiển thị phiên test. Stop: người dùng xử lý/đối chiếu đúng và giải thích được trạng thái.
- Ghi: đúng người/trạng thái/lý do; nội dung sau lỗi; ý định gửi lặp; điểm cần trợ giúp.
- Mục tiêu dự kiến: ≤90 giây, không sửa nhầm, không gửi tiếp khi kết quả chưa rõ. Hết 180 giây ghi incomplete; không ép hoàn tất bằng dữ liệu thật.

### T03 — Ghi và tìm lại

**Đề đọc:** “Buổi [mục tiêu] còn phần [nội dung test] cần tiếp nối. Hãy ghi lại, rời màn rồi tìm lại ghi chú đó. Tạo một việc chuẩn bị có hạn nếu cần.”

- Start: S01/S02 đã tải. Stop: mở lại đúng ghi chú, nội dung khớp và việc được lưu nếu đã tạo.
- Hỏi sau nhiệm vụ: “Nếu mở trên điện thoại khác, thầy/cô có kỳ vọng thấy ghi chú này không? Vì sao?” Không gợi ý câu trả lời trước task.
- Ghi: giây, nhầm buổi/lớp, lưu thành công, hiểu phạm vi thiết bị, trợ giúp.
- Mục tiêu dự kiến: ≤120 giây, đúng nội dung/buổi và hiểu lưu trên máy. Hết 240 giây ghi incomplete.

Các ngưỡng trên do nhóm đề xuất, không phải chuẩn của môn hoặc số đo đã có. Ghi rõ khi task bị chặn bởi cấu hình hoặc môi trường; không quy thành lỗi người dùng.

## Mẫu ghi kết quả — chưa có dữ liệu

| Participant | Task | Thiết bị/chữ | Giây | Số chạm | Hoàn thành | Sai sót/trợ giúp | SEQ 1–7 sau task | Evidence |
|---|---|---|---|---|---|---|---|---|
| Chưa thu thập | — | — | — | — | — | — | — | — |

Mỗi hàng: ghi thời gian bắt đầu/kết thúc, điểm dừng, ghi chú thô và nguồn. Hoàn thành có trợ giúp phải tách khỏi không trợ giúp. Dấu “—” là chưa đo, không phải 0. SEQ chỉ hỏi sau task, không thay dữ liệu hành vi.

Với mẫu nhỏ, báo cáo số đếm như 4/6 và khoảng/median thời gian của các ca hoàn thành, ghi rõ N và ca bị loại. Không tuyên bố đại diện mọi giảng viên. Nếu so sánh UI cũ/mới, chuẩn bị hai bản, cân bằng thứ tự và đề tương đương; chỉ thử bản mới thì không thể khẳng định mức cải thiện trước/sau.

## Assumption & Research Backlog

| Ưu tiên | Giả định | Việc tiếp theo | Điều kiện quyết định |
|---|---|---|---|
| P0 | Môi trường thử có thể chạy an toàn | Hoàn tất OAuth và kiểm dữ liệu test, hoặc ghi rõ dùng prototype | Chỉ bắt đầu task ghi khi có môi trường cô lập |
| P1 | A01/A05: gọn vẫn dễ tìm | T01; hỏi nghĩa nhãn Trợ lý/Sổ tay/Đã chốt sau task | Modify nếu không tìm/giải thích được; phục hồi nhãn hoặc trợ giúp |
| P1 | A02: lỗi được hiểu đúng | T02; mã hóa cách đối chiếu và gửi tiếp | Không duyệt luồng nếu dẫn đến sửa nhầm hoặc gửi lặp |
| P1 | A03: ghi chú theo buổi có ích | Phỏng vấn artefact gần đây + T03 | Giữ/tái thiết kế theo cách truy xuất thực tế |
| P2 | A04: một tay/mạng ảnh hưởng chính | Quan sát có đồng thuận và task trên thiết bị thường dùng | Chọn kích thước/bố cục từ vướng mắc thực |
| P2 | A06: nhiều công cụ/workaround | Hỏi quy trình hiện tại trước khi giới thiệu app | Bỏ phát biểu thay thế công cụ nếu không có bằng chứng |
| P2 | A07: ba persona khác nhau | Đối chiếu coverage sau mỗi vòng | Gộp nếu cùng pattern; giữ nếu khác biệt dẫn tới quyết định UI |

## Quy tắc cập nhật persona

Sau mỗi vòng, thêm E thực tế và nguồn, ghi bằng chứng thuận/nghịch cho A; không đổi nhãn cả persona thành validated chỉ vì một người phù hợp. Ghi phiên bản và lý do giữ/gộp/tách. Nếu chưa đủ nguồn thì giữ Proto-persona, nêu câu hỏi mở; không tự chấm đạt research gate.

