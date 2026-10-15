# Evidence và assumption matrix

Ngày rà soát: 15/10/2026. Chỉ `Observed` không đủ để hiểu độ mạnh bằng chứng: phải đọc cả **loại nguồn**. Source/test hiện diện không phải quan sát hành vi giảng viên.

## Nhãn và quy tắc

- **Observed:** người ghi trực tiếp kiểm tra đối tượng nêu trong nguồn; ví dụ code, ảnh UI hoặc thao tác trong một buổi nghiên cứu có ghi chép.
- **Reported:** điều người cung cấp tự nói; ghi rõ ai theo mã ẩn danh, thời điểm, hoàn cảnh. Chưa có phát biểu nghiên cứu của giảng viên.
- **Inferred:** diễn giải từ nguồn đã ghi, có thể bị phản bác.
- **Assumed:** chưa có nguồn người dùng hỗ trợ; cần câu hỏi/phép thử.
- Dùng E01… cho nguồn thực tế; A01… cho giả định. Chưa cấp E cho các buổi phỏng vấn dự kiến.

## Nguồn hiện có

| ID | Nhãn / loại nguồn | Nguồn cụ thể | Điều hỗ trợ | Điều không chứng minh |
|---|---|---|---|---|
| E01 | Observed / tài liệu sản phẩm | [README](../README.md), mục Chức năng và Chạy shared mode | Mobile lecturer, bốn tab, Student Web riêng, giới hạn dữ liệu | Quy mô nhu cầu, tần suất dùng thật |
| E02 | Observed / source UI | [today.dart](../lib/lab2/today.dart), [timetable_card.dart](../lib/lab2/timetable_card.dart), [timetable.dart](../lib/lab2/timetable.dart) | Focus buổi, lớp/môn/slot/phòng, lọc ngày/kỳ, nhãn ngắn | Thời gian tìm lớp hoặc mức độ dễ hiểu |
| E03 | Observed / source xử lý phiên | [live_attendance.dart](../lib/lab2/live_attendance.dart) | QR/Sinh viên, tìm kiếm/lọc, stale/expiry/denial, chốt phiên | Đã hoạt động ở mọi mạng/thiết bị hoặc cloud hiện hành |
| E04 | Observed / source form | [attendance_actions.dart](../lib/lab2/attendance_actions.dart), [báo cáo Nielsen](../docs/NIELSEN_UI_IMPLEMENTATION_REPORT.md) | Giữ lý do khi lỗi, chặn submit lặp, chỉ đóng khi thành công | Người dùng nhận ra hoặc hiểu cơ chế này |
| E05 | Observed / source + báo cáo triển khai | [lecturer_workspace.dart](../lib/lab2/lecturer_workspace.dart), [store](../lib/lab2/lecturer_workspace_store.dart), [MVP1](../docs/LECTURER_MVP1_IMPLEMENTATION.md) | Sổ tay/việc local, khóa buổi, nhắc Android, tổng kết tuần | Đã có đồng bộ cloud, backup hay nhắc đúng giờ trên mọi thiết bị |
| E06 | Observed / source test | [Nielsen tests](../test/nielsen_ui_test.dart), [phase2](../test/phase2_ui_test.dart), [assistant](../test/assistant_ui_test.dart), [motion](../test/motion_test.dart) | Có tình huống kỹ thuật tương ứng để đối chiếu | Test đã chạy trong đợt tài liệu hoặc người thật hoàn thành nhiệm vụ |
| E07 | Reported / phản hồi chủ dự án | Tin nhắn và ảnh màn Hôm nay trong cuộc trao đổi ngày 15/10/2026: chủ dự án nhận xét nhiều chữ và yêu cầu dùng keyword | Một yêu cầu thiết kế cụ thể: giảm mật độ chữ | Ý kiến đại diện cho giảng viên FPT, hay hiệu quả sau khi rút chữ |
| E08 | Observed / tài liệu môn | [Persona Guideline](https://prm393-material.web.app/persona-guideline), [Chuẩn chung](https://prm393-material.web.app/#standards), đọc 15/10/2026 | Nguồn đối chiếu cấu trúc hồ sơ và thuật ngữ | Giảng viên đã duyệt bài hoặc nhóm đã đạt gate |

Không đưa ảnh chứa tên/email/lớp thật vào hồ sơ chia sẻ. E07 chỉ lưu mô tả tối thiểu; không sao chép ảnh tài khoản vào tài liệu. Muốn dùng làm dữ liệu nghiên cứu cần ghi vai trò, phạm vi đồng thuận và giới hạn nguồn.

## Giả định cần kiểm chứng

| ID | Phát biểu có thể bị bác bỏ | Nguồn hình thành | Tác động nếu sai | Kiểm chứng |
|---|---|---|---|---|
| A01 | Người đổi lớp cần tìm đúng buổi nhanh và thường bị chia chú ý | Inferred E02/E07 | Keyword/thu gọn có thể làm khó hơn | Hỏi lần chuyển lớp gần nhất; T01 |
| A02 | Có nhóm cần phục hồi rõ hơn tốc độ | Assumed, tham chiếu nhánh lỗi E03/E04 | P02 có thể không phải phân khúc riêng | Quan sát lỗi ghi an toàn; T02; so sánh cách xử lý |
| A03 | Ghi việc tiếp nối theo buổi là nhu cầu lặp lại | Assumed, năng lực E05 | P03 có thể trùng P01 hoặc ít giá trị | Hỏi artefact tuần trước; T03 |
| A04 | Kết nối và thao tác một tay là rào cản đáng kể | Assumed | Chọn bố cục dựa bối cảnh sai | Quan sát thiết bị/bối cảnh thực có đồng thuận |
| A05 | Nhãn ngắn vẫn được hiểu ở chữ lớn và khi ít quen app | Assumed, phản hồi E07 chỉ đòi gọn | Người dùng không nhận ra Trợ lý/Sổ tay/Đã chốt | T01–T03, hỏi nghĩa nhãn sau nhiệm vụ, tránh gợi ý trước |
| A06 | Người dùng phải ghép thông tin qua nhiều công cụ | Assumed | Không nên tuyên bố app thay được workaround | Phỏng vấn về lần dùng gần nhất, xin artefact đã ẩn danh |
| A07 | Ba hồ sơ đủ bao quát mobile lecturer | Assumed | Bỏ sót nhu cầu hoặc tạo persona trùng | Review coverage sau từng vòng, tuyển ca đối lập |

## Mẫu thêm bằng chứng thật

```text
Evidence ID: [E09 trở đi, chỉ cấp khi đã thu thập]
Date/time & researcher: [điền]
Source kind: interview / observation / usability
Participant ID: [R01; không ghi email hay MSSV]
Consent scope: [ghi chép / ghi âm / artefact, có thể từ chối]
Context & task: [điền]
Raw observation or exact reported statement: [điền; không tự viết quote]
Status: Observed / Reported
Interpretation (separate): [Inferred; có thể trống]
Supports / contradicts: [A, P, D IDs]
Private source location + timestamp/line: [điền]
Redaction/access/retention: [điền]
Limitations and counterexamples: [điền]
```

