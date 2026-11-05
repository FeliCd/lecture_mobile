# Kịch bản demo Lab 3 — bản cập nhật 05/11/2026

## Chuẩn bị trước buổi trình bày

- Dùng **điện thoại Android thật** theo yêu cầu thầy; emulator là dự phòng. Cài APK mới `C:/PRM/lecture_mobile/build/app/outputs/flutter-apk/app-debug.apk`. Chạy bản có `ENABLE_LAB3_DEMO=true`. Đăng nhập tài khoản giảng viên test được cấp UID allowlist; cấp notification permission.
- Mở Student Web https://fap-sinhvien.web.app/ trên browser với tài khoản **sinh viên test riêng**. Desktop/Mobile là giảng viên; không đăng nhập SV vào màn giảng viên để demo.
- Lưu một ảnh PNG/JPEG mẫu không có dữ liệu cá nhân vào Downloads trên điện thoại. Ảnh tối đa 5 MB; có thể dùng ảnh cam mẫu đã thử. Kiểm Wi-Fi và dự phòng hotspot.
- Mở trước Firebase Console đúng project `fap-attendance-88920`: Authentication Users, Storage, Functions logs, Analytics DebugView, Crashlytics, Remote Config. Dùng các link trong `docs/LAB3_COMPLETION_SETUP.md`.
- Mở sẵn VS Code tại `lib/cloud/image_upload_panel.dart`, `lib/cloud/cloud_view_model.dart`, `lib/cloud/cloud_services.dart`, `lib/cloud/demo_push.dart`, `functions/src/demo-push.ts`, `lib/cloud/push_notifications.dart`, `lib/lab2/session_view_model.dart` và `firebase/storage.rules`.
- ARTEMIS ở `C:/PRM/tools/artemis`, dashboard http://127.0.0.1:8000. Chạy thử trước; có 10 ca và runner trong `testing/artemis`. Key local không đưa vào slide. Lưu logs/actual; chuẩn bị ảnh/replay của các lượt thực sự đã chạy.
- Chạy thử push nền và vuốt Recent trên đúng điện thoại trước khi lên lớp. Chuẩn bị video quay thật dự phòng. Chưa có kết quả thì nói rõ, không dùng clip/ảnh fixture làm bằng chứng cloud.
- Không gây crash khi còn nháp hoặc dữ liệu chưa lưu. Không mở `.env`, key Gemini, service-account key hoặc token FCM trước máy chiếu. Khi chỉ URL ảnh, tránh chiếu toàn bộ bearer token.

## Bản demo khoảng 10 phút

