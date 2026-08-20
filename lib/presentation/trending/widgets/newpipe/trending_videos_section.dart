import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/domain/subscribes/models/subscribe.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/presentation/trending/widgets/newpipe/home_video_info_card_widget.dart';
import 'package:go_router/go_router.dart';

class NewPipeTrendingVideosSection extends StatefulWidget {
  const NewPipeTrendingVideosSection({
    super.key,
    required this.locals,
    required this.state,
  });

  final S locals;
  final TrendingState state;

  @override
  State<NewPipeTrendingVideosSection> createState() =>
      _NewPipeTrendingVideosSectionState();
}

class _NewPipeTrendingVideosSectionState
    extends State<NewPipeTrendingVideosSection> {
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
            const TrendingEvent.loadMoreNewPipeTrending(),
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
    final displayCount = widget.state.newPipeTrendingDisplayCount;
    final totalCount = widget.state.newPipeTrendingResult.length;
    final itemCount = displayCount.clamp(0, totalCount);
    final hasMore = displayCount < totalCount;
    final isLoading = widget.state.isLoadingMoreNewPipeTrending;

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

            final trending = widget.state.newPipeTrendingResult[index];
            final String? videoId = trending.videoId;

            if (videoId == null || videoId.isEmpty) {
              return const SizedBox.shrink();
            }

            final String channelId =
                trending.uploaderUrl?.split("/").last ?? '';

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
                            title: trending.name,
                            thumbnailUrl: trending.thumbnailUrl,
                            channelName: trending.uploaderName,
                            channelThumbnailUrl: trending.uploaderAvatarUrl,
                            channelId: channelId,
                            uploaderVerified: trending.uploaderVerified)));
                context.goNamed('watch', pathParameters: {
                  'videoId': videoId,
                  'channelId': channelId,
                });
              },
              child: NewPipeTrendingVideoInfoCardWidget(
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
                                channelName: trending.uploaderName ??
                                    widget.locals.noUploaderName,
                                isVerified:
                                    trending.uploaderVerified ?? false)));
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
