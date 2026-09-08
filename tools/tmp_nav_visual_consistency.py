from pathlib import Path

path = Path('lib/app/theme/app_theme.dart')
text = path.read_text()
indicator_old = 'indicatorColor: colorScheme.secondaryContainer,'
indicator_new = 'indicatorColor: colorScheme.primaryContainer,'
if text.count(indicator_old) != 2:
    raise SystemExit(f'expected two navigation indicator matches, got {text.count(indicator_old)}')
text = text.replace(indicator_old, indicator_new)

replacements = [
    ('? colorScheme.onSecondaryContainer\n                : colorScheme.onSurfaceVariant,', '? colorScheme.onPrimaryContainer\n                : colorScheme.onSurfaceVariant,'),
    ('color: colorScheme.onSecondaryContainer,\n        ),\n        unselectedIconTheme:', 'color: colorScheme.onPrimaryContainer,\n        ),\n        unselectedIconTheme:'),
    ('color: colorScheme.onSecondaryContainer,\n          fontFamilyFallback: fontFallback,\n        ),\n        unselectedLabelTextStyle:', 'color: colorScheme.onPrimaryContainer,\n          fontFamilyFallback: fontFallback,\n        ),\n        unselectedLabelTextStyle:'),
]
for old, new in replacements:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'expected one match, got {count}: {old[:50]}')
    text = text.replace(old, new, 1)
path.write_text(text)

test_path = Path('test/app/theme_test.dart')
test = test_path.read_text()
anchor = """    expect(light.bottomSheetTheme.shape, isNotNull);\n    expect(dark.bottomSheetTheme.shape, isNotNull);\n"""
addition = """    expect(light.bottomSheetTheme.shape, isNotNull);\n    expect(dark.bottomSheetTheme.shape, isNotNull);\n    expect(\n      light.navigationBarTheme.indicatorColor,\n      light.colorScheme.primaryContainer,\n    );\n    expect(\n      dark.navigationBarTheme.indicatorColor,\n      dark.colorScheme.primaryContainer,\n    );\n    expect(\n      light.navigationRailTheme.indicatorColor,\n      light.colorScheme.primaryContainer,\n    );\n    expect(\n      dark.navigationRailTheme.indicatorColor,\n      dark.colorScheme.primaryContainer,\n    );\n"""
if test.count(anchor) != 1:
    raise SystemExit('theme test anchor mismatch')
test_path.write_text(test.replace(anchor, addition, 1))
