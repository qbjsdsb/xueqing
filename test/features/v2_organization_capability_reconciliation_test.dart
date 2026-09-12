import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_data.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  testWidgets(
    'revoked Organization capability returns an open Organization view to Personal Today',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final hasOrganizationCapability = ValueNotifier<bool>(true);
      addTearDown(hasOrganizationCapability.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: ValueListenableBuilder<bool>(
            valueListenable: hasOrganizationCapability,
            builder: (context, enabled, _) => V2WorkspacePreview(
              data: v2FixtureWorkspaceData,
              organizationPageBuilder: enabled
                  ? (context, onBackToPersonal) => const Center(
                      child: Text('机构权限测试页'),
                    )
                  : null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      var navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navigation.destinations, hasLength(4));

      await tester.tap(find.text('机构'));
      await tester.pumpAndSettle();
      expect(find.text('机构权限测试页'), findsOneWidget);

      hasOrganizationCapability.value = false;
      await tester.pumpAndSettle();

      expect(find.text('机构权限测试页'), findsNothing);
      expect(find.text('机构'), findsNothing);
      navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navigation.destinations, hasLength(3));
      expect(navigation.selectedIndex, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
