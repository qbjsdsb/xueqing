from pathlib import Path

# Durable local draft attachment directory and stable per-user/org scope helper.
store_path = Path('lib/cloud/composer_draft_store.dart')
store = store_path.read_text(encoding='utf-8')
store = store.replace('final root = await getTemporaryDirectory();', 'final root = await getApplicationSupportDirectory();')
if 'quickCaptureComposerScopeKey' not in store:
    marker = '\nclass InMemoryComposerDraftStore implements ComposerDraftStore {'
    helper = r'''

String quickCaptureComposerScopeKey({
  required String sessionUserId,
  String? organizationId,
}) {
  final user = _validateScope(sessionUserId);
  final organization = organizationId?.trim();
  if (organization != null && organization.isNotEmpty) {
    return 'quick-capture:$user:$organization';
  }
  return 'quick-capture:$user';
}
'''
    if marker not in store:
        raise SystemExit('composer draft store insertion marker not found')
    store = store.replace(marker, helper + marker, 1)
store_path.write_text(store, encoding='utf-8')

composer_path = Path('lib/features/design_v2/v2_composers.dart')
text = composer_path.read_text(encoding='utf-8')
if "import '../../cloud/composer_draft_store.dart';" not in text:
    text = text.replace(
        "import '../../app/theme/app_motion.dart';\n",
        "import '../../app/theme/app_motion.dart';\nimport '../../cloud/composer_draft_store.dart';\n",
        1,
    )

save_marker = 'typedef V2QuickCaptureSave = Future<void> Function(V2QuickCaptureDraft draft);\ntypedef V2ProgressSave = Future<void> Function(V2ProgressDraft draft);\n'
if 'class V2QuickCapturePersistence' not in text:
    persistence = r'''

class V2QuickCapturePersistence {
  const V2QuickCapturePersistence({
    required this.store,
    required this.scopeKey,
    required this.studentId,
    required this.operationId,
    this.initialDraft,
    this.lostAttachmentLoader,
  });

  final ComposerDraftStore store;
  final String scopeKey;
  final String studentId;
  final String operationId;
  final ComposerDraftSnapshot? initialDraft;
  final EvidenceAttachmentLostDataLoader? lostAttachmentLoader;
}
'''
    if save_marker not in text:
        raise SystemExit('quick capture persistence insertion marker not found')
    text = text.replace(save_marker, save_marker + persistence, 1)

show_signature = r'''  V2QuickCaptureSave? onSave,
  V2AttachmentPicker attachmentPicker = pickEvidenceAttachment,
}) async {'''
show_replacement = r'''  V2QuickCaptureSave? onSave,
  V2AttachmentPicker attachmentPicker = pickEvidenceAttachment,
  V2QuickCapturePersistence? persistence,
}) async {'''
if show_signature not in text:
    raise SystemExit('showV2QuickCapture signature marker not found')
text = text.replace(show_signature, show_replacement, 1)

constructor_marker = r'''          onSave: onSave,
          attachmentPicker: attachmentPicker,
        ),'''
constructor_replacement = r'''          onSave: onSave,
          attachmentPicker: attachmentPicker,
          persistence: persistence,
        ),'''
if constructor_marker not in text:
    raise SystemExit('quick capture composer constructor call marker not found')
text = text.replace(constructor_marker, constructor_replacement, 1)

