import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/ui/widgets.dart';
import '../../songs/domain/lrc_parser.dart';
import '../../songs/domain/song.dart';
import '../data/admin_media_store.dart';
import '../domain/song_editor_logic.dart';
import 'lyrics_sync_preview_screen.dart';

/// Admin form to create ([songId] == null) or edit a song: metadata, audio,
/// cover, LRC lyrics, Vietnamese translations, and a live sync check before
/// publishing (section 7.12).
class SongEditorScreen extends ConsumerStatefulWidget {
  const SongEditorScreen({super.key, this.songId});

  final String? songId;

  @override
  ConsumerState<SongEditorScreen> createState() => _SongEditorScreenState();
}

class _SongEditorScreenState extends ConsumerState<SongEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _artist = TextEditingController();
  final _license = TextEditingController();
  final _keywords = TextEditingController();
  final _audio = TextEditingController();
  final _cover = TextEditingController();
  final _lrc = TextEditingController();
  final List<TextEditingController> _translations = [];
  List<LrcLine> _lines = const [];

  String _level = cefrLevels.first;
  final Set<String> _topics = {};
  String _genre = genreLabels.keys.first;
  bool _hidden = false;

  Song? _base;
  bool _loading = false;
  String? _loadError;
  bool _saving = false;
  Duration _detectedDuration = Duration.zero;

  bool get _isNew => widget.songId == null;

  @override
  void initState() {
    super.initState();
    _lrc.addListener(_syncTranslations);
    if (!_isNew) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(songRepositoryProvider);
      final song = await repo.byId(widget.songId!);
      if (song == null) throw StateError('Không tìm thấy bài hát "${widget.songId}"');
      var lrc = '';
      try {
        lrc = await repo.lrcSource(song);
      } catch (_) {
        // Lyrics unreachable (offline URL): the admin can paste them again.
      }
      if (!mounted) return;
      _base = song;
      _title.text = song.title;
      _artist.text = song.artist;
      _license.text = song.license;
      _keywords.text = song.keywords.join(', ');
      _audio.text = song.audio;
      _cover.text = song.cover ?? '';
      _level = cefrLevels.contains(song.level) ? song.level : cefrLevels.first;
      _topics
        ..clear()
        ..addAll(song.topics);
      _genre = song.genre;
      _hidden = song.hidden;
      _lrc.text = lrc;
      final tr = resizeTranslations(song.translations, _lines.length);
      for (var i = 0; i < tr.length; i++) {
        _translations[i].text = tr[i];
      }
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = '$e';
        });
      }
    }
  }

  /// Keeps one translation field per parsed LRC line (by line index).
  void _syncTranslations() {
    final lines = LrcParser.parse(_lrc.text).lines;
    final n = lines.length;
    while (_translations.length < n) {
      _translations.add(TextEditingController());
    }
    while (_translations.length > n) {
      _translations.removeLast().dispose();
    }
    setState(() => _lines = lines);
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _artist,
      _license,
      _keywords,
      _audio,
      _cover,
      _lrc,
      ..._translations,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  SongDraft _draft() => SongDraft(
    title: _title.text,
    artist: _artist.text,
    level: _level,
    topics: topicLabels.keys.where(_topics.contains).toList()
      ..addAll(_topics.where((t) => !topicLabels.containsKey(t))),
    genre: _genre,
    license: _license.text,
    keywords: parseKeywords(_keywords.text),
    audio: _audio.text.trim(),
    cover: _cover.text.trim(),
    lrcText: _lrc.text,
    translations: [for (final c in _translations) c.text.trim()],
    hidden: _hidden,
  );

  Future<String?> _pick(FileType type, {List<String>? extensions}) async {
    try {
      final files = await FilePicker.pickFiles(type: type, allowedExtensions: extensions);
      if (files.isEmpty) return null;
      final path = files.first.path;
      if (path == null) showMessage('Không đọc được tệp đã chọn');
      return path;
    } catch (e) {
      showMessage('Không mở được trình chọn tệp: $e');
      return null;
    }
  }

  Future<void> _pickAudio() async {
    final path = await _pick(FileType.audio);
    if (path != null) setState(() => _audio.text = path);
  }

  Future<void> _pickCover() async {
    final path = await _pick(FileType.image);
    if (path != null) setState(() => _cover.text = path);
  }

  Future<void> _pickLrc() async {
    final path = await _pick(FileType.custom, extensions: const ['lrc', 'txt']);
    if (path == null) return;
    try {
      final text = await File(path).readAsString();
      _lrc.text = text;
      if (LrcParser.parse(text).lines.isEmpty) {
        showMessage('Tệp không có dòng LRC hợp lệ');
      }
    } catch (e) {
      showMessage('Không đọc được tệp LRC: $e');
    }
  }

  Future<void> _openPreview() async {
    final d = _draft();
    final problem =
        mediaRefError(d.audio, required: true, label: 'tệp nhạc') ?? lrcError(d.lrcText);
    if (problem != null) {
      showMessage(problem);
      return;
    }
    final temp = d.toSong(
      _base?.id ?? (slugify(d.title)),
      base: _base,
      durationMs: _base?.durationMs ?? 0,
    );
    final result = await Navigator.of(context).push<SyncPreviewResult>(
      MaterialPageRoute(builder: (_) => LyricsSyncPreviewScreen(song: temp)),
    );
    if (result == null || !mounted) return;
    if (result.duration > Duration.zero) _detectedDuration = result.duration;
    if (result.lrcText != _lrc.text) {
      _lrc.text = result.lrcText;
      showMessage('Đã cập nhật mốc thời gian lời bài hát');
    }
  }

  Future<bool> _confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Lưu bài hát?'),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Quay lại')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vẫn lưu')),
          ],
        ),
      ) ??
      false;

  Future<void> _save() async {
    if (_saving) return;
    final formOk = _formKey.currentState?.validate() ?? false;
    final draft = _draft();
    final check = validateDraft(draft);
    if (!formOk || !check.ok) {
      showMessage(check.errors.isEmpty ? 'Vui lòng kiểm tra lại các trường' : check.errors.first);
      return;
    }
    if (check.warnings.isNotEmpty &&
        !await _confirm(
          '${check.warnings.join('\n')}.\nNgười học sẽ không thấy nghĩa của các câu này.',
        )) {
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(songRepositoryProvider);
      final base = _base;
      final id = base?.id ?? newSongId(draft.title, (await repo.allSongs()).map((s) => s.id));
      final media = AdminMediaStore(uploader: ref.read(mediaUploaderProvider));
      final audio = await media.persist(draft.audio, id);
      final cover = draft.cover.isEmpty ? '' : await media.persist(draft.cover, id);
      final durationMs = _detectedDuration > Duration.zero
          ? _detectedDuration.inMilliseconds
          : (base != null && base.audio == draft.audio ? base.durationMs : 0);
      final song = SongDraft(
        title: draft.title,
        artist: draft.artist,
        level: draft.level,
        topics: draft.topics,
        genre: draft.genre,
        license: draft.license,
        keywords: draft.keywords,
        audio: audio,
        cover: cover,
        lrcText: draft.lrcText,
        translations: draft.translations,
        hidden: draft.hidden,
      ).toSong(id, base: base, durationMs: durationMs);
      final saved = await repo.save(song);
      _base = saved;
      showMessage(
        saved.hidden ? 'Đã lưu "${saved.title}" (đang ẩn)' : 'Đã lưu và xuất bản "${saved.title}"',
      );
      if (mounted) await Navigator.of(context).maybePop();
    } catch (e) {
      showMessage('Lưu thất bại: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(authStateProvider) is AsyncLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý bài hát')),
        body: const LoadingView(),
      );
    }
    final user = ref.watch(currentUserProvider);
    if (user == null || !user.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý bài hát')),
        body: const EmptyState(
          icon: Icons.lock_outline,
          title: 'Chỉ quản trị viên nội dung mới truy cập được',
        ),
      );
    }
    final title = _isNew ? 'Thêm bài hát' : 'Sửa bài hát';
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const LoadingView(),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ErrorView(error: _loadError!),
      );
    }

    final t = Theme.of(context);
    final genres = {...genreLabels, if (!genreLabels.containsKey(_genre)) _genre: _genre};
    const gap = SizedBox(height: 12);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Kiểm tra lời đồng bộ',
            onPressed: _saving ? null : _openPreview,
            icon: const Icon(Icons.play_circle_outline),
          ),
          TextButton(
            key: const ValueKey('save_song'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Lưu'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('Thông tin bài hát'),
              TextFormField(
                key: const ValueKey('field_title'),
                controller: _title,
                decoration: const InputDecoration(labelText: 'Tên bài hát *'),
                validator: (v) => requiredText(v, 'tên bài hát'),
              ),
              gap,
              TextFormField(
                key: const ValueKey('field_artist'),
                controller: _artist,
                decoration: const InputDecoration(labelText: 'Ca sĩ / tác giả *'),
                validator: (v) => requiredText(v, 'ca sĩ / tác giả'),
              ),
              gap,
              Text('Trình độ', style: t.textTheme.labelLarge),
              Wrap(
                spacing: 8,
                children: [
                  for (final l in cefrLevels)
                    ChoiceChip(
                      label: Text(l),
                      selected: _level == l,
                      onSelected: (_) => setState(() => _level = l),
                    ),
                ],
              ),
              gap,
              Text('Chủ đề', style: t.textTheme.labelLarge),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final e in topicLabels.entries)
                    FilterChip(
                      label: Text(e.value),
                      selected: _topics.contains(e.key),
                      onSelected: (on) =>
                          setState(() => on ? _topics.add(e.key) : _topics.remove(e.key)),
                    ),
                ],
              ),
              gap,
              DropdownButtonFormField<String>(
                initialValue: _genre,
                decoration: const InputDecoration(labelText: 'Thể loại'),
                items: [
                  for (final e in genres.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _genre = v ?? _genre),
              ),
              gap,
              TextFormField(
                key: const ValueKey('field_keywords'),
                controller: _keywords,
                decoration: const InputDecoration(
                  labelText: 'Từ khóa',
                  helperText: 'Phân cách bằng dấu phẩy, ví dụ: family, mother, love',
                ),
              ),
              gap,
              TextFormField(
                key: const ValueKey('field_license'),
                controller: _license,
                decoration: const InputDecoration(
                  labelText: 'Nguồn / giấy phép *',
                  helperText: 'Chỉ đăng nội dung có bản quyền hoặc giấy phép (vd. Public domain, CC BY 4.0)',
                  helperMaxLines: 2,
                ),
                validator: (v) => requiredText(v, 'nguồn / giấy phép'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ẩn bài hát'),
                subtitle: const Text('Bài đang ẩn không hiển thị với người học'),
                value: _hidden,
                onChanged: (v) => setState(() => _hidden = v),
              ),
              const SectionTitle('Tệp nhạc và ảnh bìa'),
              TextFormField(
                key: const ValueKey('field_audio'),
                controller: _audio,
                decoration: InputDecoration(
                  labelText: 'Tệp nhạc *',
                  hintText: 'https://... hoặc chọn tệp',
                  suffixIcon: IconButton(
                    tooltip: 'Chọn tệp nhạc',
                    onPressed: _pickAudio,
                    icon: const Icon(Icons.audio_file_outlined),
                  ),
                ),
                validator: (v) => mediaRefError(v, required: true, label: 'tệp nhạc'),
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('field_cover'),
                      controller: _cover,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Ảnh bìa',
                        hintText: 'https://... hoặc chọn ảnh',
                        suffixIcon: IconButton(
                          tooltip: 'Chọn ảnh bìa',
                          onPressed: _pickCover,
                          icon: const Icon(Icons.image_outlined),
                        ),
                      ),
                      validator: (v) => mediaRefError(v, required: false, label: 'ảnh bìa'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SongCover(
                    song: Song(
                      id: 'cover',
                      title: '',
                      artist: '',
                      level: _level,
                      topics: const [],
                      genre: _genre,
                      durationMs: 0,
                      audio: '',
                      cover: _cover.text.trim().isEmpty ? null : _cover.text.trim(),
                      color: _base?.color ?? '#00796b',
                    ),
                  ),
                ],
              ),
              SectionTitle(
                'Lời bài hát (LRC)',
                trailing: TextButton.icon(
                  onPressed: _pickLrc,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Mở tệp .lrc'),
                ),
              ),
              TextFormField(
                key: const ValueKey('field_lrc'),
                controller: _lrc,
                minLines: 6,
                maxLines: 14,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  hintText: '[00:01.00]Dòng lời thứ nhất\n[00:05.50]Dòng lời thứ hai',
                  helperText: '${_lines.length} dòng lời hợp lệ',
                  alignLabelWithHint: true,
                ),
                validator: lrcError,
              ),
              gap,
              OutlinedButton.icon(
                key: const ValueKey('open_preview'),
                onPressed: _saving ? null : _openPreview,
                icon: const Icon(Icons.graphic_eq),
                label: const Text('Kiểm tra lời đồng bộ'),
              ),
              SectionTitle('Bản dịch tiếng Việt (${_lines.length} câu)'),
              if (_lines.isEmpty)
                Text('Nhập lời LRC để thêm bản dịch cho từng câu.', style: t.textTheme.bodySmall)
              else
                for (var i = 0; i < _lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextFormField(
                      key: ValueKey('field_tr_$i'),
                      controller: _translations[i],
                      decoration: InputDecoration(
                        labelText: '${i + 1}. ${_lines[i].text}',
                        isDense: true,
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_hidden ? 'Lưu (đang ẩn)' : 'Lưu và xuất bản'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
