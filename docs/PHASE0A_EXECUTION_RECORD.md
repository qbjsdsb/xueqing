# Phase 0A｜执行记录

> 本记录只收录实际检查结果。区分本次 Work 容器、本次 GitHub Actions runner 与静态审查；不得把一个环境的能力或失败冒充另一个环境的结论。

## Scope

- 目标分支：`phase0/flutter-bootstrap`；不直接 push `main`。
- 目标 PR：Draft PR #4；目标 Issue：#3。
- `main` Foundation 基线：`e467bb3777d92c2068e4d95582cabc0cbd30d06a`。
- 本轮只建立 Flutter 工程、Android / Windows 平台骨架、启动链路、基础 UI 能力、测试与 CI；没有实现 Supabase、Auth 或正式业务页面。

## Project decisions

- Dart package：`xueqing`。
- Android namespace / application id：`com.xueqing.app`。
- 路由：Flutter SDK 内置 `MaterialApp.onGenerateRoute`；当前范围不增加 `go_router`。
- 环境配置：`--dart-define=XUEQING_ENV=development|production` 与 `XUEQING_APP_VERSION`，不包含服务端 Secret。
- Flutter / CI 基线：Flutter `3.47.1`、Dart `3.13.1`。
- 正式视觉尚未冻结；Theme / Shell / Responsive 只作为 Phase 0A.5 可替换基础。

## Work 容器探针｜2026-09-02 UTC

最初执行任务所在 Linux 容器没有 Flutter / Dart / Android SDK 等工具。这只说明**该容器**不能承担构建，不代表项目本身构建失败。

| Check | Evidence | Result |
| --- | --- | --- |
| `flutter --version` | `flutter: command not found` | **FAIL / EXECUTED（该容器）** |
| `dart --version` | `dart: command not found` | **FAIL / EXECUTED（该容器）** |
| `flutter doctor -v` | `flutter: command not found` | **FAIL / EXECUTED（该容器）** |
| `java -version` | OpenJDK `17.0.20` | **PASS / EXECUTED（该容器）** |
| `gradle --version` | command unavailable | **FAIL / EXECUTED（该容器）** |
| `adb version` | command unavailable | **FAIL / EXECUTED（该容器）** |
| `sdkmanager --version` | command unavailable | **FAIL / EXECUTED（该容器）** |
| `cmake --version` | command unavailable | **FAIL / EXECUTED（该容器）** |

因此最初在该容器中尝试的 `flutter pub get`、format、analyze、test 与 APK build 都不能作为项目级失败证据。

## GitHub Actions｜轻量 PR 验证

### 最终轻量 CI

GitHub Actions run `33606400363`：**PASS / EXECUTED**。

使用 Flutter `3.47.1`，实际通过：
- `flutter pub get`；
- `git diff --exit-code -- pubspec.lock`；
- `dart format --output=none --set-exit-if-changed .`；
- `flutter analyze`；
- `flutter test`。

此前 CI 曾真实发现 formatter 与 analyzer 问题，修复后才转绿；因此当前 green 是执行结果，不是静态推断。

CI 触发策略已在最终审计中收紧：
- 普通 PR：轻量 Linux format / lockfile / analyze / test；
- `main` push：同一轻量检查；
- 不再同时对 `phase0/flutter-bootstrap` push 与 PR 重复跑同一轻量 workflow。

## GitHub Actions｜Android 原生构建

平台验证 run：`33606216237`。

Android job：**PASS / EXECUTED**。

真实环境与结果：
- Ubuntu `24.04.4` GitHub-hosted runner；
- Flutter `3.47.1` stable；
- Dart `3.13.1`；
- Android SDK `37.0.0`；
- Java Temurin `17.0.20.1`；
- `flutter pub get` 成功；
- `flutter build apk --debug` 成功；
- 真实产物路径：`build/app/outputs/flutter-apk/app-debug.apk`。

`flutter doctor -v` 报告 runner 上仍有部分 Android licenses 未接受，但这没有阻止本次 debug APK 构建；该 runner 警告不应被误写成项目 build 失败。

## GitHub Actions｜Windows 原生构建

平台验证 run：`33606216237`。

Windows job：**PASS / EXECUTED**。

真实环境与结果：
- Microsoft Windows Server 2025 GitHub-hosted runner；
- Visual Studio Enterprise 2026 `18.9.1`；
- Windows SDK `10.0.26100.0`；
- Flutter `3.47.1` stable；
- Dart `3.13.1`；
- `flutter pub get` 成功；
- `flutter build windows --debug` 成功；
- 真实产物路径：`build\windows\x64\runner\Debug\xueqing.exe`。

因此 Windows 平台状态已从先前的 **REVIEWED ONLY / NOT RUN** 升级为 **PASS / EXECUTED**。

## Platform-build CI policy

完成本次 milestone 双平台验证后，`.github/workflows/phase0a-platform-builds.yml` 已改为 `workflow_dispatch` 手动触发。

原因：
- Android / Windows 原生 build 已获得 Phase 0A 真实证据；
- 普通 PR 不需要为每个 commit 重复消耗 native runner；
- 后续在 milestone / release / platform-sensitive 变更时再手动运行。

## Git tree 完整性事故与修正

本轮曾发生一次低层 Git Data API tree 写入错误，远端 tree 临时只保留少量路径。随后通过正确 parent/base tree 重建恢复。

最终审计再次读取 recursive tree：
- 返回 `truncated=false`；
- `AGENTS.md`、`.github/`、`docs/`、`lib/`、`test/`、`android/`、`windows/`、`pubspec.yaml`、`pubspec.lock` 等关键路径均存在。

该经验已经写入 `AGENTS.md`：以后低层 Git Data API 写入后必须重新读取 recursive tree 并检查关键路径，不能只以“commit 创建成功”作为远端完整性的证明。

## Security and scope boundaries

审计确认：
- 没有提交 Secret、token、password、service_role、DB password、API key 或 production credential；
- 没有提交真实学生、家长或教师业务数据，也没有导入 Excel 原型；
- 没有创建 Supabase migration / DB table / RLS / Storage bucket / Edge Function / Auth onboarding；
- 没有创建 Student、Learning Case、Evidence、Intervention、Assessment、Lesson、Today、Dashboard 或 AI 正式业务页面；
- Bootstrap UI 保持克制，只验证工程、环境、平台与路由状态；最终 UX/UI 留给 Phase 0A.5。

## 当前结论

Phase 0A 的关键工程证据现为：

| Item | Final result |
| --- | --- |
| Flutter project metadata | **PASS / REVIEWED + CI** |
| `flutter pub get` | **PASS / EXECUTED** |
| lockfile current | **PASS / EXECUTED** |
| format | **PASS / EXECUTED** |
| analyze | **PASS / EXECUTED** |
| tests | **PASS / EXECUTED** |
| Android debug build | **PASS / EXECUTED** |
| Windows debug build | **PASS / EXECUTED** |
| Supabase / Auth / RLS | **NOT IMPLEMENTED — intentionally out of scope** |
| Final UX/UI | **NOT DESIGNED — intentionally deferred to Phase 0A.5** |

Phase 0A 不再需要以“本地 Work 容器缺少工具链”为理由保留 Android / Windows build 未验证项。后续仍需在真实开发电脑 / 真机上做运行体验与设备级验证，但这属于后续开发与发行证据，不否定本轮原生 build 已通过。
