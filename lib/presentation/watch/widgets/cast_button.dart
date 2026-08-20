import 'package:flutter/material.dart';
import 'package:fluxtube/core/services/cast_service.dart';
import 'package:fluxtube/generated/l10n.dart';

/// Everything a receiver needs to play one video.
class CastMedia {
  const CastMedia({
    required this.url,
    this.title,
    this.subtitle,
    this.imageUrl,
    this.contentType = 'video/mp4',
    this.isLive = false,
    this.positionMs = 0,
  });

  /// Must be independently playable — a progressive (muxed) stream or an HLS
  /// manifest, never a video-only adaptive track.
  final String url;
  final String? title;
  final String? subtitle;
  final String? imageUrl;
  final String contentType;
  final bool isLive;
  final int positionMs;
}

/// Cast button that mirrors real session state.
///
/// Hidden unless the Cast framework is present *and* has found a receiver, so
/// it never advertises casting on a device that cannot do it. Once a session
/// starts, [mediaProvider] is asked for the stream to hand over.
class CastButton extends StatefulWidget {
  const CastButton({super.key, this.mediaProvider, this.onCastStarted});

  /// Called when a stream is needed. Returning null skips loading.
  final CastMedia? Function()? mediaProvider;

  /// Fired once media has been handed to the receiver, so the caller can pause
  /// local playback.
  final VoidCallback? onCastStarted;

  @override
  State<CastButton> createState() => _CastButtonState();
}

class _CastButtonState extends State<CastButton> {
  final _cast = CastService();
  CastState _lastState = CastState.unavailable;

  @override
  void initState() {
    super.initState();
    _lastState = _cast.state;
    _cast.addListener(_onCastChanged);
    _cast.start();
  }

  @override
  void dispose() {
    _cast.removeListener(_onCastChanged);
    _cast.stop();
    super.dispose();
  }

  void _onCastChanged() {
    final previous = _lastState;
    _lastState = _cast.state;
    if (mounted) setState(() {});

    // A session just came up: push the current video across.
    if (previous != CastState.connected && _cast.state == CastState.connected) {
      _loadCurrentMedia();
    }
  }

  Future<void> _loadCurrentMedia() async {
    final media = widget.mediaProvider?.call();
    if (media == null || media.url.isEmpty) return;
    final ok = await _cast.loadMedia(
      url: media.url,
      title: media.title,
      subtitle: media.subtitle,
      imageUrl: media.imageUrl,
      contentType: media.contentType,
      isLive: media.isLive,
      positionMs: media.positionMs,
    );
    if (!mounted) return;
    if (ok) {
      widget.onCastStarted?.call();
    } else {
      _toast(S.of(context).castFailed);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ));
  }

  Future<void> _onPressed() async {
    final locals = S.of(context);
    if (_cast.isConnected) {
      final shouldStop = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(locals.castTitle),
          content: Text(_cast.deviceName == null
              ? locals.castConnected
              : locals.castConnectedTo(_cast.deviceName!)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(locals.cancel)),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(locals.castStop)),
          ],
        ),
      );
      if (shouldStop == true) await _cast.stopCasting();
      return;
    }

    final opened = await _cast.showPicker();
    if (!opened && mounted) _toast(locals.castUnavailable);
  }

  @override
  Widget build(BuildContext context) {
    if (!CastService.isSupportedPlatform || !_cast.isCastable) {
      return const SizedBox.shrink();
    }
    final locals = S.of(context);
    final connecting = _cast.state == CastState.connecting;

    return IconButton(
      tooltip: _cast.isConnected
          ? (_cast.deviceName ?? locals.castConnected)
          : locals.castTitle,
      onPressed: connecting ? null : _onPressed,
      icon: connecting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Icon(
              _cast.isConnected ? Icons.cast_connected : Icons.cast,
              color: _cast.isConnected ? Colors.lightBlueAccent : Colors.white,
            ),
    );
  }
}
