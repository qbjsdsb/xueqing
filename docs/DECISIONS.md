# 架构与产品决策记录（ADRs）

> 已接受决定不得在代码里静默推翻。若实践证明需要改变，先写新的 ADR：原因、影响、迁移/回滚方案、验证证据。

## ADR-001｜Flutter，Windows + Android 优先
**Accepted**
办公深度管理优先 Windows，课中/课后快速记录优先 Android，共享主要业务模型。V1 不同时铺 Web/iOS。

## ADR-002｜Supabase 作为 V1 云端基础设施
**Accepted**
PostgreSQL + Auth + Storage + RLS + Edge Functions。业务强关系、多角色、多租户，适合关系数据库。

## ADR-003｜普通 Data API，高权限/事务受控执行
**Accepted**
普通授权读写走 RLS Data API；数据库内多表不变量走 DB Function；需要 Auth Admin/Secret/跨系统编排走 Edge Function/可信服务端。Flutter 永不持有 service_role。

## ADR-004｜从第一天多租户，但 V1 不做 SaaS 计费
**Accepted**
保留 organization 边界与 RLS；不做套餐/订阅/自助开通。

## ADR-005｜一个学生一份机构主档案
**Accepted**
不同教师/学科/年级不重复建 Student。姓名不是唯一键，重复通过提示 + 受控合并。

## ADR-006｜年级与责任关系保存历史
**Accepted**
`student_enrollments`、`student_teacher_assignments`、`student_staff_assignments` 保存历史，不覆盖单一当前值。

## ADR-007｜“顽固问题”不是第二台账
**Accepted**
由 case 的持续、失败、复发等事实派生。

## ADR-008｜周度/阶段指标优先派生
**Accepted**
教师不重新填周表。

## ADR-009｜Case：当前快照 + append-only 事件
**Accepted**
`learning_cases` 保存当前状态，`case_events` 保存关键生命周期变化。

## ADR-010｜下一步行动是一等对象
**Accepted / Refined by ADR-034**
`case_actions` 是 Today 事实源。正式未关闭 case 不能成为没有下一步的孤儿。

## ADR-011｜Lesson 支持一对多，但不是排课 CRM
**Accepted**
`lessons + lesson_students` 只表达实际教学会话，不扩收费、课消、招生、复杂排课。

## ADR-012｜Online-first，但保护未提交输入
**Accepted / Refined by ADR-036**
云端 PostgreSQL 是正式事实源；本地仅临时草稿，不做 CRDT 多主同步。

## ADR-013｜不做未经验证的“学情健康分”
**Accepted**
展示透明事实，不把人为加权包装成科学结论。

## ADR-014｜AI 是副驾驶
**Accepted**
AI 可 draft/摘要/相似提示；正式教学事实和状态必须人工确认。

## ADR-015｜完整 6 入口，V1 4 入口
**Accepted**
完整：今日/学生/课程/学情/家校/报告；V1：今日/学生/课程/学情。

## ADR-016｜Today 行动驱动，不依赖完整排课
**Accepted**
主要聚合 case_actions、待验证、重点 case、最近负责学生。

## ADR-017｜受控分类 + 自由表达
**Accepted**
轻量 taxonomy 用于统计，title/description 保留真实教学表达。

## ADR-018｜业务层不散落 Supabase SDK
**Accepted**
View/ViewModel 经 Repository/Service 访问后端，可 fake/test。

## ADR-019｜V1 正确性不依赖 Realtime
**Accepted / Refined by ADR-042**
提交后刷新、页面进入、App resume、手动刷新必须足以保证正确。

## ADR-020｜Local / Remote Dev / Production 分离
**Accepted / Refined by ADR-037**
Local 做可重复 DB/RLS；Remote Dev 虚构公网集成；Production 承载真实数据。

## ADR-021｜首位 org_admin 一次性 bootstrap
**Accepted**
可信运维初始化，完成后关闭入口；Flutter 不内置超级管理员 Secret。

## ADR-022｜Assessment 与 Case Status 是两类事实
**Accepted**
passed 不自动 stable/closed。

## ADR-023｜客户端 View 显式处理 RLS
**Accepted**
优先 `security_invoker = true`；security-definer helper 放非 exposed schema。

## ADR-024｜Git migrations 是数据库结构事实源
**Accepted**
Schema/RLS/View/Function/Trigger/Index 正式变化全部 migration；Remote Dashboard 不是第二事实源。

## ADR-025｜Supabase Invite Link 账号方案
**Superseded**
早期依赖 invite link/deep link，已被后续零成本 Password onboarding 替代。

## ADR-026｜分类 schema 先稳，复杂治理 UI 后置
**Accepted**
少量默认 taxonomy + “其他/暂未分类”。

## ADR-027｜Email OTP 作为 V1 首选
**Superseded by ADR-030**
真实机构 OTP 依赖可靠 SMTP；零额外付费阶段降为未来可替换登录 UX。

## ADR-028｜Invitation 与 Membership 分离
**Deferred for V1**
概念仍正确；V1 内部封闭开通暂不建 invitation 表。

## ADR-029｜课堂“快速捕捉 → 课后确认”
**Accepted**
`new` 目标 10–20 秒，confirmed 再补结构。

## ADR-030｜零成本认证：管理员开通 + 临时密码 + onboarding
**Accepted / Refined by ADR-035 / ADR-041**
少量已知教师，不开放公共注册。Auth User 与业务 membership 分离；onboarding 无学生业务权限；Email OTP 未来可替换登录层。

## ADR-031｜零额外付费 Pilot 基础设施
**Accepted**
GitHub Free private + 精简 Actions；Supabase Local + 一个 Free Remote Dev + 一个 Free Production Pilot；不买 SMTP/域名/SMS/AI API/Work extra credits。Free 不等于 SLA，必须手工备份/恢复。

