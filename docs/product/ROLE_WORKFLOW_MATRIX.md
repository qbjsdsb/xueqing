# Role / Workflow Matrix｜角色与工作流权限矩阵

> 状态：Phase 0A.6 产品权限事实源。本文定义业务能力边界，正式 RLS / command policy 需在 Phase 0B 以负面测试证明。

## 1. 先区分五种权力

不能只写“有权限/没权限”。

- **Read**：看得到必要事实；
- **Append**：追加自己真实发生的事实；
- **Edit**：修改当前可变业务快照；
- **Confirm**：执行会改变正式领域状态/冻结快照的命令；
- **Govern**：做交接、合并、成员/范围治理等高风险动作。

一个人可以 Read，但没有 Edit；可以 Append 自己的 Intervention，但不能改另一个老师的历史 Intervention。

---

## 2. 授权计算不是只看 Role

最终业务许可至少由：

```text
live session
+ active membership
+ role/capability
+ active subject scope（如需）
+ active student/staff assignment（如需）
+ entity current state
+ command-specific rule
```

共同决定。

Role Matrix 是能力上限，不是数据范围本身。

---

## 3. Teacher · Student Lead

条件：
- teacher role；
- matching teaching subject scope；
- student+subject active assignment role=lead。

### 默认能力
- Read：该学生本科详细 Subject Profile / Case / Evidence / Intervention / Assessment / Action / Lesson context；
- Append：本人实际产生的 Evidence / Intervention / Assessment / Quick Capture；
- Edit：本科当前可变 Case judgment/profile summary（受 version）；
- Confirm：confirm_case、允许的 transition、stable/closed/reopen、primary Action replacement；
- Parent Communication：创建/确认本科反馈；
- Subject Stage Review：创建并 finalize 本科阶段复盘；
- Lesson：开始/完成本人授课 Lesson；
- Governance：无机构级 merge/member 权限。

### 不允许
- 读取未 assignment 学生，仅因“我教这科”；
- 修改其他学科专业结论；
- 修改别人已经 finalized 的历史 snapshot；
- 改写别的老师“实际实施过”的 Intervention actor。

---

## 4. Teacher · Collaborator

条件：
- teacher role；
- matching teaching subject scope；
- student+subject assignment role=collaborator。

### 默认能力
- Read：本科足够完成协作的详细事实；
- Append：本人真实 Evidence / Intervention / Assessment；
- Action：可以承担明确 assigned Action；
- Lesson：记录本人实际授课。

### 关键状态命令
Collaborator 是否可 stable/close/reopen 不应靠 UI 猜。

推荐默认：
- 可以提出/执行普通干预与验证；
- 若自己是当前 Case owner 或被明确授予 command capability，可执行相应状态命令；
- 否则关键最终判断由 Lead/Case owner 完成。

Phase 0B command test 必须覆盖“Collaborator 有 assignment 但不是 owner”的负面/正面场景。

---

## 5. Student Advisor / 学管

条件：
- student_advisor role；
- active student_staff_assignment。

### Read
- 被分配学生的跨学科必要摘要；
- 当前重点/待验证/下一步；
- 已授权的家校素材；
- finalized subject review 摘要。

### Append/Edit
- 记录实际家校沟通；
- 记录符合权限的综合协调事实；
- 创建综合 Parent Communication draft；
- 创建综合 Stage Review draft（若机构采用）。

### 不允许默认
- 修改 subject teacher 的 root-cause judgment；
- 把某科 Assessment result 改掉；
- 以 Advisor 身份伪造 Intervention；
- 直接 close/reopen 学科 Case；
- 通过综合视角看到所有内部敏感细节。

### Confirm
- 可以 finalize 自己有权限负责的综合家校沟通；
- 综合 Stage Review finalization 是否允许取决于机构权限，但不能改变引用的 subject finalized source。

---

## 6. Subject Lead

条件：
- subject_lead role；
- matching `leadership` subject scope。

### Read
本科范围必要的：
- Student Subject Profiles；
- Cases；
-长期/重复问题；
-教学 Evidence/Assessment；
-阶段复盘。

### 专业管理
可以：
- review 教师结论；
- 提出调整；
- 参与复杂 Case；
- 查看本学科治理异常。

### Edit/Confirm
不能简单定义为“所有东西都能改”。

推荐：
- 可在明确治理/协作场景执行特定 command；
- 普通历史事实仍保留实际 actor；
- 不自动替代 Student Lead teacher 成为 owner；
- 修改 finalized 内容走 correction/audit。

### 数据范围
leadership scope=语文，只获得语文范围，不访问历史/数学等其他科。

---

## 7. Academic Admin

机构教学管理角色。

### Read
必要跨学科：
- Student/Subject 状态；
- Case/Action 完整性；
-交接；
-长期异常；
-阶段复盘；
-必要家校协调。

### Govern
- assignment 调整；
-教学 handoff；
-处理 orphan；
-纠正异常；
-必要的 report/communication correction。

### 不代表
Academic Admin 有广视角，但不表示：
- 可以伪造本人没有发生的 Intervention；
- 自动成为每个 Case owner；
- 默认通过 UI 修改所有教师专业正文。

高风险操作必须 audit。

---

## 8. Org Admin

核心职责：
- membership；
- roles；
- subject scopes；
-账号 onboarding/reset/disable；
- student master governance；
- merge；
- break-glass/治理。

### 特别原则
Org Admin 的“系统管理员”身份不等于“教学专家”。

如果 Org Admin 同时实际授课：
- 另有 teacher role；
- teaching subject scope；
- student assignment；
- 真实记录按 teacher 身份/关系产生。

