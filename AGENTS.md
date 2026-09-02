# AGENTS.md

本文件是 ChatGPT Work、Codex 与后续开发者的**硬约束索引**。详细语义以 `docs/` 对应专题和已接受 ADR 为准。不得在代码中静默改方向。

## 1. 优先级

1. 数据正确与权限安全
2. 学生历史连续
3. 教师高频流程低负担
4. 保存/恢复可靠
5. 可追溯
6. 可维护
7. 零额外付费 Pilot 约束
8. 功能数量

本项目不是 Excel 网页化、传统教务 ERP、收费排课 CRM，也不是 AI Demo。

---

## 2. V1 边界

教师主导航只有：
- 今日
- 学生
- 课程
- 学情

家校、报告进入 V1.1。

V1 暂不做：收费/课消/招生 CRM、完整排课、大型题库、学情综合分、成绩预测、家长/学生独立 App、自助 SaaS 注册、AI 自动正式诊断、Google Docs 式协同、复杂 offline-first/CRDT、庞大知识图谱。

---

## 3. 业务铁律

- 同一机构一个真实学生只有一份主档案；姓名不是唯一键。
- 升年级、换老师、换班/校区保留历史。
- 任课教师与学管/班主任关系分开。
- 离职不删除历史事实。
- `new` 是 10–20 秒快速捕捉，不把完整诊断表塞回课堂。
- assessment passed 不自动 stable/closed。
- 周度/长期问题/阶段指标优先派生。
- Today 由 case_actions 驱动，不依赖完整排课。
- AI 只做 draft/建议，不静默修改正式学情。

### 正式 Case 永远有下一步
- new 可没有行动；
- confirmed/intervening/pending_verification/stable 必须有一个 pending primary action；
- 暂缓 = `review` primary action + `due_at`；`pause_reason` 只解释；
- closed 不得有 pending primary action。

---

## 4. Auth / Session / Membership

V1：管理员受控开通 + Password + onboarding。

- 不开放公网注册。
- 临时密码强随机、短有效期，只显示一次，不进 DB/log/audit/GitHub。
- membership 初始 onboarding，普通业务 RLS 全拒绝。
- `complete_member_onboarding`：更新密码 → global sign-out 所有 Sessions → 成功后 active → 强制重新登录。
- 普通业务授权还必须验证 JWT `session_id` 对应 `auth.sessions` 仍存在。
- `reset_member_credential`：**先 membership→onboarding，再更新 Auth 密码**。
- provision/reset 响应丢失：reissue 新密码，绝不保存旧明文满足幂等。
- onboarding 必须有 `onboarding_expires_at`；过期只能 reissue。
- disabled / revoked Session 即使 JWT 尚未到 `exp` 也不能访问业务。
- 权限事实源是 membership / roles / assignments，不是 user_metadata。
- 真实 Pilot 至少两个可信 org_admin，或已演练 break-glass。

详见 `docs/AUTH_AND_PERMISSIONS.md`。

---

## 5. Flutter 客户端安全

- Windows + Android 优先。
- View / ViewModel / Repository / Service 职责分离；UI 可 feature-oriented。
- Widget 不拼复杂权限、事务或表查询。
- 不允许页面散落 `Supabase.instance.client.from(...)`。
- Repository/Service 可 fake/test。
- 优先参考 Flutter 官方 `compass_app`，不要为“Clean Architecture”造空层。

### Session
- Production 不使用默认 SharedPreferences Session 存储作为最终方案；
- Supabase custom `LocalStorage` + OS secure storage；
- Password 不本地持久化；
- App 启动通过 Session/live membership Gate 后才能挂业务 Shell；
- expired/revoked/disabled 不得闪现学生页。

### Draft
跨重启敏感 draft：
- 加密；
- key 在 OS secure storage；
- user/org scope；
- TTL；
- sync 后清除；
- account switch 不串数据；
- 不存 Token/Password。

---

## 6. Supabase / 数据库

- PostgreSQL + Auth + Storage + RLS。
- 普通授权读写 Data API；
- Secret/Auth Admin 走可信服务端；
- 数据库内多表不变量走受控 Function。

