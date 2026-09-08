from pathlib import Path

script_path = Path('.github/scripts/patch_action_completion.py')
source = script_path.read_text()

old_pattern = r'''r"class _WorkspaceCompleteActionFormState\n    extends State<_WorkspaceCompleteActionForm> \{.*?\n\}\n\nenum _CaseCommandMode"'''
new_pattern = r'''r"class _WorkspaceCompleteActionFormState\n    extends State<_WorkspaceCompleteActionForm> \{.*?(?=\n(?:class|enum|String|CaseActionType) )"'''
if source.count(old_pattern) != 1:
    raise SystemExit(
        f'completion form regex source marker count={source.count(old_pattern)}'
    )
source = source.replace(old_pattern, new_pattern, 1)

old_replacement_tail = '''\nenum _CaseCommandMode""",\n    "completion form state",'''
new_replacement_tail = '''""",\n    "completion form state",'''
if source.count(old_replacement_tail) != 1:
    raise SystemExit(
        'completion form replacement tail marker was not found exactly once'
    )
source = source.replace(old_replacement_tail, new_replacement_tail, 1)

exec(compile(source, str(script_path), 'exec'))
