# Teacher / Subject / Student Assignments｜教师学科范围与学生分配

状态：Phase 0A.6 product/domain decision draft  
目标：冻结“一个老师可以教多科、一个学生由多位老师协作”的真实机构关系，并明确**身份、学科范围、学生分配不是同一件事**。

---

## 1. 当前 Foundation 已经做对的事情

现有 Foundation 已区分：

```text
Auth User
≠ Organization Membership
≠ Role
≠ Assignment
```

并已有：

### `student_teacher_assignments`

```text
student
+ organization_subject
+ membership
+ assignment_role = lead / collaborator
+ active period/status
```

规则：同一学生/学科同一时点默认最多一个 active Lead。

### `student_staff_assignments`

```text
student
+ membership
+ advisor / homeroom / coordinator / other
```

并明确：

> 班主任/学管不能伪装成学科教师。

这些设计继续保留。

---

# 2. 当前缺口：缺少“教师学科范围”

现有模型能回答：

> 乔老师是不是张三语文的 Lead？

但不能独立回答：

> 乔老师在这个机构被配置/授权可以教哪些科？

如果仅从 `student_teacher_assignments` 反推，会出现问题：

1. 新入职老师尚未分学生时无法表达可教学科；
2. 老师暂时没有某科学生，不代表失去该科授权；
3. 管理员分配学生时无法先验证“这个老师是否属于该学科”；
4. 一名老师多学科的组织配置没有独立事实；
5. Subject Lead 的学科范围无法仅靠 student assignment 表达；
6. 老师仍在职但不再教某一科时，没有受控撤销/交接语义。

因此 Phase 0A.6 决策：

> **必须新增独立的 membership ↔ organization subject scope 领域关系；不得从 Student Assignment 反推。**

精确数据库表名/DDL 留给 Data Model revision 和 Phase 0B migration；产品语义在本文件先冻结。

---

# 3. 三层关系必须分开

## Layer 1｜Organization Membership

回答：

> 这个人在机构里是谁？账号现在能否进入业务？

示例：

```text
乔老师
membership = active
roles = teacher
```

Membership 本身不说明教什么科，也不说明负责哪些学生。

---

## Layer 2｜Membership Subject Scope

回答：

> 这个 membership 在机构内被授权/配置可以在哪些学科承担哪类 subject-scoped 工作？

例：

```text
乔老师
├─ 语文：teaching
├─ 政治：teaching
└─ 历史：teaching
```

另一例：

```text
王老师
├─ 语文：teaching
└─ 语文：leadership
```

因此一个 membership 可以：
- 教一科；
- 教多科；
- 在某一科教学；
- 在另一科同时承担 subject leadership；
- teacher + subject lead 多角色组合。

### 推荐领域命名

候选：`membership_subject_scopes`

推荐概念字段：

```text
id
organization_id
membership_id
organization_subject_id
scope_kind = teaching / leadership
active_from
active_to
status
created_at
```

说明：
- `scope_kind` 是 subject-scoped 能力范围，不替代 `membership_roles`；
- `membership_roles` 回答“具有什么能力角色”；
- subject scope 回答“这个角色/能力在哪些学科有效”。

最终是否采用 `scope_kind`、是否需要历史状态字段，由 DATA_MODEL audit 决定。

### 为什么不只存一个 subject list

如果只维护：

```text
乔老师：语文、历史
roles：teacher + subject_lead
```

系统无法知道：
- 乔老师是语文负责人、历史普通教师；
还是
- 两科都是负责人。

因此 subject scope 必须能表达至少“教学范围”和“学科管理范围”的区别。

---

## Layer 3｜Student Subject Assignment

回答：

> 这个老师当前实际负责哪个学生的哪个学科？

例：

```text
乔老师
├─ 张三 · 语文 · Lead
├─ 李四 · 语文 · Lead
├─ 王五 · 政治 · Collaborator
└─ 赵六 · 历史 · Lead
```

这是当前 `student_teacher_assignments` 的职责，继续保留。

---

# 4. 最重要的权限原则：Scope 不是数据通行证

Teacher Subject Scope 只表示：

> **该老师有资格/被配置可以在这个学科承担教师类业务关系。**

它绝不意味着：

> **该老师自动可以读取本学科所有学生。**

因此 teacher 业务访问仍应满足类似：

```text
live Auth Session
+ active membership
+ teacher role/capability
+ active teaching subject scope
+ active student_teacher_assignment
+ operation permission
```

