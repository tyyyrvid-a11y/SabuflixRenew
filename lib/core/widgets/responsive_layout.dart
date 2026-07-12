import 'package:flutter/widgets.dart';

class ResponsiveLayout {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;

  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < mobileBreakpoint;
  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= mobileBreakpoint && MediaQuery.of(context).size.width < tabletBreakpoint;
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= tabletBreakpoint;

  static double getMediaRowHeight(BuildContext context) {
    if (isDesktop(context)) return 310;
    if (isTablet(context)) return 260;
    return 225; // mobile
  }

  static double getPosterWidth(BuildContext context) {
    if (isDesktop(context)) return 175;
    if (isTablet(context)) return 145;
    return 125; // mobile
  }
}
