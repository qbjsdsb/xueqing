import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadii {
  static const small = 6.0;
  static const medium = 10.0;
  static const dialog = 12.0;
}

abstract final class AppBorders {
  static const subtle = BorderSide(color: Color(0xFFD5DDD7));
}
