# Proto-persona và phạm vi nhu cầu

**Trạng thái chung: Assumed, chưa nghiên cứu giảng viên.** Tên nhân vật là tên minh họa; các hành vi, tuổi và thiết bị dưới đây là giả định để tuyển mẫu/đặt câu hỏi. Không có lời trích dẫn người tham gia. Mã E chỉ tới [nguồn](evidence.md); A chỉ tới giả định, không phải bằng chứng xác thực persona.

## Phạm vi và problem statement

Mobile phục vụ giảng viên được phân công lớp; sinh viên check-in qua Student Web, dữ liệu lớp/điểm danh dùng chung với Desktop. Dữ liệu việc và sổ tay hiện lưu trên thiết bị. Xem E01–E05.

**Problem statement cần kiểm chứng:** Giảng viên phụ trách nhiều buổi dạy có thể khó nhận diện đúng buổi, theo dõi tình trạng điểm danh và tìm lại việc cần tiếp nối khi sự chú ý bị chia nhỏ, dẫn đến mất thời gian hoặc thao tác nhầm.

Đây là giả thuyết A01/A03, không phải kết luận nghiên cứu. Phản hồi E07 chỉ xác nhận chủ dự án thấy một màn hình nhiều chữ.

## P01 — Giảng viên chuyển lớp, ưu tiên tốc độ

| Trường | Hồ sơ nháp |
|---|---|
| 01. Identity & Archetype | **Thầy Minh**, nhân vật minh họa cho người thường chuyển bối cảnh giữa các buổi dạy. |
| 02. Persona Priority | **Primary**: tác vụ trọng tâm là nhận diện buổi và điều hành điểm danh. Ưu tiên này là lựa chọn phạm vi, chưa chứng minh nhóm này đông nhất. |
| 03. Usage Context | Assumed A01: dùng điện thoại trước giờ vào lớp, đang đứng/di chuyển, vừa trao đổi với sinh viên vừa nhìn màn hình. |
| 04. Goals | Nhận diện đúng lớp/phòng; bắt đầu đúng phiên; biết khi nào có thể chốt mà không bỏ sót trường hợp cần kiểm tra. |
| 05. Job to Be Done | Khi chuyển sang buổi dạy tiếp theo, tôi muốn xác định đúng buổi và kiểm tra điểm danh để bắt đầu giảng với ít gián đoạn. |
| 06. Current Behaviors | UNKNOWN: công cụ đang dùng, số lần chuyển lớp/ngày và cách đối chiếu danh sách. Giả thuyết A06: có thể kiểm lịch trên hệ thống khác rồi mở danh sách riêng; phải hỏi lần sử dụng gần nhất. |
| 07. Pain Points | Assumed A01: nhiều dòng chữ làm chậm quét thông tin; cuộn qua QR để tìm người; nhầm lớp khi tên môn giống nhau. E07 liên quan tới mật độ chữ, chưa xác nhận hai vấn đề còn lại. |
| 08. Motivations | Assumed: giữ nhịp buổi học, chính xác danh sách, giảm thời gian xử lý trước lớp. |
| 09. Constraints | Assumed A04/A05: mạng không ổn định, thao tác một tay, chú ý bị phân tán; quyền sửa/chốt do backend quyết định (E03/E04). |
| 10. Key Scenarios | Trước giờ dạy: tìm buổi mục tiêu, đối chiếu môn/lớp/slot/phòng, mở hoặc tiếp tục đúng phiên. Trong buổi: tìm một sinh viên trong danh sách và kiểm tra trạng thái. F01, T01. |
| 11. Success Criteria | **Mục tiêu thử**, chưa có kết quả: nhận diện và tới đúng phiên trong ≤30 giây, không chọn nhầm lớp, không cần điều phối viên chỉ vị trí. Chưa tính thời gian tạo phiên qua mạng vào chỉ số này. |
| 12. Evidence & Status | Proto-persona. A01/A04/A06; E01–E04 là nguồn mô tả sản phẩm, E07 là phản hồi một chủ dự án. Chưa có interview/observation ID. |

