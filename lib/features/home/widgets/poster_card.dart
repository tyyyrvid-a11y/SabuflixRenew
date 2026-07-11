
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/haptics.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/media_item.dart';

class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 128,
    this.showTitle = true,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final double width;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _PosterImage(url: item.posterUrl),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: _RatingBadge(rating: item.voteAverage),
                    ),
                  ],
                ),
              ),
            ),
            if (showTitle) ...[
              const SizedBox(height: 8),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: AppColors.surface,
        child: const Icon(Icons.movie_creation_outlined, color: AppColors.textTertiary),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Shimmer.fromColors(
          baseColor: AppColors.surface,
          highlightColor: AppColors.backgroundAlt,
          child: Container(color: AppColors.surface),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppColors.surface,
        child: const Icon(Icons.broken_image_outlined, color: AppColors.textTertiary),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: AppColors.accentTeal),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
