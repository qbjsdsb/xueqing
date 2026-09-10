from pathlib import Path

path = Path('lib/features/design_v2/v2_workspace_preview.dart')
text = path.read_text(encoding='utf-8')
start = text.index('class _StudentRow extends StatelessWidget {')
end = text.index('class _InitialMark extends StatelessWidget {', start)
segment = text[start:end]
old = '''      ),\n    );\n  }\n}\n\n'''
if segment.count(old) != 1:
    raise SystemExit(f'expected one StudentRow tail, found {segment.count(old)}')
segment = segment.replace(
    old,
    '''      ),\n      ),\n    );\n  }\n}\n\n''',
    1,
)
path.write_text(text[:start] + segment + text[end:], encoding='utf-8')
