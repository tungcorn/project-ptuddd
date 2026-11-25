import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/events/app_event_bus.dart';
import 'package:singlearn/features/auth/presentation/auth_screens.dart';
import 'package:singlearn/features/vocabulary/domain/saved_word.dart';
import 'package:singlearn/features/vocabulary/domain/sm2.dart';
import 'package:singlearn/singlearn_app.dart';

import 'harness.dart';

/// One learner's data, different for every account so a leak is visible.
class _Account {
  const _Account(this.email, this.name, this.xp, this.word, {this.today = true});

  final String email;
  final String name;
  final int xp;
  final String word;

  /// Studied today (streak 1) or only a week ago (streak 0).
  final bool today;
}

const _a = _Account('an@test.vn', 'An Nguyễn', 120, 'star');
const _b = _Account('binh@test.vn', 'Bình Trần', 35, 'moon', today: false);

void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() => app.dispose());

  /// Registers [account] and stores its XP ledger and saved word locally,
  /// as earlier learning on this device would have.
  Future<void> seed(_Account account, String level) async {
    final user = await app.auth.signUp(
      email: account.email,
      password: 'secret1',
      displayName: account.name,
    );
    await app.auth.updateProfile(level: level);
    final at = account.today
        ? DateTime.now()
        : DateTime.now().subtract(const Duration(days: 7));
    await app.store.put('xp_ledger_${user.uid}', 'seed', {
      'id': 'seed',
      'type': 'exerciseCompleted',
      'xp': account.xp,
      'at': at.millisecondsSinceEpoch,
      'day': dayKey(at),
      'data': const <String, dynamic>{},
      'updatedAt': at.millisecondsSinceEpoch,
    });
    await app.store.put(
      'words_${user.uid}',
      account.word,
      SavedWord(
        id: account.word,
        word: account.word,
        ipa: '',
        pos: 'noun',
        meaning: 'nghĩa của ${account.word}',
        sm2: Sm2State(dueAt: DateTime(2030)),
        createdAt: 1,
        updatedAt: 1,
      ).toJson(),
    );
    await app.auth.signOut();
  }

  Finder tab(String label) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );

  Future<void> open(WidgetTester tester, String label) async {
    await tester.tap(tab(label));
    await settleIo(tester);
  }

  Future<void> signIn(WidgetTester tester, _Account account) async {
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('login-email')), account.email);
    await tester.enterText(find.byKey(const Key('login-password')), 'secret1');
    await tester.tap(find.byKey(const Key('login-submit')));
    expect(
      await settleUntil(tester, () => tab('Trang chủ').evaluate().isNotEmpty),
      isTrue,
      reason: 'signed in as ${account.email}',
    );
    await settleIo(tester);
  }

  Future<void> signOutFromProfile(WidgetTester tester) async {
    await open(tester, 'Hồ sơ');
    final signOut = find.byKey(const Key('sign-out'));
    await tester.scrollUntilVisible(
      signOut,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(signOut);
    await settleIo(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
    expect(
      await settleUntil(
        tester,
        () => find.byKey(const Key('login-email')).evaluate().isNotEmpty,
      ),
      isTrue,
      reason: 'back on the login screen',
    );
    await settleIo(tester);
  }

  /// Home, vocabulary and profile of the running app show [shown] only.
  Future<void> expectOnly(
    WidgetTester tester,
    _Account shown,
    _Account hidden, {
    required bool admin,
  }) async {
    await open(tester, 'Trang chủ');
    expect(find.text('Xin chào, ${shown.name}!'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('home-xp'))).data,
      '${shown.xp}',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('home-streak'))).data,
      shown.today ? '1' : '0',
    );

    await open(tester, 'Từ vựng');
    expect(find.byKey(Key('word-${shown.word}')), findsOneWidget);
    expect(find.byKey(Key('word-${hidden.word}')), findsNothing);

    await open(tester, 'Hồ sơ');
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-name'))).data,
      shown.name,
    );
    expect(find.text(shown.email), findsOneWidget);
    expect(find.text(hidden.name), findsNothing);
    expect(find.text(hidden.email), findsNothing);
    expect(find.byKey(const Key('admin-entry')), admin ? findsOneWidget : findsNothing);
  }

  testWidgets('one running app: A -> sign out -> B -> sign out -> A shows '
      'only the signed-in account', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await seed(_a, 'A1'); // first local account: admin
    await seed(_b, 'A2');

    // Mounted once: every switch below happens in the same container and
    // widget tree, so stale providers or screens would show up here.
    final container = ProviderContainer(overrides: app.overrides);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SingLearnApp(),
      ),
    );
    await settleIo(tester);

    await signIn(tester, _a);
    await expectOnly(tester, _a, _b, admin: true);

    await signOutFromProfile(tester);
    expect(find.text(_a.name), findsNothing);
    expect(find.byKey(const Key('home-xp')), findsNothing);

    await signIn(tester, _b);
    await expectOnly(tester, _b, _a, admin: false);

    await signOutFromProfile(tester);
    await signIn(tester, _a);
    await expectOnly(tester, _a, _b, admin: true);

    // Guest after an account: no profile, friend code or words of A.
    await signOutFromProfile(tester);
    await tester.tap(find.byKey(const Key('guest-button')));
    expect(
      await settleUntil(
        tester,
        () => find.text('Xin chào, Khách!').evaluate().isNotEmpty,
      ),
      isTrue,
    );
    await settleIo(tester);
    expect(tester.widget<Text>(find.byKey(const Key('home-xp'))).data, '0');
    await open(tester, 'Từ vựng');
    expect(find.byKey(Key('word-${_a.word}')), findsNothing);
    await open(tester, 'Hồ sơ');
    expect(find.text(_a.name), findsNothing);
    expect(find.textContaining('Mã kết bạn:'), findsNothing);
    expect(
      find.text('Đăng ký tài khoản để sử dụng (khách chỉ học trên máy).'),
      findsOneWidget,
    );
    expect(find.text('Thoát chế độ khách'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ForgotPasswordScreen clearly shows demo mode cloud requirement', (tester) async {
    await app.pumpScreen(tester, const ForgotPasswordScreen());
    await settleIo(tester);

    expect(find.text('Quên mật khẩu'), findsOneWidget);
    expect(
      find.textContaining('Chế độ demo không gửi được email đặt lại mật khẩu'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Chức năng này hoạt động khi ứng dụng được cấu hình Firebase.'),
      findsOneWidget,
    );

    // Button is disabled in demo mode
    final submitButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Gửi email đặt lại'),
    );
    expect(submitButton.onPressed, isNull);
  });
}
