import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stable publisher stays isolated from development releases', () {
    final workflow = File('.github/workflows/publish-release-assets.yml')
        .readAsStringSync();

    expect(workflow, contains('XUEQING_ENV: production'));
    expect(workflow, contains('XUEQING_ALLOW_DEVELOPMENT_RELEASE: "false"'));
    expect(workflow, isNot(contains('release_environment')));
    expect(workflow, isNot(contains('czuctoulgnfytcfonkhc.supabase.co')));
    expect(workflow, contains('group: publish-stable-release'));
    expect(
      workflow,
      contains('^\[0-9\]+\\.\[0-9\]+\\.\[0-9\]+\\+\[1-9\]\[0-9\]\*\$'),
      reason: 'Stable versions must not accept prerelease identifiers.',
    );
  });

  test('stable publisher verifies the permanent Android signing identity', () {
    final workflow = File('.github/workflows/publish-release-assets.yml')
        .readAsStringSync();

    expect(workflow, contains('XUEQING_ANDROID_CERT_SHA256'));
    expect(workflow, contains('apksigner'));
    expect(workflow, contains('verify --verbose --print-certs'));
    expect(
      workflow,
      contains(
        'Android release certificate fingerprint does not match the pinned '
        'repository variable.',
      ),
    );
  });

  test('stable publisher promotes only after staged assets are verified', () {
    final workflow = File('.github/workflows/publish-release-assets.yml')
        .readAsStringSync();

    final stageCheck = workflow.indexOf(
      'The stable target must start as a published Pre-release staging Release.',
    );
    final upload = workflow.indexOf(
      'Upload immutable assets to staged Release',
    );
    final verify = workflow.indexOf('Verify staged Release assets');
    final promote = workflow.indexOf('Promote staged Release to Stable');
    final finalVerify = workflow.indexOf('Verify final Stable Release');

    expect(stageCheck, greaterThanOrEqualTo(0));
    expect(upload, greaterThan(stageCheck));
    expect(verify, greaterThan(upload));
    expect(promote, greaterThan(verify));
    expect(finalVerify, greaterThan(promote));
    expect(workflow, contains('--prerelease=false'));
    expect(workflow, contains('--latest'));
    expect(workflow, contains('"channel": "stable"'));
  });

  test('stable publisher keeps the proven Windows runtime pipeline', () {
    final workflow = File('.github/workflows/publish-release-assets.yml')
        .readAsStringSync();

    expect(workflow, contains('| Where-Object {'));
    expect(workflow, contains('| Select-Object -First 1'));
    expect(workflow, contains('Windows updater tests failed'));
    expect(workflow, contains('Build Windows installer'));
  });
}
