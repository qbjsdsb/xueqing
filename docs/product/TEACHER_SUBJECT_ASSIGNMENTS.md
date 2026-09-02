# Teacher / Subject / Student Assignments｜教师学科范围与学生分配

> 状态：Phase 0A.6 产品/领域事实源。目标：冻结一个老师可教多科、一个学生可由多位老师协作，以及 Membership / Subject Scope / Subject Profile / Assignment 的真实边界。

## 1. 基础关系

```text
Auth Identity
≠ Organization Membership
≠ Role / Capability
≠ Subject Scope
≠ Student / Staff Assignment
≠ Student Subject Profile service state
```

### `student_teacher_assignments`

```text
student
+ organization_subject
+ membership
+ assignment_role = lead / collaborator
+ active period/status
```

同一 student+subject 同一时点默认最多一个 active Lead。

### `student_staff_assignments`

```text
student
+ membership
+ advisor / homeroom / coordinator / other
```

班主任/学管不能伪装成学科教师。

---

## 2. 为什么需要 Teacher Subject Scope

Student Assignment 只能回答：

> 乔老师是不是张三语文的 Lead？

不能回答：

> 乔老师在机构里被授权教哪些学科？

因此独立建模：

```text
membership_subject_scopes
  membership_id
  organization_subject_id
  scope_kind = teaching / leadership
  active_from
  active_to
  status
```

示例：

```text
乔老师
├─ 语文 / teaching
├─ 政治 / teaching
└─ 语文 / leadership
```

表示教语文和政治，但只负责语文学科管理。

---

## 3. Scope 不是数据通行证

Teaching scope 只表示“可以在该学科承担教师类业务关系”，不授予全学科学生访问。

普通教师访问某 Student+Subject 至少需要：

```text
live session
+ active membership
+ teacher capability
+ matching active teaching scope
+ target Student Subject Profile = active
+ matching active student_teacher_assignment
+ operation-specific permission
```

因此：

> Scope 限制“可否被分配”；Profile 决定“这门学科当前是否在持续服务”；Assignment 决定“普通教师具体负责谁”。

---

## 4. Committed-state invariant｜必须和 lifecycle transaction 分开理解

### 正常提交态硬规则

一个 **committed active `student_teacher_assignment`** 必须同时匹配：
1. organization 一致；
2. membership=active；
3. teacher capability；
4. matching active `teaching` scope；
5. Student Subject Profile=active；
6. Lead 唯一/时间区间合法。

一个 **committed inactive/archived Profile** 不得存在 active teacher assignment。

### 生命周期 command 的事务内部 staging

`reactivate_student_subject_profile` 是单一原子事务。

事务开始时合法旧状态：

```text
Profile = inactive
active assignment = none
formal unresolved Cases 可以暂时无 current owner/primary Action
```

事务内部可以 stage：
- target active assignment；
- owner；
- primary Actions；
- tracking-resumed events；
- Profile=active。

**这些 staging 不得独立 commit，也不得被其他 Session 看到。**

事务 commit 时才一次性变成：

```text
Profile = active
+ legal active assignment
+ each formal open Case has legal owner
+ each formal open Case has pending primary Action
```

因此“active assignment 必须匹配 active Profile”约束的是**提交后的数据库状态**，不是要求同一数据库事务里的每一个 SQL 语句执行瞬间都独立成为可提交业务状态。

同理，`deactivate_student_subject_profile` 在同一事务内 stage：
- 结束 assignments；
- 结束 current responsibility；
- 完成/取消 pending Actions；
- tracking-suspended events；
- Profile=inactive；

然后一次 commit。

禁止把“先结束 assignment，再另一个 API 把 Profile 设 inactive”暴露为两次 committed writes。

---

## 5. Lifecycle transaction hard rules

所有下列操作必须走受控 command，而不是 Flutter 普通 CRUD：
- `deactivate_student_subject_profile`
- `archive_student_subject_profile`
- `unarchive_student_subject_profile`
- `reactivate_student_subject_profile`
- `reassign_teacher`
- `revoke_teacher_subject_scope_and_handoff`
- membership disable handoff
- Student deactivate/reactivate 涉及的多 Profile reconciliation。

共同要求：
- `operation_id`；
- `expected_version`；
- 单一业务 DB transaction；
- commit 前验证最终不变量；
- 任一步失败整单 rollback；
- timeout 后按 operation_id 查询，不用客户端 CRUD 补齐。

### 失败后的合法结果只有两种

#### command 未 commit
保持完整旧状态。

#### command 已 commit
得到完整新状态。

不允许正常命令产生：
- inactive Profile + active assignment；
- active Profile + formal open Case 无 owner/primary Action；
- 一半老师已交接、一半 owner/Action 仍 orphan。

