from pathlib import Path

path = Path('tool/d1c_apply.py')
source = path.read_text()
old_one = "暂无学情记录\\n主责：$responsibilitySummary"
new_one = "暂无学情记录 · 主责：$responsibilitySummary"
old_two = "问题'}\\n'\n        '主责：$responsibilitySummary'"
new_two = "问题'} · 主责：$responsibilitySummary'"
for old, new in ((old_one, new_one), (old_two, new_two)):
    count = source.count(old)
    if count != 1:
        raise SystemExit(f'expected one escaping target, got {count}: {old!r}')
    source = source.replace(old, new, 1)
path.write_text(source)
