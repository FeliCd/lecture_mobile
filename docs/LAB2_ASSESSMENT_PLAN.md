# Kế hoạch trình bày và demo Lab 2 cho FAP Smart Lecturer

Ngày chuẩn bị: 15/10/2026. Hình thức: chấm cả nhóm, một người trình bày chính.

Mục tiêu của buổi trình bày là chứng minh chuỗi Analyze → Generate → Critique → Refine → Prototype → Handoff qua thiết kế ứng dụng hỗ trợ giảng viên. Người trình bày chính dẫn toàn bộ câu chuyện và thao tác demo; các thành viên hỗ trợ bằng chứng và trả lời phần phụ trách.

## 1 Phạm vi chấm và nguyên tắc chuẩn bị

Hai tài liệu tiếng Việt và tiếng Anh mô tả cùng một hướng dẫn đánh giá UI/UX có hỗ trợ AI từ Google Stitch sang Figma. Khung 10 phút trình bày, 5 phút demo, 5 phút hỏi đáp và 10–12 slide là đề xuất; điều chỉnh theo thông báo của giảng viên. Code Flutter không phải yêu cầu bắt buộc của Lab 2. Bản app đang chạy là tài liệu tham khảo và minh chứng triển khai bổ sung, không thay thế Figma, prototype, AI log hay handoff.

Các mức tối thiểu trong hướng dẫn: 8 màn hình khác nhau; 3 user flow có nhánh thay thế và ít nhất một nhánh lỗi/phục hồi; 3 vòng tinh chỉnh AI với mục tiêu khác nhau; 5 phát hiện UX gắn màn hình; 9 nhóm component; 6 trường handoff cho mỗi màn hình và 2 bảng mapping. Dialog và biến thể loading/error không tính thành màn hình mới.

Không trình bày ảnh mockup, prompt viết lại hoặc ví dụ trong kế hoạch này như bằng chứng đã thực hiện. Nếu thiếu lịch sử Stitch, tìm lại prompt và đầu ra gốc; nếu thực hiện bổ sung, ghi ngày thật và mô tả đây là vòng thiết kế bổ sung.

## 2 Câu chuyện xuyên suốt

**Thông điệp mở đầu đề xuất:** “Nhóm em thiết kế FAP Smart Lecturer để giảng viên xem đúng buổi dạy, mở điểm danh và theo dõi kết quả trên điện thoại. Nhóm sử dụng AI để tạo phương án ban đầu, sau đó đánh giá và chỉnh sửa dựa trên nhu cầu người dùng. Em sẽ trình bày các quyết định chính và chứng minh bằng ba luồng tương tác trong Figma.”

**Persona để nhóm hoàn thiện:** giảng viên cần thao tác nhanh giữa các tiết học, phân biệt đúng lớp/môn/phòng, theo dõi trạng thái điểm danh và tra cứu tài liệu theo môn. Đây là giả thuyết persona; chỉ gọi là kết quả nghiên cứu khi có phỏng vấn hoặc dữ liệu thật.

**Problem statement đề xuất:** giảng viên cần nhận diện đúng buổi học và trạng thái điểm danh trong thời gian ngắn, vì thao tác nhầm lớp hoặc không biết dữ liệu đã cập nhật có thể dẫn đến xử lý sai kết quả.

**Tiêu chí thành công để đo khi rehearsal:** tìm đúng buổi học và mở được bảng xác nhận trong tối đa 3 bước từ Hôm nay; hoàn thành 3 flow mà không cần người dẫn chỉ đường; nhận biết được lỗi và tìm được cách thử lại; không mất hành động chính ở độ rộng 360 và 412 dp. Đây là mục tiêu đề xuất, chưa phải kết quả đo.

## 3 Phân công khi bạn trình bày chính

| Vai trò | Trước buổi chấm | Trong buổi chấm |
|---|---|---|
| Bạn là người trình bày chính | Nắm cả 12 slide, tập ba flow và các câu hỏi trọng tâm | Dẫn 10 phút trình bày, thao tác 5 phút demo, nhận và điều phối câu hỏi |
| Người hỗ trợ UX và AI | Hoàn thiện persona, flow, prompt gốc, log, ảnh trước/sau | Mở sẵn bằng chứng khi cần; trả lời câu hỏi về AI và UX nếu được chuyển lời |
| Người hỗ trợ Figma | Kiểm tra pages, tokens, component instances, prototype links | Xử lý link/file khi gặp sự cố; giải thích Auto Layout, variants, token binding |
| Người hỗ trợ handoff và nộp bài | Kiểm tra README, screen specs, mappings, quyền truy cập | Canh giờ, mở repo/handoff, trả lời phần chuyển giao Flutter |

