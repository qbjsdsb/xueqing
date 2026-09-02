# Phase 0A｜Flutter Bootstrap 执行任务书

> 对应 Issue #3。目标是把 Foundation 占位仓库转换为真正可构建、可测试、可继续演进的 Flutter Windows + Android 工程。

## 1. 执行前必读

按顺序阅读：
1. `AGENTS.md`
2. `docs/FOUNDATION_FINAL_AUDIT.md`
3. `docs/ARCHITECTURE.md`
4. `docs/DEVELOPMENT_WORKFLOW.md`
5. `docs/ROADMAP.md`
6. Issue #3

若本文与已接受 ADR/AGENTS 冲突，以 AGENTS + 已接受 ADR 为准，并在 PR 中指出冲突；不要静默改方向。

## 2. 本阶段唯一目标

建立一个真正的 Flutter 工程基线，使后续后端与安全阶段可以在不返工 Flutter 外壳的前提下接入 Local Supabase。

本阶段不是做业务功能。

## 3. 必须完成

### Flutter 工程
- 使用当前稳定 Flutter toolchain；
- 正式生成/修复 Flutter project metadata；
- Windows + Android 平台文件完整；
- 包名 / application id 使用稳定、可长期沿用的值；
- 提交 `pubspec.lock`；
- 保留 Foundation 已有文档，不覆盖/丢失；
- 删除或迁移会与正式 `flutter create` 冲突的占位代码，但保留其表达的产品边界。

### 代码结构
保持轻量，不为 Clean Architecture 造空层。至少形成清晰职责：
- `app/`：App、router、theme、bootstrap；
- `features/`：按 feature 组织；
- data/service/repository/viewmodel 在需要时出现；
- Widget 中不散落未来 Supabase 查询或复杂业务规则。

Phase 0A 可以只有 Bootstrap/Placeholder UI，不要提前开发 Student / Case / Lesson / Today 正式页面。

### 环境配置
建立 typed configuration 的骨架，至少区分：
- development
- production

不得提交真实 URL、Secret、service_role、数据库密码或 Production credential。

Phase 0A 可以使用明显占位/编译期注入方式；Supabase 真正接入留到后续阶段。

### Router / Theme / Error handling
只建立最小可维护基线：
- App router；
- 全局 Theme；
- bootstrap/error/loading 的清晰边界；
- 不做复杂设计系统。

### 测试
至少建立：
- 一个基础 Widget/App smoke test；
- 对新增的纯逻辑组件有必要的 unit test；
- 测试不得依赖真实云服务。

### CI
建立精简、零额外付费取向的 GitHub Actions workflow：
- format check；
- analyze；
- unit/widget tests；
- 不在每个 commit 跑昂贵的双平台 release build；
- 不使用 larger runner；
- artifact 保留从简。

若 GitHub Free private runner/平台限制导致 Windows build 不适合作为每 PR 必跑项，记录原因，不为了“看起来完整”制造高成本 CI。

## 4. 明确禁止

Phase 0A 不做：
- Supabase schema / migrations / RLS；
- Auth/onboarding；
- Local secure Session 实现；
- encrypted student draft；
- 真实 Student / Learning Case / Lesson / Today 业务；
- 真实账号、学生、家长、教师隐私数据；
- Realtime；
- AI API；
- 付费 SaaS；
- 为未来需求提前造复杂抽象。

这些分别属于后续 Phase 0B 或业务 Milestone。

## 5. 必须真实执行的命令

只要当前环境具备能力，就真实执行并在 PR 记录版本/结果：

```bash
flutter --version
flutter doctor -v
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Android：
- 如果 Android SDK / JDK / toolchain 可用，真实执行至少一个可证明工程有效的 Android build；
- 如果环境缺能力，明确写“未执行”及具体缺口，不能写“应该可以”。

Windows：
- 如果任务运行在 Linux 云端，不得伪称执行了 Windows build；
- 可以检查 Windows runner/workflow 配置与工程文件，但必须区分静态审查和真实执行；
- 真正 Windows build 证据留给可用 Windows runner/环境。

## 6. 证据分级

PR 的每项结论必须属于以下一种：

- **PASS / executed**：命令真实执行并成功；
- **FAIL / executed**：命令真实执行并失败，附根因；
- **NOT RUN / environment unavailable**：环境缺能力，明确缺什么；
- **REVIEWED ONLY**：仅代码/配置静态审查，不能包装成执行成功。

禁止使用“看起来没问题”“理论上可运行”替代执行证据。

## 7. Git 工作方式

目标分支：`phase0/flutter-bootstrap`

要求：
- 不直接 push `main`；
- 所有 Phase 0A 变更只进入该分支；
- 完成后创建 Draft PR → `main`；
- PR 关联 Issue #3；
- 不混入 Local Supabase / Auth / 业务页面；
- 若发现 Foundation 真正存在硬错误，只做最小必要修正并在 PR 明确说明原因。

## 8. PR 最低内容

PR 正文至少包含：
1. 做了什么；
2. 为什么这样组织；
3. 哪些 Foundation 约束被遵守；
4. 文件/目录结构摘要；
5. 真实执行命令与结果；
6. Android build 状态；
7. Windows build 状态；
8. 已知限制；
9. Phase 0A.5 UX/UI Design Foundation 以及后续后端阶段的明确交接点；
10. “未执行”的检查清单。

## 9. 完成定义

只有同时满足以下条件，Phase 0A 才能视为完成：
- 正式 Flutter 工程结构存在；
- Windows + Android 平台文件存在；
- `pubspec.lock` 已提交；
- `flutter pub get` 成功；
- format/analyze/test 在可用环境中真实执行并通过；
- 至少 Android 或当前可用目标平台有真实 build 证据，无法执行的平台明确 NOT RUN；
- CI 基线存在且不过度消耗免费额度；
- 没有真实数据/Secret；
- README/必要 docs 已同步当前状态；
- Draft PR 已创建并关联 Issue #3；
- 没有提前实现 Phase 0B 及之后的功能。

完成后停止，不自动继续 Phase 0B；先等待 PR 审查/合并。

## 当前执行状态（2026-09-02）

Phase 0A 的工程源文件已经在既有 `phase0/flutter-bootstrap` 分支上补齐，并继续使用 Draft PR #4。当前云端 host 是 Linux，未安装 Flutter、Dart、Android SDK、Gradle、CMake 或 Windows toolchain；JDK 17 可用。因此以下执行证据必须保持区分：

- `flutter --version`、`dart --version`、`flutter doctor -v`：**FAIL / EXECUTED**，命令返回 `command not found`；
- `flutter pub get`、format、analyze、test：**FAIL / EXECUTED**，命令返回 `flutter/dart: command not found`；
- Android debug build：**FAIL / EXECUTED**，Flutter executable 与 Android SDK 缺失；
- Windows build：**NOT RUN / ENVIRONMENT UNAVAILABLE**；Windows runner 仅做 **REVIEWED ONLY** 静态审查。
- GitHub Actions PR run `33603964885`：**PASS / EXECUTED**，Flutter setup、`flutter pub get`、format、analyze 与 test 全部成功。

详细结果见 `docs/PHASE0A_EXECUTION_RECORD.md`。这些环境限制不能被写成工程构建通过。
