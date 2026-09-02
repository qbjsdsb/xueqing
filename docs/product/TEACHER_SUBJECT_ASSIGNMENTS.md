# Teacher / Subject / Student Assignments｜教师学科范围与学生分配

> 状态：Phase 0A.6 产品/领域事实源。目标：冻结“一个老师可以教多科、一个学生由多位老师协作”的真实机构关系，并明确**身份、学科范围、服务状态、学生分配不是同一件事**。

## 1. 已冻结的基础关系

Xueqing 区分：

```text
Auth Identity
≠ Organization Membership
≠ Role
≠ Subject Scope
≠ Student/Staff Assignment
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

同一学生/学科同一时点默认最多一个 active Lead。

### `student_staff_assignments`

```text
student
+ membership
+ advisor / homeroom / coordinator / other
```

班主任/学管不能伪装成学科教师。

---

## 2. 为什么必须有 Teacher Subject Scope

现有 Student Assignment 能回答：

> 乔老师是不是张三语文的 Lead？

但不能独立回答：

> 乔老师在这个机构被授权可以教哪些科？

不能只从 assignment 反推，因为新入职尚未分学生、暂时没有某科学生、Subject Lead 管理范围、老师退出某一科等场景都需要独立 scope。

因此冻结：

> **必须独立建模 membership ↔ organization subject scope。**

---

## 3. 三层关系必须分开

### Layer 1｜Organization Membership
回答这个人在机构里是谁、账号当前是否 active。

### Layer 2｜Membership Subject Scope
回答在哪些学科承担哪类 subject-scoped 能力。

候选：

```text
membership_subject_scopes
  membership_id
  organization_subject_id
  scope_kind = teaching / leadership
  active_from
  active_to
  status