Đây là các vai trò công việc, không giả định nhóm có bốn người. Một thành viên có thể kiêm nhiều vai trò. Điền tên và phần đóng góp thực tế trước khi đưa vào slide 1. Không chia đều thời gian nói nếu làm đứt câu chuyện; mỗi người vẫn phải hiểu và bảo vệ được phần mình làm.

## 4 Nội dung 12 slide trong 10 phút

| Slide | Thời lượng | Nội dung và câu chốt | Bằng chứng cần mở được |
|---|---|---|---|
| 1 Tổng quan | 30 giây | Tên sản phẩm, đối tượng, vấn đề, thành viên và đóng góp. Chốt phạm vi thiết kế Mobile giảng viên. | Link Figma và repo thật |
| 2 Vấn đề và persona | 55 giây | Bối cảnh giữa các tiết học; khó nhận diện lớp và trạng thái; mục tiêu thao tác. Giải thích nguồn persona và chỉ số dự kiến đo. | Persona và problem statement |
| 3 Kiến trúc thông tin | 35 giây | Bốn tab Hôm nay, Lịch dạy, Lớp học, Cập nhật; màn hình con và tối thiểu 8 màn hình. Giải thích vì sao ưu tiên Hôm nay. | Sitemap và danh sách screen ID |
| 4 Ba user flow | 55 giây | Mở điểm danh; xem kết quả lớp; tìm/lưu tài liệu. Chỉ start, goal, kết thúc, nhánh thay thế và lỗi/phục hồi. | Sơ đồ flow và mapping flow–screen |
| 5 Tạo UI bằng AI | 50 giây | Trích prompt nguyên văn và đầu ra Stitch ban đầu; chỉ ra persona, task, mobile platform, constraints, style. | Prompt gốc, ảnh output, DESIGN.md |
| 6 Ba vòng tinh chỉnh | 85 giây | Mỗi vòng: vấn đề khác nhau → prompt → before/after → đánh giá. Trình bày ít nhất 5 phát hiện UX ở màn hình cụ thể. | AI log và ảnh có thứ tự, nguồn, ngày |
| 7 Quyết định thiết kế | 40 giây | 3–5 quyết định accept/modify/reject; liên hệ persona, Nielsen hoặc ràng buộc. Chỉ nhận là quyết định với AI khi có output tương ứng. | design-decisions.md và frame liên quan |
| 8 Wireframe và UI cuối | 60 giây | So sánh bố cục low-fi và final; hierarchy, CTA, consistency, loading/empty/error. Chọn 2 cặp màn hình để giải thích sâu. | Pages 02 và 03; tổng đủ 8 màn hình |
| 9 Design system | 65 giây | Color/type/spacing/radius/elevation; 9 nhóm component; Auto Layout, variants và instances gắn tokens thật. | Pages 04 và 05, Variables/styles |
| 10 Accessibility và responsive | 45 giây | Contrast, target 48×48 dp, body ≥14 sp, 360/412 dp; nhãn chữ/icon bên cạnh màu trạng thái. | Số đo, cặp màu, ảnh hai độ rộng |
| 11 Giới thiệu prototype | 20 giây | Nêu ba flow sẽ demo, điểm cần quan sát: phục hồi lỗi, Back, overlay và loading→result. Chưa thao tác dài ở slide này. | Page 06 và starting points |
| 12 Handoff và kết luận | 60 giây | Một screen spec đủ 6 phần; hai bảng token→Flutter và component→widget; giới hạn thực tế và link nộp. | flutter-handoff.md và README |

Tổng cộng 600 giây. Mỗi slide ưu tiên một luận điểm và ảnh bằng chứng. Để log dài, bảng spec và thông số chi tiết trong repo; slide chỉ trỏ tới nơi kiểm chứng.

**Câu chuyển sang demo:** “Phần tiếp theo em sẽ chạy ba nhiệm vụ trong prototype để chứng minh các quyết định vừa trình bày có thể sử dụng được, bao gồm trường hợp lỗi và cách quay lại.”

