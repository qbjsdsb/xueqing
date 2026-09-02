# Phase 0A.6 Foundation Change Proposal

> 状态：Phase 0A.6 最终领域变更提案。本文集中记录对 `PRODUCT.md / DATA_MODEL.md / COMMANDS_AND_INVARIANTS.md / AUTH_AND_PERMISSIONS.md` 的必要修订。它不是 migration，也不授权进入真实 Auth/RLS/CRUD。

## 1. 决策纪律

每个缺口只允许归入三类：

- **ACCEPT**：已有充分产品依据，已/应回写 Foundation；
- **PENDING SPIKE**：需求真实，但实现必须由 Phase 0B.0 最小实验决定；
- **REJECT / DERIVE**：不新增领域对象，继续从已有事实派生。

判断标准：

> 这是新的真实业务事实，还是同一事实的另一种展示/总结？

如果只是展示/统计，默认派生；如果只是为了“表结构完整”，默认不建。

---

## 2. ACCEPT｜Role / Subject Scope / Assignment 三层授权

新增独立 `membership_subject_scopes`：
- membership；
- organization subject；
- `scope_kind = teaching / leadership`；
- active history。

冻结：
- Role 回答“能做哪类事”；
- Subject Scope 回答“在哪个学科有效”；
- Student Assignment 回答“具体负责哪个 Student + Subject”；
- teaching scope **不授予全学科学生访问**；
- leadership scope **不允许伪造 Intervention/Assessment/Lesson teacher**；
- Subject Lead 真实授课时仍需 teacher capability + teaching scope + Student/Lesson relationship。

新增/强化学科级 handoff：`revoke_teacher_subject_scope_and_handoff`。

**Decision：ACCEPT，已回写 Foundation。**

---

## 3. ACCEPT｜Student Subject Profile 是教学主线 + 服务生命周期

Profile 增强：
- `status = active / inactive / archived`；
- current positioning；
- strengths；
- version；
- 可选教学频次背景。

最重要的新边界：

> **Subject service lifecycle 与 Learning Case resolution lifecycle 分开。**

学生可以继续语文但停止数学：

```text
Student active
语文 Profile active
数学 Profile inactive
```

数学未解决 Case：
- 保留真实 status；
- 不自动 closed/清零；
- 当前 pending Actions 受控收口；
- 暂停进入 Today；
- 数学恢复 active 前重新建立合法 owner + primary Action。

因此 primary Action 不变量精确为：

> **active Subject Profile 下的 formal open Case 必须有 pending primary Action。**

新增/强化：
- `deactivate_student_subject_profile`
- `reactivate_student_subject_profile`
- Student 整体 deactivate/reactivate 逐 Profile reconciliation。

**Decision：ACCEPT，已回写 Foundation。**

---

## 4. DEFER WITH VALIDATION｜Initial Diagnosis Snapshot

Initial Diagnosis workflow 必须有，但**不先建 `initial_diagnoses` 平行大表**。

已有自然事实源：
- Student；
- Subject Profile；
- Evidence；
- Case；
- Action。

唯一可能新增的真实事实是：

> 第一次正式建档时的整体基线判断。

Pilot 专门验证是否需要“一键回看初始基线”。如果需要，再做轻量 immutable snapshot/event，而不是第二套 Case。

**Decision：P2 DEFER，理由明确。**

---

## 5. ACCEPT｜三类 Case Workflow，不改六态生命周期

统一底层：Case / Evidence / Intervention / Assessment / Action / Event。

默认 workflow：
- knowledge：当堂订正 → 相似题 → 延迟独立验证；
- habit：可观察行为 → 干预 → 多场景连续观察；
- exam_strategy：方法 → 应用 → 限时/模拟迁移 → 独立验证。

冻结：

```text
Assessment passed ≠ stable ≠ closed
```

知识“三阶”是教学模板，不是 schema 三列；`closed` 只有真实解决时产品才显示“已清零”。

**Decision：ACCEPT。**

---

## 6. ACCEPT｜Lesson Workspace + 受控 start/complete

Lesson：
- 课前看旧问题/到期/待验证；
- 课中逐步可靠保存事实；
- 课后 30–60 秒收口。

新增 `start_lesson` domain command；保留 `complete_lesson`。

小班最终 transaction granularity：
- whole lesson atomic；
- vs per-student reconcile then finalize；

**PENDING Phase 0B.0 fault/transaction Spike**，不得在文档阶段假装已经验证。

---

## 7. ACCEPT｜Parent Communication 是不可变沟通事件

这是 Round 2 前的重要修订。

主语义：
- Draft 可编辑；
- Finalized = 一次真实沟通 event；
- outbound finalized 后，家长后来异步回复 → **新增 inbound event**；
- 可 `reply_to` 原 communication；
- 电话/面谈同一 interaction 可一条 `conversation` event；
- Thread 是 events 聚合，不是 mutable finalized row。

因此不允许：

