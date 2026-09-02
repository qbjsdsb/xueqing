# 架构与产品决策记录（ADRs）

> 已接受决定不得在实现中静默推翻。需要改变时先新增/修订 ADR，写清原因、影响、迁移/回滚与验证证据。

## ADR-001｜Flutter，Windows + Android 优先
**Accepted** — Windows 深度管理、Android 快速记录；V1 不同时铺 Web/iOS。

## ADR-002｜Supabase 作为 V1 云端基础设施
**Superseded / Qualified by ADR-045**

历史上 Supabase 被选为 V1 参考基础设施（PostgreSQL/Auth/Storage/RLS/Functions）。Phase 0A.6 发现中国大陆部署候选、Auth ID 类型与 revoked-session 语义仍需实测，因此 **Supabase 不再是已冻结 Production provider**；它保留为 reference candidate。任何实现者不得仅凭 ADR-002 跳过 ADR-045 的 Phase 0B.0 gates。

## ADR-003｜普通 Data API，高权限/事务受控执行
**Accepted** — 普通授权读写走 RLS/Data API；多表不变量走 DB Function/受控 command；Secret/Auth Admin 走可信服务端。Flutter 不持有高权限 Secret。

## ADR-004｜从第一天多租户，但 V1 不做 SaaS 计费
**Accepted** — organization 边界/RLS 保留，不做套餐订阅。

## ADR-005｜一个学生一份机构主档案
**Accepted** — 学科/教师/年级不重复 Student；duplicate 走提示 + 受控 merge。

## ADR-006｜年级与责任关系保存历史
**Accepted** — Enrollment/teacher/staff assignment 不覆盖历史。

## ADR-007｜顽固问题不是第二台账
**Accepted** — 从持续、失败、reopen 等事实派生。

## ADR-008｜周度/阶段指标优先派生
**Accepted** — 不让教师重复填周表。

## ADR-009｜Case 当前快照 + append-only events
**Accepted** — learning_cases 当前状态，case_events 关键历史。

## ADR-010｜下一步行动是一等对象
**Accepted / Refined by ADR-034 and Phase 0A.6 service lifecycle** — Active Profile 的 formal open Case 必须有 pending primary Action；inactive/archived 是合法 suspended exception。

## ADR-011｜Lesson 支持一对多但不是排课 CRM
**Accepted**。

## ADR-012｜Online-first，保护未提交输入
**Accepted / Refined by reliability foundation** — 云端为正式事实源；本地仅加密 Draft，不做 CRDT 多主。

## ADR-013｜不做未经验证的学情健康分
**Accepted**。

## ADR-014｜AI 是副驾驶
**Accepted** — AI 可 draft/摘要，不自动正式诊断、status、finalize。

## ADR-015｜完整 6 入口，V1 4 入口
**Accepted / Refined** — V1 主导航 Today/Students/Lessons/Learning；最小家校能力在 Student/Case context，独立家校/报告工作台后置。

## ADR-016｜Today 行动驱动，不依赖完整排课
**Accepted**。

## ADR-017｜受控分类 + 自由表达
**Accepted**。

## ADR-018｜业务层不散落 provider SDK
**Accepted / Provider-neutral wording** — View/ViewModel 经 Repository/Service；Supabase/CloudBase 等 SDK 只在 infrastructure adapter。

## ADR-019｜V1 正确性不依赖 Realtime
**Accepted / Refined by ADR-042**。

## ADR-020｜Local / Remote Dev / Production 分离
**Accepted / Refined by ADR-045** — Remote Dev 仅虚构数据；Production provider 在 Phase 0B.0 gate 后才创建/冻结。

## ADR-021｜首位 org_admin 一次性 bootstrap
**Accepted**。

## ADR-022｜Assessment 与 Case Status 是两类事实
**Accepted** — passed ≠ stable ≠ closed。

## ADR-023｜客户端 View 显式处理 RLS
**Accepted** — security-invoker 优先；definer helper 最小化并隔离。

## ADR-024｜Git migrations 是数据库结构事实源
**Accepted**。

## ADR-025｜Supabase Invite Link 账号方案
**Superseded**。

## ADR-026｜分类 schema 先稳，复杂治理 UI 后置
**Accepted**。

## ADR-027｜Email OTP 作为 V1 首选
**Superseded by ADR-030**。

## ADR-028｜Invitation 与 Membership 分离
**Deferred for V1**。

## ADR-029｜课堂快速捕捉 → 课后确认
**Accepted / Refined by Phase 0A.6** — Quick Capture 10–20 秒，但 new Case 云端创建必须完整 Teaching Fact Gate；Advisor-only 不可借此创建教学 Case。

