# Tính điểm FE/PE cho giảng viên

## Mở công cụ

- **Mobile:** vào Trợ lý giảng dạy hoặc mở một lớp, bấm biểu tượng máy tính có nhãn trợ năng **Tính điểm FE/PE** trên thanh tiêu đề.
- **Desktop:** vào Điểm số, chọn lớp, bấm **Tính điểm FE/PE**. Công cụ mở màn riêng; quay lại vẫn giữ bảng điểm đang sửa.

## Sử dụng

Nhập điểm đã có (Assignment, PT, Quiz, Lab…) trên thang 10 và trọng số theo syllabus. Có thể thêm/xóa cột. Giữ FE hoặc thêm PE, nhập trọng số và để trống điểm cần tính. Nếu đã có điểm FE/PE, nhập để cố định bài đó. Tổng trọng số phải đúng 100%; không tự đặt trọng số của môn.

Nhấn **Tính điểm cần đạt**. Công cụ đưa ra điểm FE/PE nhỏ nhất theo bước 0,1 để tổng **lớn hơn 5**, hoặc các cặp điểm khi chưa có cả hai bài thi. Nếu hai bài thi bằng điểm nhau, hiển thị một mục tiêu chung; bảng kịch bản giả định PE từ 0 đến 10 và tính FE tương ứng. Nếu điểm tối đa vẫn không đủ, báo tổng tối đa.

Ví dụ: Assignment 5 × 20%, PT 5 × 20%, Quiz 5 × 20%, FE 40% → cần FE 5,1; tổng 5,04. FE 5 chỉ cho tổng 5, chưa vượt mục tiêu.

Chấp nhận dấu phẩy hoặc dấu chấm, tối đa hai chữ số thập phân. Giữ đúng điểm 0; không tự coi ô trống của cột thường là 0. Từ chối điểm ngoài 0–10, trọng số không hợp lệ, tổng khác 100%, FE/PE trùng và dữ liệu thiếu. Sửa bất kỳ đầu vào nào sẽ xóa kết quả cũ và yêu cầu tính lại.

## Vai trò và dữ liệu

Mobile/Desktop dùng công cụ để giảng viên tư vấn; Student Web vẫn có công cụ dành cho sinh viên. Ba bản dùng cùng quy tắc tổng > 5, với phép tính số nguyên để tránh sai số tại ngưỡng. Không tự suy đoán điểm liệt FE/PE, chuyên cần hoặc chính sách làm tròn: cần kiểm tra syllabus môn.

Tính năng nhập tay trong màn hình riêng, không tự đọc hay chuyển đổi bảng điểm của một sinh viên. Không có API ghi, không lưu localStorage/SharedPreferences, không sửa nháp/công bố điểm và không gửi thông báo. Đóng màn hình sẽ mất bản tính thử; không cần triển khai backend mới.

Mã Dart nằm tại `lib/grade_forecast/` trong từng repo Mobile/Desktop; hai bản được giữ giống nhau, không phụ thuộc chéo vào đường dẫn máy. Các test kiểm tra điểm biên, số 0, thập phân, hai bài thi, tính tối thiểu, đầu vào lỗi và giao diện hẹp/rộng; test tích hợp kiểm tra đường mở và bảo toàn dữ liệu đang sửa.

Chức năng được quản lý trên nhánh `develop` của repo Mobile. Kiểm tra bằng unit/widget test; chưa triển khai hoặc chạy thử bản native trên điện thoại thật.
