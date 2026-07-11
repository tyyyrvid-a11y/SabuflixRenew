import 'package:flutter/material.dart';

/// Wraps whatever physics the platform would normally use and only damps
/// the fling (momentum) velocity, so scrolling still tracks the finger
/// 1:1 but doesn't fly off as fast once released.
class _DampedScrollPhysics extends ScrollPhysics {
  const _DampedScrollPhysics({super.parent});

  static const double _velocityFactor = 0.72;

  @override
  _DampedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _DampedScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    return super.createBallisticSimulation(position, velocity * _velocityFactor);
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return _DampedScrollPhysics(parent: super.getScrollPhysics(context));
  }
}
