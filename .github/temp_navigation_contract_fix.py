from pathlib import Path

root = Path('.')

# The production change intentionally removes the repeated Compact Organization
# header action and moves desktop Organization sections into the rail. Keep the
# behavioral continuity assertions, but update stale UI selectors.
p = root / 'test/features/v2_typed_organization_navigation_test.dart'
t = p.read_text(encoding='utf-8')

# The old scope button must not exist anywhere in Compact Personal headers.
t = t.replace(
    "find.byKey(const Key('v2-open-organization-scope')),\n        findsOneWidget,",
    "find.byKey(const Key('v2-open-organization-scope')),\n        findsNothing,",
)
t = t.replace(
    "find.byKey(const Key('v2-open-organization-scope')),\n      findsOneWidget,",
    "find.byKey(const Key('v2-open-organization-scope')),\n      findsNothing,",
)

# Desktop Organization is now a grouped pair of rail destinations.
t = t.replace("find.byTooltip('机构'), findsOneWidget", "find.byTooltip('学情监督'), findsOneWidget")

# Compact Organization's local section is now explicitly named 学情监督.
t = t.replace("expect(find.text('学情'), findsOneWidget);", "expect(find.text('学情监督'), findsOneWidget);")

# Expanded Organization no longer carries its own segmented section switch;
# the parent rail controls the two sibling sub-destinations.
t = t.replace("await tester.tap(find.text('管理').last);", "await tester.tap(find.byTooltip('管理'));" )
t = t.replace("await tester.tap(find.text('学情').last);", "await tester.tap(find.byTooltip('学情监督'));" )

# Advanced attention filters now live behind the progressive 筛选 control.
old_resize = """      final filterFinder = find.byKey(
        const Key('v2-organization-filter-unassigned'),
      );
      await tester.tap(filterFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(filterFinder).selected, isTrue);

      await tester.binding.setSurfaceSize(const Size(800, 844));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(filterFinder).selected, isTrue);

      await tester.binding.setSurfaceSize(const Size(1100, 844));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(filterFinder).selected, isTrue);
"""
new_resize = """      await tester.tap(
        find.byKey(const Key('v2-organization-filter-more')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('v2-organization-filter-unassigned')),
      );
      await tester.pumpAndSettle();
      Finder selectedFilter() => find.descendant(
        of: find.byKey(const Key('v2-organization-filter-more')),
        matching: find.text('未明确主责'),
      );
      expect(selectedFilter(), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(800, 844));
      await tester.pumpAndSettle();
      expect(selectedFilter(), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(1100, 844));
      await tester.pumpAndSettle();
      expect(selectedFilter(), findsOneWidget);
"""
if old_resize not in t:
    raise SystemExit('typed navigation resize filter contract not found')
t = t.replace(old_resize, new_resize, 1)

old_management_filter = """      final filterFinder = find.byKey(
        const Key('v2-organization-filter-unassigned'),
      );
      await tester.tap(filterFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(filterFinder).selected, isTrue);

      await tester.tap(find.byTooltip('管理'));
      await tester.pumpAndSettle();
      expect(find.text('当前账号没有可用的机构管理权限。'), findsOneWidget);

      await tester.tap(find.byTooltip('学情监督'));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(filterFinder).selected, isTrue);
"""
new_management_filter = """      await tester.tap(
        find.byKey(const Key('v2-organization-filter-more')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('v2-organization-filter-unassigned')),
      );
      await tester.pumpAndSettle();
      Finder selectedFilter() => find.descendant(
        of: find.byKey(const Key('v2-organization-filter-more')),
        matching: find.text('未明确主责'),
      );
      expect(selectedFilter(), findsOneWidget);

      await tester.tap(find.byTooltip('管理'));
      await tester.pumpAndSettle();
      expect(find.text('当前账号没有可用的机构管理权限。'), findsOneWidget);

      await tester.tap(find.byTooltip('学情监督'));
      await tester.pumpAndSettle();
      expect(selectedFilter(), findsOneWidget);
"""
if old_management_filter not in t:
    raise SystemExit('typed navigation management filter contract not found')
t = t.replace(old_management_filter, new_management_filter, 1)

p.write_text(t, encoding='utf-8')

# Standalone Organization still owns a local section switch, but the section is
# now named 学情监督 and the repeated explanatory copy is intentionally gone.
p = root / 'test/features/v2_organization_workspace_test.dart'
t = p.read_text(encoding='utf-8')
t = t.replace("expect(find.text('学情'), findsOneWidget);", "expect(find.text('学情监督'), findsOneWidget);")
p.write_text(t, encoding='utf-8')

print('temporary navigation contracts aligned')
