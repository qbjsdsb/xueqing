# 学情闭环 Xueqing

> 面向教培机构的教学协作与学生成长闭环系统

## 当前状态

**Phase 0B.0 pilot hardening｜邀请接管、软件更新与生产运行边界验证**

Foundation v0.3 的产品边界、核心数据模型、Auth / 权限、安全、本地存储、零成本云端开发、恢复与运行风险已完成正式开发前审计。

`main` 的本次收口基线为 `c311927`（GitHub 实时 HEAD 以 `main` 为准）：PR #53（成员开通异常恢复）、PR #58（服务端权威 Case reopen）和 PR #54（按已验证 tag commit 构建发布包）已合并。图片附件 PR #51 已重基到该主线并补上会话切换保护、同一附件 ID 重试与 public RPC 安全边界；在 Android / Windows 真实设备 gate 完成前不合入 `main`。仓库按零成本 CI 决策保持公开，本阶段继续使用虚构数据，不承载真实学生、家长或教师隐私材料。

当前开发线已经包含：

- Flutter Windows + Android 工程、typed environment config、App bootstrap、Material 3 theme、响应式布局和系统暗色模式；
- Supabase Auth、OS secure storage session、live-session / membership / role / 学科与学生分配边界；
- Student、Learning Case、Evidence、Intervention、Assessment、Next Action 的教师工作台闭环；
- 机构自定义问题类型：管理员创建、改名、归档；新 Case 使用活动类型，历史 Case 保留标签快照；
- 加载、空状态、网络失败、重试、账号切换隔离和错误日志兜底；
- Local migration / RLS 测试、轻量 CI，以及 Remote Development 的真实 Data API smoke evidence。

### 当前执行证据（2026-09-06）

以当前仓库和远端开发项目的实时状态为准：

- 文档同步前的 `main` 收口基线为 `c311927`；已包含 PR #53 的成员开通异常恢复、PR #58 的服务端权威 Case reopen，以及 PR #54 的 tag commit 不可变发布构建校验。
- `xueqing-dev`（ap-southeast-1）已应用 `phase_0b_0_z_member_provisioning`；`organization-member-credentials` Edge Function v2 已部署并保持 `verify_jwt=true`。
- PR #51 已重基为集成分支并通过代码审计：上传中账号切换会中止，失败重试复用同一 attachment ID；其自动化 CI 需通过，Android / Windows 真实设备 gate 仍未在本环境执行。旧的堆叠 Draft PR #20–#45 已关闭，原分支保留用于追溯。
- 仓库保持公开是当前零成本 CI 的明确选择；公开期间不得提交 service key、访问令牌、真实学生 / 家长 / 教师资料或可回溯的敏感导出。
- 当前所有远端数据仍为虚构开发数据；未发布正式安装包，也未开启 Production 数据承载。

当前 Android / Windows 包只连接虚构的 Remote Development；它们不是 Production 包，也不代表真实数据上线许可。
### Production 边界仍未开放

P0 Gate A / B 的身份可移植性与撤销 Session / 旧 token spike 证据已经存在，但这只证明开发验证范围内的风险被测试过，不等于 Production provider、业务 migration 或真实数据上线获批。

- 成员接管与异常恢复已经合并（PR #50 / #53）；软件内更新已在主线，PR #54 进一步要求 release workflow checkout 已验证的 tag commit。
- PR #50 / #53 的 migration / Edge Function 只部署到虚构的 xueqing-dev，不包含 Production schema、真实 Auth 用户开通或真实数据授权。
- 图片附件仍是独立的真实设备 gate：必须用虚构账号和非敏感图片验证拍照/选图、上传、签名预览、失败重试、跨机构拒绝与 closed Case 拒绝后，才允许合入主线。
- Release 构建必须显式声明 XUEQING_ENV；Production 还必须使用 HTTPS，并把 URL host 放进精确的 XUEQING_SUPABASE_ALLOWED_HOSTS，不接受通配符。开发 release 必须显式设置 XUEQING_ALLOW_DEVELOPMENT_RELEASE=true。
- leaked password protection、SECURITY DEFINER 逐函数复核、intentional no-policy 表说明、迁移 drift、真实设备 / 网络、备份恢复和 Go / No-Go 仍待完成。
- Production provider、region、identity/session strategy、signing、正式发布渠道和升级兼容窗口仍未最终冻结。
- Realtime、家校端、报告、AI 正式诊断、复杂 offline-first / CRDT 等不属于当前迭代。

