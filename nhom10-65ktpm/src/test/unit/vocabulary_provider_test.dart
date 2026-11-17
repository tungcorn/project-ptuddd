import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/core/storage/local_store.dart';

import '../helpers.dart';

void main() {
  late LocalStore store;
  late ProviderContainer container;

  setUp(() async {
    store = await openTestStore();
    container = ProviderContainer(overrides: [
      localStoreProvider.overrideWithValue(store),
      uidProvider.overrideWithValue('learner'),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await closeTestStore(store);
  });

  test('paused due query does not miss a saved word', () async {
    final repo = container.read(vocabularyRepositoryProvider);
    final iterator = StreamIterator(liveQuery(repo.watch(), repo.due));
    addTearDown(iterator.cancel);
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, isEmpty);
    // StreamIterator pauses after each value, like an offscreen tab's
    // subscription. The storage watcher must already be listening here.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.save(lemma: 'peace', ipa: '', pos: 'noun', meaning: 'hoa binh');
    expect((await repo.due()).map((word) => word.id), contains('peace'));
    expect(await iterator.moveNext().timeout(const Duration(seconds: 3)), isTrue);
    expect(iterator.current.map((word) => word.id), contains('peace'));
  });

  test('due provider refreshes after saving a word with real Hive', () async {
    final refreshed = Completer<void>();
    final subscription = container.listen(dueWordsProvider, (_, next) {
      if (next.value?.any((word) => word.id == 'peace') == true &&
          !refreshed.isCompleted) {
        refreshed.complete();
      }
    });
    addTearDown(subscription.close);
    expect(await container.read(dueWordsProvider.future), isEmpty);
    // Simulate the home tab remaining mounted while the learner opens a song.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final repo = container.read(vocabularyRepositoryProvider);
    await repo.save(lemma: 'peace', ipa: '', pos: 'noun', meaning: 'hoa binh');
    expect((await repo.due()).map((word) => word.id), contains('peace'));
    await refreshed.future.timeout(const Duration(seconds: 3));
  });
}
