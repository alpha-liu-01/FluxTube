import 'package:flutter/material.dart';
import 'package:fluxtube/domain/watch/models/video_chapter.dart';

class ChapterBar extends StatelessWidget {
  const ChapterBar({
    super.key,
    required this.chapters,
    required this.positionSeconds,
    required this.durationSeconds,
    this.onChapterTap,
  });

  final List<VideoChapter> chapters;
  final int positionSeconds;
  final int durationSeconds;
  final Function(int startSeconds)? onChapterTap;

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty || durationSeconds <= 0) {
      return const SizedBox.shrink();
    }

    final activeChapter = _currentChapter;

    return SizedBox(
      height: 24,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: chapters.length,
        itemBuilder: (context, index) {
          final chapter = chapters[index];
          final nextStart = index + 1 < chapters.length
              ? chapters[index + 1].startSeconds
              : durationSeconds;
          final isActive = chapter == activeChapter;
          final width = ((nextStart - chapter.startSeconds) / durationSeconds *
                  MediaQuery.of(context).size.width)
              .clamp(60.0, 200.0);

          return GestureDetector(
            onTap: () => onChapterTap?.call(chapter.startSeconds),
            child: Container(
              width: width,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  chapter.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  VideoChapter? get _currentChapter {
    VideoChapter? current;
    for (final chapter in chapters) {
      if (chapter.startSeconds <= positionSeconds) {
        current = chapter;
      } else {
        break;
      }
    }
    return current;
  }
}
