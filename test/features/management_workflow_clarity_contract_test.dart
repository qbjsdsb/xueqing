import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('management keeps current teacher inside student context', () {
    final areas = File(
      'lib/features/organization_management/presentation/organization_management_areas.dart',
    ).readAsStringSync();
    final rows = File(
      'lib/features/organization_management/presentation/organization_management_rows.dart',
    ).readAsStringSync();

    expect(areas, isNot(contains("'任课老师与交接'")));
    expect(areas, contains("'历史任课记录'"));
    expect(rows, contains("'暂未安排负责老师'"));
    expect(rows, contains('for (final assignment in assignments)'));
    expect(
      rows,
      contains("'student-assignment-transfer-\${assignment.assignmentId}'"),
    );
  });

  test('management exposes one export entry and concrete setup next steps', () {
    final areas = File(
      'lib/features/organization_management/presentation/organization_management_areas.dart',
    ).readAsStringSync();

    expect(areas, contains("label: const Text('导出记录')"));
    expect(areas, contains("title: const Text('导出记录')"));
    expect(areas, isNot(contains("label: const Text('导出老师记录')")));
    expect(areas, isNot(contains("label: const Text('导出学生记录')")));
    expect(areas, contains("title = '先添加机构学科';"));
    expect(areas, contains("title = '下一步：配置老师可教学科';"));
    expect(areas, contains("title = '准备完成，可以添加第一位学生';"));
  });
}
