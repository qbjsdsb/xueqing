from pathlib import Path

p = Path('.github/temp_navigation_simplification.py')
text = p.read_text(encoding='utf-8')

old_guard = """    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, got {count}')
    return text.replace(old, new, 1)
"""
new_guard = """    if count != 1:
        if label == 'organization lifecycle section sync' and count == 2:
            return text.replace(old, new, 1)
        raise SystemExit(f'{label}: expected 1 match, got {count}')
    return text.replace(old, new, 1)
"""
if old_guard not in text:
    raise SystemExit('temporary patcher guard not found')
text = text.replace(old_guard, new_guard, 1)

start_marker = '# Replace both full five-chip surfaces.\n'
end_marker = '# Reduce normal responsibility repetition in expanded selection rows.\n'
start = text.index(start_marker)
end = text.index(end_marker, start)

structural = '''# Replace both full five-chip surfaces by structural widget boundaries.
def _call_end(source: str, start: int) -> int:
    open_at = source.index('(', start)
    depth = 0
    for index in range(open_at, len(source)):
        char = source[index]
        if char == '(':
            depth += 1
        elif char == ')':
            depth -= 1
            if depth == 0:
                return index + 1
    raise SystemExit('unbalanced widget call while simplifying filters')

first_search = text.index("key: const Key('v2-organization-learning-search')")
expanded_start = text.index('                      Wrap(', first_search)
expanded_end = _call_end(text, expanded_start)
text = (
    text[:expanded_start]
    + '                      _filterControls(context)'
    + text[expanded_end:]
)

second_search = text.index(
    "key: const Key('v2-organization-learning-search')",
    first_search + 1,
)
compact_start = text.index('                    SingleChildScrollView(', second_search)
compact_end = _call_end(text, compact_start)
text = (
    text[:compact_start]
    + '                    _filterControls(context)'
    + text[compact_end:]
)
'''

text = text[:start] + structural + text[end:]
p.write_text(text, encoding='utf-8')
print('temporary patcher hardened')
