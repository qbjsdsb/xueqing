import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher save feedback states the resulting next-step state', () {
    final source = File('lib/features/design_v2/v2_composers.dart')
        .readAsStringSync();

    expect(source, contains('已记录问题 · 下一步可在问题详情中继续跟进。'));
    expect(source, contains('已保存进展 · 已安排再次检查。'));
    expect(source, contains('已保存进展 · 已结束跟进。'));
    expect(source, contains('已保存进展 · 继续观察，暂不设提醒。'));
    expect(source, contains('completedDraft = draft'));
  });
}
