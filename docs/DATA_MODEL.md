# 核心数据模型

> 目标：稳定表达真实教学事实，不为页面造表。正式 schema 最终以 migrations 为事实源；本文冻结领域语义与硬不变量。

## 1. 建模原则

- 主键默认业务 UUID；
- 系统事件时间 UTC `timestamptz`；业务日期按 organization timezone；
- 机构业务对象显式 `organization_id`；
- 人员责任引用 membership；
- Student/Subject service lifecycle 与 Learning Case resolution lifecycle 分层；
- 当前快照 + append-only history；
- finalized communication/report 不随后续事实静默改写；
- 关键 aggregate 使用 `version`；
- 同一事实只存一次，周度/阶段/治理提示优先派生；
- provider-specific Auth/Storage 不渗透业务对象。

### Phase 0B.0 pre-migration hard gates

P0 Gate A（Auth Identity Portability）与 P0 Gate B（Revoked Session / Old Token Security）的 compatibility spike 已通过；Production provider、region 与最终 session strategy 仍未冻结。正式 production business migrations 前，仍需完成候选 provider 的地区网络、Storage、backup/restore 与 Go/No-Go 证据。

Supabase 是 reference candidate，不是已锁定 provider。

---

## 2. Organization / Identity / Authorization

### `organizations`
- `id`
- `name`
- `time_zone`
- `status`
- timestamps

### `app_users`
- `id`: application-owned stable UUID
- `display_name`
- `status`
- timestamps
- no foreign key to a provider auth primary key

### `identity_links`
- `id`
- `app_user_id`
- `provider_key`
- `issuer`: provider project, environment, or tenant namespace
- `external_subject`: opaque `text`; never cast to UUID
- `status`: active / retired
- timestamps / retired_at
- unique `(provider_key, issuer, external_subject)`
- V1 partial uniqueness: at most one active link per App User

A provider switch retires the old link and activates the new link in one controlled transaction. Business facts reference `app_user_id`; they never reference `external_subject` or a provider auth primary key. Email is not an identity key.

### `organization_memberships`
- `id`
- `organization_id`
- `app_user_id`
- `status`: onboarding / active / disabled
- timestamps / onboarding expiry

### `membership_roles`
V1 roles：org_admin / academic_admin / subject_lead / teacher / student_advisor。

### `membership_subject_scopes`
- `id`
- `organization_id`
- `membership_id`
- `organization_subject_id`
- `scope_kind`: teaching / leadership
- `status`
- active interval / timestamps

Teaching scope 只代表可承担该科学科教学关系，不授予全部学生访问；leadership scope 不能伪造教学 actor。

---

## 3. Student aggregate

### `students`
- `id`
- `organization_id`
- `student_code` optional
- `display_name`
- `status`: active / inactive / archived / merged
- `merged_into_student_id` only merged
- **`version`**
- timestamps / archived_at

姓名不是硬唯一。

### Student lifecycle

```text
active --deactivate_student--> inactive --archive_student--> archived
active <--reactivate_student-- inactive <--unarchive_student-- archived
```

- archived 可恢复但必须先 inactive；
- merged 是 current-business terminal identity；
- `students.version` 只表示 Student root/current canonical/lifecycle snapshot；
- 成功的 deactivate/archive/unarchive/reactivate 各使 Student.version +1 exactly once；
- `merge_students` 成功时 source.version +1 exactly once、target.version +1 exactly once；
- 普通 Evidence/Assessment append、普通 Case transition、普通 Assignment current-state change 不机械递增 Student.version；
- Student multi-Profile command 必须同时验证 Student expected version、受影响子聚合 versions 与 current relation snapshot；
- 同 operation retry 不重复 version increment。

### `student_enrollments`
- `id`
- organization/student/term/campus
- grade/class
- starts_on / ends_on

升年级/换校区保留历史，不新建 Student。

---

## 4. Subject model

### `subjects` / `organization_subjects` / `learning_taxonomy_nodes`
稳定字典 + 机构学科 + 轻量 taxonomy。历史已引用节点停用而非硬删。

