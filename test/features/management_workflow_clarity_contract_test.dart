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
    expect(rows, contains("'暂未明确主责老师'"));
    expect(rows, contains("'设置主责老师'"));
    expect(rows, contains('for (final assignment in assignments)'));
    expect(
      rows,
      contains("final aOrder = a.assignmentRole == 'lead' ? 0 : 1;"),
    );
    expect(
      rows,
      contains("'student-assignment-transfer-\${assignment.assignmentId}'"),
    );
  });

  test(
    'management routes one quiet export tool by active area and keeps concrete setup next steps',
    () {
      final areas = File(
        'lib/features/organization_management/presentation/organization_management_areas.dart',
      ).readAsStringSync();
      final layout = File(
        'lib/features/organization_management/presentation/organization_management_layout.dart',
      ).readAsStringSync();

      expect(areas, contains('_ManagementToolbar('));
      expect(areas, contains('_exportActionForSelectedArea()'));
      expect(
        areas,
        contains(
          'OrganizationManagementArea.people => widget.onExportTeacherRecords',
        ),
      );
      expect(
        areas,
        contains(
          'OrganizationManagementArea.students => widget.onExportStudentRecords',
        ),
      );
      expect(areas, contains('OrganizationManagementArea.settings => null'));
      expect(areas, contains('onExport: exportAction'));
      expect(layout, contains("key: const Key('management-export-records')"));
      expect(layout, contains("tooltip: '导出记录'"));
      expect(layout, contains("label: const Text('导出记录')"));
      expect(areas, isNot(contains("label: const Text('导出老师记录')")));
      expect(areas, isNot(contains("label: const Text('导出学生记录')")));
      expect(areas, contains("title = '先添加机构学科';"));
      expect(areas, contains("title = '下一步：配置老师可教学科';"));
      expect(areas, contains("title = '准备完成，可以添加第一位学生';"));
    },
  );
}
