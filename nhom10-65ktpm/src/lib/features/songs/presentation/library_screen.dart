import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/ui/widgets.dart';
import '../data/song_progress_repository.dart';
import '../domain/song.dart';

/// Pure filter used by the library (and its tests).
class SongFilter {
  const SongFilter({
    this.query = '',
    this.level,
    this.topic,
    this.genre,
    this.favoritesOnly = false,
    this.offlineOnly = false,
  });

  final String query;
  final String? level;
  final String? topic;
  final String? genre;
  final bool favoritesOnly;
  final bool offlineOnly;

  bool get isActive =>
      query.isNotEmpty || level != null || topic != null || genre != null ||
      favoritesOnly || offlineOnly;

  List<Song> apply(
    List<Song> songs, {
    Map<String, SongProgress> progress = const {},
    Set<String> downloaded = const {},
  }) {
    final q = _fold(query.trim());
    return songs.where((s) {
      if (level != null && s.level != level) return false;
      if (topic != null && !s.topics.contains(topic)) return false;
      if (genre != null && s.genre != genre) return false;
      if (favoritesOnly && !(progress[s.id]?.favorite ?? false)) return false;
      if (offlineOnly && !(s.bundled || downloaded.contains(s.id) || !s.isRemoteAudio)) {
        return false;
      }
      if (q.isNotEmpty &&
          !_fold(s.title).contains(q) &&
          !_fold(s.artist).contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Case- and accent-insensitive comparison key.
  static String _fold(String s) {
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      b.write(_accentMap[ch] ?? ch);
    }
    return b.toString().replaceAll(RegExp(r"[^a-z0-9 ]"), '');
  }

  static final Map<String, String> _accentMap = () {
    const groups = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    return {
      for (final e in groups.entries)
        for (final ch in e.value.split('')) ch: e.key,
    };
  }();

  static String foldForTest(String s) {
    return _fold(s);
  }

  SongFilter copyWith({
    String? query,
    String? Function()? level,
    String? Function()? topic,
    String? Function()? genre,
    bool? favoritesOnly,
    bool? offlineOnly,
  }) =>
      SongFilter(
        query: query ?? this.query,
        level: level != null ? level() : this.level,
        topic: topic != null ? topic() : this.topic,
        genre: genre != null ? genre() : this.genre,
        favoritesOnly: favoritesOnly ?? this.favoritesOnly,
        offlineOnly: offlineOnly ?? this.offlineOnly,
      );
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  SongFilter _filter = const SongFilter();
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);
    final progress = ref.watch(songProgressProvider).value ?? const {};
    final downloaded = ref.watch(downloadedSongsProvider).value ?? const {};
    return Scaffold(
      appBar: AppBar(title: const Text('Bài hát')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              key: const Key('library-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên bài hoặc ca sĩ',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xóa',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _filter = _filter.copyWith(query: ''));
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _filter = _filter.copyWith(query: v)),
            ),
          ),
          _FilterBar(
            filter: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: songsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(songsProvider)),
              data: (songs) {
                final list = _filter.apply(songs, progress: progress, downloaded: downloaded);
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: 'Không có bài hát phù hợp',
                    message: _filter.isActive ? 'Thử bỏ bớt bộ lọc.' : null,
                    action: _filter.isActive
                        ? TextButton(
                            onPressed: () {
                              _search.clear();
                              setState(() => _filter = const SongFilter());
                            },
                            child: const Text('Xóa bộ lọc'),
                          )
                        : null,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: list.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text('${list.length} bài hát',
                            style: Theme.of(context).textTheme.bodySmall),
                      );
                    }
                    final s = list[i - 1];
                    return SongTile(
                      song: s,
                      progress: progress[s.id],
                      offline: !s.isRemoteAudio || downloaded.contains(s.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onChanged});

  final SongFilter filter;
  final ValueChanged<SongFilter> onChanged;

  Future<String?> _pick(BuildContext context, String title, Map<String, String> options) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
            child: ListView(shrinkWrap: true, children: [
              ListTile(title: Text(title)),
              ListTile(
                  leading: const Icon(Icons.clear_all),
                  title: const Text('Tất cả'),
                  onTap: () => Navigator.pop(context, '')),
              for (final e in options.entries)
                ListTile(title: Text(e.value), onTap: () => Navigator.pop(context, e.key)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final l in cefrLevels)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(l),
                selected: filter.level == l,
                onSelected: (sel) => onChanged(filter.copyWith(level: () => sel ? l : null)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              avatar: const Icon(Icons.category_outlined, size: 18),
              label: Text(filter.topic == null ? 'Chủ đề' : topicLabels[filter.topic]!),
              selected: filter.topic != null,
              onSelected: (_) async {
                final v = await _pick(context, 'Chủ đề', topicLabels);
                if (v != null) onChanged(filter.copyWith(topic: () => v.isEmpty ? null : v));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              avatar: const Icon(Icons.queue_music, size: 18),
              label: Text(filter.genre == null ? 'Thể loại' : genreLabels[filter.genre]!),
              selected: filter.genre != null,
              onSelected: (_) async {
                final v = await _pick(context, 'Thể loại', genreLabels);
                if (v != null) onChanged(filter.copyWith(genre: () => v.isEmpty ? null : v));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              avatar: const Icon(Icons.favorite, size: 18),
              label: const Text('Yêu thích'),
              selected: filter.favoritesOnly,
              onSelected: (v) => onChanged(filter.copyWith(favoritesOnly: v)),
            ),
          ),
          FilterChip(
            avatar: const Icon(Icons.offline_pin, size: 18),
            label: const Text('Nghe offline'),
            selected: filter.offlineOnly,
            onSelected: (v) => onChanged(filter.copyWith(offlineOnly: v)),
          ),
        ],
      ),
    );
  }
}