检测到这些状态应视为数据完整性/运维异常，而不是普通 UI 恢复流程。

---

## 6. Lead / Collaborator

### Lead
某 student+subject 的主要负责教师。

默认职责：
- 理解当前学情；
- 默认 Case owner 候选；
- 关键专业确认；
- 保持 primary Action 连续；
- 参与阶段学科复盘。

Lead 不是组织角色，不自动成为 Subject Lead/Admin。

### Collaborator
在完整 Teaching Fact Gate 成立时可：
- 看协作所需详情；
- 记录本人真实 Evidence / Intervention / Assessment；
- 承担明确 Action；
- 参与本人真实 Lesson。

如果不是当前 owner，不自动获得 stable/close/reopen 等所有关键命令。

---

## 7. Advisor / Homeroom / Coordinator

使用 `student_staff_assignments`。

Advisor 可看授权跨学科摘要、协调教师、组织家校、跟进综合事项，但不能：
- 伪装学科教师；
- 修改 Assessment；
- 随意改 root cause；
- close/reopen 学科 Case；
- 通过 staff role 自动获得全机构学生。

---

## 8. Subject Lead

Subject Lead 必须匹配 `leadership` scope。

例如：

```text
roles = teacher + subject_lead
teaching scopes = 语文 / 历史
leadership scopes = 语文
```

Subject Lead：
- 可有本科治理/审阅视角；
- 不自动成为 Student teacher；
- 不自动成为 Case owner；
- 不因 leadership scope 产生教学事实；
- 真正授课仍需完整 Teaching Fact Gate。

---

## 9. Academic / Org Admin

Admin 可以处理 assignment、orphan、handoff、duplicate、archive/reactivate 等治理命令，但管理权限不能伪造授课事实。

如果 Admin 本人授课，仍需：

```text
live session
+ active membership
+ teacher capability
+ teaching scope
+ active Subject Profile
+ active Student Assignment / validated Lesson relationship
+ operation permission
```

---

## 10. Today 在多学科教师下如何工作

一位老师同时教多科时，Today 默认聚合所有**当前合法 committed teaching relationships** 下的 pending Actions：

```text
我的工作
├─ overdue
├─ today
├─ pending verification
├─ future
└─ undated
```

进入 Today 的 Action 必须同时满足：
- assigned_membership_id=当前老师；
- Profile=active；
- legal active assignment；
- Action=pending。

inactive/archived Profile 下 suspended Case 不进入普通 Today。

---

## 11. Student Detail 多学科上下文

同一个 Student 可以多个 Subject Profiles。

从语文 Action 进入时保持语文上下文；只有有权限才切其他科。Advisor 从综合入口看授权摘要，但专业 Case 始终显示明确学科与来源 actor。

No permission ≠ empty data。

---

## 12. 新老师入职

```text
Provision membership
→ onboarding
→ roles
→ teaching/leadership scopes
→ complete onboarding
→ membership active
→ active Subject Profile
→ student assignment
```

onboarding 可预配置 scope，但 membership active + Profile active 前不能形成 committed active teacher assignment。

---

## 13. 分配学生管理 UX

```text
选择学生
→ 选择学科
→ 验证 Profile=active
→ 只列 active membership + teacher capability + active teaching scope
→ 选择 Lead / Collaborator
→ 检查冲突
→ 受控 command 提交
```

Profile inactive/archived 时提示先恢复学科服务；不得静默扩权限或绕过 service lifecycle。

---

## 14. 普通 Reassign

`reassign_teacher` 必须在**一个事务**中处理：
- 旧/新 assignment；
- Case owner；
- pending Action assignee；
- history/events/audit；
- Lead uniqueness；
- final no-orphan validation。

失败整单 rollback，不直接覆盖历史 membership_id。

---

## 15. 老师仍在职但退出某科

`revoke_teacher_subject_scope_and_handoff`：
1. inventory 该科 active assignments/owners/pending Actions；
2. 验证接手人；
3. 同一事务 staged 新 assignment + owner/Action handoff + 旧 assignment end + teaching scope end；
4. commit 前验证无 orphan，其他学科不受影响；
5. audit；
6. commit。

任一步失败全部 rollback。

---

## 16. Membership disabled / 离职

业务 DB handoff：

```text
student/staff assignments
+ subject scopes
+ Case owners
+ pending Actions
→ staged handoff
→ membership disabled
→ validate no orphan
→ commit
```

Session revoke 属于可能不同的 Auth 事务域：DB membership disabled 必须先保证 RLS fail-closed；随后 revoke old Sessions，可安全重试。

历史 creator/teacher/scope/assignment 不重写。

---

## 17. Scope / Assignment 历史