> 在 Phase 0 的权限、安全、恢复、网络与合规 Go / No-Go 通过前，只允许使用虚构或严格脱敏数据，不录入真实学生、家长或教师隐私材料。

> **Phase 0B.0 provider / production hard boundary**
>
> P0 Gate A / B 的 compatibility/security spike 已在虚构开发数据上完成，并已形成身份、旧 token 和 live-session 回归证据；它们不是无条件的 Production migration 授权。
>
> 在 provider、region、identity 与 session strategy 最终冻结，并完成远端安全处置、备份恢复、真实设备 / 网络验收和 Go / No-Go 之前，仍不得承载真实学生、教师或家长数据。
---

## 一句话定位

**不是把 Excel 搬进软件，而是让机构把“发现问题 → 干预 → 验证 → 下一步”变成多人共享、可追溯、低负担的日常教学闭环。**

系统始终回答三个问题：
1. 学生现在最需要解决什么？
2. 老师下一步做什么？
3. 前一次教学是否有证据证明有效？

---

## V1 教师端

只做 4 个核心入口：
- **今日**：到期 / 逾期行动、待验证、重点事项；
- **学生**：连续主档案、当前重点、时间线；
- **课程**：快速开始 / 完成真实教学记录；
- **学情**：Case、Evidence、Intervention、Assessment、Next Action。

家校和报告进入 V1.1。

V1 不做收费 / 课消 / 招生 CRM、完整排课、大型题库、成绩预测、学情健康分、家长 / 学生独立 App、AI 自动正式诊断、复杂 offline-first / CRDT。

---

## 学情 Case

```text
new → confirmed → intervening → pending_verification → stable → closed
```

- `new`：课堂 10–20 秒快速捕捉；
- `reopen`：受控命令 / 事件，不是第七个状态；
- assessment passed 不自动等于 stable / closed。

### 正式 Case 永远有下一步

- `new` 可以没有 action；
- `confirmed / intervening / pending_verification / stable` **必须始终有一个 pending primary action**；
- 暂缓 / 观察使用 `review` primary action；该 review 必须有 `due_at`；
- `pause_reason` 只解释原因，不代替下一步；
- `closed` 不存在 pending primary action。

这样问题不会因为“先观察”永久从 Today 消失。

---

## 一份连续学生主档案

同一机构，一个真实学生只有一个 Student。

升年级、换老师、换班 / 校区都保存历史：
- `student_enrollments`
- `student_teacher_assignments`
- `student_staff_assignments`

任课教师关系与班主任 / 学管关系分开，不用一个 teacher_id 覆盖历史。

---

## 时间与“今日”

系统事件时间保存 UTC；机构业务日期由 `organizations.time_zone`（IANA timezone，例如 `Asia/Shanghai`）统一解释。

以下都按机构时区计算，而不是相信教师手机 / 电脑当前时区：
- Today；
- action 到期 / 逾期；
- lesson 属于哪一天；
- 周度 / 阶段统计；
- report period。

V1 暂不做 campus 独立时区。

---

## V1 账号与权限

为了保持零额外付费，V1 不把 SMTP / Email OTP / SMS / 域名作为登录硬依赖。

```text
org_admin provision_member
    ↓
Auth User + membership(onboarding)
    ↓
强随机临时密码 + onboarding_expires_at
    ↓
教师登录，只能进入账号接管
    ↓
设置自己的新密码
    ↓
global sign-out 全部 Sessions
    ↓
membership active
    ↓
强制用新密码重新登录
```

普通学生业务授权还要求：

```text
JWT user
+ JWT session_id 仍对应 live auth.sessions
+ membership = active
+ organization
+ role / capability
+ student / subject assignment（如需要）
```

