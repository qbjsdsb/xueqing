from pathlib import Path


def replace_exact(path: str, old: str, new: str, expected: int = 1) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != expected:
        raise SystemExit(f"{path}: expected {expected} matches, found {count}: {old!r}")
    file.write_text(text.replace(old, new), encoding="utf-8")


replace_exact("pubspec.yaml", "version: 0.2.0+2", "version: 0.2.0+4")
replace_exact(
    "lib/config/app_config.dart",
    "defaultValue: '0.2.0+2'",
    "defaultValue: '0.2.0+4'",
)
replace_exact(
    "lib/config/app_config.dart",
    "String appVersion = '0.2.0+2'",
    "String appVersion = '0.2.0+4'",
)
replace_exact(
    ".github/workflows/publish-release-assets.yml",
    'for example 0.2.0+2',
    'for example 0.2.0+4',
)
replace_exact(
    ".github/workflows/publish-release-assets.yml",
    'default: 0.2.0+2',
    'default: 0.2.0+4',
)

for path in ("docs/RELEASING.md", "docs/update-manifest.example.json"):
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    if "0.2.0+2" not in text:
        raise SystemExit(f"{path}: expected release-version example not found")
    file.write_text(text.replace("0.2.0+2", "0.2.0+4"), encoding="utf-8")

replace_exact(
    "lib/update/update_service.dart",
    """      if (response.statusCode != HttpStatus.ok) {\n        throw UpdateException('检查更新失败（HTTP ${response.statusCode}）。');\n      }\n""",
    """      if (response.statusCode == HttpStatus.notFound) {\n        throw const UpdateException('当前还没有可用的稳定更新。');\n      }\n      if (response.statusCode != HttpStatus.ok) {\n        throw UpdateException('检查更新失败（HTTP ${response.statusCode}）。');\n      }\n""",
)

service_test = Path("test/update/update_service_test.dart")
text = service_test.read_text(encoding="utf-8")
if "import 'dart:async';" not in text:
    text = text.replace("import 'dart:convert';\n", "import 'dart:async';\nimport 'dart:convert';\n", 1)
marker = "\n}\n"
if "stable updater explains a missing manifest without raw HTTP details" in text:
    raise SystemExit("update_service_test.dart: release-readiness test already present")
insert = r'''

  test(
    'stable updater explains a missing manifest without raw HTTP details',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) {
        request.response.statusCode = HttpStatus.notFound;
        unawaited(request.response.close());
      });
      try {
        final service = UpdateService(
          currentVersion: '0.2.0+4',
          platform: UpdatePlatform.android,
          manifestUri: Uri.parse(
            'http://${server.address.address}:${server.port}/update-manifest.json',
          ),
        );

        await expectLater(
          service.checkForUpdate(),
          throwsA(
            isA<UpdateException>().having(
              (error) => error.userMessage,
              'userMessage',
              '当前还没有可用的稳定更新。',
            ),
          ),
        );
      } finally {
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
'''
head, sep, tail = text.rpartition(marker)
if not sep:
    raise SystemExit("update_service_test.dart: final brace not found")
service_test.write_text(head + insert + marker + tail, encoding="utf-8")
