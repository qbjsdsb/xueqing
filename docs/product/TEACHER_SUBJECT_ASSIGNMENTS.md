# Teacher / Subject / Student Assignments｜教师学科范围与学生分配

> Phase 0A.6 起的关系事实源。冻结一个老师可教多科、一个学生可由多位老师协作，以及 Membership / Subject Scope / Subject Profile / Assignment 的边界。v0.3.8 起同时受 ADR-047 与 `docs/RESPONSIBILITY_MODEL.md` 约束。

## 1. 关系分层

```text
Auth Identity
≠ Organization Membership
≠ Role / Capability
≠ Subject Scope
≠ Student/Staff Assignment
≠ Subject Profile service state
```

### `membership_subject_scopes`
- membership
- organization_subject
- scope_kind=teaching/leadership
- active interval/status

### `student_teacher_assignments`
- student
- organization_subject
- membership
- assignment_role=lead/collaborator
- active interval/status

### `student_staff_assignments`
Advisor/homeroom/coordinator 等综合职责，不伪装学科教师。

## 2. Scope 不是数据通行证

Teaching scope 只表示可以承担该科 teacher assignment；普通教师访问具体 Student+Subject 仍需 active assignment + active Profile。

Leadership scope 只表示 Subject Lead 本科治理范围，不自动成为任课教师/Case owner。

机构负责人/管理员的 organization supervision capability 也不是 Student Teacher Assignment：它可以授予机构级监督入口，但不能自动成为 Personal Projection、Case owner 或 Action assignee 的责任来源。

## 3. Committed active assignment invariant

必须同时：
- organization 一致；
- membership active；
- teacher capability；
- matching active teaching scope；
- Subject Profile active；
- Lead uniqueness/时间合法。

Committed inactive/archived Profile 不得 active teacher assignment。

## 4. Teaching Fact Gate 与机构监督

### 4.1 Personal Scope / Responsible Teacher

Teaching Evidence / Intervention / Assessment / Lesson teacher / **Personal Quick Capture new Case** 必须：

```text
live session
+ active membership
+ teacher capability
+ active teaching scope
+ active Subject Profile
+ legal active Student Teacher Assignment
+ operation permission
```

Advisor-only 或 management-only 成员**不能仅凭身份成为 teaching Case owner**。

### 4.2 Organization Scope

负责人/管理员可以依据机构监督能力：

- 查看机构范围内的学情；
- 在 command policy 允许时监督已有 Case；
- 作为真实 actor 留下 Event/audit；
- 从机构视角为合法责任老师发起 responsibility-aware new Case。

但必须满足：

- 已有 Case 的监督操作不自动把 owner/assignee 改成管理者；
- 新 Case 的 Responsible Teacher 必须由 server 解析到目标 Profile 当前合法 Assignment；
- 默认责任人是 active Lead；
- 没有 active Lead 时 fail closed，先明确主责老师；
- 管理者本人只有在同时满足完整 Personal Teaching Fact Gate、确实是该 Profile 合法任课老师时，才能成为 owner。

因此“management-only 不能借 Quick Capture 把自己变成 teaching owner”与“管理者可在 Organization Scope 为合法责任老师发起 Case”并不矛盾。

Actor Gate：`start_lesson` 的执行 actor 必须有 live active authenticated identity、valid active session、active membership、teacher capability、required teaching Subject Scope 与 operation permission。Per-Student Participant Gate：每一个 Student participant 另须有 active Profile、current/legal Student、actor 对 Student+Subject 的 legal active assignment、及一致的 organization/subject/Lesson context；live identity/session 不属于 participant。已有 `lesson_students` 不能成为权限来源。assignment 在课中撤销后 fail closed；temporary substitute 只能走 time-bounded collaborator assignment，治理 actor 仅可 controlled cancel/cleanup。

### V1 Lesson authorization rule

V1 所有以教师本人责任身份发生的教学写权限必须依赖 legal active Student Teacher Assignment。Lesson 或 `lesson_students` participant 记录只表达实际参与事实，不能替代 assignment、grant temporary permission 或创建 capability/scope。

`start_lesson` 创建前必须为每个 participant 验证完整 Gate；仅有 teaching scope、把 Student 自己加入 participants、或 Lesson 已经 `in_progress` 都不能形成授权。临时代课统一用 time-bounded collaborator assignment（`active_from`/`active_to`），在有效期间按同一 Gate 工作。

## 5. Lead / Collaborator

Lead：主要负责教师、Organization Scope 新 Case 的默认 owner 候选、关键专业确认。

Collaborator：在 Gate 成立时可协作教学、记录本人事实、承担 Action；非 owner 不自动获得 stable/close/reopen 权限。

临时代课不另建 Lesson authorization。V1 通过 time-bounded collaborator assignment（`active_from`/`active_to`）提供完整 Gate；有效期结束后 assignment expired/ended，后续教学写入拒绝。