正常历史不物理删除。至少解释：
- 何时 scope 生效/结束；
- 何时 assignment 生效/结束；
- 谁调整；
- 为什么过去存在某教学事实。

---

## 18. 数据不变量｜Committed State

1. active assignment 必须 active membership；
2. active assignment 必须 matching active teaching scope；
3. **active assignment 必须 Profile=active；**
4. Subject Lead 权限必须 leadership scope；
5. scope/membership/subject/assignment/Profile organization 一致；
6. 默认最多一个 active Lead；
7. teacher role/scope 不授予未 assigned Student；
8. revoke teaching scope 前 handoff；
9. committed inactive/archived Profile 不得 active assignment；
10. disabled membership 不得 active assignment/scope；
11. historical relations 不因停用物理删除。

这些是 commit 后不变量。生命周期 command 的事务内部 staging 由 §4/§5 解释。

---

## 19. RLS / Permission 推导

### Teacher

```text
live session
+ active membership
+ teacher capability
+ active teaching scope
+ Profile=active
+ active student_teacher_assignment
+ operation permission
```

### Subject Lead

```text
live session
+ active membership
+ subject_lead capability
+ leadership scope
```

写实际教学事实仍需完整 Teaching Fact Gate。

### Advisor

```text
live session
+ active membership
+ student_advisor capability
+ active student_staff_assignment
```

### Admin
org-level governance；高风险写走 command/audit，不能 bypass Teaching Fact Gate。

---

## 20. 典型场景验收

### A. 一位老师教三科
合法。Today 只显示真实 assigned + active Profile 的事项。

### B. 有语文 scope，无张三 assignment
不能读取张三语文完整学情。

### C. Lead + Collaborator
两者都需 teaching scope + active Profile；默认最多一个 active Lead。

### D. Subject Lead 还教其他科
Leadership scope 只在对应科生效。

### E. Advisor
看授权摘要，不拥有专业 Case 修改权。

### F. 老师退出政治但继续语文
政治 handoff + scope end 同一事务；语文不受影响。

### G. Profile inactive 但故障残留 active assignment
这是**非法 committed state**：
- Teaching Fact Gate 仍拒绝写入；
- governance anomaly 报警；
- 不由客户端继续教学；
- 需要受控治理修复。

### H. Profile archived
必须 unarchive→inactive；不能直接 active assignment。

### I. Reactivate 事务在“已 stage assignment”后失败
期望：整单 rollback；commit 后仍是 inactive Profile + 无 active assignment/owner/new Action。

### J. Reactivate 事务 commit 成功但客户端 timeout
用同一 operation_id 查询；必须得到完整：active Profile + legal assignment + owner + primary Actions。不得重复创建。

### K. Deactivate 事务在取消 Action 后失败
期望：整单 rollback；旧 active Profile、assignment、owner、Action 仍完整存在。

### L. Deactivate commit 成功但 response lost
查询 operation result；必须得到完整 inactive 状态，无 active assignment/ordinary pending Action。

---

## 21. Foundation 对齐

本文件与以下事实源必须使用相同概念：
- `DATA_MODEL.md`
- `COMMANDS_AND_INVARIANTS.md`
- `AUTH_AND_PERMISSIONS.md`
- `ROLE_WORKFLOW_MATRIX.md`
- `RELIABILITY_AND_CONCURRENCY.md`

Teaching Fact Gate：

```text
live session
+ active membership
+ teacher capability
+ active teaching scope
+ active Subject Profile
+ legal Student/Lesson relationship
+ operation permission
```

Lifecycle atomicity：

> Profile/Student status + assignment + owner + primary Action 的服务生命周期变化是一个受控原子 command；事务内部 staging 不对外可见，commit 后必须一次满足全部 committed-state invariants。

---

## 22. 决策结论

1. 一名教师可有多个学科范围。
2. Subject Scope 与 Student Assignment 独立。
3. Scope 不授予全学科学生访问。
4. active Profile 是 committed active assignment 和教学事实的硬前置。
5. Lead/Collaborator 是 student+subject 关系。
6. Advisor 使用 staff assignment。
7. Subject Lead 需要 leadership scope。
8. 普通教师继续 assignment-level access。
9. 结束 teaching scope 前必须原子 handoff。
10. inactive/archived Profile 提交态不允许 active assignment。
11. Reactivate/deactivate 必须同时事务化 Profile、assignment、owner、Actions，失败全回滚，timeout 使用 operation_id 恢复。
12. archive 恢复只能 unarchive→inactive→reactivate。
13. 历史 scope/assignment/actor 可解释。
14. 精确 DDL/RLS/deferrable validation 由 Phase 0B.0/0B.1 Spike 后实现。
