import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher reminder handling uses the full progress closure flow', () {
    final workspace = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();
    final composer = File('lib/features/design_v2/v2_composers.dart')
        .readAsStringSync();

    expect(workspace, contains('completeCurrentActionInitially: true'));
    expect(workspace, contains("label: const Text('处理这一步')"));
    expect(workspace, isNot(contains('showV2CompleteActionComposer(')));
    expect(workspace, contains("'处理提醒'"));
    expect(workspace, contains("'处理复检提醒'"));

    expect(composer, contains('completeCurrentActionInitially'));
    expect(composer, contains("V2NextStep.remind => '安排再次检查'"));
    expect(composer, contains("'选择日期（可选）'"));
    expect(composer, contains('暂不确定日期也可以保存，之后会出现在“待安排”。'));
    expect(
      composer,
      isNot(
        contains('_nextStep == V2NextStep.remind && _reminderDate == null'),
      ),
    );
  });
}
