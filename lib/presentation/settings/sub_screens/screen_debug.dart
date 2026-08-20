import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluxtube/core/services/log_collector.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class ScreenDebug extends StatefulWidget {
  const ScreenDebug({super.key});

  @override
  State<ScreenDebug> createState() => _ScreenDebugState();
}

class _ScreenDebugState extends State<ScreenDebug> {
  final _scrollController = ScrollController();
  final _collector = LogCollector();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locals = S.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(locals.debugConsole),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.share),
            tooltip: locals.shareLogs,
            onPressed: _shareLogs,
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.delete),
            tooltip: locals.clearLogs,
            onPressed: () {
              _collector.clear();
              setState(() {});
            },
          ),
          IconButton(
            icon: Icon(_autoScroll
                ? CupertinoIcons.arrow_down
                : CupertinoIcons.pause),
            tooltip: _autoScroll ? locals.autoScrollOn : locals.autoScrollOff,
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildInfoBar(isDark, locals),
          Expanded(
            child: StreamBuilder<String>(
              stream: _collector.stream,
              builder: (context, snapshot) {
                final entries = _collector.entries;
                if (entries.isEmpty) {
                  return Center(child: Text(locals.noLogs));
                }
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final color = entry.tag == 'ERROR'
                        ? Colors.red
                        : entry.tag == 'WARN'
                            ? Colors.orange
                            : isDark
                                ? Colors.white70
                                : Colors.black54;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 1),
                      child: Text(
                        entry.formatted,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: color,
                        ),
                      ),
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

  Widget _buildInfoBar(bool isDark, S locals) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
      child: Row(
        children: [
          _infoChip(locals.logsLabel, '${_collector.entries.length}'),
          const SizedBox(width: 8),
          _infoChip(locals.imageCacheLabel,
              '${PaintingBinding.instance.imageCache.currentSize}'),
          const SizedBox(width: 8),
          _infoChip(locals.platformLabel, Platform.operatingSystem),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
      ),
    );
  }

  void _scrollToBottom() {
    if (!_autoScroll || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      _scrollController.jumpTo(maxScroll);
    }
  }

  Future<void> _shareLogs() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/fluxtube_debug.log');
    await file.writeAsString(_collector.fullLog);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }
}
