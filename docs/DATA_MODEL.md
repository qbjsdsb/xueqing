# 核心数据模型

> 目标：稳定表达真实教学事实，不为页面造表。正式数据库结构以后以 migrations 为事实源；本文件定义领域语义、字段边界、提交态不变量与 provider-neutral 约束。

## 1. 建模原则

- 主键默认业务 UUID；
- 系统事件时间使用 `timestamptz` 并按 UTC 存储；
- Today / 周期 / due 以 organization timezone 解释；
- 纯业务日期使用 `date`；
- 机构业务对象显式 `organization_id`；
- 人员业务关系引用 membership；
- 身份事实、教学事实、当前快照、历史事件、派生视图分层；
- Student/Subject service lifecycle 与 Learning Case resolution lifecycle 分离；
- 历史优先 append/event，不覆盖过去；
- 关键可变 aggregate 使用 `version`；
- 同一事实只存一次，周度/治理/统计优先派生；
- finalized Communication/Report 是历史快照；
- Provider-specific Auth/Storage 差异不得渗透到业务模型。

### 1.1 Committed-state invariant｜事务语义

本文所有“必须对应 / 不得存在”的跨表不变量都描述**事务 commit 后对外可见的状态**。

对于 `deactivate/reactivate/archive/unarchive/handoff/merge` 等生命周期 command：
- Profile/Student status；
- active assignment；
- Case owner；
- primary Action；
- events/audit；

必须在**同一个业务数据库事务**内一起构造目标状态并一次 commit。

因此，`reactivate_student_subject_profile` 可以在事务内部先 stage assignment/owner/Action，再 stage Profile=active；这些 staging 不得被其他 Session 看到，也不能分多次 API 提交。

同理，`deactivate_student_subject_profile` 可以在事务内部 stage 结束 assignment/Action/owner 与 Profile=inactive；在 commit 前不允许把“active Profile + 已删除当前责任”或“inactive Profile + active assignment”作为独立提交态暴露。

**失败 → 全事务 rollback；timeout → 用同一 `operation_id` 查询最终 committed 结果。**

### 1.2 Phase 0A.6 Cloud/Auth P0 Gate

Supabase 与 CloudBase Auth identity / Session 细节不同。正式 business migrations 前不冻结 `profiles.id == provider auth.users.id`。

Phase 0B.0 必须验证：
1. Auth identity physical strategy；
2. revoked-session / old-token security。

在两项通过前不得落正式业务 migration。

---

# 2. 机构、身份与授权

## `profiles`
逻辑业务 Profile，对应已知 Auth identity。

稳定字段：display name、avatar path、created/updated time。

Auth PK/FK 物理类型 P0 pending；不保存 Password/Token/Secret。

## `organizations`
- `id`
- `name`
- `time_zone`
- `status`
- `created_at`
- `updated_at`

organization timezone 是 Today / due / report period / lesson business date 的唯一事实源。

## `campuses`
- `id`
- `organization_id`
- `name`
- `status`

## `roles`
V1：`org_admin / academic_admin / subject_lead / teacher / student_advisor`。

## `organization_memberships`
- `id`
- `organization_id`
- Auth identity link（物理类型待 Phase 0B.0）
- `staff_no`（可选）
- `display_name_override`（可选）
- `status`：`onboarding / active / disabled`
- `joined_at`
- `activated_at`
- `onboarding_expires_at`
- `disabled_at`

约束：一个 Auth identity 在同机构只有一个 membership；V1 同一 identity 同时最多一个 onboarding/active organization membership。

## `membership_roles`
- `membership_id`
- `role_id`

## `membership_subject_scopes`
- `id`
- `organization_id`
- `membership_id`
- `organization_subject_id`
- `scope_kind`：`teaching / leadership`
- `status`
- `active_from`
- `active_to`
- `created_at`
- `updated_at`

语义：
- teaching scope：允许承担该科 teacher assignment；
- leadership scope：Subject Lead 的该科治理范围；
- scope 不授予全学科学生访问；
- leadership scope 不能伪造实际教学事实。

## Auth Session
安全目标：signOut/reset/disabled 后旧 Access Token 不得继续读取学生业务数据。Supabase `session_id→auth.sessions` 只是 reference，其他 provider 需 Phase 0B.0 证明等价。

---

# 3. 学期、Enrollment 与 Student

