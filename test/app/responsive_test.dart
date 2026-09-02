import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/layout/responsive.dart';

void main() {
  test('classifies the three supported window sizes', () {
    expect(
      ResponsiveBreakpoints.classify(599),
      WindowSizeClass.compact,
    );
    expect(
      ResponsiveBreakpoints.classify(600),
      WindowSizeClass.medium,
    );
    expect(
      ResponsiveBreakpoints.classify(1023),
      WindowSizeClass.medium,
    );
    expect(
      ResponsiveBreakpoints.classify(1024),
      WindowSizeClass.expanded,
    );
  });
}