| Thời gian | Thao tác | Lời nói gợi ý | Kết quả cần cho thầy thấy |
|---|---|---|---|
| 0:00–0:40 | Slide 1–2; mở app trên điện thoại và link web | “Mobile và Desktop phục vụ giảng viên, web phục vụ sinh viên; dữ liệu nghiệp vụ đi qua backend chung.” | App chạy thật; web deploy mở được |
| 0:40–1:30 | Chỉ sơ đồ slide 4 và một controller/repository | “View phát thao tác. Riverpod ViewModel quản lý busy/error. Service gọi Firebase hoặc API; UI theo state dựng lại.” | Chỉ đúng class và lời gọi trong code; không chỉ nói tên MVVM |
| 1:30–2:15 | Nếu chưa login: Google chooser → account test → trang chủ; mở Console Users | “Google credential được Firebase xác minh và tạo phiên/UID. Backend tiếp tục kiểm quyền lớp.” | Google login thật và account trên Users. Demo hủy/guard nếu thời gian cho phép; không logout làm gián đoạn phần sau |
| 2:15–3:30 | Cài đặt → Dịch vụ đám mây → demo → Chọn và upload ảnh → ảnh mẫu; mở Console Storage | “Ảnh được đọc có giới hạn, controller cập nhật progress. Service lưu theo UID; rules giới hạn chủ sở hữu, MIME và dung lượng.” | Preview, progress, success/path/URL; object mới `images/{uid}/…png|jpg` trên bucket, đối chiếu đúng file |
| 3:30–4:10 | Bấm Gửi thông báo thử; mở Trung tâm thông báo | “Nút gọi callable có xác thực. Server dùng Firebase Admin gửi FCM, không nhúng khóa server trong app.” | Banner/tin mới và giờ nhận; accepted chỉ là server nhận, chưa phải delivery |
| 4:10–5:00 | Chờ cooldown ≥30 giây; bấm Gửi sau 15 giây; về Android Home ngay; chạm notification tray | “Đây là nhánh background. Chạm push mở màn đã được whitelist.” | App nằm nền; notification hệ thống; tap mở đúng màn. Không dùng nút Back thay Home |
| 5:00–5:50 | Chờ cooldown; gửi trễ lần nữa; mở Recent và vuốt app; nhận/tap push | “Đây là mở lại sau khi app bị loại khỏi Recent. Không Force stop.” | Notification tray và cold start/guard/đích đúng. Một số hãng hạn chế nền: thử trước trên điện thoại demo |
| 5:50–6:40 | Console Remote Config; đổi một tham số đã chuẩn bị → Publish; app Tải lại cấu hình | “Console phân phối tham số. SDK fetch/activate, ViewModel cập nhật UI; cache/default hỗ trợ offline.” | UI thay đổi không rebuild. Cache thường 15 phút; kiểm cấu hình demo fetch interval trước; không hứa luôn cập nhật ngay |
| 6:40–7:20 | Mở Analytics DebugView đã chuẩn bị, đối chiếu event và UID | “Analytics ghi sự kiện thao tác có ý nghĩa; không gửi tên/email/MSSV hay nội dung chat.” | Event/parameter thật; nếu yêu cầu ≥7, dùng luồng và logs đã thực hiện trước trên lớp test |
| 7:20–8:00 | Web: xem nhóm, điểm đã công bố hoặc tin test | “SV chỉ thấy thông tin được backend cho phép. Chat và nhóm là nghiệp vụ dùng chung; tệp chat Drive khác Firebase Storage.” | Dùng đúng tài khoản SV, một luồng ngắn. Không phát sinh tin nhắn vào nhóm thật |
| 8:00–9:00 | ARTEMIS dashboard/replay và CSV actual | “Goal → quan sát → thao tác → kiểm giá trị → trace/replay. SUCCESS không thay assertion.” | Logs thật, expected/actual, số lượt đã thực hiện. Chưa đủ 30 lượt thì công khai trạng thái |
| 9:00–10:00 | Demo non-fatal/crash cuối; xác nhận, mở app lại; mở Console Crashlytics chuẩn bị trước | “Crashlytics thu lỗi và stack trace. App gửi báo cáo khi có kết nối và khởi động lại.” | Crash có chủ đích và Console fatal/non-fatal/UID/custom key. Console có độ trễ, dùng report thật đã ghi trước nếu report mới chưa hiện |

Nếu thầy chỉ cho 5 phút: giữ MVVM 30s, Google Auth 30s, ảnh 60s, push 90s, ARTEMIS 30s, crash 60s; Analytics/RC/web mở ở tab dự phòng để trả lời.

## Kết quả kiểm key mới

Key mới được endpoint Gemini models chấp nhận HTTP 200 và đã lưu local. Lượt ARTEMIS thử lại vẫn thất bại ở planning do provider 503 quá tải rồi 429 quota, chưa có thao tác/ca nghiệm thu pass. Không demo trực tiếp khi provider còn lỗi; dùng logs lỗi và trình bày phạm vi trung thực. Blaze của Firebase không tự tăng quota Gemini API.

## Lệnh ARTEMIS khi trình bày

Không chạy cả 30 lượt ngay trên lớp. Chạy một ca ngắn hoặc mở replay đã thu trước:

