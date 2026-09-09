from pathlib import Path
import runpy

script_path = Path('tool/apply_teacher_student_grouping_plain_recovery_v021.py')
source = script_path.read_text()

old = "test = replace_once(test, reopen_open_anchor, reopen_open_new, 'plain reopen copy test')"
new = """match_count = test.count(reopen_open_anchor)
if match_count != 2:
    raise SystemExit(
        f'plain reopen copy test: expected two reusable form-open anchors, found {match_count}'
    )
test = test.replace(reopen_open_anchor, reopen_open_new, 1)"""
if source.count(old) != 1:
    raise SystemExit('plain reopen patch runner: target statement changed')
source = source.replace(old, new, 1)

old_escape = "count: '\\${studentGroups.length} 人'"
new_escape = "count: '\\\\${studentGroups.length} 人'"
if source.count(old_escape) != 1:
    raise SystemExit('plain reopen patch runner: contract escape target changed')
source = source.replace(old_escape, new_escape, 1)

script_path.write_text(source)
runpy.run_path(str(script_path), run_name='__main__')
