import 'package:flutter/material.dart';
import 'package:fluxtube/domain/playlist/models/local_playlist.dart';
import 'package:fluxtube/infrastructure/playlist/local_playlist_service.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxtube/generated/l10n.dart';

class ScreenLocalPlaylists extends StatefulWidget {
  const ScreenLocalPlaylists({super.key});

  @override
  State<ScreenLocalPlaylists> createState() => _ScreenLocalPlaylistsState();
}

class _ScreenLocalPlaylistsState extends State<ScreenLocalPlaylists> {
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

  @override
  Widget build(BuildContext context) {
    final playlists = _service.playlists;
    final locals = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(locals.localPlaylists),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createPlaylist,
          ),
        ],
      ),
      body: playlists.isEmpty
          ? Center(
              child: Text(locals.noPlaylistsYet,
                  textAlign: TextAlign.center),
            )
          : ListView.builder(
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(Icons.playlist_play, size: 22),
                  title: Text(playlist.name,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                      '${locals.videoCountLabel(playlist.videoIds.length)} · ${_formatDate(playlist.createdAt)}',
                      style: const TextStyle(fontSize: 11)),
                  trailing: PopupMenuButton(
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'rename', child: Text(locals.renameAction)),
                      PopupMenuItem(
                          value: 'delete',
                          child: Text(locals.delete,
                              style: const TextStyle(color: Colors.red))),
                    ],
                    onSelected: (action) {
                      if (action == 'rename') _renamePlaylist(playlist);
                      if (action == 'delete') _deletePlaylist(playlist);
                    },
                  ),
                  onTap: () => context.pushNamed('playlistDetail',
                      pathParameters: {'playlistId': playlist.id}),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _createPlaylist() async {
    final locals = S.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(locals.newPlaylist),
        content: TextField(
          autofocus: true,
          controller: controller,
          decoration: InputDecoration(hintText: locals.playlistNameHint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(locals.cancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(locals.createAction)),
        ],
      ),
    );
    await Future.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) {
      _service.create(name.trim());
    }
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
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(locals.cancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
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

  void _deletePlaylist(LocalPlaylist playlist) {
    final locals = S.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(locals.deletePlaylistTitle),
        content: Text(locals.deletePlaylistConfirm(playlist.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: Text(locals.cancel)),
          TextButton(
              onPressed: () {
                _service.delete(playlist.id);
                Navigator.of(ctx).pop();
              },
              child: Text(locals.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