新增/修改业务表必须检查：
- organization_id 归属一致；
- RLS；
- 最小 GRANT；
- live-session + active membership；
- cross-org/cross-subject/cross-student 负面测试；
- 核心历史 FK 不意外 cascade；
- 高频 RLS 字段索引。

View 优先 `security_invoker=true`。

`security definer`：非 exposed schema、`search_path=''`、schema-qualified、revoke 默认 execute、最小 grant、越权测试。

Storage：private bucket + storage.objects policy；signed URL 短时且只在授权后生成，不进日志。

---

## 7. 环境与 Migration

- Local：Supabase CLI + fake seed + schema/RLS/tests；
- Remote Development：一个 Free Project，仅虚构数据；
- Production Pilot：第二个 Free Project，真实数据前通过 Go/No-Go。

`supabase/migrations` 是 schema/RLS/View/Function/Trigger/Index 正式事实源。

禁止：
- 只改 Dashboard/SQL Editor 不回写 migration；
- Production seed/reset；
- Development/Production 共享 Secret/Storage/账号。

### Region
Production region 必须先用 Remote Dev 在实际机构 Wi‑Fi + 普通移动网络 + **无代理/VPN**测试 Auth/Data/Storage/Functions；不合格就重建 Dev 换 APAC region。不要先建 Production 再后悔 region。

---

## 8. 事务 / 幂等 / 并发

以下不得由 ViewModel 拼多次 CRUD：
- provision / complete onboarding / reset
- confirm / transition / reopen case
- replace primary action
- complete lesson
- teacher handoff + disable
- merge students

业务命令考虑：权限、状态、expected_version、事务、operation_id、失败恢复。

Credential 是特殊例外：明文密码不持久化，因此响应丢失时 reissue，不承诺重复返回同一 secret。

关键快照使用乐观并发；冲突不静默覆盖。

Realtime 只增强体验，正确性不依赖它。

---

## 9. 隐私

开发/测试/截图/seed 只用虚构数据。

不得提交：真实学生/家长联系方式、作文/试卷照片、家校正文、真实账号密码、Token/Secret、真实 backup。

自由文本只收集必要教学事实；日志/audit 不复制完整敏感正文。

---

## 10. 零额外付费硬约束

默认不新增现金支出：
- SMTP/域名/SMS；
- AI API；
- Supabase Pro/add-ons；
- 商业 UI/监控/分析 SaaS；
- GitHub larger runner；
- Work/Codex extra credits；
- Windows 付费公信签名作为 Pilot 硬依赖。

GitHub：
- repo 必须 Private；
- Free private 无付费级 branch protection 强制能力，靠 branch + Draft PR + 人工合并纪律；
- Work/Codex 禁直推 main；
- Actions budget 开启 **Stop usage when budget limit is reached**。

Supabase Free：
- Remote Dev + Production Pilot 两个项目；
- 定期 roles/schema/data dump；
- Storage 独立 backup；
- 实际 restore drill；
- Pilot 默认 RPO ≤ 一个教学日。

达到 ChatGPT 方案内 agentic 用量后等待重置，不自行购买 credits。

---

## 11. 测试与完成定义

数据库 PR 至少证明：
- Local 从空库 migrations + seed 成功；
- DB/RLS tests；
- unauth/no-member/revoked/onboarding/disabled/cross-org 等负面测试。

Auth Phase 0 至少：
- onboarding expiry/reissue；
- global sign-out；
- 保存旧 JWT 后直接请求仍被拒；
- reset 顺序和故障注入；
- Session secure storage；
- Startup Gate；
- 双平台。

业务命令至少：
- 合法/非法状态；
- expected_version；
- 中间失败；
- 重复 operation；
- 响应丢失；
- 网络重试不重复事实。

一个功能只有在正常/错误/权限/网络/测试/migration/文档都同步后才完成。

---

## 12. Git / PR

- 较大功能 branch + Draft PR；
- schema/RLS/代码/受影响文档同 PR；
- 正式初始化后提交 `pubspec.lock`；
- 依赖升级独立 PR；
- 不把大重构和无关 UI 混一起；
- 改关键方向先更新 `docs/DECISIONS.md`；
- 未实际运行的检查必须明确“未执行”。

PR 检查项见 `.github/pull_request_template.md`。
