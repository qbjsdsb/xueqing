import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class CaseReopenDraftStore {
  Future<CaseReopenDraft?> load(String scopeKey);

  Future<void> save(String scopeKey, CaseReopenDraft draft);

  Future<void> clear(String scopeKey);
}

class CaseReopenDraft {
  const CaseReopenDraft({
    required this.schemaVersion,
    required this.caseId,
    required this.expectedCaseVersion,
    required this.evidenceOperationId,
    required this.reopenOperationId,
    required this.sourceType,
    required this.evidenceTitle,
    required this.evidenceSummary,
    required this.observedAt,
    required this.evidenceVersion,
    required this.nextActionTypeWire,
    required this.nextActionTitle,
    this.evidenceId,
    this.nextActionDueOn,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String caseId;
  final int expectedCaseVersion;
  final String evidenceOperationId;
  final String reopenOperationId;
  final String sourceType;
  final String evidenceTitle;
  final String evidenceSummary;
  final DateTime observedAt;
  final String? evidenceId;
  final int evidenceVersion;
  final String nextActionTypeWire;
  final String nextActionTitle;
  final DateTime? nextActionDueOn;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schema_version': schemaVersion,
      'case_id': caseId,
      'expected_case_version': expectedCaseVersion,
      'evidence_operation_id': evidenceOperationId,
      'reopen_operation_id': reopenOperationId,
      'source_type': sourceType,
      'evidence_title': evidenceTitle,
      'evidence_summary': evidenceSummary,
      'observed_at': observedAt.toIso8601String(),
      'evidence_id': evidenceId,
      'evidence_version': evidenceVersion,
      'next_action_type': nextActionTypeWire,
      'next_action_title': nextActionTitle,
      'next_action_due_on': nextActionDueOn?.toIso8601String(),
    };
  }

  factory CaseReopenDraft.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _positiveInt(
      json['schema_version'],
      'schema_version',
    );
    if (schemaVersion != currentSchemaVersion) {
      throw FormatException(
        'Unsupported case reopen draft schema: $schemaVersion.',
      );
    }
    final sourceType = _requiredString(json['source_type'], 'source_type');
    const sourceTypes = <String>{
      'observation',
      'homework',
      'quiz',
      'exam',
      'essay',
      'classwork',
      'guardian_report',
      'other',
    };
    if (!sourceTypes.contains(sourceType)) {
      throw const FormatException(
        'Unsupported source_type in case reopen draft.',
      );
    }
    final nextActionTypeWire = _requiredString(
      json['next_action_type'],
      'next_action_type',
    );
    const actionTypes = <String>{
      'reteach',
      'practice',
      'verify',
      'communicate',
      'review',
      'other',
    };
    if (!actionTypes.contains(nextActionTypeWire)) {
      throw const FormatException(
        'Unsupported next_action_type in case reopen draft.',
      );
    }
    return CaseReopenDraft(
      schemaVersion: schemaVersion,
      caseId: _requiredString(json['case_id'], 'case_id'),
      expectedCaseVersion: _positiveInt(
        json['expected_case_version'],
        'expected_case_version',
      ),
      evidenceOperationId: _requiredString(
        json['evidence_operation_id'],
        'evidence_operation_id',
      ),
      reopenOperationId: _requiredString(
        json['reopen_operation_id'],
        'reopen_operation_id',
      ),
      sourceType: sourceType,
      evidenceTitle: _requiredString(json['evidence_title'], 'evidence_title'),
      evidenceSummary: _requiredString(
        json['evidence_summary'],
        'evidence_summary',
      ),
      observedAt: _requiredDateTime(json['observed_at'], 'observed_at'),
      evidenceId: _optionalString(json['evidence_id'], 'evidence_id'),
      evidenceVersion: _positiveInt(
        json['evidence_version'],
        'evidence_version',
      ),
      nextActionTypeWire: nextActionTypeWire,
      nextActionTitle: _requiredString(
        json['next_action_title'],
        'next_action_title',
      ),
      nextActionDueOn: _optionalDateTime(
        json['next_action_due_on'],
        'next_action_due_on',
      ),
    );
  }
}

class SecureCaseReopenDraftStore implements CaseReopenDraftStore {
  SecureCaseReopenDraftStore({FlutterSecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorage();

  static const _keyPrefix = 'xueqing.case_reopen_draft.v1.';

  final FlutterSecureStorage _storage;

  @override
  Future<CaseReopenDraft?> load(String scopeKey) async {
    final key = _keyFor(scopeKey);
    final raw = await _storage.read(key: key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Case reopen draft must be a JSON object.');
      }
      return CaseReopenDraft.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on Object {
      await _storage.delete(key: key);
      rethrow;
    }
  }

  @override
  Future<void> save(String scopeKey, CaseReopenDraft draft) {
    return _storage.write(
      key: _keyFor(scopeKey),
      value: jsonEncode(draft.toJson()),
    );
  }

  @override
  Future<void> clear(String scopeKey) {
    return _storage.delete(key: _keyFor(scopeKey));
  }

  String _keyFor(String scopeKey) {
    if (scopeKey.trim().isEmpty) {
      throw ArgumentError.value(scopeKey, 'scopeKey', 'cannot be blank.');
    }
    final encoded = base64UrlEncode(utf8.encode(scopeKey)).replaceAll('=', '');
    return '$_keyPrefix$encoded';
  }
}

class InMemoryCaseReopenDraftStore implements CaseReopenDraftStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<CaseReopenDraft?> load(String scopeKey) async {
    final raw = _values[scopeKey];
    if (raw == null) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Case reopen draft must be a JSON object.');
    }
    return CaseReopenDraft.fromJson(Map<String, dynamic>.from(decoded));
  }

  @override
  Future<void> save(String scopeKey, CaseReopenDraft draft) async {
    _values[scopeKey] = jsonEncode(draft.toJson());
  }

  @override
  Future<void> clear(String scopeKey) async {
    _values.remove(scopeKey);
  }
}

class NoopCaseReopenDraftStore implements CaseReopenDraftStore {
  const NoopCaseReopenDraftStore();

  @override
  Future<CaseReopenDraft?> load(String scopeKey) async => null;

  @override
  Future<void> save(String scopeKey, CaseReopenDraft draft) async {}

  @override
  Future<void> clear(String scopeKey) async {}
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or blank $field in case reopen draft.');
  }
  return value;
}

String? _optionalString(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $field in case reopen draft.');
  }
  return value;
}

int _positiveInt(Object? value, String field) {
  final number = value is int ? value : int.tryParse('$value');
  if (number == null || number <= 0) {
    throw FormatException('Invalid $field in case reopen draft.');
  }
  return number;
}

DateTime _requiredDateTime(Object? value, String field) {
  final parsed = DateTime.tryParse(_requiredString(value, field));
  if (parsed == null) {
    throw FormatException('Invalid $field in case reopen draft.');
  }
  return parsed;
}

DateTime? _optionalDateTime(Object? value, String field) {
  if (value == null) {
    return null;
  }
  return _requiredDateTime(value, field);
}