# Teacher / Subject / Student Assignments｜教师学科范围与学生分配

> Phase 0A.6 事实源。冻结一个老师可教多科、一个学生可由多位老师协作，以及 Membership / Subject Scope / Subject Profile / Assignment 的边界。

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

## 3. Committed active assignment invariant

必须同时：
- organization 一致；
- membership active；
- teacher capability；
- matching active teaching scope；
- Subject Profile active；
- Lead uniqueness/时间合法。

Committed inactive/archived Profile 不得 active teacher assignment。

## 4. Teaching Fact Gate

Teaching Evidence / Intervention / Assessment / Lesson teacher / **Quick Capture new Case** 必须：

```text
live session
+ active membership
+ teacher capability
+ active teaching scope
+ active Subject Profile
+ legal active Student Teacher Assignment
+ operation permission
```

Advisor-only/management-only 不可借 Quick Capture 创建 teaching Case。

Actor Gate：`start_lesson` 的执行 actor 必须有 live active authenticated identity、valid active session、active membership、teacher capability、required teaching Subject Scope 与 operation permission。Per-Student Participant Gate：每一个 Student participant 另须有 active Profile、current/legal Student、actor 对 Student+Subject 的 legal active assignment、及一致的 organization/subject/Lesson context；live identity/session 不属于 participant。已有 `lesson_students` 不能成为权限来源。assignment 在课中撤销后 fail closed；temporary substitute 只能走 time-bounded collaborator assignment，治理 actor 仅可 controlled cancel/cleanup。


## 5. Lead / Collaborator

Lead：主要负责教师、默认 Case owner 候选、关键专业确认。

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

## 9. Reassign

`reassign_teacher` 一个事务：旧/新 assignment + Case owner + pending Action assignee + event/audit + final no-orphan validation。

高风险 event/audit 绑定 operation_id stable keys；重复 operation 不重复副作用。

## 10. Teacher exits one subject

`revoke_teacher_subject_scope_and_handoff`：只处理目标 subject 的 assignments/owners/Actions + scope end；其他科不受影响。单事务、operation_id、expected versions/locks、no orphan。

## 11. Membership disable

业务 DB handoff 先在单事务完成 assignments/owners/Actions/scopes/membership disabled；Auth session revoke 若属外部事务域则 fail-closed 重试。历史 actor 不重写。

## 12. Today

多学科 Teacher 的 Today 聚合本人所有**合法 active Profile + active assignment** 下 pending Actions，可 subject filter；filter 不是权限事实源。

Inactive/archived tracking suspended 不进入普通 Today。

## 13. Student Detail

从某学科 Action 进入保持该学科上下文；无权学科不泄露、不显示成“暂无数据”。Advisor 看授权摘要。

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

## 16. Negative tests

至少：
- scope but no assignment → no Student detail/Quick Capture；
- Profile inactive + old assignment → teaching facts/new Case deny；
- pure Subject Lead/Admin/Advisor → Quick Capture deny；
- reactivate staging failure → old complete state；
- Student 第 N Profile stale → whole Student command rollback；
- target teacher scope changed after preview → stale_plan；
- handoff response lost → same operation_id returns original result。
