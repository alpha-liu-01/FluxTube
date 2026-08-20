import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/enums.dart';
import 'package:fluxtube/domain/search/models/invidious/invidious_search_resp.dart';
import 'package:fluxtube/domain/subscribes/models/subscribe.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/presentation/search/widgets/widgets.dart';
import 'package:fluxtube/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

class InvidiousSearcheResultSection extends StatefulWidget {
  const InvidiousSearcheResultSection({
    super.key,
    required this.locals,
    required this.state,
    required this.searchQuery,
    this.filter = "all",
  });

  final S locals;
  final SearchState state;
  final String searchQuery;
  final String filter;

  @override
  State<InvidiousSearcheResultSection> createState() =>
      _InvidiousSearcheResultSectionState();
}

class _InvidiousSearcheResultSectionState
    extends State<InvidiousSearcheResultSection> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !(widget.state.fetchMoreSearchResultStatus == ApiStatus.loading) &&
        !widget.state.isMoreFetchCompleted) {
      BlocProvider.of<SearchBloc>(context).add(SearchEvent.getMoreSearchResult(
        query: widget.searchQuery,
        filter: widget.filter,
        nextPage: null,
        serviceType: YouTubeServices.invidious.name,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubscribeBloc, SubscribeState>(
      buildWhen: (previous, current) =>
          previous.subscribedChannels != current.subscribedChannels,
      builder: (context, subscribeState) {
        final items = widget.state.invidiousSearchResult;
        return ListView.separated(
          controller: _scrollController,
          scrollCacheExtent: const ScrollCacheExtent.pixels(500),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index < items.length) {
              final InvidiousSearchResp result = items[index];

              if (result.type == "channel") {
                final String channelId = result.authorId!;
                final bool isSubscribed = subscribeState.subscribedChannels
                    .any((channel) => channel.id == channelId);
                return ChannelWidget(
                  key: ValueKey('channel_$channelId'),
                  channelName: result.author,
                  isVerified: result.authorVerified,
                  subscriberCount: result.subCount,
                  thumbnail: 'https:${result.authorThumbnails?.last.url}',
                  isSubscribed: isSubscribed,
                  channelId: channelId,
                  locals: widget.locals,
                );
              } else if (result.type == "playlist") {
                final String playlistId = result.playlistId!;
                String? thumbnail = result.playlistThumbnail;
                if (thumbnail != null && !thumbnail.startsWith('http')) {
                  thumbnail = 'https:$thumbnail';
                }
                return PlaylistWidget(
                  key: ValueKey('playlist_$playlistId'),
                  playlistId: playlistId,
                  title: result.title,
                  thumbnail: thumbnail,
                  videoCount: result.videoCount,
                  uploaderName: result.author,
                  onTap: () {
                    context.goNamed('playlist', pathParameters: {
                      'playlistId': playlistId,
                    });
                  },
                );
              } else if (result.type == "video") {
                final String videoId = result.videoId ?? '';
                final String channelId = result.authorId ?? '';

                if (videoId.isEmpty || channelId.isEmpty) {
                  return const SizedBox.shrink();
                }

                final bool isSubscribed = subscribeState.subscribedChannels
                    .any((channel) => channel.id == channelId);
                return GestureDetector(
                  key: ValueKey('video_$videoId'),
                  onTap: () {
                    BlocProvider.of<WatchBloc>(context).add(
                      WatchEvent.setSelectedVideoBasicDetails(
                        details: VideoBasicInfo(
                          id: videoId,
                          title: result.title,
                          thumbnailUrl: result.videoThumbnails!.first.url,
                          channelName: result.author,
                          channelThumbnailUrl: null,
                          channelId: channelId,
                          uploaderVerified: result.authorVerified,
                        ),
                      ),
                    );
                    context.goNamed('watch', pathParameters: {
                      'videoId': videoId,
                      'channelId': channelId,
                    });
                  },
                  child: InvidiousSearchVideoInfoCardWidget(
                    channelId: channelId,
                    cardInfo: result,
                    isSubscribed: isSubscribed,
                    onSubscribeTap: () {
                      if (isSubscribed) {
                        BlocProvider.of<SubscribeBloc>(context).add(
                            SubscribeEvent.deleteSubscribeInfo(id: channelId));
                      } else {
                        BlocProvider.of<SubscribeBloc>(context).add(
                          SubscribeEvent.addSubscribe(
                            channelInfo: Subscribe(
                              id: channelId,
                              channelName:
                                  result.author ?? widget.locals.noUploaderName,
                              isVerified: result.authorVerified ?? false,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              } else {
                return const SizedBox();
              }
            } else {
              // Only show loading indicator when actually loading more
              return cIndicator(context);
            }
          },
          // Only add extra item when loading more results
          itemCount: items.length +
              (widget.state.fetchMoreInvidiousSearchResultStatus == ApiStatus.loading ? 1 : 0),
        );
      },
    );
  }
}
