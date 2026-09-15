import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  testWidgets('desktop rail selection changes only its quiet surface layer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final theme = V2Theme.light();
    await tester.pumpWidget(
      MaterialApp(theme: theme, home: const V2WorkspacePreview()),
    );
    await tester.pumpAndSettle();

    Finder studentRail() => find.byTooltip('我的学生');
    Finder railMaterial() =>
        find.descendant(of: studentRail(), matching: find.byType(Material));
    Finder railIcon() =>
        find.descendant(of: studentRail(), matching: find.byType(Icon));
    Finder railLabel() =>
        find.descendant(of: studentRail(), matching: find.text('学生'));

    expect(studentRail(), findsOneWidget);
    expect(railMaterial(), findsOneWidget);
    expect(railIcon(), findsOneWidget);
    expect(railLabel(), findsOneWidget);

    final beforeMaterial = tester.widget<Material>(railMaterial());
    final beforeIcon = tester.widget<Icon>(railIcon());
    final beforeLabel = tester.widget<Text>(railLabel());

    expect(beforeMaterial.color, Colors.transparent);
    expect(beforeIcon.color, theme.colorScheme.onSurfaceVariant);
    expect(beforeLabel.style?.color, theme.colorScheme.onSurfaceVariant);
    expect(beforeLabel.style?.fontWeight, FontWeight.w500);

    await tester.tap(studentRail());
    await tester.pumpAndSettle();

    final afterMaterial = tester.widget<Material>(railMaterial());
    final afterIcon = tester.widget<Icon>(railIcon());
    final afterLabel = tester.widget<Text>(railLabel());

    expect(afterMaterial.color, theme.colorScheme.surfaceContainerHigh);
    expect(afterIcon.color, beforeIcon.color);
    expect(afterLabel.style?.color, beforeLabel.style?.color);
    expect(afterLabel.style?.fontWeight, beforeLabel.style?.fontWeight);
    expect(tester.takeException(), isNull);
  });
}