### `student_subject_profiles`
- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`
- `status`: active / inactive / archived
- current positioning / strengths / optional cadence note
- `version`
- timestamps

唯一 `(organization_id, student_id, organization_subject_id)`。

### Profile committed-state rules

active：
- 可以存在合法 active teacher assignments；
- formal open Cases 必须 owner + pending primary Action；
- 可以产生教学事实/Lesson。

inactive/archived：
- 无 active teacher assignment；
- unresolved Case 可保留真实 status；
- 无普通 pending primary Action；
- 不进普通 Today；
- 不产生新 teaching facts/new Lesson/new teaching Case。

事务内部 staging 不属于可观察 committed state。

### `student_teacher_assignments`
- `id`
- organization/student/organization_subject/membership
- assignment_role: lead / collaborator
- active interval / status

Committed active assignment 必须：active membership + teacher capability + active teaching scope + Profile active。

### `student_staff_assignments`
Advisor/homeroom/coordinator 等综合职责；不伪装学科教师。

---

## 5. Learning Case

### `learning_cases`
- `id`
- `organization_id`
- `student_subject_profile_id`
- `owner_membership_id`
- `case_type`: knowledge / habit / exam_strategy / other
- taxonomy/title/description/root cause/priority
- `status`: new / confirmed / intervening / pending_verification / stable / closed
- `first_observed_at`
- `stable_at`
- `closed_at`
- `reopened_count`
- `version`
- created_by/timestamps

Phase 0B.0-C physical foundation:
- `learning_cases` is the current Case snapshot; `version` protects state-changing commands；
- `case_events` is append-only and command-generated lifecycle events carry operation identity；
- `case_evidence` is finalized append-only history in this vertical slice；
- `operation_receipts` stores the committed result for exactly-once command retry。

唯一 lifecycle：

```text
new → confirmed → intervening → pending_verification → stable → closed
```

`reopen` 不是 status。

Active Profile formal open Case 必须 owner + exactly one pending primary Action；inactive/archived 是 tracking-suspended exception。

### reopen current snapshot semantics
`reopen_case` 唯一 target：`closed → confirmed`。

Commit 后：
- `status=confirmed`
- `closed_at=null`
- `stable_at=null`
- `reopened_count += 1`
- legal owner
- exactly one pending primary Action
- `version += 1`

旧 stable/closed 时间保存在 Case Events。

### `case_events`
- `id`
- `organization_id`
- `learning_case_id`
- `event_type`
- actor
- `occurred_at`
- metadata
- `operation_id` optional for ordinary manual events, REQUIRED for high-risk command-generated lifecycle events
- `operation_event_key` required when operation_id is present

`case_closed` 是 close lifecycle command 在成功事务中写入的 immutable lifecycle fact；只有 committed close 才能成为后续 `reopen_case` 的 boundary。它不能因为 current Case snapshot 后续 reopen 而消失或被改写。`case_reopened` metadata 必须引用 server-resolved latest previous `case_closed` event 与 recurrence Evidence IDs。

逻辑唯一：

```text
(organization_id, operation_id, operation_event_key)
```

command retry 不得重复 lifecycle event。

### `case_evidence`
- Case/source type/title/`observed_at`/summary/storage path/created_by/`created_at`
- `observed_at` 是事实实际发生或被观察到的业务时间；
- `created_at` 是 Evidence 录入系统的时间，不能替代 `observed_at`；
- `guardian_report` 可引用 source Parent Communication；
- recurrence candidate 必须属于目标 Case、具备 non-null observed_at，并满足 `observed_at > latest committed case_closed.occurred_at`；
- source_type 不构成 recurrence 白名单或自动证明；合法 source type 均须通过 Evidence 合法性与 teacher judgment；
- 旧 Evidence 可被新 post-close Evidence 引用，但旧 observed_at 不能单独 reopen。

#### Committed Evidence：append-only historical fact

- Evidence 在服务端 commit 前可以是 Draft；只有 committed/finalized Evidence 才能进入正式 timeline、Case history 或被 `reopen_case` 作为 recurrence 依据。
- 一旦 committed/finalized，Evidence 的历史含义与 provenance 冻结：不得通过普通 UPDATE、reparent 或物理 DELETE 改变/抹掉 `case_id`、`observed_at`、`created_at`、author/source attribution、provenance 或其他 recurrence-relevant 字段。
- 记录错误时必须沿用现有 Evidence/Event 领域模型表达 correction record、superseding Evidence 或 explicit correction/invalidation event；不得静默改写原 Evidence，也不得为了本规则创建第二套 Evidence 模型。
- `reopen_case` 必须在同一 logical DB transaction 内 lock/re-read 每条 selected recurrence Evidence，重新确认其仍 committed、legally usable、属于目标 Case，且其 expected Evidence version 或 server-issued opaque freshness token 未漂移；任何 drift、invalidation、reparent 或 version conflict 都整体拒绝并 rollback。
- physical implementation（immutable revision、version 或 freshness token）可在 Phase 0B.0 provider Spike 中冻结；Phase 0A.6 先冻结以上逻辑契约。任一 Case/close-event/Evidence/Profile/assignment/version 校验失败都必须 whole rollback，并返回明确 domain conflict；

### `interventions`
- `id`
- `organization_id`
- `learning_case_id`
- actor App User / Membership
- `strategy` / `notes` / `occurred_at` / `created_at`
- finalized append-only teaching history

### `assessments`
- `id`
- `organization_id`
- `learning_case_id`
- assessor App User / Membership
- `result`: passed / partial / not_passed
- `evidence_summary` / `notes` / `assessed_at` / `created_at`
- finalized append-only verification history

### Teaching Fact Gate

以下全部必须同时满足：

```text
live session
+ active membership
+ teacher capability
+ active teaching scope
+ target Profile active
+ legal active Student Teacher Assignment
+ operation-specific permission
```

V1 所有 teaching writes 依赖 legal active Student Teacher Assignment。Lesson participant/`lesson_students` 只记录实际参与事实，不是 authorization grant、temporary permission、capability、scope 或 Student Teacher Assignment；把 Student 加入 Lesson 不能自我授权。

## 7. Case Action

### `case_actions`
- `id`
- organization/case/assigned_membership
- action_type: reteach / practice / verify / communicate / review / other
- title/due_at/is_primary
- status: pending / done / cancelled
- completed_at / cancelled_at / actor provenance / version / timestamps

Phase 0B.0-C 的命令只授予一个 pending primary Action；状态变化先结束旧 primary，再在同一事务创建新 primary。关闭 Case 会取消当前 primary。

Rules：
- 同一 Case 最多一个 pending primary；
- active Profile formal open Case 恰好一个 pending primary；
- inactive/archived unresolved Case 可无 primary；
- closed 无 pending primary；
- Guardian 不是 membership，不成为 Action assignee。

---

## 8. Lesson

### `lessons`
- `id`
- organization/subject/teacher
- started_at/ended_at
- status: in_progress/completed/cancelled
- summary
- `version`
- timestamps

### `lesson_students`
- lesson/student/attendance；
- 仅表示某 Student 实际参与某次 Lesson 的 business fact；
- 不是 authorization grant、temporary permission、Student Teacher Assignment、capability 或 scope；
- `start_lesson` 创建前每一个 participant 都必须已有 legal active Student Teacher Assignment；
- assignment 在 Lesson 中被撤销后，后续 teaching writes 与 ordinary complete 均拒绝；controlled governance cancel 只做 cleanup；
- 历史 lesson teacher/participant provenance 不静默改写。

## 9. Guardian / Communication

### `guardians` / `student_guardians`
只收集教学协作必要信息。

### `parent_communications`
一次实际沟通 event：
- direction: outbound / inbound / conversation
- status: draft / finalized
- channel/occurred_at/content snapshot/home support/guardian response
- reply_to optional
- recorded_by/finalized_by/finalized_at
- follow-up fields
- `version`

异步 reply 新增 inbound，不回写旧 finalized outbound。

多 recipient 可使用 `parent_communication_recipients`。

---

## 10. Report / Stage Review

### `reports`
- student + optional subject
- report_type/period/source_cutoff
- template/content schema version
- content_snapshot
- status draft/finalized
- `version`
- finalized_by/time
- correction/supersede provenance

Finalized Report ≠ Parent informed。

---

## 11. Operation / Audit

### Logical `operation_receipts`
高风险 DB command 必须有等价的 operation result registry；物理表名可在 Phase 0B 冻结。

最小语义：
- `organization_id`
- `operation_id`
- command_type
- target_type / target_id
- committed result reference/fingerprint
- committed_at

唯一 `(organization_id, operation_id)`。

如果事务 rollback，不能留下“已 committed” receipt；同 operation 重试若已 committed 直接返回原结果。

### `audit_logs`
- id/org/actor identity + membership
- entity type/id/action/changed_fields
- **`operation_id` REQUIRED for high-risk command audit**
- **`operation_audit_key` REQUIRED when operation_id present**
- occurred_at

逻辑唯一：

```text
(organization_id, operation_id, operation_audit_key)
```

普通低风险 audit 若无 command 可 operation_id nullable。

Audit 不复制 Password/Token/完整敏感正文。

### `student_merge_records`
- source/target
- performed_by
- operation_id
- merged_at

source→merged，旧 ID 可解释。

完整 merge matrix：`docs/product/STUDENT_MERGE_POLICY.md`。

---

## 12. Student multi-Profile concurrency

Student lifecycle command 必须输入/验证：
- `student_expected_version`；
- affected Profile expected versions；
- affected Case expected versions；
- preview/command binding 中的 current assignment IDs/roles/intervals、owner IDs、primary Action IDs/assignees/status；
- target membership/scope current validity。

`students.version` 不是 child global counter。普通 Evidence/Intervention/Assessment append、普通 Case transition、普通 Assignment current-state change 不机械递增它；相关 aggregate 或 current relation predicate 负责并发检测。

事务中按稳定 ID 顺序 lock/re-read Student → Profiles → Cases → assignments/Actions/current relations → target authority。任一 merge-relevant drift → `stale_plan/version_conflict`，整体 rollback。

对于 `merge_students`：
- preview 必须由 server/domain logic 从完整 merge-relevant snapshot 生成；
- preview 至少绑定 source/target root versions、affected Profile/Case versions、Enrollment、Teacher/Staff Assignments、owner、current Actions、target authority、BLOCK matrix；
- binding 可为 server-generated opaque `merge_plan_token`、完整 expected snapshot/values 或 server-generated fingerprint，不冻结 Phase 0A.6 物理 API，也不新增 `merge_plans` 表；
- execute 时 server lock/re-read 并 regenerate current snapshot，与 confirmed plan 比较；
- 会改变 safe/BLOCK decision、canonical relationship、Profile structure、owner、active assignment、primary Action、Enrollment、staff responsibility、authority 或 Student lifecycle 的 drift → stale_plan/version_conflict，要求重新 preview，不能静默接受新 plan；
- ordinary append-only Evidence/Intervention history 若不改变 current merge decision/matrix/relationship，不单独造成 stale；
- source-only Profile safe reparent 使 Profile.version +1 exactly once；Case 只有 current snapshot 真正变化时才更新 Case.version。

## 13. Student merge committed semantics

V1 safe merge matrix 见 `STUDENT_MERGE_POLICY.md`。

硬 BLOCK：
- source/target 同时有同 subject Profile；
- conflicting Enrollment；
- 双 active Lead/无法机械解决 current responsibility；
- owner/Action 无法在 target context 保持合法；
- unresolved mutable Parent Communication/Report Draft；
- source 或 target 存在 `in_progress` Lesson。

source.version 与 target.version 各 +1 exactly once；source-only Profile safe reparent 时 Profile.version +1 exactly once；不对所有 child Case 机械级联 +1。

Finalized Communication/Report/Lesson historical provenance 不静默重写；target 历史通过 merge lineage 聚合。

## 14. Derived governance anomalies

优先派生：
- active Profile formal open Case 无 primary；
- inactive/archived Profile 残留 active assignment/pending Action；
- long overdue / pending verification；
- stale Quick Capture；
- repeated failed/reopen；
- handoff remaining；
- communication follow-up due；
- duplicate candidates；
- command receipt/event/audit integrity mismatch。

这些不是新的 Case status，也不做教师/学生风险评分。

---

## 15. 数据库/command 硬约束

必须防止：
- cross-org/cross-subject；
- active assignment without active Profile/teaching scope；
- management-only teaching facts；
- Quick Capture bypass；
- active formal Case missing owner/primary；
- closed Case pending primary；
- inactive/archived teaching facts/Lesson/new Case；
- archived→active direct；
- merged Student reactivation；
- high-risk event/audit duplicate under same operation；
- Student lifecycle stale multi-Profile plan；
- unsafe Student merge conflict。

实现可用 FK/CHECK/partial unique/exclusion/row lock/trigger/function/RLS；跨表不变量不能假装只靠一个 CHECK。
