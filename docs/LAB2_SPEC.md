# FAP SMART LECTURER — LAB 2

> Source Mobile hiện hành 11/10/2026: Google-only, 4 tab Hôm nay/Lịch dạy/Lớp học/Cập nhật, phiên từ lịch với duration 5/10/15/20/30 phút và phòng hiệu lực. Xem [MOBILE_UI_UX_REDESIGN_REPORT](MOBILE_UI_UX_REDESIGN_REPORT.md). Mô tả email/password, form phiên thủ công và deployment cũ trong tài liệu này là lịch sử, không chứng minh source mới đã được triển khai cloud.
## Master Product Requirements, Architecture, Business Rules, Design System & Codex Execution Plan

> **Document type:** Single source of truth / PRD + Technical Specification + Design System + AI coding instructions  
> **Version:** 1.1 — 08/10/2026 (FPT Orange & White update)  
> **Project origin:** FAP Attendance — PRM393 Lab 1 (Flutter Desktop)  
> **Project target:** PRM393 Lab 2 — Flutter Mobile (Android-first, iOS-ready)  
> **Language:** Vietnamese UI; English names for source code, classes, APIs and collections.  
> **Status:** Implementation specification. Codex MUST audit the existing repository before implementing; do not assume current files or Lab 1 integration are already available.

---

# 0. LỆNH ĐỌC TRƯỚC CHO CODEX (READ THIS FIRST)

Bạn đóng vai **Senior Flutter Engineer + Firebase Architect + UI/UX Designer + QA Engineer**. Hãy xây dựng **một ứng dụng Mobile sử dụng được từ đầu đến cuối**, không chỉ mock UI, theo tài liệu này. Giữ đúng bốn phân hệ cốt lõi:

1. **Smart QR Attendance** — tạo phiên, hiển thị QR động, quét và ghi nhận điểm danh.
2. **Attendance Analytics** — tình trạng điểm danh lớp, biểu đồ, thống kê từng sinh viên.
3. **Subject News & Research Hub** — khám phá bài báo/tin tức liên quan đến môn được dạy.
4. **Live Quiz & Classroom Poll** — tạo quiz/poll, sinh viên tham gia, giảng viên xem kết quả real-time.

Các chức năng nền tảng **Login / Role / Subjects / Classes / Sessions / Student Membership** là bắt buộc để bốn module hoạt động, nhưng không được mở rộng dự án thành LMS toàn năng.

**Quy tắc làm việc:**

- **Khảo sát code trước:** liệt kê cấu trúc repo, dependency, schema hiện tại, logic Lab 1 có thể tái sử dụng. Không viết lại Desktop nếu không cần.
- **Tuyệt đối không bịa rằng đã tích hợp FAP API**: Lab 1 không xác nhận API FAP chính thức. Dùng nhập dữ liệu/CSV/Google Sheets và xuất dữ liệu phù hợp để cập nhật FAP thủ công.
- Chạy ứng dụng theo **vertical slices**: một luồng end-to-end chạy được, sau đó hoàn thiện luồng tiếp theo; không làm hàng loạt UI giả rồi mới làm backend.
- Tách rõ UI, state, repositories, Firebase adapters, Cloud Functions và tests. Không hardcode dữ liệu thực vào màn hình.
- Toàn bộ chức năng ghi dữ liệu quan trọng phải xác thực, phân quyền và kiểm tra **ở server**, không chỉ phía Flutter.
- Thực thi Security Rules, indexes, emulator tests, trạng thái loading/empty/error/retry, xử lý timeouts và các tình huống edge case.
- Nếu thiếu Firebase credentials, Google OAuth, API key hoặc billing: tạo `.env.example` / template config, adapters/mock providers **được đánh dấu rõ**, seed data, hướng dẫn cấu hình; không tuyên bố tích hợp thành công khi chưa chạy thật.
- Không commit secrets, service-account JSON, OAuth tokens hoặc API keys. Không phá hủy dữ liệu hoặc chạy lệnh git reset/force push.
- Mọi thay đổi phải nhất quán với **Design System “FPT Campus Orange”** mục 11; KHÔNG dùng màu sắc/font/card khác nhau tùy màn hình.
- Sau mỗi phase, ghi những gì đã làm/chưa làm, cách chạy và bằng chứng kiểm thử vào `docs/IMPLEMENTATION_PROGRESS.md`.
- Khi cần chọn thư viện, ưu tiên stable versions tương thích Flutter/Dart hiện có, không tự động áp phiên bản gây breaking change.

## 0.1. Definition of Done (toàn dự án)

- [ ] Flutter mobile build được trên Android emulator/thiết bị Android thật.
- [ ] Có 2 role `lecturer` và `student`, đồng nhất trong một ứng dụng, có route guard thực sự.
- [ ] Giảng viên chọn lớp, mở phiên QR, sinh viên thuộc lớp quét QR và được ghi nhận; không thể điểm danh trùng/hết hạn/sai lớp.
- [ ] Lecturer xem analytics đúng với các phiên đã kết thúc và có drill-down theo sinh viên.
- [ ] Lecturer tìm bài báo liên quan đến môn, có nguồn/ngày/link; có thể chia sẻ link cho lớp.
- [ ] Lecturer tạo quiz/poll, student tham gia 1 lần theo rule và lecturer nhìn thấy kết quả.
- [ ] Firebase Security Rules + tests ngăn truy cập trái phép. Firebase client không được tự ý sửa điểm danh/đáp án quiz.
- [ ] Có import/export cơ bản bằng CSV; Google Sheets live sync triển khai nếu có quyền truy cập và credentials, nếu không thì ghi rõ là optional.
- [ ] Có light/dark theme, giao diện tiếng Việt, responsive, trạng thái lỗi, accessibility cơ bản.
- [ ] Unit/widget/integration/emulator tests quan trọng chạy pass (hoặc ghi rõ blockers nếu thiếu môi trường).
- [ ] Có README, setup guide, `.env.example`, seed demo, demo script và danh sách known limitations.

---

# 1. TẦM NHÌN SẢN PHẨM & PHẠM VI

## 1.1. Product vision

**FAP Smart Lecturer** là trợ lý lớp học trên điện thoại cho giảng viên: chuẩn bị buổi học → tổ chức điểm danh → tương tác quiz/poll → khám phá/chia sẻ tri thức mới → xem báo cáo chuyên cần.

**USP:** Điểm danh + Phân tích lớp học + Nội dung nghiên cứu theo môn + Tương tác trong giờ, kết nối trên **cùng lớp học/môn học/buổi học**.

## 1.2. Personas & quyền

| Actor | Nhiệm vụ |
|---|---|
| **Lecturer** | Xem lớp được giao; tạo và điều khiển phiên điểm danh; sửa điểm danh có audit; xem analytics; khám phá và chia sẻ article; tạo/mở/đóng quiz/poll, xem thống kê. |
| **Student** | Xem lớp được ghi danh; quét QR; xem điểm danh bản thân; đọc bài được chia sẻ; tham gia quiz/poll trong giờ. |
| **System Operator / Seeder** | Tạo tài khoản, gán lecturer vào lớp, import sinh viên, cấu hình subject taxonomy. **Không xây màn hình Admin** trong scope Lab 2; thực hiện bằng script đáng tin cậy hoặc Firebase Console có kiểm soát. |

**Lưu ý quan trọng:** Student UI là một phần tối thiểu của **cùng app Flutter** để demo hai chức năng yêu cầu hai phía (QR và quiz), không phải một dự án Mobile thứ hai.

## 1.3. Scope

| Ưu tiên | Bao gồm | Không bao gồm |
|---|---|---|
| **P0 / Required** | Auth + role; class/subject/session; QR check-in; attendance analytics; article discovery; article sharing; single-choice quiz + poll; kết quả real-time; seed data; Security Rules; export CSV. | Không có FAP API tự động; không tạo LMS assignment/grading; không AI chatbot; không hệ thống chat/video. |
| **P1 / Nice to have** | Google Sheets import/export trực tiếp; push notifications; attendance corrections kèm audit; book-mark article; lịch xem theo tuần; offline cache các màn hình read-only. | — |
| **P2 / Future** | Multi-question quizzes, AI quiz generation, advanced recommendations, geofencing, AI summarization, iOS release. | Không tự ý thực hiện nếu P0 chưa đạt. |

**Assumptions cần kiểm chứng từ repo hoặc với chủ dự án:**
- Android là target demo chính; iOS-ready nhưng không bắt buộc phát hành iOS.
- Dùng Firebase project riêng cho Lab 2; không giả định Lab 1 đã dùng Firebase.
- Dữ liệu tên trường/học phần/sinh viên demo là **synthetic**; không cần kết nối FAP trực tiếp.
- Default timezone `Asia/Ho_Chi_Minh`; lưu timestamp UTC tại server.
- Phân quyền giảng viên không suy ra từ tên email: có thể nhập email trường nhưng **role phải do hệ thống cấp**.

---

# 2. TECH STACK & TỔ CHỨC REPOSITORY

## 2.1. Stack đề xuất

