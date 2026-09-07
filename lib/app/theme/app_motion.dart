import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const Duration quick = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 180);

  static Duration effectiveDuration(
    BuildContext context, [
    Duration duration = standard,
  ]) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return mediaQuery?.disableAnimations == true ? Duration.zero : duration;
  }
}
