# 账号与权限模型

> V1 面向少量已知内部教师。目标：账号接管、机构授权、学科范围、学生分配、Session revoke 与 teaching-fact 权限全部可解释、可测试。

> v0.3.8 起，本文受 ADR-047 与 `RESPONSIBILITY_MODEL.md` 约束：**机构监督权、实际操作者和教学责任必须分开解释。** 管理者可以监督机构学情，但管理角色本身不能替代真实 Student Teacher Assignment 成为新的教学责任来源。

## 1. 授权五层

```text
Auth Identity / live Session
→ Organization Membership
→ Role / Capability
→ Subject Scope
→ Student / Staff Assignment
→ entity state / owner / command policy
```

能登录不等于能读学生数据；前端隐藏按钮不是权限控制。

## 2. Provider status

Production provider 尚未冻结。ADR-045：Supabase reference candidate、CloudBase mainland candidate、自托管 fallback。

Phase 0B.0 pre-migration P0：
1. Auth Identity Portability；
2. Revoked Session / Old Token Security。

## 3. Membership

status：onboarding / active / disabled。

onboarding：可最小 Auth 接管，但普通学生业务全部拒绝；可以预配置 roles/scopes，不等于 active。

disabled：所有学生业务拒绝，历史 actor 保留。

## 4. V1 Auth UX

org_admin provision known member → temporary password once → membership onboarding → user changes credential → revoke old sessions → membership active → forced re-login。

Password/Token/高权限 Secret 不进业务 DB/log/GitHub/Flutter。

## 5. Live Session hard rule

普通学生业务必须同时有：有效 Auth identity + 当前 Session still live + membership active + 后续权限关系。

Supabase `JWT session_id → auth.sessions` 只是 reference；其他 provider 必须 old-token negative test 证明等价。

## 6. Role、Scope、Assignment 与责任语义

当前试点只保留三种机构角色：org_owner / org_admin / teacher。

- org_owner：机构负责人，管理机构、管理员和老师，并具备机构级学情监督能力；
- org_admin：管理员，管理老师、学生和教学关系，并具备机构级学情监督能力；
- teacher：老师，仅在有效教学范围和学生分配内承担个人教学责任。

学管、班主任或学科复核等分工先通过人员关系和流程表达，不新增系统角色。

`scope_kind=teaching`：可承担该科 teacher assignment；不自动访问全学科学生。

`scope_kind=leadership` 为早期预留字段，当前试点不据此授予任何能力。

### Actor / Supervisor / Responsible Teacher

必须区分：

- **Actor**：实际执行当前命令的人；
- **Supervisor**：因 org_owner / org_admin 身份拥有机构级监督能力的人；
- **Responsible Teacher**：基于合法 Assignment 承担具体学生学科、Case 或 Action 责任的人。

同一个成员可以同时具有多个身份，但系统不能因为“能看/能监督”就自动推断“由他负责”。

## 7. Student Assignment

普通 teacher 访问具体学生本科数据需要 active `student_teacher_assignment` + active Profile。

Lead：主要责任；Collaborator：协作。Case owner 是责任关系，不是 Role。

负责人/管理员如果本人也要承担具体学生教学责任，同样必须存在合法 active Student Teacher Assignment；管理角色不能替代 Assignment。

非学科协调职责当前不形成独立角色，也不自动产生教学责任。

## 8. Teaching Fact Gate｜责任硬定义

以下全部属于 teaching facts / teaching Case lifecycle：
- teaching Evidence；
- Intervention；
- Assessment；
- Lesson teacher behavior；
- Quick Capture / new Learning Case。

### 8.1 Personal Scope

当 actor 以自己的教师责任身份产生教学事实时，必须同时满足：

```text
live session
+ membership active
+ teacher capability
+ matching active teaching subject scope
+ target Student Subject Profile active
+ actor 的 legal active Student Teacher Assignment
+ operation-specific permission
```

### 8.2 Organization supervision

负责人/管理员可依据机构监督能力读取并监督已有 Case，但必须继续区分：

```text
actor membership
!=
responsible membership
```

监督已有 Case 时：

- Event / audit 记录真实 actor；
- 原 Case owner 与 pending Action assignee 不因一次监督操作自动改成管理员；
- command 仍需满足 entity state 与 command-specific policy；
- 管理者不能借监督权把自己伪装成不存在的任课关系。

### 8.3 Organization Scope 新建 Case

管理者从机构视角创建新 Case 时：

- 管理身份提供监督/命令资格；
- Case responsibility 必须解析到目标 Profile 的合法 active teaching assignment；
- 默认责任人是 active Lead；
- 如允许显式选择其他老师，该成员必须是当前合法 Assignment；
- 没有 active Lead 时 fail closed，先明确主责老师；
- 管理者本人只有在同时满足完整 Teaching Fact Gate 且确实承担该 Profile Assignment 时，才能成为 Responsible Teacher。

因此：

> Admin-only 不能因为“管理者”这一身份本身成为新 teaching Case owner；但具备机构监督权限的管理者可以监督已有 Case，并可在 Organization Scope 为合法责任老师发起责任安全的新 Case。

### `start_lesson` actor / participant contract

Actor Gate 与 Per-Student Participant Gate 必须分开解释：执行 `start_lesson` 的 member/teacher 才需要 live active authenticated identity、valid active session、active membership、teacher capability、required teaching Subject Scope、operation permission 与其他 Teaching Fact Gate 条件；Student participant 本身不需要、也不“拥有” live identity/session。对每一个 participant，server 另须验证 Student current/legal、Subject Profile active、actor 对该 Student+Subject 的 legal active Student Teacher Assignment，以及 organization/subject/Lesson context 一致。

