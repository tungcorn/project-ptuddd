import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/features/admin/presentation/admin_songs_screen.dart';

import 'harness.dart';

/// Pumps real I/O until [done] holds (CI machines can be slow).
Future<void> _settleUntil(WidgetTester tester, bool Function() done, {int max = 80}) async {
  for (var i = 0; i < max && !done(); i++) {
    await settleIo(tester, rounds: 1);
  }
  await settleIo(tester, rounds: 2);
}

bool _shown(String text) => find.text(text).evaluate().isNotEmpty;

void main() {
  late TestApp app;

  setUp(() async {
    app = await TestApp.create();
    await app.signIn(); // first local account is the content admin
  });
  tearDown(() => app.dispose());

  testWidgets('hiding a song removes it from songsProvider but not allSongsProvider', (
    tester,
  ) async {
    final c = await app.pumpScreen(tester, const AdminSongsScreen());
    final visibleSub = c.listen(songsProvider, (_, _) {});
    final allSub = c.listen(allSongsProvider, (_, _) {});
    await _settleUntil(
      tester,
      () =>
          allSub.read().value != null &&
          visibleSub.read().value != null &&
          _shown('Quản lý bài hát') &&
          find.byType(ListTile).evaluate().isNotEmpty,
    );

    final first = allSub.read().value!.first;
    expect(first.hidden, isFalse);
    expect(find.text('Đang ẩn'), findsNothing);
    final toggle = find.byKey(ValueKey('toggle_hidden_${first.id}'));

    await tester.tap(toggle);
    await _settleUntil(
      tester,
      () =>
          _shown('Đang ẩn') &&
          toggle.evaluate().isNotEmpty &&
          visibleSub.read().value!.every((s) => s.id != first.id),
    );

    expect(find.text('Đang ẩn'), findsOneWidget);
    expect(visibleSub.read().value!.map((s) => s.id), isNot(contains(first.id)));
    expect(allSub.read().value!.singleWhere((s) => s.id == first.id).hidden, isTrue);

    // Show it again.
    await tester.tap(toggle);
    await _settleUntil(
      tester,
      () =>
          !_shown('Đang ẩn') &&
          toggle.evaluate().isNotEmpty &&
          visibleSub.read().value!.any((s) => s.id == first.id),
    );
    expect(find.text('Đang ẩn'), findsNothing);
    expect(visibleSub.read().value!.map((s) => s.id), contains(first.id));
  });

  testWidgets('non-admins see a guard message', (tester) async {
    await tester.runAsync(() async {
      await app.auth.signOut();
      await app.signIn(email: 'learner@test.vn', name: 'Học viên');
    });
    final c = await app.pumpScreen(tester, const AdminSongsScreen());
    final userSub = c.listen(currentUserProvider, (_, _) {});
    await _settleUntil(tester, () => userSub.read() != null);
    expect(userSub.read()!.isAdmin, isFalse);
    expect(find.text('Chỉ quản trị viên nội dung mới truy cập được'), findsOneWidget);
  });
}