```

例：

```text
乔老师
├─ 语文 / teaching
├─ 政治 / teaching
└─ 语文 / leadership
```

表示他教语文和政治，但只负责语文学科管理。

### Layer 3｜Student Subject Assignment
回答这个老师当前实际负责哪个学生的哪个学科。

例：

```text
乔老师
├─ 张三 · 语文 · Lead
├─ 李四 · 语文 · Lead
└─ 王五 · 政治 · Collaborator
```

---

## 4. Scope 不是数据通行证

Teaching scope 只表示：

> 可以在该学科承担教师类业务关系。

它绝不意味着自动读取该学科所有学生。

普通教师访问具体 Student+Subject，至少需要：

```text
live session
+ active membership
+ teacher capability
+ matching active teaching subject scope
+ target Student Subject Profile = active
+ matching active student_teacher_assignment
+ operation-specific permission
```

因此：

> **Subject Scope 限制 Assignment 能否成立；active Profile 决定该学科服务是否正在进行；Assignment 决定普通教师具体学生范围。**

---

## 5. Assignment 建立不变量

管理员创建 active `student_teacher_assignment` 时必须检查：

1. organization 一致；
2. membership=active；
3. membership 具备 teacher capability；
4. matching active `teaching` scope；
5. Student 属于同机构；
6. **对应 Student Subject Profile 必须存在且 status=active；**
7. 同 student+subject 不违反 active Lead 唯一规则；
8. 时间区间不产生非法重叠；
9. 写 audit/history。

如果 Profile 不存在/inactive/archived：
- 不能直接创建 active teacher assignment；
- 必须先通过受控 Student Subject service lifecycle workflow 建立/恢复 Profile；
- archived 必须先 unarchive→inactive，再经过 reactivate reconciliation→active。

不得让 Flutter ViewModel 任意 insert 绕过。

---

## 6. Lead / Collaborator

### Lead
某 student+subject 的主要负责教师。

默认职责：理解当前学情、默认 Case owner 候选、关键专业确认、保持 primary Action 连续、参与阶段学科复盘。

Lead 不是组织角色，不自动成为 Subject Lead/管理员，也不绕过 Session/Profile/RLS。

### Collaborator
某 student+subject 的协作教师，可在完整 Teaching Fact Gate 成立时：
- 查看协作所需详情；
- 记录本人真实 Evidence / Intervention / Assessment；
- 承担明确 Action；
- 参与本人真实 Lesson。

但不无条件覆盖 Lead 的专业判断；关键 Case command 仍按 owner/capability policy。

---

## 7. Advisor / Homeroom / Coordinator

使用 `student_staff_assignments`，不使用 teacher assignment。

### Advisor
可以查看被分配学生的跨学科必要摘要、协调教师、组织家校、跟进综合事项。

不能假装学科教师、随意修改 root cause/Assessment、通过 Advisor 自动获得全机构学生。

Homeroom/Coordinator 同理，具体 UI 随机构真实组织结构。

---

## 8. Subject Lead

`subject_lead` role 还必须匹配 `leadership` subject scope。

例如：

```text
roles = teacher + subject_lead
teaching scopes = 语文 / 历史
leadership scopes = 语文
```

表示教语文和历史，但只负责语文管理。

Subject Lead 可以有本科专业审阅/治理视角，但：
- 不自动成为 Student teacher；
- 不自动成为 Case owner；
- 不因 leadership scope 产生教学事实；
- 真实授课时仍必须通过完整 Teaching Fact Gate。

---

## 9. Academic / Org Admin

Admin 可以处理 assignment、orphan、handoff、duplicate 等治理问题，但必须遵守最小必要数据与 audit。

管理权限不意味着可以伪装成实际授课教师。

如果 admin 亲自授课，仍需：

```text
teacher capability
+ teaching scope
+ active Subject Profile
+ active student assignment / controlled Lesson relationship
+ live session
+ operation permission
```

---

## 10. Today 在多学科教师下如何工作

一名老师同时教语文、政治、历史时，Today 默认聚合其所有**当前合法 active teaching relationship** 下的事项。

```text
我的工作
├─ overdue
├─ today
├─ pending verification
├─ future
└─ undated
```

事项必须来自：
- assigned_membership_id=当前老师；
- matching active Profile；
- 合法 active assignment；
- Action 本身仍 pending。

Inactive/archived Profile 下 suspended Case/Action 不进入普通 Today。

可按 subject filter 查看，但 filter 不是权限事实源。

---

## 11. Student Detail 多学科上下文

同一个 Student 可有多个 Subject Profile。

从 Today 某条语文 Action 进入时默认保持语文上下文；有权限才可显式切其他科；未授权学科不泄露细节。

Advisor 从综合入口看授权摘要，但专业 Case 仍显示明确学科与来源 actor。

---

## 12. 新老师入职流程中的 Subject Scope

推荐：

```text
Provision membership
→ onboarding
→ roles
→ teaching/leadership scopes
→ complete onboarding
→ membership active
→ Student Subject Profile active
→ student assignments
```

onboarding 可以预配置 scope，但 membership active + Profile active 前不能形成 active student teacher assignment。

---

## 13. 分配学生的管理 UX

```text
选择学生
→ 选择学科
→ 验证 Subject Profile=active
→ 只列出 active membership + teacher capability + active teaching scope
→ 选择 Lead / Collaborator
→ 检查冲突
→ 确认
```

没有 teaching scope 时提示先调整范围；Profile inactive/archived 时提示先恢复学科服务；不得静默帮管理员扩权限或恢复服务。

---

## 14. 普通 Reassign

`reassign_teacher` 需要考虑：
- Subject Profile=active；
- active assignment；
- Case ownership；
- pending Action assignee；
- 当前 Lesson；
- timeline/audit；
- 新老师 active teaching scope。

换老师后 Subject Profile 和 Case history 不新建、不清空。

---

## 15. 老师仍在职但退出某一科

例如乔老师继续教语文，但不再教政治。

不能直接删除政治 teaching scope，因为可能仍有 active assignments、owned Cases、pending Actions、future Lesson context。

受控流程：
1. inventory 该 subject active assignments；
2. inventory Case ownership；
3. inventory pending Actions；
4. 指定合法接手人；
5. 新接手人必须 active + teacher capability + same teaching scope + active Profile relation；
6. 完成交接；
7. 验证无 orphan；
8. 最后结束旧 scope；
9. audit。

使用 `revoke_teacher_subject_scope_and_handoff` 或等价 command，不普通 DELETE/UPDATE。

---

## 16. Membership disabled / 离职

`disable_membership_and_handoff` inventory：

```text
student assignments
+ staff assignments
+ subject scopes
+ Case ownership
+ pending Actions
→ handoff
→ verify no orphan
→ membership disabled
→ revoke Sessions
```

历史 creator/teacher/scope/assignment 不重写。

---

## 17. Scope / Assignment 历史

不物理删除正常历史。至少可解释何时开始/结束某科 scope、何时 assignment 生效/结束、谁调整、为什么过去存在某 Intervention。

精确实现可用 active_from/active_to/status/audit。

---

## 18. 数据不变量

1. active student teacher assignment 必须匹配 active teaching scope；
2. **active student teacher assignment 必须匹配 active Student Subject Profile；**
3. Subject Lead subject-scoped 权限必须匹配 leadership scope；
4. scope/membership/subject/assignment/Profile organization 必须一致；
5. 同 student+subject 默认最多一个 active Lead；
6. teacher role/teaching scope 不授予未 assigned Student 的普通教师访问；
7. 撤销 teaching scope 前必须交接对应 active responsibilities；
8. Profile deactivation/archive 前必须结束 active teacher assignments；
9. inactive/archived Profile 不允许新的 active teacher assignment；
10. disabled membership 不得保留 active subject scope/assignment；
11. historical scope/assignment 不因停用物理删除。

---

## 19. RLS / Permission 推导原则

### Teacher

```text
live session
+ active membership
+ teacher capability
+ active teaching scope
+ target Subject Profile = active
+ matching active student_teacher_assignment
+ operation permission
```

### Subject Lead

```text
live session
+ active membership
+ subject_lead capability
+ matching leadership scope
```

再按具体表/操作决定治理 read/write；如要写实际教学事实仍需完整 Teaching Fact Gate。

### Advisor

```text
live session
+ active membership
+ student_advisor capability
+ matching active student_staff_assignment
```

不通过 teaching scope 冒充教师。

### Admin
org-level governance；高风险写走 command/audit，不能 bypass Teaching Fact Gate。

---

## 20. 典型场景验收

### A. 一位老师教三科
合法，Today 只显示三科中真正分配且 Profile active 的 Action。

### B. 有语文 scope，但没有张三 assignment
不能读取张三语文完整学情。

### C. 张三语文 Lead + Collaborator
两者都必须有语文 teaching scope，且张三语文 Profile=active。

### D. Teacher A 是语文 Subject Lead、还教历史
Leadership scope 只在语文生效，不自动拥有历史管理视角。

### E. Advisor 负责张三
可见授权跨学科摘要，不拥有语文 Case 专业编辑权。

### F. 乔老师不再教政治但继续语文
先政治 handoff，再结束政治 scope；membership 继续 active。

### G. 张三数学 Profile inactive，但旧 assignment 因故障仍存在
任何 Intervention/Assessment/Lesson 写入必须被 RLS/command 拒绝；治理异常提示清理旧 assignment。

### H. 张三数学 Profile archived
不能直接创建 active assignment；必须：

```text
unarchive Profile → inactive
→ reactivate reconciliation
→ active
→ 才能建立/恢复 active assignment / 教学事实
```

---

## 21. Foundation 对齐

本文件与以下事实源必须使用同一硬定义：
- `DATA_MODEL.md`
- `COMMANDS_AND_INVARIANTS.md`
- `AUTH_AND_PERMISSIONS.md`
- `ROLE_WORKFLOW_MATRIX.md`

统一 Teaching Fact Gate：

```text
live session
+ active membership
+ teacher capability
+ active teaching scope
+ active Subject Profile
+ legal Student/Lesson relationship
+ operation permission
```

---

## 22. 决策结论

1. 一名教师可拥有多个学科范围。
2. Teacher Subject Scope 与 Student Assignment 独立建模。
3. Scope 不授予全学科学生访问。
4. **active Profile 是 active teacher assignment 和实际教学事实的硬前置。**
5. Lead/Collaborator 是 student+subject 关系，不是全局 role。
6. Advisor 使用 staff assignment，不伪装教师。
7. Subject Lead 需要 leadership scope。
8. 普通教师继续 assignment-level access。
9. 结束某 teaching scope 先 handoff。
10. inactive/archived Profile 不允许 active assignment；archive 恢复必须先 unarchive→inactive，再 reactivate。
11. 历史 scope/assignment/actor 必须可解释。
12. 精确 DDL/RLS 留 Phase 0B.0/0B.1，在通过独立审计后执行。
