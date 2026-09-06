const maxUpdaterArchiveEntries = 10000;

const _reservedWindowsNames = <String>{
  'AUX',
  'CLOCK
  'COM2',
  'COM3',
  'COM4',
  'COM5',
  'COM6',
  'COM7',
  'COM8',
  'COM9',
  'COM¹',
  'COM²',
  'COM³',
  'CONIN
  'LPT2',
  'LPT3',
  'LPT4',
  'LPT5',
  'LPT6',
  'LPT7',
  'LPT8',
  'LPT9',
  'LPT¹',
  'LPT²',
  'LPT³',
  'NUL',
  'PRN',
};

String normalizeUpdaterArchivePath(String raw) {
  var path = raw.replaceAll(r'\', '/');
  if (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final parts = path.split('/');
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.contains(':') ||
      path.contains(RegExp(r'[\x00-\x1f]')) ||
      parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw StateError('压缩包包含不安全路径：$raw');
  }

  for (final part in parts) {
    if (part.endsWith('.') || part.endsWith(' ')) {
      throw StateError('压缩包包含 Windows 非法文件名：$raw');
    }
    final stem = part.split('.').first.trimRight().toUpperCase();
    if (_reservedWindowsNames.contains(stem)) {
      throw StateError('压缩包包含 Windows 保留设备名：$raw');
    }
  }
  return path;
}

void validateUpdaterArchivePaths(Iterable<String> rawPaths) {
  final seen = <String>{};
  var count = 0;
  for (final rawPath in rawPaths) {
    count++;
    if (count > maxUpdaterArchiveEntries) {
      throw StateError('压缩包条目数量超过安全上限：$maxUpdaterArchiveEntries');
    }
    final path = normalizeUpdaterArchivePath(rawPath);
    final key = path.toLowerCase();
    if (!seen.add(key)) {
      throw StateError('压缩包包含大小写冲突或重复路径：$path');
    }
  }
}
,
  'COM1',
  'COM2',
  'COM3',
  'COM4',
  'COM5',
  'COM6',
  'COM7',
  'COM8',
  'COM9',
  'LPT1',
  'LPT2',
  'LPT3',
  'LPT4',
  'LPT5',
  'LPT6',
  'LPT7',
  'LPT8',
  'LPT9',
  'NUL',
  'PRN',
};

String normalizeUpdaterArchivePath(String raw) {
  var path = raw.replaceAll(r'\', '/');
  if (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final parts = path.split('/');
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.contains(':') ||
      path.contains(RegExp(r'[\x00-\x1f]')) ||
      parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw StateError('压缩包包含不安全路径：$raw');
  }

  for (final part in parts) {
    if (part.endsWith('.') || part.endsWith(' ')) {
      throw StateError('压缩包包含 Windows 非法文件名：$raw');
    }
    final stem = part.split('.').first.toUpperCase();
    if (_reservedWindowsNames.contains(stem)) {
      throw StateError('压缩包包含 Windows 保留设备名：$raw');
    }
  }
  return path;
}

void validateUpdaterArchivePaths(Iterable<String> rawPaths) {
  final seen = <String>{};
  var count = 0;
  for (final rawPath in rawPaths) {
    count++;
    if (count > maxUpdaterArchiveEntries) {
      throw StateError('压缩包条目数量超过安全上限：$maxUpdaterArchiveEntries');
    }
    final path = normalizeUpdaterArchivePath(rawPath);
    final key = path.toLowerCase();
    if (!seen.add(key)) {
      throw StateError('压缩包包含大小写冲突或重复路径：$path');
    }
  }
}
,
  'CONOUT
  'LPT2',
  'LPT3',
  'LPT4',
  'LPT5',
  'LPT6',
  'LPT7',
  'LPT8',
  'LPT9',
  'NUL',
  'PRN',
};

String normalizeUpdaterArchivePath(String raw) {
  var path = raw.replaceAll(r'\', '/');
  if (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final parts = path.split('/');
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.contains(':') ||
      path.contains(RegExp(r'[\x00-\x1f]')) ||
      parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw StateError('压缩包包含不安全路径：$raw');
  }

  for (final part in parts) {
    if (part.endsWith('.') || part.endsWith(' ')) {
      throw StateError('压缩包包含 Windows 非法文件名：$raw');
    }
    final stem = part.split('.').first.toUpperCase();
    if (_reservedWindowsNames.contains(stem)) {
      throw StateError('压缩包包含 Windows 保留设备名：$raw');
    }
  }
  return path;
}

void validateUpdaterArchivePaths(Iterable<String> rawPaths) {
  final seen = <String>{};
  var count = 0;
  for (final rawPath in rawPaths) {
    count++;
    if (count > maxUpdaterArchiveEntries) {
      throw StateError('压缩包条目数量超过安全上限：$maxUpdaterArchiveEntries');
    }
    final path = normalizeUpdaterArchivePath(rawPath);
    final key = path.toLowerCase();
    if (!seen.add(key)) {
      throw StateError('压缩包包含大小写冲突或重复路径：$path');
    }
  }
}
,
  'COM1',
  'COM2',
  'COM3',
  'COM4',
  'COM5',
  'COM6',
  'COM7',
  'COM8',
  'COM9',
  'LPT1',
  'LPT2',
  'LPT3',
  'LPT4',
  'LPT5',
  'LPT6',
  'LPT7',
  'LPT8',
  'LPT9',
  'NUL',
  'PRN',
};