## ADR-032｜ChatGPT Project + Work 是云端主控，Git/CI 是事实与证据
**Accepted**
一个可验收目标通常一条 Work 会话 + PR；GitHub 是代码事实源；真实命令由 Work/Codex/CI 给证据。Luna Max 留给高风险推理。

## ADR-033｜开源项目借“模式”，不 fork 大型学校 ERP
**Accepted**
参考 Flutter official compass、supabase-flutter、AppFlowy、Frappe Education、Gibbon；借工程/领域经验，不复制产品范围。

---

## ADR-034｜正式未关闭 Case 必须始终有下一步行动
**Accepted**
- new 可没有 action；
- confirmed/intervening/pending_verification/stable 必须有一个 pending primary action；
- 暂缓/观察使用 `action_type=review`；暂停 review 必须有 `due_at`；
- `pause_reason` 只是解释，不替代行动；
- closed 不存在 pending primary action。

理由：避免 case 因“暂停”永久从 Today 消失，同时坚持 case_actions 单一行动事实源，不新增 `next_review_at` 第二套日期。

---

## ADR-035｜业务授权要求 Active Membership + Live Supabase Session
**Accepted（Phase 0 必须实测）**

Supabase JWT 包含 `session_id`，可关联 `auth.sessions`。global sign-out 会移除 Session/Refresh Token，但已有 Access Token 仍可能在 `exp` 前存在。

普通学生业务 RLS 要同时证明：

```text
auth.uid()
+ jwt session_id 仍存在于 auth.sessions
+ membership = active
+ role / assignment
```

`complete_member_onboarding`：验证 onboarding/expiry → 更新新密码 → global sign-out 全部 Sessions → 成功后 active → 强制重新登录。

`reset_member_credential`：先 membership→onboarding，再更新 Auth 密码。

Phase 0 用保存的旧 JWT 做攻击式测试，并评估 live-session helper 性能。

---

## ADR-036｜Session 和本地草稿都按敏感数据保护
**Accepted（Phase 0 选实现）**

- Supabase 使用 custom `LocalStorage` + Windows/Android OS secure storage；
- Password 永不本地持久化；
- App Startup 验证 Session/live membership 后才挂业务 Shell；
- 跨重启敏感 draft 加密；key 存 OS secure storage；
- draft 按 user/org 隔离，有 TTL，同步后删除，切账号不串数据。

具体开源依赖在 Phase 0 选型，不为安全引入付费服务。

---

## ADR-037｜Production Region 由真实无代理网络测试决定
**Accepted**

Supabase APAC 有 Singapore/Tokyo/Seoul 等，但没有中国大陆 region；project region 不能原地修改。

用虚构 Remote Development 在实际机构 Wi‑Fi、普通移动网络、无代理/VPN下测 Auth/Data/Storage/Functions；不合格就重建 Dev 换 region；测完才创建 Production。Region 不是合规证明，真实未成年人数据驻留/跨境另做机构评估。

---

## ADR-038｜GitHub Free Private 采用流程治理，不假装有付费 Branch Protection
**Accepted**

隐私要求 repo Private，但 GitHub Free 私有仓库没有 Pro/Team 才有的 private ruleset/branch protection 强制能力。

零成本阶段：Work/Codex 禁直推 main；feature/review branch + Draft PR；没真实执行证据不人工合并；Actions budget 开启 `Stop usage when budget limit is reached`。

---

## ADR-039｜Free Pilot 的恢复能力是产品门槛
**Accepted**

真实数据前必须：roles/schema/data dump、Storage 独立备份 + manifest、项目配置清单、加密离站、restore drill。

Pilot 默认 RPO ≤ 一个教学日；机构不能接受则 0 元 Production 不满足要求。

---

## ADR-040｜临时 Credential 不为“可重复返回”而持久化
**Accepted**

provision/reset 响应可能丢失，但临时密码只显示一次、不保存明文。交付状态未知时 member 保持 onboarding，管理员 reissue 新密码，旧临时密码失效。

---

## ADR-041｜V1 数据库多租户，但同一 Auth User 不跨机构同时活跃
**Accepted**

V1 的 Password 是全局 Supabase Auth credential，而 `reset_member_credential` 由机构 org_admin 管理。如果同一个 Auth User 同时属于 A、B 两个机构，A 的管理员重置密码会影响 B，这违反租户身份治理边界。

因此 V1：
- 数据库/业务表继续支持多个 organization；
- 同一 `auth user_id` 同一时点最多一个 `onboarding` 或 `active` membership；
- 可以保留其他 organization 的 disabled 历史；
- schema 用 partial unique index/受控命令防止跨机构双活；
- `provision_member` 遇到另一机构非 disabled membership 时拒绝。

未来要支持一个教师加入多个机构，先采用不会让单一机构管理员控制全局 credential 的身份治理：中央 identity admin、Email OTP、SSO 或等价方案，再新增 ADR 移除限制。

---

## ADR-042｜V1 学生敏感表默认不启用 Realtime
**Accepted**

理由：
- ADR-019 已要求正确性不依赖 Realtime；
- Session revoke 对既有长连接的行为需要专门安全测试；
- V1 的页面进入/保存后/App resume/手动刷新已足够内部 Pilot；
- 不为“实时感”增加不必要攻击面、调试复杂度和流量。

因此 V1 默认不把学生/学情敏感表加入 Realtime publication，也不写依赖 Realtime 才正确的业务逻辑。

以后需要 Realtime 时，新增 ADR，至少测试 revoked session、token refresh/re-auth、reconnect、cross-org、subscription cleanup 后再开启。
