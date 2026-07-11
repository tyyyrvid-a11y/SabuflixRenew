import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/media_item.dart';
import '../../../data/services/watch_history_store.dart';
import 'continue_watching_card.dart';

class ContinueWatchingRow extends StatelessWidget {
  const ContinueWatchingRow({super.key, required this.entries, required this.onItemTap});

  final List<ContinueWatchingEntry> entries;
  final ValueChanged<MediaItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Continuar assistindo',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
        SizedBox(
          height: 165,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final entry = entries[i];
              return ContinueWatchingCard(entry: entry, onTap: () => onItemTap(entry.item));
            },
          ),
        ),
      ],
    );
  }
}