String normalizeUpdaterArchivePath(String raw) {
  var path = raw.replaceAll(r'\', '/');
  if (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final parts = path.split('/');
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.contains(':') ||
      path.contains(RegExp(r'[\x00-\x1f]')) ||
      parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw StateError('压缩包包含不安全路径：$raw');
  }

  for (final part in parts) {
    if (part.endsWith('.') || part.endsWith(' ')) {
      throw StateError('压缩包包含 Windows 非法文件名：$raw');
    }
    final stem = part.split('.').first.toUpperCase();
    if (_reservedWindowsNames.contains(stem)) {
      throw StateError('压缩包包含 Windows 保留设备名：$raw');
    }
  }
  return path;
}

void validateUpdaterArchivePaths(Iterable<String> rawPaths) {
  final seen = <String>{};
  var count = 0;
  for (final rawPath in rawPaths) {
    count++;
    if (count > maxUpdaterArchiveEntries) {
      throw StateError('压缩包条目数量超过安全上限：$maxUpdaterArchiveEntries');
    }
    final path = normalizeUpdaterArchivePath(rawPath);
    final key = path.toLowerCase();
    if (!seen.add(key)) {
      throw StateError('压缩包包含大小写冲突或重复路径：$path');
    }
  }
}
,
  'LPT1',
  'LPT2',
  'LPT3',
  'LPT4',
  'LPT5',
  'LPT6',
  'LPT7',
  'LPT8',
  'LPT9',
  'NUL',
  'PRN',
};

String normalizeUpdaterArchivePath(String raw) {
  var path = raw.replaceAll(r'\', '/');
  if (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final parts = path.split('/');
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.contains(':') ||
      path.contains(RegExp(r'[\x00-\x1f]')) ||
      parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw StateError('压缩包包含不安全路径：$raw');
  }

  for (final part in parts) {
    if (part.endsWith('.') || part.endsWith(' ')) {
      throw StateError('压缩包包含 Windows 非法文件名：$raw');
    }
    final stem = part.split('.').first.toUpperCase();
    if (_reservedWindowsNames.contains(stem)) {
      throw StateError('压缩包包含 Windows 保留设备名：$raw');
    }
  }
  return path;
}

void validateUpdaterArchivePaths(Iterable<String> rawPaths) {
  final seen = <String>{};
  var count = 0;
  for (final rawPath in rawPaths) {
    count++;
    if (count > maxUpdaterArchiveEntries) {
      throw StateError('压缩包条目数量超过安全上限：$maxUpdaterArchiveEntries');
    }
    final path = normalizeUpdaterArchivePath(rawPath);
    final key = path.toLowerCase();
    if (!seen.add(key)) {
      throw StateError('压缩包包含大小写冲突或重复路径：$path');
    }
  }
}
,
  'COM1',
  'COM2',
  'COM3',
  'COM4',
  'COM5',
  'COM6',
  'COM7',
  'COM8',
  'COM9',
  'LPT1',
  'LPT2',
  'LPT3',
  'LPT4',
  'LPT5',
  'LPT6',
  'LPT7',
  'LPT8',
  'LPT9',
  'NUL',
  'PRN',
};

String normalizeUpdaterArchivePath(String raw) {
  var path = raw.replaceAll(r'\', '/');
  if (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final parts = path.split('/');
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.contains(':') ||
      path.contains(RegExp(r'[\x00-\x1f]')) ||
      parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw StateError('压缩包包含不安全路径：$raw');
  }

  for (final part in parts) {
    if (part.endsWith('.') || part.endsWith(' ')) {
      throw StateError('压缩包包含 Windows 非法文件名：$raw');
    }
    final stem = part.split('.').first.toUpperCase();
    if (_reservedWindowsNames.contains(stem)) {
      throw StateError('压缩包包含 Windows 保留设备名：$raw');
    }
  }
  return path;
}

void validateUpdaterArchivePaths(Iterable<String> rawPaths) {
  final seen = <String>{};
  var count = 0;
  for (final rawPath in rawPaths) {
    count++;
    if (count > maxUpdaterArchiveEntries) {
      throw StateError('压缩包条目数量超过安全上限：$maxUpdaterArchiveEntries');
    }
    final path = normalizeUpdaterArchivePath(rawPath);
    final key = path.toLowerCase();
    if (!seen.add(key)) {
      throw StateError('压缩包包含大小写冲突或重复路径：$path');
    }
  }
}