因此被撤销的旧 Access Token 即使自身尚未到 `exp`，也不能继续读取学生业务数据。

reset 必须**先 membership → onboarding，再更新 Auth 临时密码**。

临时密码：强随机、短有效期、只显示一次、不进 DB / log / audit / GitHub；如果成功响应丢失，不找回旧明文，而是 reissue 新凭据。

### V1 身份边界

数据库支持多个 organization，但同一个 Auth User 在 V1 同一时点最多一个 `onboarding / active` membership。未来若确需跨机构同账号，再先升级为中央身份恢复 / OTP / SSO 等不会让单一机构管理员控制全局 credential 的方案。

详见 `docs/AUTH_AND_PERMISSIONS.md`。

---

## 客户端本地安全

### Session
未来 gated Production 不能把候选 provider 的默认 `supabase_flutter` Session 持久化直接当最终安全方案；若选择 Supabase，须使用 custom `LocalStorage` + Windows / Android OS secure storage。Password 永不本地保存；provider/identity/session strategy 仍须先过 P0 Gate A/B。

### Startup Gate
只有在 Session validity / refresh、live Session、active membership、current organization 全部解析后，App 才挂载业务 Shell；失效 Session 不得先闪现学生页面。

### Draft
需要跨重启恢复的敏感草稿：
- encrypted at rest；
- key 在 OS secure storage；
- user / organization 隔离；
- TTL；
- sync 成功后删除；
- logout / account switch / disabled 有明确清理；
- 不存 Password / Token。

本地草稿只用于防止老师白填，不是第二份正式数据库。

---

## 总体技术方向

```text
Windows / Android Flutter
        │
        ├─ Secure Session Storage
        ├─ Encrypted Drafts
        └─ Startup Authorization Gate
                │
                ▼
Supabase Auth + Data API + Storage（V1 reference candidate；正式 Production 使用须先过 P0 Gate A/B）
                │
        live Session + RLS
                │
                ▼
PostgreSQL

高权限 / 跨系统：Edge Functions
数据库事务命令：Database Functions
GitHub：source / docs / migrations / tests / PR / CI（正式 migration 仅在 P0 Gate A/B 后）
```

Flutter 只持有客户端 Publishable Key。Secret / service_role / DB password / backup credential 不进入客户端或 GitHub。

V1 不在学生敏感业务表默认启用 Realtime，也不让业务正确性依赖 Realtime。

---

## 零额外付费开发

```text
ChatGPT Project + Work / Luna
→ Private GitHub + Free Actions
→ Supabase Local CLI（compatibility）
→ Free Remote Development（仅虚构数据的 compatibility/security Spike）
→ Gated Production Pilot（仅 P0 Gate A/B + Go/No-Go 后）
```

原则：
- 一个可验收目标通常一条 Work 会话 + 一个 branch / PR；
- GitHub 是源码事实源；
- migrations 是数据库结构事实源；
- Agent 没真实执行命令时必须明确“未执行 / 未验证”；
- Luna / Max 高推理优先 RLS、migration、Auth / Session、事务、并发、安全和 Milestone 终审；
- 机械 UI、改名、重复 CRUD 不无脑使用 Max；
- 包含额度用完等待重置，不购买 extra credits；
- Actions zero-overage budget 当前未设置，这是用户明确接受的账户级风险；
- 普通 PR 只跑轻量 Linux 检查，Windows / Android native build 只在 milestone / release / 手动执行；
- Work / Codex 禁止直推 main，使用 Draft PR + 执行证据 + 人工合并。

详见 `docs/ZERO_COST_CLOUD_DEVELOPMENT.md`。

---

## Region / 实际网络

Future gated Production region 不提前拍脑袋决定；region 选择也不能替代 P0 Gate A/B。

创建 Production 前必须用仅含虚构数据的 Remote Development，在真实机构场景测试：
- 机构 Wi-Fi；
- 普通移动网络；
- **无代理 / VPN**；
- Auth；
- Data API；
- Storage；
- Edge Functions；
- 网络切换与恢复。