**Lab 2 bổ sung:** tuổi minh họa 35 (Assumed, không dùng để phân nhóm); vai trò giảng viên đại học; thói quen Android hằng ngày và một tay là Assumed; cần kiểm chứng nhu cầu chữ lớn, độ tương phản và sử dụng ngoài lớp. Không suy ra thị lực hoặc năng lực số từ tuổi.

## P02 — Giảng viên cần xác nhận và phục hồi rõ ràng

| Trường | Hồ sơ nháp |
|---|---|
| 01. Identity & Archetype | **Cô An**, nhân vật minh họa cho người ưu tiên hiểu kết quả thao tác và sửa sai. |
| 02. Persona Priority | **Secondary**: bảo đảm luồng chính vẫn dùng được khi người dùng cần trợ giúp hoặc ít quen app này. |
| 03. Usage Context | Assumed A02: chỉnh một ngoại lệ điểm danh hoặc quay lại sau lỗi ghi; có thể dùng app không thường xuyên. |
| 04. Goals | Biết đang sửa ai; hiểu thao tác đã được lưu chưa; tiếp tục xử lý sau lỗi mà không nhập lại. |
| 05. Job to Be Done | Khi cần điều chỉnh một trường hợp điểm danh, tôi muốn hiểu thay đổi và xác nhận kết quả để tránh ghi sai hoặc gửi lặp. |
| 06. Current Behaviors | UNKNOWN: có nhờ người khác hỗ trợ, ghi ra giấy hay chờ xử lý trên Desktop không. Đây là câu hỏi nghiên cứu A06, không phải hành vi đã quan sát. |
| 07. Pain Points | Assumed A02: nhãn quá ngắn có thể khó hiểu; không rõ lỗi có làm mất dữ liệu; sợ xác nhận nhầm người hoặc phiên. E04 chứng minh có nhánh lỗi kỹ thuật, không chứng minh mức độ lo lắng này. |
| 08. Motivations | Assumed: cảm giác kiểm soát, khả năng đối chiếu, tin cậy kết quả và có đường quay lại an toàn. |
| 09. Constraints | Assumed A05: cần chữ lớn/nhãn dễ hiểu; mạng lỗi khi ghi là tình huống thiết kế. Lý do sửa và phân quyền không được bỏ để giảm số chạm. |
| 10. Key Scenarios | Đổi một trạng thái, nhập lý do, gặp lỗi ghi trong môi trường test; kiểm tra nội dung còn giữ và xác minh trước khi quyết định gửi tiếp. F02, T02. |
| 11. Success Criteria | Mục tiêu thử: hoàn thành tình huống trong ≤90 giây; giữ đúng người và lý do; không gửi lặp khi kết quả chưa rõ; giải thích được tình trạng lưu. |
| 12. Evidence & Status | Proto-persona. A02/A05/A06; E03/E04/E06 hỗ trợ thiết kế hiện có. Chưa có dữ liệu xác nhận một phân khúc riêng. |

**Lab 2 bổ sung:** tuổi minh họa 44 (Assumed); vai trò giảng viên; tần suất dùng điện thoại/app và trình độ công nghệ UNKNOWN. Nhu cầu accessibility cần hỏi trực tiếp: chữ phóng to, thao tác chạm, đọc màn hình; không mặc định người này có khuyết tật.

## P03 — Giảng viên tổ chức công việc qua nhiều buổi

