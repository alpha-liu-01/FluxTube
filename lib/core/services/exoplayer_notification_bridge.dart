import 'dart:io';

import 'package:flutter/services.dart';

/// Controls the Android ExoPlayer notification. The channel only exists on
/// Android, so every call is a no-op elsewhere.
class ExoPlayerNotificationBridge {
  ExoPlayerNotificationBridge._();

  static final ExoPlayerNotificationBridge instance =
      ExoPlayerNotificationBridge._();

  static const _controlChannel = MethodChannel(
    'com.fazilvk.fluxtube/newpipe_exoplayer_control',
  );

  void attach(MethodChannel channel) {}

  Future<void> play() async {
    if (!Platform.isAndroid) return;
    await _controlChannel.invokeMethod('play');
  }

  Future<void> pause() async {
    if (!Platform.isAndroid) return;
    await _controlChannel.invokeMethod('pause');
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await _controlChannel.invokeMethod('stop');
  }

  Future<void> seek(Duration position) async {
    if (!Platform.isAndroid) return;
    await _controlChannel.invokeMethod('seekTo', {
      'positionMs': position.inMilliseconds,
    });
  }

  Future<Duration> seekBy(Duration delta) async {
    if (!Platform.isAndroid) return Duration.zero;
    final positionMs = await _controlChannel.invokeMethod<int>('seekBy', {
      'deltaMs': delta.inMilliseconds,
    });
    return Duration(milliseconds: positionMs ?? 0);
  }
}
