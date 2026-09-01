# 核心数据模型

## 1. 建模原则

- 主键默认使用 UUID。
- 时间统一使用 `timestamptz`，数据库保存 UTC，客户端按本地时区展示。
- 机构业务表必须能明确归属 `organization_id`。
- 人员关系优先引用 organization membership，而不是只引用裸 `auth.users.id`。
- 事实、当前状态、派生数据分层。
- 历史优先追加事件，避免用一段不断覆盖的长文本保存全过程。
- 关键表考虑 `created_at / updated_at / archived_at`。
- 需要防止并发覆盖的对象增加 `version`。

## 2. 身份与机构

### `profiles`
应用侧人员展示资料。

- `id` → references `auth.users(id)`
- `display_name`
- `avatar_path`
- `created_at`
- `updated_at`

不要把单一机构写死在 profile 上。

### `organizations`
- `id`
- `name`
- `status`
- `created_at`

### `campuses`
- `id`
- `organization_id`
- `name`
- `status`

### `organization_memberships`
一个账号加入某机构后的成员身份。

- `id`
- `organization_id`
- `user_id`
- `staff_no`（可选）
- `status`：invited / active / disabled
- `joined_at`
- `disabled_at`

建议唯一约束：`(organization_id, user_id)`。

### `roles`
V1 固定角色字典，例如：
- org_admin
- academic_admin
- subject_lead
- teacher
- homeroom_or_advisor

### `membership_roles`
允许同一个成员同时拥有多个角色。

- `membership_id`
- `role_id`

后期若权限复杂，再逐步引入 capability，不在 V1 先做巨大权限平台。

## 3. 学期、年级与在读历史

不要长期只在 `students.grade` 上覆盖年级，否则升年级后历史丢失。

### `academic_terms`
- `id`
- `organization_id`
- `name`
- `starts_on`
- `ends_on`

### `students`
稳定身份主档案。

- `id`
- `organization_id`
- `student_code`（机构内可读编号，可选）
- `display_name`
- `status`：active / inactive / archived
- `created_at`
- `updated_at`

姓名不能作为唯一键。

### `student_enrollments`
保存学生某阶段所在校区/年级/班级。

- `id`
- `organization_id`
- `student_id`
- `term_id`
- `campus_id`
- `grade_code`
- `class_name`（可选）
- `starts_on`
- `ends_on`

当前年级从有效 enrollment 推导或缓存，不覆盖历史。

## 4. 家长/监护人信息

如果 V1 需要联系方式，不直接把大量家长字段塞进 students。

### `guardians`
- `id`
- `organization_id`
- `name`
- `phone`（可选）
- `email`（可选）
- `notes`（谨慎使用）

### `student_guardians`
- `student_id`
- `guardian_id`
- `relationship`
- `is_primary_contact`

V1 不需要家长登录账号也可以使用这套关系。

## 5. 学科与师生关系

### `subjects`
学科字典，例如语文、数学、英语。

### `student_subject_profiles`
学生在某一学科上的连续学情主线。

- `id`
- `organization_id`
- `student_id`
- `subject_id`
- `status`
- `created_at`
- `updated_at`

建议唯一约束：`(organization_id, student_id, subject_id)`。

### `student_teacher_assignments`
记录谁在什么时间负责该学生的哪门学科。

- `id`
- `organization_id`
- `student_id`
- `subject_id`
- `membership_id`
- `assignment_role`：lead / collaborator / homeroom
- `active_from`
- `active_to`
- `status`

教师交接是结束旧 assignment + 新建新 assignment，不覆盖历史负责人。

## 6. 学情案例

### `learning_cases`
核心业务对象。

- `id`
- `organization_id`
- `student_subject_profile_id`
- `owner_membership_id`
- `case_type`：knowledge / habit / exam_strategy / other
- `module_code`（可选）
- `title`
- `description`
- `root_cause_summary`（当前判断，可修改但要留事件）
- `priority`：low / medium / high / urgent
- `status`：new / confirmed / intervening / pending_verification / stable / closed
- `first_observed_at`
- `stable_at`
- `closed_at`
- `reopened_count`
- `version`
- `created_by_membership_id`
- `created_at`
- `updated_at`
- `archived_at`

“顽固问题”不单独建第二份业务台账。通过规则或标签从 learning_case 派生。

### `case_events`
案例不可丢失的时间轴。

- `id`
- `organization_id`
- `learning_case_id`
- `event_type`：created / confirmed / status_changed / reopened / owner_changed / note_added / archived 等
- `actor_membership_id`
- `occurred_at`
- `metadata`（只存必要结构化信息，不无节制复制敏感正文）

## 7. 证据、干预与验证

### `case_evidence`
- `id`
- `organization_id`
- `learning_case_id`
- `source_type`：exam / homework / essay / classwork / quiz / observation / other
- `title`
- `observed_at`
- `summary`
- `storage_object_path`（可选）
- `created_by_membership_id`
- `created_at`

