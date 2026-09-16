import 'dart:async';

import 'package:flutter/widgets.dart';

/// Debounces low-risk draft persistence while ensuring pending text is flushed
/// when the app leaves the foreground.
///
/// Call [suspend] before a confirmed save or discard. Composer draft stores
/// serialize mutations per scope, so an already-running flush completes before
/// the final clear and cannot resurrect a discarded draft.
class V2DraftAutosaveController with WidgetsBindingObserver {
  V2DraftAutosaveController({
    required Future<void> Function() persist,
    this.debounce = const Duration(milliseconds: 700),
  }) : _persist = persist {
    WidgetsBinding.instance.addObserver(this);
  }

  final Future<void> Function() _persist;
  final Duration debounce;

  Timer? _timer;
  bool _suspended = false;
  bool _disposed = false;

  bool get isSuspended => _suspended;

  void schedule() {
    if (_suspended || _disposed) return;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      unawaited(flush());
    });
  }

  void cancelPending() {
    _timer?.cancel();
    _timer = null;
  }

  void suspend() {
    if (_disposed) return;
    _suspended = true;
    cancelPending();
  }

  void resume() {
    if (_disposed) return;
    _suspended = false;
  }

  Future<void> flush() async {
    if (_suspended || _disposed) return;
    cancelPending();
    await _persist();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_suspended || _disposed) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(flush());
    }
  }

  void dispose() {
    if (_disposed) return;
    _suspended = true;
    _disposed = true;
    cancelPending();
    WidgetsBinding.instance.removeObserver(this);
  }
}
