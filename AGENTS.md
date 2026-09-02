# AGENTS.md# Provider / production boundary

> **Phase 0B.0 provider / production hard boundary**
>
> 当前仅将 Supabase 视为 V1 reference / preferred implementation candidate；尚未无条件冻结为 production provider。正式 production business migrations、Production Auth/RLS/CRUD 与真实学生/教师/家长数据之前，必须先完成并通过：
> 1. **P0 Gate A — Auth Identity Portability Spike**；
> 2. **P0 Gate B — Revoked Session / Old Token Security Spike**。
>
> 在两项 Gate 之前，只允许用虚构数据进行 provider-specific compatibility/security spike；Spike 不构成 production migration 授权。两 Gate 通过后，才可冻结 provider、region、identity 与 session strategy，再另行执行正式 migrations、Auth/RLS/CRUD 与 Go/No-Go。


本文件是 ChatGPT Work、Codex 与后续开发者的**硬约束索引**。详细语义以 `docs/` 对应专题和已接受 ADR 为准。不得在代码中静默改方向。

## 1. 优先级

1. 数据正确与权限安全
2. 学生历史连续
3. 教师高频流程低负担
4. 保存 / 恢复可靠
5. 可追溯
6. 可维护
7. 零额外付费 Pilot 约束
8. 功能数量

本项目不是 Excel 网页化、传统教务 ERP、收费排课 CRM，也不是 AI Demo。

---

## 2. V1 边界

教师主导航只有：今日 / 学生 / 课程 / 学情。

家校、报告进入 V1.1。

V1 暂不做：收费 / 课消 / 招生 CRM、完整排课、大型题库、学情综合分、成绩预测、家长 / 学生独立 App、自助 SaaS 注册、AI 自动正式诊断、Google Docs 式协同、复杂 offline-first/CRDT、庞大知识图谱。

---

## 3. 业务铁律

- 同一机构一个真实学生只有一份主档案；姓名不是唯一键。
- 升年级、换老师、换班 / 校区保留历史。
- 任课教师与学管 / 班主任关系分开。
- 离职不删除历史事实。
- `new` 是 10–20 秒快速捕捉，不把完整诊断表塞回课堂。
- assessment passed 不自动 stable / closed。
- 周度 / 长期问题 / 阶段指标优先派生。
- Today 由 case_actions 驱动，不依赖完整排课。
- AI 只做 draft / 建议，不静默修改正式学情。

### 时间语义
- 系统事件时间使用 UTC / `timestamptz`；
- `organizations.time_zone` 是 Today、due / overdue、lesson 业务日期、周度 / 报告周期的唯一机构时区事实源；
- 不直接使用设备当前时区决定机构业务日期；
- V1 不做 campus 独立时区。

### 正式 Case 永远有下一步
- `new` 可没有行动；
- `confirmed / intervening / pending_verification / stable` 必须有一个 pending primary action；
- 暂缓 = `review` primary action + `due_at`；`pause_reason` 只解释；
- `closed` 不得有 pending primary action。

---

## 4. Auth / Session / Membership

V1：管理员受控开通 + Password + onboarding。

- 不开放公网注册。
- 临时密码强随机、短有效期，只显示一次，不进 DB / log / audit / GitHub。
- membership 初始 onboarding，普通业务 RLS 全拒绝。
- `complete_member_onboarding`：更新密码 → global sign-out 所有 Sessions → 成功后 active → 强制重新登录。
- 普通业务授权还必须验证 JWT `session_id` 对应 `auth.sessions` 仍存在。
- `reset_member_credential`：**先 membership → onboarding，再更新 Auth 密码**。
- provision / reset 响应丢失：reissue 新密码，绝不保存旧明文满足幂等。
- onboarding 必须有 `onboarding_expires_at`；过期只能 reissue。
- disabled / revoked Session 即使 JWT 尚未到 `exp` 也不能访问业务。
- 权限事实源是 membership / roles / assignments，不是 user_metadata。
- 真实 Pilot 至少两个可信 org_admin，或已演练 break-glass。

