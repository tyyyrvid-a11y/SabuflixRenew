
import 'package:flutter/material.dart';
import '../../../core/haptics.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/watch_history_store.dart';

class ContinueWatchingCard extends StatelessWidget {
  const ContinueWatchingCard({super.key, required this.entry, required this.onTap});

  final ContinueWatchingEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = entry.item.backdropUrl.isNotEmpty ? entry.item.backdropUrl : entry.item.posterUrl;
    return GestureDetector(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    url.isEmpty
                        ? Container(color: AppColors.surface)
                        : Image.network(url, fit: BoxFit.cover),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: entry.progress,
                          minHeight: 4,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
