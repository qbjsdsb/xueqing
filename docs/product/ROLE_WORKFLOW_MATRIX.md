# Role / Workflow Matrix｜角色与工作流权限矩阵

> Phase 0A.6 权限事实源。Role 只定义能力上限；最终授权仍取决于 live session、membership、subject scope、Student/Staff Assignment、entity state 与 command policy。

## 1. 五种权力

- Read：读取授权事实；
- Append：追加本人真实事实；
- Edit：修改当前可变快照；
- Confirm：执行正式状态/快照 command；
- Govern：handoff、merge、成员/范围治理。

## 2. Teaching Fact Gate｜任何角色都不能绕过

以下全部属于教学事实创建：
- teaching Evidence；
- Intervention；
- Assessment；
- Lesson teacher 行为；
- **Quick Capture / new Learning Case**。

必须同时：

```text
live session
+ active membership
+ teacher capability
+ active teaching subject scope
+ target Subject Profile active
+ legal active Student Assignment OR controlled Lesson relationship
+ operation permission
```

Subject Lead / Academic Admin / Org Admin / Advisor 的管理身份本身均不能满足该 Gate。

## 3. Lead Teacher

前置：teacher + teaching scope + active lead assignment + active Profile。

默认：
- Read 本科详细事实；
- Append 本人教学事实/Quick Capture；
- Edit 当前本科判断（version controlled）；
- Confirm Case/Action/Lesson commands 按 owner/policy；
- 创建本科 Parent Communication / Stage Review。

不访问未 assignment 学生；不改其他学科；不覆盖别人 finalized history。

## 4. Collaborator Teacher

前置同 Gate，assignment=collaborator。

可以读取协作事实、记录本人教学行为、Quick Capture、执行 assigned Action/Lesson。

关键 stable/close/reopen 默认要求其是合法 owner 或 command policy 明确授权；不能因 collaborator 身份自动拥有全部最终判断权。

## 5. Student Advisor / 学管

前置：student_advisor + active student_staff_assignment。

可以：
- 读被分配学生的授权跨学科摘要；
- 记录真实 Parent Communication；
- 创建综合沟通/复盘 Draft；
- 记录允许的综合 Observation（该能力实现后）；
- 做非学科专业协调 follow-up。

**不能：**
- Quick Capture/new teaching Case；
- teaching Evidence/Intervention/Assessment；
- close/reopen 学科 Case；
- 修改学科老师 root-cause/Assessment。

如果 Advisor 同时也是任课教师，只有在完整 Teaching Fact Gate 成立的那个 Student+Subject context 下，才可以按 teacher 身份 Quick Capture。

## 6. Subject Lead

前置：subject_lead + leadership scope。

可以本科专业 review / governance /复杂 Case 协助；但 leadership scope 本身不授予：
- Student teacher assignment；
- Case owner；
- Quick Capture；
- Intervention/Assessment；
- Lesson teacher identity。

本人实际授课时必须额外通过 Teaching Fact Gate。

## 7. Academic Admin

跨学科治理：assignment、orphan、handoff、finalized correction、必要视角。

Admin 权限不能伪造 Quick Capture/Intervention/Assessment/Lesson actor。本人授课时另走 teacher Gate。

## 8. Org Admin

主要负责 membership/roles/scopes/student master/merge/break-glass。系统管理身份不是教学身份。

## 9. Case Owner

Owner 是当前教学责任关系，不是组织 Role。

Active Profile 下 owner 必须：active membership + teacher capability + teaching scope + legal Student Assignment。

Advisor/Admin/纯 Subject Lead 不能仅靠治理身份成为 Case owner。

Profile inactive/archived tracking suspended 时 unresolved Case 可以暂无 current owner；reactivate transaction 恢复 owner。

## 10. Reopen 权限

`reopen_case` 只允许 closed Case + active Profile。

默认 actor：
- 当前合法 Lead teacher；或
- 被 command policy 明确授权并同时具备 Teaching Fact Gate 的合法 teacher/owner candidate。

管理角色如果没有 Teaching Fact Gate，不能直接 reopen；可以通过治理流程先建立合法 teacher relationship，再由教师确认复发。

## 11. Quick Capture 唯一权限语义

```text
Quick Capture → new Learning Case
```

不是“管理便签”。它必须完整 Teaching Fact Gate。

因此：
- Lead Teacher：Gate 成立 → A；
- Collaborator：Gate 成立 → A；
- Advisor-only：—；
- pure Subject Lead：—；
- Academic Admin-only：—；
- Org Admin-only：—。

Advisor 的非专业观察只能走 Observation/Parent Communication/综合协调事实，不得借 Quick Capture 创建教学 Case。

## 12. Workflow Matrix

符号：R=Read，A=Append actual fact，E=Edit mutable snapshot，C=Confirm，G=Govern，—=默认无权。

| Workflow | Lead Teacher | Collaborator | Advisor | Subject Lead | Academic Admin | Org Admin |
| --- | --- | --- | --- | --- | --- | --- |
| 本科 Student Detail | R/E | R | 摘要 R | 本科 R | 必要 R | 治理必要 R |
| Quick Capture/new Case | A(Gate) | A(Gate) | — | 仅另具 Teacher Gate | 仅另具 Teacher Gate | 仅另具 Teacher Gate |
| Teaching Evidence | R/A(Gate) | R/A(Gate) | 必要 R | Gate 后才 A | Gate 后才 A | Gate 后才 A |
| Intervention | R/A(Gate) | R/A(Gate) | R | Gate 后才 A | Gate 后才 A | Gate 后才 A |
| Assessment | R/A(Gate) | R/A(Gate) | 摘要 R | Gate 后才 A | Gate 后才 A | Gate 后才 A |
| Confirm Case | C | owner/policy C | — | 特定治理 C | 特定治理 C | 默认 — |
| Stable/Close/Reopen | C | owner/policy C | — | 必须同时 Teacher Gate/特定治理 | 必须同时 Teacher Gate/特定治理 | 默认 — |
| Primary Action | E/C | assigned/owner | 协调 R | 专业治理 | G | 治理必要 |
| Lesson | C(Gate) | C(Gate) | R 摘要 | Gate 后本人 Lesson | Gate 后本人 Lesson | Gate 后本人 Lesson |
| Parent Communication | 本科 R/E/C | 关系范围 | 综合 R/E/C | Review | G/必要 C | 治理 |
| Stage Review | 本科 R/E/C | 协作 | 综合 R/E/C | R/Review | G | 治理 |
| Student Assignment | — | — | — | 建议 | G | G |
| Subject Scope | — | — | — | — | 部分 G | G |
| Handoff/Disable | — | — | — | 学科协助 | G | G |
| Student Merge | — | — | — | — | G（若授权） | G |

## 13. Historical actor

离职/换科/停科/merge 后历史 actor 不重写。Current owner/assignment 可以变化，过去 Evidence/Intervention/Assessment/finalized snapshot 的 actor 仍是原人。

## 14. Phase 0B 权限负向矩阵

至少证明：
- teaching scope 但无 Student Assignment → 不能读详细/Quick Capture；
- Advisor-only → Quick Capture 拒绝；
- pure Subject Lead/Admin → teaching facts/new Case 拒绝；
- Profile inactive/archived + old assignment → new Case/teaching facts/Lesson 拒绝；
- closed Case + inactive Profile → reopen 拒绝；
- collaborator 非 owner → 关键 command 按 policy 拒绝；
- revoked/disabled/cross-org 全拒绝。
