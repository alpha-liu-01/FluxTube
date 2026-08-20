import 'package:flutter/material.dart';
import 'package:fluxtube/core/player/playback_queue.dart';
import 'package:fluxtube/domain/playlist/models/local_playlist.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';
import 'package:fluxtube/infrastructure/playlist/local_playlist_service.dart';
import 'package:fluxtube/widgets/thumbnail_image.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:go_router/go_router.dart';

class ScreenPlaylistDetail extends StatefulWidget {
  const ScreenPlaylistDetail({super.key, required this.playlistId});

  final String playlistId;

  @override
  State<ScreenPlaylistDetail> createState() => _ScreenPlaylistDetailState();
}

class _ScreenPlaylistDetailState extends State<ScreenPlaylistDetail> {
  final _service = LocalPlaylistService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
    _service.load();
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  LocalPlaylist? get _playlist => _service.getById(widget.playlistId);

  @override
  Widget build(BuildContext context) {
    final locals = S.of(context);
    final playlist = _playlist;
    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(locals.playlistNotFound)),
      );
    }

    final items = _buildVideoItems(playlist);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(playlist.name, style: const TextStyle(fontSize: 16)),
            Text(locals.videoCountLabel(items.length),
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          ],
        ),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: locals.playAll,
              onPressed: () => _playAll(items),
            ),
          PopupMenuButton(
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(locals.renameAction)),
              PopupMenuItem(
                  value: 'delete',
                  child: Text(locals.deletePlaylistAction,
                      style: const TextStyle(color: Colors.red))),
            ],
            onSelected: (action) {
              if (action == 'rename') _renamePlaylist(playlist);
              if (action == 'delete') {
                _service.delete(playlist.id);
                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.playlist_add,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(locals.noVideosInPlaylist,
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(locals.addVideosHint,
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildVideoRow(context, item, index, playlist);
              },
            ),
    );
  }

  List<_PlaylistVideo> _buildVideoItems(LocalPlaylist playlist) {
    final items = <_PlaylistVideo>[];
    for (int i = 0; i < playlist.videoIds.length; i++) {
      items.add(_PlaylistVideo(
        id: playlist.videoIds[i],
        title: i < playlist.videoTitles.length ? playlist.videoTitles[i] : '',
        thumbnailUrl: i < playlist.thumbnailUrls.length ? playlist.thumbnailUrls[i] : null,
        channelName: i < playlist.channelNames.length ? playlist.channelNames[i] : null,
        channelId: i < playlist.channelIds.length ? playlist.channelIds[i] : null,
      ));
    }
    return items;
  }

  Widget _buildVideoRow(
      BuildContext context, _PlaylistVideo item, int index, LocalPlaylist playlist) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _playVideo(context, item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text('${index + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.outline)),
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 120,
                  height: 68,
                  child: item.thumbnailUrl != null
                      ? ThumbnailImage.small(url: item.thumbnailUrl!)
                      : Container(
                          color: isDark ? Colors.white10 : Colors.black12,
                          child: const Icon(Icons.play_circle_outline,
                              color: Colors.white38),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, height: 1.3)),
                    const SizedBox(height: 4),
                    if (item.channelName != null)
                      Text(item.channelName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Colors.white30,
                onPressed: () {
                  _service.removeVideo(playlist.id, item.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playVideo(BuildContext context, _PlaylistVideo item) {
    context.pushNamed('watch', pathParameters: {
      'videoId': item.id,
      'channelId': item.channelId ?? '',
    });
  }

  /// Loads the whole playlist into the playback queue, then opens the first
  /// video. Without seeding the queue, "Play all" would only play one video.
  void _playAll(List<_PlaylistVideo> items) {
    if (items.isEmpty) return;
    PlaybackQueue().setQueue(
      items
          .map((item) => VideoBasicInfo(
                id: item.id,
                title: item.title,
                thumbnailUrl:
                    (item.thumbnailUrl?.isEmpty ?? true) ? null : item.thumbnailUrl,
                channelName:
                    (item.channelName?.isEmpty ?? true) ? null : item.channelName,
                channelId:
                    (item.channelId?.isEmpty ?? true) ? null : item.channelId,
              ))
          .toList(),
    );
    _playVideo(context, items.first);
  }

  Future<void> _renamePlaylist(LocalPlaylist playlist) async {
    final locals = S.of(context);
    final controller = TextEditingController(text: playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(locals.renamePlaylistTitle),
        content: TextField(
          autofocus: true,
          controller: controller,
          decoration: InputDecoration(hintText: locals.newNameHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(locals.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(locals.renameAction)),
        ],
      ),
    );
    await Future.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) {
      _service.rename(playlist.id, name.trim());
    }
  }
}

class _PlaylistVideo {
  final String id;
  final String title;
  final String? thumbnailUrl;
  final String? channelName;
  final String? channelId;

  _PlaylistVideo({
    required this.id,
    required this.title,
    this.thumbnailUrl,
    this.channelName,
    this.channelId,
  });
}
