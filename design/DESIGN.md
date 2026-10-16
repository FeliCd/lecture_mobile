# DESIGN.md — FAP Smart Lecturer (Lab 2: Google Stitch → Figma)

Tài liệu đầu vào cho Google Stitch và là nguồn style của Figma. Prompt bên dưới là **nguyên văn** để dán vào Stitch; output, ảnh và các vòng chỉnh ghi trong [ai/ai-design-log.md](ai/ai-design-log.md). Persona và flow: [ux/persona.md](ux/persona.md), [ux/user-flow.md](ux/user-flow.md).

## 1. Sản phẩm

- **Tên:** FAP Smart Lecturer (FAP Attendance — Mobile giảng viên).
- **Nền tảng:** Android-first, iOS-ready; Flutter Material 3; khung thiết kế 360×800 và 412×915 dp.
- **Người dùng:** giảng viên đại học được phân công lớp. Sinh viên check-in qua Student Web, không dùng app này.
- **Vấn đề:** giảng viên dạy nhiều buổi khó nhận đúng buổi, theo dõi điểm danh và tìm lại việc cần tiếp nối khi bị chia nhỏ chú ý (giả thuyết, xem persona).
- **Persona chính:** P01 Thầy Minh — chuyển lớp, ưu tiên tốc độ. Phụ: P02 Cô An (xác nhận/phục hồi), P03 Cô Linh (tiếp nối nhiều buổi).

## 2. Ràng buộc thiết kế

| Nhóm | Ràng buộc |
|---|---|
| Ngôn ngữ | UI tiếng Việt, nhãn ngắn dạng keyword; không thuật ngữ kỹ thuật (secret, kind code) |
| Điều hướng | 4 tab đáy: Hôm nay · Lịch dạy · Lớp học · Cập nhật; Tài khoản ở avatar app bar |
| Nghiệp vụ | 4 trạng thái riêng: Có mặt / Đi trễ / Vắng / Vắng có phép; sửa điểm danh bắt buộc lý do; chốt phiên phải xác nhận |
| Trạng thái | Mỗi màn có loading / empty / error + hành động phục hồi; QR ẩn khi hết hạn hoặc dữ liệu cũ |
| Accessibility | Chữ ≥4.5:1, điều khiển ≥3:1, vùng chạm ≥48 dp, chữ nội dung ≥14 sp, không chỉ dùng màu |
| Phạm vi | Không thêm livestream, chat, bảng viết, workspace sinh viên |

## 3. Style "FPT Campus Orange"

| Token | Light | Dark | Ghi chú |
|---|---|---|---|
| color/brand | `#F37021` | `#F37021` | Chỉ accent, không làm chữ (2.94:1) |
| color/primary (action) | `#B54708` | `#FFB181` | Nút, link, tab chọn |
| color/on-primary | `#FFFFFF` | `#24150D` | |
| color/primary-container | `#FFE7D5` | `#543020` | Indicator tab, chip chọn |
| color/surface | `#FFFFFF` | `#1B2535` | Card, sheet, input |
| color/background | `#F7F8FA` | `#111A29` | Nền trang |
| color/on-surface | `#172033` | `#EDF2FA` | Chữ chính |
| color/on-surface-variant | `#667085` | `#AEBBD0` | Chữ phụ |
| color/outline-variant | `#E7EAF0` | `#2D3A50` | Divider, viền card |
| color/status/present·late·absent·excused·pending | `#15803D` `#98600B` `#B42318` `#0F6B93` `#667085` | `#74D89A` `#FFD27A` `#FF8E85` `#8ED8F3` `#B6C0CE` | Luôn kèm icon + chữ |
| space | 4 · 8 · 12 · 16 · 24; gutter trang 20 | | `CampusSpace` |
| radius | control 8 · card 12 · sheet 16 | | `CampusRadius` |
| elevation | 0 (card phẳng + viền); sheet/dialog dùng elevation M3 mặc định | | |
| type | headline 24/700 · title-L 20/700 · title-M 16/600 · title-S 14/600 · body 16/14 · label nav 12 | | Font hệ thống (Roboto) |

