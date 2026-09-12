import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stable release backend gate is version-aware through v0.3.9', () {
    final workflow = File('.github/workflows/publish-release-assets.yml')
        .readAsStringSync();

    expect(workflow, contains(r'RELEASE_VERSION_NAME="$version_name"'));
    expect(
      workflow,
      contains(
        "BACKEND_JSON=\"\$backend_json\" "
        "RELEASE_VERSION_NAME=\"\$version_name\" python3 - <<'PY'",
      ),
    );
    expect(
      workflow,
      isNot(contains("python3 -c 'import json, os; required_schema=")),
    );

    expect(workflow, contains('required_schema = "20260911193000"'));
    expect(workflow, contains('version >= (0, 3, 8)'));
    expect(workflow, contains('version >= (0, 3, 9)'));

    for (final capability in <String>[
      'responsibility_read_model',
      'organization_profile_responsibility',
      'responsibility_safe_quick_capture',
      'explicit_teaching_handoff',
      'set_student_subject_lead',
    ]) {
      expect(workflow, contains('"$capability"'));
    }

    expect(
      workflow,
      contains(
        'required += [\n'
        '              "explicit_teaching_handoff",\n'
        '              "set_student_subject_lead",\n'
        '          ] if version >= (0, 3, 9) else []',
      ),
    );
  });
}
