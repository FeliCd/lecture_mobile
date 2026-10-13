# Kế hoạch tính năng hỗ trợ giảng viên Đại học FPT

Ngày: 13/10/2026. Trạng thái: đang triển khai đợt đầu F01/F02/F04a; xem [phạm vi đã làm và giới hạn](LECTURER_MVP1_IMPLEMENTATION.md). Các mục còn lại vẫn là đề xuất. Dựa trên source shared hiện tại và các thay đổi UI Nielsen trong working tree.

## Mục tiêu và giả định

Giảm thời gian chuẩn bị, thao tác và tổng hợp công việc của giảng viên; hỗ trợ theo dõi lớp qua cả học kỳ. Android làm trước; giữ bốn tab hiện tại, không tạo thêm một hệ thống LMS cạnh tranh. Ưu tiên tính năng có thể dùng độc lập, không phụ thuộc API FAP/FLM chưa được cung cấp.

Ưu tiên bên dưới là đánh giá sản phẩm ban đầu, chưa phải kết quả phỏng vấn giảng viên. Cần xác minh với 3–5 giảng viên thuộc ít nhất hai nhóm môn trước khi khóa phạm vi.

Nguồn bối cảnh:
- Quy chế đào tạo FPTU: https://daihoc.fpt.edu.vn/hoat-dong-nha-truong/tin-tuc-chung/quy-che-dao-tao-dai-hoc-chinh-quy/
- Nghiên cứu và đổi mới FPTU: https://daihoc.fpt.edu.vn/nghien-cuu-doi-moi/

Các nguồn xác nhận bối cảnh tổ chức giảng dạy, hướng dẫn, phản hồi và nghiên cứu; không xác nhận nhu cầu đối với từng tính năng đề xuất. Quy định/mẫu áp dụng thực tế cần xác nhận theo campus, học phần và học kỳ. Không dùng một ngưỡng mặc định để kết luận quyền dự thi hoặc điểm chính thức.

## Nền tảng đã có, không xây trùng

Today, lịch ngày/tuần và ngoại lệ lịch; roster và import OCR/Excel/CSV; điểm danh QR, sửa có lý do/audit; thống kê chuyên cần và CSV; tin/nghiên cứu theo môn và thư viện riêng. Quiz có source nhưng tắt trong shared mode; cần tích hợp backend và Student Web trước khi công bố dùng được.

ARCHITECTURE.md và README.md là mô tả shared hiện hành. DATA_DICTIONARY.md còn mô tả mô hình Firestore Lab 2 cũ, không dùng nó làm cơ sở di chuyển điểm danh khỏi Sheets.

## Backlog ưu tiên

| ID | Tính năng | Tiện ích cụ thể | Ưu tiên | Ước lượng sơ bộ |
|---|---|---|---|---|
| F01 | Nhắc lịch và việc cần làm | Nhắc trước giờ dạy, chuẩn bị tài liệu, hạn chấm bài và việc cá nhân | P1 | 3–5 ngày công |
| F02 | Sổ tay buổi dạy | Mục tiêu, checklist, link tài liệu, nội dung đã dạy, việc cần nối tiếp | P1 | 4–6 ngày |
| F03 | Theo dõi hỗ trợ sinh viên | Nâng thống kê hiện có thành danh sách cần liên hệ, ghi chú trao đổi, hẹn theo dõi | P1 | 4–6 ngày |
| F04 | Báo cáo tuần/học kỳ | Tổng hợp phiên đã chốt, việc chưa xong và chuyên cần; xuất XLSX/PDF | P1 | 3–5 ngày |
| F05 | Nhóm và tiến độ đồ án | Chia nhóm, đề tài, checkpoint, biên bản hướng dẫn và lịch bảo vệ | P2 | 6–9 ngày |
| F06 | Poll/exit ticket cuối buổi | Kiểm tra nhanh mức hiểu bài qua Student Web; giảng viên xem tổng hợp | P2 | 5–8 ngày |
| F07 | Bộ rubric và nhận xét mẫu | Soạn tiêu chí chấm, đánh giá nháp, tái dùng nhận xét; giảng viên duyệt | P2 | 5–8 ngày |
| F08 | Tài liệu giảng dạy theo môn | Gắn bài đã lưu/link slide/code demo vào đề cương và buổi học | P2 | 3–5 ngày |

