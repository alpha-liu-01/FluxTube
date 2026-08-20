import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum CastState {
  /// No Cast framework on this device — no Play Services, or not Android.
  unavailable,

  /// Framework is running but has not discovered a receiver yet.
  noDevices,

  /// Receivers are on the network and can be picked.
  available,
  connecting,
  connected,
}

/// Dart side of the Google Cast bridge.
///
/// Discovery only runs while something is listening, so widgets should
/// [start] on mount and [stop] on dispose rather than keeping it warm.
class CastService extends ChangeNotifier {
  static final CastService _instance = CastService._();
  factory CastService() => _instance;
  CastService._();

  static const _methods = MethodChannel('com.fazilvk.fluxtube/cast');
  static const _events = EventChannel('com.fazilvk.fluxtube/cast_events');

  StreamSubscription<dynamic>? _subscription;
  int _listeners = 0;

  CastState _state = CastState.unavailable;
  String? _deviceName;

  CastState get state => _state;
  String? get deviceName => _deviceName;
  bool get isConnected => _state == CastState.connected;

  /// Whether the Cast button should be shown at all. Hidden while no receiver
  /// has been discovered, matching how Cast buttons behave elsewhere.
  bool get isCastable =>
      _state != CastState.unavailable && _state != CastState.noDevices;

  /// Cast is Android-only here; no iOS receiver bridge is registered.
  static bool get isSupportedPlatform => Platform.isAndroid;

  /// Begins listening for state changes. Reference-counted, so several widgets
  /// can start and stop independently.
  void start() {
    _listeners++;
    if (_subscription != null) return;
    if (!isSupportedPlatform) return;

    _subscription = _events.receiveBroadcastStream().listen(
      (event) {
        if (event is! Map) return;
        _apply(Map<String, dynamic>.from(event));
      },
      onError: (Object error) {
        dev.log('cast event stream error: $error', name: 'CastService');
        _state = CastState.unavailable;
        notifyListeners();
      },
    );
  }

  void stop() {
    if (_listeners > 0) _listeners--;
    if (_listeners > 0) return;
    _subscription?.cancel();
    _subscription = null;
  }

  void _apply(Map<String, dynamic> event) {
    final next = _parseState(event['state'] as String?);
    final name = event['deviceName'] as String?;
    if (next == _state && name == _deviceName) return;
    _state = next;
    _deviceName = name;
    notifyListeners();
  }

  static CastState _parseState(String? raw) {
    switch (raw) {
      case 'noDevices':
        return CastState.noDevices;
      case 'available':
        return CastState.available;
      case 'connecting':
        return CastState.connecting;
      case 'connected':
        return CastState.connected;
      default:
        return CastState.unavailable;
    }
  }

  /// Opens the system Cast device chooser. Selecting a device starts a session,
  /// which arrives back through the event stream.
  Future<bool> showPicker() async {
    if (!isSupportedPlatform) return false;
    try {
      return await _methods.invokeMethod<bool>('showPicker') ?? false;
    } on PlatformException catch (e) {
      dev.log('showPicker failed: ${e.code}', name: 'CastService');
      return false;
    }
  }

  /// Hands a stream to the connected receiver.
  ///
  /// [url] has to be independently playable — a progressive (muxed) file or an
  /// HLS manifest, never the video-only adaptive track used locally.
  Future<bool> loadMedia({
    required String url,
    String? title,
    String? subtitle,
    String? imageUrl,
    String contentType = 'video/mp4',
    bool isLive = false,
    int positionMs = 0,
  }) async {
    if (!isSupportedPlatform || url.isEmpty) return false;
    try {
      return await _methods.invokeMethod<bool>('loadMedia', {
            'url': url,
            'title': title,
            'subtitle': subtitle,
            'imageUrl': imageUrl,
            'contentType': contentType,
            'isLive': isLive,
            'positionMs': positionMs,
          }) ??
          false;
    } on PlatformException catch (e) {
      dev.log('loadMedia failed: ${e.code} ${e.message}', name: 'CastService');
      return false;
    }
  }

  Future<void> stopCasting() async {
    if (!isSupportedPlatform) return;
    try {
      await _methods.invokeMethod<bool>('stop');
    } on PlatformException catch (e) {
      dev.log('stop failed: ${e.code}', name: 'CastService');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
