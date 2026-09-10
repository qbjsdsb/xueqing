import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compact V2 intercepts internal Android back hierarchy', () {
    final source = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();
    expect(source, contains('PopScope<void>('));
    expect(source, contains('canPop: !hasInternalHistory'));
    expect(source, contains('widget.onBackFromCase();'));
    expect(source, contains('setState(() => _studentOpen = false)'));
  });

  test('compact student canvas no longer mixes list and scaffold surfaces', () {
    final source = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();
    expect(
      source,
      contains(
        'widget.compact ? scheme.surface : scheme.surfaceContainerLowest',
      ),
    );
    expect(
      source,
      contains('backgroundColor: Theme.of(context).colorScheme.surface'),
    );
  });

  test(
    'teacher workspace exposes own-student export and Windows path feedback',
    () {
      final loader = File('lib/features/design_v2/v2_workspace_loader.dart')
          .readAsStringSync();
      final preview = File('lib/features/design_v2/v2_workspace_preview.dart')
          .readAsStringSync();
      final feedback = File('lib/export/learning_record_export_feedback.dart')
          .readAsStringSync();
      expect(loader, contains('_exportMyStudentRecords'));
      expect(preview, contains('导出我的学生学情'));
      expect(feedback, contains(r'保存位置：$savedPath'));
      expect(feedback, contains("label: '打开文件夹'"));
      expect(feedback, contains("'explorer.exe'"));
    },
  );

  test('update flow reports bytes and renders visible progress', () {
    final service = File('lib/update/update_service.dart').readAsStringSync();
    final flow = File('lib/features/design_v2/v2_update_flow.dart')
        .readAsStringSync();
    expect(service, contains('UpdateDownloadProgress? onProgress'));
    expect(
      service,
      contains('onProgress?.call(downloadedBytes, artifact.sizeBytes)'),
    );
    expect(flow, contains('LinearProgressIndicator(value: fraction)'));
    expect(flow, contains('下载完成并已校验'));
  });
}