## `academic_terms`
- `id`
- `organization_id`
- `name`
- `starts_on`
- `ends_on`

## `students`
- `id`
- `organization_id`
- `student_code`（可选）
- `display_name`
- `status`：`active / inactive / archived / merged`
- `merged_into_student_id`（仅 merged）
- `created_at`
- `updated_at`
- `archived_at`

姓名不是硬唯一键。

### Student lifecycle

```text
active --deactivate_student--> inactive --archive_student--> archived
active <--reactivate_student-- inactive <--unarchive_student-- archived
```

- archived 可恢复，但不能直接 active；
- merged 是身份终态，不可 unarchive/reactivate；
- unarchive 只恢复到 inactive 可管理状态；
- reactivate 是恢复当前服务，不创建新 Student identity。

Student lifecycle command 同样遵守 §1.1 原子事务规则：多 Profile reconciliation 任一步失败，本次 Student command 整体 rollback。

## `student_enrollments`
- `id`
- `organization_id`
- `student_id`
- `term_id`
- `campus_id`
- `grade_code`
- `class_name`（可选）
- `starts_on`
- `ends_on`

升年级/换校区用 Enrollment 历史，不新建 Student。

---

# 4. Guardian

## `guardians`
- `id`
- `organization_id`
- `name`
- `phone`（可选）
- `email`（可选）
- `notes`（严格限制用途）

不默认收集与教学无关的家庭敏感信息。

## `student_guardians`
- `student_id`
- `guardian_id`
- `relationship`
- `is_primary_contact`

---

# 5. 学科、Subject Profile 与人员关系

## `subjects`
稳定学科字典。

## `organization_subjects`
- `id`
- `organization_id`
- `subject_id`
- `display_name`
- `status`
- `sort_order`

## `learning_taxonomy_nodes`
- `id`
- `organization_id`
- `organization_subject_id`
- `parent_id`（可空）
- `code`
- `name`
- `status`
- `sort_order`

parent/child 必须同 organization_subject；历史引用节点停用而非硬删。

## `student_subject_profiles`
- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`
- `status`：`active / inactive / archived`
- `current_positioning_code`（可选）
- `current_positioning_summary`（可选）
- `strengths_summary`（可选）
- `teaching_cadence_note`（可选）
- `version`
- `created_at`
- `updated_at`
- `archived_at`

唯一 `(organization_id, student_id, organization_subject_id)`。

### Subject Profile service lifecycle

```text
active --deactivate_student_subject_profile--> inactive --archive_student_subject_profile--> archived
active <--reactivate_student_subject_profile-- inactive <--unarchive_student_subject_profile-- archived
```

提交态硬规则：
- `active`：可以存在合法 active teacher assignments；formal open Cases 必须有合法 owner + pending primary Action；
- `inactive`：不得存在 active teacher assignment 或普通 pending primary Action；不允许新教学事实/新 Lesson；
- `archived`：与 inactive 一样无当前教学义务，并退出普通当前业务视图；
- archive 只允许 inactive→archived；
- unarchive 只允许 archived→inactive；
- reactivate 只允许 inactive→active；
- active→archived、archived→active 直跳禁止。

### Lifecycle transaction rule

`deactivate/reactivate/archive/unarchive` 的 target status 与 assignment/owner/Action/event 必须在同一事务一次 commit。

#### deactivate commit 后必须同时满足
- Profile=inactive；
- 无 active teacher assignment；
- unresolved Cases 保留真实 resolution status；
- 无普通 pending primary Action；
- 不进入普通 Today；
- 无非法 in-progress/current teaching obligation。

#### reactivate commit 后必须同时满足
- Profile=active；
- 至少一条合法 active teacher relationship（按实际组织策略）；
- 每个 formal open Case 有合法 owner；
- 每个 formal open Case 有且仅有一个 pending primary Action；
- assignment/owner/Action/org/subject/Profile 一致。

事务内部 staging 不受“inactive 不得有 active assignment”的对外可见性约束，因为它不产生独立 committed state；commit 前必须验证最终目标快照。

失败全 rollback；timeout 用 `operation_id` 查询完整旧状态或完整新状态，不能靠客户端补半状态。

### 定位与优势
定位是当前教学上下文，不是能力分；优势不强制。Initial Diagnosis baseline snapshot 是否另存，P2 Pilot validation。

## `student_teacher_assignments`
- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`
- `membership_id`
- `assignment_role`：`lead / collaborator`
- `active_from`
- `active_to`
- `status`