## 5 Bộ màn hình và ba flow đề xuất

Tạo hoặc đối chiếu 11 màn hình dưới đây với file Figma thật. Màn nào chưa có phải được thiết kế và nối prototype trước khi ghi là hoàn thành.

| ID | Màn hình | Flow sử dụng |
|---|---|---|
| S01 | Đăng nhập Google | Điểm vào hoặc bối cảnh cho các flow |
| S02 | Hôm nay | A |
| S03 | Lịch dạy | Nhánh thay thế của A |
| S04 | Điểm danh trực tiếp | A |
| S05 | Danh sách lớp | B |
| S06 | Chi tiết lớp và danh sách sinh viên | B |
| S07 | Thống kê lớp | B |
| S08 | Lịch sử điểm danh của sinh viên | B |
| S09 | Cập nhật theo môn | C |
| S10 | Chi tiết bài viết | C |
| S11 | Thư viện đã lưu | C |

**Flow A mở và theo dõi điểm danh:** S02 → chọn buổi học → overlay chọn thời lượng và xác nhận → loading → S04 → overlay kết thúc → kết quả. Nhánh thay thế: S03 → chọn cùng buổi → tiếp tục flow. Nhánh lỗi: không tải được trạng thái → hiện lý do và Thử lại → tải thành công. Back không được vô tình chốt phiên. Trong prototype, việc lưu/chốt chỉ là mô phỏng tương tác.

**Flow B kiểm tra sinh viên cần theo dõi:** S05 → tìm lớp → S06 → S07 → chọn sinh viên → S08 → Back về đúng lớp/bộ lọc. Nhánh thay thế: mở sinh viên từ danh sách S06. Nhánh lỗi: không có buổi đã chốt → empty state giải thích và đường quay lại danh sách, không biểu diễn tỷ lệ giả.

**Flow C tìm và lưu tài liệu theo môn:** S09 → chọn môn/từ khóa → loading → kết quả → S10 → lưu → S11 → mở lại bài. Nhánh thay thế: đổi môn hoặc bộ lọc nguồn trước khi chọn bài. Nhánh lỗi: nguồn lỗi hoặc không có kết quả → thông báo cụ thể → Thử lại hoặc đổi điều kiện → kết quả. Tách trạng thái Lưu thành công khỏi thao tác chỉ mở nguồn ngoài.

## 6 Kịch bản demo trực tiếp trong 5 phút

| Mốc | Thao tác | Điểm cần nói |
|---|---|---|
| 00:00–00:20 | Cho xem đủ 6 page và zoom overview Final UI | Có tối thiểu 8 màn hình khác nhau; dialog không được đếm riêng |
| 00:20–01:25 | Chạy flow A từ starting point đến đích | Overlay, loading→result, lỗi→Thử lại, kết thúc có xác nhận |
| 01:25–02:10 | Chạy flow B đến lịch sử sinh viên rồi Back | Mục tiêu rõ ràng; quay lại đúng ngữ cảnh; không dead-end |
| 02:10–02:55 | Chạy flow C đến bài đã lưu | Đổi điều kiện hoặc phục hồi lỗi; có phản hồi lưu thành công |
| 02:55–03:40 | Mở một component dùng Auto Layout, states, instance và token binding | Chứng minh tái sử dụng thật; văn bản token trên bảng chưa đủ |
| 03:40–04:20 | Mở một vòng AI có ảnh trước/sau và frame đã sửa | Prompt → output → critique → decision → thay đổi |
| 04:20–05:00 | Mở repo và một screen spec, hai bảng mapping | Người khác có đủ thông tin để triển khai layout và states |

Sáu page cần có đúng tên và thứ tự: **01 User Flow**, **02 Wireframe**, **03 Final UI**, **04 Design System**, **05 Components**, **06 Prototype**. Mở sẵn các starting point và tab tài liệu trước khi bắt đầu. Với ba flow ngắn, tập thao tác đúng nhịp; tránh dành cả 5 phút cho điểm danh.

## 7 Chuẩn bị bằng chứng AI và UX

Ba chủ đề cải tiến phù hợp dự án để đối chiếu với lịch sử thật:

