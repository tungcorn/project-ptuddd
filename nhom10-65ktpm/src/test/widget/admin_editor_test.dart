import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/features/admin/presentation/song_editor_screen.dart';

import 'harness.dart';

const _lrc = '[00:01.00]Hello my friend\n[00:05.00]How are you\n[00:09.00]\n';

Future<void> _type(WidgetTester tester, String key, String text) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

Future<void> _fillNewSong(WidgetTester tester) async {
  await _type(tester, 'field_title', 'Bạn Thân Mến');
  await _type(tester, 'field_artist', 'Nhóm 10');
  await _type(tester, 'field_keywords', 'friend, hello');
  await _type(tester, 'field_license', 'CC BY 4.0');
  await _type(tester, 'field_audio', 'https://example.com/ban-than.mp3');
  await _type(tester, 'field_lrc', _lrc);
}

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

  testWidgets('creates a new song with pasted LRC, URL audio and translations', (tester) async {
    final c = await app.pumpScreen(tester, const SongEditorScreen());
    final allSub = c.listen(allSongsProvider, (_, _) {});
    await _settleUntil(tester, () => _shown('Thêm bài hát') && allSub.read().value != null);
    expect(find.text('Thêm bài hát'), findsOneWidget);

    await _fillNewSong(tester);
    // One translation field per parsed LRC line.
    expect(find.byKey(const ValueKey('field_tr_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('field_tr_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('field_tr_2')), findsNothing);
    await _type(tester, 'field_tr_0', 'Xin chào bạn tôi');
    await _type(tester, 'field_tr_1', 'Bạn có khỏe không');

    await tester.tap(find.byKey(const ValueKey('save_song')));
    await _settleUntil(tester, () => allSub.read().value!.any((s) => s.title == 'Bạn Thân Mến'));
    final all = allSub.read().value!;
    final song = all.singleWhere((s) => s.title == 'Bạn Thân Mến');
    expect(song.id, startsWith('ban-than-men-'));
    expect(song.artist, 'Nhóm 10');
    expect(song.audio, 'https://example.com/ban-than.mp3');
    expect(song.lrcText, _lrc);
    expect(song.translations, ['Xin chào bạn tôi', 'Bạn có khỏe không']);
    expect(song.keywords, ['friend', 'hello']);
    expect(song.license, 'CC BY 4.0');
    expect(song.level, 'A1');
    expect(song.hidden, isFalse);
    expect(song.bundled, isFalse);

    final lyrics = await tester.runAsync(() => c.read(songRepositoryProvider).lyrics(song));
    expect(lyrics!.lines.map((l) => l.vi), ['Xin chào bạn tôi', 'Bạn có khỏe không']);
  });

  testWidgets('blocks saving when required fields are missing', (tester) async {
    final c = await app.pumpScreen(tester, const SongEditorScreen());
    await _settleUntil(tester, () => _shown('Thêm bài hát'));
    await _type(tester, 'field_title', 'Thiếu dữ liệu');
    await tester.tap(find.byKey(const ValueKey('save_song')));
    await settleIo(tester, rounds: 4);
    expect(find.text('Vui lòng nhập nguồn / giấy phép'), findsOneWidget);
    final all = await tester.runAsync(() => c.read(songRepositoryProvider).allSongs());
    expect(all!.where((s) => s.title == 'Thiếu dữ liệu'), isEmpty);
  });

  testWidgets('live sync preview re-times a line and returns the LRC to the form', (tester) async {
    await app.pumpScreen(tester, const SongEditorScreen());
    await _settleUntil(tester, () => _shown('Thêm bài hát'));
    await _fillNewSong(tester);

    final open = find.byKey(const ValueKey('open_preview'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await _settleUntil(tester, () => app.audio.playing);
    await tester.pump(const Duration(seconds: 1)); // finish the route transition
    expect(find.text('Kiểm tra lời đồng bộ'), findsWidgets);
    expect(app.audio.loadedSource, 'https://example.com/ban-than.mp3');
    expect(app.audio.log.any((e) => e.startsWith('load:') && e.contains('__preview')), isTrue);
    expect(app.audio.playing, isTrue);

    // Select line 2 (seeks to 00:05), play on 1.5 s and mark its start.
    await tester.tap(find.byKey(const ValueKey('preview_line_1')));
    await tester.pump();
    app.audio.advance(const Duration(milliseconds: 1500));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('mark_time')));
    await tester.pump();
    expect(find.text('[00:06.50]'), findsOneWidget);

    await tester.tap(find.text('Xong'));
    await settleIo(tester, rounds: 4);
    await tester.pump(const Duration(seconds: 1));
    final field = tester.widget<TextFormField>(find.byKey(const ValueKey('field_lrc')));
    expect(field.controller!.text, contains('[00:06.50]How are you'));
    expect(field.controller!.text, contains('[00:01.00]Hello my friend'));
  });
}
