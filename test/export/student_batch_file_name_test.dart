import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/export/learning_record_export.dart';

void main() {
  test('student batch export filename is concise and deterministic', () {
    expect(
      LearningRecordExport.studentBatchFileName(
        studentCount: 2,
        profileCount: 3,
        exportedAt: DateTime(2026, 9, 9),
      ),
      '学生学情记录_2人_3科_2026-09-09',
    );
  });
}