class SongTile extends ConsumerStatefulWidget {
  const SongTile({super.key, required this.song, this.progress, required this.offline});

  final Song song;
  final SongProgress? progress;
  final bool offline;

  @override
  ConsumerState<SongTile> createState() => _SongTileState();
}

class _SongTileState extends ConsumerState<SongTile> {
  double? _downloading;

  Future<void> _download() async {
    setState(() => _downloading = 0);
    try {
      await ref.read(downloadServiceProvider).download(
            widget.song.id,
            widget.song.audio,
            onProgress: (p) => mounted ? setState(() => _downloading = p) : null,
          );
      showMessage('Đã tải “${widget.song.title}” để nghe offline');
    } catch (e) {
      showMessage('Không tải được: $e');
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.song;
    final p = widget.progress;
    final t = Theme.of(context);
    Widget offlineAction;
    if (_downloading != null) {
      offlineAction = SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: CircularProgressIndicator(value: _downloading == 0 ? null : _downloading, strokeWidth: 2),
        ),
      );
    } else if (widget.offline) {
      offlineAction = Tooltip(
        message: s.isRemoteAudio ? 'Đã tải về, nghe được khi không có mạng' : 'Có sẵn trong ứng dụng, nghe offline',
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.offline_pin, color: t.colorScheme.primary),
        ),
      );
    } else {
      offlineAction = IconButton(
        tooltip: 'Tải về nghe offline',
        icon: const Icon(Icons.download_outlined),
        onPressed: _download,
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('song-${s.id}'),
        onTap: () => context.push(Routes.player(s.id)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SongCover(song: s, size: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(s.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        LevelBadge(s.level),
                        Text(formatDuration(s.duration), style: t.textTheme.labelSmall),
                        for (final topic in s.topics.take(1))
                          Text(topicLabels[topic] ?? topic, style: t.textTheme.labelSmall),
                        if (p != null && p.listens > 0)
                          Text('· ${p.listens} lượt nghe', style: t.textTheme.labelSmall),
                        if (p != null && p.bestExerciseScore > 0)
                          Text('· BT ${p.bestExerciseScore}%', style: t.textTheme.labelSmall),
                        if (p != null && p.bestPronunciationScore > 0)
                          Text('· PÂ ${p.bestPronunciationScore}', style: t.textTheme.labelSmall),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('fav-${s.id}'),
                    tooltip: (p?.favorite ?? false) ? 'Bỏ yêu thích' : 'Yêu thích',
                    icon: Icon((p?.favorite ?? false) ? Icons.favorite : Icons.favorite_border,
                        color: (p?.favorite ?? false) ? Colors.pink : null),
                    onPressed: () =>
                        ref.read(songProgressRepositoryProvider).toggleFavorite(s.id),
                  ),
                  offlineAction,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