| Layer | Tech | Purpose |
|---|---|---|
| Mobile UI | Flutter + Dart, Material 3 | Android-first, iOS-ready, 1 codebase, 2 role |
| State management | Riverpod (`flutter_riverpod`) | Async state, dependency injection, testable presentation |
| Navigation | `go_router` | Auth/role guards, deep links, typed params nếu phù hợp |
| Data models | Freezed + json_serializable **hoặc** handwritten immutable models có test | Chọn một quy ước xuyên dự án |
| Authentication | Firebase Authentication | Google Sign-In nếu cấu hình phù hợp; email/password demo fallback |
| Data | Cloud Firestore | Classes, membership, sessions, attendance, article cache, quizzes |
| Privileged logic | Firebase Cloud Functions (TypeScript) | Check-in, QR signing, quiz submit/score, analytics reconciliation, Sheets integration |
| API Security | Firebase Auth + Firestore Security Rules + App Check (khi cấu hình production) | Phân quyền và giảm abuse |
| External articles | OpenAlex; Crossref fallback/augmentation; curated RSS | Bài nghiên cứu và tin chuyên ngành theo keywords môn học |
| Import / export | CSV local; Google Sheets API nếu cấp quyền | Liên hệ luồng Lab 1 |
| QR | `qr_flutter` để tạo; `mobile_scanner` để quét | Generate/scanner Flutter |
| Charts | `fl_chart` hoặc Flutter chart package stable tương đương | Analytics, poll results |
| HTTP | `dio` hoặc `http`, tùy repo | Request từ Cloud Function tới API; không lộ private API key ở Flutter |
| Local settings | `shared_preferences` | Theme, preference (không lưu role/token bí mật) |

**Giải thích:** Google Sheets là phương tiện nhập/xuất, không phải database authoritative vì không phù hợp cho xác thực QR và các update quiz thời gian thực. Cloud Functions có thể cần bật **Blaze/pay-as-you-go**, phải kiểm tra pricing/budget alerts trước deploy. Nếu chưa có billing, sử dụng Firebase Emulator Suite để chạy và test server logic; không chuyển thao tác bảo mật sang client rồi xem đó là production-ready.

## 2.2. Monorepo target (thích nghi theo repo hiện có)

```text
repo/
├── apps/
│   └── fap_smart_lecturer_mobile/
│       ├── lib/
│       │   ├── app/                       # bootstrap, router, theme, localization
│       │   │   ├── router/
│       │   │   └── theme/                 # app_theme, color_tokens, typography, spacing
│       │   ├── core/                      # errors, date, result, validators, firebase, widgets
│       │   │   └── ui/                    # UiCard, AppButton, StatusBadge, EmptyState...
│       │   ├── features/
│       │   │   ├── auth/
│       │   │   ├── dashboard/
│       │   │   ├── classes/
│       │   │   ├── attendance/
│       │   │   ├── analytics/
│       │   │   ├── news/
│       │   │   └── quiz/
│       │   ├── shared_models/
│       │   ├── firebase_options.dart     # generated; do not manually invent
│       │   └── main.dart
│       ├── assets/
│       ├── test/
│       └── integration_test/
├── functions/                              # TypeScript Cloud Functions
│   ├── src/
│   │   ├── auth/
│   │   ├── attendance/
│   │   ├── quiz/
│   │   ├── articles/
│   │   ├── sheets/
│   │   ├── shared/
│   │   └── index.ts
│   └── test/
├── firebase/
│   ├── firestore.rules
│   ├── firestore.indexes.json
│   └── storage.rules                    # chỉ nếu dùng storage
├── scripts/                                # seed/import/migration/test helpers
├── docs/
│   ├── IMPLEMENTATION_PROGRESS.md
│   ├── SETUP.md
│   ├── ARCHITECTURE.md
│   ├── DATA_DICTIONARY.md
│   └── TEST_REPORT.md
└── README.md
```

**Architecture per feature:** `presentation/`, `application/` (providers/controllers), `domain/` (models, interfaces, rules), `data/` (Firebase/API repositories). Được phép rút gọn thư mục nếu app nhỏ nhưng luôn tách presentation khỏi data access. **Không tạo 4 kiến trúc khác nhau cho 4 module.**

## 2.3. Nguyên tắc tái sử dụng Lab 1

1. Kiểm tra tên lớp/môn/MSSV, file Excel/Google Sheets, mô hình điểm danh của Lab 1.
2. Dùng cùng `studentId`, `classCode`, `subjectCode` hoặc cung cấp migration mapping rõ ràng.
3. Nếu Desktop chưa có backend chung, **không tự hứa đồng bộ 2 chiều tức thời**. Lab 2 dùng Firebase làm source of truth; Lab 1 kết nối qua import/export trước.
4. Document mapping giữa dữ liệu Desktop và Firestore; tránh hai hệ thống ghi vào cùng sheet mà không có cơ chế conflict.
5. Không làm ảnh hưởng build Desktop hiện tại; thay đổi shared code phải có tests.

---

# 3. AUTH, PROFILE, SUBJECTS, CLASSES — FOUNDATION

## 3.1. Functional requirements

- `AUTH-01` Login/Logout; Splash kiểm tra auth state; session persistence.
- `AUTH-02` Google Sign-In nếu thuộc phương thức định danh được trường hỗ trợ; email/password demo để chạy Lab khi không có OAuth setup. Không dùng email suffix để tự phong `lecturer`.
- `AUTH-03` App đọc authoritative role từ server/claims. Unknown/not-approved account hiển thị **“Tài khoản chưa được phân quyền”** và không vào màn hình nội bộ.
- `AUTH-04` Lecturer chỉ thấy lớp được phân công; Student chỉ thấy lớp đã được ghi danh.
- `CLS-01` Subject: `code`, `name`, `description`, `keywords`, `academicTerm` optional.
- `CLS-02` Class: `classCode`, `subjectId`, `term`, `lecturerUids[]`, `studentCount`, `status`.
- `CLS-03` Enrollment có UID + MSSV unique per class; thao tác import validation, báo duplicate và row-level errors.
- `CLS-04` Lecturer xem upcoming/past session theo lớp; demo có thể tạo buổi mới thủ công; không cần FAP timetable API.

## 3.2. Phân quyền tối thiểu

| Action | Lecturer (được gán lớp) | Student (enrolled) | Unrelated / unauthenticated |
|---|---|---|---|
| Xem thông tin lớp | Yes | Yes (redacted nếu cần) | No |
| Xem toàn bộ attendance | Yes | No | No |
| Xem attendance của chính mình | Không mặc định | Yes | No |
| Tạo/mở/đóng QR session | Yes | No | No |
| Submit QR attendance | No | Yes | No |
| Xem News theo môn | Yes | Yes nếu đang học | No |
| Share article vào lớp | Yes | No | No |
| Tạo/mở/đóng quiz | Yes | No | No |
| Submit quiz/poll | No | Yes | No |
| Xem toàn bộ quiz submissions | Yes | No | No |
| Xem kết quả quiz của chính mình | No | Yes, theo reveal policy | No |

**Rule:** Ẩn button trong UI không thay thế Security Rules hoặc server checks.

---

# 4. MODULE 1 — SMART QR ATTENDANCE

## 4.1. Goal

Giảng viên tổ chức điểm danh ngay tại lớp qua QR động; sinh viên quét bằng Mobile; kết quả hiển thị live và được đóng phiên có kiểm toán.

## 4.2. Lecturer flow

1. Vào **Lớp học → chọn lớp → Buổi học → Bắt đầu điểm danh**.
2. System đảm bảo lớp thuộc giảng viên; phiên thuộc buổi học; không có **hai phiên attendance đang mở cho cùng một buổi**.
3. Giảng viên chọn thời gian điểm danh (mặc định **10 phút**, cấu hình 5–30 phút), ngưỡng đi muộn (mặc định 5 phút sau mở phiên, điều chỉnh được).
4. Server tạo `attendanceSession`, set `status=open`, `opensAt`, `closesAt`, `qrRotationSeconds=120`.
5. Flutter lecturer hiển thị QR token **signed, limited lifetime** và countdown; mỗi ~120 giây lấy token mới từ callable backend, hoặc sau khi token hiện tại hết hạn. Có thể manual refresh nếu network issue.
6. Danh sách student check-in update real-time theo Firestore stream, có counters `present`, `late`, `notYetCheckedIn`.
7. Giảng viên chọn **Kết thúc điểm danh**; server chuyển sang `closed`, không nhận check-in; finalize các student eligible chưa check-in thành `absent` (có thể tính implicit rồi materialize bằng batch/server job).
8. Cho phép giảng viên sửa thủ công `present/late/absent/excused` với lý do bắt buộc và `attendanceAudit` (P1, nhưng nếu cho sửa UI thì phải audit đầy đủ).

## 4.3. Student flow

1. Đăng nhập → **Điểm danh → Quét QR** → cấp quyền camera.
2. Quét QR, gửi `checkInWithQr({token})` đến callable Function (không ghi attendance trực tiếp).
3. Backend dùng authenticated UID, xác thực chữ ký/phiên/đúng lớp/thời gian, rồi transaction ghi record duy nhất.
4. Hiển thị thành công `Có mặt` hoặc `Đi muộn`, tên lớp/buổi và giờ server.
5. Khi token hết hạn/không hợp lệ/khác lớp/điểm danh rồi/phiên đã đóng phải có thông báo cụ thể tiếng Việt.

## 4.4. Security & QR implementation

