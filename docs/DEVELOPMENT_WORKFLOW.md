# 开发、数据库与发布工作流

> 定义如何从新电脑开始开发、修改数据库、验证和发布，避免出现“某个人在 Dashboard 手工改过，所以别人无法复现”的隐性状态。

## 1. 三种环境语义

### Local Development
用于数据库结构、RLS、函数与自动化测试。

- Supabase CLI 本地 stack；
- 虚构数据；
- 可 reset / reseed；
- Local Mailpit 用于查看 Auth 邮件和 OTP 模板输出；
- 不承载真实机构数据。

### Remote Development
独立 Supabase Project，只用于虚构数据的真实集成验证：
- Windows + Android 同一云端数据；
- Email OTP 真实邮箱投递；
- OTP 错误/过期/限流；
- Session 恢复；
- invitation → membership；
- Storage；
- Edge Functions；
- 公网延迟和多设备。

它不是 schema 的第二事实源。

### Production
用于真实机构数据：
- 独立 Supabase Project；
- 独立数据库、Auth、Storage、Secret、SMTP；
- 不运行开发 seed/reset；
- schema 只通过已评审 migration 前进。

后期需要时再增加 Staging，不在 V1 为环境数量提前增加复杂度。

## 2. Supabase 目录是版本化基础设施

正式初始化后仓库应包含：

```text
supabase/
  config.toml
  migrations/
  seed.sql
  tests/
  functions/
```

提交：
- config.toml
- migrations
- 仅虚构 seed
- DB/RLS tests
- Edge Function 源码

不提交：
- CLI 临时状态
- Secret
- 本地缓存
- Production 数据

## 3. Schema 变更唯一正规路径

Schema / RLS / View / Function / Trigger / Index 正式变化都进入 migration。

```text
feature branch
  ↓
创建 migration
  ↓
local supabase db reset
  ↓
DB/RLS tests
  ↓
Flutter tests
  ↓
提交 migration + 代码 + 文档
  ↓
PR Review
  ↓
Remote Development 集成验证
  ↓
合并
  ↓
受控 Production 发布
```

禁止：
- 只在 Production Table Editor 改表；
- 只在远程 SQL Editor 修 policy；
- 让 Git schema 与 Remote Development 长期分叉。

## 4. 本地数据库验收

数据库相关 PR 至少验证：
1. 干净状态运行 migrations；
2. 加载虚构 seed；
3. DB tests；
4. RLS 正向与负向测试；
5. 从空库可重复重建当前 schema。

负面权限至少包括：未登录、只有 Auth User 无 membership、pending invitation、disabled membership、跨机构、无 assignment、其他学科。

## 5. Local Auth / Mailpit

Local Supabase 用 Mailpit 检查 Auth 邮件，不需要真实 SMTP。

Email OTP 开发要求：
- passwordless email template 输出 `{{ .Token }}` 验证码，而不是把 Magic Link 当作 V1 主流程；
- 测试新用户创建/已有用户登录；
- 测试错误/过期 OTP；
- 测试仅 Auth User 没有 membership 时无法读业务数据；
- invitation 接受逻辑独立于邮件发送本身。

Local 环境验证逻辑正确，Remote Development 再验证真实邮箱投递体验。

## 6. Remote Development OTP 测试矩阵

| 场景 | Windows | Android |
|---|---|---|
| 新邮箱 OTP 登录 | 必测 | 必测 |
| 已有 Auth User OTP 登录 | 必测 | 必测 |
| 错误验证码 | 必测 | 必测 |
| 过期验证码 | 必测 | 必测 |
| 高频请求/429 | 必测 | 必测 |
| Session 恢复 | 必测 | 必测 |
| 无 invitation/membership | 必测 | 必测 |
| pending invitation 接受 | 必测 | 必测 |
| 同一账号第二机构 invitation | 集成测试 | 集成测试 |
| membership disabled 后旧 Session | 必测 | 必测 |

V1 不以 Magic Link/deep link/password recovery 为核心登录流程，因此不要为这些路径提前引入平台复杂度。

## 7. Production 邮件与防滥用

Email OTP 是 Production 登录基础设施的一部分。

真实数据上线前必须：
- 配置可靠 Custom SMTP 或等价邮件服务；
- 不依赖 Supabase 默认 best-effort 邮件服务承担机构关键登录；
- 配置合理 Auth rate limits；
- 根据实际暴露程度配置 CAPTCHA 或等价滥用防护；
- 测试主要教师邮箱域名的投递、垃圾箱、延迟；
- 准备“验证码迟迟未到”的支持说明。

SMTP / 邮件服务 Secret 只在受信任服务端配置，不进入 Flutter/GitHub。

## 8. Flutter 配置

使用 typed AppConfig：

```text
appEnvironment
supabaseUrl
supabasePublishableKey
appVersion
buildNumber
```

Publishable Key 本来就是客户端公开凭据；安全来自 RLS、GRANT 和业务授权。

永远不能打进客户端：
- Supabase Secret/service_role
- 数据库密码
- SMTP Secret
- AI/第三方私钥

## 9. 依赖版本

正式 Flutter 初始化后提交：
- `pubspec.yaml`
- `pubspec.lock`

CI 固定明确 Flutter stable 版本。

依赖升级单独 PR：查看 breaking changes → 更新 lockfile → analyze/test/integration → 再进入 Production。

## 10. Database Push 规则

### Remote Development
- review/dry-run 待应用 migrations；
- push；
- 仅使用虚构 seed；
- 临时远程实验最终回写 migration。

### Production
- 只部署已通过 PR 与测试的 migration；
- 发布前再次确认 project/environment；
- destructive migration 有迁移与恢复方案；
- 禁止 reset；
- 发布后 smoke test。

## 11. Production smoke test

涉及 schema/Auth/权限的发布至少验证：
- org_admin Email OTP 登录；
- 普通教师 Email OTP 登录；
- 无 membership 测试账号读不到业务数据；
- 教师能看到授权学生；
- 教师看不到未授权学生；
- 跨机构失败；
- invitation → membership 受控流程正常；
- 一条专用测试业务记录可正常创建；
- 日志无 Secret/Token/学生敏感正文。

Production smoke test 使用专用测试账号/测试数据，不拿真实学生数据做调试样本。

## 12. 回滚与兼容

数据库发布优先向前修复，不假定 migration 都能安全逆向。

发布前回答：
- migration 是否 destructive；
- 旧客户端是否还能工作；
- 失败时前一 App 版本能否继续；
- 是否需提前备份；
- 是否需 expand → migrate → contract。

删除列、重命名核心字段、改变状态语义等高风险变化不一步破坏旧客户端。

## 13. Git 与 PR

建议：

```text
main
  ├─ feature/*
  ├─ fix/*
  └─ review/*
```

`main` 代表认可基线。

PR 至少说明：
- 解决什么用户问题；
- schema/RLS/Auth 是否变化；
- 是否触及敏感数据；
- 测试结果；
- 风险与恢复。

使用 `.github/pull_request_template.md`。

## 14. 一键重建目标

Phase 0 结束时，新开发环境应能：

```text
clone
  ↓
安装指定 Flutter / Supabase CLI / Docker-compatible runtime
  ↓
supabase start
  ↓
supabase db reset
  ↓
虚构 seed + DB/RLS tests
  ↓
flutter pub get
  ↓
flutter analyze
  ↓
flutter test
  ↓
运行 App
```

如果还依赖“某个人记得在 Dashboard 手工配了什么”，Foundation 就没有真正完成。