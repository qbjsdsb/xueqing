# v0.3.8 Responsibility Read Model B1｜责任上下文基础设施

> 本文件是 PR #192 的真实实施边界，受 ADR-047 与 `docs/RESPONSIBILITY_MODEL.md` 约束。B1 只建立 server-authoritative responsibility context 与纯 Dart projection helpers；它**不声称已经改造既有 `TeacherWorkspace` 大模型，也不改变 UI/navigation 或任何写命令**。

## 1. 为什么拆成 B1 / B2

现有 `SupabaseLearningRepository.loadWorkspace()` 和 `TeacherWorkspace` 已承载大量稳定读取与 UI 兼容逻辑。为了避免在责任语义尚未稳定时直接重写大文件，本阶段采用两步：

```text
B1 责任上下文基础设施（本 PR）
→ B2 V2 responsibility projection integration（后续独立 PR）
```

B1 先让后端可靠回答“当前 membership 是谁、哪些 Assignment 真的是我的、现有 Case/Action/Event 的责任 membership 是谁”；B2 再把这些事实组合进 V2 的 Personal / Organization projection。这样旧教师工作台和 v0.3.7 客户端在 B1 阶段完全不受影响。

## 2. B1 唯一目标

提供一个最小、受控、可自动验证的责任上下文：

- 当前登录成员的 `currentMembershipId`；
- 当前成员自己的合法 `personalAssignments`；
- 当前调用者本来就有权读取的 Learning Case owner membership IDs；
- Action assignee membership IDs；
- Case Event actor membership IDs；
- 仅为这些已引用 membership 提供 `membershipId -> displayName`；
- 纯 Dart helper：`hasPersonalTeachingResponsibility`、personal profile IDs、`isPersonalAction` 等。

本 PR 不把 manager-wide visibility 解释成 Personal responsibility。

## 3. Personal Assignment read model

新增 additive、RLS-aware view：

```text
public.teacher_workspace_personal_assignments
```

每一行包含：

```text
organization_id
membership_id
student_subject_profile_id
assignment_id
assignment_role
business_date
```

只返回同时满足：

```text
current live app user
+ active organization
+ active membership belonging to current app user
+ teacher role/capability
+ active Student Teacher Assignment
+ assignment interval includes organization business_date
+ active Student Subject Profile
+ active Student
+ active Organization Subject + Subject
+ active teaching subject scope for same membership/subject
+ scope interval includes organization business_date
```

owner/admin 当前可能自动具有 `teacher` capability，但没有真实 teaching scope + Assignment 时必须为 0 行。

View 使用 `security_invoker = true`，authenticated 可读取、anon 不可读取，底层 RLS 不被旁路。

## 4. Responsibility context RPC

新增：

```text
public.get_workspace_responsibility_context(p_organization_id uuid)
```

公共 wrapper 为 security invoker；内部 security-definer helper 必须自己验证：

- live app identity；
- requested organization 中存在当前 active membership；
- 责任数据只来自调用者已经可读取的 Profile；
- 跨机构请求 fail closed。

返回 JSON：

```text
organization_id
current_membership_id
personal_assignments[]
case_owners[]
action_assignees[]
event_actors[]
member_display_names[]
```

该 RPC 不返回 email、credential、token、password、Auth metadata 等无关账号字段。

## 5. Minimal member display directory

显示姓名只为当前返回的 responsibility membership 建立最小目录：

```text
membership_id
display_name
```

不得为了显示老师姓名扩大 `app_users` 或 `organization_memberships` 的客户端表读取权限。历史记录可引用已停用成员，因此姓名目录允许保留历史 membership 的 display name，但必须仍属于当前 organization，并且只能通过当前已可读责任记录被引用。

## 6. Dart contract

新增独立 `ResponsibilityReadRepository` 与 `WorkspaceResponsibilityContext`，而不是在 B1 直接改写现有大 `LearningRepository`。

最小 helper：

```text
hasPersonalTeachingResponsibility
personalProfileIds
isPersonalProfile(profileId)
isPersonalAction(actionId)
displayNameForMembership(membershipId)
```

