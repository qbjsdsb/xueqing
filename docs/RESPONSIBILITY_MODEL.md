# Xueqing 教学责任模型

> 本文冻结 v0.3.8 起的责任语义。它解决的是“谁能看、谁能监督、谁真正负责、谁实际操作”四件事长期混用的问题。

## 1. 核心原则

Xueqing 记录的是学生成长过程中的真实教学责任，不是简单的数据访问权限。

任何重要教学事实必须能够回答：

1. 谁实际执行了这次操作；
2. 谁对这个 Case 的持续跟进负责；
3. 下一步 Action 应该由谁执行。

因此必须严格区分：

- **Actor**：实际执行当前操作的成员；
- **Supervisor**：因机构负责人/管理员身份拥有机构级查看与监督能力的成员；
- **Responsible Teacher**：基于真实教学关系承担 Student Subject Profile / Case / Action 教学责任的老师。

`Actor`、`Supervisor`、`Responsible Teacher` 可以是同一个人，也可以是不同的人。

## 2. Access 不等于 Responsibility

负责人或管理员可以因为机构管理能力读取、监督和治理机构内的学情，但这不意味着他们自动成为任课老师、Case owner 或 Action assignee。

管理身份只能回答：

> 这个人是否有权在机构视角查看或监督？

教学责任必须由真实教学事实回答：

> 这个人是否真的负责该学生该学科？

合法教学责任至少依赖：

```text
active membership
+ teacher role/capability
+ active teaching subject scope
+ active Student Subject Profile
+ legal active Student Teacher Assignment
+ organization business date validity
```

负责人/管理员如果同时真实任课，也必须满足同一套 Teaching Fact Gate；不能因为管理角色绕过 Assignment。

## 3. Personal Projection 与 Organization Projection

同一份授权后的 Workspace 数据只产生两种视角，不建立两套业务系统。

### Personal Projection

用于 v0.3.x 当前生产 V2 教师主线“今日 / 学生 / 学情”。Lesson / 课程仍保留为未来领域能力，但当前没有可发布的 Lesson 运行时，因此不作为一级入口。

只表达当前登录者自己的教学责任：

- 我的学生：当前成员存在合法有效 Student Teacher Assignment 的 Profile；
- 我的今日：`pending primary action.assigned_membership_id == currentMembershipId`；
- 未来我的课程：只有在真实 Lesson 能力上线后，才可在本人合法 Assignment / Teaching Fact Gate 下进入教学会话；当前 v0.3.x 不展示该入口；
- 我的学情：当前成员真实任课 Profile 的完整合法成长历史，不按 Case owner 再次切碎历史。

负责人/管理员如果没有真实任课 Assignment，则 Personal Projection 可以为空。

### Organization Projection

仅对具有机构监督能力的负责人/管理员开放。

它表达：

- 全机构学生与学情监督；
- 按学生、学科、状态、责任老师筛选；
- 对既有 Case 进行合法监督性操作；
- 进入机构管理能力。

Organization Projection 不把机构可见数据重新标记成“我的学生/我的任务”。

## 4. Case owner 与 Action assignee

### Case owner

Case owner 表示当前主要教学责任人，不等于最后操作者，也不等于拥有管理权限的人。

### Action assignee

Action assignee 表示下一步行动的真实执行责任人。

v0.3.8 第一阶段默认：新 Case 的首个 primary Action 交给 Case owner；复杂 Action 分派后置，不在本版本扩张范围。

## 5. 管理者监督既有 Case

负责人/管理员可以在机构监督权限允许的范围内处理已有 Case，但监督操作不得静默接管原责任关系。

例如：

```text
张老师负责 王同学·语文
李管理员确认该 Case 并补充干预记录
```

正确事实应为：

```text
case.owner_membership_id          = 张老师
primary_action.assigned_membership_id = 张老师
case_event.actor_membership_id    = 李管理员
```

也就是说：

- 责任仍属于张老师；
- 操作审计真实记录李管理员；
- 管理者参与不自动改写责任链。

## 6. 新建 Case 的责任解析

### Personal Scope

普通老师或同时任课的管理者在个人工作区创建 Case：

- responsible membership = 当前成员；
- server 必须重新验证完整 Teaching Fact Gate；
- 不能只因为客户端处于个人页面就信任责任身份。

### Organization Scope

管理者从机构视角创建 Case：

- 默认 responsible membership = 当前 Profile 的 active Lead；
- 如果管理者本人就是合法 active Lead，可以成为 owner；
- 如允许显式选择其他成员，该成员必须是该 Profile 当前合法 Assignment 的老师；
- 没有 active Lead 时，不创建正式 Case，先明确主责老师。

管理角色本身永远不是成为新 Case owner 的充分条件。

## 7. Actor 与写入审计

任何 responsibility-aware command 都必须分别解析：

```text
actor_membership_id
responsible_membership_id
```

当二者不同：