1. **Nhận diện buổi học và ưu tiên CTA:** xem lại màn Hôm nay; làm rõ môn, lớp, slot, phòng và hành động chính.
2. **Phản hồi trạng thái và phòng lỗi:** xem lại Live Attendance; trạng thái đồng bộ, tải lỗi, thử lại và xác nhận kết thúc.
3. **Khả năng đọc và dùng trên màn nhỏ:** xem lại lớp, bộ lọc hoặc form; text scaling, target size, bố cục ở 360/412 dp.

Các mục này là đề xuất cho việc chọn minh chứng hoặc thực hiện vòng bổ sung; không chứng minh nhóm đã thực hiện ba vòng AI đó. Báo cáo sửa Flutter theo Nielsen cũng không tự thay thế lịch sử prompt và output của Stitch.

Mỗi bản ghi AI log nên có: ngày/giờ, công cụ, screen ID, mục tiêu, prompt nguyên văn, đường dẫn ảnh đầu ra, nhận xét UX, accept/modify/reject, lý do, thay đổi Figma và kết quả kiểm tra. Dùng cùng screen ID trong log, slide, frame và handoff để tìm nhanh.

Năm vấn đề UX để kiểm tra trên ảnh thật: CTA bị cạnh tranh ở S02; thiếu feedback khi tải ở S04; kết thúc phiên quá dễ ở S04; khó đọc danh sách/bộ lọc ở S06; nguồn nội dung lỗi thiếu đường phục hồi ở S09. Với mỗi vấn đề, ghi vị trí cụ thể, ảnh trước, heuristic liên quan, ảnh sau và cách xác minh. Chỉ báo cáo vấn đề đã quan sát, không khẳng định cả năm tồn tại nếu ảnh không thể hiện.

Ví dụ lập luận quyết định để dùng khi phù hợp bằng chứng: giữ bốn tab theo nhóm nhiệm vụ; chỉnh lịch tuần thành danh sách ngày dễ đọc trên điện thoại; từ chối trạng thái chỉ phân biệt bằng màu; thêm xác nhận trước thao tác kết thúc. Không nhận đây là accept/reject AI nếu chưa có đề xuất AI tương ứng.

## 8 Design system accessibility và handoff

Design system phải có color, typography, spacing, radius và elevation; đủ Button, Text field, Card, Navigation, App bar, Dialog, Loading, Empty, Error. Mỗi nhóm có states phù hợp: ví dụ Button default/pressed/disabled/loading; Text field default/focus/error/disabled; Navigation selected/unselected; Error có thử lại. Dùng variants và instances; thể hiện binding với Variables/styles.

Source Flutter hiện có thể tham khảo cho spacing 4/8/12/16/24, gutter 20, radius 8/12/16 và màu brand/action trong `lib/lab2/theme.dart`. Đây là thông số code, cần đối chiếu Figma trước khi tuyên bố đã đồng bộ. Bổ sung elevation rõ ràng, kể cả lựa chọn flat/0 cho component phù hợp.

Checklist accessibility theo tài liệu: normal text ≥4.5:1; large text/UI controls ≥3:1; touch target ≥48×48 dp; body text ≥14 sp; kiểm tra 360 và 412 dp; trạng thái có nhãn/icon chứ không chỉ màu. Lưu kết quả đo theo cặp foreground/background và state thực tế. Báo cáo UI hiện có nhắc 360, 393 và 430, không đủ để khẳng định đã kiểm đúng 412 dp.

Mỗi screen spec gồm đúng 6 phần: **layout**, **components**, **states**, **interactions**, **navigation**, **UI constraints**. Với S04, cần chỉ rõ vùng thông tin buổi học, counters, QR, danh sách, hành động kết thúc; trạng thái đang tải/mở/dữ liệu cũ/lỗi/đã đóng; hành vi thử lại, Back, xác nhận kết thúc và ràng buộc màn nhỏ. Viết tương tự cho mọi màn hình final, không chỉ một màn mẫu.

Hai bảng mapping phải tách riêng:

| Token Figma đề xuất | Flutter tham chiếu cần đối chiếu |
|---|---|
| color/action | CampusColors.action hoặc ColorScheme.primary theo theme |
| space/lg | CampusSpace.lg |
| radius/card | CampusRadius.card |
| type/body | TextTheme và thông số final cụ thể |
| elevation/card | CardTheme hoặc elevation theo thiết kế đã chốt |

| Component Figma đề xuất | Widget Flutter tham chiếu |
|---|---|
| Button primary | AppPrimaryButton |
| Search field | CampusSearchField |
| Card | CampusCard |
| Confirm dialog | campusConfirm |
| Loading | CampusLoadingState |
| Empty | EmptyState |
| Error | ErrorState |

