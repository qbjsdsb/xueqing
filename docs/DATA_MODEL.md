# 核心数据模型

> 目标：稳定表达真实教学事实，不为页面造表。正式数据库结构以后以 `supabase/migrations` 为事实源；本文件定义领域语义、字段边界与必须守住的不变量。

## 1. 建模原则

- 主键默认 UUID；
- 系统事件时间使用 `timestamptz` 并按 UTC 存储；
- “今天 / 本周 / 到期日 / 课程所属业务日期”按机构时区解释；
- 纯业务日期使用 `date`；
- 机构业务对象明确 `organization_id`；
- 人员业务关系引用 membership，不直接引用裸 Auth User；
- 身份事实、教学事实、当前快照、历史事件和派生数据分层；
- 历史优先 append/event，不用覆盖当前字段抹掉过去；
- 姓名和自由文本不承担唯一性；
- 核心历史默认 RESTRICT / archived / disabled / merged，不随意 cascade；
- 关键可变快照使用 `version` 做乐观并发；
- 同一事实只存一次，周度、阶段、高频问题和重点提示优先派生。

---

# 2. 机构、身份与授权

## `profiles`

- `id` → `auth.users(id)`
- `display_name`
- `avatar_path`
- `created_at`
- `updated_at`

不写死 organization，不保存 Password / Token / Secret。

## `organizations`

- `id`
- `name`
- `time_zone`：IANA timezone，例如 `Asia/Shanghai`
- `status`
- `created_at`
- `updated_at`

### 时区规则

`time_zone` 是机构业务日期的唯一事实源。

例如：
- Today 工作台；
- action 到期 / 逾期；
- 课程属于哪一天；
- 周度 / 阶段统计边界；
- 报告周期。

这些都不能直接相信手机或电脑当前时区。

系统事件仍保存 UTC；展示和业务日期计算时再转换为 organization timezone。

V1 不做 campus 独立时区。未来确有跨时区机构需求，再新增 ADR。

## `campuses`

- `id`
- `organization_id`
- `name`
- `status`

## `roles`

V1 固定能力角色：

`org_admin / academic_admin / subject_lead / teacher / student_advisor`

角色名称用于能力组合，不把业务关系塞进 role。

## `organization_memberships`

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
2. V1 partial unique：同一 `user_id` 在 `status in ('onboarding','active')` 时全 project 最多一行。

因此数据库可以有多个 organization，但 V1 不允许同一 Auth User 同时跨机构 onboarding / active。其他机构 disabled 历史可以保留。

状态语义：
- `onboarding`：可以 Auth 登录，但普通学生业务 RLS 全拒绝；
- `active`：可以进入后续 role / assignment 授权；
- `disabled`：无业务访问。

`onboarding_expires_at` 只控制账号接管有效期，不保存 credential。

## `membership_roles`

- `membership_id`
- `role_id`

一个 membership 可以多个角色。

## Auth Session

Session 继续由 `auth.sessions` 管理，不复制到 public schema。

普通业务授权除了 active membership，还要验证 JWT `session_id` 对应 Session 仍然有效。Phase 0 必须验证该 helper 的安全性和查询开销，不能在每行策略里无意义重复昂贵计算。

## V1 不建 invitation 表

管理员直接 provision onboarding member。以后启用 Email OTP / 自助加入，再引入 invitation 领域对象。

---

# 3. 学期、年级与学生主档案

## `academic_terms`

- `id`
- `organization_id`
- `name`
- `starts_on`
- `ends_on`

业务日期按 organization timezone 解释。

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

姓名不能做硬唯一键。

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

不使用 `students.grade` 覆盖升年级历史；同时段冲突 enrollment 需要数据库约束。

---

# 4. 家长 / 监护人（V1.1）

## `guardians`

- `id`
- `organization_id`
- `name`
- `phone`（可选）
- `email`（可选）
- `notes`（严格限制用途）

## `student_guardians`

- `student_id`
- `guardian_id`
- `relationship`
- `is_primary_contact`

家长登录不是 V1 / V1.1 前置。