不合格就换 Dev region 重测；结论稳定、P0 Gate A/B 通过且 provider/identity/session strategy 冻结后，才可创建 gated Production。真实未成年人数据的数据驻留 / 跨境合规另外评估；region 选择本身不是合规证明。

---

## 备份 / 恢复

Free Pilot 不把“有 SQL 文件”当成恢复能力。

完整恢复至少考虑：
- `roles.sql`
- `schema.sql`
- `data.sql`
- 必要 migration history
- Auth user / identity 按当时官方流程恢复并实际登录验证
- Storage objects + manifest
- Auth / Realtime / Extensions / Edge Functions / Secret 名单 / Project config checklist
- 加密 off-site backup
- **真实 restore drill**

若未来选择 Supabase，新的 gated Production Project 的 JWT / API 配置可能变化，旧 Token 不应被假定继续有效；恢复后重新登录是可接受的安全默认。

Pilot 默认目标 RPO ≤ 一个教学日；如果机构不能接受这个恢复点，0 元 Production 方案不合格，应重新评估基础设施。

详见 `docs/DISASTER_RECOVERY.md`。

---

## 开源经验

参考但不直接 fork：
- Flutter 官方 `flutter/samples/compass_app`：多环境、Repository / Service、测试；
- `supabase/supabase-flutter`：Local stack、测试、custom LocalStorage；
- AppFlowy：真实 Flutter 跨平台、隐私、发行；
- Frappe Education / Gibbon：教育实体、历史关系、角色、长期模块化。

只借模式和踩坑经验，不把 Xueqing 做成大型学校 ERP。

详见 `docs/OPEN_SOURCE_REFERENCES.md`。

---

## 文档导航

### 产品
- `docs/PRODUCT.md`
- `docs/USER_FLOWS.md`
- `docs/EXCEL_TO_PRODUCT.md`

### 架构 / 权限 / 数据
- `docs/ARCHITECTURE.md`
- `docs/AUTH_AND_PERMISSIONS.md`
- `docs/DATA_MODEL.md`
- `docs/COMMANDS_AND_INVARIANTS.md`
- `docs/DECISIONS.md`

### 安全 / 开发 / 运维
- `docs/SECURITY_AND_PRIVACY.md`
- `docs/RISKS_AND_OPERATIONS.md`
- `docs/DEVELOPMENT_WORKFLOW.md`
- `docs/RELEASING.md`
- `docs/REMOTE_DEVELOPMENT_RELEASE_CHECKLIST.md`
- `docs/ZERO_COST_CLOUD_DEVELOPMENT.md`
- `docs/DISASTER_RECOVERY.md`
- `docs/FOUNDATION_FINAL_AUDIT.md`
- `docs/PHASE0A_EXECUTION_RECORD.md`
- `docs/ROADMAP.md`
- `AGENTS.md`

### 外部经验
- `docs/OPEN_SOURCE_REFERENCES.md`

---

## 当前推进顺序

1. 完成 PR #51 集成分支的 Flutter / Supabase / Android / Windows build smoke，并在真实 Android / Windows 设备上验收图片附件；未通过前不把图片功能视为主线能力。
2. 用虚构账号完成完整验收矩阵：登录与启动门、邀请接管、权限隔离、学生交接、Case 全闭环与 reopen、图片、网络失败、软件更新、失败回滚和旧 Session 拒绝。
3. 基于“已验证 tag commit”构建并发布新的开发测试版；逐项核对版本、更新包、manifest/hash/size、Windows 安全解包、备份与回滚，不把未验证包当作自更新基线。
4. 记录 Android / Windows 设备型号、系统版本、构建 SHA、网络条件、测试账号和每条结果；所有账号与图片必须是虚构或非敏感数据。
5. 完成 DB / Auth / Storage recovery drill 与 Production Go / No-Go；在此之前不接入真实未成年人数据，也不扩展到 AI、家校和大型报表。

当前阶段的主要质量增量是可复核执行证据和完整人工闭环，而不是继续堆叠页面或复杂后台。

---
