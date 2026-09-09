from pathlib import Path

path = Path('.github/scripts/finish_v2_injectable_data_once.py')
text = path.read_text()
old = '''preview = replace_once(
    preview,
    '    final student = v2StudentForFocusItem(item);',
    "    final student = V2WorkspaceDataScope.of(context).studentForFocusItemOrNull(item);\\n    if (student == null) {\\n      return const SizedBox.shrink();\\n    }",
    'today student lookup',
)'''
new = '''preview = replace_exact_count(
    preview,
    '    final student = v2StudentForFocusItem(item);',
    "    final student = V2WorkspaceDataScope.of(context).studentForFocusItemOrNull(item);\\n    if (student == null) {\\n      return const SizedBox.shrink();\\n    }",
    2,
    'today student lookup',
)'''
if text.count(old) != 1:
    raise SystemExit(f'helper patch: expected 1 match, found {text.count(old)}')
path.write_text(text.replace(old, new, 1))
