import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/watch/watch_bloc.dart';
import 'package:fluxtube/core/animations/animations.dart';
import 'package:fluxtube/core/colors.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/core/enums.dart';
import 'package:fluxtube/core/operations/math_operations.dart';
import 'package:fluxtube/domain/watch/models/piped/comments/comment.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/presentation/watch/widgets/shimmer_comment_widgets.dart';
import 'package:fluxtube/widgets/indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:rich_readmore/rich_readmore.dart';
import 'package:simple_html_css/simple_html_css.dart';

/// Modern comments bottom sheet with draggable behavior
/// Supports snap points at 40% and 90% of screen height
class CommentsBottomSheet extends StatefulWidget {
  const CommentsBottomSheet({
    super.key,
    required this.videoId,
    required this.commentCount,
  });

  final String videoId;
  final int commentCount;

  /// Show the comments bottom sheet
  static Future<void> show(
    BuildContext context, {
    required String videoId,
    required int commentCount,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (context) => CommentsBottomSheet(
        videoId: videoId,
        commentCount: commentCount,
      ),
    );
  }

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    // Fetch comments when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WatchBloc>().add(WatchEvent.getCommentData(id: widget.videoId));
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locals = S.of(context);

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.4, 0.6, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surface,
            borderRadius: AppRadius.topXl,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              _DragHandle(),

              // Header
              _CommentsHeader(
                commentCount: widget.commentCount,
                locals: locals,
                onClose: () => Navigator.of(context).pop(),
              ),

              const Divider(height: 1),

              // Comments list
              Expanded(
                child: _CommentsListView(
                  scrollController: scrollController,
                  videoId: widget.videoId,
                  locals: locals,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: isDark ? AppColors.dividerDark : AppColors.divider,
        borderRadius: AppRadius.borderFull,
      ),
    );
  }
}

class _CommentsHeader extends StatelessWidget {
  const _CommentsHeader({
    required this.commentCount,
    required this.locals,
    required this.onClose,
  });

