# 核心数据模型

> 目标是稳定表达真实教学事实，而不是为每个页面造一张表。正式 schema 以 `supabase/migrations` 为唯一事实源；本文件定义语义与必须守住的不变量。

## 1. 建模原则

- 主键默认 UUID；
- 系统时间用 `timestamptz`，数据库保存 UTC；纯业务日期用 `date`；
- 机构业务对象必须能明确归属 `organization_id`；
- 人员业务关系优先引用 organization membership，不引用裸 `auth.users.id`；
- 身份事实、教学事实、当前快照、派生数据分层；
- 历史优先 append/event，不用不断覆盖长文本冒充历史；
- 姓名、标题、自由文本不承担唯一性；
- 核心历史默认 RESTRICT / archived / disabled / merged，不随意 cascade 删除；
- 冗余 `organization_id` 可用于 RLS/查询，但必须防止父子跨机构错配；
- 关键快照使用 `version`；
- 事实只保存一次，周度/阶段/重点提示优先派生。

---

## 2. 身份与机构

### `profiles`
全局 Auth User 的最小应用资料：
- `id` → `auth.users(id)`
- `display_name`
- `avatar_path`
- `created_at`
- `updated_at`

不写死 organization，不保存密码、临时密码、Token、SMTP/Secret。

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

### `roles`
V1 固定字典：
- `org_admin`
- `academic_admin`
- `subject_lead`
- `teacher`
- `student_advisor`

### `organization_memberships`
Auth User 在某机构里的正式业务身份：
- `id`
- `organization_id`
- `user_id`
- `staff_no`（可选）
- `display_name_override`（可选）
- `status`：`onboarding / active / disabled`
- `joined_at`
- `activated_at`（可空）
- `onboarding_expires_at`（onboarding 时必须有）
- `disabled_at`（可空）

唯一：`(organization_id, user_id)`。

语义：
- onboarding：可以 Auth 登录，但不能读取普通学生业务；
- active：才进入业务授权链；
- disabled：无业务访问。

`onboarding_expires_at` 只控制是否还允许完成接管，不保存任何 credential。过期后管理员 reissue/reset。

### `membership_roles`
- `membership_id`
- `role_id`

同一 member 可多角色。V1 不提前建设庞大 capability 平台。

### Session 不是业务表

Supabase Session 仍由 `auth.sessions` 管理。业务 RLS 需要结合 JWT `session_id` 检查对应 Session 是否仍存在，但**不复制一份 session/token 到 public schema**。

### V1 不建 invitation 表

V1 是少量已知教师的内部 Pilot，管理员直接 `provision_member` 建 onboarding membership。以后需要 Email OTP / 自助加入时再增加 invitation workflow，不能改变 membership 是业务权限事实源。

---

## 3. 学期、年级与在读历史

### `academic_terms`
- `id`
- `organization_id`
- `name`
- `starts_on`
- `ends_on`

### `students`
稳定学生主档案：
- `id`
- `organization_id`
- `student_code`（可选）
- `display_name`
- `status`：`active / inactive / archived / merged`
- `merged_into_student_id`（仅 merged）
- `created_at`
- `updated_at`
- `archived_at`

姓名不能硬唯一。

### `student_enrollments`
保存阶段性的校区/年级/班级：
- `id`
- `organization_id`
- `student_id`
- `term_id`
- `campus_id`
- `grade_code`
- `class_name`（可选）
- `starts_on`
- `ends_on`

不能靠覆盖 `students.grade` 表达升年级。对同一时间段的冲突 enrollment 要有数据库/业务约束。

---

## 4. 家长/监护人（V1.1）

### `guardians`
- `id`
- `organization_id`
- `name`
- `phone`（可选）
- `email`（可选）
- `notes`（严格限制用途）

### `student_guardians`
- `student_id`
- `guardian_id`
- `relationship`
- `is_primary_contact`

家长登录不是 V1/V1.1 前置。

---

## 5. 学科、分类与人员关系

### `subjects`
系统稳定学科字典。

### `organization_subjects`
- `id`
- `organization_id`
- `subject_id`
- `display_name`
- `status`
- `sort_order`

唯一 `(organization_id, subject_id)`。

