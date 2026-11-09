# Đối chiếu slide FAP Attendance với guideline PRM393

Rà soát ngày 09/11/2026. Tệp guideline có tên V1.0, nội dung ghi Version 11. Bản đã rà soát giữ 24 slide chính, khoảng 20 phút, và 8 slide phụ lục. Ba workflow dùng một lớp mẫu. Mobile và Desktop dành cho giảng viên. Student Web dành cho sinh viên.

**Kết luận** — Bản trước đủ số mục chính, nhưng một số mục chỉ có mô tả hoặc kỳ vọng demo. Bản mới bổ sung nội dung thiết kế và minh chứng cục bộ. Các phần cần người dùng hoặc môi trường thật được tách riêng bên dưới.

## Đối chiếu từng mục

| Slide | Mục của guideline | Bản đã rà soát | Phần cần thêm hoặc xác nhận |
|---|---|---|---|
| 01 | Overview | Tên đề tài, PRM393, vai trò và ảnh Mobile/Student Web với dữ liệu mẫu. | Thông tin nhóm và GVHD để người trình bày tự điền. |
| 02 | Context | Bối cảnh một lớp đại học, lịch, roster và các mốc xử lý. Walkthrough kỹ thuật dùng 32 SV mẫu. | Quy mô, quy trình và tần suất thực tế chưa được khảo sát. |
| 03 | Problem | Ba điểm nghẽn có nguyên nhân và hệ quả. Có tình huống kỹ thuật để kiểm chứng. | Chưa có số liệu hiện trường hoặc phỏng vấn để định lượng tác động. |
| 04 | Proposed Solution | Ánh xạ từng vấn đề với thiết kế, kết quả quan sát và phạm vi MVP. | Mục tiêu ở mức nghiệm thu chức năng. Chưa đo mức giảm thời gian hoặc sai sót. |
| 05 | Main Actors | Giảng viên, sinh viên, dịch vụ xác thực và quyền theo lớp. | Đối chiếu quyền bằng tài khoản test khi demo live. |
| 06 | Main Features | Bốn nhóm FR, ba workflow và phạm vi mở rộng. | — |
| 07 | Business Flow | Luồng tổng thể theo vai trò, ba điểm quyết định có mã BR và kết quả từ chối. | — |
| 08 | State Machine | Vòng đời đơn, điều kiện chuyển, đường chuyển bị cấm và TC-01b. | — |
| 09 | Architecture | Ba client, API chung, Sheets, giao tiếp và lưu ý đồng bộ theo lượt đọc. | Kiểm bản backend đang deploy trước buổi demo. |
| 10 | Technology Stack | Công nghệ theo trách nhiệm, đối chiếu source. | — |
| 11 | UI/UX | Điều hướng, mã UI và ảnh triển khai. A4 có trạng thái và thay đổi sau walkthrough. | Link Figma chốt và lịch sử wireframe/hi-fi để người trình bày tự bổ sung. Walkthrough kỹ thuật dùng dữ liệu mẫu. |
| 12 | Sequence | Công bố điểm với lifeline, tên hàm và nhánh VERSION_CONFLICT. | — |
| 13 | Class Design | UI, controller, repository, dịch vụ và dữ liệu; có thuộc tính, hàm và phụ thuộc. | — |
| 14 | Database Conceptual | Quan hệ và cardinality cho lớp, buổi, đơn, phiên, điểm. | — |
| 15 | Database Logical/Physical | Bảng/cột thật, khóa logic, kiểu dữ liệu và hàm khởi tạo ở A5. | Ràng buộc thực thi trong Apps Script và kiểm bằng fixture. |
| 16 | Traceability | FR, WF, BR, UI, code, dữ liệu và test trong một bảng. | — |
| 17 | Demo Plan | Storyboard, tài khoản theo vai trò, seed cố định, phân vai và script tái tạo dữ liệu local. | Chọn lớp, slot và tài khoản test cho live. Video dự phòng do nhóm bổ sung. |
| 18 | Demo WF-01 | Gửi, duyệt, đọc lại đơn. Nhánh gửi trùng. Có ID và kết quả fixture. | Chạy Web và Desktop trực tiếp, ghi ID và trạng thái thật. |
| 19 | Demo WF-02 | Mở, check-in, chốt và đối chiếu. Nhánh check-in sau chốt. Có ID và kết quả fixture. | Chạy Mobile, QR Web và đối chiếu Desktop trên cùng deployment. |
| 20 | Demo WF-03 | Lưu nháp, giữ điểm cũ, công bố, đọc điểm mới. Có ID và ca version cũ. | Chạy Mobile, Desktop và Web, ghi ID công bố thật. |
| 21 | Testing | Bốn bộ kiểm thử local, số pass/fail, test theo BR và ba workflow fixture. Có lệnh tái chạy và tham chiếu CI trong Notes. | Chưa có kết quả E2E cloud/UAT cho ba workflow. |
| 22 | Achievements | Đối chiếu mục tiêu với kết quả đo được trong fixture và ID ở A6. | Chưa có chỉ số vận hành thật. |
| 23 | Limitations | Giới hạn, tác động, ưu tiên và bước xác minh. | — |
| 24 | Conclusion | Kết luận, liên kết repo và cổng sinh viên công khai. | Figma và video demo để người trình bày tự điền. |
| A1–A8 | Appendix | Test theo BR, Firebase Lab 3, chuẩn bị và reset demo local, UI, schema, bản ghi fixture, đặc tả và activity từng workflow. | Phân công tên thành viên theo vai trò nếu nhóm cần. |

