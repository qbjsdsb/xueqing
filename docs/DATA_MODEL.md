# 核心数据模型

> 稳定表达真实教学事实，不为每个页面造表。正式 schema 以 `supabase/migrations` 为事实源；本文件定义语义和不变量。

## 1. 建模原则

- 主键默认 UUID；
- 系统时间 `timestamptz`/UTC，纯业务日期 `date`；
- 机构业务对象明确 `organization_id`；
- 人员业务关系引用 membership，不引用裸 Auth User；
- 身份事实、教学事实、当前快照、派生数据分层；
- 历史优先 append/event；
- 姓名/自由文本不承担唯一性；
- 核心历史默认 RESTRICT / archived / disabled / merged，不随意 cascade；
- 关键快照用 `version`；
- 事实只存一次，周度/阶段/重点提示派生。

---

## 2. 身份与机构

### `profiles`
- `id` → `auth.users(id)`
- `display_name`
- `avatar_path`
- `created_at`
- `updated_at`

不写死 organization，不保存 Password/Token/Secret。

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
V1：`org_admin / academic_admin / subject_lead / teacher / student_advisor`。

### `organization_memberships`
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

约束：
1. `(organization_id, user_id)` unique；
2. **V1 再加 partial unique：同一 `user_id` 在 `status in ('onboarding','active')` 时全 project 最多一行。**

这意味着数据库支持多个机构，但 V1 同一 Auth User 不跨机构同时活跃；disabled 历史可以保留。未来身份治理升级后再用新 ADR 移除该 partial unique。

语义：
- onboarding：可 Auth 登录，普通学生业务 RLS 全拒绝；
- active：进入业务授权链；
- disabled：无业务访问。

`onboarding_expires_at` 控制接管是否仍可完成，不保存 credential。

### `membership_roles`
- `membership_id`
- `role_id`

一个 membership 可多角色。

### Auth Session
Session 由 `auth.sessions` 管理，不复制到 public schema。业务 RLS 使用 JWT `session_id` 检查 Session 仍存在。

### V1 不建 invitation 表
内部管理员直接 provision onboarding member。未来 Email OTP/自助加入再引入 invitation。

---

## 3. 学期、年级与学生主档案

### `academic_terms`
- `id`
- `organization_id`
- `name`
- `starts_on`
- `ends_on`

### `students`
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
- `id`
- `organization_id`
- `student_id`
- `term_id`
- `campus_id`
- `grade_code`
- `class_name`（可选）
- `starts_on`
- `ends_on`

不覆盖 `students.grade` 表达升年级；同时段冲突 enrollment 有约束。

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
- `id`
- `organization_id`
- `organization_subject_id`
- `parent_id`（可空）
- `code`
- `name`
- `status`
- `sort_order`

parent/child 同 organization_subject；历史引用节点停用不硬删；V1 少量默认 + “其他/暂未分类”。

### `student_subject_profiles`
- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`
- `status`
- `created_at`
- `updated_at`

唯一 `(organization_id, student_id, organization_subject_id)`。

### `student_teacher_assignments`
- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`
- `membership_id`
- `assignment_role`：`lead / collaborator`
- `active_from`
- `active_to`
- `status`

同一学生/学科同一时点默认最多一个 active lead；current teacher 必须 membership active。

### `student_staff_assignments`
- `id`
- `organization_id`
- `student_id`
- `membership_id`
- `assignment_role`：`advisor / homeroom / coordinator / other`
- `active_from`
- `active_to`
- `status`

班主任/学管不伪装成学科教师。

---

## 6. 学情案例

### `learning_cases`
- `id`
- `organization_id`
- `student_subject_profile_id`
- `owner_membership_id`（new 可空；confirmed 起 active 且关系有效）
- `case_type`：`knowledge / habit / exam_strategy / other`
- `taxonomy_node_id`（new 可空）
- `title`
- `description`（可选）
- `root_cause_summary`（可选；重要修改写 event）
- `priority`：`low / medium / high / urgent`
- `status`：`new / confirmed / intervening / pending_verification / stable / closed`
- `pause_reason`（可选，仅解释，不代替行动）
- `first_observed_at`
- `stable_at`
- `closed_at`
- `reopened_count`
- `version`
- `created_by_membership_id`
- `created_at`
- `updated_at`
- `archived_at`