### `learning_taxonomy_nodes`
轻量“学科 → 模块/能力”树：
- `id`
- `organization_id`
- `organization_subject_id`
- `parent_id`（可空）
- `code`
- `name`
- `status`
- `sort_order`

parent/child 必须同 organization_subject；已被历史引用的节点优先停用，不硬删。V1 提供少量默认分类 + “其他/暂未分类”。

### `student_subject_profiles`
学生某学科连续主线：
- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`
- `status`
- `created_at`
- `updated_at`

唯一 `(organization_id, student_id, organization_subject_id)`。

### `student_teacher_assignments`
学科型教学责任历史：
- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`
- `membership_id`
- `assignment_role`：`lead / collaborator`
- `active_from`
- `active_to`
- `status`

同一学生/学科同一时点默认最多一个 active lead。

### `student_staff_assignments`
非学科责任：
- `id`
- `organization_id`
- `student_id`
- `membership_id`
- `assignment_role`：`advisor / homeroom / coordinator / other`
- `active_from`
- `active_to`
- `status`

不要把班主任/学管伪装成一门不存在的学科教师。

---

## 6. 学情案例

### `learning_cases`
- `id`
- `organization_id`
- `student_subject_profile_id`
- `owner_membership_id`（new 可空；confirmed 起必须 active 且关系有效）
- `case_type`：`knowledge / habit / exam_strategy / other`
- `taxonomy_node_id`（new 可空）
- `title`
- `description`（可选）
- `root_cause_summary`（可选；重要修改写 event）
- `priority`：`low / medium / high / urgent`
- `status`：`new / confirmed / intervening / pending_verification / stable / closed`
- `pause_reason`（可选，仅作为解释，不代替下一行动）
- `first_observed_at`
- `stable_at`
- `closed_at`
- `reopened_count`
- `version`
- `created_by_membership_id`
- `created_at`
- `updated_at`
- `archived_at`

“顽固问题”从持续时间、失败、复发等事实派生，不建第二台账。

### 状态不变量
- new：允许轻量草稿；
- confirmed/intervening/pending_verification/stable：必须有一个 pending primary action；
- 暂缓：可以有 `pause_reason`，但仍必须创建 `review` 主行动，且该 review `due_at` 必填；
- pending_verification：通常有 `verify` 主行动；
- stable：尚未 closed 就必须有后续 review/verify；
- closed：不应存在 pending primary action；
- reopen 是命令/事件，不是第七状态。

### `case_events`
append-only 生命周期时间线：
- `id`
- `organization_id`
- `learning_case_id`
- `event_type`
- `actor_membership_id`
- `occurred_at`
- `metadata`（只放必要结构化差异）

普通业务不开放 UPDATE/DELETE 历史事件。

---

## 7. 证据、干预与验证

### `case_evidence`
- `id`
- `organization_id`
- `learning_case_id`
- `source_type`：`exam / homework / essay / classwork / quiz / observation / other`
- `title`
- `observed_at`
- `summary`
- `storage_object_path`（可选）
- `created_by_membership_id`
- `created_at`

证据不等于必须上传图片；课堂可观察事实也可以是 evidence。

### `interventions`
- `id`
- `organization_id`
- `learning_case_id`
- `lesson_id`（可选）
- `teacher_membership_id`
- `strategy`
- `notes`
- `occurred_at`
- `created_at`

### `assessments`
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

assessment result 与 case status 是两种事实；passed 不自动关闭。

---

## 8. 下一步行动

### `case_actions`
Today 的主要事实源：
- `id`
- `organization_id`
- `learning_case_id`
- `assigned_membership_id`
- `action_type`：`reteach / practice / verify / communicate / review / other`
- `title`
- `due_at`（一般可空；暂停/稳定观察用 review 时必填）
- `is_primary`
- `status`：`pending / done / cancelled`
- `completed_at`
- `created_at`

规则：
- 一个案例可以有辅助 action，但最多一个 pending primary；
- confirmed 起直到 closed 必须有 pending primary；
- 暂停/观察不另建 `next_review_at`，统一用 `review` action + `due_at` 表达，避免第二日期事实源；
- 无 due_at 的主行动在 Today 中至少进入“待安排/无日期”区，不能隐藏；
- done/cancelled 保留历史。

---

## 9. 课程