### `interventions`
- `id`
- `organization_id`
- `learning_case_id`
- `lesson_id`（可选）
- `teacher_membership_id`
- `strategy`
- `notes`
- `occurred_at`

### `assessments`
- `id`
- `organization_id`
- `learning_case_id`
- `lesson_id`（可选）
- `assessor_membership_id`
- `result`：passed / partial / failed / not_scored
- `evidence_id`（可选）
- `notes`
- `assessed_at`

验证结果与最终案例状态不要完全等同：一次 passed 不一定立即意味着“长期稳定”。

## 8. 下一步行动

### `case_actions`
它是“今日工作台”的核心事实源。

- `id`
- `organization_id`
- `learning_case_id`
- `assigned_membership_id`
- `action_type`：reteach / practice / verify / communicate / review / other
- `title`
- `due_at`
- `status`：pending / done / cancelled
- `completed_at`
- `created_at`

建议业务约束：一个未结束案例通常只保留一个“当前主行动”，旧行动完成/取消后再产生下一项，避免待办无限堆积。

## 9. 课程

不要把 `student_id` 直接写死在 lessons 上，否则未来小班/多人课会返工。

### `lessons`
- `id`
- `organization_id`
- `subject_id`
- `teacher_membership_id`
- `started_at`
- `ended_at`
- `status`：planned / in_progress / completed / cancelled
- `summary`（可选）
- `created_at`

### `lesson_students`
- `lesson_id`
- `student_id`
- `attendance_status`

一对一课程只是 lesson_students 里只有一个学生。

### `lesson_case_actions`
关联某次课实际处理了哪些案例。

- `lesson_id`
- `learning_case_id`
- `student_id`
- `result`：passed / partial / failed / observed
- `notes`（可选）

## 10. 综合观察

### `observations`
- `id`
- `organization_id`
- `student_id`
- `observer_membership_id`
- `subject_id`（可空）
- `category`：homework / attention / participation / avoidance / study_habit / other
- `fact_text`
- `observed_at`
- `visibility_scope`：subject_team / student_team / management
- `created_at`

原则：优先记录可观察事实，例如“本周 3 次作业有 2 次未完成”，避免“懒惰”“自制力差”等人格化标签。

## 11. 家校沟通

### `parent_communications`
- `id`
- `organization_id`
- `student_id`
- `recorded_by_membership_id`
- `guardian_id`（可选）
- `channel`：phone / wechat / in_person / other
- `occurred_at`
- `summary`
- `follow_up_at`（可选）
- `created_at`

不重复保存家长联系方式，联系方式以 guardian 为事实源。

## 12. 阶段报告

### `reports`
报告是派生结果的“冻结快照”，不是事实源。

- `id`
- `organization_id`
- `student_id`
- `subject_id`（综合报告可空）
- `period_start`
- `period_end`
- `generated_at`
- `generated_by_membership_id`
- `source_cutoff_at`
- `content_snapshot`
- `status`：draft / finalized

报告生成后若底层事实继续变化，应明确“重新生成”，不要静默修改已经发给家长的 finalized 版本。

## 13. 审计

### `audit_logs`
系统治理审计与案例教学事件分开。

- `id`
- `organization_id`
- `actor_user_id`
- `actor_membership_id`
- `entity_type`
- `entity_id`
- `action`
- `changed_fields`
- `operation_id`（可选）
- `occurred_at`

只有确有需要的高风险操作保存脱敏 before/after 摘要，避免审计表成为第二份敏感正文数据库。

## 14. 派生数据

以下优先通过 View / Materialized View / SQL Function / 查询层计算，而不是教师重复录入：

- 本周新增/解决案例数；
- 待验证案例；
- 超期 case_actions；
- 重复失败/复发次数；
- “重点问题/长期问题”提示；
- 家校沟通间隔；
- 阶段报告基础指标；
- 机构高频问题分布。

## 15. 查重与学生合并

不要用姓名做硬唯一约束。

V1 建议：
1. 新建学生时按姓名 + 当前年级/校区 + 可选联系信息提示“可能重复”；
2. 由有权限人员确认是否使用已有学生；
3. 真正合并走受控服务端操作；
4. 合并必须记录 source_student_id → target_student_id 映射与审计；
5. 不允许普通教师自行硬删除重复学生。

## 16. 从 Excel 到数据库的关键改变

- `students.grade` → 改为 enrollment 历史；
- “授课老师” → 改为 assignment 历史；
- 周度跟进 → 派生，不作为重复事实源；
- 顽固问题 → learning_case 的规则/标签；
- 三阶闭环 → evidence + intervention + assessment + event；
- 阶段复盘 → report snapshot；
- 一个工作簿一名学生 → 一个机构统一数据库。

详见 `EXCEL_TO_PRODUCT.md`。
