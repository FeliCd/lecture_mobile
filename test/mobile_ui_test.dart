import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/api/repository.dart';
import 'package:lecturer_companion/app/app.dart';
import 'package:lecturer_companion/features/auth/auth.dart';
import 'fixtures.dart';

void main() {
  Future<AuthController> account(FixtureApi api) async {
    final auth = AuthController(TestIdentity(), MemoryVault())
      ..repository = LecturerRepository(api);
    await auth.login();
    return auth;
  }

  Future<void> phone(WidgetTester tester, {double width = 390}) async {
    await tester.runAsync(() async {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      // Optional host font for readable review captures; assertions remain portable.
      final font = File('C:/Windows/Fonts/segoeui.ttf');
      if (await font.exists()) {
        final loader = FontLoader('Roboto')
          ..addFont(
            font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        await loader.load();
      }
    });
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('artifacts/ui').create(recursive: true);
      await File(
        'artifacts/ui/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('Launch displays honest setup state at phone size', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture'),
        child: CompanionApp(
          auth: AuthController(TestIdentity(), MemoryVault()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Setup required'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'login');
  });
  testWidgets(
    'Home, schedule, classes, roster, attendance and report on phone',
    (tester) async {
      await phone(tester);
      final auth = await account(FixtureApi());
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: CompanionApp(auth: auth),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Focus for today'), findsOneWidget);
      await capture(tester, 'home');
      await tester.tap(find.text('Schedule').last);
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
      await capture(tester, 'schedule');
      await tester.tap(find.text('Classes').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('PRM393 · SE1901').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Students'));
      await tester.pumpAndSettle();
      expect(find.text('Test Student'), findsOneWidget);
      await capture(tester, 'roster');
      await tester.tap(find.text('Sessions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      expect(find.text('Display QR attendance'), findsOneWidget);
      await capture(tester, 'attendance');
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Report absence includes'), findsOneWidget);
      await capture(tester, 'report');
      await tester.ensureVisible(find.text('Correct attendance'));
      await tester.tap(find.text('Correct attendance'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Verified in class');
      await tester.tap(find.text('Save attendance'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 1 present'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await auth.logout();
      await tester.pumpAndSettle();
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Correct attendance'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Small phone and large text keep navigation and empty states usable',
    (tester) async {
      await phone(tester, width: 320);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = FixtureApi()..empty = true;
      final auth = await account(api);
      await tester.pumpWidget(CompanionApp(auth: auth));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schedule').last);
      await tester.pumpAndSettle();
      expect(find.text('No classes scheduled.'), findsOneWidget);
      await tester.tap(find.text('Classes').last);
      await tester.pumpAndSettle();
      expect(find.text('No classes found.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
