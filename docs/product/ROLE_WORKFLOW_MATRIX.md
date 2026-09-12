# Role / Workflow Matrix｜三角色权限矩阵

> 当前试点权限事实源。此前工作流草案中的 Academic Admin、Subject Lead、Advisor 是探索性分工，不再是可分配的系统角色。本文件的三角色合同优先。

> v0.3.8 起，矩阵同时区分 **Personal Projection** 与 **Organization Projection**。机构级监督能力不等于本人任课责任，详见 ADR-047 与 `docs/RESPONSIBILITY_MODEL.md`。

## 1. 当前角色

| 角色 | 中文 | 主要职责 | 默认不能做 |
| --- | --- | --- | --- |
| `org_owner` | 负责人 | 管理机构与成员；机构级查看/监督学情；本人有真实 Assignment 时也可承担教学责任 | 仅凭负责人身份成为新 Case owner / Action assignee |
| `org_admin` | 管理员 | 管理老师、学生、学科范围、学生分配；机构级查看/监督学情 | 仅凭管理员身份成为新 Case owner / Action assignee；成员生命周期高权限操作 |
| `teacher` | 老师 | 管理本人负责的学生；创建问题；记录行动、证据和验证；查看授权成长历史 | 查看其他机构或未分配学生；机构级监督 |

一个成员可以同时拥有管理角色与真实教学责任。系统始终按当前操作需要的完整条件授权，不因高层级角色自动获得 Student Teacher Assignment。

## 2. 组织管理层级

```text
org_owner
  → org_admin
    → teacher
```

- 负责人可以邀请管理员和老师；
- 管理员可以邀请老师，也可以发起需要现有负责人审批的负责人提名；
- 老师不能管理机构成员；
- 首位负责人仍由可信运维流程产生，不提供公开自助入口。

这里的层级表示机构治理关系，不表示教学责任可以从上向下继承。

## 3. Teaching Fact Gate

### 3.1 Personal Scope / Responsible Teacher Gate

当当前成员要以本人责任身份成为 teaching fact actor/responsible teacher 时，Quick Capture/new Learning Case、Evidence、Intervention、Assessment 与 Lesson 教师行为都必须同时满足：

```text
live session
+ active membership
+ teacher capability
+ effective teaching subject scope
+ active Student Subject Profile
+ legal active Student Teacher Assignment
+ operation permission
```

负责人或管理员如果本人授课，也必须通过以上全部检查。管理身份不能代替教学范围、学生分配或 Case owner。

### 3.2 Organization supervision

负责人/管理员可以基于机构监督能力读取和处理已有 Case，但此时必须区分：

```text
Actor       = 实际操作的负责人/管理员
Responsible = 原合法责任老师
```

监督操作允许记录管理者本人为 Event/audit actor，但不能因此自动改写 Case owner 或 pending Action assignee。

### 3.3 Organization Scope new Case

负责人/管理员从机构视角发起新 Case 时：

- 管理身份提供机构监督/命令资格；
- teaching responsibility 必须由 server 解析到当前合法 Student Teacher Assignment；
- 默认 owner 为该 Profile 的 active Lead；
- 没有 active Lead 时 fail closed，先明确主责老师；
- 管理者本人只有在确实是目标 Profile 的合法任课老师时才可成为 Responsible Teacher。

## 4. 工作流矩阵

符号：R=读取，A=追加事实，E=修改当前快照，C=确认命令，G=治理，S=机构监督，—=默认无权。

| 工作流 | 负责人 | 管理员 | 已授权老师 |
| --- | --- | --- | --- |
| 机构设置 | G | 必要 G | — |
| 成员与邀请 | G | 邀请老师 / 提名负责人 | — |
| 学科范围 | G | G | R 本人 |
| 学生主档案 | G | G | R 已分配学生 |
| 学生任课分配 / handoff | G | G | — |
| Personal Today / Students / Learning | R/A/C：仅本人合法 Assignment | R/A/C：仅本人合法 Assignment | R/A/C：按本人 Assignment |
| Organization 学情详情 | R/S | R/S | — |
| 已有 Case 的机构监督 | S：按 command policy，保留原责任 | S：按 command policy，保留原责任 | — |
| Personal Quick Capture / new Case | A：仅本人通过完整 Gate | A：仅本人通过完整 Gate | A：完整 Gate |
| Organization Quick Capture / new Case | A/S：责任默认 active Lead；无 Lead 拒绝 | A/S：责任默认 active Lead；无 Lead 拒绝 | — |
| Evidence / Intervention / Assessment | Personal：Gate；Organization：监督 policy | Personal：Gate；Organization：监督 policy | R/A：Gate |
| Confirm / Stable / Close / Reopen | Personal：Gate+owner/policy；Organization：监督 policy | Personal：Gate+owner/policy；Organization：监督 policy | C：owner/policy |
| 成长历史 | Personal 仅任课 Profile；Organization 全机构监督范围 | Personal 仅任课 Profile；Organization 全机构监督范围 | R 已分配 Profile 的完整合法历史 |

任课交接不自动改写 Case owner 或 Action assignee；存在未关闭 Case 或待执行 Action 时拒绝交接，直到完成显式责任处理。

## 5. 数据隔离硬规则

- 任何角色都不能跨机构读取或写入数据；
- Personal Projection 必须有对应学生、学科和有效期内的任课分配；
- teaching scope 本身不授予整学科学生的 Personal Projection；
- 已停用成员、已结束范围、已结束 assignment、inactive/archived Profile 均 fail closed；
- 前端隐藏按钮只是体验，数据库 RLS 与受保护命令才是安全边界；
- handoff、停用和合并不改写历史 actor；
- Organization Projection 的“可见”不能被重新解释成“我的学生/我的任务”；
- responsibility-aware command 必须 server-side 验证负责老师，不能信任客户端传入 membership。

## 6. 必测负向矩阵

- teacher scope 但无 student assignment → Personal detail / Personal new Case 拒绝；
- Admin/Owner 无 Assignment → Personal Projection 为空，不自动成为 Case owner；
- Admin/Owner 监督已有 Case → actor 记录本人，但原 owner/assignee 保持；
- Organization Scope new Case + active Lead → owner 解析到 Lead；
- Organization Scope new Case + no active Lead → 拒绝；
- non-manager 指定其他 responsible membership → 拒绝；
- cross-org / ended / expired assignment 作为责任来源 → 拒绝；
- inactive/archived Profile → 拒绝新教学事实；
- collaborator 非 owner → 关键命令按 policy 拒绝；
- revoked session / disabled membership → 拒绝；
- 学生创建不得隐式新建或恢复教师教学范围。

## 7. 暂不增加角色

小型机构的班主任、学管、学科复核等现实分工，先作为流程责任、teacher assignment 或管理员治理任务表达。只有在真实试点证明三角色无法安全表达必要工作，而且新增角色的权限边界可以被自动化测试时，才重新评估新的系统角色。