### V1 不支持同一账号跨机构同时活跃
- 数据库仍支持多个 organization；
- 同一 `auth user_id` 同一时点最多一个 `onboarding / active` membership；
- 可以保留其他机构 disabled 历史；
- provision 发现该 Auth User 已在另一机构 onboarding / active 时必须拒绝；
- 原因：org_admin 的 Password reset 是全局 Auth credential，不能让 A 机构管理员影响 B 机构用户；
- 未来要跨机构账号，先新增 ADR，改为中央身份治理 / OTP / SSO 等方案后再开放。

详见 `docs/AUTH_AND_PERMISSIONS.md` 与 `docs/FOUNDATION_FINAL_AUDIT.md`。

---

## 5. Flutter 客户端安全

- Windows + Android 优先。
- View / ViewModel / Repository / Service 职责分离；UI 可 feature-oriented。
- Widget 不拼复杂权限、事务或表查询。
- 不允许页面散落 `Supabase.instance.client.from(...)`。
- Repository / Service 可 fake / test。
- 优先参考 Flutter 官方 `compass_app`，不要为“Clean Architecture”制造空层。

### Session
- 未来 gated Production 的 Session 方案必须在 P0 Gate A/B 通过后冻结；
- 若兼容性 Spike 采用 Supabase，使用 custom `LocalStorage` + OS secure storage；
- Password 不本地持久化；
- App 启动通过 Session / live membership Gate 后才能挂业务 Shell；
- expired / revoked / disabled 不得闪现学生页。

### Draft
跨重启敏感 draft：
- 加密；
- key 在 OS secure storage；
- user / org scope；
- TTL；
- sync 后清除；
- account switch 不串数据；
- logout / disabled 有明确处理；
- 不存 Token / Password。

---

## 6. Supabase / 数据库

> 这里的 Supabase 仅表示 V1 reference / preferred implementation candidate；本阶段不得据此创建 production provider、production Auth/RLS/CRUD 或正式 business migration。


- V1 reference implementation candidate：PostgreSQL + Auth + Storage + RLS；provider-specific 细节只在 Phase 0B.0 compatibility/security Spike 中用虚构数据验证；
- 普通授权读写 Data API；
- Secret / Auth Admin 走可信服务端；
- 数据库内多表不变量走受控 Function。

新增 / 修改业务表必须检查：
- organization_id 归属一致；
- RLS；
- 最小 GRANT；
- live-session + active membership；
- cross-org / cross-subject / cross-student 负面测试；
- 核心历史 FK 不意外 cascade；
- 高频 RLS 字段索引；
- 涉及业务日期时使用 organization timezone。

live-session helper 还必须做执行计划 / 实际性能验证；不能为了性能静默删掉安全条件。

View 优先 `security_invoker = true`。

`security definer`：非 exposed schema、`search_path = ''`、schema-qualified、revoke 默认 execute、最小 grant、越权测试。

Storage：private bucket + `storage.objects` policy；signed URL 短时且只在授权后生成，不进日志。

### Realtime
V1 不在学生敏感业务表默认开启 Realtime，也不让正确性依赖 Realtime。

页面进入、保存后、App resume、手动刷新必须足够正确。以后如需 Realtime，必须单独 ADR + revoked-session / reconnect / cross-org 安全测试后才开放。

---

## 7. 环境与 Migration

- Local compatibility：Supabase CLI + fake seed + schema / RLS / tests；
- Remote Development compatibility/security Spike：一个 Free Project，仅虚构数据；
- Gated Production Pilot：只有 P0 Gate A/B、provider/region/identity/session strategy 冻结并通过 Go/No-Go 后才可创建/承载真实数据；

若 Phase 0B.0 Gate A/B 通过并选定 Supabase，`supabase/migrations` 才作为该 provider 路径的 schema / RLS / View / Function / Trigger / Index 正式事实源；Phase 0A.6 不创建 production migration。

禁止：
- 只改 Dashboard / SQL Editor 不回写 migration；
- Gated Production 禁止 seed / reset；
- Development 与 gated Production 不共享 Secret / Storage / 账号。

### Region
未来 gated Production region 必须先用 Remote Dev 在实际机构 Wi-Fi + 普通移动网络 + **无代理 / VPN**测试 Auth / Data / Storage / Functions；不合格就重建 Dev 换 APAC region。不要先建 Production 再后悔 region。

---

## 8. 事务 / 幂等 / 并发