- Token QR **không chứa PII hoặc attendance status**; payload tối thiểu gồm `sessionId`, `slotId`, `sessionVersion` và `expiresAt`, có HMAC/signature được tạo ở trusted backend với secret lưu trong Secret Manager.
- Không đặt signing key, service account, Firebase Admin SDK trong Flutter.
- `getQrToken({sessionId})` chỉ lecturer của lớp và chỉ khi session mở gọi được.
- `checkInWithQr({token})` chỉ student đã enrolled gọi được; server xác thực signature, slot, expiry bằng server time, status open, `closesAt`, `sessionVersion` và quyền membership.
- Refresh token sau mỗi 120 giây. Nếu hết hạn mà network mất, giảng viên thấy lỗi “Không thể làm mới QR, vui lòng thử lại”, **không** dùng mã cũ như còn hiệu lực.
- Anti-duplicate: deterministic document ID `attendanceRecords/{sessionId}_{studentUid}`, transaction tạo duy nhất; nếu record tồn tại trả về `ALREADY_CHECKED_IN`, không tính hai lượt.
- Check-in timeout: nếu client không nhận response, truy vấn server record trước khi cho retry; retry vẫn idempotent.
- Client clock **không có quyền** quyết định token còn hạn hay status late; dùng server time.
- Chống spam: callable rate-limit logic (per UID/session), optional App Check; không tin device ID.
- QR xoay vòng **chỉ giảm chia sẻ mã**, không chứng minh sinh viên đang ở phòng học. Không tuyên bố chống gian lận tuyệt đối. Geolocation/selfie/Wi-Fi có vấn đề quyền riêng tư, không thêm vào P0.
- Không cho student ghi, cập nhật, xóa `attendanceRecords` trực tiếp qua Firestore client. Cho read của record cá nhân theo Rules.

## 4.5. Attendance state machine

```text
SESSION: scheduled -> open -> closed -> finalized
                     \-> cancelled (nếu chưa finalized; audit)
RECORD: (none) -> present | late
        (none) -> absent on finalize
        any finalized status -> corrected status (lecturer, reason, audit)
```

- `present`: check-in đúng giờ; `late`: check-in sau `lateThresholdAt` và trước `closesAt`.
- `absent`: không check-in khi phiên đã finalized.
- `excused`: vắng có phép, do lecturer cập nhật với reason; không tự suy diễn từ không check-in.
- `cancelled`: phiên bị hủy không tính vào thống kê chuyên cần.
- Student enrolled sau khi buổi học kết thúc không bị tính vắng retroactively; dùng snapshot/eligibility hoặc enrollment date.

## 4.6. Acceptance criteria

- [ ] Giảng viên A không thể mở session lớp của giảng viên B.
- [ ] Student ngoài lớp bị từ chối kể cả có QR hợp lệ.
- [ ] QR hết hạn, QR bị sửa payload, phiên đóng, session khác, forged token đều bị từ chối.
- [ ] Quét cùng QR 2 lần không tăng present count; concurrent submits chỉ tạo 1 record.
- [ ] Server set check-in timestamp; refresh QR không làm mất attendance đã ghi.
- [ ] Kết thúc phiên không gây trùng record, kể cả retry finalize.
- [ ] Không có internet → show lỗi/retry; không hiển thị điểm danh thành công ảo.

---

# 5. MODULE 2 — ATTENDANCE ANALYTICS

## 5.1. Lecturer views

- `ANA-01` Overview lớp: tổng số buổi đã hoàn tất, tổng sinh viên, tỷ lệ chuyên cần, số sinh viên cần theo dõi.
- `ANA-02` Attendance breakdown theo buổi: `present`, `late`, `absent`, `excused`; stacked bar hoặc grouped bar.
- `ANA-03` Student list sortable/filterable theo vắng nhiều, tên/MSSV, tỷ lệ điểm danh.
- `ANA-04` Student detail: các buổi, timestamp, status và lịch sử sửa (nếu P1).
- `ANA-05` Filter `class`, `subject`, `date range`, `status`; default lớp hiện tại + kỳ học.
- `ANA-06` CSV export đúng schema, Unicode UTF-8, escape CSV injection (`=`, `+`, `-`, `@` ở các giá trị đầu ô phải được xử lý an toàn theo định dạng export).

## 5.2. Student views

- Xem điểm danh của bản thân theo lớp/môn, tổng số buổi và danh sách từng buổi; không thấy thông tin điểm danh của sinh viên khác.
- Hiển thị trạng thái record rõ ràng: Có mặt / Đi muộn / Vắng / Có phép / Chưa chốt.

## 5.3. Formula & invariant

**Chỉ tính các attendance sessions `finalized` và eligible cho sinh viên** (không tính session mở/cancelled/diễn ra trước khi enrolled).

```text
eligibleCount = finalizedEligibleSessions - excusedSessions
attendedCount = presentSessions + lateSessions
attendanceRate = eligibleCount > 0 ? attendedCount / eligibleCount * 100 : N/A
absentCount = eligibleCount - attendedCount
```

- `late` vẫn được tính là có tham dự; biểu đồ vẫn tách `late` để giảng viên nhận biết.
- `excused` không tính trong mẫu số tỷ lệ chuyên cần (quy tắc **đề xuất cho Lab**, không coi đây là chính sách chính thức FPT; để cấu hình nếu giảng viên yêu cầu).
- `at-risk` default demo khi `attendanceRate < 80%` với ít nhất 3 buổi eligible, cấu hình được; label “Cần theo dõi”, **không** tự kết luận đủ điều kiện cấm thi.
- Nếu chưa đủ dữ liệu: hiển thị `Chưa đủ dữ liệu`, không trả 0% gây hiểu lầm.
- Server recompute hoặc update aggregates khi sửa bản ghi; chart không được giữ số liệu cũ.
- Dùng aggregate server/cache có reconciliation hoặc query theo lớp cho demo nhỏ; document rõ trade-offs, tránh client load toàn bộ database.

## 5.4. Visual requirements

- KPI cards: **Buổi đã học**, **Tỷ lệ chuyên cần**, **Vắng hôm nay**, **Cần theo dõi**.
- Bar chart theo buổi, tap cột để drill-down; donut chart hiện diện/vắng nếu phù hợp; không dùng 3D chart.
- Status chip màu + icon + chữ: luôn có label, tránh chỉ dựa màu.
- Empty/skeleton/loading/error và retry đầy đủ.
- Dashboard / charts mobile tối ưu viewport 360–430 logical px, không scroll ngang toàn trang.

## 5.5. Acceptance criteria

- [ ] Analytics khớp records nguồn sau finalize.
- [ ] Session cancelled không đi vào denominator.
- [ ] `excused` không bị tính thành `absent` ở KPI.
- [ ] Sửa điểm danh gây refresh số liệu sau sync.
- [ ] Student chỉ thấy record của mình.
- [ ] CSV export tiếng Việt/MSSV đúng, mở trong Excel không lỗi cột.

---

# 6. MODULE 3 — SUBJECT NEWS & RESEARCH HUB

## 6.1. Goal

Giảng viên cập nhật các bài báo khoa học, công nghệ mới và kiến thức liên quan tới môn học. Student có thể đọc nội dung được chia sẻ trong lớp. **Không cần AI để tạo gợi ý P0.**

## 6.2. Main features

- `NEWS-01` Subject keywords: mỗi môn có `keywords[]` và `searchSynonyms[]`. Ví dụ:
  - `PRM393` → `Flutter`, `Dart`, `Mobile application development`, `Android`, `iOS`.
  - `PRN212` → `ASP.NET Core`, `C#`, `.NET`, `Entity Framework`.
  - `SWE201c` → `Software architecture`, `Agile`, `DevOps`, `Software testing`.
  - **Đây là seed demo**, không xác nhận chương trình học chính thức của trường.
- `NEWS-02` Chọn một môn đang dạy → feed bài báo theo từ khóa môn.
- `NEWS-03` Search keyword, filter nguồn (OpenAlex/Crossref/curated RSS), lọc thời gian, sort mới nhất hoặc liên quan.
- `NEWS-04` Article card có title, source, authors (nếu có), publishedAt, short summary/abstract snippet (nếu được phép), category/keywords, DOI/link.
- `NEWS-05` Article detail: metadata và mở trang nguồn bằng external browser; không scrape/full-copy nội dung có bản quyền.
- `NEWS-06` Lecturer chọn **Chia sẻ cho lớp** và optional note; Student trong lớp xem các bài được chia sẻ theo ngày.
- `NEWS-07` Chống duplicate theo normalized DOI trước, fallback canonical URL/source ID. Không hiện bài thiếu title và URL.

## 6.3. External API strategy

**Primary — OpenAlex Works API:**
- `https://api.openalex.org/works` với `search`, `filter=from_publication_date:...`, `per_page`, sort có hỗ trợ phù hợp.
- OpenAlex có cơ chế API key/quota/usage theo chính sách hiện hành: **kiểm tra lại docs trước deploy**, không mặc định mọi request không giới hạn.

**Secondary — Crossref REST API:**
- `https://api.crossref.org/works` metadata scholarly; dùng `mailto` polite pool nếu phù hợp; tôn trọng response 429/backoff.

**Optional — Curated RSS:**
- Danh sách RSS hợp pháp, có kiểm chứng, dành cho tin công nghệ nhanh (ví dụ blog kỹ thuật chính thống). Chỉ lưu title, excerpt ngắn, ngày, publisher và URL.

**Integration rules:**
- Đặt adapters ở trusted Function nếu cần API key, server-side caching hoặc RSS parse. Không gọi public APIs mỗi lần scroll mà không cache.
- Cache results trong Firestore (`articleCache`) trong ~6 giờ (configurable), có pagination, debounce search, throttle, timeout và exponential backoff.
- Nếu API lỗi: hiển thị dữ liệu cache (kèm “Cập nhật lần cuối”) hoặc trạng thái không tải được; không sinh bài viết giả.
- Nếu bài không có abstract, hiển thị “Chưa có tóm tắt”. Không bắt buộc AI summarization.
- Metadata từ publisher/API chỉ dùng làm data; sanitize URL và text, không chạy script/external HTML trong WebView.
- Phải hiển thị nguồn rõ ràng và chuyển tới URL publisher/DOI.

