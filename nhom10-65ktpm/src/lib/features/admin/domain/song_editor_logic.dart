import 'dart:math';

import '../../songs/domain/lrc_parser.dart';
import '../../songs/domain/song.dart';

const _vnFrom = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _vnTo = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

/// URL-safe id fragment: lowercase ASCII, Vietnamese accents removed, other
/// characters collapsed to `-`. Returns `song` when nothing is left.
String slugify(String input) {
  final buf = StringBuffer();
  for (final ch in input.toLowerCase().split('')) {
    final i = _vnFrom.indexOf(ch);
    buf.write(i >= 0 ? _vnTo[i] : ch);
  }
  final slug = buf
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) return 'song';
  return slug.length > 40 ? slug.substring(0, 40).replaceAll(RegExp(r'-+$'), '') : slug;
}

/// New song id: slug of [title] + a short random suffix, unique among
/// [existingIds].
String newSongId(String title, Iterable<String> existingIds, {Random? random}) {
  final rnd = random ?? Random();
  final taken = existingIds.toSet();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final base = slugify(title);
  while (true) {
    final suffix = List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join();
    final id = '$base-$suffix';
    if (!taken.contains(id)) return id;
  }
}

/// Pads with empty strings or truncates [translations] to [lineCount] items,
/// keeping existing translations by line index.
List<String> resizeTranslations(List<String> translations, int lineCount) => [
  for (var i = 0; i < lineCount; i++) i < translations.length ? translations[i] : '',
];

/// Comma-separated keywords → trimmed, non-empty, de-duplicated list.
List<String> parseKeywords(String input) {
  final seen = <String>{};
  return [
    for (final k in input.split(',').map((e) => e.trim()))
      if (k.isNotEmpty && seen.add(k.toLowerCase())) k,
  ];
}

/// Serialises [doc] back to LRC text. Times are already offset-adjusted by
/// the parser, so an `offset` tag is not written again.
String formatLrc(LrcDocument doc) {
  final out = StringBuffer();
  for (final e in doc.tags.entries) {
    if (e.key == 'offset') continue;
    out.writeln('[${e.key}:${e.value}]');
  }
  for (final l in doc.lines) {
    out.writeln('${LrcParser.format(l.start)}${l.text}');
  }
  if (doc.end != null) out.writeln(LrcParser.format(doc.end!));
  return out.toString();
}

/// Sets the start of parsed line [lineIndex] to [at] and returns the new LRC
/// text. Line order is preserved: earlier lines that would start at/after
/// [at] are pulled before it and later lines that would start at/before it
/// are pushed after it (10 ms apart), so tapping lines in order works.
String retimeLine(String lrcText, int lineIndex, Duration at) {
  final doc = LrcParser.parse(lrcText);
  if (lineIndex < 0 || lineIndex >= doc.lines.length) return lrcText;
  const gap = Duration(milliseconds: 10);
  final at10 = Duration(milliseconds: (at.inMilliseconds ~/ 10) * 10);
  final starts = [for (final l in doc.lines) l.start];
  starts[lineIndex] = at10 < Duration.zero ? Duration.zero : at10;
  for (var j = lineIndex + 1; j < starts.length; j++) {
    final min = starts[j - 1] + gap;
    if (starts[j] < min) starts[j] = min;
  }
  for (var j = lineIndex - 1; j >= 0; j--) {
    final max = starts[j + 1] - gap;
    if (starts[j] > max) starts[j] = max < Duration.zero ? Duration.zero : max;
  }
  var end = doc.end;
  if (end != null && end <= starts.last) end = null;
  return formatLrc(
    LrcDocument(
      lines: [for (var i = 0; i < doc.lines.length; i++) LrcLine(starts[i], doc.lines[i].text)],
      tags: doc.tags,
      end: end,
    ),
  );
}

/// Current values of the song editor form.
class SongDraft {
  const SongDraft({
    required this.title,
    required this.artist,
    required this.level,
    required this.topics,
    required this.genre,
    required this.license,
    required this.keywords,
    required this.audio,
    required this.cover,
    required this.lrcText,
    required this.translations,
    this.hidden = false,
  });

  final String title;
  final String artist;
  final String level;
  final List<String> topics;
  final String genre;
  final String license;
  final List<String> keywords;

  /// Local file path, asset path or http(s) URL.
  final String audio;
  final String cover;
  final String lrcText;
  final List<String> translations;
  final bool hidden;

  /// Builds a song with [id]. Fields not edited here (color, lrc file
  /// reference, bundled flag, updatedAt) are kept from [base].
  Song toSong(String id, {Song? base, int durationMs = 0}) {
    final s = Song(
      id: id,
      title: title.trim(),
      artist: artist.trim(),
      level: level,
      topics: topics,
      genre: genre,
      durationMs: durationMs,
      audio: audio.trim(),
      lrc: base?.lrc ?? '',
      lrcText: lrcText,
      cover: cover.trim().isEmpty ? null : cover.trim(),
      color: base?.color ?? '#00796b',
      license: license.trim(),
      keywords: keywords,
      translations: translations,
      hidden: hidden,
      bundled: base?.bundled ?? false,
      updatedAt: base?.updatedAt ?? 0,
    );
    return s;
  }
}

/// Result of [validateDraft]: blocking errors and non-blocking warnings.
class DraftValidation {
  const DraftValidation(this.errors, this.warnings);

  final List<String> errors;
  final List<String> warnings;

  bool get ok => errors.isEmpty;
}

String? requiredText(String? v, String label) =>
    (v == null || v.trim().isEmpty) ? 'Vui lòng nhập $label' : null;

/// Audio/cover reference check: empty allowed only when not [required].
String? mediaRefError(String? v, {required bool required, required String label}) {
  final value = v?.trim() ?? '';
  if (value.isEmpty) return required ? 'Vui lòng chọn $label' : null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return 'Đường dẫn không hợp lệ';
    return null;
  }
  if (value.contains('://')) return 'Chỉ hỗ trợ đường dẫn http(s)';
  return null;
}

String? lrcError(String? v) {
  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập lời LRC';
  if (LrcParser.parse(v).lines.isEmpty) {
    return 'Lời LRC chưa có dòng nào hợp lệ (dạng [mm:ss.xx] lời)';
  }
  return null;
}

DraftValidation validateDraft(SongDraft d) {
  final errors = <String>[
    ?requiredText(d.title, 'tên bài hát'),
    ?requiredText(d.artist, 'ca sĩ / tác giả'),
    ?requiredText(d.license, 'nguồn / giấy phép'),
    ?mediaRefError(d.audio, required: true, label: 'tệp nhạc'),
    ?mediaRefError(d.cover, required: false, label: 'ảnh bìa'),
    ?lrcError(d.lrcText),
  ];
  if (!cefrLevels.contains(d.level)) errors.add('Trình độ không hợp lệ');
  final warnings = <String>[];
  final lines = LrcParser.parse(d.lrcText).lines.length;
  if (lines > 0) {
    if (d.translations.length != lines) {
      errors.add('Số bản dịch (${d.translations.length}) khác số dòng lời ($lines)');
    } else {
      final empty = d.translations.where((t) => t.trim().isEmpty).length;
      if (empty > 0) warnings.add('Còn $empty/$lines câu chưa có bản dịch');
    }
  }
  return DraftValidation(errors, warnings);
}