start = text.index('class V2QuickCaptureComposer extends StatefulWidget {')
end = text.index('\nclass V2ProgressComposer extends StatefulWidget {', start)
new_quick_capture = r'''class V2QuickCaptureComposer extends StatefulWidget {
  const V2QuickCaptureComposer({
    required this.studentName,
    required this.subjects,
    required this.problemTypes,
    required this.attachmentPicker,
    this.onSave,
    this.persistence,
    super.key,
  });

  final String studentName;
  final List<String> subjects;
  final List<V2ProblemTypeOption> problemTypes;
  final V2AttachmentPicker attachmentPicker;
  final V2QuickCaptureSave? onSave;
  final V2QuickCapturePersistence? persistence;

  @override
  State<V2QuickCaptureComposer> createState() => _V2QuickCaptureComposerState();
}

class _V2QuickCaptureComposerState extends State<V2QuickCaptureComposer> {
  final _controller = TextEditingController();
  final _attachments = <PickedEvidenceAttachment>[];
  String? _selectedSubject;
  bool _showMore = false;
  late String _problemTypeKey;
  String? _mediaError;
  String? _saveError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _problemTypeKey = widget.problemTypes.first.key;
    if (widget.subjects.length == 1) {
      _selectedSubject = widget.subjects.single;
    }
    final initialDraft = widget.persistence?.initialDraft;
    if (initialDraft != null) {
      _applyInitialDraft(initialDraft);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _restoreLostAttachment();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyInitialDraft(ComposerDraftSnapshot snapshot) {
    final persistence = widget.persistence;
    if (persistence == null ||
        snapshot.kind != 'quick_capture' ||
        snapshot.studentId != persistence.studentId ||
        snapshot.state['operation_id'] != persistence.operationId) {
      return;
    }
    final subject = snapshot.subject;
    if (subject != null && widget.subjects.contains(subject)) {
      _selectedSubject = subject;
    }
    final caseTypeKey = snapshot.state['case_type_key'];
    if (caseTypeKey is String &&
        widget.problemTypes.any((option) => option.key == caseTypeKey)) {
      _problemTypeKey = caseTypeKey;
    }
    final body = snapshot.state['body'];
    if (body is String) {
      _controller.text = body;
    }
    final showMore = snapshot.state['show_more'];
    if (showMore is bool) {
      _showMore = showMore;
    }
    _attachments
      ..clear()
      ..addAll(
        snapshot.attachments.take(3).map(
          (attachment) => PickedEvidenceAttachment(
            attachmentId: attachment.attachmentId,
            bytes: attachment.bytes,
            fileName: attachment.fileName,
            contentType: attachment.contentType,
          ),
        ),
      );
  }

  ComposerDraftSnapshot _draftSnapshot() {
    final persistence = widget.persistence!;
    return ComposerDraftSnapshot(
      kind: 'quick_capture',
      studentId: persistence.studentId,
      subject: _selectedSubject,
      state: <String, dynamic>{
        'operation_id': persistence.operationId,
        'case_type_key': _problemTypeKey,
        'body': _controller.text,
        'show_more': _showMore,
      },
      attachments: _attachments
          .map(
            (attachment) => ComposerDraftAttachment(
              attachmentId: attachment.attachmentId,
              bytes: attachment.bytes,
              fileName: attachment.fileName,
              contentType: attachment.contentType,
            ),
          )
          .toList(growable: false),
      savedAt: DateTime.now(),
    );
  }

  Future<void> _persistDraft() async {
    final persistence = widget.persistence;
    if (persistence == null) return;
    await persistence.store.save(persistence.scopeKey, _draftSnapshot());
  }

  Future<void> _persistDraftSilently() async {
    try {
      await _persistDraft();
    } catch (_) {
      // Best effort after an in-app state change. The external-picker boundary
      // below is strict and will not launch unless the draft was saved.
    }
  }

  Future<void> _clearPersistedDraft() async {
    final persistence = widget.persistence;
    if (persistence == null) return;
    try {
      await persistence.store.clear(persistence.scopeKey);
    } catch (_) {
      // A successful server write must not be reported as failed only because
      // local cleanup could not complete. Operation ids keep a stale retry safe.
    }
  }

  Future<void> _restoreLostAttachment() async {
    final persistence = widget.persistence;
    if (persistence?.initialDraft == null || _attachments.length >= 3) {
      return;
    }
    try {
      final loader =
          persistence?.lostAttachmentLoader ?? recoverLostEvidenceAttachment;
      final recovered = await loader();
      if (!mounted || recovered == null) return;
      if (_attachments.any(
        (attachment) => attachment.attachmentId == recovered.attachmentId,
      )) {
        return;
      }
      setState(() {
        _attachments.add(recovered);
        _mediaError = null;
      });
      await _persistDraftSilently();
    } catch (error) {
      if (!mounted) return;
      setState(() => _mediaError = describeEvidenceAttachmentError(error));
    }
  }

  Future<void> _pickAttachment() async {
    if (_saving || _attachments.length >= 3) {
      return;
    }
    if (widget.persistence != null) {
      try {
        await _persistDraft();
      } catch (_) {
        if (mounted) {
          setState(() {
            _mediaError = '暂时无法保护当前草稿，请稍后再拍照；已经输入的文字仍在当前窗口。';
          });
        }
        return;
      }
    }
    try {
      final picked = await widget.attachmentPicker(context);
      if (!mounted || picked == null) {
        return;
      }
      setState(() {
        _attachments.add(picked);
        _mediaError = null;
      });
      await _persistDraftSilently();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _mediaError = describeEvidenceAttachmentError(error));
    }
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
    _persistDraftSilently();
  }

  bool get _hasDraft =>
      _controller.text.trim().isNotEmpty || _attachments.isNotEmpty;

  bool get _canSave =>
      !_saving &&
      _selectedSubject != null &&
      _controller.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }
    final onSave = widget.onSave;
    if (onSave == null) {
      await _clearPersistedDraft();
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    final draft = V2QuickCaptureDraft(
      subject: _selectedSubject!,
      caseTypeKey: _problemTypeKey,
      body: _controller.text.trim(),
      attachments: List<PickedEvidenceAttachment>.unmodifiable(_attachments),
    );
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await _persistDraftSilently();
      await onSave(draft);
      await _clearPersistedDraft();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      await _persistDraftSilently();
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = _describeV2SaveError(error);
        });
      }
    }
  }

  Future<void> _close() async {
    if (_saving) {
      return;
    }
    if (!_hasDraft) {
      await _clearPersistedDraft();
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    final action = await _showV2DraftCloseDialog(
      context,
      saveFailed: _saveError != null,
    );
    if (!mounted ||
        action == null ||
        action == _V2DraftCloseAction.keepEditing) {
      return;
    }
    if (action == _V2DraftCloseAction.retry) {
      await _save();
      return;
    }
    await _clearPersistedDraft();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return _ComposerScaffold(
      title: '记录新问题',
      contextLine: _selectedSubject == null
          ? widget.studentName
          : '${widget.studentName} · $_selectedSubject',
      onClose: _saving ? null : _close,
      footer: _ComposerFooter(
        primaryLabel: '记录问题',
        onPrimary: _canSave ? _save : null,
        saving: _saving,
        previewMode: widget.onSave == null,
        errorText: _saveError,
      ),
      child: AbsorbPointer(
        absorbing: _saving,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.subjects.length > 1) ...[
              Text('选择学科', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              _InlineSelector<String>(
                key: const Key('v2-quick-capture-subject-selector'),
                value: _selectedSubject,
                values: widget.subjects,
                label: (value) => value,
                onChanged: (value) {
                  setState(() => _selectedSubject = value);
                  _persistDraftSilently();
                },
              ),
              const SizedBox(height: 22),
            ],
            Text('今天发现什么？', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              key: const Key('v2-quick-capture-body'),
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 7,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '写下刚才真实看到的题目、行为或表现…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            V2MediaDraftStrip(
              attachments: _attachments,
              onAdd: _pickAttachment,
              onRemove: _removeAttachment,
            ),
            if (_mediaError != null) ...[
              const SizedBox(height: 8),
              Text(
                _mediaError!,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('v2-quick-capture-more'),
              onPressed: () {
                setState(() => _showMore = !_showMore);
                _persistDraftSilently();
              },
              icon: Icon(_showMore ? Icons.expand_less : Icons.tune, size: 18),
              label: Text(_showMore ? '收起更多选项' : '更多选项'),
            ),
            AnimatedSize(
              duration: AppMotion.effectiveDuration(context),
              alignment: Alignment.topCenter,
              child: _showMore
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: DropdownButtonFormField<String>(
                        initialValue: _problemTypeKey,
                        decoration: const InputDecoration(labelText: '问题类型'),
                        items: widget.problemTypes
                            .map(
                              (option) => DropdownMenuItem(
                                value: option.key,
                                child: Text(option.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _problemTypeKey = value);
                            _persistDraftSilently();
                          }
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
'''
text = text[:start] + new_quick_capture + text[end:]
composer_path.write_text(text, encoding='utf-8')