## 6.4. Share flow

Lecturer → article detail → `Share to class` → select one of assigned classes of same subject (hoặc cho chọn lớp theo policy) → optional note → server validate rights → create sharedArticle record → students thấy trong Class Resources.

## 6.5. Acceptance criteria

- [ ] Mỗi môn hiện feed khác nhau theo keywords; có ít nhất 2 môn seed.
- [ ] Bài có title, source, date (nếu cung cấp), link thật.
- [ ] No duplicate DOI/article across same search feed.
- [ ] Nếu nguồn bên thứ ba timeout, UI không crash và có retry/cached results.
- [ ] Chỉ lecturer của lớp share được; Student đọc shares thuộc lớp mình.
- [ ] Không lưu/copy toàn văn article có bản quyền.

---

# 7. MODULE 4 — LIVE QUIZ & CLASSROOM POLL

## 7.1. MVP scope

- **Single-choice quiz:** 1 câu hỏi, 2–5 lựa chọn, 1 đáp án đúng; tính đúng/sai sau khi quiz đóng hoặc theo reveal policy.
- **Classroom poll:** 1 câu hỏi, 2–5 lựa chọn, không có đáp án đúng; tổng hợp % lựa chọn.
- Giới hạn **một response / sinh viên / activity** trong P0. Không làm multi-question test bank, timer theo từng câu, leaderboard/gamification P0.

## 7.2. Lecturer flow

1. Chọn lớp → **Tương tác → Tạo hoạt động** → Quiz hoặc Poll.
2. Nhập câu hỏi; các đáp án 2–5; nếu Quiz, chọn đáp án đúng (private server-only); optional thời lượng (mặc định 3 phút, 1–15 phút).
3. Publish → status `scheduled` / `open`. Hiển thị live code (6–8 ký tự ngẫu nhiên unique đủ an toàn) hoặc activity xuất hiện ở lớp đang học.
4. Theo dõi `respondedCount`, chart từng phương án real-time (nếu class size nhỏ, có thể từ summary document).
5. Đóng hoạt động khi hết giờ hoặc thủ công; server chấm Quiz và cho lecturer xem kết quả; student xem kết quả theo reveal policy.

## 7.3. Student flow

- Vào **Hoạt động → quiz đang mở của lớp** (hoặc nhập join code), đọc câu hỏi và chọn 1 option.
- Confirm **Gửi câu trả lời**; server validate auth, enrollment, open status, deadline, option thuộc tập lựa chọn, anti duplicate.
- Nhận kết quả đã ghi hoặc `ALREADY_SUBMITTED`. Khi chưa đến lúc reveal, chỉ thông báo “Đã gửi câu trả lời”, **không tiết lộ đáp án đúng**.

## 7.4. Security & anti-cheat

- `correctOptionId` chỉ ở `quizPrivate/{quizId}` hoặc server-only backend store, **không** trong document đọc bởi Student.
- Student chỉ có thể đọc quiz công khai thuộc lớp mình, đọc response của mình và tạo submission **qua callable** `submitQuiz`.
- Không cho student tự ghi `isCorrect`, `score`, `submittedAt`, `choiceCounts` hoặc sửa response.
- Unique ID `quizResponses/{quizId}_{studentUid}`. Server transaction check duplicate; time lấy từ server.
- Quiz `scheduled -> open -> closed -> published` (hoặc `closed` với `revealAt`); không thể submit khi đóng.
- `joinCode` không thay thế đăng nhập/membership; người ngoài lớp không được tham gia dù biết code.
- Nếu share source article cho quiz, lưu article link metadata; không rò rỉ answer bằng client payload.
- Lecturer phải có quyền lớp tại thời điểm tạo và đóng quiz; không auto grant qua UID gửi từ client.
- Handling server retries and concurrent submissions idempotent.

## 7.5. Result visuals

- Live responses count `28/35`.
- Horizontal bar chart các option; hiển thị cả số lượng và %; tổng hợp từ server-authoritative responses.
- Quiz: sau khi reveal, highlight đáp án đúng + accuracy %, số người tham gia.
- Poll: chỉ hiển thị phân phối; không có đúng/sai.
- Nếu 0 response, báo `Chưa có phản hồi` thay vì chia cho 0.

## 7.6. Acceptance criteria

- [ ] Lecturer A không tạo quiz lớp B.
- [ ] Student ngoài lớp không tham gia được dù có join code.
- [ ] Không thể gửi 2 lần, kể cả double-tap, retry và concurrent submit.
- [ ] Hết hạn → reject, không ghi kết quả.
- [ ] Student không truy cập `correctOptionId` trước reveal, cả qua Firestore queries.
- [ ] Response count/chart khớp server; offline không hiện submit thành công giả.
- [ ] Quiz & Poll dùng chung components nhưng tách rule chấm điểm.

---

# 8. FIRESTORE DATA MODEL — PROPOSED

> Codex được phép tối ưu schema để giảm reads nhưng phải bảo toàn semantics, security và cập nhật `docs/DATA_DICTIONARY.md`. `createdAt`, `updatedAt` nên dùng server timestamps; `uid` là Firebase Auth UID, `studentCode` là MSSV; không trộn hai khái niệm.

```text
users/{uid}
  uid, displayName, email, role: lecturer|student,
  studentCode?, lecturerCode?, photoUrl?, active, createdAt, updatedAt

subjects/{subjectId}
  code, name, description, keywords[], searchSynonyms[], active

classes/{classId}
  classCode, subjectId, term, lecturerUids[], startDate?, endDate?,
  studentCount, status: active|archived, createdAt

classes/{classId}/members/{studentUid}
  studentUid, studentCode, displayName, enrolledAt, active

users/{studentUid}/enrollments/{classId}   # optional read optimization, server-managed
  classId, enrolledAt, active

classSessions/{sessionId}
  classId, subjectId, lecturerUid, title?, startsAt, endsAt,
  status: scheduled|completed|cancelled, createdAt

attendanceSessions/{attendanceSessionId}
  classSessionId, classId, createdBy, status: scheduled|open|closed|finalized|cancelled,
  opensAt, closesAt, lateThresholdAt, qrRotationSeconds: 120,
  sessionVersion, finalizedAt?, eligibleStudentUids? OR membershipSnapshotRef?

attendanceRecords/{attendanceSessionId}_{studentUid}
  attendanceSessionId, classId, classSessionId, studentUid,
  status: present|late|absent|excused,
  checkedInAt?, recordedAt, recordedBy: qr|lecturer|system, updatedAt

attendanceAudit/{auditId}
  attendanceRecordId, fromStatus, toStatus, reason, changedBy, changedAt

articleCache/{articleId}   # ID from normalized DOI or canonical sourceId/URL
  doi?, title, authors[], publisher, source, publishedAt?,
  abstractSnippet?, url, topicKeywords[], fetchedAt, expiresAt

sharedArticles/{shareId}
  classId, subjectId, articleId, sharedBy, note?, sharedAt

quizzes/{quizId}
  classId, subjectId, classSessionId?, type: quiz|poll,
  question, options: [{id, text}], createdBy,
  status: scheduled|open|closed|published,
  opensAt, closesAt, revealPolicy, joinCode?, createdAt

quizPrivate/{quizId}              # Backend only; never client readable
  correctOptionId?                # absent for poll

quizResponses/{quizId}_{studentUid}
  quizId, classId, studentUid, selectedOptionId, submittedAt,
  isCorrect?                       # server-only, only for quiz

quizStats/{quizId}
  totalResponses, optionCounts: {optionId: count}, updatedAt,
  correctCount?                    # server-managed summary
```

## 8.1. Indexes

Start from actual queried screens; expect composite indexes for:

- `classSessions`: `classId ASC, startsAt DESC`
- `attendanceSessions`: `classId ASC, opensAt DESC` / `classSessionId ASC, status ASC`
- `attendanceRecords`: `classId ASC, attendanceSessionId ASC` (or single equality queries)
- `sharedArticles`: `classId ASC, sharedAt DESC`
- `quizzes`: `classId ASC, status ASC, closesAt DESC`
- `articleCache`: indexes on `topicKeywords` and `publishedAt` as dictated by query design.

Do not blindly create huge unnecessary indexes; configure from actual Firestore error links and tests. Arrays/maps have index costs.

## 8.2. Security Rules design (requirements; implement actual rules + emulator tests)

1. `deny by default`; unauthenticated gets nothing sensitive.
2. Role from immutable trusted claims or server-managed role doc; client cannot self-upgrade `role`/`active`.
3. Lecturer reads only classes assigned to that UID and attendance/quiz records for those classes.
4. Student reads only own user/profile and enrolled classes; own attendance and quiz response; permitted public quiz/article metadata.
5. `attendanceRecords`, `attendanceAudit`, `quizPrivate`, `quizResponses`, `quizStats` writes **server-only** (all client writes denied unless explicitly granted for non-sensitive fields, ideally none).
6. `sharedArticles`, `classSessions`, `quizzes` create/update through callable functions or restrictive rules with class ownership checks; do not trust client-supplied `classId` alone.
7. `users/*` profile update must whitelist allowed fields; prohibit role edits.
8. All raw external API keys/secrets only server side.
9. Design collection layout to support Rules efficient lookups (`exists()` membership doc); do not implement client-side filtering as an authorization control.
10. Use emulator tests for positive and negative rights; test unrelated lecturer, student, anonymous, disabled user.

