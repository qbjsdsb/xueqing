# Phase 0A.6 Foundation Change Proposal

> 状态：Phase 0A.6 最终领域变更提案。本文集中记录对 `PRODUCT.md / DATA_MODEL.md / COMMANDS_AND_INVARIANTS.md / AUTH_AND_PERMISSIONS.md` 的必要修订。它不是 migration，也不授权进入真实 Auth/RLS/CRUD。

## 1. 决策纪律

每个缺口只允许归入：
- **ACCEPT**：已有充分产品依据，已/应回写 Foundation；
- **PENDING SPIKE**：需求真实，但实现必须由 Phase 0B.0 最小实验决定；
- **REJECT / DERIVE**：不新增领域对象，继续从已有事实派生。

判断标准：

> 这是新的真实业务事实，还是同一事实的另一种展示/总结？

如果只是展示/统计，默认派生；如果只是为了“表结构完整”，默认不建。

---

## 2. ACCEPT｜Role / Subject Scope / Assignment / Profile 四层业务授权关系

新增独立 `membership_subject_scopes`：
- membership；
- organization subject；
- `scope_kind = teaching / leadership`；
- active history。

冻结：
- Role 回答“能做哪类事”；
- Subject Scope 回答“在哪个学科有效”；
- Student Assignment 回答“具体负责哪个 Student + Subject”；
- **Subject Profile service state 回答“这门学科当前是否真的在持续教学”；**
- teaching scope 不授予全学科学生访问；
- leadership scope 不允许伪造 Intervention/Assessment/Lesson teacher。

active teacher assignment 必须匹配：

```text
active membership
+ teacher capability
+ active teaching scope
+ active Student Subject Profile
```

新增/强化学科级 handoff：`revoke_teacher_subject_scope_and_handoff`。

**Decision：ACCEPT，已回写 Foundation。**

---

## 3. ACCEPT｜Student Subject Profile 是教学主线 + 可恢复服务生命周期

Profile：
- `status = active / inactive / archived`；
- current positioning；
- strengths；
- version。

冻结完整状态机：

```text
active --deactivate--> inactive --archive--> archived
active <--reactivate-- inactive <--unarchive-- archived
```

规则：
- `archive` 只能 inactive→archived；
- `unarchive` 只能 archived→inactive；
- `reactivate` 只能 inactive→active；
- 禁止 active→archived、archived→active 直跳；
- unarchive 只恢复可管理状态，不恢复教学；
- reactivate 前必须重建 teacher assignment、Case owner、unresolved formal Case primary Actions。

最重要边界：

> **Subject service lifecycle 与 Learning Case resolution lifecycle 分开。**

Profile inactive/archived 下 unresolved Case：
- 保留真实 status；
- 当前 pending Actions 受控收口；
- 暂停进入 Today；
- 不要求 current primary Action；
- 不自动 closed/清零；
- 不允许普通教学事实/新 Lesson。

Primary Action 不变量精确为：

> **active Subject Profile 下的 formal open Case 必须有 pending primary Action。**

新增/冻结：
- `deactivate_student_subject_profile`
- `archive_student_subject_profile`
- `unarchive_student_subject_profile`
- `reactivate_student_subject_profile`

**Decision：ACCEPT，已回写 Foundation。**

---

## 4. ACCEPT｜Student lifecycle 同样区分 archive 与 merged

Student：

```text
active --deactivate_student--> inactive --archive_student--> archived
active <--reactivate_student-- inactive <--unarchive_student-- archived
```

- archived 可恢复，但只能先回 inactive；
- unarchive 不自动恢复 enrollment/Subject Profile/assignment；
- reactivate 逐实际恢复学科做 Profile reconciliation；
- `merged` 是终态，不可 unarchive/reactivate 为独立 Student。

**Decision：ACCEPT。**

---

## 5. DEFER WITH VALIDATION｜Initial Diagnosis Snapshot

Initial Diagnosis workflow 必须有，但不先建 `initial_diagnoses` 平行大表。

已有自然事实源：Student、Subject Profile、Evidence、Case、Action。

唯一可能新增的真实事实是第一次正式建档时的整体基线判断。Pilot 验证真实需求后，再决定是否做轻量 immutable snapshot/event。

**Decision：P2 DEFER。**

---

## 6. ACCEPT｜Initial Diagnosis 不能绕过 Teaching Fact Gate

管理员可以创建/恢复 Profile、建立合法 teacher assignment，但不能通过“授权初诊”跳过实际教学事实权限。

凡初诊会产生 Intervention、Assessment、教学型 Evidence、Lesson teacher 行为，必须通过完整 Teaching Fact Gate。

**Decision：ACCEPT，已回写 Initial Diagnosis / Auth / Role Matrix。**

---

## 7. ACCEPT｜三类 Case Workflow，不改六态生命周期

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

模板层必须尊重 suspended exception：inactive/archived Profile 下 formal open Case 可以没有 current primary Action。

**Decision：ACCEPT。**

---

## 8. ACCEPT｜Teaching Fact Gate｜跨事实源唯一硬定义

任何成员要作为实际教学 actor 写/确认 Intervention、Assessment、教学型 Evidence、Lesson teacher 行为，必须同时满足：

```text
live session
+ active membership
+ teacher capability
+ matching active teaching scope
+ target Student Subject Profile = active
+ legal active Student Assignment / controlled Lesson relationship
+ operation-specific permission
```

