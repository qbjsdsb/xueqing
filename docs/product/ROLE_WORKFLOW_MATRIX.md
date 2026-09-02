# Role / Workflow Matrix｜角色与工作流权限矩阵

> 状态：Phase 0A.6 产品权限事实源。本文定义业务能力边界；正式 RLS / command policy 必须在 Phase 0B 用正向+负向测试证明。

## 1. 权限不能只写“能/不能”

至少区分五种权力：

- **Read**：读取权限允许的事实；
- **Append**：追加本人真实发生/观察到的事实；
- **Edit**：修改当前可变快照；
- **Confirm**：执行改变正式领域状态或冻结快照的 command；
- **Govern**：交接、合并、成员/范围治理、高风险纠错。

一个人可以 Read 但不能 Edit；可以 Append 自己真实实施的 Intervention，但不能改写另一位老师过去已经发生的 Intervention。

---

## 2. 最重要的硬规则：管理权限不能伪造教学事实

### 教学事实写入 Gate

任何成员要追加：
- Intervention；
- Assessment；
- 以任课教师身份形成的教学 Evidence；
- Lesson 内教师教学行为；

至少必须满足：

```text
live session
+ active membership
+ teacher capability/role
+ matching active teaching subject scope
+ 对该 student+subject 的合法 active teacher assignment 或本次合法 Lesson relationship
+ operation-specific permission
```

### 明确禁止
以下身份**单独存在时**都不能让系统把该成员记录成“实际授课教师”：
- `subject_lead role + leadership scope`
- `academic_admin`
- `org_admin`
- `student_advisor`

如果 Subject Lead / Academic Admin / Org Admin 本人真的参加授课，则必须另外拥有：
- teacher role/capability；
- teaching subject scope；
- 对应 Student Assignment / Lesson relationship。

这样 audit 才能解释：

> 这条记录是管理行为，还是这个人真的参与了教学？

---

## 3. 授权不是只看 Role

最终许可由多层共同决定：

```text
live Auth Session
+ active Organization Membership
+ role / capability
+ active Subject Scope（如需要）
+ active Student/Staff Assignment（如需要）
+ entity current state
+ owner/assignee relation（如需要）
+ command-specific rule
```

Role Matrix 只定义能力上限，不能替代数据范围。

---

## 4. Subject Scope 两种语义

`membership_subject_scopes.scope_kind`：
- `teaching`
- `leadership`

### Teaching Scope
表示成员可以在该学科承担教师类 assignment。

它**不自动授予该学科所有学生的数据访问权**；普通教师仍需 Student Assignment。

### Leadership Scope
表示 Subject Lead 的学科管理范围。

它可以扩大该学科的专业治理/审阅视角，但：
- 不自动成为每个学生的教师；
- 不自动成为 Case owner；
- 不自动允许写 Intervention/Assessment；
- 不访问其他学科。

---

## 5. Lead Teacher

前置：
- teacher role/capability；
- matching teaching scope；
- student+subject active assignment=`lead`。

### 默认能力
- Read：本科详细 Subject Profile / Case / Evidence / Intervention / Assessment / Action / Lesson context；
- Append：本人真实产生的教学事实；
- Edit：本科当前可变判断/profile summary，受 version 控制；
- Confirm：按 command policy 执行 confirm/transition/stable/closed/reopen、primary Action replacement；
- Lesson：开始/完成本人合法授课 Lesson；
- Parent Communication：创建/确认本科反馈；
- Subject Stage Review：创建并 finalize 授权范围内本科阶段复盘。

### 不允许
- 因 teaching scope 读取未 assignment 学生；
- 修改其他学科专业结论；
- 静默覆盖 finalized 历史；
- 把其他老师真实行为改成自己的 actor。

---

## 6. Collaborator Teacher

前置：
- teacher role/capability；
- matching teaching scope；
- student+subject assignment=`collaborator`。

### 默认能力
- Read：本科完成协作所需的详细事实；
- Append：本人真实 Evidence / Intervention / Assessment；
- Action：执行明确 assigned 给自己的 Action；
- Lesson：记录本人实际授课。

### 关键 Case command
Collaborator 不因 assignment 自动拥有所有最终判断权。

推荐默认：
- 如果是当前 Case owner，按 command policy 可执行相应状态命令；
- 如果不是 owner，能完成普通干预/验证，但 stable/close/reopen 等关键确认需由合法 owner/Lead 或明确治理 command 完成。

Phase 0B 必须覆盖 collaborator=assigned 但 owner=false 的正负测试。

---

## 7. Student Advisor / 学管

前置：
- student_advisor capability；
- active `student_staff_assignment`。

### Read
- 被分配学生的跨学科必要摘要；
- 当前重点、待验证、下一步；
- 权限允许的家校素材；
- finalized subject review 摘要。