**Note:** Firebase Admin SDK/Cloud Functions bypass Firestore client Security Rules; EACH privileged Function MUST enforce its own authorization and data validation.

---

# 9. CALLABLE API CONTRACTS & ERRORS

Implement server functions (can adapt signatures if repo structure requires). Requests must be validated with schemas, authenticated context and centralized error mapping; response JSON must be stable.

| Callable / secured endpoint | Actor | Request | Response |
|---|---|---|---|
| `openAttendanceSession` | lecturer | `{classSessionId, durationMinutes, lateAfterMinutes}` | `{attendanceSessionId, opensAt, closesAt}` |
| `getQrToken` | lecturer | `{attendanceSessionId}` | `{token, expiresAt, rotationSeconds}` |
| `checkInWithQr` | student | `{token}` | `{attendanceSessionId, status, checkedInAt}` |
| `closeAttendanceSession` | lecturer | `{attendanceSessionId}` | `{status: closed|finalized, summary}` |
| `correctAttendance` (P1) | lecturer | `{recordId, status, reason}` | `{record, auditId}` |
| `createQuiz` | lecturer | `{classId, type, question, options, correctOptionId?, durationSeconds}` | `{quizId}` |
| `openQuiz` | lecturer | `{quizId}` | `{status, closesAt}` |
| `submitQuiz` | student | `{quizId, selectedOptionId}` | `{accepted, submittedAt}` |
| `closeQuiz` | lecturer | `{quizId}` | `{status, summary}` |
| `discoverArticles` | lecturer/student | `{subjectId, query?, source?, dateRange?, cursor?}` | `{articles[], nextCursor?, fetchedAt, cached}` |
| `shareArticle` | lecturer | `{classId, articleId, note?}` | `{shareId}` |
| `importClassRoster` (optional) | operator/trusted | validated CSV/sheet ref | `{added, updated, skipped, errors[]}` |
| `exportAttendanceCsv` (can be client exporter from authorized query) | lecturer | `{classId, dateRange?}` | CSV share/download (not necessarily a Cloud Function) |

**Error taxonomy** (map to localized UX):

- `UNAUTHENTICATED` → Vui lòng đăng nhập.
- `PERMISSION_DENIED` → Bạn không có quyền thao tác với lớp này.
- `NOT_ENROLLED` → Bạn chưa được ghi danh vào lớp.
- `QR_EXPIRED` → Mã QR đã hết hạn. Hãy quét mã mới.
- `QR_INVALID` → Mã QR không hợp lệ.
- `SESSION_CLOSED` → Phiên điểm danh đã kết thúc.
- `ALREADY_CHECKED_IN` → Bạn đã điểm danh buổi này.
- `ALREADY_SUBMITTED` → Bạn đã gửi câu trả lời.
- `QUIZ_CLOSED` → Hoạt động đã đóng.
- `RATE_LIMITED` → Thao tác quá nhanh. Vui lòng thử lại sau.
- `NETWORK_ERROR` → Không thể kết nối. Vui lòng kiểm tra mạng.
- `ARTICLE_SOURCE_UNAVAILABLE` → Chưa thể tải bài viết từ nguồn này.

**No silent failure**, no generic “Something went wrong” for known cases.

---

# 10. GOOGLE SHEETS, CSV & LAB 1 COMPATIBILITY

## 10.1. CSV first — mandatory

**Import:** Chấp nhận bảng danh sách với ít nhất `classCode`, `studentCode`, `fullName`, `email?`; preview + validation duplicate/error per-row. Chưa có Auth UID thì giữ trạng thái pending mapping bằng email/MSSV; operator resolve UID sau khi student đăng nhập.

**Export:** Dạng normalized rows:

```csv
classCode,subjectCode,sessionDate,studentCode,studentName,status,checkedInAt,notes
SE1928,PRM393,2026-10-08,SE000001,Nguyen Van A,present,2026-10-08T02:14:22Z,
```

- UTF-8 BOM nếu Excel Windows cần; normalize CRLF; proper CSV quoting/escaping.
- Bảo vệ CSV formula injection; cấu hình local Vietnamese date output nếu file theo định dạng FAP Lab 1 yêu cầu.
- Không dùng dữ liệu mẫu làm real class roster.

## 10.2. Sheets API — optional enhancement

- Có thể import sheet cố định của giảng viên và export/append một báo cáo bằng server-side integration.
- Không đặt service account credential trong mobile. Dùng service account được share đúng spreadsheet hoặc OAuth consent phù hợp trên trusted backend.
- Batch requests; exponential backoff theo 429; show sync status/lastSyncedAt; tránh overwrite sheet người dùng không chủ ý.
- Chỉ sync khi user explicit bấm; idempotency key theo `classId + reportRange + revision` để tránh ghi trùng.
- Ưu tiên **one-way sync + conflict resolution rõ ràng**, không mặc định vừa Sheets vừa Firestore đều là source of truth.

---

# 11. DESIGN SYSTEM — **FPT CAMPUS ORANGE & WHITE** (BẮT BUỘC ĐỒNG BỘ)

## 11.1. Style direction — FPT Campus Orange

**Style name:** `FPT Campus Orange — Clean Academic Mobile`  
**Foundation:** Flutter Material 3 (M3), giao diện **cam–trắng đặc trưng FPT**, typography hiện đại, tối ưu đọc dữ liệu chuyên cần.  
**Keywords:** fresh, academic, energetic, simple, professional, practical, accessible.  
**Hệ phân cấp màu:** cam thương hiệu + các sắc độ cam cho thao tác; trắng cho card/nền chính; màu mực nâu-đen cho văn bản; xám ấm cho divider. Xanh lá/đỏ/vàng/xanh dương chỉ dùng để biểu thị **trạng thái có ý nghĩa** (có mặt/vắng/cảnh báo/thông tin), tuyệt đối KHÔNG trở thành màu chủ đạo của một module.

**Brand reference:** Sổ tay thương hiệu FPT 2023 (mục màu sắc logo) quy định **FPT Orange `#F37021`** và **FPT White `#FFFFFF`**. Trong app, chọn các sắc độ cam tối/sáng tự thiết kế để đảm bảo tương phản. Đây là **bộ giao diện lấy cảm hứng FPT**, không phải tuyên bố app chính thức của FPT/FAP; không dùng logo/biểu trưng chính thức hoặc tài sản nhận diện có bản quyền nếu chưa được cho phép. Nguồn: https://fpt.com/-/media/project/fpt-corporation/fpt/common/fpt/file/stth-fpt_20230929.pdf (FPT Brand Manual v3.0, 04/10/2023, trang 14).

**Do:** nền trắng thoáng, header/app bar đơn giản, CTA cam nổi bật, card trắng, icon line đồng bộ Material Symbols, dashboard chính xác, chart tiết chế, hoạt ảnh nhỏ có mục đích.

**Don't:** đổi sang navy/teal làm primary, neon, gradient cam toàn màn hình, nhiều banner cam dày đặc, glassmorphism, shadow nặng, icon 3D, card mỗi trang một màu, hardcode màu trong từng màn hình, white-on-bright-orange cho chữ body.

**Tỷ lệ thị giác gợi ý (không phải business rule):** khoảng **65–75% nền trắng/trắng ấm**, **15–25% cam/kem cam**, **5–10% text, dividers và semantic statuses**. Cam được dùng đủ rõ ở brand/CTA/selected states nhưng tránh gây mỏi mắt khi xem danh sách sinh viên dài.

## 11.2. Color tokens (single source of truth)

| Token | Light | Dark | Usage |
|---|---|---|---|
| `brandOrange` | `#F37021` | `#FFB181` | Cam FPT chính trên light; dark dùng phiên bản sáng dễ nhìn (KHÔNG nhận là mã brand chính thức) |
| `brandWhite` | `#FFFFFF` | `#FFFFFF` | Trắng nhận diện; light cards |
| `primary` / `actionOrange` | `#B54708` | `#FFB181` | Filled CTA, selected icons, active indicator; light cam đậm để **chữ trắng** có đủ contrast |
| `onPrimary` | `#FFFFFF` | `#24150D` | Foreground trên `primary` |
| `primaryContainer` | `#FFE7D5` | `#543020` | Chip/filter/selected tile nền cam nhạt |
| `onPrimaryContainer` | `#7C2E05` | `#FFE3D0` | Text/icon trên chip nền cam nhạt |
| `secondary` | `#8C3D18` | `#F9C7A8` | Tông cam đất bổ trợ; KHÔNG dùng xanh teal làm secondary |
| `tertiary` | `#A95A2B` | `#EFB18A` | Đường biểu đồ/gợi ý cấp 3, vẫn thuộc họ cam |
| `background` / `scaffold` | `#FFF9F5` | `#15110F` | Nền app nhẹ, ấm |
| `surface` / `surfaceCard` | `#FFFFFF` | `#241B16` | Cards, sheets, dialog |
| `surfaceMuted` | `#FFF1E8` | `#33251E` | Search, tiles, soft callout |
| `textPrimary` / `onSurface` | `#281C16` | `#FFF7F2` | Main body/headline |
| `textSecondary` | `#68554B` | `#D0BBAF` | Secondary metadata |
| `border` / `outline` | `#EAD8CC` | `#574239` | Outlines, dividers |
| `success` | `#15803D` | `#74D89A` | Đã điểm danh / đã nộp |
| `warning` | `#98600B` | `#FFD27A` | Đi muộn / rủi ro |
| `error` | `#B42318` | `#FF8E85` | Vắng / lỗi |
| `info` | `#0F6B93` | `#8ED8F3` | Thông tin chức năng/đang xử lý |

