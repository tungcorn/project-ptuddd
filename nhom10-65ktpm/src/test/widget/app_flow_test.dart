import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/features/auth/presentation/placement_screen.dart';
import 'package:singlearn/features/songs/presentation/library_screen.dart';
import 'package:singlearn/singlearn_app.dart';

import 'harness.dart';

/// Songs listed in the bundled catalog (the library shows all of them).
List<Map<String, dynamic>> catalogSongs() => [
      for (final s in (jsonDecode(File('assets/content/catalog.json').readAsStringSync())
          as Map<String, dynamic>)['songs'] as List)
        Map<String, dynamic>.from(s as Map),
    ];

void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() => app.dispose());

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: app.overrides);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const SingLearnApp(),
    ));
    await settleIo(tester);
    return container;
  }

  testWidgets('register -> placement test -> home with suggestions', (tester) async {
    await pumpApp(tester);
    expect(find.text('Đăng nhập'), findsWidgets);

    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await settleIo(tester);
    await tester.enterText(find.byKey(const Key('reg-name')), 'Lan');
    await tester.enterText(find.byKey(const Key('reg-email')), 'lan@test.vn');
    await tester.enterText(find.byKey(const Key('reg-password')), 'secret1');
    await tester.enterText(find.byKey(const Key('reg-confirm')), 'secret2');
    await tester.tap(find.byKey(const Key('reg-submit')));
    await settleIo(tester);
    expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('reg-confirm')), 'secret1');
    await tester.tap(find.byKey(const Key('reg-submit')));
    expect(await settleUntil(tester, () => find.byKey(const Key('placement-next')).evaluate().isNotEmpty),
        isTrue, reason: 'router moves a new account to the placement test');

    // Placement: answer every question correctly -> B2.
    for (final q in placementQuestions) {
      await tester.tap(find.text(q.options[q.answer]));
      await tester.pump();
      await tester.tap(find.byKey(const Key('placement-next')));
      await tester.pump();
    }
    expect(find.byKey(const Key('placement-result')), findsOneWidget);
    expect(find.text('Trình độ gợi ý: B2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('placement-accept')));
    await settleUntil(tester, () => find.text('Xin chào, Lan!').evaluate().isNotEmpty);
    await settleIo(tester);

    expect(find.text('Xin chào, Lan!'), findsOneWidget);
    expect(find.text('Gợi ý cho trình độ B2'), findsOneWidget);
    expect(find.byKey(const Key('home-xp')), findsOneWidget);
    expect(app.auth.current!.level, 'B2');
    expect(app.auth.current!.isAdmin, isTrue, reason: 'first local account is admin');
  });

  testWidgets('wrong password shows an error; guest mode enters the app', (tester) async {
    await app.auth.signUp(email: 'a@b.vn', password: 'secret1', displayName: 'An');
    await app.auth.signOut();
    await pumpApp(tester);
    await tester.enterText(find.byKey(const Key('login-email')), 'a@b.vn');
    await tester.enterText(find.byKey(const Key('login-password')), 'wrong12');
    await tester.tap(find.byKey(const Key('login-submit')));
    await settleUntil(tester, () => find.text('Email hoặc mật khẩu không đúng').evaluate().isNotEmpty);
    expect(find.text('Email hoặc mật khẩu không đúng'), findsOneWidget);

    await tester.tap(find.byKey(const Key('guest-button')));
    await settleUntil(tester, () => find.text('Xin chào, Khách!').evaluate().isNotEmpty);
    expect(find.text('Xin chào, Khách!'), findsOneWidget);
  });

  testWidgets('library: search, level filter and navigation tabs', (tester) async {
    await app.signIn();
    await pumpApp(tester);
    await settleUntil(tester, () => find.text('Bài hát').evaluate().isNotEmpty);
    await tester.tap(find.text('Bài hát').last);
    final all = catalogSongs();
    await settleUntil(tester, () => find.text('${all.length} bài hát').evaluate().isNotEmpty);
    expect(find.text('${all.length} bài hát'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('library-search')), 'bethlehem');
    await settleIo(tester);
    expect(find.text('1 bài hát'), findsOneWidget);
    expect(find.text('O Little Town of Bethlehem'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('library-search')), '');
    await settleIo(tester);
    final b2 = find.widgetWithText(FilterChip, 'B2');
    await tester.ensureVisible(b2);
    await tester.pump();
    await tester.tap(b2);
    await settleIo(tester);
    expect(find.text('${all.where((s) => s['level'] == 'B2').length} bài hát'), findsOneWidget);
  });

  test('SongFilter folds Vietnamese accents and filters favorites', () {
    expect(SongFilter.foldForTest('Đồng Quê'), 'dong que');
  });
}
