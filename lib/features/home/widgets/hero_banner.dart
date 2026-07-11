
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/glass/glass_button.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/media_item.dart';

class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.item,
    required this.onPlay,
    required this.onInfo,
  });

  final MediaItem item;
  final VoidCallback onPlay;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 560,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Backdrop(url: item.backdropUrl),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppColors.heroScrim,
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MetaChips(item: item),
                  const SizedBox(height: 12),
                  // Original title, per product requirement.
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.8,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.overview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: GlassButton(
                          label: 'Assistir',
                          icon: Icons.play_arrow_rounded,
                          style: GlassButtonStyle.filled,
                          onTap: onPlay,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassButton(
                          label: 'Detalhes',
                          icon: Icons.info_outline_rounded,
                          onTap: onInfo,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(color: AppColors.surface);
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
      errorBuilder: (context, error, stackTrace) => Container(color: AppColors.surface),
    );
  }
}

class _MetaChips extends StatelessWidget {
  const _MetaChips({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (item.year.isNotEmpty) _chip(item.year),
        if (item.year.isNotEmpty) const SizedBox(width: 8),
        if (item.voteAverage > 0) _chip('★ ${item.voteAverage.toStringAsFixed(1)}'),
        const SizedBox(width: 8),
        _chip(item.mediaType == MediaType.movie ? 'FILME' : 'SÉRIE'),
      ],
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