  final int commentCount;
  final S locals;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Text(
            'Comments (${formatCount(commentCount.toString())})',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          ScaleTap(
            onTap: onClose,
            child: Container(
              padding: AppSpacing.paddingXs,
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? AppColors.surfaceVariantDark
                    : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.xmark,
                size: AppIconSize.sm,
                color: theme.brightness == Brightness.dark
                    ? AppColors.onSurfaceDark
                    : AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsListView extends StatefulWidget {
  const _CommentsListView({
    required this.scrollController,
    required this.videoId,
    required this.locals,
  });

  final ScrollController scrollController;
  final String videoId;
  final S locals;

  @override
  State<_CommentsListView> createState() => _CommentsListViewState();
}

class _CommentsListViewState extends State<_CommentsListView> {
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final state = context.read<WatchBloc>().state;
    if (widget.scrollController.position.pixels ==
            widget.scrollController.position.maxScrollExtent &&
        !(state.fetchMoreCommentsStatus == ApiStatus.loading) &&
        !state.isMoreCommentsFetchCompleted) {
      context.read<WatchBloc>().add(WatchEvent.getMoreCommentsData(
          id: widget.videoId, nextPage: state.comments.nextpage));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchBloc, WatchState>(
      buildWhen: (previous, current) =>
          previous.fetchCommentsStatus != current.fetchCommentsStatus ||
          previous.comments != current.comments ||
          previous.fetchMoreCommentsStatus != current.fetchMoreCommentsStatus,
      builder: (context, state) {
        if (state.fetchCommentsStatus == ApiStatus.initial ||
            state.fetchCommentsStatus == ApiStatus.loading) {
          return const ShimmerCommentWidget();
        }

        if (state.fetchCommentsStatus == ApiStatus.error) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_circle,
                  size: AppIconSize.xxl,
                  color: AppColors.error,
                ),
                AppSpacing.height16,
                Text('Error loading comments'),
                AppSpacing.height16,
                ScaleTap(
                  onTap: () {
                    context
                        .read<WatchBloc>()
                        .add(WatchEvent.getCommentData(id: widget.videoId));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: Text(
                      widget.locals.retry,
                      style: const TextStyle(color: AppColors.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (state.comments.comments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.bubble_left_bubble_right,
                  size: AppIconSize.xxl,
                  color: AppColors.disabled,
                ),
                AppSpacing.height16,
                Text(
                  widget.locals.noCommentsFound,
                  style: TextStyle(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        // Only add extra item when loading more comments
        final isLoadingMore = state.fetchMoreCommentsStatus == ApiStatus.loading;
        return ListView.builder(
          controller: widget.scrollController,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          scrollCacheExtent: const ScrollCacheExtent.pixels(500),
          itemCount: state.comments.comments.length + (isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < state.comments.comments.length) {
              final comment = state.comments.comments[index];
              return AnimatedListItem(
                index: index,
                child: CommentCard(
                  key: ValueKey('comment_${comment.commentId ?? index}'),
                  comment: comment,
                  videoId: widget.videoId,
                  locals: widget.locals,
                ),
              );
            } else {
              // Only show loading indicator when actually loading more
              return Padding(
                padding: AppSpacing.verticalLg,
                child: cIndicator(context),
              );
            }
          },
        );
      },
    );
  }
}

/// Individual comment card with modern design
class CommentCard extends StatelessWidget {
  const CommentCard({
    super.key,
    required this.comment,
    required this.videoId,
    required this.locals,
  });

  final Comment comment;
  final String videoId;
  final S locals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formattedLikes = formatCount((comment.likeCount ?? 0).toString());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          ScaleTap(
            onTap: () => _navigateToChannel(context),
            child: CircleAvatar(
              radius: 20,
              backgroundImage: (comment.thumbnail?.isNotEmpty ?? false)
                  ? NetworkImage(comment.thumbnail!)
                  : null,
              backgroundColor:
                  isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
              child: (comment.thumbnail?.isEmpty ?? true)
                  ? Icon(
                      CupertinoIcons.person_fill,
                      size: AppIconSize.sm,
                      color: AppColors.disabled,
                    )
                  : null,
            ),
          ),

          AppSpacing.width12,

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author name
                Text(
                  comment.author ?? locals.commentAuthorNotFound,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.onSurfaceVariantDark
                        : AppColors.onSurfaceVariant,
                  ),
                ),

                AppSpacing.height4,

                // Comment text
                RichReadMoreText(
                  HTML.toTextSpan(
                    context,
                    // Decode HTML entities
                    (comment.commentText ?? '')
                        .replaceAll('&amp;', '&')
                        .replaceAll('&lt;', '<')
                        .replaceAll('&gt;', '>')
                        .replaceAll('&quot;', '"')
                        .replaceAll('&#39;', "'")
                        .replaceAll('&nbsp;', ' '),
                    defaultTextStyle: theme.textTheme.bodyMedium,
                  ),
                  settings: LineModeSettings(
                    trimLines: 4,
                    trimCollapsedText: ' ${locals.readMoreText}',
                    trimExpandedText: ' ${locals.showLessText}',
                    moreStyle: TextStyle(
                      fontSize: AppFontSize.body2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    lessStyle: TextStyle(
                      fontSize: AppFontSize.body2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                AppSpacing.height8,

                // Actions row
                Row(
                  children: [
                    // Likes
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.hand_thumbsup,
                          size: AppIconSize.xs,
                          color: isDark
                              ? AppColors.onSurfaceVariantDark
                              : AppColors.onSurfaceVariant,
                        ),
                        AppSpacing.width4,
                        Text(
                          formattedLikes,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.onSurfaceVariantDark
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                    // Replies button
                    if ((comment.replyCount ?? 0) > 0) ...[
                      AppSpacing.width16,
                      ScaleTap(
                        onTap: () => _showReplies(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.return_icon,
                              size: AppIconSize.xs,
                              color: AppColors.primary,
                            ),
                            AppSpacing.width4,
                            Text(
                              '${formatCount(comment.replyCount.toString())} ${locals.repliesPlural(comment.replyCount!)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToChannel(BuildContext context) {
    if (comment.commentorUrl != null) {
      context.goNamed(
        'channel',
        pathParameters: {
          'channelId': comment.commentorUrl!.split("/").last,
        },
        queryParameters: {
          'avatarUrl': comment.thumbnail,
        },
      );
    }
  }

  void _showReplies(BuildContext context) {
    if (comment.commentId != null && comment.repliesPage != null) {
      context.read<WatchBloc>().add(WatchEvent.getCommentRepliesData(
          id: comment.commentId!, nextPage: comment.repliesPage!));

      _CommentRepliesSheet.show(
        context,
        parentComment: comment,
        videoId: videoId,
        locals: locals,
      );
    }
  }
}

/// Replies sheet for nested comments
class _CommentRepliesSheet extends StatefulWidget {
  const _CommentRepliesSheet({
    required this.parentComment,
    required this.videoId,
    required this.locals,
  });

  final Comment parentComment;
  final String videoId;
  final S locals;

  static Future<void> show(
    BuildContext context, {
    required Comment parentComment,
    required String videoId,
    required S locals,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (context) => _CommentRepliesSheet(
        parentComment: parentComment,
        videoId: videoId,
        locals: locals,
      ),
    );
  }

  @override
  State<_CommentRepliesSheet> createState() => _CommentRepliesSheetState();
}

class _CommentRepliesSheetState extends State<_CommentRepliesSheet> {
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
    final state = context.read<WatchBloc>().state;
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !(state.fetchMoreCommentRepliesStatus == ApiStatus.loading) &&
        !state.isMoreReplyCommentsFetchCompleted) {
      context.read<WatchBloc>().add(WatchEvent.getMoreReplyCommentsData(
          id: widget.videoId, nextPage: state.commentReplies.nextpage));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surface,
            borderRadius: AppRadius.topXl,
          ),
          child: Column(
            children: [
              _DragHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Text(
                      widget.locals.repliesPlural(widget.parentComment.replyCount ?? 0),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    ScaleTap(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: AppSpacing.paddingXs,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceVariantDark
                              : AppColors.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.xmark,
                          size: AppIconSize.sm,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: BlocBuilder<WatchBloc, WatchState>(
                  buildWhen: (previous, current) =>
                      previous.fetchCommentRepliesStatus !=
                          current.fetchCommentRepliesStatus ||
                      previous.commentReplies != current.commentReplies,
                  builder: (context, state) {
                    if (state.fetchCommentRepliesStatus == ApiStatus.initial ||
                        state.fetchCommentRepliesStatus == ApiStatus.loading) {
                      return const ShimmerCommentWidget();
                    }

                    if (state.fetchCommentRepliesStatus == ApiStatus.error) {
                      return const Center(
                        child: Text('Error loading replies'),
                      );
                    }

                    // Only add extra item when loading more replies
                    final isLoadingMore = state.fetchMoreCommentRepliesStatus == ApiStatus.loading;
                    return ListView.builder(
                      controller: _scrollController,
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      scrollCacheExtent: const ScrollCacheExtent.pixels(500),
                      itemCount: state.commentReplies.comments.length + (isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < state.commentReplies.comments.length) {
                          final reply = state.commentReplies.comments[index];
                          return AnimatedListItem(
                            index: index,
                            child: _ReplyCard(
                              key: ValueKey('reply_${reply.commentId ?? index}'),
                              comment: reply,
                              locals: widget.locals,
                            ),
                          );
                        } else {
                          // Only show loading indicator when actually loading more
                          return Padding(
                            padding: AppSpacing.verticalLg,
                            child: cIndicator(context),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({
    super.key,
    required this.comment,
    required this.locals,
  });

  final Comment comment;
  final S locals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formattedLikes = formatCount((comment.likeCount ?? 0).toString());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: (comment.thumbnail?.isNotEmpty ?? false)
                ? NetworkImage(comment.thumbnail!)
                : null,
            backgroundColor:
                isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
          ),
          AppSpacing.width12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.author ?? locals.commentAuthorNotFound,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.onSurfaceVariantDark
                        : AppColors.onSurfaceVariant,
                  ),
                ),
                AppSpacing.height4,
                RichReadMoreText(
                  HTML.toTextSpan(
                    context,
                    // Decode HTML entities
                    (comment.commentText ?? '')
                        .replaceAll('&amp;', '&')
                        .replaceAll('&lt;', '<')
                        .replaceAll('&gt;', '>')
                        .replaceAll('&quot;', '"')
                        .replaceAll('&#39;', "'")
                        .replaceAll('&nbsp;', ' '),
                    defaultTextStyle: theme.textTheme.bodyMedium,
                  ),
                  settings: LineModeSettings(
                    trimLines: 3,
                    trimCollapsedText: ' ${locals.readMoreText}',
                    trimExpandedText: ' ${locals.showLessText}',
                    moreStyle: TextStyle(
                      fontSize: AppFontSize.body2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    lessStyle: TextStyle(
                      fontSize: AppFontSize.body2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                AppSpacing.height8,
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.hand_thumbsup,
                      size: AppIconSize.xs,
                      color: isDark
                          ? AppColors.onSurfaceVariantDark
                          : AppColors.onSurfaceVariant,
                    ),
                    AppSpacing.width4,
                    Text(
                      formattedLikes,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.onSurfaceVariantDark
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