硬规则：
- `live session` 不能在 Data Model 文档里被省略；
- `active Profile` 不能写成“通常要求”；
- Admin/Subject Lead/Advisor 管理权限不能 bypass；
- inactive/archived Profile 即使存在遗留 assignment 也拒绝教学事实。

**Decision：ACCEPT，已回写 Auth/Data/Commands/Product/Role/Initial Diagnosis/Assignments。**

---

## 9. ACCEPT｜Lesson Workspace + 受控 start/complete

Lesson：课前看旧问题/到期/待验证；课中逐步可靠保存；课后 30–60 秒收口。

`start_lesson` / `complete_lesson` 均要求完整 Teaching Fact Gate，尤其 target Profile=active。

小班 transaction granularity 继续 **PENDING Phase 0B.0 fault/transaction Spike**。

---

## 10. ACCEPT｜Parent Communication 是不可变沟通事件

- Draft 可编辑；
- Finalized = 一次真实 event；
- outbound 后异步回复新增 inbound event；
- 可 `reply_to` 原 event；
- 电话/面谈同一 interaction 可 conversation event；
- Thread 是 events 聚合，不是 mutable finalized row；
- 多 recipients；
- guardian_report Evidence source；
- Case-related communicate Action；
- non-case 轻量 follow-up；
- correction 保留历史。

V1 Internal Pilot 在 Student/Case context 提供最小闭环；独立家校工作台 V1.1。

---

## 11. ACCEPT｜Reports 继续承载 Stage Review

不新增 `stage_reviews` 平行表。

Reports 强化：report_type、source_cutoff、content snapshot、version、finalized_by/time、correction/supersede。

Finalized Report ≠ 已告知家长。

---

## 12. DERIVE｜周度、顽固、治理异常

不建 weekly_tracking / stubborn_cases / 常驻第二套 anomaly 业务表。

从真实事实派生周度、long-running、failed/reopened、orphan、overdue、stale Quick Capture、handoff remaining、inactive/archived Profile 残留 Action、active Profile formal Case 无 primary Action、communication follow-up due、duplicate candidate 等。

这些是可处理事实，不是教师效能分/学生风险分。

---

## 13. P0 PENDING SPIKE｜Cloud/Auth Portability

### P0-A｜Auth identity type
Supabase 与 CloudBase Auth ID 类型不同；正式 migrations 前比较 provider-specific PK、business UUID + external subject、text auth subject 等方案。

### P0-B｜Revoked Session Security
必须证明 signOut/reset/disabled 后旧 Access Token 不能继续读学生数据。

Supabase `session_id → auth.sessions` 只是 reference；其他 provider 必须达到等价结果。

其他 Spike：Windows/Android Auth、RLS、RPC/transaction/version conflict、private Storage、export/restore、大陆网络、migration automation。

**Decision：PENDING Phase 0B.0；任何正式 business migration 前硬 Gate。**

---

## 14. REJECT｜Realtime 作为 correctness 前置

V1 correctness 继续依赖 page enter/save refresh/App resume/manual refresh。Realtime 以后 enhancement，需新 ADR/安全测试。

---

## 15. Foundation 回写状态

已/应保持同步：
- `PRODUCT.md`
- `DATA_MODEL.md`
- `COMMANDS_AND_INVARIANTS.md`
- `AUTH_AND_PERMISSIONS.md`
- `DOMAIN_GLOSSARY.md`
- `TEACHER_SUBJECT_ASSIGNMENTS.md`
- `ROLE_WORKFLOW_MATRIX.md`
- `INITIAL_DIAGNOSIS_WORKFLOW.md`
- `CASE_WORKFLOW_TEMPLATES.md`
- `LESSON_WORKFLOW.md`

以及家校、阶段复盘、治理、可靠性、Cloud 决策等配套事实源。

---

## 16. Independent Audit Remediation｜2026-09-02

独立审计对原 Head `2207290...` 给出 `CHANGES REQUIRED`，三个 P1：

1. Teaching Fact Gate 跨事实源不一致；
2. inactive/archived Profile 下 Case Action 规则冲突；
3. archived Student/Profile 的归档—回归状态机未定义。

当前修复方向已冻结为：
- Teaching Fact Gate 七项硬条件全局统一；
- primary Action 不变量只对 active Profile 的 formal open Case 强制；
- Student/Profile 都采用 `active → inactive → archived`，恢复 `archived → inactive → active`；
- merged Student 终态；
- 管理员不能绕过 Gate。

修复后必须重新执行独立审计，不能沿用旧 PASS/CI 证据。

---

## 17. 进入 Phase 0B 的 Gate

Phase 0A.6 结束前必须：
1. Independent Product Completeness Audit 无 P0/P1 blocker；
2. 所有核心事实源对 Teaching Gate / Case Action / archive lifecycle 给出一致语义；
3. P0 Cloud/Auth 未验证项明确转交 Phase 0B.0，且禁止正式 migrations 先行；
4. Initial Diagnosis Snapshot 继续显式 deferred；
5. 小班 Lesson transaction boundary 明确 PENDING SPIKE；
6. **修复后的最终 PR Head CI success；**
7. 独立终审明确 `PASS — READY FOR MERGE`。

随后：

```text
Phase 0A.6 merge
→ Phase 0B.0 Cloud/Auth Compatibility Spike（虚构数据）
→ 解 P0 Auth ID / revoked-session / provider gate
→ Phase 0B.1 正式 Auth/Membership/RLS + Vertical Slice
```
