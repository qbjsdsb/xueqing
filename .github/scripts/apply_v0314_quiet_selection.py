from pathlib import Path

path = Path('lib/features/design_v2/v2_workspace_preview.dart')
text = path.read_text(encoding='utf-8')

replacements = [
    (
        '    final foreground = selected ? scheme.onSurface : scheme.onSurfaceVariant;\n',
        '    final foreground = scheme.onSurfaceVariant;\n',
    ),
    (
        '''                    SizedBox(\n                      width: 3,\n                      height: 22,\n                      child: DecoratedBox(\n                        decoration: BoxDecoration(\n                          color: selected ? scheme.primary : Colors.transparent,\n                          borderRadius: BorderRadius.circular(2),\n                        ),\n                      ),\n                    ),\n                    if (expanded) const SizedBox(width: 10) else const Spacer(),\n''',
        '''                    if (expanded)\n                      const SizedBox(width: 13)\n                    else\n                      const Spacer(),\n''',
    ),
    (
        '''                                fontWeight: selected\n                                    ? FontWeight.w600\n                                    : FontWeight.w500,\n''',
        '                                fontWeight: FontWeight.w500,\n',
    ),
]

for old, new in replacements:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'expected one match, found {count}: {old[:80]!r}')
    text = text.replace(old, new, 1)

path.write_text(text, encoding='utf-8')