### 为什么必须这样

如果“语文 teaching scope”就能读全部语文学生：
- 新入职老师会看到未分配学生；
- 临时代课配置会扩大数据面；
- 多学科教师会无意获得大量学生数据；
- 违反 Foundation 已冻结的 assignment-level RLS 原则。

因此：

> **Subject Scope 限制 Assignment 能否成立；Assignment 才决定普通教师具体学生数据范围。**

---

# 5. Assignment 建立不变量

管理员创建 active `student_teacher_assignment` 时至少应检查：

1. organization 一致；
2. membership = active；
3. membership 具备 teacher 能力；
4. membership 对 `organization_subject_id` 有 active `teaching` scope；
5. student 属于同机构；
6. Student Subject Profile 存在或由受控 workflow 建立；
7. 同一 student+subject 不违反 active Lead 唯一规则；
8. 时间区间不产生非法重叠；
9. 写 audit/history。

不得让普通 Flutter ViewModel 通过任意 insert 绕过这些规则。

---

# 6. Lead / Collaborator

## Lead

某 student + subject 的主要负责教师。

默认职责：
- 主要理解学生当前学情；
- 默认 Case owner 候选；
- 对本学科关键专业结论承担主要确认责任；
- 负责保持 primary Action 连续；
- 参与/确认阶段学科复盘。

### 不等于

Lead 不是组织角色：
- 不自动成为 subject lead；
- 不自动拥有管理员权限；
- 不绕过 RLS/live-session。

---

## Collaborator

某 student + subject 的协作教师。

适用：
- 同一个学生由主讲 + 辅导教师共同教学；
- 临时替课/专题协作；
- 教研负责人实际参与某学生教学，但不更换 Lead。

Collaborator 可以根据权限：
- 查看该学生该学科的必要详情；
- 记录自己真实发生的 Evidence / Intervention / Assessment；
- 承担明确 Action。

但：
- 不应无条件覆盖 Lead 的专业判断；
- Case ownership/关键状态命令仍需按 capability/command policy 控制。

具体“谁可以 confirm stable/close/reopen”在 Role Workflow Matrix / Commands audit 冻结。

---

# 7. Advisor / Homeroom / Coordinator

这些属于 `student_staff_assignments`，不使用 teacher assignment。

## Advisor / 学管、学生负责人

需要：
- 综合查看被分配学生的跨学科必要状态；
- 协调老师；
- 组织家校反馈；
- 跟进跨学科事项。

不应：
- 假装成某学科教师；
- 随意编辑 Case root cause/Assessment 等专业结论；
- 通过 Advisor 身份自动获得全机构学生。

## Homeroom / 班主任

语义与 Advisor 类似但对应机构实际班主任职责；是否在 V1 UI 明确暴露取决于试点组织结构。

## Coordinator

用于跨团队协调但不等价于 subject teacher。

---

# 8. Subject Lead / 学科负责人

现有 `membership_roles.subject_lead` 只有能力角色，还需要 Subject Scope 告诉系统：

> 负责哪个学科？

例：

```text
membership_roles: subject_lead
membership_subject_scopes:
  语文 / leadership
```

这样一个人可以：

```text
teacher role
+ teaching scope: 语文、历史
+ subject_lead role
+ leadership scope: 语文
```

表达：

> 他教语文和历史，但只负责语文学科管理。

### Subject Lead 的数据边界

建议默认：
- 在 leadership subject scope 内拥有必要的教学质量/Case 审查视角；
- 可查看该学科授权范围内更多学生信息，用于专业管理；
- 不因 subject lead 身份访问其他学科；
- 不自动替代具体 Student Lead teacher 的所有权；
- 对专业结论的“修改”与“审阅/建议”应区分。

精确 read/write matrix 留给权限审查文件，但 subject scope 必须先存在才能定义 RLS。

---

# 9. Academic Admin

`academic_admin` 是机构级教学管理角色。

可能需要跨学科治理能力，例如：
- 查看无 owner Case；
- 完成交接；
- 查看长期 pending verification；
- 处理重复/失配 assignment。

但仍应遵循：
- 最小必要数据；
- 审计；
- 高风险命令受控；
- 管理权限不意味着可以伪装成实际授课教师写“我实施了某 Intervention”。

如果 admin 亲自授课，应同时拥有 teacher role + teaching scope + student assignment。

---

# 10. Today 在多学科教师下如何工作

