# Lab 2 data dictionary và mapping Lab 1

Firestore là authoritative database của Lab 2. Timestamps dùng Firestore Timestamp UTC. UI hiển thị UTC+7 / Asia/Ho_Chi_Minh.

| Collection | Các trường chính / quyền |
|---|---|
| users/{uid} | uid, displayName, email, role lecturer/student, active, subjectIds[], studentCode. Chỉ operator ghi; user đọc chính mình khi active. |
| subjects/{code} | code, name, keywords[], active. User chỉ đọc môn được server cấp trong subjectIds. |
| schedules/{id} | lecturerUid, classId?, term, subjectId, subjectName, classCode, dayOfWeek 1–7 (thứ 2–CN), slot 1–12, startTime/endTime HH:mm, room. Lịch định kỳ, chỉ giảng viên phụ trách được đọc; operator quản lý. Chế độ Sheet ánh xạ từ Schedules theo lecturerId và ghép lớp bằng semester + subjectCode + classCode. |
| classes/{id} | classCode, subjectId, term, lecturerUids[], studentUids[], studentCount, status. UID lists phục vụ query có thể được Rules chứng minh; chỉ server/operator quản lý. |
| classes/{id}/members/{uid} | studentUid, studentCode, displayName, enrolledAt, active. Giảng viên lớp đọc roster, sinh viên chỉ đọc mình. |
| classSessions/{id} | classId, subjectId, title, lecturerUid, startsAt, endsAt, slot?, room?, status scheduled/completed. Tạo qua callable. Lịch theo ngày ưu tiên hơn lịch định kỳ cùng lớp + slot. Không suy đoán slot khi thiếu dữ liệu. |
| attendanceSessions/{classSessionId} | ID deterministic để chỉ có một attendance session/buổi. classId, classSessionId, opensAt, closesAt, lateThresholdAt, eligibleStudentUids snapshot, status open/finalized, sessionVersion, qrRotationSeconds. |
| attendanceRecords/{sessionId}_{uid} | classId, classSessionId, attendanceSessionId, studentUid, status present/late/absent/excused, checkedInAt?, recordedAt, recordedBy. Server-only writes; giảng viên lớp hoặc chính sinh viên đọc. |
| quizzes/{id} | classId, subjectId, type quiz/poll, question, options[{id,text}], durationSeconds, status scheduled/open/published, opensAt?, closesAt?, createdBy, createdAt, joinCode. Không có correctOptionId. P0 chọn hoạt động trực tiếp trong lớp; joinCode chỉ metadata, chưa có màn nhập code. |
| quizPrivate/{id} | correctOptionId cho quiz; poll không có. Không client nào đọc/ghi, kể cả giảng viên. |
| quizResponses/{quizId}_{uid} | quizId, classId, studentUid, selectedOptionId, submittedAt. Không chứa điểm/đáp án trước reveal. Server-only writes. |
| quizStats/{id} | classId, totalResponses, optionCounts, updatedAt. Chỉ lecturer đọc khi đang live. |
| quizResults/{id} | stats + correctOptionId/correctCount sau publish. Server xuất đúng lúc, student membership bắt buộc. Chấm điểm một câu thông qua server counts; sinh viên so lựa chọn riêng với đáp án đã công bố. |
| articleCache/{sha256} | id, DOI normalized, title, authors[], publisher, source, publishedAt?, url HTTPS, abstractSnippet null, subjectIds[], fetchedAt/expiresAt millis. Server-only reads/writes; callable trả metadata được phép. Không lưu full text. |
| articleFeeds/{sha256} | articles[], fetchedAt, expiresAt (6h), nextPage. Cache theo subject/query/source/sort/date/page, server-only. |
| sharedArticles/{classId}_{articleId} | classId, subjectId, articleId, article metadata snapshot, sharedBy, note, sharedAt. Snapshot cho tài liệu lớp vẫn đọc được khi cache nguồn đổi; chỉ lecturer cùng môn share. |
| rateLimits/{uid}_{action} | sliding fixed window 60s, count. QR/quiz tối đa 30, articles tối đa 12 requests/phút/user. Không client đọc/ghi. |
| pendingEnrollments/{classId}_{studentCode} | imported CSV values, status pending_uid_mapping. Operator resolve trước khi được tham gia. |
| testClock/control | now millis, chỉ Emulator backend test harness; toàn bộ client bị deny, production không sử dụng. |

Lab 1 `semester → term`, `subjectCode → subjectId/code`, `classCode → classCode`, `fullName → displayName`, `studentCode → studentCode`. `studentId` của hệ thống cũ không được dùng làm Firebase UID: operator phải map bằng tài khoản đã xác minh. `lecturerId` cũng không tự động thành Auth UID. Giữ old IDs trong mapping operator nếu cần trao đổi với Desktop.

CSV export chuẩn: `classCode,subjectCode,sessionDate,studentCode,studentName,status,checkedInAt,notes`. sessionDate hiển thị dd/MM/yyyy ở VN, checkedInAt ISO UTC. Cần transform thêm nếu Lab 1 dùng enum PRESENT/LATE/ABSENT uppercase. Không có đồng bộ hai chiều, không ghi lại Sheets Desktop từ app này.

Giới hạn prototype: finalize atomic tối đa 400 eligible students/phiên, truy vấn records theo lớp nên phù hợp lớp/kỳ Lab nhỏ; production lớn cần pagination/reconciliation jobs. Thống kê chỉ lấy finalized sessions và records eligibility đã snapshot, loại excused khỏi denominator, late tính attended, cần ít nhất 3 eligible buổi trước khi gắn Cần theo dõi (<80%). Không phải quy định cấm thi chính thức.