Tên token và component Figma ở đây là đề xuất đặt tên. Điền đường dẫn component/token thật và thông số thực tế vào bản handoff nộp bài.

## 9 Đối chiếu rubric và khoảng trống hiện tại

| Tiêu chí | Điểm | Bằng chứng phải chuẩn bị | Trạng thái qua kiểm tra repo |
|---|---|---|---|
| UX analysis và user flows | 15 | Persona, problem statement, sitemap, 3 flow, screen mapping | Chưa tìm thấy bộ ux/persona.md và ux/user-flow.md trong repo |
| AI UI generation | 10 | Prompt gốc và output Stitch | Chưa tìm thấy DESIGN.md hoặc bộ output Stitch được dẫn nguồn |
| AI iterations và critique | 15 | 3 vòng khác mục tiêu, before/after, ≥5 phát hiện UX | Có báo cáo Nielsen; chưa tìm thấy AI log theo yêu cầu |
| Final UI/UX | 20 | ≥8 final screens, states, hierarchy, accessibility | Có code UI và báo cáo; cần kiểm Figma và bằng chứng 412 dp |
| Design system và components | 15 | Tokens, 9 nhóm, Auto Layout, variants, instances | Có theme/widgets Flutter; chưa kiểm file Figma |
| Interactive prototype | 10 | 3 flow, Back, overlay, loading→result, recovery | Chưa có link Figma để xác minh |
| Flutter handoff | 10 | 6 trường/màn và 2 bảng mapping | Chưa tìm thấy flutter-handoff.md |
| Documentation và AI log | 5 | README dẫn đủ artifacts và link xem được | Có README kỹ thuật; cần mục điều hướng hồ sơ Lab 2 |

Tổng 100 điểm; nhóm quá trình 45 và nhóm sản phẩm 55. Slide/demo không có điểm riêng ngoài rubric này. Đây là kiểm kê minh chứng, không phải điểm dự đoán. Không tìm thấy trong repo không đồng nghĩa thành viên chưa có tài liệu ở nơi khác.

## 10 Danh mục hồ sơ và thứ tự hoàn thiện

Cấu trúc đề xuất trong repo hiện tại, không cần tạo repo thứ hai chỉ để trình bày:

```text
README.md                         mục Lab 2 và link Figma
DESIGN.md                         định hướng thiết kế và prompt đầu
ux/persona.md
ux/user-flow.md                    sitemap và mapping flow–screen
ai/ai-design-log.md
ai/evidence/                      output và before/after thật
design-decisions.md
flutter-handoff.md                 screen specs và hai mappings
assets/lab2/                      ảnh final và accessibility evidence
```

**Ưu tiên 1:** lấy file Figma và minh chứng gốc từ các thành viên; kiểm số màn hình, pages và ba flow. Chốt cái gì đã có, cái gì cần làm thêm.

**Ưu tiên 2:** bổ sung AI log và quyết định thiết kế có ảnh thật; hoàn thiện persona/flow/handoff; kiểm tokens, components và layout 412 dp. Đây là các phần bản app chạy được chưa chứng minh thay cho nhóm.

**Ưu tiên 3:** làm 12 slide theo bảng trên; gắn mọi ảnh với frame/log tương ứng; điền thành viên và đóng góp thật; thêm link và QR link nộp nếu cần.

**Ưu tiên 4:** rehearsal một lượt đúng 20 phút, ghi câu hỏi bị vấp và thao tác thừa; lặp lại ba flow trong 5 phút; một người khác thử prototype mà không được chỉ đường.

## 11 Chuẩn bị hỏi đáp trong 5 phút

