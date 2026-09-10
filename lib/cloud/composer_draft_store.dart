import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class ComposerDraftAttachment {
  const ComposerDraftAttachment({
    required this.attachmentId,
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final String attachmentId;
  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

class ComposerDraftSnapshot {
  const ComposerDraftSnapshot({
    required this.kind,
    required this.studentId,
    required this.subject,
    required this.state,
    required this.attachments,
    required this.savedAt,
    this.caseId,
  });

  final String kind;
  final String studentId;
  final String? subject;
  final String? caseId;
  final Map<String, dynamic> state;
  final List<ComposerDraftAttachment> attachments;
  final DateTime savedAt;
}

abstract interface class ComposerDraftStore {
  Future<ComposerDraftSnapshot?> load(String scopeKey);

  Future<void> save(String scopeKey, ComposerDraftSnapshot snapshot);

  Future<void> clear(String scopeKey);
}

class SecureComposerDraftStore implements ComposerDraftStore {
  SecureComposerDraftStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const int _schemaVersion = 1;
  static const String _keyPrefix = 'xueqing.composer_draft.v1.';
  static const String _directoryName = 'xueqing_composer_drafts';

  final FlutterSecureStorage _storage;

  @override
  Future<ComposerDraftSnapshot?> load(String scopeKey) async {
    final normalizedScope = _validateScope(scopeKey);
    final raw = await _storage.read(key: _keyFor(normalizedScope));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Composer draft metadata is invalid.');
    }
    final json = Map<String, dynamic>.from(decoded);
    if (_positiveInt(json['schema_version'], 'schema_version') !=
        _schemaVersion) {
      throw const FormatException('Composer draft schema is not supported.');
    }

    final expectedDirectory = await _draftDirectory(normalizedScope);
    final expectedPrefix = '${expectedDirectory.path}${Platform.pathSeparator}';
    final attachmentRows = json['attachments'];
    if (attachmentRows is! List) {
      throw const FormatException('Composer draft attachments are invalid.');
    }
    final attachments = <ComposerDraftAttachment>[];
    for (final row in attachmentRows) {
      if (row is! Map) {
        continue;
      }
      final metadata = Map<String, dynamic>.from(row);
      final path = _requiredString(metadata['path'], 'attachment.path');
      if (!path.startsWith(expectedPrefix)) {
        continue;
      }
      final file = File(path);
      if (!await file.exists()) {
        continue;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        continue;
      }
      attachments.add(
        ComposerDraftAttachment(
          attachmentId: _requiredString(
            metadata['attachment_id'],
            'attachment.attachment_id',
          ),
          bytes: bytes,
          fileName: _requiredString(metadata['file_name'], 'attachment.file_name'),
          contentType: _requiredString(
            metadata['content_type'],
            'attachment.content_type',
          ),
        ),
      );
    }

    final state = json['state'];
    if (state is! Map) {
      throw const FormatException('Composer draft state is invalid.');
    }
    return ComposerDraftSnapshot(
      kind: _requiredString(json['kind'], 'kind'),
      studentId: _requiredString(json['student_id'], 'student_id'),
      subject: _optionalString(json['subject'], 'subject'),
      caseId: _optionalString(json['case_id'], 'case_id'),
      state: Map<String, dynamic>.from(state),
      attachments: List<ComposerDraftAttachment>.unmodifiable(attachments),
      savedAt: _requiredDateTime(json['saved_at'], 'saved_at'),
    );
  }

  @override
  Future<void> save(String scopeKey, ComposerDraftSnapshot snapshot) async {
    final normalizedScope = _validateScope(scopeKey);
    if (snapshot.kind.trim().isEmpty || snapshot.studentId.trim().isEmpty) {
      throw ArgumentError('Composer draft identity cannot be blank.');
    }

    final directory = await _draftDirectory(normalizedScope);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);

    final attachmentRows = <Map<String, dynamic>>[];
    for (final attachment in snapshot.attachments) {
      if (attachment.bytes.isEmpty || attachment.attachmentId.trim().isEmpty) {
        continue;
      }
      final extension = _extensionForContentType(attachment.contentType);
      final file = File(
        '${directory.path}${Platform.pathSeparator}'
        '${attachment.attachmentId}.$extension',
      );
      await file.writeAsBytes(attachment.bytes, flush: true);
      attachmentRows.add(<String, dynamic>{
        'attachment_id': attachment.attachmentId,
        'path': file.path,
        'file_name': attachment.fileName,
        'content_type': attachment.contentType,
      });
    }

    final payload = <String, dynamic>{
      'schema_version': _schemaVersion,
      'kind': snapshot.kind,
      'student_id': snapshot.studentId,
      'subject': snapshot.subject,
      'case_id': snapshot.caseId,
      'state': snapshot.state,
      'saved_at': snapshot.savedAt.toUtc().toIso8601String(),
      'attachments': attachmentRows,
    };
    await _storage.write(
      key: _keyFor(normalizedScope),
      value: jsonEncode(payload),
    );
  }

  @override
  Future<void> clear(String scopeKey) async {
    final normalizedScope = _validateScope(scopeKey);
    await _storage.delete(key: _keyFor(normalizedScope));
    final directory = await _draftDirectory(normalizedScope);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<Directory> _draftDirectory(String scopeKey) async {
    final root = await getTemporaryDirectory();
    return Directory(
      '${root.path}${Platform.pathSeparator}$_directoryName'
      '${Platform.pathSeparator}${_scopeToken(scopeKey)}',
    );
  }

  String _keyFor(String scopeKey) => '$_keyPrefix${_scopeToken(scopeKey)}';

  String _scopeToken(String scopeKey) =>
      base64UrlEncode(utf8.encode(scopeKey)).replaceAll('=', '');

  String _extensionForContentType(String contentType) {
    return switch (contentType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'bin',
    };
  }
}

class InMemoryComposerDraftStore implements ComposerDraftStore {
  final Map<String, ComposerDraftSnapshot> _values =
      <String, ComposerDraftSnapshot>{};

  @override
  Future<ComposerDraftSnapshot?> load(String scopeKey) async =>
      _values[_validateScope(scopeKey)];

  @override
  Future<void> save(String scopeKey, ComposerDraftSnapshot snapshot) async {
    _values[_validateScope(scopeKey)] = snapshot;
  }

  @override
  Future<void> clear(String scopeKey) async {
    _values.remove(_validateScope(scopeKey));
  }
}

String _validateScope(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, 'scopeKey', 'cannot be blank.');
  }
  return normalized;
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or blank $field in composer draft.');
  }
  return value;
}

String? _optionalString(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $field in composer draft.');
  }
  return value;
}

int _positiveInt(Object? value, String field) {
  final number = value is int ? value : int.tryParse('$value');
  if (number == null || number <= 0) {
    throw FormatException('Invalid $field in composer draft.');
  }
  return number;
}

DateTime _requiredDateTime(Object? value, String field) {
  final parsed = DateTime.tryParse(_requiredString(value, field));
  if (parsed == null) {
    throw FormatException('Invalid $field in composer draft.');
  }
  return parsed.toLocal();
}