| Trường | Hồ sơ nháp |
|---|---|
| 01. Identity & Archetype | **Cô Linh**, nhân vật minh họa cho người ưu tiên chuẩn bị và tiếp nối nội dung qua nhiều buổi. |
| 02. Persona Priority | **Secondary**: bổ trợ trước/sau luồng lên lớp và điểm danh; có thể gộp vào P01 sau nghiên cứu. |
| 03. Usage Context | Assumed A03: chuẩn bị trước giờ dạy và ghi việc tiếp nối sau buổi; phụ trách hơn một lớp. |
| 04. Goals | Tìm lại đúng kế hoạch; nhớ phần chưa hoàn thành; theo dõi hạn cá nhân mà không bỏ sót. |
| 05. Job to Be Done | Khi kết thúc một buổi, tôi muốn lưu lại phần cần tiếp tục và tìm được ở buổi sau để chuẩn bị đúng nội dung. |
| 06. Current Behaviors | UNKNOWN: ghi chú trong sổ giấy, ứng dụng ghi chú, lịch hoặc chat là các khả năng cần hỏi, chưa được khẳng định. Tần suất và cách đặt tên ghi chú chưa rõ. |
| 07. Pain Points | Assumed A03: khó ghép ghi chú với đúng lớp/buổi; quên việc nối tiếp; nhầm giữa đã lưu trên máy và đồng bộ thiết bị khác. |
| 08. Motivations | Assumed: chuẩn bị chủ động, duy trì mạch bài, giảm việc phải ghi nhớ bằng trí nhớ. |
| 09. Constraints | E05: việc/sổ tay chỉ lưu local; thông báo phụ thuộc Android, quyền và thời gian yên lặng. Nhu cầu chuyển nhiều máy là UNKNOWN; chưa được giải quyết bởi tính năng hiện tại. |
| 10. Key Scenarios | Mở sổ tay đúng buổi, ghi phần tiếp nối, tạo một việc, mở lại và đối chiếu. F03, T03. |
| 11. Success Criteria | Mục tiêu thử: lưu và tìm lại đúng buổi trong ≤120 giây; nội dung khớp; nói đúng nơi lưu dữ liệu; không nhầm sang lớp cùng môn. |
| 12. Evidence & Status | Proto-persona. A03/A06; E05 là khả năng/giới hạn kỹ thuật, chưa phải bằng chứng nhu cầu sử dụng hằng ngày. |

**Lab 2 bổ sung:** tuổi minh họa 32 (Assumed); vai trò giảng viên; giả thuyết dùng Android tại lớp và có thể dùng máy tính khi chuẩn bị. Thói quen chuyển thiết bị và nhu cầu hỗ trợ đọc/nhập chưa xác minh.

## Persona Coverage Matrix

Mọi ô hành vi dưới đây là giả định; không coi ba cột là ba nhóm người đã tuyển.

| Trục khác biệt | P01 | P02 | P03 |
|---|---|---|---|
| Kết quả ưu tiên | Đúng buổi, thao tác nhanh | Hiểu và phục hồi đúng | Tiếp nối công việc |
| Thời điểm | Trước/trong lớp | Khi gặp ngoại lệ/lỗi | Trước/sau lớp |
| Nút thắt cần kiểm chứng | Tìm kiếm, cuộn, chia chú ý | Sự rõ ràng, xác nhận, giữ input | Truy xuất ghi chú, nhớ hạn |
| Thiết kế khác biệt để thử | Nhãn gọn, focus buổi, QR/Sinh viên | Nhãn trạng thái, lý do, trợ giúp đúng chỗ | Gắn sổ tay với buổi, tự lưu, checklist |
| Rủi ro tối giản quá mức | Bỏ mất môn/phòng | Keyword gây khó hiểu | Không nhận ra nơi lưu/phạm vi buổi |
| Thiết bị/rào cản | Một tay, mạng | Chữ lớn, app ít quen | Nhập dài, chuyển thiết bị chưa hỗ trợ |
| Bằng chứng người dùng | Chưa có; E07 chỉ là phản hồi chủ dự án | Chưa có | Chưa có |
| Quyết định sau nghiên cứu | Giữ nếu tác vụ tốc độ nổi bật | Gộp nếu chỉ là trạng thái tạm thời của P01 | Gộp nếu cùng pattern và không cần quyết định UI riêng |

Giữ ba hồ sơ để đặt câu hỏi, không để đạt chỉ tiêu số lượng. Nếu P02/P03 không dẫn đến quyết định khác biệt có căn cứ, ghi lý do gộp; nếu xuất hiện nhóm bị bỏ sót thì mở hồ sơ mới từ bằng chứng.