一名老师同时教语文、政治、历史时，Today 默认不要求先反复切换学科。

推荐：

```text
我的工作
├─ overdue
├─ today
├─ pending verification
├─ future
└─ undated
```

事项来自：
- assigned_membership_id = 当前老师；
- 当前老师拥有合法 active relationship；
- 多个 subject 混合显示但明确标注学科。

可提供 subject filter：

```text
全部学科 | 语文 | 政治 | 历史
```

但 filter 是查看工具，不是权限事实源。

### 禁止

不得要求：

> 打开 App → 先选“当前学科” → 才能看到其他科任务。

这会让多学科教师频繁切换上下文。

---

# 11. Student Detail 的多学科上下文

同一个 Student 可能有：

```text
张三
├─ 语文 Subject Profile
├─ 数学 Subject Profile
└─ 英语 Subject Profile
```

Teacher 从 Today 某条“语文”Action 进入 Student Detail：
- 默认保持语文上下文；
- 不静默跳到其他学科；
- 若用户有权限，可显式切换到其他学科；
- 未授权学科不泄露细节。

Advisor 从综合入口进入：
- 可以看到必要跨学科摘要；
- 进入专业 Case 时仍显示明确学科来源/作者。

这解决 Phase 0A.5 留下的“多学科 Student Detail 默认上下文”问题。

---

# 12. 新老师入职流程中的 Subject Scope

推荐管理流程：

```text
Provision membership
→ onboarding
→ roles
→ teacher/leadership subject scopes
→ complete onboarding
→ active
→ student assignments
```

注意：
- onboarding 状态仍然无普通学生业务权限；
- 可以在 onboarding 阶段预配置 scope，但只有 membership active 后才可成为 active student assignment；
- subject scope 变更需要 audit。

---

# 13. 分配学生的管理 UX

管理员不应直接面对裸数据库表。

推荐工作流：

```text
选择学生
→ 选择学科
→ 系统只列出：
   active membership
   + teacher capability
   + active teaching scope
→ 选择 Lead / Collaborator
→ 检查冲突
→ 确认
```

如果该老师没有对应 teaching scope：

> “该老师当前未被配置为语文教师。请先调整教师学科范围。”

不得静默帮管理员扩权限。

---

# 14. 教师换学生 / 普通 Reassign

当前 `reassign_teacher` 命令继续有价值。

重分配 student+subject 时应考虑：
- active assignment；
- Case ownership；
- pending Action assignee；
- 当前 Lesson；
- timeline/audit；
- 新老师 subject scope。

换老师后 Student Subject Profile 和 Case history 不新建、不清空。

---

# 15. 新发现的场景：老师仍在职，但不再教某一科

这和 `disable_membership_and_handoff` 不同。

例：

```text
乔老师仍在机构任教
原本：语文 + 政治
以后：只教语文
```

不能简单删除“政治 teaching scope”，因为他可能仍有：
- active 政治 student assignments；
- owned political Cases；
- pending Actions；
- future Lessons/context。

### 需要受控的 Subject Scope Revocation Workflow

推荐业务顺序：

1. inventory 目标 subject 的 active student_teacher_assignments；
2. inventory active Case ownership；
3. inventory pending Actions；
4. 指定合法接手人；
5. 新接手人必须 active + teacher capability + same subject teaching scope；
6. 完成交接；
7. 验证无 orphan；
8. 结束旧 subject scope；
9. audit。

### Command 决策候选

Phase 0A.6 建议评估新增：

`revoke_teacher_subject_scope_and_handoff`

或扩展现有 handoff/reassign command family。

不得通过普通 DELETE/UPDATE subject scope 实现。

---

# 16. Membership disabled / 离职

现有 `disable_membership_and_handoff` 保留并扩展 inventory 对 subject scopes 的检查：

```text
student assignments
+ staff assignments
+ subject scopes
+ Case ownership
+ pending Actions
→ handoff
→ verify no orphan
→ membership disabled
```

历史：
- creator/teacher membership reference 保留；
- scope/assignment 历史保留；
- 不把历史老师重写成接手老师。

---

# 17. Scope 变更与历史

Subject Scope 是组织授权事实，未来可能变化。

因此不建议物理删除历史。

至少需要可解释：
- 什么时候开始教某科；
- 什么时候结束；
- 谁调整；
- 为什么会出现过去的 assignment/Intervention。

