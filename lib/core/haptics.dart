import 'package:flutter/services.dart';

/// Central place for haptic feedback so touch targets feel tactile
/// without every screen having to remember to trigger it.
class Haptics {
  Haptics._();

  static void tap() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
}