### 可以做
- 记录本人真实进行的家校沟通；
- 创建综合 Parent Communication draft；
- 在权限允许范围整理多个学科的摘要；
- 负责非学科专业性的综合 follow-up；
- 创建综合 Stage Review draft（若机构采用）。

### 默认不能
- 修改学科老师 root-cause judgment；
- 修改 Assessment result；
- 伪造 Intervention；
- close/reopen 学科 Case；
- 通过“综合视角”读取全部内部专业细节。

Advisor 可以确认自己有权负责的综合家校沟通，但不能通过 composite draft 回写 subject finalized source。

---

## 8. Subject Lead

前置：
- subject_lead role/capability；
- matching `leadership` scope。

### 默认 Read / Govern
在本科范围内可按机构规则查看：
- Subject Profiles；
- Cases；
-长期/重复问题；
- Evidence/Assessment；
-阶段复盘；
-本科治理异常。

可以：
- 专业 review；
- 提出调整建议；
- 协助复杂 Case；
- 执行少量明确的 subject-governance commands（需 audit）。

### 绝对不因 leadership scope 自动获得
- Intervention append；
- Assessment append；
- Lesson teacher identity；
- Student Assignment；
- Case ownership。

如果 Subject Lead 真实参与某个学生教学，必须另外满足 **Teaching Fact Gate**。

---

## 9. Academic Admin

职责是机构教学完整性与跨学科治理。

### Read / Govern
可按最小必要原则：
- 查看 Case/Action 完整性；
- 处理 orphan/handoff；
- 协调跨学科问题；
- 处理 assignment；
- 必要时执行 finalized snapshot correction 等治理动作。

### 不能仅凭 admin 身份
- 伪造 Intervention；
- 伪造 Assessment；
- 成为 Lesson teacher；
- 自动覆盖教师专业正文；
- 自动成为所有 Case owner。

如果本人授课，同样必须通过 Teaching Fact Gate。

---

## 10. Org Admin

主要负责：
- membership / onboarding / reset / disable；
- roles；
- subject scopes；
- Student 主档案治理；
- merge；
- break-glass / 高风险治理。

Org Admin 是系统管理身份，不等于教学专业身份。

如果 Org Admin 也授课，需要另有 teacher capability + teaching scope + Student Assignment / Lesson relationship。

---

## 11. Case Owner 是责任关系，不是 Role

`owner_membership_id` 表示一个 Case 当前主要推进责任人。

Owner 必须：
- membership active；
- 有 teacher capability；
- matching teaching scope；
- 对该 student+subject 有合法 teacher relationship；
- 满足 command-specific rules。

Owner 通常是 Lead，也可以是合法 Collaborator。

**Advisor / Admin / Subject Lead 不能仅凭管理身份被设为 Case owner 来绕过教学权限。**

Owner 变化必须留下 event/audit，不能只覆盖字段导致历史责任消失。

---

## 12. 多学科教师

例如：

```text
乔老师
- 语文 / teaching
- 政治 / teaching
- 历史 / teaching

Student Assignments
- 张三 · 语文 · Lead
- 李四 · 政治 · Lead
- 王五 · 历史 · Collaborator
```

Today 默认聚合本人所有合法 assigned Actions：
- overdue；
- today；
- pending verification；
- future；
- undated。

可按 subject filter 查看，但 filter 不是权限事实源。

不要求用户进入 App 先选择一个“全局当前学科”。

---

## 13. Student Detail 多学科上下文

从某个“语文”Action 进入 Student Detail：
- 默认保留语文上下文；
- 不静默跳科；
- 有其他学科权限时可显式切换；
- 无权限学科不泄露细节。

Advisor 从综合入口进入：
- 可以看到授权的跨学科摘要；
- 进入专业 Case 时必须显示明确学科与专业来源。

### No permission ≠ Empty
无数学权限时不能显示：

> 数学：暂无问题

这会误导成“确实没有数据”。

应根据 privacy spec 隐藏 section 或表达“当前不在你的可见范围”。

---

## 14. 家校特别边界

### Subject Teacher
基于本科正式事实形成专业反馈。

### Advisor
可以组织多个学科**被允许共享的摘要**形成综合家校沟通。

正确结构：

```text
subject source facts/finalized source
        ↓
advisor composite draft
        ↓
actual parent communication snapshot
```

综合文案变化不能回写原 subject professional source。

---

## 15. Stage Review 边界

### Subject Review
由有学科专业确认权的教师/按机构规则的 Subject Lead review/finalize。

Subject Lead 如果只是 reviewer，不因此成为该学生的 actual teacher actor。

### Comprehensive Review
Advisor / Academic Admin 可以在授权范围内组织跨学科摘要，但不能更改被引用的 subject finalized source。

---

## 16. 管理 Workflow Matrix

