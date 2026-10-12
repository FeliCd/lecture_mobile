# FAP Smart Lecturer Lab 2 architecture

Audit 08/10/2026 tại `C:\PRM\lecture_mobile`: repository Flutter mobile Android/iOS có Apps Script/Sheets backend, lecturer-only Google auth, ChangeNotifier, HTTP repository, QR URL cho web student. Không tìm thấy Firebase, News, Quiz, native scanner hoặc student role. Working tree ban đầu sạch. Báo cáo audit Desktop cũ có đường dẫn máy khác, chưa được coi là bằng chứng Desktop có sẵn trên máy này.

Chọn giữ Flutter project ở root và thêm `lib/lab2`, không di chuyển Android/iOS vào monorepo con. `lib/main.dart` khởi động Firebase Lab 2; `lib/main_legacy.dart` chạy companion cũ khi cần tham chiếu. Không sửa Apps Script hoặc gọi các deployment live cũ. Legacy README/architecture lưu dưới `docs/LEGACY_*`.

| Layer | Files |
|---|---|
| Bootstrap | main.dart: config validation, FirebaseOptions, emulator wiring, explicit setup failure |
| App state/navigation | lab2/app.dart: Riverpod auth/profile/theme, GoRouter guards, 4 tabs/role; SharedPreferences chỉ lưu theme |
| Domain | lab2/domain.dart: immutable profile, attendance formula, UTC+7 formatting, CSV safety, Vietnamese errors |
| Data | lab2/repository.dart: Firestore query/read streams, callable mutation adapter, Google credential exchange |
| Shared UI | lab2/theme.dart, widgets.dart: orange/white Material 3, semantic status colors, cards/buttons/chart/status/async states |
| Features | classes.dart, attendance.dart, news.dart, quiz.dart: presentation and local form state |
| Backend | functions/src/index.ts: auth/ownership, schemas, transactional mutations, scheduler; domain.ts HMAC QR; news.ts metadata adapters/caches |
| Security | firebase/firestore.rules deny default, no client writes; firestore.indexes.json for documented sorted queries |
| Operator | scripts/seed.cjs (emulator-only synthetic data), import-roster.cjs (CSV preview/pending mapping) |
| Tests | test/lab2_*.dart widget/unit/navigation; functions/test/*.test.cjs unit; emulator.cjs real Auth/Firestore/callables/rules; news-live.cjs opt-in external source smoke; integration_test/lab2_smoke_test.dart Android SDK smoke |

Emulator demo dùng Firebase Auth/Firestore SDK và gọi Functions local qua callable HTTP protocol (`data` request / `result` response) với Firebase Auth bearer token. Cách này tránh bước Firebase Installations của Android callable SDK vốn yêu cầu cấu hình cloud ngay cả với demo project. Nhánh local chỉ bật khi USE_EMULATORS=true, APP_ENV không phải prod và project ID bắt đầu demo-. Backend vẫn xác minh user/role/membership và chạy cùng các callable handlers; production giữ callable SDK. Tham chiếu protocol: https://firebase.google.com/docs/functions/callable-reference.

Attendance: deterministic attendance session ID from classSessionId prevents concurrent opens; membership snapshot uses enrolledAt; signed tokens use slotId/sessionVersion/expiry; server clock is authority. Check-in transaction reads session + membership + deterministic record, rejects duplicate and deadline. Finalization atomically creates missing absent records and completes teaching session, retries return same final state.

Quiz/Poll: public quiz has no correctOptionId; private answer readable only by Admin. Submit transaction checks membership/status/deadline/option and creates deterministic response + stats together. Close transaction reads stats/private answer and publishes result document; Rules permit result only after status published. Poll has no answer/scoring. Join-by-class is the implemented P0 path.

News: authenticated user has server-managed subjectIds; OpenAlex/Crossref only contacted from backend with fixed endpoints and safe parameter encoding. Metadata normalized by DOI/URL hash, 20 items/page, search debounce, 6-hour feed cache, bounded timeout/retry, source-date-sort filters, stale cache fallback. Shared article embeds metadata snapshot and is membership-protected. No full text scraping, WebView HTML execution, or AI generation.

Read streams always scoped to assigned/enrolled class, plus studentUid for own records. Rules cannot safely authorize an unbounded student history query across arbitrary classes; native UI explicitly queries class by class. Lecturer roster names share a Riverpod family stream per class. QR/quiz detail timers preserve stream subscriptions; theme updates keep navigator/form state.

Tradeoffs: one Lab-sized class query per feature (no whole-database scan), atomic finalize cap 400 students, manual session creation starts now, results always reveal on close, no scheduled quiz editing/reopening or multi-question tests. Scheduled production job closes expired attendance/quiz every minute; submission deadline is enforced independently even if scheduler delayed. Google Sheets is P1 and not connected.

Official references used while implementing: [callable Functions](https://firebase.google.com/docs/functions/callable), [OpenAlex API](https://help.openalex.org/api/), [OpenAlex authentication](https://help.openalex.org/api/authentication/), [OpenAlex paging](https://help.openalex.org/api/paging/), [Crossref access](https://www.crossref.org/documentation/retrieve-metadata/rest-api/access-and-authentication/). Package versions resolved against the installed Flutter SDK; no Flutter SDK upgrade performed.
# Chế độ mặc định cập nhật 09/10/2026

Mobile → Firebase Authentication (Spark) → Apps Script chung → Desktop Google Sheets. Class roster, sessions và attendance cùng một nguồn dữ liệu, không có Firestore mirror. Mobile poll snapshot 30s và refresh sau mutation; Apps Script giữ role, deadline, kiểm tra QR và atomic Sheets batch writes. Quiz tắt. Xem [FREE_DESKTOP_SYNC](FREE_DESKTOP_SYNC.md). Kiến trúc Firebase Functions bên trên còn áp dụng cho Emulator/bản cloud đầy đủ tùy chọn.
