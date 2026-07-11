import 'package:flutter/material.dart';
import '../haptics.dart';
import '../theme/app_theme.dart';
import 'glass_container.dart';

enum GlassButtonStyle { filled, glass }

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.style = GlassButtonStyle.glass,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final GlassButtonStyle style;

  void _handleTap() {
    Haptics.light();
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    if (style == GlassButtonStyle.filled) {
      return GestureDetector(
        onTap: _handleTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _handleTap,
      child: GlassContainer(
        borderRadius: 18,
        blurSigma: 20,
        tintOpacity: 0.14,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize = 20,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Haptics.light();
        onTap();
      },
      child: GlassContainer(
        width: size,
        height: size,
        borderRadius: size / 2,
        blurSigma: 20,
        tintOpacity: 0.12,
        child: Icon(icon, color: AppColors.textPrimary, size: iconSize),
      ),
    );
  }
}
