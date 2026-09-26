import 'package:flutter/material.dart';
import 'package:fluxtube/widgets/thumbnail_image.dart';
import 'package:fluxtube/core/animations/animations.dart';
import 'package:fluxtube/core/colors.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/core/operations/math_operations.dart';
import 'package:fluxtube/core/player/playback_queue.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';
import 'package:fluxtube/domain/watch/models/newpipe/newpipe_related.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/infrastructure/playlist/local_playlist_service.dart';
import 'package:fluxtube/presentation/search/widgets/newpipe/home_video_info_card_widget.dart';
import 'package:fluxtube/widgets/common_video_description_widget.dart';
import 'package:go_router/go_router.dart';

/// NewPipe-specific video card widget for channel videos
class NewPipeChannelVideoCard extends StatelessWidget {
  const NewPipeChannelVideoCard({
    super.key,
    required this.videoInfo,
    required this.channelId,
    this.subscribeRowVisible = false,
    this.isSubscribed = false,
    this.onSubscribeTap,
    this.onTap,
    this.index = 0,
    this.aspectRatioThumbnail = false,
  });

  final NewPipeRelatedStream videoInfo;
  final String channelId;
  final bool subscribeRowVisible;
  final bool isSubscribed;
  final VoidCallback? onSubscribeTap;
  final VoidCallback? onTap;
  final int index;

  /// 16:9 thumbnail with no outer horizontal padding, for a multi-column row.
  final bool aspectRatioThumbnail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locals = S.of(context);
    final String duration =
        formatDuration(videoInfo.isLive == true ? -1 : videoInfo.duration);
    final isLiveVideo = duration == "Live";

