
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/glass/glass_button.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/media_item.dart';

import '../../../core/widgets/responsive_layout.dart';

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
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    
    return SizedBox(
      height: isDesktop ? 650 : (isTablet ? 500 : 560),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Backdrop(url: item.backdropUrl),
          // Vertical Gradient (Bottom fade)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDesktop ? [Colors.transparent, AppColors.background.withOpacity(0.4), AppColors.background] : AppColors.heroScrim,
                stops: isDesktop ? [0.6, 0.85, 1.0] : const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          // Horizontal Gradient (Left fade for Desktop)
          if (isDesktop || isTablet)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [AppColors.background.withOpacity(0.9), AppColors.background.withOpacity(0.7), Colors.transparent],
                  stops: const [0.0, 0.4, 0.7],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: isDesktop ? 60 : 28,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 20),
              child: SizedBox(
                width: isDesktop ? MediaQuery.of(context).size.width * 0.45 : double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MetaChips(item: item),
                    const SizedBox(height: 12),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isDesktop ? 52 : 36,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -1.2,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: isDesktop ? MediaQuery.of(context).size.width * 0.45 : double.infinity,
                      child: Text(
                        item.overview,
                        maxLines: isDesktop ? 4 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : 14.5,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisSize: isDesktop ? MainAxisSize.min : MainAxisSize.max,
                      children: [
                        if (!isDesktop) Expanded(child: _playBtn()) else SizedBox(width: 160, child: _playBtn()),
                        const SizedBox(width: 16),
                        if (!isDesktop) Expanded(child: _infoBtn()) else SizedBox(width: 160, child: _infoBtn()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playBtn() {
    return GlassButton(
      label: 'Assistir',
      icon: Icons.play_arrow_rounded,
      style: GlassButtonStyle.filled,
      onTap: onPlay,
    );
  }

  Widget _infoBtn() {
    return GlassButton(
      label: 'Detalhes',
      icon: Icons.info_outline_rounded,
      onTap: onInfo,
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
