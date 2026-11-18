import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/ui/widgets.dart';
import '../../auth/domain/app_user.dart';
import '../data/social_repository.dart';
import '../domain/social_models.dart';
import 'social_widgets.dart';

/// Friends (M4): my code, search by e-mail / code, requests and friend list.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _query = TextEditingController();
  bool _searching = false;
  bool _sending = false;
  String? _searchError;
  PublicProfile? _result;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    FocusScope.of(context).unfocus();
    final cloud = ref.read(currentUserProvider)?.isCloud ?? false;
    if (q.isEmpty) {
      setState(() => _searchError = cloud
          ? 'Nhập mã 6 ký tự của bạn bè'
          : 'Nhập email hoặc mã 6 ký tự của bạn bè');
      return;
    }
    if (!q.contains('@') && q.length != 6) {
      setState(() {
        _result = null;
        _searchError = 'Mã người dùng gồm đúng 6 ký tự (hoặc nhập email)';
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
      _result = null;
    });
    try {
      final p = await ref.read(socialRepositoryProvider).find(q);
      if (!mounted) return;
      setState(() {
        _result = p;
        _searchError = p == null ? 'Không tìm thấy người dùng' : null;
      });
    } catch (e) {
      if (mounted) setState(() => _searchError = socialErrorText(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _send(String myUid, PublicProfile target) async {
    setState(() => _sending = true);
    try {
      await ref.read(socialRepositoryProvider).sendFriendRequest(myUid, target.uid);
      ref.invalidate(friendshipsProvider);
      showMessage('Đã gửi lời mời kết bạn tới ${target.displayName}');
      if (mounted) {
        setState(() {
          _result = null;
          _query.clear();
        });
      }
    } catch (e) {
      showMessage(socialErrorText(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _respond(String myUid, String other, {required bool accept}) async {
    try {
      await ref
          .read(socialRepositoryProvider)
          .respondFriendRequest(myUid, other, accept: accept);
      ref.invalidate(friendshipsProvider);
      showMessage(accept ? 'Hai bạn đã trở thành bạn bè' : 'Đã từ chối lời mời');
    } catch (e) {
      showMessage(socialErrorText(e));
    }
  }

  Future<void> _remove(String myUid, String other, String name, {bool cancel = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(cancel ? 'Hủy lời mời?' : 'Hủy kết bạn?'),
        content: Text(cancel
            ? 'Hủy lời mời kết bạn đã gửi tới $name?'
            : 'Bạn có chắc muốn xóa $name khỏi danh sách bạn bè?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(cancel ? 'Hủy lời mời' : 'Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(socialRepositoryProvider).removeFriend(myUid, other);
      ref.invalidate(friendshipsProvider);
      showMessage(cancel ? 'Đã hủy lời mời' : 'Đã xóa $name khỏi danh sách bạn bè');
    } catch (e) {
      showMessage(socialErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bạn bè'),
        actions: [
          if (user != null && !user.isGuest)
            IconButton(
              tooltip: 'Bảng xếp hạng',
              icon: const Icon(Icons.leaderboard_outlined),
              onPressed: () => context.push(Routes.leaderboard),
            ),
        ],
      ),
      body: user == null || user.isGuest
          ? const GuestSocialNotice()
          : _body(context, user),
    );
  }

  Widget _body(BuildContext context, AppUser me) {
    final friendships = ref.watch(friendshipsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(friendshipsProvider);
        await ref.read(friendshipsProvider.future).catchError((_) => <Friendship>[]);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _myCodeCard(context, me),
          _searchCard(context, me, friendships.value ?? const []),
          ...friendships.when(
            loading: () => [
              const Padding(padding: EdgeInsets.all(32), child: LoadingView()),
            ],
            error: (e, _) => [
              ErrorView(
                error: socialErrorText(e),
                onRetry: () => ref.invalidate(friendshipsProvider),
              ),
            ],
            data: (list) => _sections(context, me.uid, list),
          ),
        ],
      ),
    );
  }

  Widget _myCodeCard(BuildContext context, AppUser me) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        color: t.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mã của bạn',
                        style: t.textTheme.labelLarge
                            ?.copyWith(color: t.colorScheme.onPrimaryContainer)),
                    const SizedBox(height: 4),
                    SelectableText(
                      me.userCode,
                      style: t.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                        color: t.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text('Gửi mã này cho bạn bè để họ tìm bạn',
                        style: t.textTheme.bodySmall
                            ?.copyWith(color: t.colorScheme.onPrimaryContainer)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sao chép mã',
                icon: Icon(Icons.copy, color: t.colorScheme.onPrimaryContainer),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: me.userCode));
                  showMessage('Đã sao chép mã ${me.userCode}');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchCard(BuildContext context, AppUser me, List<Friendship> existing) {
    final result = _result;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('friend-search'),
            controller: _query,
            textInputAction: TextInputAction.search,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Tìm bạn bè',
              hintText: me.isCloud ? 'Mã bạn bè 6 ký tự' : 'Email hoặc mã 6 ký tự',
              prefixIcon: const Icon(Icons.person_search_outlined),
              errorText: _searchError,
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      tooltip: 'Tìm',
                      icon: const Icon(Icons.search),
                      onPressed: _search,
                    ),
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 12),
            _resultCard(context, me, result, existing),
          ],
        ],
      ),
    );
  }

  Widget _resultCard(
      BuildContext context, AppUser me, PublicProfile p, List<Friendship> existing) {
    final err = friendRequestError(me.uid, p, existing);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                NameAvatar(p.displayName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('Mã ${p.userCode} · Cấp ${p.level} · ${p.xp} XP',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (err != null)
              Text(err,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
            else
              FilledButton.icon(
                onPressed: _sending ? null : () => _send(me.uid, p),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Kết bạn'),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sections(BuildContext context, String myUid, List<Friendship> list) {
    final incoming = [
      for (final f in list)
        if (f.status == FriendStatus.pending && f.requestedBy != myUid) f,
    ];
    final sent = [
      for (final f in list)
        if (f.status == FriendStatus.pending && f.requestedBy == myUid) f,
    ];
    final friends = [
      for (final f in list)
        if (f.status == FriendStatus.accepted) f,
    ];
    return [
      if (incoming.isNotEmpty) ...[
        SectionTitle('Lời mời kết bạn (${incoming.length})'),
        for (final f in incoming)
          _FriendTile(
            uid: f.other(myUid),
            subtitle: (_) => 'Muốn kết bạn với bạn',
            actionsBuilder: (name) => [
              IconButton(
                tooltip: 'Từ chối',
                icon: const Icon(Icons.close),
                onPressed: () => _respond(myUid, f.other(myUid), accept: false),
              ),
              FilledButton(
                onPressed: () => _respond(myUid, f.other(myUid), accept: true),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: const Text('Chấp nhận'),
              ),
            ],
          ),
      ],
      if (sent.isNotEmpty) ...[
        SectionTitle('Đã gửi lời mời (${sent.length})'),
        for (final f in sent)
          _FriendTile(
            uid: f.other(myUid),
            subtitle: (_) => 'Đang chờ chấp nhận',
            actionsBuilder: (name) => [
              IconButton(
                tooltip: 'Hủy lời mời',
                icon: const Icon(Icons.cancel_outlined),
                onPressed: () => _remove(myUid, f.other(myUid), name, cancel: true),
              ),
            ],
          ),
      ],
      SectionTitle('Bạn bè (${friends.length})'),
      if (friends.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: EmptyState(
            icon: Icons.group_outlined,
            title: 'Chưa có bạn bè',
            message: 'Tìm bạn bằng email hoặc mã 6 ký tự để cùng học, '
                'thách đấu và đua top tuần.',
          ),
        )
      else
        for (final f in friends)
          _FriendTile(
            uid: f.other(myUid),
            subtitle: (p) => p == null
                ? 'Đang tải…'
                : 'Cấp ${p.level} · ${p.xp} XP · ${p.weekXpAt(DateTime.now())} XP tuần này',
            actionsBuilder: (name) => [
              IconButton(
                tooltip: 'Thách đấu',
                icon: const Icon(Icons.sports_esports_outlined),
                onPressed: () =>
                    context.push('${Routes.newChallenge}?to=${Uri.encodeQueryComponent(f.other(myUid))}'),
              ),
              PopupMenuButton<String>(
                tooltip: 'Tùy chọn',
                onSelected: (_) => _remove(myUid, f.other(myUid), name),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'remove', child: Text('Hủy kết bạn')),
                ],
              ),
            ],
          ),
    ];
  }
}

/// One person row; loads the public profile by uid.
class _FriendTile extends ConsumerWidget {
  const _FriendTile({
    required this.uid,
    required this.subtitle,
    required this.actionsBuilder,
  });

  final String uid;
  final String Function(PublicProfile? p) subtitle;
  final List<Widget> Function(String name) actionsBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(publicProfileProvider(uid)).value;
    final name = p?.displayName ?? 'Người dùng';
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 8),
      leading: NameAvatar(name),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle(p), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: actionsBuilder(name)),
    );
  }
}