Phong cách: Material 3, "modern campus productivity" — nền trung tính, card phẳng viền nhẹ, cam là điểm nhấn; không gradient, glow, ảnh trang trí giả hay biểu đồ không có dữ liệu.

## 4. Prompt khởi tạo cho Google Stitch (nguyên văn)

> Chế độ Stitch: **Mobile**. Dán nguyên văn, không chỉnh sửa; lưu ảnh output vào `ai/screenshots/R0-*.png`.

```text
Design a mobile app (Android, Material 3, 360x800 dp) called "FAP Smart Lecturer" for university lecturers in Vietnam. All UI text in Vietnamese.

PERSONA: Thầy Minh, 35, a lecturer who teaches 3–4 different classes per day and moves between rooms. He checks his phone while standing, often one-handed, with unstable Wi-Fi, a few minutes before class. Pain points: too much text slows scanning, he scrolls past the QR to find one student, and he confuses classes with similar subject names.

PRIMARY TASK: In under 30 seconds, identify the correct teaching session (subject, class code, slot, room), open or resume its attendance session, show a QR code for students to scan, then find one student and change their status.

SCREENS (8): 1) Google sign-in; 2) "Hôm nay" today dashboard with the current/next session card and quick actions; 3) "Lịch dạy" timetable with day/week toggle; 4) "Lớp học" class list with search; 5) class detail with tabs Sinh viên / Điểm danh / Buổi học / Thống kê; 6) live attendance session with segmented QR | Sinh viên, a large QR with countdown, and a searchable student list; 7) "Sổ tay" lesson notebook tied to one session (before/after class notes, autosave); 8) "Cập nhật" subject news feed with source and date.
Bottom navigation with 4 tabs: Hôm nay, Lịch dạy, Lớp học, Cập nhật. Account via avatar in the top app bar.

CONSTRAINTS: attendance statuses are exactly Có mặt, Đi trễ, Vắng, Vắng có phép, each shown with icon + text + color (never color alone). Editing a status requires a reason. Ending a session needs a confirmation dialog. Every list needs loading, empty and error states with a recovery action. Touch targets at least 48x48 dp, body text at least 14 sp, text contrast at least 4.5:1.

STYLE: FPT campus orange. Accent #F37021 only for highlights; action/button color #B54708 with white text; text #172033, secondary text #667085; background #F7F8FA; flat white cards with 1px #E7EAF0 border, radius 12; controls radius 8; spacing 4/8/12/16/24. Clean, calm, productivity-focused. No gradients, no glow, no decorative illustrations, no fake charts.
```

## 5. Prompt chỉnh sửa (mỗi vòng một mục tiêu khác nhau)

Ghi output và critique của từng vòng trong AI log.

**R1 — Mật độ thông tin / nhận diện buổi (Nielsen #8, persona P01):**

```text
On the "Hôm nay" screen, reduce text density. Each session card shows only: time + slot, subject code, class code, room, and one status chip. Remove repeated descriptions and helper paragraphs. Make the current session card visually dominant and place its primary action ("Mở phiên" or "Tiếp tục phiên") at the bottom of the card within thumb reach. Keep all text at least 14 sp.
```

**R2 — Phục hồi lỗi khi sửa điểm danh (Nielsen #5, #9, persona P02):**

```text
Design the "Sửa điểm danh" bottom sheet over the live session screen. Show the student's full name, student ID, class and slot at the top so the lecturer can confirm the right person. Four status choice chips (Có mặt, Đi trễ, Vắng, Vắng có phép) with icon + text. A required "Lý do" text field. Primary button "Lưu" shows a spinner and "Đang lưu…" while saving and cannot be pressed twice. Also design the error state: the sheet stays open, the reason text is preserved, and an inline message says the result is uncertain and asks to check the record before sending again.
```

**R3 — Accessibility / contrast và dark mode (WCAG, constraint):**

```text
Create the dark theme for all screens: background #111A29, surface #1B2535, text #EDF2FA, secondary text #AEBBD0, primary #FFB181 with dark text #24150D on buttons. Make every input and chip border at least 3:1 contrast against its background in both light and dark themes. Check that status colors stay distinguishable without color by keeping their icons. Show the live session screen and the class list at 412 dp width as well.
```
