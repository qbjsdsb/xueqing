from pathlib import Path

composers = Path('lib/features/design_v2/v2_composers.dart')
text = composers.read_text(encoding='utf-8')

old_quick = """        content: Text(onSave == null ? 'V2 预览：记录已完成，但没有写入正式学情。' : '已记录问题。'),\n"""
new_quick = """        content: Text(\n          onSave == null\n              ? 'V2 预览：记录已完成，但没有写入正式学情。'\n              : '已记录问题 · 下一步可在问题详情中继续跟进。',\n        ),\n"""
if old_quick not in text:
    raise SystemExit('quick-capture success anchor not found')
text = text.replace(old_quick, new_quick, 1)

progress_start = text.find('Future<bool> showV2ProgressComposer(')
if progress_start < 0:
    raise SystemExit('progress function not found')
old_progress_head = """}) async {\n  final saved =\n      await _showAdaptiveComposer<bool>(\n        context,\n        child: V2ProgressComposer(\n"""
new_progress_head = """}) async {\n  V2ProgressDraft? completedDraft;\n  final effectiveOnSave = onSave == null\n      ? null\n      : (V2ProgressDraft draft) async {\n          await onSave(draft);\n          completedDraft = draft;\n        };\n  final saved =\n      await _showAdaptiveComposer<bool>(\n        context,\n        child: V2ProgressComposer(\n"""
head_pos = text.find(old_progress_head, progress_start)
if head_pos < 0:
    raise SystemExit('progress function head anchor not found')
text = text[:head_pos] + text[head_pos:].replace(old_progress_head, new_progress_head, 1)

progress_start = text.find('Future<bool> showV2ProgressComposer(')
on_save_pos = text.find('          onSave: onSave,', progress_start)
if on_save_pos < 0:
    raise SystemExit('progress onSave anchor not found')
text = text[:on_save_pos] + text[on_save_pos:].replace('          onSave: onSave,', '          onSave: effectiveOnSave,', 1)

old_progress_success = """        content: Text(onSave == null ? 'V2 预览：进展已完成，但没有写入正式学情。' : '已保存进展。'),\n"""
new_progress_success = """        content: Text(\n          onSave == null\n              ? 'V2 预览：进展已完成，但没有写入正式学情。'\n              : _v2ProgressSuccessMessage(completedDraft),\n        ),\n"""
if old_progress_success not in text:
    raise SystemExit('progress success anchor not found')
text = text.replace(old_progress_success, new_progress_success, 1)

helper_anchor = "\nString _describeV2SaveError(Object error) {\n"
helper = """
String _v2ProgressSuccessMessage(V2ProgressDraft? draft) {
  return switch (draft?.nextStep) {
    V2NextStep.remind => '已保存进展 · 已安排再次检查。',
    V2NextStep.close => '已保存进展 · 已结束跟进。',
    V2NextStep.continueTracking => '已保存进展 · 继续观察，暂不设提醒。',
    null => '已保存进展。',
  };
}
"""
if helper_anchor not in text:
    raise SystemExit('save error helper anchor not found')
text = text.replace(helper_anchor, '\n' + helper + helper_anchor, 1)
composers.write_text(text, encoding='utf-8')

contract = Path('test/features/v2_closed_loop_feedback_contract_test.dart')
contract.write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher save feedback states the resulting next-step state', () {
    final source = File('lib/features/design_v2/v2_composers.dart').readAsStringSync();

    expect(source, contains('已记录问题 · 下一步可在问题详情中继续跟进。'));
    expect(source, contains('已保存进展 · 已安排再次检查。'));
    expect(source, contains('已保存进展 · 已结束跟进。'));
    expect(source, contains('已保存进展 · 继续观察，暂不设提醒。'));
    expect(source, contains('completedDraft = draft'));
  });
}
""", encoding='utf-8')