**Committed-state rules：**
- active assignment 必须对应 active membership；
- teacher capability；
- matching active teaching scope；
- **Subject Profile=active**；
- 同 student+subject 默认最多一个 active Lead；
- organization/subject 一致。

注意：reactivate command 可以在单一事务内部 stage assignment 与 Profile active 的最终状态，但不允许先把 active assignment 独立 commit 在 inactive Profile 下。

## `student_staff_assignments`
- `id`
- `organization_id`
- `student_id`
- `membership_id`
- `assignment_role`：`advisor / homeroom / coordinator / other`
- `active_from`
- `active_to`
- `status`

Advisor/班主任不能伪装学科教师。

---

# 6. Learning Case

## `learning_cases`
- `id`
- `organization_id`
- `student_subject_profile_id`
- `owner_membership_id`（new 可空；active Profile formal Case 必须合法）
- `case_type`：`knowledge / habit / exam_strategy / other`
- `taxonomy_node_id`（new 可空）
- `title`
- `description`（可选）
- `root_cause_summary`（可选）
- `priority`：`low / medium / high / urgent`
- `status`：`new / confirmed / intervening / pending_verification / stable / closed`
- `pause_reason`（可选）
- `first_observed_at`
- `stable_at`
- `closed_at`
- `reopened_count`
- `version`
- `created_by_membership_id`
- `created_at`
- `updated_at`
- `archived_at`

Case lifecycle 严格六态：

```text
new → confirmed → intervening → pending_verification → stable → closed
```

`reopen` 是 command/event，不是第七状态。

### Case invariant
- new 可快速草稿；
- Profile=active 时 formal open Case 必须合法 owner + pending primary Action；
- Profile=inactive/archived 时 unresolved Case 可无 current owner/primary Action；
- stopped service 不自动 closed；
- `Assessment passed ≠ stable ≠ closed`；
- 产品只有真实解决时才可把 closed 表达“已清零”。

### 默认 workflow
- knowledge：当堂订正 → 相似题 → 延迟独立验证；
- habit：可观察行为 → 策略干预 → 多场景观察；
- exam_strategy：方法 → 应用 → 限时/模拟迁移 → 独立验证。

## `case_events`
- `id`
- `organization_id`
- `learning_case_id`
- `event_type`
- `actor_membership_id`
- `occurred_at`
- `metadata`

append-only；普通业务不 UPDATE/DELETE。Profile lifecycle 写 tracking suspended/archived/unarchived/resumed event，但不新增 Case status。

---

# 7. Evidence / Intervention / Assessment

## `case_evidence`
- `id`
- `organization_id`
- `learning_case_id`
- `source_type`：`exam / homework / essay / classwork / quiz / observation / guardian_report / other`
- `source_parent_communication_id`（guardian_report 可选）
- `title`
- `observed_at`
- `summary`
- `storage_object_path`（可选）
- `created_by_membership_id`
- `created_at`

Guardian 信息经授权教师判断后才可形成 Evidence，并保留来源。

## `interventions`
- `id`
- `organization_id`
- `learning_case_id`
- `lesson_id`（可选）
- `teacher_membership_id`
- `strategy`
- `notes`
- `occurred_at`
- `created_at`

## `assessments`
- `id`
- `organization_id`
- `learning_case_id`
- `lesson_id`（可选）
- `assessor_membership_id`
- `result`：`passed / partial / failed / not_scored`
- `evidence_id`（可选）
- `notes`
- `assessed_at`
- `created_at`

### Teaching Fact Gate
任何 Intervention、Assessment、教学型 Evidence、Lesson teacher 行为必须运行时同时满足：

```text
live session
+ active membership
+ teacher capability
+ matching active teaching scope
+ target Subject Profile=active
+ legal active Student Assignment
  或受控验证的合法 Lesson relationship
+ operation-specific permission
```

Leadership/Admin/Advisor 不能 bypass。

---

# 8. Case Action

## `case_actions`
- `id`
- `organization_id`
- `learning_case_id`
- `assigned_membership_id`
- `action_type`：`reteach / practice / verify / communicate / review / other`
- `title`
- `due_at`
- `is_primary`
- `status`：`pending / done / cancelled`
- `completed_at`
- `created_at`

