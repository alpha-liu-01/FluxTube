import 'package:flutter/material.dart';
import 'package:fluxtube/core/colors.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/core/window_layout.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerHomeVideoInfoCard extends StatelessWidget {
  const ShimmerHomeVideoInfoCard({
    super.key,
    this.subscribeRowVisible = true,
    this.aspectRatioThumbnail = false,
  });

  final bool subscribeRowVisible;

  /// 16:9 thumbnail with no outer horizontal padding, for a multi-column row.
  final bool aspectRatioThumbnail;

  @override
  Widget build(BuildContext context) {
    final thumbnail = Shimmer(
      gradient: shimmerGradient,
      child: Container(
        margin: aspectRatioThumbnail
            ? EdgeInsets.zero
            : const EdgeInsets.only(bottom: 10),
        width: double.infinity,
        height: aspectRatioThumbnail ? null : 230,
        decoration: BoxDecoration(
          color: kGreyColor,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(
        top: 5,
        left: aspectRatioThumbnail ? 0 : 20,
        right: aspectRatioThumbnail ? 0 : 20,
        bottom: 10,
      ),
      child: Column(
        children: [
          aspectRatioThumbnail
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AspectRatio(aspectRatio: 16 / 9, child: thumbnail),
                )
              : thumbnail,
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 12),
            child: Column(
              children: [
                // * caption row
                const ShimmerCaptionWidget(),

                kHeightBox5,

                // * views row
                const ShimmerViewWidget(),

                kHeightBox10,

                // * channel info row
                subscribeRowVisible
                    ? const ShimmerSubscribeWidget()
                    : const SizedBox(),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class ShimmerSubscribeWidget extends StatelessWidget {
  const ShimmerSubscribeWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: Shimmer(
            gradient: shimmerGradient,
            child: Container(
              color: Colors.white,
              width: 50,
              height: 50,
            ),
          ),
        ),
        kWidthBox10,
        Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 50, maxWidth: 150),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Shimmer(
                  gradient: shimmerGradient,
                  child: Container(
                    color: Colors.white,
                    width: 180,
                    height: 20,
                  ),
                ),
              ),
            ),
            kWidthBox5,
          ],
        ),
        const Spacer(),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Shimmer(
            gradient: shimmerGradient,
            child: Container(
              color: Colors.white,
              width: 80,
              height: 30,
            ),
          ),
        )
      ],
    );
  }
}

class ShimmerViewWidget extends StatelessWidget {
  const ShimmerViewWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Shimmer(
            gradient: shimmerGradient,
            child: Container(
              color: Colors.white,
              width: 60,
              height: 20,
            ),
          ),
        ),
        const SizedBox(
          width: 10,
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Shimmer(
            gradient: shimmerGradient,
            child: Container(
              color: Colors.white,
              width: 60,
              height: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class ShimmerCaptionWidget extends StatelessWidget {
  const ShimmerCaptionWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Shimmer(
              gradient: shimmerGradient,
              child: Container(
                color: Colors.white,
                width: 180,
                height: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ShimmerLikeWidget extends StatelessWidget {
  const ShimmerLikeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Shimmer(
              gradient: shimmerGradient,
              child: Container(
                color: Colors.white,
                width: 80,
                height: 30,
              ),
            ),
          ),
          kWidthBox20,
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Shimmer(
              gradient: shimmerGradient,
              child: Container(
                color: Colors.white,
                width: 80,
                height: 30,
              ),
            ),
          ),
          kWidthBox10,
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Shimmer(
              gradient: shimmerGradient,
              child: Container(
                color: Colors.white,
                width: 80,
                height: 30,
              ),
            ),
          ),
          kWidthBox10,
        ],
      ),
    );
  }
}

/// One row of compact shimmer cards. [columns] includes empty cells.
class ShimmerHomeVideoRow extends StatelessWidget {
  const ShimmerHomeVideoRow({super.key, required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var column = 0; column < columns; column++) ...[
            if (column > 0) const SizedBox(width: 12),
            const Expanded(
              child: ShimmerHomeVideoInfoCard(aspectRatioThumbnail: true),
            ),
          ],
        ],
      ),
    );
  }
}

/// Video-card placeholders that follow [WindowLayout.cardColumns].
class ShimmerHomeVideoGrid extends StatelessWidget {
  const ShimmerHomeVideoGrid({super.key, this.itemCount = 10});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth.isFinite
            ? WindowLayout.cardColumns(constraints.maxWidth)
            : 1;
        if (columns == 1) {
          return ListView.separated(
            separatorBuilder: (context, index) => kHeightBox10,
            itemCount: itemCount,
            itemBuilder: (context, index) => const ShimmerHomeVideoInfoCard(),
          );
        }
        final rowCount = (itemCount / columns).ceil();
        return ListView.builder(
          itemCount: rowCount,
          itemBuilder: (context, row) {
            final start = row * columns;
            final filled = (itemCount - start).clamp(0, columns);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) const SizedBox(width: 12),
                    Expanded(
                      child: column < filled
                          ? const ShimmerHomeVideoInfoCard(
                              aspectRatioThumbnail: true,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