---

# 5. 学科、分类与人员关系

## `subjects`

系统稳定学科字典。

## `organization_subjects`

- `id`
- `organization_id`
- `subject_id`
- `display_name`
- `status`
- `sort_order`

唯一 `(organization_id, subject_id)`。

## `learning_taxonomy_nodes`

- `id`
- `organization_id`
- `organization_subject_id`
- `parent_id`（可空）
- `code`
- `name`
- `status`
- `sort_order`

规则：
- parent / child 必须同 organization_subject；
- 历史已引用节点停用而不是硬删；
- V1 只提供少量默认节点 + “其他 / 暂未分类”。

## `student_subject_profiles`

- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`
- `status`
- `created_at`
- `updated_at`

唯一 `(organization_id, student_id, organization_subject_id)`。

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

同一学生 / 学科同一时点默认最多一个 active lead。当前 teacher 必须是同机构 active membership。

## `student_staff_assignments`

- `id`
- `organization_id`
- `student_id`
- `membership_id`
- `assignment_role`：`advisor / homeroom / coordinator / other`
- `active_from`
- `active_to`
- `status`

班主任 / 学管不能伪装成学科教师。

---

# 6. 学情案例

## `learning_cases`

- `id`
- `organization_id`
- `student_subject_profile_id`
- `owner_membership_id`（new 可空；confirmed 起必须 active 且关系有效）
- `case_type`：`knowledge / habit / exam_strategy / other`
- `taxonomy_node_id`（new 可空）
- `title`
- `description`（可选）
- `root_cause_summary`（可选；重要变化写 event）
- `priority`：`low / medium / high / urgent`
- `status`：`new / confirmed / intervening / pending_verification / stable / closed`
- `pause_reason`（可选，只解释，不代替行动）
- `first_observed_at`
- `stable_at`
- `closed_at`
- `reopened_count`
- `version`
- `created_by_membership_id`
- `created_at`
- `updated_at`
- `archived_at`

“顽固问题”由失败、复发、持续时间等事实派生，不维护第二套表。

### 状态不变量

- `new`：快速草稿，可以暂时没有完整结构和 action；
- `confirmed / intervening / pending_verification / stable`：始终必须有一个 pending primary action；
- 暂缓 / 观察：使用 `review` primary action，且 `due_at` 必填；`pause_reason` 只解释原因；
- `pending_verification`：通常 primary action 为 verify；
- `stable` 但未 closed：仍然有 review / verify；
- `closed`：不得存在 pending primary action；
- `reopen` 是受控命令 / event，不是第七个 status。

## `case_events`

案例不可丢失的 append-only 时间轴：

- `id`
- `organization_id`
- `learning_case_id`
- `event_type`
- `actor_membership_id`
- `occurred_at`
- `metadata`（只保留必要结构化差异）

普通业务不开放 UPDATE / DELETE 历史事件。

---

# 7. 证据、干预与验证

## `case_evidence`

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

assessment result 与 case status 分离；一次 passed 不自动 stable / closed。

---

# 8. 下一步行动

## `case_actions`

- `id`
- `organization_id`
- `learning_case_id`
- `assigned_membership_id`
- `action_type`：`reteach / practice / verify / communicate / review / other`
- `title`
- `due_at`（一般可空；暂停 / 稳定观察 review 时必填）
- `is_primary`
- `status`：`pending / done / cancelled`
- `completed_at`
- `created_at`

规则：
- 辅助 action 可多个；
- 同一 case 最多一个 pending primary；
- confirmed 起直到 closed 必须有 pending primary；
- 暂停 / 观察统一使用 `review + due_at`，不新增 `next_review_at`；
- 无 due_at 的普通 primary 仍进入 Today 的“待安排”；
- done / cancelled 保留历史。

`due_at` 是时间点；Today / overdue 判断按 organization timezone 转换成业务日期。

---

# 9. 课程

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

课程事件保存 UTC；“属于机构哪一天”按 organization timezone 计算。

## `lesson_students`

- `lesson_id`
- `student_id`
- `attendance_status`

一对一只是一个 lesson_student。课程中发生的 case 结果通过 intervention / assessment / event 关联，不另建重复结果表。

---

# 10. 综合观察（V1.5）

## `observations`

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

只记录必要、可观察事实，避免人格化或无关敏感推断。

---

# 11. 家校沟通（V1.1）

## `parent_communications`

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

联系方式引用 guardian，不在沟通记录重复保存。

---

# 12. 阶段报告（V1.1）

## `reports`

- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`（综合报告可空）
- `period_start`
- `period_end`
- `generated_at`
- `generated_by_membership_id`
- `source_cutoff_at`
- `template_version`
- `content_schema_version`
- `content_snapshot`
- `status`：`draft / finalized`

