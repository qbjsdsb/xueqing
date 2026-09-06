# Windows updater helper

The Windows release bundle contains two copies of this helper:

- `xueqing_updater.exe` is the normal helper. New installs launch a temporary
  copy so the helper itself can be replaced safely.
- `xueqing_updater_bootstrap.exe` is a one-time migration helper. Older
  installs cannot replace their running `xueqing_updater.exe`, so the first
  upgraded bundle carries this second name through the old helper. The next
  update runs the bootstrap, replaces the canonical helper, and records a
  marker before future updates use the temporary-copy path.

The helper waits for the old app process to exit, verifies the package and
SHA-256, rejects unsafe archive paths, backs up the install directory, replaces
the files, starts the new app, and rolls back if the new process does not remain
alive during the startup grace period. User data is kept outside the install
directory and is not touched by this process.
