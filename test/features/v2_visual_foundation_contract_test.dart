import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/theme/app_spacing.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';

void main() {
  test('V2 derives its production colors from the shared AppTheme', () {
    final appDark = AppTheme.dark();
    final v2Dark = V2Theme.dark();
    final appLight = AppTheme.light();
    final v2Light = V2Theme.light();

    expect(v2Dark.colorScheme.surface, appDark.colorScheme.surface);
    expect(
      v2Dark.colorScheme.surfaceContainerLowest,
      appDark.colorScheme.surfaceContainerLowest,
    );
    expect(v2Dark.colorScheme.primary, appDark.colorScheme.primary);
    expect(v2Light.colorScheme.surface, appLight.colorScheme.surface);
    expect(v2Light.colorScheme.primary, appLight.colorScheme.primary);
  });

  test('dark canvas stays continuous across the root and lowest surface', () {
    final scheme = AppTheme.dark().colorScheme;
    expect(scheme.surfaceContainerLowest, scheme.surface);
    expect(scheme.surface, const Color(0xFF121412));
  });

  test('V2 restores the shared 48dp interaction target', () {
    final theme = V2Theme.light();
    final buttonStyle = theme.filledButtonTheme.style!;
    final minimum = buttonStyle.minimumSize!.resolve(<WidgetState>{});
    expect(minimum?.height, AppSpacing.touchTarget);
  });

  test(
    'embedded management does not expose a duplicate refresh affordance',
    () {
      final source = File(
        'lib/features/organization_management/presentation/'
        'organization_management_layout.dart',
      ).readAsStringSync();

      expect(
        source,
        contains(
          "if (!showTitle) {\n      return const SizedBox.shrink();\n    }",
        ),
      );
      expect(
        source,
        contains('class _ManagementAreaCard extends StatelessWidget'),
      );
      expect(
        source,
        contains('Divider(height: 1, color: colorScheme.outlineVariant)'),
      );
    },
  );
}
