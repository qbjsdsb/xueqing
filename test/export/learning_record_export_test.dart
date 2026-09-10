import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/export/learning_record_export.dart';

void main() {
  group('LearningRecordExport', () {
    test('builds readable rows from teaching facts instead of raw events', () {
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
            status: LearningCaseStatus.pendingVerification,
            priority: 'normal',
            description: '概括题经常只答一个方面。',
            firstObservedAt: DateTime(2026, 9, 8, 19, 30),
            version: 1,
            evidence: <WorkspaceEvidence>[
              WorkspaceEvidence(
                id: 'evidence-1',
                sourceType: 'observation',
                title: '概括题容易漏点',
                observedAt: DateTime(2026, 9, 8, 19, 30),
                summary: '能找到原文，但答案经常只写一个方面。',
                status: 'finalized',
              ),
            ],
            interventions: <WorkspaceIntervention>[
              WorkspaceIntervention(
                id: 'intervention-1',
                strategy: '重新练习圈关键词、分层和合并答案。',
                notes: null,
                occurredAt: DateTime(2026, 9, 10, 18, 20),
              ),
            ],
            assessments: <WorkspaceAssessment>[
              WorkspaceAssessment(
                id: 'assessment-1',
                result: 'partial',
                evidenceSummary: '能答出两个方面，但概括仍不够准确。',
                notes: null,
                assessedAt: DateTime(2026, 9, 12, 20, 5),
              ),
            ],
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
                id: 'event-duplicate',
                occurredAt: DateTime(2026, 9, 12, 20, 5),
                typeLabel: 'Assessment / 验证',
                text: '记录了一次验证。',
              ),
            ],
          ),
        ],
        recentFacts: const <WorkspaceTimelineEvent>[],
      );

      final rows = LearningRecordExport.rowsForStudentSubject(student);
      expect(rows, hasLength(3));
      expect(rows.map((row) => row.recordType), <String>[
        '发现问题',
        '教学处理',
        '检查结果',
      ]);
      expect(rows.first.content, contains('具体表现：能找到原文'));
      expect(
        rows.where((row) => row.recordType.contains('Assessment')),
        isEmpty,
      );
      expect(rows.last.assessmentResult, '部分改善');
      expect(rows.last.nextStep, '下节课再检查一次');
      expect(rows.last.status, '继续关注');

      final bytes = LearningRecordExport.buildWorkbook(rows: rows);
      expect(bytes, isNotEmpty);

      final workbook = Excel.decodeBytes(bytes);
      final sheet = workbook.tables['全部记录'];
      expect(sheet, isNotNull);
      expect(sheet!.maxRows, 4);
      expect(sheet.maxColumns, LearningRecordExport.headers.length);
      expect(sheet.rows.first.first?.value.toString(), '发生时间');
      expect(sheet.rows[1][1]?.value.toString(), '测试学生');
      expect(sheet.rows[1][2]?.value.toString(), '语文');
      expect(sheet.rows[1][3]?.value.toString(), '概括题容易漏点');
      expect(sheet.rows[1][4]?.value.toString(), '发现问题');
      expect(sheet.rows[3][4]?.value.toString(), '检查结果');
      expect(sheet.rows[3][6]?.value.toString(), '部分改善');
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
