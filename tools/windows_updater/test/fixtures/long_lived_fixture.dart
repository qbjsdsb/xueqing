import 'dart:async';
import 'dart:io';

const _lifecycleEnvironmentKey =
    'XUEQING_UPDATER_LONG_FIXTURE_LIFECYCLE';

Future<void> main() async {
  final lifecyclePath = Platform.environment[_lifecycleEnvironmentKey];
  final lifecycleFile = lifecyclePath == null || lifecyclePath.trim().isEmpty
      ? null
      : File(lifecyclePath);

  if (lifecycleFile != null) {
    await lifecycleFile.parent.create(recursive: true);
    await lifecycleFile.writeAsString('running:$pid\n', flush: true);
  }

  try {
    await Future<void>.delayed(const Duration(seconds: 5));
  } finally {
    if (lifecycleFile != null) {
      try {
        await lifecycleFile.writeAsString('exited:$pid\n', flush: true);
      } on FileSystemException {
        // A forced Windows taskkill can prevent the fixture from writing its
        // terminal marker. The updater rollback path launches the restored
        // long-lived fixture again; that process must eventually write the
        // terminal marker or the integration test will fail its bounded wait.
      }
    }
  }
}
