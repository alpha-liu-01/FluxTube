import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/enums.dart';
import 'package:fluxtube/domain/search/models/piped/item.dart';
import 'package:fluxtube/domain/subscribes/models/subscribe.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

class SearcheResultSection extends StatefulWidget {
  const SearcheResultSection({
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
  State<SearcheResultSection> createState() => _SearcheResultSectionState();
}

class _SearcheResultSectionState extends State<SearcheResultSection> {
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
        nextPage: widget.state.result?.nextpage,
        serviceType: YouTubeServices.piped.name,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubscribeBloc, SubscribeState>(
      buildWhen: (previous, current) =>
          previous.subscribedChannels != current.subscribedChannels,
      builder: (context, subscribeState) {
        final items = widget.state.result?.items ?? [];
        return ListView.separated(
          controller: _scrollController,
          scrollCacheExtent: const ScrollCacheExtent.pixels(500),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index < items.length) {
              final Item result = items[index];

              if (result.type == "channel") {
                final String channelId = result.url!.split("/").last;
                final bool isSubscribed = subscribeState.subscribedChannels
                    .any((channel) => channel.id == channelId);
                return ChannelWidget(
                  key: ValueKey('channel_$channelId'),
                  channelName: result.name,
                  isVerified: result.verified,
                  subscriberCount: result.subscribers,
                  thumbnail: result.thumbnail,
                  isSubscribed: isSubscribed,
                  channelId: channelId,
                  locals: widget.locals,
                );
              } else if (result.type == "playlist") {
                final String playlistId = result.url!.split('=').last;
                return PlaylistWidget(
                  key: ValueKey('playlist_$playlistId'),
                  playlistId: playlistId,
                  title: result.name,
                  thumbnail: result.thumbnail,
                  videoCount: result.videos,
                  uploaderName: result.uploaderName,
                  uploaderAvatar: result.uploaderAvatar,
                  onTap: () {
                    context.goNamed('playlist', pathParameters: {
                      'playlistId': playlistId,
                    });
                  },
                );
              } else if (result.type == "stream") {
                final String videoId = result.url?.split('=').last ?? '';
                final String channelId =
                    result.uploaderUrl?.split("/").last ?? '';

                if (videoId.isEmpty || channelId.isEmpty) {
                  return const SizedBox.shrink();
                }

                final bool isSubscribed = subscribeState.subscribedChannels
                    .any((channel) => channel.id == channelId);
                return HomeVideoInfoCardWidget(
                  key: ValueKey('video_$videoId'),
                  channelId: channelId,
                  cardInfo: result,
                  isSubscribed: isSubscribed,
                  onTap: () {
                    BlocProvider.of<WatchBloc>(context).add(
                      WatchEvent.setSelectedVideoBasicDetails(
                        details: VideoBasicInfo(
                          id: videoId,
                          title: result.title,
                          thumbnailUrl: result.thumbnail,
                          channelName: result.uploaderName,
                          channelThumbnailUrl: result.uploaderAvatar,
                          channelId: channelId,
                          uploaderVerified: result.uploaderVerified,
                        ),
                      ),
                    );
                    context.goNamed('watch', pathParameters: {
                      'videoId': videoId,
                      'channelId': channelId,
                    });
                  },
                  onSubscribeTap: () {
                    if (isSubscribed) {
                      BlocProvider.of<SubscribeBloc>(context).add(
                          SubscribeEvent.deleteSubscribeInfo(id: channelId));
                    } else {
                      BlocProvider.of<SubscribeBloc>(context).add(
                        SubscribeEvent.addSubscribe(
                          channelInfo: Subscribe(
                            id: channelId,
                            channelName: result.uploaderName ??
                                widget.locals.noUploaderName,
                            isVerified: result.uploaderVerified ?? false,
                          ),
                        ),
                      );
                    }
                  },
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
              (widget.state.fetchMoreSearchResultStatus == ApiStatus.loading ? 1 : 0),
        );
      },
    );
  }
}
