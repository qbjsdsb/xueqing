# 开发、数据库与发布工作流

> 本文件定义项目如何从一台新电脑开始开发、如何修改数据库、如何验证、如何部署。目标是避免“某个人在 Dashboard 点了几下，别人和 CI 都复现不了”的隐性状态。

## 1. 环境模型

至少维护两个完全独立环境：

### Local / Development
用于开发与自动化测试。

- 本地 Supabase CLI stack：数据库 schema 与 RLS 的主要开发/测试场；
- Remote Development Supabase Project：双设备联调、真实 Auth 邮件/深链、远程网络和 Storage 集成测试；
- 数据全部虚构；
- 允许 reset、重新 seed。

### Production
用于真实机构数据。

- 独立 Supabase Project；
- 独立数据库、Storage、Auth、Secret；
- 不运行开发 seed；
- 不执行用于清空测试环境的 reset；
- schema 只通过已经评审的 migration 前进。

后期需要更严格发布流程时再增加 Staging，不在 V1 为环境数量而增加复杂度。

## 2. Supabase 目录是版本化基础设施

正式初始化后，仓库应包含：

```text
supabase/
  config.toml
  migrations/
  seed.sql
  tests/
  functions/
```

原则：

- `config.toml`：提交；
- `migrations/`：提交；
- `seed.sql`：只放虚构开发数据并提交；
- 数据库/RLS 测试：提交；
- Edge Functions 源码：提交；
- CLI 临时状态、Secret、本地缓存：不提交。

## 3. Schema 变更唯一正规路径

一旦 migration 工作流建立，所有 schema / RLS / View / Function / index / trigger 变化都进入 migration。

推荐循环：

```text
新建 feature branch
  ↓
创建 migration
  ↓
本地 supabase db reset
  ↓
运行 DB/RLS tests
  ↓
Flutter tests / integration tests
  ↓
提交 migration + 代码 + 文档
  ↓
PR Review
  ↓
部署到 Remote Development 验证
  ↓
合并
  ↓
受控发布 Production
```

禁止：

- 只在 Production Dashboard Table Editor 改表；
- 只在远程 SQL Editor 修 policy 而不回写 migration；
- 为了“先跑通”让远程 schema 和 Git migration 历史长期分叉。

## 4. 本地数据库验收

每个涉及数据库的 PR 至少执行：

1. 从干净状态运行 migrations；
2. 加载虚构 seed；
3. 运行数据库测试；
4. 验证跨机构负面权限；
5. 验证 migration 能重复从空库重建当前 schema。

重要：测试不能只验证“管理员能成功”，还必须验证未登录、disabled、跨机构、无 assignment、其他学科等请求被拒绝。

## 5. Remote Development 的职责

Remote Development 不是 schema 的第二事实源，它用于本地难以完整覆盖的集成场景：

- Android + Windows 同一云端数据互通；
- Auth 邮件邀请/重置密码；
- redirect URL / deep link；
- Remote Storage；
- Edge Functions；
- 真实公网延迟与错误；
- 多设备 Session。

如果在远程开发项目临时试验了 schema，最终必须转回 migration 并重新验证。

## 6. Auth 回跳测试矩阵

邮件邀请、密码恢复等依赖 redirect 的流程必须在 Remote Development 真测。

至少覆盖：

| 场景 | Windows | Android |
|---|---|---|
| 新用户首次邀请 | 必测 | 必测 |
| 邀请过期后重发 | 必测 | 必测 |
| 密码恢复 | 必测 | 必测 |
| App 已安装 | 必测 | 必测 |
| App 未运行 | 必测 | 必测 |
| redirect 不在 allowlist | 明确失败表现 | 明确失败表现 |

`redirectTo` 必须存在于 Supabase Auth 的允许 Redirect URL 配置中。不能假定服务端传了 redirect 参数就一定按预期返回 App。

## 7. Flutter 配置

Flutter 使用 typed AppConfig，至少明确：

```text
appEnvironment
supabaseUrl
supabasePublishableKey
appVersion / buildNumber
```

Publishable Key 是公开客户端凭据，不需要假装加密隐藏；真正的安全来自 RLS 与最小 GRANT。

以下永远不能通过 `--dart-define` 打进客户端：

- Supabase Secret Key / service_role；
- 数据库密码；
- AI Secret；
- SMTP / 邮件服务 Secret；
- 其他第三方私钥。

## 8. 依赖版本

这是应用项目，因此正式 Flutter 初始化后提交：

- `pubspec.yaml`；
- `pubspec.lock`。

CI 使用明确的 Flutter stable 版本，不依赖“runner 当前碰巧是什么版本”。

依赖升级单独 PR：

1. 查看 breaking changes；
2. 更新 lockfile；
3. 跑 analyze/test/integration；
4. 不与无关业务重构混在同一个 PR。

## 9. Database Push 规则

对 Remote Development：

- 先 dry-run / review 将应用的 migration；
- 再 push；
- seed 仅用于开发环境。

对 Production：

- 只部署已通过 PR 与测试的 migration；
- 发布前确认目标 project；
- 破坏性 migration 必须有数据迁移/恢复方案；
- 不使用会清空真实数据的 reset 工作流；
- 发布后执行 smoke test。

## 10. Production smoke test

每次涉及 schema/Auth/权限的 Production 发布至少验证：

- 管理员可登录；
- 普通教师可登录；
- 教师能看到本人授权学生；
- 教师看不到未授权学生；
- 跨机构请求失败；
- 新建一条测试业务记录的受控流程正常；
- 无 Secret / Token 出现在日志。

真实生产 smoke test 应使用专用测试账号/测试数据，不拿真实学生数据做调试样本。

## 11. 回滚思路

数据库发布优先采用“向前修复”，不假定所有 migration 都能安全逆向。

发布前必须回答：

- 这次 migration 是否 destructive？
- 旧客户端是否还能工作？
- 如果部署失败，能否用前一 App 版本继续？
- 数据是否需要提前备份？
- 是否需要分两阶段迁移（先加新结构，再切换，再清旧结构）？

涉及删除列、重命名核心字段、改变枚举/状态等高风险变化时，优先采用 expand → migrate → contract，而不是一步破坏旧客户端。

## 12. Git 分支与 PR

建议：

```text
main
  └─ feature/*
  └─ fix/*
  └─ review/*
```

`main` 代表当前认可基线。

较大功能通过 PR 合并，PR 至少说明：

- 解决什么用户问题；
- schema 是否变化；
- RLS 是否变化；
- 是否触及敏感数据；
- 测试结果；
- 回滚/恢复考虑。

## 13. 开发环境的一键重建目标

Phase 0 结束时，一名新开发者/Codex 环境应能根据仓库说明完成：

```text
clone repository
  ↓
安装指定 Flutter / Supabase CLI / Docker-compatible runtime
  ↓
supabase start
  ↓
supabase db reset
  ↓
加载虚构数据
  ↓
flutter pub get
  ↓
flutter analyze
  ↓
flutter test
  ↓
运行 App
```

如果项目依赖“某个人记得在 Dashboard 手工配置了什么”，说明工程底座还没有真正完成。