这样 audit 能解释“这次行为是管理员治理，还是实际授课”。

---

## 9. Workflow Matrix

符号：
- R = Read
- A = Append own fact
- E = Edit mutable snapshot
- C = Confirm/domain command
- G = Governance
- — = 默认无权，除非另有关系/角色

| Workflow | Lead Teacher | Collaborator | Advisor | Subject Lead | Academic Admin | Org Admin |
| --- | --- | --- | --- | --- | --- | --- |
| 本科 Student Detail | R/E | R | 摘要 R | R | R | 治理必要 R |
| 其他学科详细 Case | — | — | 默认摘要 | — | R（必要） | 默认不因 admin 全开正文 |
| Quick Capture | A | A | 仅允许范围 | A（实际参与时） | 非默认教学事实 | 非默认教学事实 |
| Evidence | R/A | R/A | 必要 R | R/A（实际参与） | R | 治理 R |
| Intervention | R/A | R/A | R，不伪造 | R/A（实际参与） | R | R |
| Assessment | R/A | R/A | 摘要/必要 R | R/A（实际参与） | R | R |
| Confirm Case | C | owner/capability 时 C | — | 特定治理 C | 特定治理 C | — |
| Stable/Close/Reopen | owner/Lead C | policy 限制 | — | 特定治理 C | 特定治理 C | — |
| Primary Action | E/C | assigned/owner 范围 | 协调 R | 专业治理 | G | — |
| Lesson | C 自己课程 | C 自己课程 | R 摘要 | 实际授课时 | R | — |
| Parent Comm subject | R/E/C | 根据实际关系 | R/E/C 综合 | R/Review | G/必要 C | 治理 |
| Stage Review subject | R/E/C | 协作/Review | 摘要 R | R/Review/C（按机构） | G | 治理必要 |
| Stage Review comprehensive | R source | R source | R/E/C | 本科 source | R/E/C | 治理必要 |
| Teacher assignment | — | — | — | 建议/按机构 | G | G |
| Subject Scope | — | — | — | — | 建议/部分 G | G |
| Disable + handoff | — | — | — | 学科协助 | G | G |
| Student merge | — | — | — | — | G（若授权） | G |

此表是默认模型，不替代 command-specific policy。

---

## 10. 家校特别边界

### Subject Teacher
只基于本科正式事实形成专业反馈。

### Advisor
可以把多个学科**已经允许共享的摘要**组织成家长可理解的综合信息。

不能：

> Advisor 改完一句话后，原数学老师的 finalized 学科判断也被改了。

正确：

`subject source snapshot → advisor composite draft → parent communication snapshot`

三层都可解释。

---

## 11. 多学科同一教师

一位老师如果：
- 语文 Lead；
- 政治 Lead；
- 历史 Collaborator；

系统用各自 assignment 判断访问，不依赖“当前选择的一个全局学科”。

Today 默认汇总其所有 assigned Actions，再按 subject filter 查看。

Student Detail 从来源进入时保留学科上下文。

---

## 12. Case Owner 是责任，不是角色

`owner_membership_id` 表示某个 Case 当前主要推进责任人。

它必须：
- active；
- 有适当 role/capability；
- matching subject scope；
- 有合理 student relationship。

Case owner 可以是 Lead，必要时也可以是合法 Collaborator；不能指向 Advisor 来绕过专业权限。

Owner 变化必须 event/audit，不能只覆盖字段丢历史。

---

## 13. Historical actor 不随权限变化重写

老师离职后：
- 过去 Evidence 的 created_by 仍是该老师；
- Intervention teacher 仍是该老师；
- finalized report/communication 仍显示原确认者；
- 当前 owner/action 转交新老师。

禁止因为用户 disabled 就把历史 actor 改成新老师。

---

## 14. No-permission vs Empty

UI 不能让权限不足看起来像“学生没有数据”。

例如 Teacher 无权读数学 Case：
- 不应该显示“数学：暂无问题”，因为这泄露/误导；
- 应显示经过设计的“不在你的当前可见范围”或根本不呈现该 section。

精确文案在真实 RLS 接入后 privacy review。

---

## 15. Phase 0B 权限测试最小矩阵

至少建立：
- Org A / Org B；
- Teacher A：语文 scope，学生 1 Lead；
- Teacher B：语文 scope，学生 1 Collaborator；
- Teacher C：语文 scope，但未 assignment；
- Teacher D：数学 scope；
- Subject Lead：语文 leadership scope；
- Advisor：学生 1 staff assignment；
- Academic Admin；
- Org Admin；
- onboarding/disabled variants。

必须证明：
1. Teacher C 虽有语文 scope，不能读学生 1；
2. Teacher D 不能读学生 1 语文细节；
3. Advisor 能读允许摘要但不能 close 语文 Case；
4. Collaborator 能追加自己事实，但关键命令按 owner policy；
5. Subject Lead 仅在语文 leadership scope 生效；
6. disabled/revoked 全拒绝；
7. Org A/B 完全隔离；
8. admin 治理能力不能被普通 teacher endpoint 冒用。

---

## 16. 当前冻结结论

- Role、Subject Scope、Student Assignment 三层必须共同参与授权。
- “能看、能追加、能改、能确认、能治理”必须分开。
- Teacher Scope 不授予全学科学生访问。
- Advisor 是综合协作角色，不是跨学科专业编辑者。
- Subject Lead 必须有 leadership subject scope。
- Admin 广视角不等于伪造教学事实。
- Case owner 是明确责任关系，并受 subject/student relationship 约束。
- 历史 actor 永不因为交接而重写。
