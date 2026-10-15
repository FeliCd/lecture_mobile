# Hồ sơ UX — FAP Attendance Mobile

Ngày lập: 15/10/2026. Phạm vi: app giảng viên trong repo hiện tại, entry `lib/main.dart`. Đây là hồ sơ chuẩn bị nghiên cứu và truy vết thiết kế; chưa phải báo cáo nghiên cứu đã hoàn thành.

## Đọc và sử dụng

1. [Persona](persona.md): problem statement, ba phân khúc giả định, đủ 12 trường mỗi hồ sơ và thông tin bổ sung phục vụ Lab 2.
2. [Evidence matrix](evidence.md): tách bằng chứng source, phản hồi của chủ dự án và giả định về giảng viên.
3. [Stakeholder, brainstorming và affinity](discovery.md): bản đồ phạm vi, nhóm ý tưởng và cách quyết định giữ/gộp persona.
4. [User flow](user-flow.md): IA, ba luồng, nhánh phục hồi và mã màn hình.
5. [Kế hoạch nghiên cứu](research-plan.md): tuyển người, câu hỏi, ba nhiệm vụ usability, backlog và mẫu ghi kết quả.
6. [Design decisions](../design/design-decisions.md): chuỗi Evidence → Persona → Need → Flow → Screen → Decision → Test.
7. [Screen spec](../design/screen-spec.md): danh mục màn và trạng thái cần kiểm tra.

Tài liệu dựa trên code và các báo cáo trong repo; không thêm tính năng, tài khoản hoặc dữ liệu giảng viên vào hệ thống.

## Trạng thái hồ sơ

| Hạng mục | Trạng thái |
|---|---|
| Phạm vi và problem statement | Có bản nháp, cần xác thực nhu cầu |
| Ba proto-persona và coverage matrix | Có; chưa có qualitative persona |
| Stakeholder map và affinity ban đầu | Có; nguồn code/giả định được gắn nhãn |
| Kế hoạch workshop | Có; chưa có biên bản hay ảnh workshop thật |
| Bằng chứng phỏng vấn/quan sát giảng viên | Chưa thu thập |
| Ba flow và truy vết tới source/test | Có đối chiếu tĩnh; không chạy lại test trong đợt tài liệu |
| Usability với người tham gia | Có protocol; chưa thực hiện, không có điểm đo |
| Tuổi, thiết bị, accessibility của người tham gia | Chưa xác minh; không lấy thông tin cá nhân trong tài khoản app để suy ra |
| Figma, prototype và ảnh workshop để nộp | Chưa bổ sung trong đợt này |
| Tự chấm / kết luận qua gate | Chưa chấm; không tuyên bố đạt môn từ hồ sơ này |

Các kết quả analyze/widget test trong báo cáo triển khai là bằng chứng kỹ thuật tại thời điểm ghi nhận. Chúng không xác nhận giảng viên hiểu UI, không thay kết quả usability và không chứng minh cloud E2E hiện tại.

## Nguồn và cách đọc

- [Persona Guideline](https://prm393-material.web.app/persona-guideline), đặc biệt các mục quantity, deliverables.
- [Chuẩn chung](https://prm393-material.web.app/#standards).
- [README hiện hành](../README.md), [Nielsen](../docs/NIELSEN_UI_IMPLEMENTATION_REPORT.md), [Trợ lý giảng dạy](../docs/LECTURER_MVP1_IMPLEMENTATION.md).

Hai trang môn học đã được tải đọc ngày 15/10/2026. Chuẩn chung phân biệt hồ sơ cá nhân và đồ án nhóm; quy định chấm áp dụng cho nhóm cần xác nhận với giảng viên. Các tài liệu trong thư mục này là cách nhóm chuẩn bị cho dự án, không sao chép ví dụ Teacher Station thành yêu cầu sản phẩm.

## Việc nhóm cần làm tiếp

- Chọn người phụ trách tuyển mẫu, điều phối và ghi chép; ghi tên vào [research plan](research-plan.md).
- Thực hiện phỏng vấn/quan sát có đồng thuận; lưu ghi chú ẩn danh và mã nguồn.
- Điền kết quả ba nhiệm vụ, điều chỉnh/gộp persona khi bằng chứng không ủng hộ phân khúc ban đầu.
- Gắn bằng chứng mới vào quyết định thiết kế; bổ sung artefact Figma/prototype theo đề bài thực tế.

