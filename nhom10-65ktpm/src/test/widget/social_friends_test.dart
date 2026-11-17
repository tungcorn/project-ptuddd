import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/features/auth/domain/app_user.dart';
import 'package:singlearn/features/social/data/social_repository.dart';
import 'package:singlearn/features/social/domain/social_models.dart';
import 'package:singlearn/features/social/presentation/friends_screen.dart';

import 'harness.dart';

PublicProfile profileOf(AppUser u) => PublicProfile(
      uid: u.uid,
      displayName: u.displayName,
      userCode: u.userCode,
      email: u.email,
    );

/// Drives async I/O (file reads) until [finder] matches (machine speed varies a lot).
Future<void> pumpUntil(WidgetTester tester, Finder finder, {int max = 200}) async {
  for (var i = 0; i < max && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump();
}


void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() => app.dispose());

  testWidgets('A finds B by email, sends a request, B accepts -> friends', (tester) async {
    late AppUser a;
    late AppUser b;
    late LocalSocialRepository repo;
    await tester.runAsync(() async {
      repo = LocalSocialRepository(app.store);
      b = await app.auth.signUp(email: 'binh@test.vn', password: 'secret1', displayName: 'Bình');
      await app.auth.signOut();
      await app.signIn(email: 'an@test.vn', name: 'An');
      a = app.auth.current!;
      // Public profiles are normally published by the app shell on sign-in.
      await repo.upsertProfile(profileOf(a));
      await repo.upsertProfile(profileOf(b));
    });

    await app.pumpScreen(tester, const FriendsScreen());
    await pumpUntil(tester, find.text('Bạn bè (0)'));

    expect(find.text(a.userCode), findsOneWidget);
    expect(find.text('Bạn bè (0)'), findsOneWidget);

    // Invalid code is rejected before searching.
    await tester.enterText(find.byKey(const Key('friend-search')), 'ABC');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(find.textContaining('6 ký tự'), findsWidgets);

    await tester.enterText(find.byKey(const Key('friend-search')), 'binh@test.vn');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpUntil(tester, find.text('Kết bạn'));
    expect(find.text('Bình'), findsOneWidget);

    await tester.tap(find.text('Kết bạn'));
    await pumpUntil(tester, find.text('Đang chờ chấp nhận'));
    expect(find.text('Đã gửi lời mời (1)'), findsOneWidget);
    expect(find.text('Đang chờ chấp nhận'), findsOneWidget);

    final pending = await tester.runAsync(() => repo.friendships(a.uid));
    expect(pending!.single.status, FriendStatus.pending);
    expect(pending.single.requestedBy, a.uid);

    // B accepts (as B, through the repository).
    await tester.runAsync(() => repo.respondFriendRequest(b.uid, a.uid, accept: true));
    await pumpUntil(tester, find.byTooltip('Thách đấu'));

    expect(find.text('Bạn bè (1)'), findsOneWidget);
    expect(find.text('Bình'), findsOneWidget);
    expect(find.text('Đang chờ chấp nhận'), findsNothing);
    expect(find.byTooltip('Thách đấu'), findsOneWidget);

    // Searching B again explains they are already friends.
    await tester.enterText(find.byKey(const Key('friend-search')), b.userCode);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpUntil(tester, find.text('Hai bạn đã là bạn bè'));
    expect(find.text('Hai bạn đã là bạn bè'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('guest sees sign-in explanation', (tester) async {
    await tester.runAsync(() async {
      await app.auth.continueAsGuest();
    });
    await app.pumpScreen(tester, const FriendsScreen());
    await pumpUntil(tester, find.text('Cần đăng nhập để dùng tính năng cộng đồng'));
    expect(find.text('Cần đăng nhập để dùng tính năng cộng đồng'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