**Bất biến UI:** FPT orange `#F37021` phải xuất hiện nhất quán trong nhận diện (logo text mark tự xây, hero, active accents), còn **nút chứa chữ trắng** dùng `#B54708` ở light. Không sử dụng `Colors.white` cho chữ nhỏ trên `#F37021`: theo tính toán tương phản, cặp đó chỉ khoảng **2.94:1**; dùng text `#23160E` trên cam sáng (khoảng **6.0:1**) hoặc nền nút cam đậm với chữ trắng (khoảng **5.43:1**). Mục tiêu **WCAG AA**: chữ thường >= 4.5:1, chữ lớn >= 3:1, kiểm thử riêng light/dark và disabled/focus/error states.

**Semantics (không lạm dụng cam làm status):**
- `present`: xanh lá + `check_circle_outline` + “Có mặt”.
- `late`: vàng nâu + `schedule` + “Đi muộn”.
- `absent`: đỏ + `cancel_outlined` + “Vắng”.
- `excused`: xanh thông tin + `verified_outlined` + “Có phép”.
- `pending`: xám ấm + `hourglass_empty` + “Chưa chốt”.
- `quiz`: icon `quiz_outlined`/`poll_outlined` màu cam; `news`: icon `article_outlined` màu cam; **đều chung primary, phân biệt bằng icon và label**, không chia mỗi module một theme màu riêng.
- Analytics: series chủ đạo cam (`primary`), semantic colors cho dữ liệu có mặt/vắng/muộn; legend có chữ + con số, không chỉ màu.

## 11.3. Typography

- Font giao diện: **Inter** có hỗ trợ tiếng Việt; fallback system sans-serif. Không tự nhúng font FPT độc quyền hoặc tải file font từ nguồn không có quyền sử dụng.
- Scale trong `TextTheme` (logical sp, tôn trọng accessibility scaling):
  - `headlineMedium`: 28 / 700 (greeting/stat lớn)
  - `titleLarge`: 22 / 700 (screen header)
  - `titleMedium`: 18 / 600 (section header)
  - `titleSmall`: 16 / 600 (cards/list)
  - `bodyLarge`: 16 / 400
  - `bodyMedium`: 14 / 400
  - `labelLarge`: 14 / 600 (button)
  - `labelMedium`: 12 / 500 (metadata)
- Văn bản chính `textPrimary`; nhãn phụ `textSecondary`; hạn chế chữ cam trên trắng trừ tiêu đề/label đạt contrast.
- Tiếng Việt ngắn, rõ, không cắt sai MSSV/tên lớp; date/time `vi-VN` / Asia/Ho_Chi_Minh.

## 11.4. Layout, shapes & motion

- 8-point grid: spacing `4, 8, 12, 16, 24, 32` dp. Screen horizontal padding **16dp** (24dp tablet); card gap 12–16dp.
- Corners: card **16dp**, sheet **24dp**, button **12dp**, chips **999dp**, input **12dp**.
- Cards: **trắng trên nền off-white**, border 1dp `#EAD8CC`, shadow nhẹ/none. Các card chuyên cần không được phủ cam toàn bộ gây khó quét danh sách.
- Button: **solid cam đậm `#B54708` + chữ trắng** cho CTA chính; outlined cam đậm trên nền trắng cho secondary; danger đỏ chỉ cho destructive action thật sự.
- Tap target >=48 × 48dp. Buttons 48–52dp, chips 32–36dp.
- Motion 150–250ms, skeleton fade; honor reduced-motion where possible. Không bỏ thời gian quá nhiều cho splash/animation.
- Responsive: phone 360–430dp, compact <=360dp, tablet >=600dp adaptive grid/rail, không overflow text scale >=1.3–1.5.
- SafeArea, inset, keyboard handling, Android edge-to-edge.
- Charts có legend/totals/description, không dựa chỉ vào màu.

## 11.5. Shared widgets — implement BEFORE feature screens

| Widget | Purpose | Brand/application rules |
|---|---|---|
| `AppScaffold` | Nền, status bar, nav | Background trắng ấm, surfaces trắng; 1 layout system cho mỗi role |
| `AppTopBar` | Back/title/actions/avatar | Trắng, chữ đậm; active action cam; optionally thin orange brand detail |
| `AppPrimaryButton` | CTA chính | Cam đậm + chữ trắng, loading/disabled, >=48dp |
| `AppSecondaryButton` | CTA phụ | Outlined cam đậm trên trắng, same radius |
| `CampusCard` | Shared content surface | Trắng, radius/border/padding từ tokens |
| `KpiCard` | Analytics metrics | Số lớn màu chữ đậm; icon nền cam nhạt; status color chỉ khi có ý nghĩa |
| `ClassCard` | Class overview | White card, small orange course/code tag, quick action |
| `StatusBadge` | Present/late/absent/etc. | Semantic color + icon + text, không dùng cam cho tất cả |
| `ArticleCard` | Subject news | Trắng + thumbnail tùy chọn + orange category chip + nguồn/ngày |
| `QuizOptionTile` | Quiz answer options | Border cam khi selected, filled cam rất nhạt, rõ disabled/error |
| `AppTextField` / `AppSearchField` | Forms | Soft orange focus outline, nhãn đủ tương phản |
| `FilterChipRow` | Search/filters | Selected màu cam nhạt + chữ cam đậm |
| `EmptyState` / `ErrorState` / `LoadingSkeleton` | Async states | Icon cùng một nét, tone màu nhất quán, CTA thật |
| `ConfirmBottomSheet` / `AppSnackbar` | Decisions/feedback | White/neutral surface; destructive red only when appropriate |
| `SectionHeader` | Hierarchy | Main text đậm, link/action cam đậm |

**Single source of truth:** đặt `ThemeData`/`ColorScheme` trong `app/theme/app_theme.dart`; tokens `AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`. Dùng `Theme.of(context).colorScheme` và shared widgets; **CẤM rải hex `#F37021`, `0xFF...` trong feature widgets**. Các màu status có thể đưa vào `ThemeExtension<AppSemanticColors>` nếu dự án đã dùng cấu trúc tương tự.

### Flutter Theme reference (adjust for installed SDK)

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  // FPT-inspired branding; official FPT Orange is #F37021.
  static const brandOrange = Color(0xFFF37021);
  static const brandWhite = Color(0xFFFFFFFF);
  static const actionOrange = Color(0xFFB54708); // AA with white text
  static const warmCanvas = Color(0xFFFFF9F5);
  static const darkCanvas = Color(0xFF15110F);
  static const darkCard = Color(0xFF241B16);
  static const ink = Color(0xFF281C16);
}

ThemeData buildCampusTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brandOrange,
    brightness: brightness,
  ).copyWith(
    primary: dark ? const Color(0xFFFFB181) : AppColors.actionOrange,
    onPrimary: dark ? const Color(0xFF24150D) : Colors.white,
    primaryContainer: dark ? const Color(0xFF543020) : const Color(0xFFFFE7D5),
    onPrimaryContainer: dark ? const Color(0xFFFFE3D0) : const Color(0xFF7C2E05),
    secondary: dark ? const Color(0xFFF9C7A8) : const Color(0xFF8C3D18),
    onSecondary: dark ? const Color(0xFF281C16) : Colors.white,
    tertiary: dark ? const Color(0xFFEFB18A) : const Color(0xFFA95A2B),
    surface: dark ? AppColors.darkCard : Colors.white,
    onSurface: dark ? const Color(0xFFFFF7F2) : AppColors.ink,
    outline: dark ? const Color(0xFF574239) : const Color(0xFFEAD8CC),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: dark ? AppColors.darkCanvas : AppColors.warmCanvas,
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    // Complete shared card, text-field, chip, navigation and snackbar themes.
    // Hero banners can use AppColors.brandOrange with DARK ink foreground;
    // do not use white body text on #F37021.
  );
}
```

**IMPORTANT:** `brandOrange` (`#F37021`) là màu nhận diện hiển thị trong hero/brand accents; `scheme.primary` là **màu action đã làm tối/sáng để bảo đảm contrast**. Đừng hiểu hai token này là mâu thuẫn. Codex phải hoàn thiện light/dark states của navigation, selected chips, input, disabled, focused, errors, cards, snackbars; kiểm tra contrast và touch target, không chỉ paste sample rồi xem như xong.

## 11.6. Navigation architecture

**Lecturer bottom navigation (4 destinations):**

1. **Trang chủ** (`home`): greeting, session hôm nay, lớp đang dạy, quick action mở điểm danh, recent quiz, top news.
2. **Lớp học** (`class`): class list → class detail tabs `Buổi học | Điểm danh | Thống kê | Tài liệu`.
3. **Khám phá** (`article`): feed theo môn, filters, bookmarks optional, detail, share.
4. **Tương tác** (`quiz`): quiz/poll list, create, live monitor, reports.

Profile/settings qua avatar top right; không thêm tab riêng gây 5–6 items rối.

**Student bottom navigation (4 destinations):**

1. **Trang chủ**: lớp hôm nay, check-in status, quiz currently live.
2. **Điểm danh**: scanner, session history cá nhân, permission explanation.
3. **Tài liệu**: bài được share từ lớp và mở link nguồn.
4. **Hoạt động**: open/closed quiz & polls, submit, own results.

