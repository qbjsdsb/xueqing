import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const mdPlus = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 40.0;

  /// Minimum size for a key interactive target on Android and touch layouts.
  static const touchTarget = 48.0;
}

abstract final class AppRadii {
  static const compact = 4.0;
  static const small = 6.0;
  static const medium = 8.0;
  static const dialog = 12.0;
}

abstract final class AppBorders {
  static const subtle = BorderSide(color: Color(0xFFD5DDD7));
  static const strong = BorderSide(color: Color(0xFFB7C2BB));
}
