import 'package:supabase_flutter/supabase_flutter.dart';

class StudentLearningRecord {
  const StudentLearningRecord({
    required this.id,
    required this.occurredAt,
    required this.studentName,
    required this.subjectName,
    required this.issueTitle,
    required this.recordKind,
    required this.content,
    required this.teacherName,
    this.nextStep,
    required this.attachmentCount,
    this.attachmentPaths = const <String>[],
    required this.currentStatus,
    this.assessmentResult,
  });

  final String id;
  final DateTime occurredAt;
  final String studentName;
  final String subjectName;
  final String issueTitle;
  final String recordKind;
  final String content;
  final String? assessmentResult;
  final String teacherName;
  final String? nextStep;
  final int attachmentCount;
  final List<String> attachmentPaths;
  final String currentStatus;

  factory StudentLearningRecord.fromJson(Map<String, dynamic> json) {
    return StudentLearningRecord(
      id: _requiredString(json['record_id'], 'record_id'),
      occurredAt: _requiredDateTime(json['occurred_at'], 'occurred_at'),
      studentName: _requiredString(json['student_name'], 'student_name'),
      subjectName: _requiredString(json['subject_name'], 'subject_name'),
      issueTitle: _requiredString(json['issue_title'], 'issue_title'),
      recordKind: _requiredString(json['record_kind'], 'record_kind'),
      content: _requiredString(json['content'], 'content'),
      assessmentResult: _optionalString(json['assessment_result']),
      teacherName: _requiredString(json['teacher_name'], 'teacher_name'),
      nextStep: _optionalString(json['next_step']),
      attachmentCount: _requiredInt(
        json['attachment_count'],
        'attachment_count',
      ),
      attachmentPaths: _stringList(json['attachment_paths']),
      currentStatus: _requiredString(json['current_status'], 'current_status'),
    );
  }
}

abstract interface class StudentLearningRecordRepository {
  Future<List<StudentLearningRecord>> listStudentSubjectRecords({
    required String profileId,
  });
}

class SupabaseStudentLearningRecordRepository
    implements StudentLearningRecordRepository {
  SupabaseStudentLearningRecordRepository(this._client);

  final SupabaseClient _client;

  static const int _pageSize = 500;

  @override
  Future<List<StudentLearningRecord>> listStudentSubjectRecords({
    required String profileId,
  }) async {
    if (profileId.trim().isEmpty) {
      throw ArgumentError('profileId is required.');
    }

    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    final expectedUserId = authUser.id;
    final records = <StudentLearningRecord>[];
    var offset = 0;

    while (true) {
      _assertSameSession(expectedUserId);
      final response = await _client.rpc(
        'list_student_subject_learning_records_with_attachments',
        params: <String, dynamic>{
          'p_profile_id': profileId,
          'p_limit': _pageSize,
          'p_offset': offset,
        },
      );
      _assertSameSession(expectedUserId);

      if (response is! List) {
        throw const FormatException(
          'Student learning record export returned an invalid result.',
        );
      }

      for (final item in response) {
        if (item is! Map) {
          throw const FormatException(
            'Student learning record export returned an invalid row.',
          );
        }
        records.add(
          StudentLearningRecord.fromJson(Map<String, dynamic>.from(item)),
        );
      }

      if (response.length < _pageSize) {
        break;
      }
      offset += response.length;
    }

    return List<StudentLearningRecord>.unmodifiable(records);
  }

  void _assertSameSession(String expectedUserId) {
    if (_client.auth.currentUser?.id != expectedUserId) {
      throw const AuthException(
        'The active session changed while loading student records.',
      );
    }
  }
}

String? studentLearningRecordExportErrorMessage(Object error) {
  final detail = switch (error) {
    AuthException(:final message) => message.trim().toLowerCase(),
    PostgrestException(:final message) => message.trim().toLowerCase(),
    _ => null,
  };
  if (detail == null) {
    return null;
  }
  return switch (detail) {
    'teaching_fact_gate' => '当前账号没有这个学生学科的记录导出权限。',
    'invalid_command_input' => '导出条件不完整，请刷新后重试。',
    'invalid_live_session' || 'no active session.' => '登录状态已失效，请重新登录。',
    'the active session changed while loading student records.' =>
      '登录账号刚刚发生变化，请重新进入后再导出。',
    _ => null,
  };
}

List<String> _stringList(Object? value) {
  if (value == null) return const <String>[];
  if (value is! List) {
    throw const FormatException('Missing or invalid attachment_paths.');
  }
  return List<String>.unmodifiable([
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item.trim(),
  ]);
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid $field.');
  }
  return value.trim();
}

String? _optionalString(Object? value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _requiredInt(Object? value, String field) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('Missing or invalid $field.');
}

DateTime _requiredDateTime(Object? value, String field) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  throw FormatException('Missing or invalid $field.');
}