精确实现可采用 active_from/active_to/status/audit；Phase 0B 再决定数据库约束。

---

# 18. 数据不变量候选

进入 Phase 0B 前建议把以下升级到 DATA_MODEL / COMMANDS：

1. active student teacher assignment 必须有匹配 active teaching subject scope；
2. subject lead 的 subject-scoped 权限必须有 matching leadership scope；
3. scope/membership/subject/assignment organization 必须一致；
4. 同 student+subject 默认最多一个 active Lead；
5. teacher role/teaching scope 不授予未 assigned student 的普通教师访问；
6. 撤销 teaching scope 前必须清空/交接该 subject 的 active assignments/owned Cases/pending Actions；
7. disabled membership 不得保留 active subject scope；
8. historical scope/assignment 不因停用物理删除。

---

# 19. RLS 推导原则

本文件不写正式 RLS SQL，但为 Phase 0B 提供约束。

### Teacher

普通学生数据至少：

```text
live session
+ active membership
+ teacher role/capability
+ matching teaching subject scope
+ matching active student_teacher_assignment
```

### Subject Lead

```text
live session
+ active membership
+ subject_lead role
+ matching leadership subject scope
```

再根据具体表/操作决定 read/write。

### Advisor

```text
live session
+ active membership
+ student_advisor role/capability
+ matching active student_staff_assignment
```

不通过 subject teaching scope 冒充教师。

### Admin

根据 org-level role 获得治理权限；高风险写仍走 command/audit。

---

# 20. 典型场景验收

## 场景 A：一位老师教三科

```text
Teacher A
teaching scopes = 语文 / 政治 / 历史
```

合法。

Today 可混合显示三个学科中**真正分配给他的行动**。

---

## 场景 B：老师有语文 scope，但没有张三 assignment

不能因为“是语文老师”自动读取张三语文完整学情。

---

## 场景 C：张三语文有 Lead + Collaborator

```text
Lead = Teacher A
Collaborator = Teacher B
```

两者都必须有语文 teaching scope。

---

## 场景 D：Teacher A 是语文 Subject Lead，但还教历史

```text
roles = teacher + subject_lead
teaching scopes = 语文 / 历史
leadership scopes = 语文
```

不能访问历史学科的 subject-lead 管理视角。

---

## 场景 E：Advisor 负责张三

Advisor 能看到授权的跨学科综合状态；不因此拥有语文 Case 专业编辑权。

---

## 场景 F：乔老师不再教政治但继续教语文

必须先完成政治相关 handoff，再结束政治 teaching scope；membership 继续 active。

---

# 21. 对现有 Foundation 的拟议修订

本文件建议后续正式审查并小范围修改：

### `DATA_MODEL.md`
新增独立 subject scope 领域关系，建议候选 `membership_subject_scopes`。

### `COMMANDS_AND_INVARIANTS.md`
- student teacher assignment 建立/重分配时验证 active teaching scope；
- `disable_membership_and_handoff` inventory subject scopes；
- 评估 subject-specific scope revocation + handoff command。

### `AUTH_AND_PERMISSIONS.md`
从四层身份扩展解释为：

```text
Auth User
+ Membership
+ Role
+ Subject Scope（subject-scoped capability）
+ Student Assignment（record-level relationship）
```

但不要把 Subject Scope 描述成新的 Auth identity；它只是业务授权范围。

这些修订在 Phase 0A.6 后续独立 audit 后再落入 Foundation 文档；本文件本身不授权直接写 migrations/RLS。

---

# 22. 决策结论

Phase 0A.6 当前冻结以下产品/领域决策：

1. **一名教师可拥有多个学科范围。**
2. **Teacher Subject Scope 与 Student Assignment 必须独立建模。**
3. **Scope 只决定“可以在哪些科承担关系”，不自动授予该科全学生访问。**
4. **Lead/Collaborator 是 student+subject 业务关系，不是全局角色。**
5. **Advisor/班主任/学管使用 staff assignment，不伪装成学科教师。**
6. **Subject Lead 需要独立的 leadership subject scope 才能形成真实学科边界。**
7. **普通教师访问继续 assignment-level，不退化成 subject-wide access。**
8. **结束某一科 teaching scope 必须先处理该科 active responsibilities，不能普通删除。**
9. **教师离职历史与学科范围/assignment 历史必须可解释。**
10. **精确表结构和 RLS SQL 留给通过 Phase 0A.6 audit 后的 Phase 0B。**