符号：R=Read，A=Append actual fact，E=Edit mutable snapshot，C=Confirm command，G=Govern。

| Workflow | Lead Teacher | Collaborator | Advisor | Subject Lead | Academic Admin | Org Admin |
| --- | --- | --- | --- | --- | --- | --- |
| 本科 Student Detail | R/E | R | 摘要 R | 本科 R | 必要 R | 治理必要 R |
| 未 assignment 学生详细数据 | — | — | 仅 staff-assigned 摘要 | 本 leadership scope 治理 R | 必要 R | 治理必要 R |
| Quick Capture | A | A | 非专业范围按 policy | **仅通过 Teaching Fact Gate 时 A** | **仅通过 Teaching Fact Gate 时 A** | **仅通过 Teaching Fact Gate 时 A** |
| Teaching Evidence | R/A | R/A | 必要 R | **Gate 后才 A** | **Gate 后才 A** | **Gate 后才 A** |
| Intervention | R/A | R/A | R | **Gate 后才 A** | **Gate 后才 A** | **Gate 后才 A** |
| Assessment | R/A | R/A | 摘要/必要 R | **Gate 后才 A** | **Gate 后才 A** | **Gate 后才 A** |
| Confirm Case | C | owner/policy 时 C | — | 特定治理 C | 特定治理 C | 默认 — |
| Stable/Close/Reopen | C | owner/policy 时 C | — | 特定治理 C | 特定治理 C | 默认 — |
| Primary Action | E/C | assigned/owner 范围 | 协调 R | 专业治理 | G | 治理必要 |
| Lesson | 本人合法 Lesson C | 本人合法 Lesson C | R 摘要 | **Gate 后本人 Lesson** | **Gate 后本人 Lesson** | **Gate 后本人 Lesson** |
| Parent Communication | 本科 R/E/C | 关系范围 | 综合 R/E/C | Review/本科治理 | G/必要 C | 治理 |
| Subject Stage Review | R/E/C | 协作 | 摘要 R | R/Review/C 按机构 | G | 治理必要 |
| Comprehensive Stage Review | source R | source R | R/E/C | 本科 source | R/E/C | 治理必要 |
| Student Assignment | — | — | — | 建议/按机构 | G | G |
| Subject Scope | — | — | — | — | 建议/部分 G | G |
| Handoff / Disable | — | — | — | 学科协助 | G | G |
| Student Merge | — | — | — | — | G（若授权） | G |

表中任何 `Gate 后才 A` 都必须满足第 2 节 Teaching Fact Gate，而不是 leadership/admin 权限本身。

---

## 17. Historical actor 永不因交接重写

老师离职/换科后：
- 过去 Evidence created_by 不变；
- Intervention teacher 不变；
- Assessment assessor 不变；
- finalized Report/Communication 仍显示原确认者；
- 只转移当前 owner / pending Actions / assignments。

禁止为了“当前负责人一致”修改历史 actor。

---

## 18. Phase 0B 权限测试最小矩阵

至少建立虚构：
- Org A / Org B；
- Teacher A：语文 teaching scope，Student 1 Lead；
- Teacher B：语文 teaching scope，Student 1 Collaborator；
- Teacher C：语文 teaching scope，但无 Student 1 assignment；
- Teacher D：数学 teaching scope；
- Subject Lead：语文 leadership scope、**无 teaching relationship**；
- Subject Lead+Teacher：同时有语文 leadership + teaching scope + Student 1 assignment；
- Advisor：Student 1 staff assignment；
- Academic Admin；
- Org Admin；
- onboarding / disabled variants。

必须证明：
1. Teacher C 虽有语文 teaching scope，不能读 Student 1 详细数据；
2. Teacher D 不能读 Student 1 语文细节；
3. Advisor 能读允许摘要但不能 close 语文 Case；
4. Collaborator 能追加本人真实教学事实，但关键 Case command 受 owner/policy；
5. **纯 Subject Lead（只有 leadership scope）不能写 Intervention/Assessment；**
6. Subject Lead+Teacher 只有在真实 Student/Lesson relationship 下才可写教学事实；
7. Academic/Org Admin 单凭 admin 身份不能伪造教学事实；
8. disabled/revoked 全拒绝；
9. Org A/B 完全隔离；
10. 管理 endpoint 不能被普通 teacher 冒用。

---

## 19. 当前冻结结论

- Role、Subject Scope、Student Assignment 三层共同参与授权。
- Subject Scope 明确区分 `teaching / leadership`。
- “能看、能追加、能改、能确认、能治理”必须分开。
- Teaching Scope 不授予全学科学生访问。
- Leadership/Admin 权限本身**绝不允许伪造实际教学事实**。
- Advisor 是综合协作角色，不是跨学科专业编辑者。
- Case owner 是受教学关系约束的责任关系。
- 历史 actor 不随 handoff 重写。
