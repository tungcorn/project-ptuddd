import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/core/ui/theme.dart';
import 'package:singlearn/features/profile/presentation/settings_screen.dart';

import '../helpers.dart' show FakeRemote;
import 'harness.dart';

void main() {
  testWidgets('"Đồng bộ ngay" reports what is still waiting, not a false '
      'success', (tester) async {
    // Tall enough for the whole settings list to be built.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await TestApp.create();
    await app.signIn();
    final uid = app.auth.current!.uid;
    final remote = FakeRemote()..online = false;
    final container = ProviderContainer(
      overrides: [
        ...app.overrides,
        remoteStoreProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);
    final sync = container.read(syncServiceProvider);
    await sync.enqueue('users/$uid/words/a', {'v': 1});
    await sync.enqueue('users/$uid/words/b', {'v': 2});
    // Another account's write on this device is neither counted nor sent.
    await sync.enqueue('users/someone-else/words/c', {'v': 3});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const SettingsScreen(),
        ),
      ),
    );
    expect(
      await settleUntil(
        tester,
        () => find.text('Thay đổi chờ đồng bộ: 2').evaluate().isNotEmpty,
      ),
      isTrue,
    );

    // Offline: sending fails, the message says so.
    await tester.tap(find.byTooltip('Đồng bộ ngay'));
    final offline =
        'còn 2 thay đổi chưa đồng bộ. Kiểm tra kết nối rồi thử lại.';
    expect(
      await settleUntil(tester, () => find.text(offline).evaluate().isNotEmpty),
      isTrue,
    );
    expect(find.textContaining('Đã đồng bộ'), findsNothing);
    expect(remote.writes, 0);

    // Back online: both writes go, the count drops to 0.
    remote.online = true;
    await tester.tap(find.byTooltip('Đồng bộ ngay'));
    expect(
      await settleUntil(
        tester,
        () => find.text('Đã đồng bộ 2 thay đổi').evaluate().isNotEmpty,
      ),
      isTrue,
    );
    expect(
      await settleUntil(
        tester,
        () => find.text('Thay đổi chờ đồng bộ: 0').evaluate().isNotEmpty,
      ),
      isTrue,
    );
    expect(remote.docs.keys, ['users/$uid/words/a', 'users/$uid/words/b']);
  });
}
