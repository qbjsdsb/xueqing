from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'expected one match in {path}, found {count}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


preview = 'lib/features/design_v2/v2_workspace_preview.dart'
controller = 'lib/features/design_v2/v2_workflow_controller.dart'
controller_test = 'test/features/design_v2_workflow_controller_test.dart'
contract_test = 'test/features/v032_case_media_void_contract_test.dart'

# 1) Real V2 evidence thumbnails open a zoomable preview while keeping the
# existing private signed-URL boundary. No public Storage URLs are introduced.
photo_anchor = "class _EvidencePhotoStrip extends StatefulWidget {\n"
photo_helper = r'''Future<void> _showV2EvidencePhotoPreview(
  BuildContext context,
  String signedUrl,
) {
  final compact = MediaQuery.sizeOf(context).width < 720;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.86),
    builder: (dialogContext) => Dialog(
      insetPadding: EdgeInsets.all(compact ? 12 : 40),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: compact ? double.maxFinite : 900,
        height: compact ? MediaQuery.sizeOf(dialogContext).height * 0.82 : 680,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(dialogContext).colorScheme.surface,
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5,
                    child: Image.network(
                      signedUrl,
                      key: const Key('v2-evidence-photo-preview-image'),
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        final expected = progress.expectedTotalBytes;
                        final value = expected == null || expected <= 0
                            ? null
                            : progress.cumulativeBytesLoaded / expected;
                        return Center(
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(value: value),
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.broken_image_outlined, size: 36),
                            const SizedBox(height: 12),
                            Text(
                              '图片暂时无法打开，请返回后重试。',
                              textAlign: TextAlign.center,
                              style: Theme.of(dialogContext).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
                shape: const CircleBorder(),
                child: IconButton(
                  key: const Key('v2-evidence-photo-preview-close'),
                  tooltip: '关闭图片',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

'''
replace_once(preview, photo_anchor, photo_helper + photo_anchor)

old_photo_loop = r'''          children: [
            for (final url in urls)
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: 96,
                  height: 72,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: scheme.surfaceContainer,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],'''
new_photo_loop = r'''          children: [
            for (var index = 0; index < urls.length; index++)
              Semantics(
                button: true,
                label: '查看图片 ${index + 1}',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  child: InkWell(
                    key: ValueKey<String>('v2-evidence-photo-$index'),
                    borderRadius: BorderRadius.circular(7),
                    onTap: () => _showV2EvidencePhotoPreview(context, urls[index]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: SizedBox(
                        width: 96,
                        height: 72,
                        child: Image.network(
                          urls[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: scheme.surfaceContainer,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],'''
replace_once(preview, old_photo_loop, new_photo_loop)

# 2) Safe teacher-facing delete/void action. It reuses the audited
# end_case_follow_up command with not_issue rather than physically deleting
# learning history.
reschedule_anchor = r'''  bool canReopenClosedCase(String caseId) {'''
void_method = r'''  Future<void> voidCase({
    required String operationId,
    required String caseId,
  }) async {
    final learningCase = _caseFor(caseId);
    if (learningCase.status == LearningCaseStatus.closed) {
      throw const V2WorkflowSaveException(
        '这个问题已经结束，请刷新后再处理。',
        recordMayBeSaved: false,
      );
    }
    try {
      await progressiveCaseRepository.endFollowUp(
        EndCaseFollowUpCommand(
          operationId: operationId,
          caseId: learningCase.id,
          expectedCaseVersion: learningCase.version,
          reason: CaseClosureReason.notIssue,
          note: '教师删除/作废误建或重复问题',
        ),
      );
    } catch (error) {
      final detail = error.toString().toLowerCase();
      if (detail.contains('version_conflict') ||
          detail.contains('case_already_closed')) {
        throw V2WorkflowSaveException(
          '这个问题刚刚有变化，请刷新后再删除。',
          recordMayBeSaved: false,
          cause: error,
        );
      }
      if (detail.contains('owner_permission_required') ||
          detail.contains('teaching_fact_gate') ||
          detail.contains('permission') ||
          detail.contains('forbidden')) {
        throw V2WorkflowSaveException(
          '你当前不能删除这个问题，请确认仍在负责这名学生后再试。',
          recordMayBeSaved: false,
          cause: error,
        );
      }
      if (detail.contains('network') ||
          detail.contains('socket') ||
          detail.contains('timeout') ||
          detail.contains('connection')) {
        throw V2WorkflowSaveException(
          '网络中断，删除结果暂时无法确认。当前操作编号已保留，可以直接重试。',
          recordMayBeSaved: true,
          cause: error,
        );
      }
      throw V2WorkflowSaveException(
        '这个问题暂时无法删除，请稍后重试。',
        recordMayBeSaved: false,
        cause: error,
      );
    }
  }

'''
replace_once(controller, reschedule_anchor, void_method + reschedule_anchor)

progress_anchor = r'''Future<void> _showV2ProgressForCase(
  BuildContext context,
  V2Student student,
  V2FocusItem item,
) async {'''
void_ui = r'''Future<bool> _showV2VoidCase(
  BuildContext context,
  V2Student student,
  V2FocusItem item,
) async {
  final runtime = _V2RuntimeScope.maybeOf(context);
  final controller = runtime?.workflowController;
  if (controller == null || item.closed) return false;
  final operationId = createOperationId();

  final removed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      var saving = false;
      String? errorText;
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('删除这个问题？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${student.name} · ${item.subject}\n${item.title}'),
              const SizedBox(height: 12),
              const Text(
                '适合误建或重复的问题。删除后不会再作为进行中问题显示；已有成长记录会保留，方便以后追溯。',
              ),
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('v2-confirm-void-case'),
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() {
                        saving = true;
                        errorText = null;
                      });
                      try {
                        await controller.voidCase(
                          operationId: operationId,
                          caseId: item.id,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } on V2WorkflowSaveException catch (error) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            saving = false;
                            errorText = error.userMessage;
                          });
                        }
                      } catch (_) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            saving = false;
                            errorText = '这个问题暂时无法删除，请稍后重试。';
                          });
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('删除问题'),
            ),
          ],
        ),
      );
    },
  );

  if (removed == true && context.mounted) {
    runtime?.onWorkspaceChanged?.call();
    return true;
  }
  return false;
}

'''
replace_once(preview, progress_anchor, void_ui + progress_anchor)

