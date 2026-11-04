import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/groups/group_attachment.dart';
import 'package:lecturer_companion/groups/study_groups.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'reads attachment bytes or a bounded stream and rejects invalid files',
    () async {
      final value = await readGroupAttachment(
        PlatformFile(
          name: 'Bài tập.PDF',
          size: 3,
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      );
      expect(value['base64'], 'AQID');
      expect(value['size'], 3);
      final streamed = await readGroupAttachment(
        PlatformFile(
          name: 'note.txt',
          size: 0,
          readStream: Stream.fromIterable([
            [65],
            [66],
          ]),
        ),
      );
      expect(streamed['base64'], 'QUI=');
      for (final file in [
        PlatformFile(name: 'empty.txt', size: 0, bytes: Uint8List(0)),
        PlatformFile(name: 'bad.exe', size: 1, bytes: Uint8List(1)),
        PlatformFile(name: '../bad.pdf', size: 1, bytes: Uint8List(1)),
        PlatformFile(name: 'big.pdf', size: 512001),
        PlatformFile(
          name: 'hidden-size.pdf',
          size: 1,
          readStream: Stream.value(List.filled(512001, 0)),
        ),
      ]) {
        await expectLater(readGroupAttachment(file), throwsFormatException);
      }
    },
  );

  const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
  Future<void> mount(
    WidgetTester tester,
    Future<dynamic> Function(String, Map<String, dynamic>) call,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (method) async => [
        {
          'name': 'sample.txt',
          'path': 'C:/fixture/sample.txt',
          'size': 3,
          'bytes': Uint8List.fromList(utf8.encode('abc')),
        },
      ],
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudyGroups(
            classId: 'c1',
            call: (method, data) async {
              if (method == 'getGroupPlan') {
                return {
                  'version': 1,
                  'groups': [
                    {'id': 'g1', 'name': 'Nhóm 1', 'memberIds': []},
                    {'id': 'g2', 'name': 'Nhóm 2', 'memberIds': []},
                  ],
                  'students': [],
                };
              }
              if (method == 'getGroupMessages') {
                return {'messages': [], 'older': null};
              }
              if (method == 'getGroupSignupSheet') {
                return {'state': 'NONE', 'currentPlanVersion': 1};
              }
              return call(method, data);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'file-only message waits for explicit send and uncertain retry keeps the same file and key',
    (tester) async {
      final sent = <Map<String, dynamic>>[];
      await mount(tester, (method, data) async {
        sent.add(Map.of(data));
        if (sent.length == 1) throw StateError('timeout');
        return {'saved': true};
      });
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Gửi tin nhắn'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Gửi file'));
      await tester.pumpAndSettle();
      expect(find.text('sample.txt'), findsOneWidget);
      expect(sent, isEmpty);
      await tester.tap(find.text('Gửi kèm file'));
      await tester.pumpAndSettle();
      expect(find.text('sample.txt'), findsOneWidget);
      await tester.tap(find.text('Thử gửi lại cùng tin'));
      await tester.pumpAndSettle();
      expect(sent.length, 2);
      expect(sent[0], sent[1]);
      expect(sent[0]['text'], '');
      expect(sent[0]['file'], {'name': 'sample.txt', 'base64': 'YWJj'});
      expect(find.text('sample.txt'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'attachment can be removed without sending or clearing message text',
    (tester) async {
      await mount(
        tester,
        (method, data) async => throw StateError('unexpected send'),
      );
      await tester.enterText(find.byType(TextField), 'Ghi chú');
      await tester.tap(find.text('Gửi file'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bỏ tệp đính kèm'));
      await tester.pumpAndSettle();
      expect(find.text('sample.txt'), findsNothing);
      expect(find.text('Ghi chú'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'switching groups confirms discarding a file and never carries it to the new group',
    (tester) async {
      await mount(tester, (_, _) async => throw StateError('unexpected send'));
      await tester.tap(find.text('Gửi file'));
      await tester.pumpAndSettle();
      Future<void> switchGroup() async {
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nhóm 2').last);
        await tester.pumpAndSettle();
      }

      await switchGroup();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('sample.txt'), findsOneWidget);
      await switchGroup();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('sample.txt'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Gửi tin nhắn'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
