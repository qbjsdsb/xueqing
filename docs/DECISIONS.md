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

- 年级/校区/班级：`student_enrollments`
- 任课教师：`student_teacher_assignments`
- 学管/班主任：`student_staff_assignments`

不覆盖一个“当前 teacher/grade”而丢历史。

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

## ADR-019｜正确性不依赖 Realtime
**Accepted**

刷新/重新进入/App resume 必须足以恢复正确状态；Realtime 只增强体验。

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

真实机构 OTP 依赖可靠 SMTP；用户要求本阶段零额外付费后降为未来可替换登录 UX。

## ADR-028｜Invitation 与 Membership 分离
**Deferred for V1**

概念仍正确；V1 内部封闭开通暂不建 invitation 表。

## ADR-029｜课堂“快速捕捉 → 课后确认”
**Accepted**

`new` 目标 10–20 秒，confirmed 再补结构。

## ADR-030｜零成本认证：管理员开通 + 临时密码 + onboarding
**Accepted / Refined by ADR-035**

少量已知教师，不开放公共注册。Auth User 与业务 membership 分离；onboarding 无学生业务权限；Email OTP 未来可替换登录层。

## ADR-031｜零额外付费 Pilot 基础设施
**Accepted**

- GitHub Free private；
- 精简 Actions；
- Supabase Local；
- 一个 Free Remote Dev；
- 一个 Free Production Pilot；
- 不买 SMTP/域名/SMS/AI API/Work extra credits。

Free 不等于 SLA，必须手工备份/恢复。

## ADR-032｜ChatGPT Project + Work 是云端主控，Git/CI 是事实与证据
**Accepted**

一个可验收目标通常一条 Work 会话 + PR；GitHub 是代码事实源；需要真实命令由 Work/Codex/CI 给证据。Luna Max 留给高风险推理。

## ADR-033｜开源项目借“模式”，不 fork 大型学校 ERP
**Accepted**

参考 Flutter official compass、supabase-flutter、AppFlowy、Frappe Education、Gibbon。借工程/领域经验，不复制产品范围。

---

## ADR-034｜正式未关闭 Case 必须始终有下一步行动
**Accepted**

最终规则：
- `new` 可以没有 action；
- `confirmed / intervening / pending_verification / stable` 必须有一个 pending primary action；
- 暂缓/观察不是“无下一步”，使用 `action_type=review`；
- 暂停 review 必须有 `due_at`；
- `pause_reason` 只是解释，不代替行动；
- closed 不存在 pending primary action。

理由：避免 case 因“暂停”永久从 Today 消失，同时坚持 case_actions 单一行动事实源，不再新增 `next_review_at` 第二套日期。

---

## ADR-035｜业务授权要求 active Membership + Live Supabase Session
**Accepted（Phase 0 必须实测）**

仅 `membership=active` 不足以覆盖被撤销旧 JWT 的窗口。

Supabase JWT 包含 `session_id`，可关联 `auth.sessions`。global sign-out 会移除 Session/Refresh Token，但已有 Access Token 仍可能在 `exp` 前存在。

因此普通学生业务 RLS 要同时证明：

```text
auth.uid()
+ jwt session_id 仍存在于 auth.sessions
+ membership = active
+ role / assignment
```

`complete_member_onboarding`：

```text
验证 onboarding / expiry
→ 更新新密码
→ global sign-out 全部 Sessions
→ 成功后 membership active
→ 强制重新登录
```

旧 Access Token 因 session row 已不存在而被 RLS 立即拒绝。

`reset_member_credential` 必须**先 membership→onboarding，再更新 Auth 密码**，跨系统失败优先无业务权限。

Phase 0 要用实际旧 JWT 做攻击式测试，并评估 live-session helper 性能。

---

## ADR-036｜Session 和本地草稿都按敏感数据保护
**Accepted（Phase 0 选实现）**

`supabase_flutter` 默认会将 Session 持久化到 SharedPreferences 系列存储；Production 不直接接受默认方案。

- Supabase 使用自定义 `LocalStorage` + Windows/Android OS secure storage；
- Password 永不本地持久化；
- App Startup 必须验证 Session/live membership 后才挂业务 Shell；
- 跨重启敏感 draft 必须加密；key 存 OS secure storage；
- draft 按 user/org 隔离，有 TTL，同步后删除，切账号不串数据。

具体开源依赖在 Phase 0 选型，不为安全而引入付费服务。

---

## ADR-037｜Production Region 由真实无代理网络测试决定
**Accepted**

Supabase APAC 有 Singapore/Tokyo/Seoul 等，但没有中国大陆 region；project region 不能原地修改。

因此：
- 用虚构 Remote Development 在实际机构 Wi‑Fi、普通移动网络、无代理/VPN下测 Auth/Data/Storage/Functions；
- 不合格就重建 Dev 到另一 APAC region；
- 测完才创建 Production；
- Region 选择是数据驻留控制之一，不等于合规结论；真实未成年人数据跨境/驻留另做机构评估。

---

## ADR-038｜GitHub Free Private 采用流程治理，不假装有付费 Branch Protection
**Accepted**

隐私要求仓库 Private，但 GitHub Free 私有仓库没有 Pro/Team 才有的 private ruleset/branch protection 强制能力。

零成本阶段：
- Work/Codex 禁直推 main；
- feature/review branch + Draft PR；
- 没有真实执行证据不人工合并；
- Actions budget 开启 `Stop usage when budget limit is reached`；
- 以后升级 GitHub 计划再启用 required PR/status checks。

Private/隐私优先，不为了免费 branch protection 把学生软件源码长期保持 Public。

---

## ADR-039｜Free Pilot 的恢复能力是产品门槛
**Accepted**

Free 没有付费级自动日备份。真实数据前必须：
- roles/schema/data logic dump；
- Storage object 独立备份 + manifest；
- 项目 Auth/Realtime/Extensions/Secrets 配置清单；
- 加密离站；
- 恢复到非 Production 新项目并 smoke test。

Pilot 默认 RPO 目标 ≤ 一个教学日；机构若无法接受，则“0 元 Production”不满足要求，必须重做成本 ADR。

---

## ADR-040｜临时 Credential 不为“可重复返回”而持久化
**Accepted**

provision/reset 响应可能丢失，但临时密码只允许显示一次且不保存明文。

因此 credential 命令的恢复语义是：
- member 保持 onboarding；
- 交付状态未知时 reissue 新密码；
- 旧临时密码失效；
- operation receipt 记录状态，不记录秘密。

“幂等”不能成为秘密长期存储的借口。
