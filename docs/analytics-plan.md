# Analytics plan - Lab 3

Lập trước khi tích hợp ngày 02/11/2026. Chỉ gửi UID Firebase làm user ID; không email, tên, MSSV, nội dung chat/tệp, lớp hoặc token. Logout xóa user ID. Analytics có thể lỗi mà không chặn nghiệp vụ.

| Event | Trigger | Parameters | Câu hỏi |
|---|---|---|---|
| login | Google credential Firebase thành công | method:string | Đăng nhập thành công không? |
| logout | Firebase logout thành công | none | Phiên được kết thúc không? |
| view_teaching_day | Mở home sau xác thực | none | Có dùng trang hôm nay? |
| attendance_session_opened | Server xác nhận mở phiên | none | Có mở phiên? |
| attendance_session_closed | Server xác nhận chốt | none | Phiên có được chốt? |
| attendance_record_updated | Server xác nhận sửa | none | Có cần điều chỉnh? |
| quick_attendance_completed | Server xác nhận điểm danh nhanh | none | Điểm danh nhanh có hoàn tất? |
| weekly_report_exported | Share sheet trả kết quả | none | Có xuất báo cáo? |
| report_upload_completed | Storage upload hoàn tất | bytes:int | Dung lượng và tỷ lệ dùng upload? |
| notification_opened | Chạm push hợp lệ | destination:enum | Push có đưa đến màn liên quan? |
| group_plan_saved | Server xác nhận chia nhóm | none | Chia nhóm có hoàn tất? |

Kiểm chứng: bật DebugView Android, thao tác trên tài khoản test, chụp từng event cùng tham số; không suy luận pass từ console log. Các event mutation ghi sau response thành công, retry có thể lặp telemetry nhưng không lặp thao tác server. Mỗi service có ca offline/permission-denied, không gửi raw exception tới telemetry vì có thể chứa dữ liệu cá nhân.