period_start / period_end 是机构时区下的业务日期。finalized 是冻结快照，不随底层事实静默改写。

---

# 13. 审计、幂等与合并

## `audit_logs`

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

不复制完整敏感正文，不记录 Password / Token。

## `operation_receipts`

是否统一使用由 Phase 0 Spike 决定。只服务普通多表命令幂等，绝不保存 credential 明文响应。

## `student_merge_records`

- `id`
- `organization_id`
- `source_student_id`
- `target_student_id`
- `performed_by_membership_id`
- `operation_id`
- `merged_at`

source → merged，target 保留；旧 ID 仍能解释迁移去向。

---

# 14. 派生数据

优先派生而不是另存台账：
- 本周新增 / 解决；
- 待验证；
- 到期 / 逾期 action；
- 无日期待安排 action；
- 复发次数；
- 长期重点问题；
- 报告指标；
- 高频问题。

客户端 View 必须明确安全语义，优先 `security_invoker = true`。

---

# 15. 数据库硬约束

必须防止：
- child organization 与 parent 错配；
- 一个 Auth User 在 V1 跨机构 onboarding / active 双活；
- membership / assignment 跨机构；
- 非 active owner / assignee；
- 同一学生 / 学科冲突 active lead；
- confirmed+ case 无 primary action；
- 暂停 review 无 due_at；
- closed 仍有 pending primary；
- lesson teacher / students / subject 跨机构；
- taxonomy parent / child 跨学科；
- taxonomy 与 subject profile 学科不一致；
- evidence / intervention / assessment / action 跨 case 机构；
- merged student 继续作为新业务主档案。

实现手段按适用性选择：composite FK、CHECK、partial unique index、exclusion constraint、trigger / 受控 Function。不能只相信 Flutter。

---

# 16. 索引与性能

重点索引：
- `organization_id`
- `membership_id`
- `student_id`
- `organization_subject_id`
- `learning_case_id`
- `status`
- `due_at`
- assignment active / status
- `(organization_id, user_id)`

live-session helper 关注 `auth.sessions.id = jwt session_id`。

Phase 0 要求：
- helper 语义由自动化测试证明；
- RLS 中避免同一语句对 helper 做无意义逐行重复计算；
- 对核心 Today / Student / Case 查询使用 `EXPLAIN (ANALYZE, BUFFERS)` 或等价证据观察计划；
- 若 live-session 校验成为真实瓶颈，必须通过 ADR 调整实现，不能静默删除安全条件。

---

# 17. 删除策略

默认：
- member → disabled；
- student / case / lesson / evidence → archived / merged / 受控更正；
- 核心历史不 cascade 丢失；
- 纯连接或可重建缓存才考虑 cascade；
- 真正个人信息删除 / 导出走管理员治理流程。

---

# 18. Excel → 软件映射

- 一工作簿一学生 → 机构统一 Student；
- 年级 → enrollment 历史；
- 授课老师 → teacher assignment；
- 学管 → staff assignment；
- 初诊 → learning_case；
- 三阶闭环 → evidence / intervention / assessment / event；
- 下周重点 → case_action；
- 周度 → 派生；
- 顽固问题 → 同一 case 的重点提示；
- 阶段复盘 → report snapshot；
- 自由分类 → taxonomy + 自由标题。
