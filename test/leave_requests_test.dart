import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/leave_requests.dart';

void main() {
  testWidgets(
    'mobile review sends the request version and reloads shared data',
    (tester) async {
      final calls = <Data>[];
      var approved = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaveRequestsPanel(
              classId: 'c1',
              sessionDate: '2026-10-24',
              slot: 1,
              closedSessionId: 'session-1',
              call: (method, data) async {
                calls.add({'method': method, ...data});
                if (method == 'reviewLeaveRequest') {
                  approved = true;
                  return {};
                }
                if (method == 'applyApprovedLeave') return {'saved': true};
                return {
                  'requests': [
                    {
                      'id': 'leave-1',
                      'studentId': 's1',
                      'studentCode': 'SE1',
                      'fullName': 'Sinh viên mẫu',
                      'sessionDate': '2026-10-24',
                      'slot': 1,
                      'reason': 'Khám bệnh theo lịch hẹn',
                      'status': approved ? 'APPROVED' : 'PENDING',
                      'version': approved ? 5 : 4,
                    },
                  ],
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.single, {
        'method': 'listClassLeaveRequests',
        'classId': 'c1',
        'sessionDate': '2026-10-24',
        'slot': 1,
      });
      await tester.tap(find.text('Từ chối'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Từ chối đơn'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập lý do từ chối.'), findsOneWidget);
      expect(calls, hasLength(1));
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duyệt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duyệt đơn'));
      await tester.pumpAndSettle();
      expect(calls[1], {
        'method': 'reviewLeaveRequest',
        'classId': 'c1',
        'id': 'leave-1',
        'version': 4,
        'status': 'APPROVED',
        'reviewNote': '',
      });
      expect(calls[2], calls[0]);
      expect(find.textContaining('SE1 · Đã duyệt'), findsOneWidget);
      await tester.tap(find.text('Cập nhật nghỉ có phép'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cập nhật'));
      await tester.pumpAndSettle();
      expect(calls[3], {
        'method': 'applyApprovedLeave',
        'sessionId': 'session-1',
        'studentId': 's1',
      });
      expect(find.text('Đã cập nhật nghỉ có phép.'), findsOneWidget);
    },
  );
}
