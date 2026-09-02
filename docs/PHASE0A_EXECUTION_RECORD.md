# Phase 0A｜执行记录

> 本记录只收录实际检查结果。无法在当前环境执行的项目不会标记为通过。

## Scope

- 目标分支：`phase0/flutter-bootstrap`；不创建同名分支，不直接 push `main`。
- 目标 PR：Draft PR #4；目标 Issue：#3。
- `main` Foundation 基线：`e467bb3777d92c2068e4d95582cabc0cbd30d06a`。
- 本轮只建立 Flutter 工程、平台骨架、启动链路、基础 UI 能力、测试与 CI；没有实现 Supabase、Auth 或正式业务页面。

## Project decisions

- Dart package：`xueqing`。
- Android namespace / application id：`com.xueqing.app`。
- 路由：Flutter SDK 内置 `MaterialApp.onGenerateRoute`；当前范围不增加 `go_router`。
- 环境配置：`--dart-define=XUEQING_ENV=development|production` 与 `XUEQING_APP_VERSION`，不包含服务端 Secret。
- CI Flutter 版本基线：`3.47.1`；当前云端没有 Flutter SDK，因此该版本没有在本地探针中声称已安装。

## Environment probe｜2026-09-02 UTC

| Check | Evidence | Result |
| --- | --- | --- |
| `flutter --version` | `/bin/bash: flutter: command not found` | **FAIL / EXECUTED** |
| `dart --version` | `/bin/bash: dart: command not found` | **FAIL / EXECUTED** |
| `flutter doctor -v` | `/bin/bash: flutter: command not found` | **FAIL / EXECUTED** |
| `java -version` | OpenJDK `17.0.20` | **PASS / EXECUTED** |
| `gradle --version` | `/bin/bash: gradle: command not found` | **FAIL / EXECUTED** |
| `adb version` | `/bin/bash: adb: command not found` | **FAIL / EXECUTED** |
| `sdkmanager --version` | `/bin/bash: sdkmanager: command not found` | **FAIL / EXECUTED** |
| `cmake --version` | `/bin/bash: cmake: command not found` | **FAIL / EXECUTED** |
| Host | Linux `x86_64`, not Windows | **REVIEWED ONLY** |

## Requested Flutter checks

| Command | Result | Root cause |
| --- | --- | --- |
| `flutter pub get` | **FAIL / EXECUTED** | Flutter executable unavailable; no package resolution was attempted. |
| `dart format --output=none --set-exit-if-changed .` | **FAIL / EXECUTED** | Dart executable unavailable. |
| `flutter analyze` | **FAIL / EXECUTED** | Flutter executable unavailable. |
| `flutter test` | **FAIL / EXECUTED** | Flutter executable unavailable. |

## Platform verification

- Android debug build command attempt (`flutter build apk --debug`)：**FAIL / EXECUTED**；command returned `flutter: command not found`. Actual Android build：**NOT RUN / ENVIRONMENT UNAVAILABLE**，因为 Flutter executable、Android SDK 与 `adb` 均缺失；这不是项目级 build diagnosis。
- Windows build：**NOT RUN / ENVIRONMENT UNAVAILABLE**；当前 host 不是 Windows，且没有 MSVC / CMake / Windows Flutter toolchain。
- Windows `CMakeLists.txt`、runner、manifest 与官方 stable 模板结构：**REVIEWED ONLY**。
- GitHub Actions PR run `33603964885`（head `2bd7f0c942a3bc6ecdb192b89df53268bb8d6292`）：**PASS / EXECUTED**；Flutter setup、`flutter pub get`、Dart format、`flutter analyze` 与 `flutter test` 全部成功。此前 run `33603316131` 的 6 个分析问题已在提交 `0520358dd883b992d84d3909fee3d605367df3eb` 修复。

## Security and boundaries

- 没有提交 Secret、token、password、service_role、DB password、API key 或 production credential。
- 没有提交真实学生、家长或教师数据，也没有从 Excel 原型导入数据。
- 没有创建 `supabase/migrations`、数据库表、RLS policy、Storage bucket、Edge Function 或 Auth onboarding。
- 没有创建 Student、Learning Case、Evidence、Intervention、Assessment、Lesson、Today、Dashboard 或 AI 页面。

## Follow-up

在具备 Flutter/Android/Windows 工具链的环境中重跑上述命令并把真实结果补入 PR #4；本记录不把静态审查替代为构建证据。
