import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Minimalist wordmark: a small glass mark + solid-color type, no rainbow
/// gradient — keeps it closer to the restrained iOS 26 look.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.fontSize = 21});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final markSize = fontSize + 8;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: markSize,
          height: markSize,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(markSize / 3),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.play_arrow_rounded, size: markSize * 0.62, color: AppColors.textPrimary),
        ),
        const SizedBox(width: 9),
        Text(
          'SabuFlix',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}
