// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nmea_dashboard/state/alarms.dart';

/// Periodically plays the platform alert sound while at least one audible
/// alarm is active and the app is in the foreground.
///
/// v1 deliberately uses [SystemSound.play] rather than a dedicated audio
/// package: no extra dependency, no asset, no platform-specific permissions.
/// Background playback is intentionally not supported — the app stops the
/// timer as soon as it leaves the resumed lifecycle state.
class AlarmAudioController with WidgetsBindingObserver {
  final AlarmManager _manager;
  final Duration _period;
  final Future<void> Function() _play;
  final bool _registerLifecycleObserver;

  Timer? _timer;
  bool _foreground = true;

  AlarmAudioController(
    this._manager, {
    Duration period = const Duration(milliseconds: 800),
    Future<void> Function()? play,
    bool registerLifecycleObserver = true,
  }) : _period = period,
       _play = play ?? (() => SystemSound.play(SystemSoundType.alert)),
       _registerLifecycleObserver = registerLifecycleObserver {
    if (_registerLifecycleObserver) {
      WidgetsBinding.instance.addObserver(this);
    }
    _manager.addListener(_reconcile);
    _reconcile();
  }

  /// Whether the timer is currently scheduled. Exposed for tests.
  @visibleForTesting
  bool get isPlaying => _timer != null;

  void _reconcile() {
    final shouldPlay = _foreground && _manager.audible.isNotEmpty;
    if (shouldPlay && _timer == null) {
      // Play immediately so the user hears something without waiting a full
      // period for the first scheduled tick.
      _play();
      _timer = Timer.periodic(_period, (_) => _play());
    } else if (!shouldPlay && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _reconcile();
  }

  /// Test-only hook to simulate lifecycle transitions without a binding.
  @visibleForTesting
  void debugSetForeground(bool foreground) {
    _foreground = foreground;
    _reconcile();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _manager.removeListener(_reconcile);
    if (_registerLifecycleObserver) {
      WidgetsBinding.instance.removeObserver(this);
    }
  }
}
