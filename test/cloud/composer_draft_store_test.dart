import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/composer_draft_store.dart';

class _FakeMetadataStore implements ComposerDraftMetadataStore {
  final Map<String, String> values = <String, String>{};
  bool failNextWrite = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('simulated metadata commit failure');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

ComposerDraftSnapshot _snapshot({
  required String body,
  required String attachmentId,
  required List<int> bytes,
}) => ComposerDraftSnapshot(
  kind: 'quick_capture',
  studentId: 'student-1',
  subject: '语文',
  state: <String, dynamic>{'operation_id': 'operation-1', 'body': body},
  attachments: <ComposerDraftAttachment>[
    ComposerDraftAttachment(
      attachmentId: attachmentId,
      bytes: Uint8List.fromList(bytes),
      fileName: '$attachmentId.png',
      contentType: 'image/png',
    ),
  ],
  savedAt: DateTime(2026, 9, 16, 14),
);

Future<List<File>> _draftFiles(Directory root) async {
  final draftRoot = Directory(
    '${root.path}${Platform.pathSeparator}xueqing_composer_drafts',
  );
  if (!await draftRoot.exists()) {
    return const <File>[];
  }
  return draftRoot
      .list(recursive: true, followLinks: false)
      .where((entity) => entity is File)
      .cast<File>()
      .toList();
}

void main() {
  late Directory temporaryDirectory;
  late _FakeMetadataStore metadataStore;
  late SecureComposerDraftStore store;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'xueqing-composer-draft-test-',
    );
    metadataStore = _FakeMetadataStore();
    store = SecureComposerDraftStore(
      metadataStore: metadataStore,
      applicationSupportDirectoryProvider: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'failed metadata commit keeps the last complete draft recoverable',
    () async {
      const scope = 'quick-capture:user-1:org-1';
      final first = _snapshot(
        body: '旧草稿仍然完整。',
        attachmentId: 'old-photo',
        bytes: const <int>[1, 2, 3],
      );
      await store.save(scope, first);

      final beforeFailure = await store.load(scope);
      expect(beforeFailure?.state['body'], '旧草稿仍然完整。');
      expect(beforeFailure?.attachments.single.bytes, orderedEquals([1, 2, 3]));
      expect(await _draftFiles(temporaryDirectory), hasLength(1));

      metadataStore.failNextWrite = true;
      final replacement = _snapshot(
        body: '这次保存会在提交 metadata 时失败。',
        attachmentId: 'new-photo',
        bytes: const <int>[9, 8, 7],
      );

      await expectLater(
        store.save(scope, replacement),
        throwsA(isA<StateError>()),
      );

      final recovered = await store.load(scope);
      expect(recovered, isNotNull);
      expect(recovered!.state['body'], '旧草稿仍然完整。');
      expect(recovered.attachments, hasLength(1));
      expect(recovered.attachments.single.attachmentId, 'old-photo');
      expect(recovered.attachments.single.bytes, orderedEquals([1, 2, 3]));
      expect(
        await _draftFiles(temporaryDirectory),
        hasLength(1),
        reason:
            'The failed generation must be removed without touching the committed one.',
      );
    },
  );

  test(
    'successful replacement commits new generation before cleaning old files',
    () async {
      const scope = 'quick-capture:user-1:org-1';
      await store.save(
        scope,
        _snapshot(
          body: '第一版。',
          attachmentId: 'first-photo',
          bytes: const <int>[1],
        ),
      );
      await store.save(
        scope,
        _snapshot(
          body: '第二版。',
          attachmentId: 'second-photo',
          bytes: const <int>[2, 3],
        ),
      );

      final loaded = await store.load(scope);
      expect(loaded?.state['body'], '第二版。');
      expect(loaded?.attachments.single.attachmentId, 'second-photo');
      expect(loaded?.attachments.single.bytes, orderedEquals([2, 3]));
      expect(
        await _draftFiles(temporaryDirectory),
        hasLength(1),
        reason: 'Only the committed generation should remain after cleanup.',
      );
    },
  );

  test('clear removes metadata and all draft generations', () async {
    const scope = 'quick-capture:user-1:org-1';
    await store.save(
      scope,
      _snapshot(body: '待清理。', attachmentId: 'photo', bytes: const <int>[4, 5]),
    );

    await store.clear(scope);

    expect(await store.load(scope), isNull);
    expect(await _draftFiles(temporaryDirectory), isEmpty);
  });
}