Role switch chỉ xuất hiện nếu user thật có **được cấp** nhiều role; P0 dùng 1 role/account.

## 11.7. Screen-by-screen UI contracts

| Screen | Key content | Main action |
|---|---|---|
| Splash/Auth | Logo text, welcome, school email prompt | Login |
| Lecturer Home | Greeting, 3 KPI (classes, session today, risk), today's classes | Open attendance |
| Class List | Search, term filter, ClassCard list | View class |
| Class Detail | Header, subject/code, sessions, members, attendance summary | Open session |
| Attendance Host | Big QR card, countdown, class/session details, live present count | Close session |
| Attendance Results | Status breakdown, student list search, edit if allowed | Export CSV |
| Analytics | 4 KPI cards, chart, filter, at-risk list | Student detail |
| Student Attendance | Own status and histories | Scan QR |
| QR Scanner | Camera frame, flash/permission, instructions | Scan/submit |
| News Feed | Subject selector, search, source/date chips, article cards | Open article |
| Article Detail | Metadata, excerpt, source URL, lecturer share | Share to class |
| Shared Resources | Article list grouped by class/date | Open publisher |
| Quiz List | Open/scheduled/closed activity cards | Create quiz |
| Create Quiz/Poll | Type toggle, question, options, duration, validation | Publish/Open |
| Quiz Live (lecturer) | Countdown, participation, chart | Close activity |
| Quiz Student | Question, option tiles, timer, submit confirm | Submit |
| Quiz Results | Option distribution, correct answer policy, completion | Back |
| Profile/Settings | User, role, theme, terms, logout | Logout |

**Screen behavior checklist EVERY screen:** AppBar state, loading skeleton, empty state, error/retry, scrollable content, keyboard safe, permission denial handling if relevant, localization, no overflow, expected back navigation.

### 11.8. Screen branding & visual acceptance criteria (must implement)

| Screen/group | FPT Orange & White UI contract |
|---|---|
| Splash / Login | Background trắng, FAP Smart Lecturer text mark/cam, CTA cam đậm; không giả logo FPT chính thức |
| Lecturer / Student Home | AppBar trắng, greeting đậm, hero thông tin buổi học viền/nền cam nhạt hoặc hero cam tươi **chữ đậm**; cards trắng |
| Class List / Class Detail | Course tags màu cam nhạt, active tab underline/indicator cam, white cards |
| QR Attendance Host | QR luôn nằm trên **nền trắng tinh** và có quiet zone; orange là CTA/countdown/progress, **không tô nền QR cam** gây giảm khả năng scan |
| QR Scanner | Khung camera đơn giản, outline cam khi quét; kết quả thành công dùng xanh semantic + nhãn |
| Attendance Analytics | Cards trắng, visual highlight cam; pie/bar use distinct semantic colors + legend, không 100% lát cam |
| News Hub | Search/filter cam nhạt, category pill cam, article cards trắng, publisher metadata rõ |
| Live Quiz / Poll | Selected answer cam nhạt + border cam; timer/submit CTA cam đậm; correct/wrong sử dụng semantic color sau khi công bố đáp án |
| Settings | Theme switch, role/account, white list surfaces; không tạo theme riêng |

**UI acceptance tests:**
1. Trên tất cả màn Lecturer/Student: white/off-white surfaces + cùng family cam, cùng typography, same rounded corners/nav/icon language.
2. Snapshot/widget tests cho `AppPrimaryButton`, `CampusCard`, active nav, selected quiz answer, statuses, light/dark.
3. Không có hardcoded navy (`#1E3A5F`) hoặc teal (`#0F766E`) đóng vai `primary`/`secondary`; không tạo palette riêng cho News hoặc Quiz.
4. Kiểm tra contrast trên các trạng thái button, hero, labels và links; tương tác 48dp+, kiểm tra QR với 2 điện thoại/emulator ở độ sáng vừa.
5. Theme thay đổi không được làm mất trạng thái quiz, QR/countdown hoặc dữ liệu đã tải.


---

# 12. END-TO-END USER JOURNEYS / DEMO SCRIPT

## Scenario A — Attendance

1. Lecturer (Demo Lecturer A) logs in → sees 2 assigned classes.
2. Opens `SE1928 / PRM393` → creates attendance session.
3. QR and countdown appear; Student A logs in on second emulator/phone and scans.
4. Student A sees green “Điểm danh thành công”, Lecturer sees `1 present` live.
5. Student A rescans → “Bạn đã điểm danh buổi này”, count unchanged.
6. Student outside class tries same QR → “Bạn chưa được ghi danh vào lớp”.
7. Lecturer closes session, remaining eligible students become absent; analytics updates.

## Scenario B — Attendance Analytics

1. Lecturer chooses class → Analytics, sees KPI and chart.
2. Chooses bar/session → sees who present/late/absent/excused.
3. Opens student details and historical attendance.
4. Exports CSV and opens it as report for Lab 1/FAP manual workflow.

## Scenario C — Subject News Hub

1. Lecturer opens Khám phá, selects PRM393 → results on Mobile Development.
2. Selects PRN212 → results change to .NET topics.
3. Opens article details → sees title, author, source, date, DOI/URL.
4. Shares article to assigned class → Student in that class sees it in Tài liệu.
5. Disconnect internet / simulate API error → uses cached results/clear retry state.

## Scenario D — Live Quiz & Poll

1. Lecturer creates 1-question Quiz in PRM393 class, selects correct option privately.
2. Opens quiz for 3 minutes.
3. Student A views activity, chooses answer and submits.
4. Student A retries → rejected as duplicate; Lecturer real-time chart updates.
5. Lecturer ends quiz → correct answer/result only revealed according to policy.
6. Lecturer creates Poll without correct answer → receives distribution only.

**Demo must be reproducible with seeded test accounts; never require access to real FPT student information.**

---

# 13. SEED DATA / DEVELOPMENT ENVIRONMENTS

- Firebase Emulator Suite for Firestore, Auth, Functions (and Storage only if needed).
- Seed scripted dataset:
  - 2 lecturers, 8–12 students (enough for screen testing), 1 outsider student.
  - 3 subjects demo with keyword lists: PRM393, PRN212, SWE201c.
  - 3 classes across 2 teachers, assigned memberships.
  - 5 historical class sessions / class, mixed present/late/absent/excused attendance.
  - 1 open/1 closed attendance session as fixtures where valid.
  - 3–6 cached articles with clearly marked **demo fixtures** for offline development only. News feed real mode must call actual source when configured.
  - 2 quizzes and 1 poll for analytics/test.
- Use fake/demo email accounts (e.g., `lecturer.a@example.test`) and Firebase Auth emulator IDs; don't hardcode live passwords in Git.
- `APP_ENV=dev|test|prod` and `USE_EMULATORS=true|false`. Fail loudly when prod config missing.
- Test backend with emulators, then integration test on Android. Add deterministic clock/test hooks to validate expiry without sleeping 2 minutes.

---

# 14. TEST PLAN — REQUIREMENTS-TO-TEST MATRIX

## 14.1. Automated

| Test type | Examples |
|---|---|
| Unit (Dart) | Attendance rate formulas; status transforms; dates; CSV escaping; subject keyword mapping; route guards. |
| Widget | Empty/error/loading states; responsive cards; role nav; quiz form validation; dark mode. |
| Rules emulator | Lecturer assigned vs outsider; student own vs other student's data; deny student writes `attendanceRecords`/`quizPrivate`. |
| Functions integration | QR valid/expired/tampered/other class/duplicate/closed; quiz duplicate/closed/outside class; article API failure. |
| Concurrency | 2 simultaneous check-ins create one record; quiz double submits produce one response; finalize retry stable. |
| External API adapter | Fake HTTP responses, 429, timeout, bad metadata, duplicate DOI, empty feed, caching. |
| Data integrity | Finalize attendance creates proper absences; analytics formula matches seeded record set. |

## 14.2. Manual / device QA

- Android emulator and physical Android if available; camera permissions granted/denied.
- 360dp, 393dp, 430dp widths; text scale 1.3–1.5; dark/light.
- Poor connection, airplane mode, orientation changes, background/foreground during countdown.
- Google sign-in setup may require SHA certificate and OAuth setup; if unavailable test emulator auth.
- Student has no leakage of classmates' private attendance or quiz answers.
- Local timezone/day boundary (11:59 PM to next day) and clock drift.

## 14.3. Commands (adjust paths)

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d <android-device-id>

# Backend (assuming functions scripts exist):
cd functions && npm install && npm run build && npm test