Ước lượng cho một kỹ sư đã hiểu repo, gồm UI/API/test cơ bản; chưa gồm chờ cấp quyền, deployment, thử nghiệm người dùng và tích hợp hệ thống trường. Không cộng tất cả thành cam kết giao hàng một lần. F01–F04 là ứng viên; MVP đầu tiên chỉ chọn F01 + F02 + phần nhỏ F04.

## MVP 1 — Trợ lý buổi dạy

### F01: Nhắc lịch và việc cần làm

- Today có mục Việc cần làm; tạo việc gắn lớp/môn/buổi hoặc độc lập, hạn hoàn thành, đánh dấu xong và hoãn.
- Cấu hình nhắc trước 10/15/30 phút, khung giờ yên lặng, tắt theo lớp; nhấn notification mở đúng buổi/việc.
- MVP dùng local notifications. Không cần thêm quyền truy cập Google Calendar. Xuất lịch ICS là tùy chọn sau MVP; đồng bộ Calendar hai chiều tách riêng.
- Chỉ lập nhắc cho occurrence có khoảng ngày hiệu lực đã xác nhận. Source hiện thiếu term date range chuẩn: phải thêm cấu hình khoảng ngày hoặc để giảng viên xác nhận khoảng lập nhắc, không lặp vô hạn từ lịch tuần.
- Khi app đồng bộ được lịch hủy/dời/đổi phòng, hủy và tạo lại nhắc bằng ID ổn định; không thông báo trùng. Nếu app chưa đồng bộ, lịch nhắc có thể cũ và phải hiển thị mốc đồng bộ.
- Nghiệm thu: từ chối quyền thông báo vẫn dùng được app; đăng xuất/đổi tài khoản dọn nhắc riêng; DST/timezone thiết bị không làm sai giờ UTC+7; không hứa đồng bộ tức thời khi app bị đóng. Thử reboot/background/battery saving trên Android thật.

### F02: Sổ tay buổi dạy

- Trước giờ: mục tiêu, checklist chuẩn bị, link slide/repo và thời lượng dự kiến.
- Sau giờ: nội dung đã hoàn thành, phần còn thiếu, ghi chú lần sau; nút sao chép kế hoạch sang buổi kế tiếp.
- Tạo mẫu theo môn nhưng bản ghi theo từng occurrence và lớp/học kỳ; hỗ trợ lớp song song với tiến độ khác nhau.
- Bản nháp local thuộc tài khoản, sync có revision/version. Khi có xung đột hai thiết bị, cho chọn/giữ bản sao, không ghi đè im lặng.
- Nghiệm thu: mở từ thẻ buổi học trong một lần chạm; giữ nháp khi offline/thoát ứng dụng; không lẫn ghi chú giữa lớp cùng mã môn; nhãn Đã lưu trên máy/Đã đồng bộ rõ ràng.

### F04a: Bản tổng kết tuần đơn giản

- Liệt kê buổi đã dạy, phiên đã chốt, buổi có lịch nhưng chưa có dữ liệu, checklist còn lại và việc tuần tới.
- Không suy diễn không có phiên = giảng viên bỏ dạy. Không dùng thời lượng mở QR làm số giờ giảng.
- Bắt đầu bằng bản xem trước và xuất XLSX từ dữ liệu đã có quyền; mở rộng PDF và báo cáo học kỳ sau.
- Nghiệm thu: đối chiếu được từng dòng về lớp/buổi nguồn; ghi kỳ báo cáo, thời điểm lấy dữ liệu, trạng thái chưa đồng bộ và policy; thiếu dữ liệu không bị đổi thành 0.

