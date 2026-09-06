# Windows updater helper

This standalone Dart executable is copied into the Windows release bundle as
xueqing_updater.exe.

The Flutter app starts it after downloading and verifying the release ZIP. The
helper waits for the app process to exit, verifies the package again, extracts
to a temporary directory, backs up the current bundle, copies the new files,
and restores the backup if replacement or relaunch fails. User data is kept
outside the Windows installation bundle.
