import 'dart:async';
import 'dart:io';

import 'dart:ffi';

import 'package:fluxtube/core/player/global_player_controller.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

const memoryLogPath = '/tmp/fluxtube-mem.log';

void sampleMemory(String label, {bool detailed = false}) {
  if (!Platform.isLinux) return;
  final cache = PaintingBinding.instance.imageCache;
  var rss = '';
  var threads = '';
  try {
    for (final line in File('/proc/self/status').readAsLinesSync()) {
      if (line.startsWith('VmRSS:')) rss = line.trim();
      if (line.startsWith('Threads:')) threads = line.trim();
    }
  } catch (_) {}
  var anonRollup = '';
  try {
    for (final line in File('/proc/self/smaps_rollup').readAsLinesSync()) {
      if (line.startsWith('Anonymous:')) {
        anonRollup = line.trim();
        break;
      }
    }
  } catch (_) {}
  final detail = detailed ? ' ${smapsSummary()}' : '';
  final entry =
      '${DateTime.now().toIso8601String()} $label images=${cache.currentSize} imageBytes=${cache.currentSizeBytes} $rss $threads $anonRollup$detail\n';
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
  final largeAnon = <String>[];
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
    if (key == 'anon' && rss >= 1024) {
      final tag = (name == null || name!.isEmpty) ? 'anon' : name!;
      largeAnon.add('$rss:$tag');
    }
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
  final noNav = Platform.environment['FLUXTUBE_MEM_NO_NAV'] == '1';
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
  final tight = Platform.environment['FLUXTUBE_MEM_TIGHT'] == '1';
  final gap = Duration(seconds: tight ? 1 : 20);
  unawaited(() async {
    sampleMemory('probe-start');
    for (var i = 0; i < ids.length; i++) {
      await Future<void>.delayed(gap);
      if (!context.mounted) return;
      sampleMemory('before-video-${i + 1}');
      if (playerOnly) {
        await playVideoOnly(sameUrl ? ids[0] : ids[i]);
      } else if (!noNav) {
        context.go('/main/watch/${ids[i]}/memprobe');
      }
      if (i == 0 || i == ids.length - 1) {
        await Future<void>.delayed(Duration(seconds: tight ? 1 : 12));
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
    await Future<void>.delayed(Duration(seconds: tight ? 1 : 25));
    if (Platform.environment['FLUXTUBE_MEM_TRIM'] == '1') {
      DynamicLibrary.open('libc.so.6')
          .lookupFunction<Int32 Function(Uint64), int Function(int)>(
              'malloc_trim')(0);
      await Future<void>.delayed(const Duration(seconds: 1));
      sampleMemory('after-trim', detailed: true);
    }
    if (Platform.environment['FLUXTUBE_MEM_DISPOSE_END'] == '1') {
      GlobalPlayerController().disposePlayer();
      await Future<void>.delayed(const Duration(seconds: 8));
      sampleMemory('after-dispose', detailed: true);
    }
    sampleMemory('probe-end');
  }());
}