Committed-state rules：
- 同一 Case 最多一个 pending primary；
- active Profile formal open Case 必须一个 pending primary；
- inactive/archived Profile unresolved Case 可以没有 pending primary，并退出普通 Today；
- profile deactivate/archive commit 后不得仍有普通 pending primary；
- profile reactivate **同一事务 commit** 时必须同时恢复 primary Action；
- closed 不得有 pending primary；
- Guardian 不是 membership，家庭配合不成为 Case Action；
- Case-related 家校员工 follow-up 优先使用 communicate Action。

关键解释：`reactivate` 中“创建 Action 在 Profile active 前”只表示事务内 staging；不能独立 commit 为 `inactive Profile + pending Action`。

---

# 9. Lesson

## `lessons`
- `id`
- `organization_id`
- `organization_subject_id`
- `teacher_membership_id`
- `started_at`
- `ended_at`
- `status`：`in_progress / completed / cancelled`
- `summary`（可选）
- `version`
- `created_at`
- `updated_at`

Lesson teacher 必须满足完整 Teaching Fact Gate。

## `lesson_students`
- `lesson_id`
- `student_id`
- `attendance_status`

Lesson 创建走 `start_lesson`；小班最终事务粒度留 Phase 0B.0 Spike，但任何实现都不能 commit 非法半状态。

---

# 10. Observation（后续）

## `observations`
- `id`
- `organization_id`
- `student_id`
- `observer_membership_id`
- `organization_subject_id`（可空）
- `category`
- `fact_text`
- `observed_at`
- `visibility_scope`
- `created_at`

只记录必要可观察事实。

---

# 11. Parent Communication

V1 Internal Pilot 在 Student/Case context 提供最小家校能力；V1.1 再做独立工作台。

Parent Communication 是一次沟通 event，不是不断增长的 mutable thread。

## `parent_communications`
- `id`
- `organization_id`
- `student_id`
- `communication_type`
- `direction`：`outbound / inbound / conversation`
- `status`：`draft / finalized`
- `channel`
- `occurred_at`
- `content_snapshot`
- `home_support_snapshot`
- `guardian_response_snapshot`（conversation 同一 interaction 可用）
- `reply_to_communication_id`（可选）
- `recorded_by_membership_id`
- `finalized_by_membership_id`
- `finalized_at`
- `follow_up_assigned_membership_id`（非 Case follow-up 可选）
- `follow_up_at`
- `follow_up_status`
- `follow_up_completed_at`
- `version`
- `created_at`
- `updated_at`

规则：
- Draft 不计已联系；
- finalized 普通业务不可 UPDATE；
- outbound 后异步回复新增 inbound reply event；
- conversation 可冻结同一现场双方内容；
- finalized correction 保留旧 snapshot；
- 家庭配合不是 staff Action；
- guardian response 不自动成为专业诊断。

## `parent_communication_recipients`
- `parent_communication_id`
- `guardian_id`

支持多 recipients。

---

# 12. Report / Stage Review

继续复用 `reports`，不建平行 `stage_reviews`。