## ADR-030｜低成本认证：管理员开通 + 临时密码 + onboarding
**Accepted / Provider implementation pending ADR-045** — 不开放公共注册；onboarding 无学生业务权限。

## ADR-031｜零额外付费 Pilot 基础设施
**Accepted as cost goal / Provider choice refined by ADR-045** — GitHub/轻量 CI/不强依赖付费 SMTP/SMS/AI；历史 Supabase Free Project 方案不再等于 Production provider 已冻结。

## ADR-032｜ChatGPT Work/项目协作，Git/CI 是事实与证据
**Accepted**。

## ADR-033｜开源借模式，不 fork 大型学校 ERP
**Accepted**。

## ADR-034｜正式未关闭 Case 必须有下一步
**Accepted / Refined by Phase 0A.6** — **仅当 Subject Profile active**；inactive/archived unresolved Case 可无 current primary Action。

## ADR-035｜业务授权要求 Active Membership + Live Session
**Accepted security goal / Provider implementation refined by ADR-045**

Supabase `JWT session_id → auth.sessions` 是 reference；任何 Production provider 必须证明 signOut/reset/disabled 后 old token 无学生业务访问。

## ADR-036｜Session 和本地 Draft 按敏感数据保护
**Accepted / Provider-neutral** — Session 放 OS secure storage 或等价安全机制；Password 不持久化；Draft 加密、user/org scoped、TTL。

## ADR-037｜Production Region 由真实网络测试决定
**Accepted / Expanded by ADR-045** — Supabase APAC 只是候选；中国大陆 CloudBase/自托管等也需同样 Auth/Data/Storage/restore/无代理网络测试。Region 不是合规证明。

## ADR-038｜GitHub Free Private 用流程治理
**Accepted / Refined by ADR-044**。

## ADR-039｜Free Pilot 恢复能力是产品门槛
**Accepted** — DB/Storage/config backup + restore drill；free ≠ SLA。

## ADR-040｜临时 Credential 不为可重复返回而持久化
**Accepted**。

## ADR-041｜V1 数据多租户，但同一 Auth identity 默认不跨机构同时活跃
**Accepted / identity physical implementation pending ADR-045**。

## ADR-042｜V1 学生敏感表默认不启用 Realtime
**Accepted**。

## ADR-043｜Phase 0A 使用 Flutter SDK 内置 Navigator
**Accepted（Phase 0A）**。

## ADR-044｜Actions zero-overage budget 暂不设置，以 CI 触发策略控制消耗
**Accepted（用户明确选择，2026-09-02）** — 轻量 Linux checks；原生 build milestone/manual；避免重复触发/大型无价值 artifacts。

---

## ADR-045｜Production cloud provider 延迟到 Phase 0B.0 Compatibility Gate 后冻结
**Accepted — Supersedes ADR-002 的“Supabase 已定 Production provider”含义**

### 背景
Phase 0A.6 确认：
- 官方 Supabase 是生态成熟的 PostgreSQL/Auth/RLS/Storage reference candidate；
- 腾讯 CloudBase PG 提供中国大陆候选，并在 PostgreSQL/RLS/PostgREST 心智上相近；
- 国内自托管 Supabase 可作为长期迁移/控制路线；
- 但 Auth user ID 类型、Session revoke/old-token 语义、Storage/SDK/国内网络并非 100% 等价。

### 决定
Phase 0A.6 **不冻结 Production provider**。

候选：
1. official Supabase APAC/Singapore；
2. Tencent CloudBase PG Shanghai；
3. mainland self-hosted Supabase fallback。

所有业务领域文档必须 provider-neutral；Supabase-specific 术语只表示 reference implementation。

### Phase 0B.0 两个 pre-migration P0 hard gates

#### P0-A｜Auth Identity Portability
必须用虚构数据比较并冻结：
- provider-specific auth PK；
- business Profile UUID + external auth subject；
- text/weak-coupled identity link。

在此之前禁止把 `profiles.id` 永久锁死为某 provider `auth.users.id` 物理类型。

#### P0-B｜Revoked Session / Old Token Security
必须保存旧 token 并实测：
- signOut；
- credential reset；
- membership disabled；
- App restart/persisted token；

之后旧 token 请求学生业务 API 必须失败。

### 其他 compatibility evidence
Windows/Android Auth、RLS、RPC/transactions、private Storage、backup/restore、export/migration、中国大陆无代理网络。

### Gate
上述 P0 未通过：
- 不创建正式 Production schema/migrations 依赖；
- 不导入真实学生/家长数据；
- 不把 provider-specific Session helper 当领域事实。

Spike 通过后新增/更新 ADR 明确最终 provider、region、identity strategy、restore strategy。
