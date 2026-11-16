/// One timed line of an LRC file.
class LrcLine {
  const LrcLine(this.start, this.text);

  final Duration start;
  final String text;
}

/// Result of parsing an LRC document.
class LrcDocument {
  const LrcDocument({required this.lines, this.tags = const {}, this.end});

  /// Non-empty lyric lines sorted by start time.
  final List<LrcLine> lines;

  /// ID tags such as `ti`, `ar`, `length`.
  final Map<String, String> tags;

  /// Time of a trailing empty timestamp (end of the last line), if present.
  final Duration? end;
}

/// Parser for the LRC lyric format: `[mm:ss.xx] text`.
///
/// Supports several timestamps on one line (`[00:12.00][01:30.50]chorus`),
/// 1–3 fractional digits, `[offset:+/-ms]`, ID tags and blank/invalid lines.
class LrcParser {
  static final _timeTag = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  static final _idTag = RegExp(r'^\[([a-zA-Z]+):(.*)\]\s*$');

  static LrcDocument parse(String source) {
    final tags = <String, String>{};
    final lines = <LrcLine>[];
    final blanks = <Duration>[];
    var offsetMs = 0;

    for (final raw in source.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final times = <Duration>[];
      var rest = line;
      while (true) {
        final m = _timeTag.matchAsPrefix(rest);
        if (m == null) break;
        times.add(_toDuration(m));
        rest = rest.substring(m.end);
      }
      if (times.isEmpty) {
        final id = _idTag.firstMatch(line);
        if (id != null) {
          final key = id.group(1)!.toLowerCase();
          final value = id.group(2)!.trim();
          tags[key] = value;
          if (key == 'offset') offsetMs = int.tryParse(value) ?? 0;
        }
        continue;
      }
      final text = rest.trim();
      for (final t in times) {
        if (text.isEmpty) {
          blanks.add(t);
        } else {
          lines.add(LrcLine(t, text));
        }
      }
    }

    // A positive offset means lyrics should appear earlier.
    Duration shift(Duration d) {
      final ms = d.inMilliseconds - offsetMs;
      return Duration(milliseconds: ms < 0 ? 0 : ms);
    }

    lines.sort((a, b) => a.start.compareTo(b.start));
    final shifted = [for (final l in lines) LrcLine(shift(l.start), l.text)];
    Duration? end;
    if (blanks.isNotEmpty && shifted.isNotEmpty) {
      final last = shifted.last.start;
      final after = blanks.map(shift).where((b) => b > last).toList()..sort();
      if (after.isNotEmpty) end = after.first;
    }
    return LrcDocument(lines: shifted, tags: tags, end: end);
  }

  static Duration _toDuration(Match m) {
    final minutes = int.parse(m.group(1)!);
    final seconds = int.parse(m.group(2)!);
    final frac = m.group(3);
    var ms = 0;
    if (frac != null) {
      // "5" -> 500ms, "05" -> 50ms, "050" -> 50ms
      ms = int.parse(frac.padRight(3, '0'));
    }
    return Duration(minutes: minutes, seconds: seconds, milliseconds: ms);
  }

  /// Formats [d] as an LRC timestamp `[mm:ss.xx]`.
  static String format(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final cs = ((d.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
    return '[$m:$s.$cs]';
  }

  /// Index of the line active at [position] (the last line whose start is
  /// <= position), or -1 before the first line. Binary search, O(log n).
  static int activeIndex(List<Duration> starts, Duration position) {
    var lo = 0, hi = starts.length - 1, ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (starts[mid] <= position) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }
}
