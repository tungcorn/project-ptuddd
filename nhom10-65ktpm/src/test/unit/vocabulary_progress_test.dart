import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/events/app_event_bus.dart';
import 'package:singlearn/core/storage/local_store.dart';
import 'package:singlearn/core/sync/sync_service.dart';
import 'package:singlearn/features/progress/data/progress_service.dart';
import 'package:singlearn/features/progress/domain/progress_rules.dart';
import 'package:singlearn/features/vocabulary/data/vocabulary_repository.dart';
import 'package:singlearn/features/vocabulary/domain/dictionary.dart';
import 'package:singlearn/features/vocabulary/domain/saved_word.dart';
import 'package:singlearn/features/vocabulary/domain/sm2.dart';

import '../helpers.dart';

WordContext ctx(int line) => WordContext(
      songId: 'twinkle',
      songTitle: 'Twinkle',
      lineIndex: line,
      line: 'Twinkle, twinkle, little star,',
      startMs: line * 1000,
      endMs: line * 1000 + 900,
    );

void main() {
  late LocalStore store;
  late FakeRemote remote;
  late SyncService sync;
  late AppEventBus bus;
  late VocabularyRepository vocab;
  late ProgressService progress;
  late List<Future<int?>> recording;
  var now = DateTime(2026, 11, 16, 10);

  setUp(() async {
    now = DateTime(2026, 11, 16, 10);
    store = await openTestStore();
    remote = FakeRemote();
    sync = SyncService(store, remote);
    bus = AppEventBus();
    vocab = VocabularyRepository(
        store: store, sync: sync, bus: bus, uid: 'u1', clock: () => now);
    progress =
        ProgressService(store: store, sync: sync, uid: 'u1', clock: () => now);
    // Keep every record() Future so settle() waits for the XP writes
    // themselves instead of sleeping a fixed time (flaky under load).
    recording = [];
    bus.stream.listen((e) => recording.add(progress.record(e)));
  });
  tearDown(() => closeTestStore(store));

  Future<void> settle() async {
    // Broadcast events are delivered asynchronously: let them arrive.
    await Future<void>.delayed(Duration.zero);
    await Future.wait(recording);
  }

  test('save -> duplicate handling -> XP once per lemma', () async {
    Future<SaveWordOutcome> save(int line) => vocab.save(
          lemma: 'Star',
          ipa: '/stɑː/',
          pos: 'noun',
          meaning: 'ngôi sao',
          context: ctx(line),
        );
    expect(await save(0), SaveWordOutcome.created);
    expect(await save(0), SaveWordOutcome.alreadySaved);
    expect(await save(4), SaveWordOutcome.contextAdded);
    await settle();
    final words = await vocab.words();
    expect(words.single.id, 'star');
    expect(words.single.contexts.length, 2);
    expect((await progress.snapshot()).totalXp, 10,
        reason: 'XP only once for the lemma');

    await vocab.delete('star');
    expect(await vocab.words(), isEmpty);
    expect(await save(0), SaveWordOutcome.restored);
    await settle();
    expect((await progress.snapshot()).totalXp, 10,
        reason: 're-saving after delete earns nothing');
  });

  test('review updates SM-2 schedule and earns XP once per day', () async {
    await vocab.save(
        lemma: 'sky', ipa: '', pos: 'noun', meaning: 'bầu trời', context: ctx(3));
    expect((await vocab.due()).length, 1);
    final r1 = await vocab.review('sky', ReviewGrade.good);
    expect(r1.sm2.intervalDays, 1);
    expect(await vocab.due(), isEmpty, reason: 'not due until tomorrow');
    await vocab.review('sky', ReviewGrade.easy);
    await settle();
    expect((await progress.snapshot()).totalXp, 10 + 5);

    now = now.add(const Duration(days: 1));
    expect((await vocab.byId('sky'))!.sm2.repetitions, 2);
    await vocab.review('sky', ReviewGrade.forgot);
    await settle();
    final w = (await vocab.byId('sky'))!;
    expect(w.sm2.repetitions, 0);
    expect(w.lapses, 1);
    expect((await progress.snapshot()).totalXp, 15,
        reason: 'wrong review earns 0');
    expect((await progress.snapshot()).streak, 2);
  });

  test('progress ledger rejects duplicate event ids (retry safety)', () async {
    final e = LearningEvent(
      id: 'fill:twinkle:easy:2026-11-16',
      type: LearningEventType.fillBlankCompleted,
      uid: 'u1',
      at: now,
    );
    expect(await progress.record(e), 20);
    expect(await progress.record(e), isNull);
    final e2 = LearningEvent(
      id: 'pron:twinkle:1:2026-11-16',
      type: LearningEventType.pronunciationScored,
      uid: 'u1',
      data: {'score': 95},
      at: now,
    );
    final results =
        await Future.wait([progress.record(e2), progress.record(e2)]);
    expect(results.whereType<int>().length, 1);
    final snap = await progress.snapshot();
    expect(snap.totalXp, 25);
    expect(snap.badges.keys, contains(AchievementBadge.firstSong));
    expect(snap.week.last.xp, 25);
    expect(snap.week.last.pronunciationAvg, 95);
  });

  test('events of another user are ignored', () async {
    expect(
      await progress.record(LearningEvent(
          id: 'x', type: LearningEventType.wordSaved, uid: 'other')),
      isNull,
    );
  });

  test('guest data is not queued for cloud sync', () async {
    final guest =
        VocabularyRepository(store: store, sync: sync, bus: bus, uid: 'guest');
    await guest.save(lemma: 'boat', ipa: '', pos: 'noun', meaning: 'thuyền');
    expect(await sync.pendingCount(), 0);
    await vocab.save(lemma: 'boat', ipa: '', pos: 'noun', meaning: 'thuyền');
    await settle();
    expect(await sync.pendingCount(), greaterThan(0));
    expect(await sync.flush(), greaterThan(0));
    expect(remote.docs.keys, contains('users/u1/words/boat'));
  });

  group('bundled dictionary', () {
    final dict = SongDictionary.fromJsonString(
      File('assets/content/dictionary.json').readAsStringSync(),
    );

    test('maps inflected forms to lemmas', () {
      expect(dict.lookup('went').lemma, 'go');
      expect(dict.lookup('Feet').lemma, 'foot');
      expect(dict.lookup('stars').entry!.vi, isNotEmpty);
      expect(dict.lookup('You’re').found, isTrue);
    });

    test('rule-based fallback for forms outside the list', () {
      expect(SongDictionary.guessLemmas('wondering'), contains('wonder'));
      expect(SongDictionary.guessLemmas('skies'), contains('sky'));
      final r = dict.lookup('diamonds');
      expect(r.lemma, 'diamond');
      expect(r.found, isTrue);
      expect(dict.lookup('xyzzyq').found, isFalse);
    });
  });
}