    return AnimatedListItem(
      index: index,
      child: ScaleTap(
        scaleDown: 0.98,
        enableHaptic: false,
        onTap: onTap,
        onLongPress: () => _showQueueOptions(context, videoInfo, channelId),
        child: Padding(
          padding: EdgeInsets.only(
            top: AppSpacing.xs,
            left: aspectRatioThumbnail ? 0 : AppSpacing.lg,
            right: aspectRatioThumbnail ? 0 : AppSpacing.lg,
            bottom: AppSpacing.md,
          ),
          child: Column(
            children: [
              // Thumbnail container
              aspectRatioThumbnail
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _thumbnail(isDark, duration, isLiveVideo),
                      ),
                    )
                  : _thumbnail(isDark, duration, isLiveVideo),

              // Video info section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Column(
                  children: [
                    // Title
                    CaptionRowWidget(
                      caption: videoInfo.name ?? locals.noVideoTitle,
                    ),

                    AppSpacing.height4,

                    // Views and date
                    ViewRowWidget(
                      views: videoInfo.viewCount ?? 0,
                      uploadedDate: videoInfo.uploadDate ?? locals.noUploadDate,
                    ),

                    AppSpacing.height8,

                    // Channel info row
                    if (subscribeRowVisible)
                      ScaleTap(
                        onTap: () => context.pushNamed(
                          'channel',
                          pathParameters: {'channelId': channelId},
                          queryParameters: {
                            'avatarUrl': videoInfo.uploaderAvatarUrl
                          },
                        ),
                        enableHaptic: false,
                        child: SubscribeRowWidget(
                          uploaderUrl: videoInfo.uploaderAvatarUrl ?? '',
                          uploader:
                              videoInfo.uploaderName ?? locals.noUploaderName,
                          isVerified: videoInfo.uploaderVerified,
                          subscribed: isSubscribed,
                          onSubscribeTap: onSubscribeTap,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(bool isDark, String duration, bool isLiveVideo) {
    return Container(
      margin: EdgeInsets.only(bottom: aspectRatioThumbnail ? 0 : AppSpacing.sm),
      width: double.infinity,
      height: aspectRatioThumbnail ? null : 210,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
        borderRadius: AppRadius.borderMd,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.borderMd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (videoInfo.thumbnailUrl != null)
              ThumbnailImage.small(url: videoInfo.thumbnailUrl!),
            Positioned(
              bottom: AppSpacing.sm,
              right: AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: isLiveVideo ? AppColors.youtubeRed : kBlackColor,
                  borderRadius: AppRadius.borderXs,
                ),
                child: Text(
                  duration,
                  style: TextStyle(
                    color: kWhiteColor,
                    fontSize: AppFontSize.caption,
                    fontWeight:
                        isLiveVideo ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (videoInfo.contentAvailability != null)
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: ContentAvailabilityBadge(
                  availability: videoInfo.contentAvailability!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Long-press actions for a channel video: queue it, or save it to a playlist.
///
/// [context] must be the screen-level context, not a sheet's — the sheet is
/// dismissed before the follow-up dialog and snackbar are shown.
void _showQueueOptions(
    BuildContext context, NewPipeRelatedStream videoInfo, String channelId) {
  final String videoId = videoInfo.url?.split('=').last ?? '';
  if (videoId.isEmpty) return;

  final basicInfo = VideoBasicInfo(
    id: videoId,
    title: videoInfo.name,
    thumbnailUrl: videoInfo.thumbnailUrl,
    channelName: videoInfo.uploaderName,
    channelThumbnailUrl: videoInfo.uploaderAvatarUrl,
    channelId: channelId,
    uploaderVerified: videoInfo.uploaderVerified,
  );

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final colors = Theme.of(ctx).colorScheme;
      final locals = S.of(ctx);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(ctx),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                videoInfo.name ?? '',
                style:
                    TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.playlist_play, size: 20),
              title: Text(locals.playNext, style: const TextStyle(fontSize: 14)),
              onTap: () {
                PlaybackQueue().addNext(basicInfo);
                Navigator.pop(ctx);
                _toast(context, locals.addedToPlayNext);
              },
            ),
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.queue_music, size: 20),
              title: Text(locals.addToQueue, style: const TextStyle(fontSize: 14)),
              onTap: () {
                PlaybackQueue().add(basicInfo);
                Navigator.pop(ctx);
                _toast(context, locals.addedToQueue);
              },
            ),
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.playlist_add, size: 20),
              title: Text(locals.saveToPlaylist,
                  style: const TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                _showPlaylistPicker(context, basicInfo);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}

void _showPlaylistPicker(BuildContext context, VideoBasicInfo basicInfo) {
  final service = LocalPlaylistService();
  service.load();

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => ListenableBuilder(
      listenable: service,
      builder: (builderContext, _) {
        final colors = Theme.of(builderContext).colorScheme;
        final locals = S.of(builderContext);
        final playlists = service.playlists;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHandle(builderContext),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text(locals.saveToPlaylist,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        // Dismiss the sheet first, then run the dialog on the
                        // screen context — ctx is defunct once popped.
                        Navigator.pop(ctx);
                        _createAndAdd(context, basicInfo, service);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child:
                          Text(locals.newPlaylistShort, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(locals.noPlaylistsYetPicker,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: colors.onSurfaceVariant, fontSize: 14)),
                ),
              ...playlists.map((p) => ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: const Icon(Icons.playlist_play, size: 20),
                    title: Text(p.name, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(locals.videoCountLabel(p.videoIds.length),
                        style: TextStyle(
                            color: colors.onSurfaceVariant, fontSize: 11)),
                    trailing: service.hasVideo(p.id, basicInfo.id)
                        ? Icon(Icons.check, color: colors.primary, size: 18)
                        : null,
                    onTap: () {
                      service.addVideo(
                        p.id,
                        basicInfo.id,
                        basicInfo.title ?? '',
                        thumbnailUrl: basicInfo.thumbnailUrl,
                        channelName: basicInfo.channelName,
                        channelId: basicInfo.channelId,
                      );
                      Navigator.pop(ctx);
                      _toast(context, locals.addedToPlaylist(p.name));
                    },
                  )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ),
  );
}

/// Creates a playlist and drops [basicInfo] into it.
///
/// [context] is the screen context; only the dialog itself is ever popped.
void _createAndAdd(BuildContext context, VideoBasicInfo basicInfo,
    LocalPlaylistService service) {
  final controller = TextEditingController();
  final locals = S.of(context);
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(locals.newPlaylist),
      content: TextField(
        autofocus: true,
        controller: controller,
        decoration: InputDecoration(hintText: locals.playlistNameHint),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(locals.cancel)),
        TextButton(
            onPressed: () {
              final name = controller.text.trim();
              Navigator.pop(dialogContext);
              if (name.isEmpty) return;
              final playlist = service.create(name);
              service.addVideo(
                playlist.id,
                basicInfo.id,
                basicInfo.title ?? '',
                thumbnailUrl: basicInfo.thumbnailUrl,
                channelName: basicInfo.channelName,
                channelId: basicInfo.channelId,
              );
              _toast(context, locals.addedToPlaylist(name));
            },
            child: Text(locals.createAction)),
      ],
    ),
  ).then((_) => controller.dispose());
}

Widget _sheetHandle(BuildContext context) {
  return Container(
    margin: const EdgeInsets.only(top: 8),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color:
          Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

void _toast(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 1),
    ));
}