以下不得由 ViewModel 拼多次 CRUD：
- provision / complete onboarding / reset
- confirm / transition / reopen Case
- replace primary action
- complete lesson
- teacher handoff + disable
- merge students

业务命令考虑：权限、状态、expected_version、事务、operation_id、失败恢复。

Credential 是特殊例外：明文密码不持久化，因此响应丢失时 reissue，不承诺重复返回同一 secret。

关键快照使用乐观并发；冲突不静默覆盖。

---

## 9. 隐私

开发 / 测试 / 截图 / seed 只用虚构数据。

不得提交：真实学生 / 家长联系方式、作文 / 试卷照片、家校正文、真实账号密码、Token / Secret、真实 backup。

Private repository 也不改变这条规则。

自由文本只收集必要教学事实；日志 / audit 不复制完整敏感正文。

---

## 10. 零额外付费硬约束

默认不新增现金支出：SMTP / 域名 / SMS、AI API、Supabase Pro / add-ons、商业 UI / 监控 / 分析 SaaS、GitHub larger runner、Work / Codex extra credits、Windows 付费公信签名作为 Pilot 硬依赖。

GitHub：
- repo 必须 Private；
- Work / Codex 禁直推 main；
- branch + Draft PR + 执行证据 + 人工合并；
- repository 已关闭 Wiki 与 Template repository；
- 用户已明确选择**暂不设置 Actions zero-overage budget**；这是已知并接受的账户级计费风险，不再作为 Foundation / Phase 0A 阻塞项；
- 因未设置 budget，CI 必须主动控制消耗：普通 PR 只跑轻量 Linux 检查，Windows / Android native build 仅 milestone / release / 手动触发；禁止 larger runner 和无价值重复构建。

Supabase Free：
- Remote Dev compatibility 项目；gated Production Pilot 只有 P0 Gate A/B 与 Go/No-Go 后才可建立；
- 定期 roles / schema / data dump；
- Auth restore 必须实际登录验证；
- Storage 独立 backup；
- 实际 restore drill；
- Pilot 默认 RPO ≤ 一个教学日。

达到 ChatGPT 方案内 agentic 用量后等待重置，不自行购买 credits。

---

## 11. 测试与完成定义

数据库 PR 至少证明：
- Local 从空库 migrations + seed 成功；
- DB / RLS tests；
- unauth / no-member / revoked / onboarding / disabled / cross-org 等负面测试；
- 核心查询性能没有被 RLS / live-session guard 拖垮；
- 涉及日期的测试覆盖 organization timezone。

Auth Phase 0 至少：
- onboarding expiry / reissue；
- global sign-out；
- 保存旧 JWT 后直接请求仍被拒；
- reset 顺序和故障注入；
- 单 user 多 active / onboarding org membership 被拒；
- Session secure storage；
- Startup Gate；
- 双平台。

业务命令至少：
- 合法 / 非法状态；
- expected_version；
- 中间失败；
- 重复 operation；
- 响应丢失；
- 网络重试不重复事实。

一个功能只有在正常 / 错误 / 权限 / 网络 / 测试 / migration / 文档都同步后才完成。

---

## 12. Git / PR

- 较大功能 branch + Draft PR；
- schema / RLS / 代码 / 受影响文档同 PR；
- 正式初始化后提交 `pubspec.lock`；
- CI 的 `flutter pub get` 后必须验证 `pubspec.lock` 没有未提交变化；
- 依赖升级独立 PR；
- 不把大重构和无关 UI 混在一起；
- 改关键方向先更新 `docs/DECISIONS.md`；
- 未实际运行的检查必须明确“未执行”。

### 低层 Git Data API 完整性规则

如果 Agent / connector 使用 Git Data API（blob / tree / commit / ref）而不是普通 Git 工作区提交：
- 创建 commit 成功**不等于**仓库树正确；
- 更新 tree 时必须以正确 parent/base tree 为基础，除非明确是在创建完整新树；
- 写入后必须重新读取目标 branch 的 recursive tree；
- 至少确认 `AGENTS.md`、`docs/`、`lib/`、`test/`、目标 platform 目录和 `.github/` 等关键路径仍存在；
- 对异常路径数量骤降、关键目录消失立即视为失败并恢复；
- 未完成最终 tree 完整性检查，不得声称远端提交成功。

PR 检查项见 `.github/pull_request_template.md`。