test_path = Path('test/features/v2_quick_capture_recovery_test.dart')
test_path.write_text(r'''import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/composer_draft_store.dart';
import 'package:xueqing/features/design_v2/v2_composers.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/teacher_workspace/presentation/evidence_attachment_picker.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
    theme: V2Theme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  final pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  testWidgets('camera boundary persists current quick-capture text before picker', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = InMemoryComposerDraftStore();
    ComposerDraftSnapshot? snapshotDuringPicker;
    const scope = 'quick-capture:user-1:org-1';

    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showV2QuickCapture(
              context,
              studentName: '林同学',
              subjects: const ['语文'],
              persistence: V2QuickCapturePersistence(
                store: store,
                scopeKey: scope,
                studentId: 'student-1',
                operationId: 'operation-1',
              ),
              attachmentPicker: (_) async {
                snapshotDuringPicker = await store.load(scope);
                return null;
              },
              onSave: (_) async {},
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('v2-quick-capture-body')),
      '文言文翻译今天还是不稳定。',
    );
    await tester.tap(find.byKey(const Key('v2-media-add')));
    await tester.pumpAndSettle();

    expect(snapshotDuringPicker, isNotNull);
    expect(snapshotDuringPicker!.studentId, 'student-1');
    expect(snapshotDuringPicker!.subject, '语文');
    expect(snapshotDuringPicker!.state['operation_id'], 'operation-1');
    expect(snapshotDuringPicker!.state['body'], '文言文翻译今天还是不稳定。');
  });

  testWidgets('recovered draft merges Android lost photo and clears after save', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = InMemoryComposerDraftStore();
    const scope = 'quick-capture:user-1:org-1';
    final snapshot = ComposerDraftSnapshot(
      kind: 'quick_capture',
      studentId: 'student-1',
      subject: '语文',
      state: const <String, dynamic>{
        'operation_id': 'operation-2',
        'case_type_key': 'builtin:knowledge',
        'body': '相机打开前已经写好的内容。',
        'show_more': true,
      },
      attachments: const [],
      savedAt: DateTime(2026, 9, 10, 16),
    );
    await store.save(scope, snapshot);

    final recoveredPhoto = PickedEvidenceAttachment(
      attachmentId: '00000000-0000-4000-8000-000000000099',
      bytes: pngBytes,
      fileName: 'camera.png',
      contentType: 'image/png',
    );
    V2QuickCaptureDraft? savedDraft;

    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showV2QuickCapture(
              context,
              studentName: '林同学',
              subjects: const ['语文'],
              persistence: V2QuickCapturePersistence(
                store: store,
                scopeKey: scope,
                studentId: 'student-1',
                operationId: 'operation-2',
                initialDraft: snapshot,
                lostAttachmentLoader: () async => recoveredPhoto,
              ),
              attachmentPicker: (_) async => null,
              onSave: (draft) async => savedDraft = draft,
            ),
            child: const Text('恢复'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();

    expect(find.text('相机打开前已经写好的内容。'), findsOneWidget);
    expect(find.byKey(const ValueKey('v2-media-remove-0')), findsOneWidget);
    expect(find.text('知识漏洞'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '记录问题'));
    await tester.pumpAndSettle();

    expect(savedDraft, isNotNull);
    expect(savedDraft!.body, '相机打开前已经写好的内容。');
    expect(savedDraft!.attachments, hasLength(1));
    expect(savedDraft!.attachments.single.fileName, 'camera.png');
    expect(await store.load(scope), isNull);
  });

  test('quick capture draft scope separates users and organizations', () {
    expect(
      quickCaptureComposerScopeKey(
        sessionUserId: 'user-a',
        organizationId: 'org-a',
      ),
      'quick-capture:user-a:org-a',
    );
    expect(
      quickCaptureComposerScopeKey(
        sessionUserId: 'user-a',
        organizationId: 'org-b',
      ),
      isNot('quick-capture:user-a:org-a'),
    );
  });
}
''', encoding='utf-8')
