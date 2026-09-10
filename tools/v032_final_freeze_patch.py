import json
from pathlib import Path


NEW_VERSION = '0.3.2+10'
NEW_TAG = 'v0.3.2'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


def replace_count(text: str, old: str, new: str, expected: int, label: str) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{label}: expected {expected} matches, found {count}')
    return text.replace(old, new)


# 1. Freeze the application source version.
pubspec_path = Path('pubspec.yaml')
pubspec = pubspec_path.read_text(encoding='utf-8')
pubspec = replace_once(
    pubspec,
    'version: 0.3.1+9',
    f'version: {NEW_VERSION}',
    'pubspec release version',
)
pubspec_path.write_text(pubspec, encoding='utf-8')

# 2. Keep runtime defaults identical to pubspec so update comparison is truthful.
app_config_path = Path('lib/config/app_config.dart')
app_config = app_config_path.read_text(encoding='utf-8')
app_config = replace_count(
    app_config,
    "'0.3.1+9'",
    f"'{NEW_VERSION}'",
    2,
    'AppConfig release defaults',
)
app_config_path.write_text(app_config, encoding='utf-8')

# 3. Repair AppVersion equality/hashCode contract for prerelease versions.
models_path = Path('lib/update/update_models.dart')
models = models_path.read_text(encoding='utf-8')
models = replace_once(
    models,
    '  int get hashCode => Object.hash(major, minor, patch, build, prerelease);',
    '  int get hashCode => Object.hash(\n'
    '    major,\n'
    '    minor,\n'
    '    patch,\n'
    '    build,\n'
    '    Object.hashAll(prerelease),\n'
    '  );',
    'AppVersion structural hashCode',
)
models_path.write_text(models, encoding='utf-8')

# 4. Add a regression proving equal versions are safe as hash keys.
update_test_path = Path('test/update/update_service_test.dart')
update_tests = update_test_path.read_text(encoding='utf-8')
marker = "  test('rejects malformed artifact security fields', () {\n"
new_test = """  test('equal parsed versions have identical structural hash codes', () {
    final left = AppVersion.parse('1.2.3-beta.2+4');
    final right = AppVersion.parse('1.2.3-beta.2+4');

    expect(left, right);
    expect(left.hashCode, right.hashCode);
    expect(<AppVersion>{left, right}, hasLength(1));
  });

"""
if new_test.strip() in update_tests:
    raise SystemExit('AppVersion hash regression already exists')
update_tests = replace_once(
    update_tests,
    marker,
    new_test + marker,
    'AppVersion hash regression insertion point',
)
update_test_path.write_text(update_tests, encoding='utf-8')

# 5. Keep the production host fixture aligned with the frozen release version.
workspace_page_test_path = Path('test/features/design_v2_workspace_page_test.dart')
workspace_page_test = workspace_page_test_path.read_text(encoding='utf-8')
workspace_page_test = replace_count(
    workspace_page_test,
    "'0.3.1+9'",
    f"'{NEW_VERSION}'",
    2,
    'workspace page release fixtures',
)
workspace_page_test_path.write_text(workspace_page_test, encoding='utf-8')

# 6. Refresh the checked-in manifest example so it cannot teach stale release values.
manifest_path = Path('docs/update-manifest.example.json')
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
if manifest.get('version') != '0.3.1+9':
    raise SystemExit(f"manifest example: unexpected source version {manifest.get('version')!r}")
manifest['version'] = NEW_VERSION
manifest['notes'] = [
    '修复 Android 系统返回与侧滑返回层级，避免在二级工作区直接退出应用',
    '完善学员资料编辑与年级历史连续性',
    '强化更新下载进度、Windows 安装更新与发布回归验证',
]
platforms = manifest.get('platforms')
if not isinstance(platforms, dict):
    raise SystemExit('manifest example: platforms is missing')
for platform, extension in [('windows', 'windows.zip'), ('android', 'android.apk')]:
    artifact = platforms.get(platform)
    if not isinstance(artifact, dict):
        raise SystemExit(f'manifest example: missing {platform} artifact')
    old_name = f'xueqing-v0.3.1-{extension}'
    new_name = f'xueqing-{NEW_TAG}-{extension}'
    expected_old_url = f'https://github.com/qbjsdsb/xueqing/releases/download/v0.3.1/{old_name}'
    if artifact.get('url') != expected_old_url or artifact.get('file_name') != old_name:
        raise SystemExit(f'manifest example: unexpected {platform} v0.3.1 artifact contract')
    artifact['url'] = f'https://github.com/qbjsdsb/xueqing/releases/download/{NEW_TAG}/{new_name}'
    artifact['file_name'] = new_name
manifest_path.write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + '\n',
    encoding='utf-8',
)

# 7. Make the stable publishing workflow default to this frozen release instead of v0.3.1.
publish_path = Path('.github/workflows/publish-release-assets.yml')
publish = publish_path.read_text(encoding='utf-8')
publish = replace_once(
    publish,
    'description: "Existing published Pre-release staging tag, for example v0.3.1"',
    'description: "Existing published Pre-release staging tag, for example v0.3.2"',
    'release tag description',
)
publish = replace_once(
    publish,
    'default: v0.3.1',
    f'default: {NEW_TAG}',
    'release tag default',
)
publish = replace_once(
    publish,
    'description: "Stable semantic app version including Android build, for example 0.3.1+9"',
    'description: "Stable semantic app version including Android build, for example 0.3.2+10"',
    'release version description',
)
publish = replace_once(
    publish,
    'default: 0.3.1+9',
    f'default: {NEW_VERSION}',
    'release version default',
)
publish = replace_once(
    publish,
    'default: "稳定性与更新流程改进"',
    'default: "修复 Android 返回层级；完善学员资料编辑与年级历史；强化更新与安装可靠性"',
    'release notes default',
)
publish_path.write_text(publish, encoding='utf-8')
