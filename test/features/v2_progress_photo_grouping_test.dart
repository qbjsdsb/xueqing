import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/learning_repository.dart';

void main() {
  group('V2 progress photo companion matching', () {
    final occurredAt = DateTime.utc(2026, 9, 9, 10, 30);

    WorkspaceEvidence evidence({
      required String id,
      required String title,
      String sourceType = 'observation',
      String summary = '重新讲解概括结构。',
      DateTime? observedAt,
    }) => WorkspaceEvidence(
      id: id,
      sourceType: sourceType,
      title: title,
      observedAt: observedAt ?? occurredAt,
      summary: summary,
      status: 'finalized',
    );

    test('matches only exact V2 companion role, time and summary', () {
      final rows = <WorkspaceEvidence>[
        evidence(id: 'ordinary', title: '普通观察'),
        evidence(
          id: 'wrong-time',
          title: v2InterventionPhotoCompanionTitle,
          observedAt: occurredAt.add(const Duration(seconds: 1)),
        ),
        evidence(
          id: 'wrong-summary',
          title: v2InterventionPhotoCompanionTitle,
          summary: '另一条处理。',
        ),
        evidence(
          id: 'wrong-role',
          title: v2AssessmentPhotoCompanionTitle,
        ),
        evidence(
          id: 'companion',
          title: v2InterventionPhotoCompanionTitle,
        ),
      ];

      expect(
        v2ProgressPhotoCompanionEvidenceId(
          evidence: rows,
          expectedTitle: v2InterventionPhotoCompanionTitle,
          occurredAt: occurredAt,
          summary: '重新讲解概括结构。',
        ),
        'companion',
      );
    });

    test('can exclude the main observation evidence from matching itself', () {
      final rows = <WorkspaceEvidence>[
        evidence(
          id: 'main',
          title: v2ObservationPhotoCompanionTitle,
          summary: v2ObservationPhotoCompanionTitle,
        ),
        evidence(
          id: 'companion',
          title: v2ObservationPhotoCompanionTitle,
          summary: v2ObservationPhotoCompanionTitle,
        ),
      ];

      expect(
        v2ProgressPhotoCompanionEvidenceId(
          evidence: rows,
          expectedTitle: v2ObservationPhotoCompanionTitle,
          occurredAt: occurredAt,
          summary: v2ObservationPhotoCompanionTitle,
          excludingEvidenceId: 'main',
        ),
        'companion',
      );
    });

    test('does not swallow a teacher evidence row with a similar title', () {
      final rows = <WorkspaceEvidence>[
        evidence(
          id: 'manual',
          title: v2InterventionPhotoCompanionTitle,
          sourceType: 'homework',
        ),
      ];

      expect(
        v2ProgressPhotoCompanionEvidenceId(
          evidence: rows,
          expectedTitle: v2InterventionPhotoCompanionTitle,
          occurredAt: occurredAt,
          summary: '重新讲解概括结构。',
        ),
        isNull,
      );
    });
  });
}
