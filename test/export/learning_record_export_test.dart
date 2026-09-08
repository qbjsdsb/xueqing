import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/export/learning_record_export.dart';

void main() {
  group('LearningRecordExport', () {
    test('builds a readable student-subject workbook', () {
      final student = WorkspaceStudent(
        id: 'student-1',
        profileId: 'profile-1',
        profileVersion: 1,
        name: '测试学生',
        grade: '九年级',
        subject: '语文',
        context: '阅读理解',
        positioning: null,
        strengths: null,
        cadenceNote: null,
        cases: <WorkspaceCase>[
          WorkspaceCase(
            id: 'case-1',
            profileId: 'profile-1',
            title: '概括题容易漏点',
            type: LearningCaseType.knowledge,
            status: LearningCaseStatus.confirmed,
            priority: 'normal',
            description: null,
            firstObservedAt: DateTime(2026, 9, 8, 19, 30),
            version: 1,
            evidence: const <WorkspaceEvidence>[],
            interventions: const <WorkspaceIntervention>[],
            assessments: const <WorkspaceAssessment>[],
            actions: <WorkspaceAction>[
              WorkspaceAction(
                id: 'action-1',
                caseId: 'case-1',
                title: '下节课再检查一次',
                actionType: 'review',
                status: WorkspaceActionStatus.pending,
                isPrimary: true,
                bucket: WorkspaceActionBucket.future,
                version: 1,
              ),
            ],
            timeline: <WorkspaceTimelineEvent>[
              WorkspaceTimelineEvent(
                id: 'event-1',
                occurredAt: DateTime(2026, 9, 8, 19, 30),
                typeLabel: '发现问题',
                text: '能找到原文，但答案经常只写一个方面。',
              ),
              WorkspaceTimelineEvent(
                id: 'event-2',
                occurredAt: DateTime(2026, 9, 10, 18, 20),
                typeLabel: '教学处理',
                text: '重新练习圈关键词、分层和合并答案。',
              ),
            ],
          ),
        ],
        recentFacts: const <WorkspaceTimelineEvent>[],
      );

      final rows = LearningRecordExport.rowsForStudentSubject(student);
      expect(rows, hasLength(2));
      expect(rows.first.studentName, '测试学生');
      expect(rows.first.subjectName, '语文');
      expect(rows.first.nextStep, '下节课再检查一次');

      final bytes = LearningRecordExport.buildWorkbook(rows: rows);
      expect(bytes, isNotEmpty);

      final workbook = Excel.decodeBytes(bytes);
      final sheet = workbook.tables['全部记录'];
      expect(sheet, isNotNull);
      expect(sheet!.maxRows, 3);
      expect(sheet.maxColumns, LearningRecordExport.headers.length);
      expect(sheet.rows.first.first?.value.toString(), '发生时间');
      expect(sheet.rows[1][1]?.value.toString(), '测试学生');
      expect(sheet.rows[1][2]?.value.toString(), '语文');
      expect(sheet.rows[1][3]?.value.toString(), '概括题容易漏点');
      expect(sheet.rows[1][4]?.value.toString(), '发现问题');
    });

    test('sanitizes file names for Windows and Android', () {
      expect(
        LearningRecordExport.sanitizeFileName(' 张三/语文:学情*记录? '),
        '张三_语文_学情_记录_',
      );
      expect(LearningRecordExport.sanitizeFileName('   '), '学情记录');
    });
  });
}