“顽固问题”从失败/复发/持续时间派生。

### 状态不变量
- new：可轻量草稿；
- confirmed/intervening/pending_verification/stable：必须有一个 pending primary action；
- 暂缓：`pause_reason` + `review` primary action，且 review `due_at` 必填；
- pending_verification：通常 `verify` primary action；
- stable 未关闭就仍有 review/verify；
- closed：无 pending primary action；
- reopen 是命令/事件。

### `case_events`
append-only：
- `id`
- `organization_id`
- `learning_case_id`
- `event_type`
- `actor_membership_id`
- `occurred_at`
- `metadata`（必要结构化差异）

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

assessment result 与 case status 分离；passed 不自动关闭。

---

## 8. 下一步行动

### `case_actions`
- `id`
- `organization_id`
- `learning_case_id`
- `assigned_membership_id`
- `action_type`：`reteach / practice / verify / communicate / review / other`
- `title`
- `due_at`（一般可空；暂停/稳定观察 review 时必填）
- `is_primary`
- `status`：`pending / done / cancelled`
- `completed_at`
- `created_at`

规则：
- 辅助 action 可多个，但最多一个 pending primary；
- confirmed 起直到 closed 必须有 pending primary；
- 暂停/观察不建第二个 `next_review_at`，统一 `review + due_at`；
- 无 due_at 的 primary 仍进入 Today “待安排”；
- done/cancelled 保留历史。

---

## 9. 课程

### `lessons`
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

一对一只是一个 lesson_student。本课 case 结果通过 intervention/assessment/event 关联，不另建重复结果表。

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

优先可观察事实，避免人格化/无关敏感推断。

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

联系方式引用 guardian，不在沟通记录重复。

---

## 12. 阶段报告（V1.1）

### `reports`
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

finalized 是冻结快照，不随底层事实静默改写。

---

## 13. 审计、幂等、合并

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

不复制完整敏感正文，不记录 Password/Token。

### `operation_receipts`（Spike 后决定统一与否）
只用于普通多表命令幂等，**不保存 credential 明文响应**。

### `student_merge_records`
- `id`
- `organization_id`
- `source_student_id`
- `target_student_id`
- `performed_by_membership_id`
- `operation_id`
- `merged_at`

source→merged，target 保留，旧 ID 可解释。

---

## 14. 派生数据

优先派生：本周新增/解决、待验证、到期/逾期 action、无日期待安排 action、复发次数、长期重点问题、报告指标、高频问题。

客户端 View 明确安全语义，优先 `security_invoker=true`。

---

## 15. 一致性硬约束

必须防止：
- child organization 与 parent 错配；
- 一个 Auth User V1 跨机构 onboarding/active 双活；
- membership/assignment 跨机构；
- 非 active owner/assignee；
- 同一学生/学科冲突 active lead；
- confirmed+ case 无 primary action；
- 暂停 review 无 due_at；
- closed 仍有 pending primary；
- lesson teacher/students/subject 跨机构；
- taxonomy parent/child 跨学科；
- taxonomy 与 subject profile 学科不一致；
- evidence/intervention/assessment/action 跨 case 机构；
- merged student 继续做新业务主档案。

使用 composite FK、CHECK、partial unique index、exclusion constraint、trigger/受控函数，不只相信 Flutter。

---

## 16. 索引原则

重点：organization_id、membership_id、student_id、organization_subject_id、learning_case_id、status、due_at、assignment active/status、`(organization_id,user_id)`。

live-session helper 关注 `auth.sessions.id = jwt session_id`。正式 schema 后用 EXPLAIN 调整。

---

## 17. 删除策略

默认：核心历史不 cascade 丢失；member/student/case/lesson/evidence 用 disabled/archived/merged；纯连接/缓存才考虑 cascade；真正隐私删除走受控治理。

---

## 18. Excel → 软件

- 一工作簿一学生 → 机构统一 Student；
- 年级 → enrollment 历史；
- 授课老师 → teacher assignment；
- 学管 → staff assignment；
- 初诊 → learning_case；
- 三阶闭环 → evidence/intervention/assessment/event；
- 下周重点 → case_action；
- 周度 → 派生；
- 顽固问题 → 同一 case 提示；
- 阶段复盘 → report snapshot；
- 自由分类 → taxonomy + 自由标题。