pending_action_anchor = r'''                  if (pendingAction != null) ...[
                    const SizedBox(height: 12),'''
# Do not insert destructive action inside the pending-action block. Put it after
# that block, immediately before the section divider.
section_anchor = r'''                  const SizedBox(height: 30),
                  Divider(color: scheme.outlineVariant),'''
section_replacement = r'''                  if (!item.closed && controller != null) ...[
                    const SizedBox(height: 14),
                    TextButton.icon(
                      key: ValueKey<String>('v2-void-${item.id}'),
                      onPressed: () async {
                        final removed = await _showV2VoidCase(
                          context,
                          student,
                          item,
                        );
                        if (removed && context.mounted) onBack();
                      },
                      style: TextButton.styleFrom(foregroundColor: scheme.error),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('删除问题'),
                    ),
                  ],
                  const SizedBox(height: 30),
                  Divider(color: scheme.outlineVariant),'''
replace_once(preview, section_anchor, section_replacement)

# 3) Controller regression: exact current case version + not_issue reason,
# allowing the existing server command to enforce owner/teaching/org boundaries.
test_anchor = r'''    test('same-name students never replace stable student identity', () async {'''
void_test = r'''    test('teacher case delete is an audited not-issue closure', () async {
      final progress = _FakeProgressiveCaseRepository();
      final controller = V2WorkflowController(
        workspace: _workspace(),
        learningRepository: _FakeLearningRepository(),
        progressiveCaseRepository: progress,
      );

      await controller.voidCase(
        operationId: 'operation-void-case',
        caseId: 'case-existing',
      );

      expect(progress.endCalls, hasLength(1));
      final command = progress.endCalls.single;
      expect(command.operationId, 'operation-void-case');
      expect(command.caseId, 'case-existing');
      expect(command.expectedCaseVersion, 3);
      expect(command.reason, CaseClosureReason.notIssue);
      expect(command.note, contains('删除/作废'));
    });

'''
replace_once(controller_test, test_anchor, void_test + test_anchor)

fake_anchor = r'''  final calls = <RecordCaseProgressCommand>[];
  ProgressiveCaseReceipt receipt = const ProgressiveCaseReceipt('''
fake_replacement = r'''  final calls = <RecordCaseProgressCommand>[];
  final endCalls = <EndCaseFollowUpCommand>[];
  ProgressiveCaseReceipt receipt = const ProgressiveCaseReceipt('''
replace_once(controller_test, fake_anchor, fake_replacement)

fake_end_anchor = r'''  @override
  Future<ProgressiveCaseReceipt> recordProgress(
    RecordCaseProgressCommand command,
  ) async {
    calls.add(command);
    log?.add('progress');
    return receipt;
  }
}'''
fake_end_replacement = r'''  @override
  Future<ProgressiveCaseReceipt> recordProgress(
    RecordCaseProgressCommand command,
  ) async {
    calls.add(command);
    log?.add('progress');
    return receipt;
  }

  @override
  Future<ProgressiveCaseReceipt> endFollowUp(
    EndCaseFollowUpCommand command,
  ) async {
    endCalls.add(command);
    log?.add('end-follow-up');
    return ProgressiveCaseReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      status: 'closed',
      caseVersion: command.expectedCaseVersion + 1,
      eventId: 'event-void',
    );
  }
}'''
replace_once(controller_test, fake_end_anchor, fake_end_replacement)

# 4) A compact source-level UI contract guards the click target, zoom preview,
# signed URL boundary, and absence of any physical learning-case delete call.
Path(contract_test).write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V2 evidence thumbnails open a zoomable signed-url preview', () {
    final source = File(
      'lib/features/design_v2/v2_workspace_preview.dart',
    ).readAsStringSync();

    expect(source, contains("key: ValueKey<String>('v2-evidence-photo-$index')"));
    expect(source, contains('onTap: () => _showV2EvidencePhotoPreview'));
    expect(source, contains('InteractiveViewer('));
    expect(source, contains("key: const Key('v2-evidence-photo-preview-image')"));
    expect(source, contains('createSignedUrl(attachment.storagePath)'));
    expect(source, isNot(contains('getPublicUrl(')));
  });

  test('teacher delete remains an audited closure rather than physical delete', () {
    final controller = File(
      'lib/features/design_v2/v2_workflow_controller.dart',
    ).readAsStringSync();
    final preview = File(
      'lib/features/design_v2/v2_workspace_preview.dart',
    ).readAsStringSync();

    expect(controller, contains('progressiveCaseRepository.endFollowUp('));
    expect(controller, contains('reason: CaseClosureReason.notIssue'));
    expect(controller, isNot(contains('deleteLearningCase')));
    expect(preview, contains("label: const Text('删除问题')"));
    expect(preview, contains("key: const Key('v2-confirm-void-case')"));
  });
}
''', encoding='utf-8')

print('v0.3.2 Gate B patch applied')
