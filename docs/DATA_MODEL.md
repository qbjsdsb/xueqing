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

Production provider 尚未冻结。正式 business migrations 前必须实测：
1. Auth Identity Portability；
2. Revoked Session / Old Token Security。

Supabase 是 reference candidate，不是已锁定 provider。

---

## 2. Organization / Identity / Authorization

### `organizations`
- `id`
- `name`
- `time_zone`
- `status`
- timestamps

### `organization_memberships`
- `id`
- `organization_id`
- provider-neutral auth identity link（物理类型 Phase 0B.0 冻结）
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
- merged 是终态；
- `version` 在任何 Student 当前快照/Student lifecycle mutation 成功时递增；
- Student multi-Profile command 必须同时验证 Student expected_version 和受影响子聚合版本/关系快照。

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
- occurred_at
- metadata
- **`operation_id` optional for ordinary manual events, REQUIRED for high-risk command-generated lifecycle events**
- **`operation_event_key` required when operation_id is present**

逻辑唯一：

```text
(organization_id, operation_id, operation_event_key)
```

command retry 不得重复 lifecycle event。

---

## 6. Evidence / Intervention / Assessment

### `case_evidence`
- Case/source type/title/observed_at/summary/storage path/created_by
- `guardian_report` 可引用 source Parent Communication

### `interventions`
Case/lesson/teacher/strategy/notes/occurred_at。

### `assessments`
Case/lesson/assessor/result/evidence/notes/assessed_at。

### Teaching Fact Gate
以下全部必须同时满足：

```text
live session
+ active membership
+ teacher capability
+ active teaching scope
+ target Profile active
+ legal active Student Assignment OR controlled validated Lesson relationship
+ operation-specific permission
```

同一 Gate **也适用于 Quick Capture/new Learning Case**。

Advisor-only/management-only 不得直接创建 teaching Case。

---

## 7. Case Action

### `case_actions`
- `id`
- organization/case/assigned_membership
- action_type: reteach / practice / verify / communicate / review / other
- title/due_at/is_primary
- status: pending / done / cancelled
- completed_at/timestamps

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
lesson/student/attendance。

Lesson teacher 必须 Teaching Fact Gate。小班 final transaction boundary 留 Phase 0B.0 Spike。

---

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
- preview 时 current assignment/owner/Action IDs。

事务中按稳定 ID 顺序 lock/re-read Student → Profiles → Cases → relations → target memberships/scopes。

任一 drift → stale_plan/version_conflict，整体 rollback。

`reactivate_student` 不允许选中 archived Profile；必须在调用前显式独立 unarchive 到 inactive。

---

## 13. Student merge committed semantics

V1 safe merge matrix见 `STUDENT_MERGE_POLICY.md`。

硬 BLOCK：
- source/target 同时有同 subject Profile；
- conflicting Enrollment；
- 双 active Lead/无法机械解决 current responsibility；
- owner/Action 无法在 target context 保持合法。

Finalized Communication/Report/Lesson historical provenance 不静默重写；target 历史通过 merge lineage 聚合。

---

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