## MVP 2 — Đồng hành cùng sinh viên

### F03: Danh sách hỗ trợ có hành động

- Tận dụng thống kê chuyên cần hiện có; thêm quy tắc cá nhân như vắng liên tiếp theo các phiên hợp lệ đã chốt. Cấu hình và hiển thị rõ cơ sở tính.
- Giảng viên chọn sinh viên cần theo dõi, ghi nội dung hỗ trợ, lịch hẹn và kết quả. Không tự gắn nhãn sinh viên yếu hoặc kết luận cấm thi.
- Nút soạn lời nhắn theo mẫu mở ứng dụng email để giảng viên kiểm tra người nhận/nội dung và tự gửi; MVP không gửi tự động, không xin quyền đọc Gmail.
- Ghi chú hỗ trợ riêng; không lộ ra Student Web hoặc export lớp mặc định. Giảng viên khác không đọc được nếu chưa có cơ chế phân quyền được duyệt.
- Nghiệm thu: sửa điểm danh làm cập nhật danh sách đề xuất; bản ghi hỗ trợ không bị xóa; lọc theo lớp/kỳ/trạng thái; mất quyền lớp thì backend chặn đọc/ghi.

### F05: Quản lý nhóm/đồ án

- Nhóm, thành viên, đề tài, các mốc và người phụ trách; lưu nhận xét sau buổi hướng dẫn.
- Mốc báo cáo/checkpoint do giảng viên cấu hình theo môn; không áp một quy trình CNTT lên mọi ngành.
- MVP giảng viên tự cập nhật trạng thái, không xây nộp bài/lưu file lớn. Link Git/Drive mở bên ngoài.
- Nghiệm thu: ngăn nhóm chứa sinh viên ngoài roster, có lịch sử đổi nhóm, phân biệt kỳ; nhắc deadline dùng F01. Gắn thành viên theo roster thật và xử lý sinh viên rời lớp.

## MVP 3 — Công cụ dạy và đánh giá

- F06: xây poll 1–3 câu và exit ticket trên backend shared/Student Web. Tái sử dụng ý tưởng và test quiz có sẵn nhưng không bật cờ trước khi đủ backend. Chọn rõ poll định danh hay ẩn danh; không hứa ẩn danh nếu vẫn lưu UID/khả năng truy ngược. Không tính điểm chính thức trong MVP.
- F07: rubric tổng trọng số hợp lệ, mức đạt, nhận xét mẫu; lưu đánh giá nháp và export sau giảng viên duyệt. Chưa tự gửi điểm lên FAP hoặc quyết định điểm bằng AI.
- F08: nâng thư viện bài đã có thành bộ tài liệu gắn môn/chủ đề/buổi; tìm kiếm và tái dùng qua kỳ. Lưu link và metadata, không tự công khai tài liệu nội bộ. Nghiên cứu chuyên sâu có thể triển khai tiếp sau khi khảo sát nhu cầu.

## Vị trí UI

- Hôm nay: buổi sắp tới, việc đến hạn và checklist chuẩn bị.
- Lịch dạy: nhắc lịch và mở sổ tay từng buổi.
- Lớp học: tab/công cụ bên trong lớp cho hỗ trợ sinh viên, nhóm và báo cáo; không nhồi thêm vào bottom navigation.
- Cập nhật: thư viện tài liệu gắn môn, giữ feed đang có.
- Settings: thông báo, khung giờ yên lặng, đồng bộ/bản nháp và export.

Giữ yêu cầu Nielsen: trạng thái rõ, một hành động chính, undo khi có thể, giữ nháp, giúp đỡ theo ngữ cảnh và bộ lọc luôn nhận biết được.

## Kiến trúc và dữ liệu đề xuất