`lesson_students` 只表达 participation business fact，不是 authorization source。已有 participant 不能绕过 assignment；assignment 在 Lesson 中途撤销后，后续 teaching writes 与 ordinary complete fail closed，治理 actor 仅可 controlled cancel/cleanup。临时代课只能使用有效期明确的 collaborator assignment。

### V1 Lesson authorization rule

V1 所有以教师本人责任身份发生的教学写权限必须依赖 legal active Student Teacher Assignment。Lesson 或 `lesson_students` participant 记录只表达实际参与事实，不能替代 assignment、grant temporary permission 或创建 capability/scope。

`start_lesson` 创建前必须为每个 participant 验证完整 Gate；仅有 teaching scope、把 Student 自己加入 participants、或 Lesson 已经 `in_progress` 都不能形成授权。临时代课统一用 time-bounded collaborator assignment（`active_from`/`active_to`），在有效期间按同一 Gate 工作。

### 绝对禁止 bypass

- 管理 Role 本身不可替代 Responsible Teacher 的 legal active Student Teacher Assignment；
- inactive/archived Profile → 即使残留旧 assignment 也拒绝产生新的正式教学责任事实；
- Initial Diagnosis 的“管理员授权”不能替代 legal active Student Teacher Assignment；
- 客户端传入的 responsible membership 必须由 server 重新验证，不能信任 UI scope；
- 跨机构、已结束、过期或无对应 teaching scope 的 Assignment 不能被选作新责任人。

非教学专业记录未来走 Parent Communication / Observation，不借 Learning Case 绕过教师权限。

## 9. Case command permissions

confirm/stable/close/reopen 等关键 command 除访问能力外还需要 entity state、责任关系和 command-specific permission。

管理者监督既有 Case 时，允许在明确 policy 下执行监督性 command，但必须保留原责任语义：actor 真实记录，owner / assignee 不因监督操作自动接管。

`reopen_case` 的责任规则必须显式区分：

- Personal Scope：由通过完整 Teaching Fact Gate 的合法责任老师执行；
- Organization supervision：只有在专门 command policy 明确允许、且不会把管理者错误变成责任人的情况下开放；否则 fail closed。

无论由谁执行，Server 都必须在事务内解析最新已提交 `case_closed` event；recurrence Evidence 必须满足 `observed_at > latest case_closed.occurred_at`。

## 10. Subject service suspension

Profile inactive/archived：
- 普通 teaching reads/writes 按最小必要原则限制；
- 新 teaching fact/new Case/new Lesson 全拒绝；
- unresolved Case 可保留 history，但不进普通 Today。

reactivate command 恢复 relationship 后才重开教学写入。

## 11. Student lifecycle / merge governance

Student deactivate/archive/unarchive/reactivate/merge 是 governance commands，需要 operation_id、expected versions、locks 与 audit。

Student merge 的 semantic conflict 不由 admin 超权自动猜测；遵守 `STUDENT_MERGE_POLICY.md`。

## 12. RLS / command test matrix

至少：
- teacher scope but no assignment → no personal detail/new Case；
- manager without assignment → Personal Projection 为空，不自动成为 Case owner；
- manager supervision existing Case → actor 变化，owner/assignee 不被静默接管；
- Organization Scope new Case → responsibility 解析到合法 active Lead；
- Organization Scope no active Lead → fail closed；
- non-manager 指定其他 responsible membership → deny；
- cross-org / ended / expired responsible assignment → deny；
- inactive/archived Profile old assignment → deny new teaching fact；
- closed Case + inactive Profile reopen → deny；
- collaborator non-owner critical command → deny unless explicit policy；
- revoked/reset/disabled old token → deny；
- Org A/B isolation；
- onboarding → no student data；
- Student merged source → no new current business operations。

## 13. Function security

RLS + GRANT + command checks。security invoker 优先；security definer 仅非 exposed schema、fixed search_path、least grants。Provider service/admin Secret 只在可信服务端。

责任相关 RPC 还必须做到：

- server-side 重新解析 actor；
- server-side 验证 responsible membership；
- 不允许一个模糊 membership helper 同时承担 access authorization 与 responsibility assignment；
- operation_id / expected_version / stale assignment 冲突 fail closed。

## 14. Historical actor / responsibility

Handoff/disable/merge/service suspension 不重写过去 Evidence/Intervention/Assessment/finalized snapshot actor。

当前责任与历史责任分开。

历史 Case 如果 owner 已不满足当前 Assignment，不通过 migration 静默批量换老师；应识别为责任关系待确认，并通过显式 handoff / responsibility governance 处理。

Student Teacher Assignment handoff 与 Case/Action responsibility handoff 是两个不同业务事实，不能互相自动替代。

## 15. UI projection contract

权限层必须支持客户端区分：

- `hasPersonalTeachingResponsibility`：当前成员是否存在合法个人任课关系；
- `canManageOrganization` / organization supervision capability：是否拥有机构级监督与管理入口。

Personal Projection 只能形成“我的今日 / 我的学生 / 我的学情”；Organization Projection 才承载全机构监督数据。

不得继续用单一 `hasTeachingAccess` 同时表达“我本人有任课”和“我能监督机构”。