```powershell
cd C:\PRM\lecture_mobile
C:\PRM\tools\artemis\.venv\Scripts\python.exe testing/artemis/run_cases.py --case T01 --runs 1
```

Để nghiệm thu đầy đủ trước buổi học:

```powershell
C:\PRM\tools\artemis\.venv\Scripts\python.exe testing/artemis/run_cases.py --runs 3
```

Mỗi lượt trong CSV mặc định REVIEW_REQUIRED. Mở trace/replay, ghi actual và quyết định PASS/FAIL/BLOCKED. Bổ sung ca lỗi mạng/tương tác Android và ba flow Lab2 trên lớp test; 10 ca đọc hiện có chưa tự phủ hết rubric. Ghi riêng phiên khám phá 15–30 phút. Chỉ tính tỷ lệ đạt từ các lượt thực tế, không cộng unit test vào ARTEMIS.

## Khi có lỗi lúc demo

| Tình huống | Xử lý và lời giải thích |
|---|---|
| Ảnh bị từ chối | Kiểm UID đăng nhập, bucket, rules, MIME/size. Giữ rule owner-only; không mở public để demo. Cho thầy xem lỗi và video upload thật đã chuẩn bị |
| FCM accepted nhưng không có notification | Kiểm permission, mạng, token hiện tại, Play services và hạn chế pin; thử điện thoại. Nói “server đã nhận, em chưa xác nhận delivery”, không tạo local notification thay thế |
| Gửi quá nhanh | Chờ ≥30 giây. Không tự bấm lặp khi timeout vì có thể gửi trùng |
| Remote Config chưa đổi | Giải thích fetch interval/cache; đối chiếu nguồn/giờ fetch và cấu hình demo đã chuẩn bị. Không rebuild để giả lập việc publish có tác dụng |
| Gemini 503/429 | Mở trace lỗi/provider, dùng replay có thật; nói chưa thực thi được lượt hiện tại. Không gắn PASS cho lượt bị quota |
| Crash Console chưa có report mới | Mở lại app/kết nối mạng; đối chiếu report thật đã chuẩn bị trước và nêu thời điểm. Không nói app đóng là đủ bằng chứng Crashlytics |
| Web lỗi dữ liệu lớp | Dùng tài khoản/lớp test đã chuẩn bị, reload và kiểm deployment/API. HTTP 200 chỉ chứng minh Hosting trả trang |

## Câu hỏi thầy có thể hỏi

- **Image Storage implement ở đâu?** Panel chọn ảnh → imageUploadProvider/Controller → FirebaseReportStorage(image:true); rules ở firebase/storage.rules.
- **Push khác local reminder thế nào?** Push đi qua FCM/server; local reminder do thiết bị lập lịch. Nút demo đang dùng Cloud Functions + Admin SDK.
- **Vì sao giới hạn UID/rate?** Endpoint chỉ dành tài khoản giảng viên demo tin cậy, nội dung cố định và giới hạn 30 giây, tránh gửi tùy ý/spam.
- **Có đủ ARTEMIS chưa?** Trả lời theo CSV/log actual mới nhất. Cài công cụ, key hợp lệ hoặc CLI exit 0 chưa chứng minh đã đạt 10×3.
- **Ba nền tảng đồng bộ thế nào?** Cùng URL/backend nghiệp vụ; kiểm quyền ở backend. Giới hạn hiện tại: giao việc có trên Mobile, Desktop chưa có màn tương ứng; web cần reload sau đồng bộ plan từ Sheets.
- **Đã hoàn tất hết Lab3 chưa?** Chỉ chốt sau khi đủ điện thoại thật, FCM ba trạng thái/tap, Console evidence, ARTEMIS + khám phá, review PR và hồ sơ nộp.

Slide cập nhật có thể dùng để trình bày công nghệ ngay; checklist này cần diễn tập trên thiết bị demo trước khi tuyên bố toàn bộ tiêu chí đã nghiệm thu.
