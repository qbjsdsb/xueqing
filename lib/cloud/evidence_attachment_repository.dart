import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

const int maxCaseEvidenceAttachmentBytes = 10 * 1024 * 1024;
const String caseEvidenceAttachmentBucket = 'case-evidence-private';

class CaseEvidenceAttachment {
  const CaseEvidenceAttachment({
    required this.id,
    required this.organizationId,
    required this.learningCaseId,
    required this.caseEvidenceId,
    required this.storageBucket,
    required this.storagePath,
    required this.originalFileName,
    required this.contentType,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String organizationId;
  final String learningCaseId;
  final String caseEvidenceId;
  final String storageBucket;
  final String storagePath;
  final String originalFileName;
  final String contentType;
  final int sizeBytes;
  final DateTime createdAt;

  factory CaseEvidenceAttachment.fromJson(Map<String, dynamic> json) {
    return CaseEvidenceAttachment(
      id: _requiredString(json['id'], 'attachment_id'),
      organizationId: _requiredString(
        json['organization_id'],
        'attachment_organization_id',
      ),
      learningCaseId: _requiredString(
        json['learning_case_id'],
        'attachment_learning_case_id',
      ),
      caseEvidenceId: _requiredString(
        json['case_evidence_id'],
        'attachment_evidence_id',
      ),
      storageBucket: _requiredString(
        json['storage_bucket'],
        'attachment_storage_bucket',
      ),
      storagePath: _requiredString(
        json['storage_path'],
        'attachment_storage_path',
      ),
      originalFileName: _requiredString(
        json['original_file_name'],
        'attachment_file_name',
      ),
      contentType: _requiredString(
        json['content_type'],
        'attachment_content_type',
      ),
      sizeBytes: _requiredInt(json['size_bytes'], 'attachment_size_bytes'),
      createdAt: _requiredDateTime(json['created_at'], 'attachment_created_at'),
    );
  }
}

abstract interface class EvidenceAttachmentRepository {
  Future<List<CaseEvidenceAttachment>> listForEvidence(String evidenceId);

  Future<CaseEvidenceAttachment> upload({
    required String organizationId,
    required String learningCaseId,
    required String evidenceId,
    required String attachmentId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  });

  Future<String> createSignedUrl(String storagePath);
}

class SupabaseEvidenceAttachmentRepository
    implements EvidenceAttachmentRepository {
  SupabaseEvidenceAttachmentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CaseEvidenceAttachment>> listForEvidence(
    String evidenceId,
  ) async {
    _validateId(evidenceId, 'evidenceId');
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    final rows = await _client
        .from('case_evidence_attachments')
        .select(
          'id,organization_id,learning_case_id,case_evidence_id,'
          'storage_bucket,storage_path,original_file_name,content_type,'
          'size_bytes,created_at',
        )
        .eq('case_evidence_id', evidenceId)
        .order('created_at')
        .order('id');
    _assertSameSession(authUser.id);
    return [
      for (final row in rows)
        CaseEvidenceAttachment.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  @override
  Future<CaseEvidenceAttachment> upload({
    required String organizationId,
    required String learningCaseId,
    required String evidenceId,
    required String attachmentId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    _validateId(organizationId, 'organizationId');
    _validateId(learningCaseId, 'learningCaseId');
    _validateId(evidenceId, 'evidenceId');
    final normalizedAttachmentId = attachmentId.trim();
    if (!_isUuidV4(normalizedAttachmentId)) {
      throw ArgumentError('attachmentId must be a UUIDv4.');
    }
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    if (bytes.isEmpty || bytes.length > maxCaseEvidenceAttachmentBytes) {
      throw ArgumentError('Image must be between 1 byte and 10 MB.');
    }
    final normalizedFileName = fileName.trim();
    if (normalizedFileName.isEmpty || normalizedFileName.length > 255) {
      throw ArgumentError('Image file name is invalid.');
    }
    if (normalizedFileName.contains('/') || normalizedFileName.contains(r'\')) {
      throw ArgumentError('Image file name must not contain a path.');
    }
    final extension = _extensionForContentType(contentType);
    final storagePath =
        'org/$organizationId/cases/$learningCaseId/evidence/'
        '$evidenceId/$normalizedAttachmentId.$extension';
    var uploadAttempted = false;
    var metadataRpcStarted = false;
    try {
      uploadAttempted = true;
      await _client.storage
          .from(caseEvidenceAttachmentBucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              cacheControl: '3600',
              upsert: false,
            ),
          );
      _assertSameSession(authUser.id);

      metadataRpcStarted = true;
      final response = await _client.rpc(
        'create_case_evidence_attachment',
        params: <String, dynamic>{
          'p_organization_id': organizationId,
          'p_learning_case_id': learningCaseId,
          'p_case_evidence_id': evidenceId,
          'p_attachment_id': normalizedAttachmentId,
          'p_storage_path': storagePath,
          'p_original_file_name': normalizedFileName,
          'p_content_type': contentType,
          'p_size_bytes': bytes.length,
        },
      );
      _assertSameSession(authUser.id);
      if (response is! Map) {
        throw const FormatException(
          'Create attachment returned an invalid result.',
        );
      }
      return CaseEvidenceAttachment.fromJson(
        Map<String, dynamic>.from(response),
      );
    } catch (error) {
      if (uploadAttempted) {
        _assertSameSession(authUser.id);
        // The RPC may have committed successfully even when its HTTP response
        // was lost. Recover that committed row before trying cleanup so a
        // user retry does not create a second attachment.
        final committed = await _findCommittedAttachment(
          storagePath,
          organizationId,
          learningCaseId,
          evidenceId,
        );
        _assertSameSession(authUser.id);
        if (committed != null) {
          return committed;
        }
        if (!metadataRpcStarted) {
          // If the upload request failed before the metadata RPC started, no
          // current attempt can commit a row for this path. The delete policy
          // still refuses to remove an object that another attempt registered.
          try {
            await _client.storage.from(caseEvidenceAttachmentBucket).remove([
              storagePath,
            ]);
          } catch (_) {
            // Preserve the original error. Orphan cleanup can be audited later
            // from Storage using the same private path convention.
          }
        }
      }
      rethrow;
    }
  }

  Future<CaseEvidenceAttachment?> _findCommittedAttachment(
    String storagePath,
    String organizationId,
    String learningCaseId,
    String evidenceId,
  ) async {
    for (final delay in <Duration>[
      Duration.zero,
      const Duration(milliseconds: 100),
      const Duration(milliseconds: 300),
      const Duration(milliseconds: 700),
    ]) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      try {
        final row = await _client
            .from('case_evidence_attachments')
            .select(
              'id,organization_id,learning_case_id,case_evidence_id,'
              'storage_bucket,storage_path,original_file_name,content_type,'
              'size_bytes,created_at',
            )
            .eq('storage_path', storagePath)
            .maybeSingle();
        if (row == null) {
          continue;
        }
        final attachment = CaseEvidenceAttachment.fromJson(
          Map<String, dynamic>.from(row),
        );
        if (attachment.organizationId != organizationId ||
            attachment.learningCaseId != learningCaseId ||
            attachment.caseEvidenceId != evidenceId) {
          return null;
        }
        return attachment;
      } catch (_) {
        // A transient read failure must not cause the caller to delete an
        // object whose metadata may already be committed.
        continue;
      }
    }
    return null;
  }

  @override
  Future<String> createSignedUrl(String storagePath) async {
    final normalizedPath = storagePath.trim();
    if (normalizedPath.isEmpty) {
      throw ArgumentError('storagePath cannot be empty.');
    }
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('No active session.');
    }
    final url = await _client.storage
        .from(caseEvidenceAttachmentBucket)
        .createSignedUrl(normalizedPath, 300);
    _assertSameSession(authUser.id);
    return url;
  }

  String _extensionForContentType(String contentType) {
    return switch (contentType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => throw ArgumentError('Unsupported image content type.'),
    };
  }

  void _assertSameSession(String expectedUserId) {
    if (_client.auth.currentUser?.id != expectedUserId) {
      throw const AuthException(
        'The active session changed while handling an attachment.',
      );
    }
  }
}

final Random _random = Random.secure();

String createCaseEvidenceAttachmentId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
  final value = hex.join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

bool _isUuidV4(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-'
    r'[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}

void _validateId(String value, String field) {
  if (value.trim().isEmpty) {
    throw ArgumentError('$field cannot be empty.');
  }
}

String _requiredString(dynamic value, String field) {
  final result = value?.toString().trim();
  if (result == null || result.isEmpty) {
    throw FormatException('Missing $field in server response.');
  }
  return result;
}

int _requiredInt(dynamic value, String field) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw FormatException('Missing $field in server response.');
  }
  return parsed;
}

DateTime _requiredDateTime(dynamic value, String field) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw FormatException('Missing $field in server response.');
  }
  return parsed.toLocal();
}
