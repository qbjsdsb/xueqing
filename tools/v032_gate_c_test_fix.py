from pathlib import Path

path = Path('test/features/v032_progress_recovery_test.dart')
text = path.read_text(encoding='utf-8')
old_import = "import 'dart:typed_data';\n\n"
new_import = "import 'dart:convert';\nimport 'dart:typed_data';\n\n"
if text.count(old_import) != 1:
    raise SystemExit(f'expected typed_data import block once, found {text.count(old_import)}')
text = text.replace(old_import, new_import, 1)
old_bytes = "      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),\n      fileName: '恢复.jpg',\n      contentType: 'image/jpeg',\n"
new_bytes = "      bytes: Uint8List.fromList(\n        base64Decode(\n          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'\n          'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',\n        ),\n      ),\n      fileName: '恢复.png',\n      contentType: 'image/png',\n"
if text.count(old_bytes) != 1:
    raise SystemExit(f'expected invalid image fixture once, found {text.count(old_bytes)}')
path.write_text(text.replace(old_bytes, new_bytes, 1), encoding='utf-8')
print('Gate C recovery test now uses a real PNG fixture')

# The production restorer now intentionally handles both quick capture and
# progress drafts. Keep the source contract strict about those two supported
# kinds instead of pinning the old quick-capture-only private method name.
path = Path('test/features/v2_quick_capture_runtime_wiring_contract_test.dart')
text = path.read_text(encoding='utf-8')
old = "    expect(preview, contains('_restoreQuickCaptureDraft'));\n"
new = (
    "    expect(preview, contains('_restoreComposerDraft'));\n"
    "    expect(preview, contains(\"draft.kind == 'quick_capture'\"));\n"
    "    expect(preview, contains(\"draft.kind == 'progress'\"));\n"
)
if text.count(old) != 1:
    raise SystemExit(f'expected old quick-capture recovery contract once, found {text.count(old)}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('Gate C runtime recovery contract now covers both durable composer kinds')

# Progress recovery deliberately reuses the operation ids saved before the
# Android camera round-trip. The previous contract only asserted fresh id
# creation, which is now the fallback rather than the primary recovery path.
path = Path('test/features/design_v2_real_preview_contract_test.dart')
text = path.read_text(encoding='utf-8')
old = """    expect(\n      workspace,\n      contains('operationId = controller == null ? null : createOperationId()'),\n    );\n"""
new = """    expect(workspace, contains(\"initialDraft?.state['operation_id']\"));
    expect(
      workspace,
      contains(\"initialDraft?.state['photo_evidence_operation_id']\"),
    );
    expect(workspace, contains('storedOperationId.trim().isNotEmpty'));
    expect(workspace, contains('storedPhotoOperationId.trim().isNotEmpty'));
    expect(workspace, contains(': createOperationId();'));
"""
if text.count(old) != 1:
    raise SystemExit(f'expected old fresh-operation-id contract once, found {text.count(old)}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('Gate C operation-id contract now requires recovery reuse plus fresh fallback')
