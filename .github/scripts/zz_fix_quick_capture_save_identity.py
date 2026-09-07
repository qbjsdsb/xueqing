from pathlib import Path

source_path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
source = source_path.read_text()
old_button = """                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? '保存中…' : '记录问题'),
                        ),
                      ),
"""
new_button = """                      Expanded(
                        child: FilledButton(
                          key: const Key('workspace-quick-capture-save'),
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? '保存中…' : '记录问题'),
                        ),
                      ),
"""
if source.count(old_button) != 1:
    raise SystemExit(
        f'Quick Capture save button anchor drifted: {source.count(old_button)}'
    )
source_path.write_text(source.replace(old_button, new_button, 1))

test_path = Path('test/features/teacher_workspace_test.dart')
tests = test_path.read_text()
old_finder = "find.widgetWithText(FilledButton, '记录问题')"
new_finder = "find.byKey(const Key('workspace-quick-capture-save'))"
if tests.count(old_finder) != 2:
    raise SystemExit(
        f'Quick Capture save finder anchor drifted: {tests.count(old_finder)}'
    )
test_path.write_text(tests.replace(old_finder, new_finder))
