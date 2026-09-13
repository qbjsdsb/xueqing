from pathlib import Path

root = Path('.')

# 1) Capability revocation: enter Organization through the real Compact More menu.
p = root / 'test/features/v2_organization_capability_reconciliation_test.dart'
t = p.read_text(encoding='utf-8')
old = """      expect(
        find.byKey(const Key('v2-open-organization-scope')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('v2-open-organization-scope')));
      await tester.pumpAndSettle();
"""
new = """      expect(
        find.byKey(const Key('v2-open-organization-scope')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('v2-compact-more')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('v2-menu-open-organization')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('v2-menu-open-organization')));
      await tester.pumpAndSettle();
"""
if t.count(old) != 1:
    raise SystemExit(f'capability entry contract count={t.count(old)}')
t = t.replace(old, new, 1)
old_tail = """      expect(find.byKey(const Key('v2-open-organization-scope')), findsNothing);
      navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navigation.destinations, hasLength(3));
      expect(navigation.selectedIndex, 0);
      expect(tester.takeException(), isNull);
"""
new_tail = """      expect(find.byKey(const Key('v2-open-organization-scope')), findsNothing);
      navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navigation.destinations, hasLength(3));
      expect(navigation.selectedIndex, 0);

      await tester.tap(find.byKey(const Key('v2-compact-more')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('v2-menu-open-organization')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
"""
if t.count(old_tail) != 1:
    raise SystemExit(f'capability tail contract count={t.count(old_tail)}')
t = t.replace(old_tail, new_tail, 1)
p.write_text(t, encoding='utf-8')

# 2) Production shell source contract: assert the new hierarchy, not removed keys.
p = root / 'test/features/v2_shell_production_capabilities_test.dart'
t = p.read_text(encoding='utf-8')
old = """    expect(preview, contains("Key('v2-compact-more')"));
    expect(preview, contains("Key('v2-open-organization-scope')"));
    expect(preview, contains("Key('v2-rail-organization')"));
"""
new = """    expect(preview, contains("Key('v2-compact-more')"));
    expect(preview, contains("Key('v2-menu-open-organization')"));
    expect(preview, isNot(contains("Key('v2-open-organization-scope')")));
    expect(preview, contains("Key('v2-rail-organization-learning')"));
    expect(preview, contains("Key('v2-rail-organization-management')"));
"""
if t.count(old) != 1:
    raise SystemExit(f'shell source contract count={t.count(old)}')
t = t.replace(old, new, 1)
p.write_text(t, encoding='utf-8')

# 3) Typed navigation: remove duplicate assertion and prove 320px More exposes Organization.
p = root / 'test/features/v2_typed_organization_navigation_test.dart'
t = p.read_text(encoding='utf-8')
duplicate = """      expect(find.byKey(const Key('v2-open-organization-scope')), findsNothing);
      expect(find.byKey(const Key('v2-open-organization-scope')), findsNothing);
"""
if t.count(duplicate) != 1:
    raise SystemExit(f'duplicate compact assertion count={t.count(duplicate)}')
t = t.replace(
    duplicate,
    "      expect(find.byKey(const Key('v2-open-organization-scope')), findsNothing);\n",
    1,
)
old_320 = """    expect(find.byKey(const Key('v2-open-organization-scope')), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop manager-teacher gets Organization in the primary rail', (
"""
new_320 = """    expect(find.byKey(const Key('v2-open-organization-scope')), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byKey(const Key('v2-compact-more')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('v2-menu-open-organization')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop manager-teacher gets Organization in the primary rail', (
"""
if t.count(old_320) != 1:
    raise SystemExit(f'320px contract count={t.count(old_320)}')
t = t.replace(old_320, new_320, 1)
p.write_text(t, encoding='utf-8')

print('navigation test contracts updated')