1. **Vì sao chọn bốn tab?** Liên hệ nhóm nhiệm vụ của persona và tần suất sử dụng; chỉ sơ đồ điều hướng, tránh chỉ nói “dễ dùng”.
2. **AI đóng góp gì, nhóm đóng góp gì?** Mở prompt/output thật và chỉ phần nhóm sửa hoặc từ chối với lý do.
3. **Ba vòng khác nhau thế nào?** Nêu ba vấn đề UX khác nhau và ảnh chứng minh; đổi màu ba lần không tự chứng minh ba mục tiêu khác nhau.
4. **Flow dễ lỗi nhất và cách phục hồi?** Chọn lỗi tải trạng thái, nguồn nội dung hoặc điều kiện mở phiên; demo đường Thử lại/đổi điều kiện và Back.
5. **Thay token có cập nhật toàn bộ không?** Chỉ instance đang binding thật. Không khẳng định tất cả nếu còn frame hardcode.
6. **Đã kiểm 412 dp thế nào?** Mở frame đúng độ rộng và kết quả kiểm nội dung dài, CTA, cuộn, danh sách. Không lấy ảnh 430 dp thay thế.
7. **Handoff có đủ để lập trình không?** Mở một spec 6 phần và hai mapping; chỉ state và tương tác dễ bỏ sót.
8. **Có cần giải thích backend không?** Nêu ngắn: Firebase Auth xác thực; Apps Script/Sheets giữ dữ liệu lớp; Firestore lưu thư viện cá nhân. Quay lại trọng tâm quyết định UI/UX nếu không được hỏi sâu.

Bạn trả lời câu đầu, rồi chuyển cho thành viên phụ trách nếu cần chi tiết. Không đọc thay phần của người khác hoặc nhận toàn bộ đóng góp về một người.

## 12 Checklist trước giờ chấm

- [ ] Đã xác nhận thời lượng, hình thức nộp slide và ngôn ngữ trình bày theo thông báo giảng viên.
- [ ] Figma có đúng 6 page, tối thiểu 8 màn hình khác nhau và 3 starting point.
- [ ] Ba flow chạy trọn vẹn; Back đúng; có nhánh thay thế, lỗi/phục hồi, overlay và loading→result.
- [ ] AI log có prompt/output thật, ít nhất 3 vòng khác mục tiêu, ảnh trước/sau và 5 phát hiện cụ thể.
- [ ] Có 3–5 quyết định được giải thích; không gắn nhãn “AI đề xuất” cho việc không có bằng chứng.
- [ ] Có tokens, 9 nhóm component, Auto Layout, variants và instance binding.
- [ ] Đã đo contrast và kiểm target/font; có bằng chứng 360 và 412 dp.
- [ ] Mỗi final screen có spec đủ 6 trường; có hai bảng mapping riêng.
- [ ] README dẫn đúng repo và Figma; thử quyền xem bằng cửa sổ chưa đăng nhập, không công khai dữ liệu lớp thật.
- [ ] Mở sẵn slide, Figma prototype, component mẫu, AI log, handoff; tắt thông báo khi trình chiếu.
- [ ] Có bản slide xuất PDF và video prototype dự phòng; nói rõ khi dùng bản ghi thay demo tương tác.
- [ ] Nếu demo Flutter bổ sung: chạy đúng config/lab2.free.json; không để phần cài đặt/đăng nhập chiếm thời gian Figma.
- [ ] Không tạo hoặc đóng phiên điểm danh thật chỉ để minh họa; ưu tiên prototype hoặc dữ liệu demo riêng.
- [ ] Cả nhóm biết phần đóng góp, nơi mở bằng chứng và ai trả lời từng nhóm câu hỏi.

**Câu kết đề xuất:** “Ba luồng vừa demo cho thấy người dùng có thể hoàn thành nhiệm vụ, nhận biết trạng thái và phục hồi khi gặp lỗi. Hồ sơ nộp kèm ghi lại quá trình AI, quyết định thiết kế, design system và đặc tả chuyển giao để có thể kiểm chứng từng phần.” Chỉ dùng câu này sau khi cả ba flow đã thực sự chạy đạt.

## Nguồn đối chiếu

- C:\Users\ontri\Downloads\PRM323_Lab2_HuongDan_Slide_Presentation_Demo.docx
- C:\Users\ontri\Downloads\PRM323_Lab2_Presentation_Assessment_Guidelines_EN.docx
- Repo hiện tại: README.md, docs/ARCHITECTURE.md, docs/MOBILE_UI_UX_REDESIGN_REPORT.md, docs/NIELSEN_UI_IMPLEMENTATION_REPORT.md, lib/lab2/theme.dart và lib/lab2/app.dart.

Hai file hướng dẫn dẫn lại đề Lab 2 gốc ngày 28/09/2026; kế hoạch này chưa đối chiếu trực tiếp bản đề gốc 12 trang. Các trạng thái Figma cần cập nhật khi có file nhóm đang sử dụng.
