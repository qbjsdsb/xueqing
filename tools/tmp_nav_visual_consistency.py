from pathlib import Path

path = Path('lib/app/theme/app_theme.dart')
text = path.read_text()
replacements = [
    ('indicatorColor: colorScheme.secondaryContainer,', 'indicatorColor: colorScheme.primaryContainer,'),
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
