from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'expected block not found in {path}: {old[:100]!r}')
    if text.count(old) != 1:
        raise SystemExit(f'expected exactly one block in {path}, found {text.count(old)}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


# 1) Compact Android system-back hierarchy, phone canvas consistency, and
# a clear teacher-level bulk export entry.
preview = 'lib/features/design_v2/v2_workspace_preview.dart'
replace_once(
    preview,
    "typedef V2WorkspaceRefresh = Future<void> Function();\n",
    "typedef V2WorkspaceRefresh = Future<void> Function();\n"
    "typedef V2WorkspaceExport = Future<void> Function(BuildContext context);\n",
)
replace_once(
    preview,
    "    this.onExportStudent,\n    this.managementPageBuilder,",
    "    this.onExportStudent,\n    this.onExportMyStudents,\n    this.managementPageBuilder,",
)
replace_once(
    preview,
    "  final V2StudentExport? onExportStudent;\n  final WidgetBuilder? managementPageBuilder;",
    "  final V2StudentExport? onExportStudent;\n"
    "  final V2WorkspaceExport? onExportMyStudents;\n"
    "  final WidgetBuilder? managementPageBuilder;",
)
replace_once(
    preview,
    "            if (widget.managementPageBuilder != null)\n              ListTile(\n                leading: const Icon(Icons.admin_panel_settings_outlined),",
    "            if (widget.onExportMyStudents != null)\n"
    "              ListTile(\n"
    "                key: const Key('v2-menu-export-my-students'),\n"
    "                leading: const Icon(Icons.download_outlined),\n"
    "                title: const Text('导出我的学生学情'),\n"
    "                subtitle: const Text('导出当前有权限的学生、记录与图片'),\n"
    "                onTap: () => _afterMenuClose(\n"
    "                  menuContext,\n"
    "                  () => unawaited(widget.onExportMyStudents!(context)),\n"
    "                ),\n"
    "              ),\n"
    "            if (widget.managementPageBuilder != null)\n"
    "              ListTile(\n"
    "                leading: const Icon(Icons.admin_panel_settings_outlined),",
)
replace_once(
    preview,
    "    return Scaffold(\n      body: SafeArea(child: body),\n      bottomNavigationBar: widget.showCase || _studentOpen\n          ? null\n          : NavigationBar(\n              selectedIndex: widget.destination,",
    "    final hasInternalHistory = widget.showCase || _studentOpen;\n"
    "    return PopScope<void>(\n"
    "      canPop: !hasInternalHistory,\n"
    "      onPopInvokedWithResult: (didPop, _) {\n"
    "        if (didPop) return;\n"
    "        if (widget.showCase) {\n"
    "          widget.onBackFromCase();\n"
    "          return;\n"
    "        }\n"
    "        if (_studentOpen) {\n"
    "          setState(() => _studentOpen = false);\n"
    "        }\n"
    "      },\n"
    "      child: Scaffold(\n"
    "        backgroundColor: Theme.of(context).colorScheme.surface,\n"
    "        body: SafeArea(child: body),\n"
    "        bottomNavigationBar: hasInternalHistory\n"
    "            ? null\n"
    "            : NavigationBar(\n"
    "                backgroundColor: Theme.of(context).colorScheme.surface,\n"
    "                selectedIndex: widget.destination,",
)
replace_once(
    preview,
    "              ],\n            ),\n    );\n  }\n}\n\nclass _NavigationRail",
    "                ],\n              ),\n      ),\n    );\n  }\n}\n\nclass _NavigationRail",
)
replace_once(
    preview,
    "    final data = V2WorkspaceDataScope.of(context);\n    final visibleStudents = _visibleStudents(data);\n    return ColoredBox(\n      color: Theme.of(context).colorScheme.surfaceContainerLowest,",
    "    final data = V2WorkspaceDataScope.of(context);\n"
    "    final visibleStudents = _visibleStudents(data);\n"
    "    final scheme = Theme.of(context).colorScheme;\n"
    "    return ColoredBox(\n"
    "      color: widget.compact ? scheme.surface : scheme.surfaceContainerLowest,",
)

# 2) Export success feedback that tells Windows users exactly where the file is
# and can reveal it in Explorer without making export success depend on Explorer.
feedback = Path('lib/export/learning_record_export_feedback.dart')
feedback.write_text("""import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

void showLearningRecordExportSuccess(
  BuildContext context, {
  required String savedPath,
  String summary = '学情记录表已生成',
}) {
  final isWindows = Platform.isWindows;
  final message = isWindows ? '$summary。\\n保存位置：$savedPath' : '$summary。';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 8),
      content: Text(message),
      action: isWindows
          ? SnackBarAction(
              label: '打开文件夹',
              onPressed: () => unawaited(_revealWindowsFile(savedPath)),
            )
          : null,
    ),
  );
}

Future<void> _revealWindowsFile(String savedPath) async {
  if (!Platform.isWindows) return;
  final file = File(savedPath).absolute;
  try {
    await Process.start(
      'explorer.exe',
      <String>['/select,', file.path],
      mode: ProcessStartMode.detached,
    );
  } catch (_) {
    try {
      await Process.start(
        'explorer.exe',
        <String>[file.parent.path],
        mode: ProcessStartMode.detached,
      );
    } catch (_) {
      // Export already succeeded. Explorer reveal is convenience only.
    }
  }
}
""", encoding='utf-8')

loader = 'lib/features/design_v2/v2_workspace_loader.dart'
replace_once(
    loader,
    "import '../../export/learning_record_export.dart';\n",
    "import '../../export/learning_record_export.dart';\n"
    "import '../../export/learning_record_export_feedback.dart';\n",
)
replace_once(
    loader,
    "      ScaffoldMessenger.of(context).showSnackBar(\n        SnackBar(content: Text(savedPath == null ? '已取消导出。' : '学情记录表已生成。')),\n      );",
    "      if (savedPath == null) {\n"
    "        ScaffoldMessenger.of(context).showSnackBar(\n"
    "          const SnackBar(content: Text('已取消导出。')),\n"
    "        );\n"
    "      } else {\n"
    "        showLearningRecordExportSuccess(\n"
    "          context,\n"
    "          savedPath: savedPath,\n"
    "        );\n"
    "      }",
)
anchor = "\n  @override\n  Widget build(BuildContext context) {\n    return FutureBuilder<TeacherWorkspace>("
if anchor not in Path(loader).read_text(encoding='utf-8'):
    raise SystemExit('loader build anchor not found')
method = r'''

  Future<void> _exportMyStudentRecords(
    BuildContext context,
    TeacherWorkspace workspace,
  ) async {
    final repository = widget.runtime?.studentLearningRecordRepository;
    if (repository == null) return;

    final profilesById = <String, WorkspaceStudent>{};
    for (final profile in workspace.students) {
      profilesById[profile.profileId] = profile;
    }
    final profiles = profilesById.values.toList(growable: false);
    if (profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前没有可导出的任课学生。')),
      );
      return;
    }

    try {
      final records = <StudentLearningRecord>[];
      const requestBatchSize = 4;
      for (var start = 0; start < profiles.length; start += requestBatchSize) {
        final end = (start + requestBatchSize).clamp(0, profiles.length);
        final batch = profiles.sublist(start, end);
        final batches = await Future.wait([
          for (final profile in batch)
            repository.listStudentSubjectRecords(profileId: profile.profileId),
        ]);
        for (final batchRecords in batches) {
          records.addAll(batchRecords);
        }
      }
      if (!context.mounted) return;
      if (records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('我的任课学生目前还没有可导出的学情记录。')),
        );
        return;
      }

      final rows = LearningRecordExport.rowsForStudentRecords(records);
      final preparedRows = await LearningRecordExport.prepareRowsWithAttachmentImages(
        rows: rows,
        repository:
            widget.runtime?.evidenceAttachmentRepository ??
            widget.evidenceAttachmentRepository,
      );
      final studentCount = profiles.map((profile) => profile.id).toSet().length;
      final savedPath = await LearningRecordExport.saveAsXlsx(
        fileNameWithoutExtension: LearningRecordExport.studentBatchFileName(
          studentCount: studentCount,
          profileCount: profiles.length,
        ),
        rows: preparedRows,
      );
      if (!context.mounted) return;
      if (savedPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消导出。')),
        );
        return;
      }
      showLearningRecordExportSuccess(
        context,
        savedPath: savedPath,
        summary: '已导出 $studentCount 名任课学生的学情记录',
      );
    } catch (error) {
      if (!context.mounted) return;
      final message =
          learningRecordImageExportErrorMessage(error) ??
          studentLearningRecordExportErrorMessage(error) ??
          '学情记录暂时无法导出，请检查网络后重试。';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
'''
p = Path(loader)
text = p.read_text(encoding='utf-8')
p.write_text(text.replace(anchor, method + anchor, 1), encoding='utf-8')
replace_once(
    loader,
    "          onExportStudent: runtime?.studentLearningRecordRepository == null\n              ? null\n              : (context, student) =>\n                    _exportStudentRecords(context, workspace, student),\n          managementPageBuilder:",
    "          onExportStudent: runtime?.studentLearningRecordRepository == null\n"
    "              ? null\n"
    "              : (context, student) =>\n"
    "                    _exportStudentRecords(context, workspace, student),\n"
    "          onExportMyStudents:\n"
    "              runtime?.studentLearningRecordRepository != null &&\n"
    "                  !workspace.canManageOrganization\n"
    "              ? (context) => _exportMyStudentRecords(context, workspace)\n"
    "              : null,\n"
    "          managementPageBuilder:",
)

# Manager and legacy export flows use the same success feedback.
manager_page = 'lib/features/organization_management/presentation/organization_management_page.dart'
replace_once(
    manager_page,
    "import '../../../export/learning_record_export.dart';\n",
    "import '../../../export/learning_record_export.dart';\n"
    "import '../../../export/learning_record_export_feedback.dart';\n",
)
manager_actions = 'lib/features/organization_management/presentation/organization_management_learning_actions.dart'
replace_once(
    manager_actions,
    "      ScaffoldMessenger.of(context).showSnackBar(\n        SnackBar(\n          content: Text(\n            savedPath == null\n                ? '已取消导出。'\n                : '已生成 ${selection.studentCount} 名学生、${selection.profiles.length} 个学科的学情记录表。',\n          ),\n        ),\n      );",
    "      if (savedPath == null) {\n"
    "        ScaffoldMessenger.of(context).showSnackBar(\n"
    "          const SnackBar(content: Text('已取消导出。')),\n"
    "        );\n"
    "      } else {\n"
    "        showLearningRecordExportSuccess(\n"
    "          context,\n"
    "          savedPath: savedPath,\n"
    "          summary:\n"
    "              '已导出 ${selection.studentCount} 名学生、${selection.profiles.length} 个学科的学情记录',\n"
    "        );\n"
    "      }",
)
replace_once(
    manager_actions,
    "      ScaffoldMessenger.of(context).showSnackBar(\n        SnackBar(\n          content: Text(\n            savedPath == null ? '已取消导出。' : '$teacherName 的教学记录表已生成。',\n          ),\n        ),\n      );",
    "      if (savedPath == null) {\n"
    "        ScaffoldMessenger.of(context).showSnackBar(\n"
    "          const SnackBar(content: Text('已取消导出。')),\n"
    "        );\n"
    "      } else {\n"
    "        showLearningRecordExportSuccess(\n"
    "          context,\n"
    "          savedPath: savedPath,\n"
    "          summary: '$teacherName 的教学记录已导出',\n"
    "        );\n"
    "      }",
)
legacy = 'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart'
replace_once(
    legacy,
    "import '../../../export/learning_record_export.dart';\n",
    "import '../../../export/learning_record_export.dart';\n"
    "import '../../../export/learning_record_export_feedback.dart';\n",
)
replace_once(
    legacy,
    "      ScaffoldMessenger.of(context).showSnackBar(\n        SnackBar(content: Text(savedPath == null ? '已取消导出。' : '学情记录表已生成。')),\n      );",
    "      if (savedPath == null) {\n"
    "        ScaffoldMessenger.of(context).showSnackBar(\n"
    "          const SnackBar(content: Text('已取消导出。')),\n"
    "        );\n"
    "      } else {\n"
    "        showLearningRecordExportSuccess(\n"
    "          context,\n"
    "          savedPath: savedPath,\n"
    "        );\n"
    "      }",
)

# 3) Make update download progress observable from the HTTP loop.
service = 'lib/update/update_service.dart'
replace_once(
    service,
    "typedef UpdateManifestLoader = Future<String> Function(Uri uri);\n",
    "typedef UpdateManifestLoader = Future<String> Function(Uri uri);\n"
    "typedef UpdateDownloadProgress = void Function(\n"
    "  int downloadedBytes,\n"
    "  int totalBytes,\n"
    ");\n",
)
replace_once(
    service,
    "  Future<UpdateDownloadedArtifact> download(UpdateCheckResult result) async {",
    "  Future<UpdateDownloadedArtifact> download(\n"
    "    UpdateCheckResult result, {\n"
    "    UpdateDownloadProgress? onProgress,\n"
    "  }) async {",
)
replace_once(
    service,
    "    if (artifact.sizeBytes > maxDownloadBytes) {\n      throw const UpdateException('更新包超过允许的最大大小，已停止下载。');\n    }\n    final temporaryDirectory",
    "    if (artifact.sizeBytes > maxDownloadBytes) {\n"
    "      throw const UpdateException('更新包超过允许的最大大小，已停止下载。');\n"
    "    }\n"
    "    onProgress?.call(0, artifact.sizeBytes);\n"
    "    final temporaryDirectory",
)
replace_once(
    service,
    "        if (downloadedBytes > artifact.sizeBytes) {\n          throw const UpdateException('下载内容超过清单声明大小，已停止。');\n        }\n        digestInput.add(chunk);",
    "        if (downloadedBytes > artifact.sizeBytes) {\n"
    "          throw const UpdateException('下载内容超过清单声明大小，已停止。');\n"
    "        }\n"
    "        onProgress?.call(downloadedBytes, artifact.sizeBytes);\n"
    "        digestInput.add(chunk);",
)
replace_once(
    service,
    "      verified = true;\n      return UpdateDownloadedArtifact(artifact: artifact, file: destination);",
    "      verified = true;\n"
    "      onProgress?.call(artifact.sizeBytes, artifact.sizeBytes);\n"
    "      return UpdateDownloadedArtifact(artifact: artifact, file: destination);",
)

# Shared V2 update flow: keep a non-dismissible progress dialog visible through
# download + checksum + installer handoff.
Path('lib/features/design_v2/v2_update_flow.dart').write_text(r'''import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../update/update_dialog.dart';
import '../../update/update_installer.dart';
import '../../update/update_service.dart';

Future<void> runV2UpdateFlow(
  BuildContext context, {
  required UpdateService service,
  required UpdateInstaller installer,
}) async {
  try {
    final result = await service.checkForUpdate();
    if (!context.mounted) return;

    final shouldInstall = await showDialog<bool>(
      context: context,
      builder: (_) => UpdateDialog(result: result),
    );
    if (shouldInstall != true || !context.mounted) return;

    final artifact = result.artifact;
    if (artifact == null) return;
    final progress = ValueNotifier<_V2UpdateProgressState>(
      _V2UpdateProgressState(
        downloadedBytes: 0,
        totalBytes: artifact.sizeBytes,
        status: '正在下载更新…',
      ),
    );
    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope<void>(
        canPop: false,
        child: _V2UpdateProgressDialog(progress: progress),
      ),
    );

    UpdateInstallResult? installResult;
    try {
      // Let the progress route render before network I/O begins.
      await Future<void>.delayed(Duration.zero);
      final downloaded = await service.download(
        result,
        onProgress: (downloadedBytes, totalBytes) {
          progress.value = _V2UpdateProgressState(
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            status: '正在下载更新…',
          );
        },
      );
      progress.value = _V2UpdateProgressState(
        downloadedBytes: artifact.sizeBytes,
        totalBytes: artifact.sizeBytes,
        status: '下载完成并已校验，正在打开安装程序…',
      );
      installResult = await installer.install(downloaded);
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        await dialogFuture;
      }
      progress.dispose();
    }

    if (!context.mounted || installResult == null) return;
    if (installResult.shouldExit) {
      await SystemNavigator.pop();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('更新包已下载并校验，已打开系统安装界面，请按提示完成更新。')),
    );
  } on UpdateException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.userMessage)),
      );
    }
  } on UpdateInstallException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.userMessage)),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新失败，请稍后重试。')),
      );
    }
  }
}

class _V2UpdateProgressState {
  const _V2UpdateProgressState({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.status,
  });

  final int downloadedBytes;
  final int totalBytes;
  final String status;

  double? get fraction {
    if (totalBytes <= 0) return null;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }
}

class _V2UpdateProgressDialog extends StatelessWidget {
  const _V2UpdateProgressDialog({required this.progress});

  final ValueListenable<_V2UpdateProgressState> progress;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('正在更新学情'),
      content: ValueListenableBuilder<_V2UpdateProgressState>(
        valueListenable: progress,
        builder: (context, value, _) {
          final fraction = value.fraction;
          final percent = fraction == null ? null : (fraction * 100).round();
          return SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value.status),
                const SizedBox(height: 14),
                LinearProgressIndicator(value: fraction),
                const SizedBox(height: 10),
                Text(
                  percent == null
                      ? '${_formatBytes(value.downloadedBytes)} 已下载'
                      : '$percent% · ${_formatBytes(value.downloadedBytes)} / ${_formatBytes(value.totalBytes)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '下载完成后会自动校验文件并打开安装程序，请不要关闭应用。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 10 ? 1 : 2)} MB';
}
''', encoding='utf-8')

# Regression contracts complement widget/full-suite tests and prevent these
# real-device affordances from silently disappearing.
Path('test/features/v032_real_device_ux_contract_test.dart').write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compact V2 intercepts internal Android back hierarchy', () {
    final source = File(
      'lib/features/design_v2/v2_workspace_preview.dart',
    ).readAsStringSync();
    expect(source, contains('PopScope<void>('));
    expect(source, contains('canPop: !hasInternalHistory'));
    expect(source, contains('widget.onBackFromCase();'));
    expect(source, contains('setState(() => _studentOpen = false)'));
  });

  test('compact student canvas no longer mixes list and scaffold surfaces', () {
    final source = File(
      'lib/features/design_v2/v2_workspace_preview.dart',
    ).readAsStringSync();
    expect(
      source,
      contains('widget.compact ? scheme.surface : scheme.surfaceContainerLowest'),
    );
    expect(
      source,
      contains('backgroundColor: Theme.of(context).colorScheme.surface'),
    );
  });

  test('teacher workspace exposes own-student export and Windows path feedback', () {
    final loader = File(
      'lib/features/design_v2/v2_workspace_loader.dart',
    ).readAsStringSync();
    final preview = File(
      'lib/features/design_v2/v2_workspace_preview.dart',
    ).readAsStringSync();
    final feedback = File(
      'lib/export/learning_record_export_feedback.dart',
    ).readAsStringSync();
    expect(loader, contains('_exportMyStudentRecords'));
    expect(preview, contains('导出我的学生学情'));
    expect(feedback, contains('保存位置：$savedPath'));
    expect(feedback, contains("label: '打开文件夹'"));
    expect(feedback, contains("'explorer.exe'"));
  });

  test('update flow reports bytes and renders visible progress', () {
    final service = File('lib/update/update_service.dart').readAsStringSync();
    final flow = File(
      'lib/features/design_v2/v2_update_flow.dart',
    ).readAsStringSync();
    expect(service, contains('UpdateDownloadProgress? onProgress'));
    expect(service, contains('onProgress?.call(downloadedBytes, artifact.sizeBytes)'));
    expect(flow, contains('LinearProgressIndicator(value: fraction)'));
    expect(flow, contains('下载完成并已校验'));
  });
}
''', encoding='utf-8')

print('v0.3.2 Gate A patch applied')