## Kết quả có thể tái chạy

| Bộ kiểm thử | Lệnh | Pass | Fail |
|---|---|---:|---:|
| Mobile | `flutter test --no-pub --reporter expanded` trong repo Mobile | 303 | 0 |
| Desktop | `flutter test --no-pub --reporter expanded` trong repo Desktop | 96 | 0 |
| Student Portal | `npm test` trong repo Web | 59 | 0 |
| Apps Script + trang QR | `node --test backend/test/*.cjs web_checkin/test/*.cjs` trong repo Mobile | 150 | 0 |
| Walkthrough Mobile | `flutter test --no-pub test/ux_lecturer_walkthrough_test.dart --reporter expanded` | 5 | 0 |
| Diễn tập nghiệp vụ local | `node output/prm/Demo_PRM_Fixture.cjs` trong repo Mobile | 3 workflow | 0 |

Walkthrough là tập con của suite Mobile. Không cộng trùng khi báo cáo. Snapshot đã đối chiếu là Mobile `ad24170`, Desktop `521e2e2` và Student Web `976b1c5`. Cổng sinh viên trả HTTP 200 cho trang công khai khi kiểm tra ngày 09/11/2026. Việc này chỉ xác nhận truy cập trang HTML.

| Workflow | ID do fixture sinh ra | Quan sát được |
|---|---|---|
| WF-01 | `9fa00f5d-cfce-4bbd-ada0-f0a52e46e850` | Đơn chuyển từ PENDING sang APPROVED. Chặn đơn trùng và chặn hủy đơn đã duyệt. |
| WF-02 | `076b580b-053a-496c-8ae7-31073a8eb31e` | Phiên CLOSED. A là EXCUSED, B là PRESENT. Check-in sau chốt bị từ chối. |
| WF-03 | `d864afef-d9fd-45df-94d4-d7859c7c0687` | API đọc điểm của Web trả 7,0 trước và sau lưu nháp, rồi 8,5 sau công bố. Version cũ bị chặn. |

Script gọi mã nghiệp vụ Apps Script trong bộ nhớ, với Google Sheets và danh tính mô phỏng. Mỗi lần chạy tạo seed mới và ID mới. Không cần tài khoản Google hoặc triển khai. Khi demo live, ghi ID, kết quả và lỗi của chính lần chạy trên ba client.
