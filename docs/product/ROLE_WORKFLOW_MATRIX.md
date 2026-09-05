# Role / Workflow Matrix｜三角色权限矩阵

> 当前试点权限事实源。此前工作流草案中的 Academic Admin、Subject Lead、Advisor 是探索性分工，不再是可分配的系统角色。本文件的三角色合同优先。

## 1. 当前角色

| 角色 | 中文 | 主要职责 | 默认不能做 |
| --- | --- | --- | --- |
| `org_owner` | 负责人 | 管理机构；邀请管理员和老师；审批负责人提名；查看机构治理信息 | 仅凭负责人身份写教学事实 |
| `org_admin` | 管理员 | 管理老师、学生、学科范围、学生分配和必要运营信息 | 仅凭管理员身份读取未授权教学详情或写教学事实 |
| `teacher` | 老师 | 管理本人负责的学生；创建问题；记录行动、证据和验证；查看授权成长历史 | 查看其他机构或未分配学生 |

一个成员可以同时拥有管理角色和 `teacher`。系统始终按当前操作需要的完整条件授权，不因高层级角色自动获得教学权限。

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

## 3. Teaching Fact Gate

Quick Capture/new Learning Case、Evidence、Intervention、Assessment 与 Lesson 教师行为都必须同时满足：

```text
live session
+ active membership
+ teacher role
+ effective teaching subject scope
+ active Student Subject Profile
+ legal active Student Teacher Assignment
+ operation permission
```

负责人或管理员如果本人授课，必须同时拥有 `teacher` 并通过以上全部检查。管理身份不能代替教学范围、学生分配或 Case owner。

## 4. 工作流矩阵

符号：R=读取，A=追加事实，E=修改当前快照，C=确认命令，G=治理，—=默认无权。

| 工作流 | 负责人 | 管理员 | 已授权老师 |
| --- | --- | --- | --- |
| 机构设置 | G | 必要 G | — |
| 成员与邀请 | G | 邀请老师 / 提名负责人 | — |
| 学科范围 | G | G | R 本人 |
| 学生主档案 | G | G | R 已分配学生 |
| 学生任课分配 / handoff | G | G | — |
| 本科学情详情 | 仅另具 Teacher Gate | 仅另具 Teacher Gate | R/E（按 assignment） |
| Quick Capture / new Case | 仅另具 Teacher Gate | 仅另具 Teacher Gate | A（Gate） |
| Evidence / Intervention / Assessment | 仅另具 Teacher Gate | 仅另具 Teacher Gate | R/A（Gate） |
| Confirm / Stable / Close / Reopen | 仅另具 Teacher Gate 与 owner/policy | 仅另具 Teacher Gate 与 owner/policy | C（owner/policy） |
| Today / 成长历史 | 治理必要摘要；详细内容仍需 Gate | 治理必要摘要；详细内容仍需 Gate | R 已分配学生 |

## 5. 数据隔离硬规则

- 任何角色都不能跨机构读取或写入数据；
- 老师必须有对应学生、学科和有效期内的任课分配；
- 教学范围本身不授予整学科学生访问；
- 已停用成员、已结束范围、已结束 assignment、inactive/archived Profile 均 fail closed；
- 前端隐藏按钮只是体验，数据库 RLS 与受保护命令才是安全边界；
- handoff、停用和合并不改写历史 actor。

## 6. 必测负向矩阵

- teacher scope 但无 student assignment → 拒绝详情与 new Case；
- Admin-only → 拒绝 Quick Capture 和所有教学事实；
- 未授权学生 / 跨机构学生 → 拒绝；
- ended scope / ended assignment → 拒绝；
- inactive/archived Profile → 拒绝新教学事实；
- collaborator 非 owner → 关键命令按 policy 拒绝；
- revoked session / disabled membership → 拒绝；
- 学生创建不得隐式新建或恢复教师教学范围。

## 7. 暂不增加角色

小型机构的班主任、学管、学科复核等现实分工，先作为流程责任、teacher assignment 或管理员治理任务表达。只有在真实试点证明三角色无法安全表达必要工作，而且新增角色的权限边界可以被自动化测试时，才重新评估新的系统角色。
