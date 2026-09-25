import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/player/global_player_controller.dart';
import 'package:fluxtube/domain/subscribes/models/subscribe.dart';
import 'package:fluxtube/domain/watch/models/newpipe/newpipe_watch_resp.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/widgets/common_video_description_widget.dart';
import 'package:go_router/go_router.dart';

class NewPipeChannelInfoSection extends StatelessWidget {
  const NewPipeChannelInfoSection({
    super.key,
    required this.watchInfo,
    required this.locals,
    required this.state,
    this.keepVisible = false,
  });

  final NewPipeWatchResp watchInfo;
  final S locals;
  final WatchState state;

  /// Wide layout keeps the channel row while comments sit in the side column.
  final bool keepVisible;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: keepVisible || !state.isTapComments,
      child: BlocBuilder<SubscribeBloc, SubscribeState>(
        builder: (context, subscribeState) {
          final String? channelId = _extractChannelId(watchInfo.uploaderUrl);
          if (channelId == null) return const SizedBox();

          final bool isSubscribed = subscribeState.channelInfo?.id == channelId;

          return GestureDetector(
            onTap: () {
              // Enable PiP mode when navigating away from watch screen
              final settingsState = context.read<SettingsBloc>().state;
              if (!settingsState.isPipDisabled) {
                GlobalPlayerController().enterPipMode();
                BlocProvider.of<WatchBloc>(context)
                    .add(WatchEvent.togglePip(value: true));
              }
              context.pushNamed('channel', pathParameters: {
                'channelId': channelId,
              }, queryParameters: {
                'avatarUrl': watchInfo.uploaderAvatarUrl,
              });
            },
            child: SubscribeRowWidget(
              subscribed: isSubscribed,
              uploaderUrl: watchInfo.uploaderAvatarUrl,
              subcount: watchInfo.uploaderSubscriberCount?.toString(),
              uploader: watchInfo.uploaderName ?? locals.noUploaderName,
              isVerified: watchInfo.uploaderVerified ?? false,
              onSubscribeTap: () {
                if (isSubscribed) {
                  BlocProvider.of<SubscribeBloc>(context)
                      .add(SubscribeEvent.deleteSubscribeInfo(id: channelId));
                } else {
                  BlocProvider.of<SubscribeBloc>(context).add(
                      SubscribeEvent.addSubscribe(
                          channelInfo: Subscribe(
                              id: channelId,
                              channelName: watchInfo.uploaderName ??
                                  locals.noUploaderName,
                              isVerified: watchInfo.uploaderVerified ?? false,
                              avatarUrl: watchInfo.uploaderAvatarUrl)));
                }
              },
            ),
          );
        },
      ),
    );
  }

  String? _extractChannelId(String? uploaderUrl) {
    if (uploaderUrl == null) return null;
    final uri = Uri.tryParse(uploaderUrl);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final channelIndex = uri.pathSegments.indexOf('channel');
      if (channelIndex != -1 && channelIndex + 1 < uri.pathSegments.length) {
        return uri.pathSegments[channelIndex + 1];
      }
    }
    return null;
  }
}
