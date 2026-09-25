import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

const memoryLogPath = '/tmp/fluxtube-mem.log';

void sampleMemory(String label, {bool detailed = false}) {
  if (!Platform.isLinux) return;
  final cache = PaintingBinding.instance.imageCache;
  var rss = '';
  try {
    for (final line in File('/proc/self/status').readAsLinesSync()) {
      if (line.startsWith('VmRSS:')) {
        rss = line.trim();
        break;
      }
    }
  } catch (_) {}
  final detail = detailed ? ' ${smapsSummary()}' : '';
  final entry =
      '${DateTime.now().toIso8601String()} $label images=${cache.currentSize} imageBytes=${cache.currentSizeBytes} $rss$detail\n';
  try {
    File(memoryLogPath).writeAsStringSync(entry, mode: FileMode.append);
  } catch (_) {}
}

String smapsSummary() {
  final totals = <String, int>{
    'heap': 0,
    'anon': 0,
    'dri': 0,
    'memfd': 0,
    'mpv': 0,
    'other': 0,
  };
  final largeAnon = <int>[];
  String? name;
  var rss = 0;
  void add() {
    if (name == null) return;
    final key = name == '[heap]'
        ? 'heap'
        : (name!.isEmpty || name!.startsWith('[anon'))
            ? 'anon'
            : name!.contains('/dev/dri')
                ? 'dri'
                : name!.contains('memfd')
                    ? 'memfd'
                    : name!.contains('mpv')
                        ? 'mpv'
                        : 'other';
    totals[key] = totals[key]! + rss;
    if (key == 'anon' && rss >= 1024) largeAnon.add(rss);
  }

  try {
    for (final line in File('/proc/self/smaps').readAsLinesSync()) {
      if (line.endsWith('kB') && line.startsWith('Rss:')) {
        rss = int.tryParse(line.split(RegExp(r'\s+'))[1]) ?? 0;
        continue;
      }
      if (line.contains('-') && !line.startsWith('Rss') && line.contains(' ')) {
        add();
        final parts = line.split(' ');
        name = parts.last == '0' && parts.length > 5 ? '' : parts.last;
        if (name == line) name = '';
        rss = 0;
      }
    }
    add();
  } catch (e) {
    return 'smaps-error=$e';
  }
  final sum = totals.values.fold<int>(0, (a, b) => a + b);
  final parts = totals.entries.map((e) => '${e.key}=${e.value}kB').join(' ');
  largeAnon.sort();
  return 'smaps=$sum kB $parts largeAnon=${largeAnon.length} [${largeAnon.join(',')}]';
}

void startMemoryProbe(
  BuildContext context, {
  required Future<String> Function() readDemuxerCache,
  required Future<void> Function(String videoId) playVideoOnly,
}) {
  if (Platform.environment['FLUXTUBE_MEM_PROBE'] != '1') return;
  final playerOnly = Platform.environment['FLUXTUBE_MEM_PLAYER_ONLY'] == '1';
  final sameUrl = Platform.environment['FLUXTUBE_MEM_SAME_URL'] == '1';
  const ids = [
    'jNQXAC9IVRw',
    'dQw4w9WgXcQ',
    'M7lc1UVf-VE',
    'e-ORhEE9VVg',
    '9bZkp7q19f0',
    'kJQP7kiw5Fk',
    'fJ9rUzIMcZQ',
    'CevxZvSJLk8',
  ];
  unawaited(() async {
    sampleMemory('probe-start');
    for (var i = 0; i < ids.length; i++) {
      await Future<void>.delayed(const Duration(seconds: 20));
      if (!context.mounted) return;
      sampleMemory('before-video-${i + 1}');
      if (playerOnly) {
        await playVideoOnly(sameUrl ? ids[0] : ids[i]);
      } else {
        context.go('/main/watch/${ids[i]}/memprobe');
      }
      if (i == 0 || i == ids.length - 1) {
        await Future<void>.delayed(const Duration(seconds: 12));
        if (!context.mounted) return;
        var cache = 'unread';
        try {
          cache = await readDemuxerCache();
        } catch (e) {
          cache = 'error:$e';
        }
        sampleMemory('after-video-${i + 1} demuxer=$cache', detailed: true);
      }
    }
    await Future<void>.delayed(const Duration(seconds: 25));
    sampleMemory('probe-end');
  }());
}
