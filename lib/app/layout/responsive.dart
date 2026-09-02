import 'package:flutter/widgets.dart';

enum WindowSizeClass {
  compact,
  medium,
  expanded,
}

abstract final class ResponsiveBreakpoints {
  static const mediumMinWidth = 600.0;
  static const expandedMinWidth = 1024.0;

  static WindowSizeClass classify(double width) {
    if (width < mediumMinWidth) {
      return WindowSizeClass.compact;
    }
    if (width < expandedMinWidth) {
      return WindowSizeClass.medium;
    }
    return WindowSizeClass.expanded;
  }
}

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.builder,
    super.key,
  });

  final Widget Function(BuildContext context, WindowSizeClass sizeClass)
      builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = ResponsiveBreakpoints.classify(constraints.maxWidth);
        return builder(context, sizeClass);
      },
    );
  }
}