同 student+subject 同时默认最多一个 active Lead。

## 6. Subject Profile lifecycle transaction

Profile：active→inactive→archived；恢复 archived→inactive→active。

### Reactivate Profile
单一事务 stage：target assignment、owner、primary Actions、resumed event、Profile active。中间 staging 不对外 commit。

### Deactivate Profile
同一事务 stage：Action 收口、assignment end、owner end、suspended event、Profile inactive。

任一步失败整体 rollback。

## 7. Student multi-Profile lifecycle concurrency

`students.version` 只负责 Student root/current canonical/lifecycle snapshot，不是 child global counter。deactivate/archive/unarchive/reactivate 成功各 +1 exactly once；merge 时 source/target 各 +1 exactly once。普通 child append/transition 不机械递增 Student.version；source-only Profile safe reparent 时 Profile.version +1 exactly once。Student command 不能只写一个模糊 `expected_version`。

必须绑定/验证：
- `student_expected_version`；
- affected Profile expected versions；
- affected Case expected versions；
- preview 时 current assignment/owner/Action IDs；
- target membership/scope 当前状态。

事务按稳定 ID 顺序锁定/重读；任何 drift → stale_plan/version_conflict。

## 8. `reactivate_student` 与 archived Profiles

Selected Profiles 必须在 command 调用前已经 inactive。

如果 archived：先由用户显式独立执行 `unarchive_student_subject_profile`。

`reactivate_student` **不暗中跨事务调用 unarchive**，不使用未定义 Saga。

先前显式 unarchive 成功、后续 reactivate 失败时，Profile 合法停在 inactive；这不是 partial reactivate。

## 9. Reassign / responsibility handoff

Student Teacher Assignment handoff 与 Case/Action responsibility handoff 是两个不同业务事实。

已有安全策略应继续 fail closed：如果结束当前 Assignment 会让 open Case owner 或 pending Action assignee 成为不再合法的责任人，则先要求显式处理 Case/Action responsibility；不得因为换老师就无声重写学生成长历史。

未来 responsibility handoff command 需要：旧/新 assignment + Case owner + pending Action assignee + event/audit + final no-orphan validation，并使用 operation_id、expected versions/locks 保证并发安全。

## 10. Teacher exits one subject

`revoke_teacher_subject_scope_and_handoff`：只处理目标 subject 的 assignments/owners/Actions + scope end；其他科不受影响。单事务、operation_id、expected versions/locks、no orphan。

若现有实现采用“先阻止 scope/assignment 结束，要求显式责任处理”的更严格策略，应继续 fail closed，不得为了文档形式上的原子 handoff 而静默重写历史。

## 11. Membership disable

业务 DB handoff/责任清理必须先保证 assignments/owners/Actions/scopes 不留下 orphan responsibility；Auth session revoke 若属外部事务域则 fail-closed 重试。历史 actor 不重写。

## 12. Today

多学科 Teacher 的 **Personal Today** 只聚合本人所有合法 active Profile + active assignment 下、且 `assigned_membership_id` 指向本人的 pending primary Actions，可 subject filter；filter 不是权限事实源。

机构管理者的 Organization Projection 可以另行查看机构监督队列，但不能把全机构 Action 标记成“我的今日”。

Inactive/archived tracking suspended 不进入普通 Today。

## 13. Student Detail

Personal Scope 从某学科 Action 进入时保持该学科上下文；无权学科不泄露、不显示成“暂无数据”。

Organization Scope 由机构监督能力读取，但页面必须明确当前负责老师，不能把 supervisor 显示为默认责任人。

## 14. Assignment creation UX

```text
Student + Subject
→ verify Profile active
→ list active teacher memberships with teaching scope
→ Lead/Collaborator
→ conflict check
→ controlled command
```

Profile inactive/archived 先走 service lifecycle，不静默建 assignment。

## 15. Historical relation

Scope/Assignment 正常结束保留历史区间。离职/换科/停科/merge 不重写过去 teaching actor。

历史 Case owner 如果已经不满足当前 Assignment，应识别为“责任关系待确认”并显式治理，不通过 migration 批量替换。

## 16. Negative tests

至少：
- scope but no assignment → no Personal Student detail / Personal Quick Capture；
- Profile inactive + old assignment → teaching facts/new Case deny；
- management-only → Personal Projection 为空，不能仅凭管理角色成为 Case owner；
- manager supervision existing Case → actor=manager，owner/assignee 保持合法原责任；
- Organization Scope new Case → owner=合法 active Lead；
- Organization Scope no active Lead → deny；
- cross-org / ended / expired assignment → 不能作为 responsible membership；
- reactivate staging failure → old complete state；
- Student 第 N Profile stale → whole Student command rollback；
- target teacher scope changed after preview → stale_plan；
- handoff response lost → same operation_id returns original result。