- actor 必须具备对应机构监督/命令权限；
- responsible member 必须满足真实教学责任条件；
- Evidence / Event 等审计事实记录实际 actor；
- Case owner / Action assignee 记录教学责任人。

不得继续用一个 `membership_id` 同时代表“谁能操作”和“谁负责”。

## 8. 历史责任与当前责任

过去的 Evidence、Intervention、Assessment、Event actor 不因为任课交接、成员停用或责任修正而被重写。

v0.3.8 采用：

> 防止继续产生错误责任，优先于静默批量改写历史。

历史 Case 如果 owner 已不满足当前教学 Assignment，应被识别为“责任关系待确认”，后续通过显式责任治理/交接处理；migration 不应无声替换老师。

## 9. Handoff

Student Teacher Assignment handoff 与 Case/Action responsibility handoff 是两个不同业务事实，但安全的 handoff command 可以、也通常应该在**一个显式确认的责任迁移计划**里原子处理二者。

规则冻结为：

- 单独结束 Assignment、scope 或 membership 时，如果会留下 open Case owner / pending Action assignee orphan，必须 fail closed；
- `reassign_teacher`、`revoke_teacher_subject_scope_and_handoff`、`disable_membership_and_handoff` 等显式 handoff 命令必须先让 server 根据当前数据生成/验证完整 affected responsibility set；
- 用户明确确认接手老师与受影响责任后，命令在同一事务锁定并迁移 Assignment、当前 Case owner、pending Action assignee，写 event/audit，并验证 no orphan；
- 任何 stale assignment、scope、membership、Case/Action version 或责任集合漂移都应 whole rollback，要求重新加载/确认；
- 已提交的历史 Evidence、Intervention、Assessment 与 Event actor 永不因 handoff 改写。

因此，“Assignment 与 Responsibility 不是同一个事实”不等于必须拆成两个可部分成功的事务；真正禁止的是**只改 Assignment 就静默、无确认地把全部责任自动搬给新老师**。

## 10. 导航语义

导航由“是否有个人教学责任”和“是否有机构监督能力”共同决定，而不是只看角色名。

- 普通任课老师：今日 / 学生 / 学情；
- 同时任课的负责人/管理员：今日 / 学生 / 学情，并通过独立机构 scope 进入机构；
- 没有任课关系的负责人/管理员：直接进入机构工作区；
- 没有当前任课的普通老师：显示暂无当前任课学生。

这里冻结的是产品语义，不提前决定窄屏如何折叠五个入口；具体 Android / Windows 导航布局属于后续 UI PR。

因此客户端必须逐步淘汰把 `org_owner / org_admin / teacher` 统一折叠成 `hasTeachingAccess` 的旧语义，改为显式区分：

- `hasPersonalTeachingResponsibility`；
- `canManageOrganization` / organization supervision capability。

## 11. 草稿、刷新与返回

Personal / Organization 是正式 UI scope。

- Quick Capture draft 必须带 scope，避免机构草稿恢复进个人工作区；
- refresh 必须保留 scope、当前学生和当前 Case；
- Android back 必须先退出 Case/Student 子层，再退出当前 scope，最后才允许离开应用。

## 12. 兼容策略

后端 responsibility 改造必须 additive：

- 保留旧客户端仍调用的 RPC；
- 旧 RPC 也必须避免继续制造“管理者因为有访问权就自动成为责任人”的新错误数据；
- 新客户端通过 capability gate 使用 responsibility-aware contract；
- 不通过 capability 时不得静默降级为不安全写法。

## 13. 测试硬约束

至少覆盖：

- teacher 只能把自己作为个人 Scope 的责任人；
- collaborator 属于个人任课 Profile，但 Case owner 可以是 Lead；
- admin/owner 无 Assignment 时 Personal Projection 为空；
- admin/owner 监督已有 Case 时 actor 改变、owner/assignee 不被接管；
- Organization Scope 新建默认给 active Lead；
- 无 Lead 时拒绝正式创建；
- 非管理者不能指定其他责任人；
- 跨机构 membership 拒绝；
- stale Assignment / stale responsibility 保存拒绝；
- handoff 只按显式确认计划原子迁移当前责任，不改写历史；
- Personal Today 只包含 assigned 给当前 membership 的 primary Action；
- Personal / Organization draft 不串；
- Android back 与 refresh 不丢失 scope；
- 未来引入 Lesson 时，Responsibility refactor 不得删除或绕过 participant Teaching Fact Gate。

## 14. 非目标

本责任模型不引入：

- 教师绩效排名；
- 管理驾驶舱；
- AI 风险评分；
- 新组织角色；
- 第二套 Admin Case UI；
- 自动批量改写历史 owner；
- 复杂 Action 分派系统。

目标只有一个：

> 让 Xueqing 在任何时候都能可靠回答：谁做了这件事、谁负责这个问题、下一步该谁做。