### `lessons`
实际教学会话，不是排课/收费系统：
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

### `lesson_students`
- `lesson_id`
- `student_id`
- `attendance_status`

一对一只是一个 lesson_student。

本节课处理结果不再建重复台账；通过 `interventions.lesson_id`、`assessments.lesson_id` 与必要 event metadata 推导。

---

## 10. 综合观察（V1.5）

### `observations`
- `id`
- `organization_id`
- `student_id`
- `observer_membership_id`
- `organization_subject_id`（可空）
- `category`
- `fact_text`
- `observed_at`
- `visibility_scope`：`subject_team / student_team / management`
- `created_at`

优先客观可观察事实，不做人格化或无关敏感推断。

---

## 11. 家校沟通（V1.1）

### `parent_communications`
- `id`
- `organization_id`
- `student_id`
- `recorded_by_membership_id`
- `guardian_id`（可选）
- `channel`：`phone / wechat / in_person / other`
- `occurred_at`
- `summary`
- `follow_up_at`（可选）
- `created_at`

联系方式引用 guardian，不在每条沟通复制。

---

## 12. 阶段报告（V1.1）

### `reports`
派生结果的冻结快照：
- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`（综合可空）
- `period_start`
- `period_end`
- `generated_at`
- `generated_by_membership_id`
- `source_cutoff_at`
- `template_version`
- `content_schema_version`
- `content_snapshot`
- `status`：`draft / finalized`

finalized 不随底层事实静默改写，需要明确重新生成。

---

## 13. 审计、合并与幂等

### `audit_logs`
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

不复制完整敏感正文，不记录密码/Token。

### `operation_receipts`（按 Spike 决定）
可用于数据库多表命令幂等，但**不用于保存 credential 明文响应**。

### `student_merge_records`
- `id`
- `organization_id`
- `source_student_id`
- `target_student_id`
- `performed_by_membership_id`
- `operation_id`
- `merged_at`

source→merged，target 保留；旧 ID 仍可解释。

---

## 14. 派生数据

优先从事实生成：
- 本周新增/解决案例；
- 待验证；
- 到期/逾期 action；
- 无日期待安排 action；
- 复发次数；
- 长期重点问题；
- 阶段报告指标；
- 高频问题分布。

客户端暴露 View 必须明确安全语义，优先 `security_invoker = true`。

---

## 15. 一致性硬约束

必须防止：
- 子表 organization_id 与父表错配；
- membership/assignment 跨机构；
- 非 active owner/assignee 承担正式当前责任；
- 同一学生/学科冲突 active lead；
- confirmed+ 案例没有 primary action；
- 暂停 review 没 due_at；
- closed 仍有 pending primary action；
- lesson teacher/students/subject 跨机构；
- taxonomy parent/child 跨学科；
- taxonomy 与 student subject profile 学科不一致；
- evidence/intervention/assessment/action 跨案例机构；
- merged student 继续成为新业务主档案。

使用 composite FK、CHECK、partial unique index、exclusion constraint、trigger 或受控函数，不只相信 Flutter 传对 ID。

---

## 16. 索引原则

重点围绕：
- organization_id
- membership_id
- student_id
- organization_subject_id
- learning_case_id
- status
- due_at
- assignment active/status
- `(organization_id, user_id)`

RLS helper 还要考虑 `auth.sessions.id = jwt session_id` 的命中效率。正式 schema 后用真实查询 + EXPLAIN 调整，不提前堆索引。

---

## 17. 删除策略

默认：
- organization member、student、case、lesson、evidence 等核心历史不 cascade 丢失；
- 使用 disabled / archived / merged；
- 纯连接/缓存才考虑 cascade；
- 真正个人信息删除/导出走受控治理流程。

---

## 18. 从 Excel 到数据库的关键改变

- 一工作簿一学生 → 机构统一学生主档案；
- 年级 → enrollment 历史；
- 授课老师 → teacher assignment 历史；
- 学管/班主任 → staff assignment；
- 初诊问题 → learning_case；
- 三阶闭环 → evidence + intervention + assessment + event；
- 下周重点 → case_action；
- 周度跟进 → 派生；
- 顽固问题 → 同一 case 的规则/提示；
- 阶段复盘 → report snapshot；
- 自由分类 → taxonomy + 自由标题。