> finalized outbound 晚上收到回复后，回头修改旧 row 的 guardian_response。

同时支持：
- 多 recipients；
- home support；
- guardian_report Evidence source；
- Case-related communicate Action；
- non-case 轻量 communication follow-up；
- correction 保留原 finalized 历史。

V1 Internal Pilot 在 Student/Case context 提供最小家校闭环；独立家校工作台仍 V1.1。

**Decision：ACCEPT，已回写 Foundation。**

---

## 8. ACCEPT｜Reports 继续承载 Stage Review

不新增 `stage_reviews` 平行表。

Reports 强化：
- report_type；
- source_cutoff；
- content snapshot；
- version；
- finalized_by/time；
- correction/supersede。

系统整理事实，教师只写真正需要专业判断的：
- 整体进步；
- 遗留问题；
- 下一阶段计划。

Finalized Report ≠ 已告知家长。

V1 第一轮短周期 Pilot 不强迫每人完成阶段报告，但数据/领域路径不得被破坏；独立报告工作台仍 V1.1。

**Decision：ACCEPT。**

---

## 9. DERIVE｜周度、顽固、治理异常

继续不建：
- `weekly_tracking` 平行表；
- `stubborn_cases`；
- `governance_anomalies` 常驻第二套业务表。

从真实事实派生：
- 周度进展；
- long-running / failed / reopened Case；
- orphan；
- overdue；
- long pending verification；
- stale Quick Capture；
- handoff remaining；
- inactive Profile 下残留 pending Action；
- active Profile formal open Case 无 primary Action；
- communication follow-up due；
- duplicate Student candidate。

这些是可处理事实，不是教师效能分/学生风险分。

**Decision：DERIVE。**

---

## 10. ACCEPT｜Teaching Fact Gate

任何成员要作为实际教学 actor 写：
- Intervention；
- Assessment；
- 教学型 Evidence；
- Lesson teacher；

必须满足：

```text
live session
+ active membership
+ teacher capability
+ matching teaching scope
+ active Subject Profile
+ Student Assignment / Lesson relationship
+ operation permission
```

Subject Lead / Academic Admin / Org Admin / Advisor 的管理权限本身都不能绕过。

**Decision：ACCEPT，已回写 Auth/Data/Commands/Product。**

---

## 11. P0 PENDING SPIKE｜Cloud/Auth Portability

### P0-A｜Auth identity type
Supabase 与 CloudBase Auth user ID 类型不同，正式 migrations 前比较：
- provider-specific PK；
- business Profile UUID + external auth subject；
- text auth subject / weak-coupled identity link。

### P0-B｜Revoked Session Security
必须证明 signOut/reset/disabled 后旧 Access Token 不能继续读学生数据。

Supabase `session_id → auth.sessions` 只是 reference；CloudBase/其他 provider 必须达到等价安全结果。

### 其他 Spike
- Windows/Android Auth；
- RLS scope+assignment；
- RPC/transaction/version conflict；
- private Storage；
- export/restore；
- 大陆网络；
- migration automation。

**Decision：PENDING Phase 0B.0；任何正式 business migration 前的硬 Gate。**

---

## 12. REJECT｜Realtime 作为 correctness 前置

V1 correctness 继续依赖：
- page enter；
- save refresh；
- App resume；
- manual refresh。

Realtime 以后可 enhancement，但需新 ADR/安全测试。

**Decision：REJECT Realtime-as-core。**

---

## 13. Foundation 回写状态

已回写：
- `PRODUCT.md`
- `DATA_MODEL.md`
- `COMMANDS_AND_INVARIANTS.md`
- `AUTH_AND_PERMISSIONS.md`

配套事实源：
- Leadership Teaching Model；
- Excel Source Provenance；
- Domain Glossary；
- Teacher Subject Assignments；
- Role Workflow Matrix；
- Initial Diagnosis；
- Case Workflow Templates；
- Lesson Workflow；
- Parent Communication Workflow；
- Stage Review Workflow；
- Institutional Governance；
- Reliability & Concurrency；
- Cloud Backend Decision。

---

## 14. 进入 Phase 0B 的 Gate

Phase 0A.6 结束前必须：
1. Round 2 Product Completeness Audit 无内部 P0/P1 blocker；
2. 四份 Foundation 对 Case/Profile/Permission/Parent event 给出一致语义；
3. P0 Cloud/Auth 未验证项明确转交 Phase 0B.0，且禁止正式 migrations 先行；
4. Initial Diagnosis Snapshot 继续显式 deferred，不暗中建表；
5. 小班 Lesson transaction boundary 明确 PENDING SPIKE；
6. final PR Head CI success；
7. 独立终审通过。

随后：

```text
Phase 0A.6 merge
→ Phase 0B.0 Cloud/Auth Compatibility Spike（虚构数据）
→ 解 P0 Auth ID / revoked-session / provider gate
→ Phase 0B.1 正式 Auth/Membership/RLS + Vertical Slice
```
