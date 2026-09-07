import 'package:test/test.dart';
import 'package:xueqing_windows_updater/updater_safety.dart';

void main() {
  test('normalizes safe Windows archive paths', () {
    expect(
      normalizeUpdaterArchivePath(r'assets\icons\student.png'),
      'assets/icons/student.png',
    );
    expect(normalizeUpdaterArchivePath('bundle/'), 'bundle');
  });

  test('rejects traversal, absolute, drive, and control paths', () {
    for (final path in <String>[
      '../escape.txt',
      r'..\escape.txt',
      r'C:\outside.txt',
      r'\\server\share.txt',
      'assets/\u0000bad.txt',
      'assets//bad.txt',
      'assets/./bad.txt',
    ]) {
      expect(
        () => normalizeUpdaterArchivePath(path),
        throwsA(isA<StateError>()),
        reason: path,
      );
    }
  });

  test('rejects Windows reserved names and trailing dot or space', () {
    for (final path in <String>[
      'CON',
      'CON.txt',
      'CON .txt',
      'folder/con.jpeg',
      'CONIN\$',
      'COM¹.txt',
      'folder/COM1.dll',
      'folder/LPT³.log',
      'folder/report.',
      'folder/report ',
    ]) {
      expect(
        () => normalizeUpdaterArchivePath(path),
        throwsA(isA<StateError>()),
        reason: path,
      );
    }
  });

  test('rejects Windows-invalid filename characters', () {
    for (final path in <String>[
      'folder/<report>.txt',
      'folder/report>.txt',
      'folder/"report".txt',
      'folder/report|draft.txt',
      'folder/report?.txt',
      'folder/report*.txt',
    ]) {
      expect(
        () => normalizeUpdaterArchivePath(path),
        throwsA(isA<StateError>()),
        reason: path,
      );
    }
  });

  test('rejects duplicate and case-insensitive archive paths', () {
    expect(
      () => validateUpdaterArchivePaths(<String>[
        'xueqing.exe',
        'assets/Logo.png',
        'assets/logo.png',
      ]),
      throwsA(isA<StateError>()),
    );
  });

  test('rejects archive entry bombs by entry count', () {
    final paths = List<String>.generate(
      maxUpdaterArchiveEntries + 1,
      (index) => 'assets/$index.bin',
    );
    expect(
      () => validateUpdaterArchivePaths(paths),
      throwsA(isA<StateError>()),
    );
  });
}
