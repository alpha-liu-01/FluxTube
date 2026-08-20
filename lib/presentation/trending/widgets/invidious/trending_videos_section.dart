import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/domain/subscribes/models/subscribe.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/presentation/trending/widgets/invidious/home_video_info_card_widget.dart';
import 'package:go_router/go_router.dart';

class InvidiousTrendingVideosSection extends StatefulWidget {
  const InvidiousTrendingVideosSection({
    super.key,
    required this.locals,
    required this.state,
  });

  final S locals;
  final TrendingState state;

  @override
  State<InvidiousTrendingVideosSection> createState() =>
      _InvidiousTrendingVideosSectionState();
}

class _InvidiousTrendingVideosSectionState
    extends State<InvidiousTrendingVideosSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<TrendingBloc>().add(
            const TrendingEvent.loadMoreInvidiousTrending(),
          );
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll - 200);
  }

  @override
  Widget build(BuildContext context) {
    final displayCount = widget.state.invidiousTrendingDisplayCount;
    final totalCount = widget.state.invidiousTrendingResult.length;
    final itemCount = displayCount.clamp(0, totalCount);
    final hasMore = displayCount < totalCount;
    final isLoading = widget.state.isLoadingMoreInvidiousTrending;

    return BlocBuilder<SubscribeBloc, SubscribeState>(
      buildWhen: (previous, current) =>
          previous.subscribedChannels != current.subscribedChannels,
      builder: (context, subscribeState) {
        return ListView.separated(
          controller: _scrollController,
          scrollCacheExtent: const ScrollCacheExtent.pixels(500),
          separatorBuilder: (context, index) => kHeightBox10,
          itemBuilder: (context, index) {
            // Show loading indicator at the end
            if (index >= itemCount) {
              return _buildLoadingIndicator(hasMore, isLoading);
            }

            final trending = widget.state.invidiousTrendingResult[index];
            final String videoId = trending.videoId ?? '';

            if (videoId.isEmpty) {
              return const SizedBox.shrink();
            }

            final String channelId = trending.authorId ?? '';

            if (channelId.isEmpty) {
              return const SizedBox.shrink();
            }

            final bool isSubscribed = subscribeState.subscribedChannels
                .any((channel) => channel.id == channelId);
            return GestureDetector(
              key: ValueKey('trending_$videoId'),
              onTap: () {
                BlocProvider.of<WatchBloc>(context).add(
                    WatchEvent.setSelectedVideoBasicDetails(
                        details: VideoBasicInfo(
                            id: videoId,
                            title: trending.title,
                            thumbnailUrl: trending.videoThumbnails!.first.url,
                            channelName: trending.author,
                            channelThumbnailUrl: null,
                            channelId: channelId,
                            uploaderVerified: trending.authorVerified)));
                context.goNamed('watch', pathParameters: {
                  'videoId': videoId,
                  'channelId': channelId,
                });
              },
              child: InvidiousTrendingVideoInfoCardWidget(
                channelId: channelId,
                cardInfo: trending,
                isSubscribed: isSubscribed,
                onSubscribeTap: () {
                  if (isSubscribed) {
                    BlocProvider.of<SubscribeBloc>(context)
                        .add(SubscribeEvent.deleteSubscribeInfo(id: channelId));
                  } else {
                    BlocProvider.of<SubscribeBloc>(context).add(
                        SubscribeEvent.addSubscribe(
                            channelInfo: Subscribe(
                                id: channelId,
                                channelName: trending.author ??
                                    widget.locals.noUploaderName,
                                isVerified: trending.authorVerified ?? false)));
                  }
                },
              ),
            );
          },
          itemCount: hasMore ? itemCount + 1 : itemCount,
        );
      },
    );
  }

  Widget _buildLoadingIndicator(bool hasMore, bool isLoading) {
    if (!hasMore) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
