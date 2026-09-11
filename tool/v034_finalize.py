from pathlib import Path

workspace = Path('lib/features/design_v2/v2_workspace_preview.dart')
text = workspace.read_text()
text = text.replace('<PickedEvidenceAttachment>', '')
workspace.write_text(text)

adapter = Path('lib/features/design_v2/v2_read_model_adapter.dart')
text = adapter.read_text().replace('lastActivityAt!', 'lastActivityAt')
adapter.write_text(text)

visual_test = Path('test/features/v2_visual_polish_contract_test.dart')
text = visual_test.read_text()
old = '''    expect(source, contains("title: '待安排下一步'"));
    expect(source, contains('!widget.compact &&'));
    expect(source, contains('final expandedRail = width >= 1280;'));
    expect(
      source,
      contains('final studentPaneWidth = width < 900 ? 288.0 : 320.0;'),
    );
    expect(source, contains("student.updatedLabel != '暂无记录'"));
    expect(source, contains('!item.pendingVerification'));
    expect(source, contains("if (item.actionTiming == null) return '待验证';"));
'''
new = '''    expect(source, contains('item.actionTiming != null'));
    expect(source, contains("_SectionTitle(title: '现在要做'"));
    expect(source, contains("_SectionTitle(title: '待安排'"));
    expect(source, contains("title: const Text('之后')"));
    expect(source, contains("const _SectionTitle(title: '最近学生')"));
    expect(source, contains('· 继续关注'));
    expect(source, contains("label: const Text('处理')"));
    expect(source, isNot(contains("title: '待安排下一步'")));
    expect(source, isNot(contains("return '待验证';")));
    expect(source, contains('!widget.compact &&'));
    expect(source, contains('final expandedRail = width >= 1280;'));
    expect(
      source,
      contains('final studentPaneWidth = width < 900 ? 288.0 : 320.0;'),
    );
    expect(source, contains("student.updatedLabel != '暂无记录'"));
'''
if old not in text:
    raise SystemExit('stale visual contract block not found')
visual_test.write_text(text.replace(old, new, 1))

shell_test = Path('test/features/v2_shell_production_capabilities_test.dart')
text = shell_test.read_text()
old = '    expect(preview, contains("const Text(\'近期安排\')"));\n'
new = '    expect(preview, contains("title: const Text(\'之后\')"));\n'
if old not in text:
    raise SystemExit('stale shell future-section contract not found')
shell_test.write_text(text.replace(old, new, 1))