`hasPersonalTeachingResponsibility` 只能由合法 `personalAssignments.isNotEmpty` 推导，不能由角色 `org_owner / org_admin / teacher` 推导。

## 7. B1 明确不做

本 PR 不：

- 修改 `TeacherWorkspace`、`WorkspaceCase`、`WorkspaceAction`、`WorkspaceTimelineEvent` 的现有构造合同；
- 改 `SupabaseLearningRepository.loadWorkspace()` 的现有 manager-wide snapshot；
- 改 Quick Capture / Case command 责任写入；
- 实现 Organization Workspace；
- 修改窄屏/桌面导航；
- 改草稿 scope；
- 部署生产 Supabase migration。

这些边界是为了让本 PR 可独立验证、可回滚，不代表这些工作被取消。

## 8. B2 后续接入 Gate

B1 合并后立即建立独立 B2，把 responsibility context 接进 V2 读取链。B2 必须做到：

- 在现有 workspace snapshot 之上组合 responsibility context，而不是复制第二套 Case UI；
- Personal Students 仅取 `personalProfileIds`；
- Personal Today 仅取 `assignedMembershipId == currentMembershipId`；
- Personal Profile 内仍展示该 Profile 完整合法 Case 历史，不按 owner 再过滤；
- manager 没有 Assignment 时不再因为 `hasTeachingAccess` 而看到全机构数据冒充个人工作区；
- Organization Projection 才使用 manager-wide snapshot；
- 保留 Lessons Teaching Fact Gate；
- 暂不进入 responsibility-safe writes。

B2 完成以前，新的 responsibility context 不作为最终 UI scope 事实源发布。

## 9. SQL 测试硬约束

B1 至少验证：

- view 存在且 `security_invoker=true`；
- anon 无 select / RPC execute；
- authenticated 可 reach；
- user without membership → 0 personal rows，RPC fail closed；
- cross-org → 0 / fail closed；
- pure manager 即使有 teacher capability，没 scope + Assignment → 0；
- manager 有真实 scope + Assignment → 只返回自己的 Assignment；
- collaborator Assignment 属于 Personal Projection；
- ended/expired Assignment → 立即移出；
- ended/expired teaching scope → 立即移出；
- inactive Profile → 移出；
- inactive Student → 移出；
- inactive Organization Subject → 移出；
- inactive organization → 移出；
- 恢复合法状态后 Personal Projection 可恢复；
- existing RLS / cross-org / old-token regression 继续通过。

## 10. Flutter/Dart 测试硬约束

至少验证：

- `currentMembershipId` 正确解析；
- personal assignment / role / business date 正确解析；
- Case owner / Action assignee / Event actor membership maps 不丢失；
- pure manager context 可有 organization responsibility facts，但 `personalAssignments` 仍为空；
- `isPersonalAction` 只认 assigned 给当前 membership 的 Action；
- display-name 缺失安全返回 null，不崩溃；
- malformed / duplicate responsibility keys fail closed。

## 11. 性能与兼容

- 优先复用现有 assignment/scope/profile 索引，不为 pilot 预先堆索引；
- migration 仅 additive；
- 不修改 v0.3.7 正在调用的 RPC signature；
- B1 部署到开发数据库后，旧客户端行为保持不变；
- 后续 B2/PR C 才通过 capability-aware 路径消费新合同。

## 12. B1 停止条件

PR #192 可以 Ready 的条件：

1. server-authoritative Personal Assignment source 存在；
2. responsibility context RPC 安全收口；
3. minimal display-name directory 不扩权；
4. Dart context/helper 可稳定解析；
5. lifecycle/cross-org/manager-without-assignment 负向测试完整；
6. Flutter format/analyze/test 通过；
7. Supabase rebuild/RLS/old-token tests 通过；
8. platform build smoke 通过；
9. PR 文档不再声称已经接入既有 `TeacherWorkspace`；
10. 不改写入、不改 UI、不部署生产。