- Sheets/Apps Script tiếp tục authoritative cho roster, lịch và điểm danh. Không nhân bản chúng sang Firestore để làm nguồn nghiệp vụ mới.
- Lịch nhắc, cache và draft dùng local storage theo account. Ghi chú/việc cá nhân MVP local trước; sync qua Apps Script với bảng mở rộng riêng và cùng kiểm quyền Lecturer.
- Bảng dự kiến: LecturerTasks, LessonNotes; sau đó StudentFollowUps, ProjectGroups, ProjectMilestones. Đây là schema đề xuất, chưa tạo bảng. Trường chung: ID, lecturerId xác định server, classId/term/occurrence selector khi cần, createdAt/updatedAt và revision.
- Nếu cần chỉ lưu metadata cá nhân trong Firestore sau này, phải có cơ chế chứng minh quyền lecturer và thu hồi quyền phù hợp. Chỉ auth.uid/email_verified không đủ quyền truy cập dữ liệu lớp dùng chung. Không mở rộng rules thư viện bài để chứa dữ liệu sinh viên tùy ý.
- API mới kiểm identity, ownership, trường cho phép, version và idempotency key. Không đưa toàn bộ ghi chú vào snapshot 30 giây; tải theo lớp/buổi, phân trang và sync incremental.
- Liên kết buổi dùng occurrence resolver hiện có, không dựng ID bằng lớp+slot vì sẽ trùng giữa ngày/kỳ. Định nghĩa rõ hành vi khi buổi dời/hủy hoặc lịch nguồn bị sửa.
- Tất cả migration thêm bảng/cột phải idempotent, có backup/rollback và giữ contract Desktop/Student Web. Xóa dữ liệu học kỳ cần chính sách lưu giữ được xác nhận.

## Lộ trình đề xuất

1. Khảo sát + kiểm nền tảng (2–3 ngày): 3–5 giảng viên, chốt ba vấn đề mất thời gian nhất; xác minh shared backend, auth thật, policy, phạm vi ngày học kỳ và cấu hình local. Có dữ liệu giả lập để dev trong lúc chờ cloud.
2. MVP 1 (10–16 ngày): F01, F02, F04a và tích hợp Today/Lịch; thử Android thật, rollout cho nhóm nhỏ.
3. Pilot và điều chỉnh (3–5 ngày làm việc, thời gian sử dụng thực tế ít nhất một tuần): thu phản hồi, lỗi nhắc, conflict và thời gian thao tác.
4. MVP 2 (10–15 ngày): F03 + F05 nếu pilot xác nhận nhu cầu; ưu tiên hỗ trợ sinh viên trước quản lý nhóm nếu nguồn lực hạn chế.
5. MVP 3: chọn từng F06/F07/F08 theo dữ liệu sử dụng, không triển khai cả ba mặc định.

## Đo hiệu quả

Lấy baseline trước pilot. Mục tiêu đề xuất để xác nhận lại: ít nhất 4/5 người thử hoàn thành chuẩn bị buổi dạy không cần hướng dẫn; giảm 30% thời gian tổng hợp tuần; tạo ghi chú trong 30 giây; không nhắc trùng trong bộ kịch bản lịch hủy/dời/đổi tài khoản.

Ghi thời gian, tỷ lệ hoàn thành, số lỗi và nhận xét tự nguyện. Không thu nội dung ghi chú cá nhân hoặc dữ liệu sinh viên vào analytics. Không coi số màn hình/tính năng mới là chỉ số thành công.

## Chưa ưu tiên

Chatbot tổng quát, nhận diện khuôn mặt/GPS để điểm danh, hệ thống chat mới, tự chấm điểm hoặc tự ghi FAP, scraping tài khoản trường, LMS đầy đủ. Các tích hợp FAP/FLM cần tài liệu API và quyền hợp lệ; hiện chưa có bằng chứng repo hỗ trợ các API đó.

Đề xuất bắt đầu: nhắc việc + sổ tay buổi dạy + tổng kết tuần. Đợt này bổ sung trực tiếp vào quy trình trước/trong/sau giờ dạy, ít phụ thuộc hệ thống ngoài và có thể đo hiệu quả sớm.