# Firebase emulators:
firebase emulators:start --only auth,firestore,functions
```

**No false claims:** When a test cannot run because Firebase project/Android SDK/credentials aren't configured, mark `BLOCKED` with exact reason and command to reproduce after setup; do not write PASS.

---

# 15. IMPLEMENTATION ROADMAP — CODEX MUST IMPLEMENT IN ORDER

## Phase 0: Audit & plan

- Inspect repo and identify Lab 1 artifacts/models/import-export conventions.
- Inventory existing platform Flutter version, Firebase resources, packages, environment variables.
- Document assumptions and migration decisions; create `docs/IMPLEMENTATION_PROGRESS.md`.
- Scaffold repo without breaking existing app.

**Exit:** Repo map + plan with dependencies + Android app boots to minimal theme.

## Phase 1: Design system, Auth & foundation

- Implement FPT Campus Orange & White tokens/components/theme light+dark; localization vi-VN.
- Firebase initialization, emulators, error mapping, auth, role assignment/guards.
- Subject/Class models, seed data, lecturer/student navigation.
- Lecturer Dashboard, Class List, Class Detail, Student Home.

**Exit:** 2 demo roles can login, each sees correct classes, all four tab shells consistent.

## Phase 2: Attendance P0

- Cloud Functions for open/getQR/checkIn/close; signature/time/role/unique records.
- Lecturer host QR UI, student scanner UI, realtime attendance list.
- Finalization and attendance records; rules + integration tests.

**Exit:** Full demo A, including duplicate and wrong-class rejection.

## Phase 3: Analytics P0

- Attendance aggregation logic and consistent records.
- Lecturer KPI + chart + student drilldown; Student own attendance.
- CSV export; charts tests and formula tests.

**Exit:** Full demo B; data reconciles after closing session.

## Phase 4: Subject News Hub P0

- Subject keyword configuration and feed provider abstraction.
- OpenAlex adapter; Crossref/RSS if time; cache/dedup/search/filter/pagination/error states.
- Article detail/source links; share-to-class and student resources screen.

**Exit:** Full demo C with real metadata in configured mode, graceful API failure.

## Phase 5: Live Quiz/Poll P0

- CRUD publish/open/close; public/private answer separation; submit callable; summary aggregate.
- Lecturer create/live/results; Student join/answer/results.
- Rules and concurrency tests.

**Exit:** Full demo D; no answer leak before reveal.

## Phase 6: Hardening & optional integrations

- Responsive/dark/accessibility pass; error/empty/network; smoke tests.
- Google Sheets integration only if user-provided credentials/permissions ready; else CSV-only meets P0.
- README, `.env.example`, demo accounts for emulator, setup, architecture, test report.
- Android release debug APK or build instructions if SDK available.

**Exit:** Acceptance matrix fully checked; remaining limitations listed.

## 15.1. Completion report format after EACH phase

```markdown
### Phase X — <name>
- DONE: ...
- MODIFIED FILES: ...
- SECURITY DECISIONS: ...
- TEST COMMANDS / RESULTS: ... (PASS/FAIL/BLOCKED)
- SCREENSHOTS/BUILD ARTIFACTS: ... (if available)
- BLOCKERS & REMAINING: ...
- NEXT PHASE: ...
```

---

# 16. NON-FUNCTIONAL REQUIREMENTS & DESIGN GUARDRAILS

- **Security:** Do not trust client time, client role, client-provided correct option, or arbitrary Firestore document access. Functions validate privileges for every mutation.
- **Privacy:** No real private class roster in Git; limit student data shown; do not expose email/studentCode of other students unless explicitly allowed. No location/microphone collection in P0.
- **Performance:** App should load cached shell quickly; paginate article feed; avoid redundant Firestore listeners; unsubscribe streams correctly.
- **Reliability:** Function operations idempotent, session transitions atomic/validated; no `set` overwrite for attendance record duplicates.
- **Observability:** Structured logs with request context but no QR token/signing secret or raw PII. Error logging clearly classifies provider failure vs auth failure.
- **Accessibility:** Screen-reader semantics, hit targets, adequate contrast, scalable text, reduced motion.
- **Cost control:** Limit reads, queries, and Cloud Function calls; configure budget alerts; no unbounded polling of News or live attendance.
- **Localization:** User-visible strings in Vietnamese; date/time Asia/Ho_Chi_Minh, backend UTC; consistent capitalization.
- **Consistency:** One app router, one theme, one error mapping, one backend access pattern; zero per-screen improvisational UI.

---

# 17. OUT OF SCOPE & ANTI-PATTERNS

**Do not implement without explicit scope approval:**

- Full Learning Management System (assignments, gradebook, class chat, video lessons).
- AI chatbot or automatic AI-generated article summaries/questions in P0.
- Automated FAP attendance submission/scraping/browser bot without a supported interface.
- A separate React/HTML frontend replacing requested Flutter Mobile.
- Attendance decisions solely in Flutter or Sheets; student direct writes to attendance records.
- Student role by checking email suffix (`@fpt.edu.vn`) only.
- Fake “real-time” charts built with hard-coded random numbers instead of actual response streams.
- Publishing quiz answer in public Firestore doc.
- Storing service-account JSON inside mobile assets.
- Fancy splash/login animations at expense of core business logic.

---

# 18. OFFICIAL REFERENCES / IMPLEMENTATION SOURCES

The following documentation was checked during spec preparation; verify SDK/API behavior and pricing when implementing.

- Flutter themes / M3: https://docs.flutter.dev/cookbook/design/themes
- Flutter Material 3 migration: https://docs.flutter.dev/release/breaking-changes/material-3-migration
- Flutter ColorScheme: https://api.flutter.dev/flutter/material/ColorScheme-class.html
- FlutterFire setup: https://firebase.google.com/docs/flutter/setup
- Firebase Auth Flutter: https://firebase.google.com/docs/auth/flutter/start
- Firestore Security Rules: https://firebase.google.com/docs/firestore/security/get-started
- Firestore transactions: https://firebase.google.com/docs/firestore/manage-data/transactions
- Firebase callable Functions: https://firebase.google.com/docs/functions/callable
- Firebase App Check Flutter: https://firebase.google.com/docs/app-check/flutter/default-providers
- Cloud Functions usage/billing: https://firebase.google.com/docs/functions/quotas
- OpenAlex API: https://help.openalex.org/api/
- OpenAlex filtering: https://help.openalex.org/api/filtering/
- Crossref API polite access: https://www.crossref.org/documentation/retrieve-metadata/rest-api/access-and-authentication/
- Crossref API best practices: https://www.crossref.org/documentation/retrieve-metadata/rest-api/tips-for-using-the-crossref-rest-api
- Sheets API quotas: https://developers.google.com/workspace/sheets/api/limits
- QR Scanner Flutter package: https://pub.dev/packages/mobile_scanner

---

# 19. FINAL PROMPT ĐỂ PASTE VÀO CODEX

> **Copy nguyên khối dưới đây khi mở repository trong Codex.** Attach/reference this MD file at the project root or inside `docs/`.

```text
Bạn là Senior Flutter Mobile Engineer, Firebase Architect, UI/UX Designer và QA.

Hãy đọc toàn bộ file FAP_SMART_LECTURER_LAB2_CODEX_MASTER_SPEC.md làm SINGLE SOURCE OF TRUTH.

Mục tiêu: Xây dựng FAP Smart Lecturer Lab 2 thành một ứng dụng Flutter Mobile (Android-first), hai role Lecturer/Student, bốn module core: Smart QR Attendance, Attendance Analytics, Subject News & Research Hub, Live Quiz & Poll; kế thừa dữ liệu/luồng có thể dùng từ FAP Attendance Lab 1.

BẮT ĐẦU BẰNG:
1. Khảo sát toàn bộ repo hiện tại, stack Flutter, data model Lab 1, các file dùng được; báo cáo những gì đang có và thiếu.
2. Đề xuất architecture thích nghi repo và list file/module sẽ tạo/sửa, đồng thời tránh làm hỏng Desktop Lab 1.
3. Tạo design system duy nhất "FPT Campus Orange & White" dựa trên Material 3 theo tokens trong mục 11 (FPT Orange #F37021, White #FFFFFF, button orange đậm #B54708), implement theme light/dark và reusable widgets trước khi dựng feature screens; tuyệt đối không giữ primary xanh navy/teal từ bản cũ.
4. Chia implementation theo Phase 0 → 6 (mục 15), và thực hiện từng vertical slice END-TO-END có Firebase Rules, Cloud Functions, UI + tests thực sự.
5. Không dừng ở wireframe/UI mock, không tự nâng quyền user, không lộ đáp án Quiz, không ghi check-in trực tiếp từ client.
6. Không có credentials thì cấu hình emulator, .env.example, seed data và hướng dẫn; ghi BLOCKED rõ ràng, đừng claim test thành công.
7. Mọi mã Flutter/Dart/TypeScript thêm vào phải được format/lint/test và compile nếu environment cho phép.
8. Sau mỗi phase ghi docs/IMPLEMENTATION_PROGRESS.md và mô tả các lệnh chạy cùng PASS/FAIL/BLOCKED; tiếp tục phase tiếp theo nếu không gặp blocker thực sự.
9. Trước khi kết thúc đối chiếu toàn bộ Acceptance Criteria theo các mục 4–7 và Definition of Done mục 0.1; xuất báo cáo còn thiếu và hướng dẫn demo Lecturer + Student trên hai máy/emulator.

KHÔNG thêm tính năng ngoài scope P0 cho đến khi P0 chạy end-to-end; ưu tiên business rules, security, ổn định và giao diện nhất quán hơn hiệu ứng trang trí.
```

---

# 20. DELIVERABLE CHECKLIST FOR LAB 2 SUBMISSION

- [ ] Flutter project runnable + Firebase configuration instructions.
- [ ] `firestore.rules`, indexes, Functions (and tests).
- [ ] Source with architecture and design tokens.
- [ ] Seed/demo data scripts with synthetic accounts.
- [ ] Lab 1 data mapping / CSV compatibility documented.
- [ ] Demo recording/screenshots showing 4 end-to-end scenarios.
- [ ] README includes setup, run, dependencies, external APIs, API key/billing notice.
- [ ] `docs/TEST_REPORT.md` includes commands, actual outputs and known issues.
- [ ] Explanation of what is **really implemented** vs mocked vs optional.

**Implementation quality standard:** A complete, coherent, safe Lab 2 mobile prototype with functioning attendance and classroom engagement workflows, not a collection of disconnected polished screens.