## `reports`
- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`（综合报告可空）
- `report_type`
- `period_start`
- `period_end`
- `generated_at`
- `generated_by_membership_id`
- `source_cutoff_at`
- `template_version`
- `content_schema_version`
- `content_snapshot`
- `status`：`draft / finalized`
- `version`
- `finalized_by_membership_id`
- `finalized_at`
- correction/supersede reference/event

finalized 不随底层事实静默改写；Report finalized ≠ Parent informed；AI 可辅助 Draft，不能代替 finalizer。

---

# 13. Audit / Idempotency / Merge

## `audit_logs`
- `id`
- `organization_id`
- provider-neutral actor identity representation
- `actor_membership_id`
- `entity_type`
- `entity_id`
- `action`
- `changed_fields`
- `operation_id`（可选）
- `occurred_at`

不复制完整敏感正文，不记录 secrets/tokens。

## `operation_receipts`
用于多实体 command 幂等/unknown-result recovery；具体 schema 由 Phase 0B Spike 决定。绝不保存 credential 明文。

生命周期 command 必须能用 operation_id 区分：
- 未执行；
- 已完整 commit；
- 失败已 rollback。

业务正常路径不得存在“部分 commit 等客户端继续补”的 receipt 状态。

## `student_merge_records`
- `id`
- `organization_id`
- `source_student_id`
- `target_student_id`
- `performed_by_membership_id`
- `operation_id`
- `merged_at`

source→merged，target 保留；旧 ID 可解释迁移去向。

---

# 14. 派生治理异常

优先派生：
- 本周新增/解决；
- pending verification；
- due/overdue/undated；
- reopen/failed patterns；
- stubborn/long-running；
- orphan Case/Action；
- stale Quick Capture；
- handoff remaining；
- communication follow-up due；
- duplicate Student candidates；
- **committed inactive/archived Profile + active assignment；**
- **committed inactive/archived Profile + ordinary pending Action；**
- **committed active Profile + formal open Case 无合法 owner/primary Action；**
- inactive/archived Profile 仍产生教学事实；
- archived→active 直跳；
- merged Student 被恢复。

最后三类原子性异常正常 command 永远不应产生；若被检测到，是数据完整性/运维告警，不是让客户端自动补齐的普通工作项。

---

# 15. 数据库硬约束 / Command Gate

必须防止 committed state 出现：
- organization mismatch；
- active assignment 没 matching teaching scope / active Profile；
- subject lead 越 leadership scope；
- Case owner 无合法 Teaching relationship；
- admin/leadership 权限伪造教学事实；
- Teaching Fact Gate 任一条件缺失；
- 同 student+subject 冲突 active Lead；
- active Profile formal open Case 无 owner/primary Action；
- inactive/archived Profile 有 active assignment/ordinary pending Action；
- archived Profile/Student 直接 active；
- merged Student unarchive/reactivate；
- closed Case 有 pending primary；
- review pause 无 due_at；
- Lesson relationship 非法；
- taxonomy/Evidence/Action 跨 org/subject；
- finalized Communication/Report 被普通业务覆盖。

实现可使用 composite FK、CHECK、partial unique index、exclusion constraint、trigger、deferred validation、受控 Function、RLS helper。

**跨表 lifecycle invariants 优先由受控 transaction command + commit 前 validation 保证，不要求每个事务内部 SQL staging 瞬间都满足最终 committed-state 约束。**

---

# 16. 索引与性能

重点：organization_id、membership_id、student_id、organization_subject_id、student_subject_profile_id+status、learning_case_id/status、due_at、active assignments、subject scopes、communication status/occurred_at/reply_to/follow-up、Report period/status、active identity membership lookup。

Phase 0B 用 EXPLAIN 或等价证据验证 Today/Student/Case/RLS，不为性能删安全条件。

---

# 17. 删除、停用、归档、恢复与纠错

- member disabled 前 handoff；
- teaching scope end 前学科级 handoff；
- Profile：active→inactive→archived；恢复 archived→inactive→active；
- Student 同上；
- merged 是 Student 身份终态；
- archive 不是 delete，unarchive 不是 reactivate；
- inactive/archived 不改 unresolved Case status；
- inactive/archived 不允许新教学事实/Lesson；
- Case/Lesson/Evidence 默认保留历史/受控更正；
- finalized Communication/Report correction/supersede；
- 核心历史不随意 cascade；
- 个人信息删除/导出/更正走管理员治理流程。

---

# 18. Excel / 领导方法 → 软件映射

高置信骨架：

`学生档案 → 三类问题初诊 → 知识三阶闭环 → 周度跟进 → 顽固问题 → 家校沟通 → 阶段复盘`

映射：
- 一工作簿一学生 → 统一 Student；
- 年级/校区 → Enrollment；
- 定位/优势 → Subject Profile；
- 学科服务是否进行 → Subject Profile lifecycle；
- 授课老师 → Subject Scope + Student Teacher Assignment；
- 学管 → Staff Assignment；
- 初诊 → Profile + Teacher relationship + Initial Diagnosis workflow → Case；
- 知识三阶 → knowledge workflow + Evidence/Intervention/Assessment/Action/Event；
- Habit/Exam Strategy → 各自 workflow；
- 周度/顽固 → 派生；
- 家校 → immutable communication events；
- 阶段复盘 → Report snapshot + human finalization。

问题编号、优先级、责任人、状态、下次跟进等部分 Excel 字段属于管理增强，不全部归因于源 Word。
