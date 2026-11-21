import 'dart:async';

import 'sync_service.dart';

/// Result of one [AccountSync.syncNow] run, worded for the learner.
class SyncOutcome {
  const SyncOutcome({
    required this.pushed,
    required this.remaining,
    this.sendFailed = false,
    this.pullFailed = false,
    this.signedIn = true,
  });

  /// Queued writes confirmed by the server in this run.
  final int pushed;

  /// Writes of the signed-in account still waiting after this run.
  final int remaining;

  /// Sending stopped on an error or did not finish within the time limit.
  final bool sendFailed;

  /// Downloading the account's data failed or timed out.
  final bool pullFailed;

  /// False when signed out or a guest: nothing is sent or downloaded.
  final bool signedIn;

  /// Everything of this account is on the server and its data is current.
  bool get complete => signedIn && remaining == 0 && !sendFailed && !pullFailed;

  /// Message for the manual sync actions. Never reports success while
  /// writes are still waiting or a step failed.
  String get message {
    if (!signedIn) return 'Đăng nhập tài khoản để đồng bộ dữ liệu';
    if (remaining > 0 || sendFailed) {
      final sent = pushed > 0 ? 'Đã gửi $pushed thay đổi; ' : '';
      final left = remaining > 0
          ? 'còn $remaining thay đổi chưa đồng bộ'
          : 'chưa gửi được lên máy chủ';
      return '$sent$left. Kiểm tra kết nối rồi thử lại.';
    }
    if (pullFailed) {
      return 'Đã gửi hết thay đổi nhưng chưa tải được dữ liệu mới. '
          'Kiểm tra kết nối rồi thử lại.';
    }
    return pushed > 0
        ? 'Đã đồng bộ $pushed thay đổi'
        : 'Dữ liệu đã được đồng bộ';
  }
}

/// One sync routine for every trigger (reconnect, app resume/pause, sign-in,
/// pull-to-refresh, "Đồng bộ ngay"), so they behave the same:
///
/// 1. send the signed-in account's queued writes (bounded by [sendLimit]);
/// 2. download that account's data (bounded by [pullLimit]);
/// 3. only after a successful download, publish the public profile from the
///    reconciled local data, so a fresh install never overwrites the cloud
///    XP/streak with its empty starting state.
///
/// Signed out or a guest: nothing is sent or downloaded. Local mode (no
/// remote): only the profile is published.
///
/// Firestore does not complete writes or reads while offline; the limits
/// make every trigger finish and report instead of waiting forever. A run
/// requested while one is in progress waits for it, then one more run serves
/// every request made meanwhile, so an account change mid-run is not lost.
class AccountSync {
  AccountSync({
    required this._sync,
    required this._account,
    required this._pull,
    required void Function(String uid) publishProfile,
    this.sendLimit = const Duration(seconds: 20),
    this.pullLimit = const Duration(seconds: 20),
  }) : _publish = publishProfile;

  final SyncService _sync;

  /// Signed-in account (uid), or null when signed out or a guest.
  final String? Function() _account;

  /// Downloads the data of the given account. Must throw if it cannot.
  final Future<void> Function(String uid) _pull;

  /// Starts writing the public profile of the given account (not awaited).
  final void Function(String uid) _publish;

  final Duration sendLimit;
  final Duration pullLimit;

  final _reconciled = <String>{};
  Future<SyncOutcome>? _running;
  Future<SyncOutcome>? _next;

  bool get isEnabled => _sync.isEnabled;

  /// Whether [uid]'s data was downloaded at least once in this app session,
  /// so local progress may be published (always true in local mode).
  bool isReconciled(String uid) => !isEnabled || _reconciled.contains(uid);

  /// Writes of the signed-in account waiting to be sent (0 when signed out,
  /// a guest or in local mode).
  Future<int> pending() async {
    final uid = _account();
    if (!isEnabled || uid == null) return 0;
    return _sync.pendingCount(uid: uid);
  }

  /// Sends, downloads and publishes for the signed-in account.
  Future<SyncOutcome> syncNow() {
    final next = _next;
    if (next != null) return next;
    final running = _running;
    if (running == null) return _start();
    return _next = running.then<void>((_) {}, onError: (Object _) {}).then((_) {
      _next = null;
      return _start();
    });
  }

  Future<SyncOutcome> _start() {
    final run = _run();
    _running = run;
    run.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      if (identical(_running, run)) _running = null;
    });
    return run;
  }

  Future<SyncOutcome> _run() async {
    final uid = _account();
    if (uid == null) {
      return const SyncOutcome(pushed: 0, remaining: 0, signedIn: false);
    }
    if (!isEnabled) {
      // Local mode: the local data is the only copy, publish it as is.
      _publish(uid);
      return const SyncOutcome(pushed: 0, remaining: 0);
    }
    var pushed = 0;
    var sendFailed = false;
    try {
      pushed = await _sync.flush(uid: uid).timeout(sendLimit);
    } catch (_) {
      // Timeout or error: the writes stay queued for the next trigger.
      sendFailed = true;
    }
    var pullFailed = false;
    if (_account() == uid) {
      try {
        await _pull(uid).timeout(pullLimit);
        if (_account() == uid) {
          _reconciled.add(uid);
          _publish(uid);
        } else {
          pullFailed = true;
        }
      } catch (_) {
        pullFailed = true;
      }
    } else {
      // Signed out or switched during the run: do not report that account's
      // data as current; the run requested for the new session follows.
      pullFailed = true;
    }
    var remaining = 0;
    try {
      remaining = await _sync.pendingCount(uid: uid);
    } catch (_) {
      sendFailed = true;
    }
    return SyncOutcome(
      pushed: pushed,
      remaining: remaining,
      sendFailed: sendFailed,
      pullFailed: pullFailed,
    );
  }
}
