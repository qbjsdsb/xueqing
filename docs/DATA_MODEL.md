# 核心数据模型

## 1. 建模原则

- 主键默认使用 UUID。
- 时间统一使用 `timestamptz`，数据库保存 UTC，客户端按本地时区展示。
- 纯日期业务（学期起止等）使用 `date`，不要为了统一而全部塞成时间戳。
- 机构业务表必须能明确归属 `organization_id`。
- 人员关系优先引用 organization membership，而不是只引用裸 `auth.users.id`。
- **身份事实、教学事实、当前状态、派生数据** 分层。
- 历史优先追加事件，避免用一段不断覆盖的长文本保存全过程。
- 关键表考虑 `created_at / updated_at / archived_at`。
- 需要防止并发覆盖的对象增加 `version`。
- 冗余保存 `organization_id` 是为了 RLS 与查询效率，但必须用约束/触发器/受控写入保证子表与父表不会跨机构错配。
- 不使用“姓名、标题、自由文本”承担唯一性或统计口径。
- 数据库状态约束与应用状态机必须一致，不能只在 Flutter 中校验。

## 2. 身份与机构

### `profiles`
应用侧最小全局人员资料。

- `id` → references `auth.users(id)`
- `display_name`
- `avatar_path`
- `created_at`
- `updated_at`

不要把永久 `organization_id` 写死在 profile 上；同一 Auth User 未来可以属于不同机构。

机构内部的员工编号、职务、显示名差异等放在 membership 或机构人员资料中，而不是污染全局 profile。

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
- `display_name_override`（可选）
- `status`：invited / active / disabled
- `joined_at`
- `disabled_at`

建议唯一约束：`(organization_id, user_id)`。

### `roles`
V1 固定角色字典，例如：
- `org_admin`
- `academic_admin`
- `subject_lead`
- `teacher`
- `student_advisor`

### `membership_roles`
允许同一个成员同时拥有多个角色。

- `membership_id`
- `role_id`

后期若权限复杂，再引入 capability；V1 不先建设巨大权限平台。

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
- `archived_at`

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

V1 不为“班级”单独建复杂教务体系；如果以后确实存在正式班级管理需求，再把 `class_name` 升级为实体。

## 4. 家长/监护人信息（V1.1 按需启用）

如果需要联系方式，不直接把大量家长字段塞进 students。

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

家长登录不是 V1/V1.1 前置条件。

## 5. 学科、分类体系与人员关系

### `subjects`
系统级学科字典，保存稳定 `code` 与基础名称，例如 Chinese / Math / English。

### `organization_subjects`
机构实际启用哪些学科，以及机构显示名称/排序。

- `id`
- `organization_id`
- `subject_id`
- `display_name`
- `status`
- `sort_order`

这样既避免每个机构各自随便拼一套字符串，也允许机构有自己的展示方式。

### `learning_taxonomy_nodes`
用于受控的“学科 → 模块/能力”分类，避免统计被自由文本污染。

- `id`
- `organization_id`
- `organization_subject_id`
- `parent_id`（可空，支持两三层简单树）
- `code`
- `name`
- `status`
- `sort_order`

V1 只做轻量层级，不建设庞大知识图谱。案例标题仍允许自由表达。

### `student_subject_profiles`
学生在某一学科上的连续学情主线。

- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`
- `status`
- `created_at`
- `updated_at`

建议唯一约束：`(organization_id, student_id, organization_subject_id)`。

### `student_teacher_assignments`
记录谁在什么时间负责该学生的哪门学科。

- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`
- `membership_id`
- `assignment_role`：lead / collaborator
- `active_from`
- `active_to`
- `status`

教师交接是结束旧 assignment + 新建新 assignment，不覆盖历史负责人。

### `student_staff_assignments`
非学科型学生责任关系，例如学管/班主任/学生负责人。

- `id`
- `organization_id`
- `student_id`
- `membership_id`
- `assignment_role`：advisor / homeroom / coordinator / other
- `active_from`
- `active_to`
- `status`

不要为了复用 `student_teacher_assignments` 而给班主任硬填一门不存在的学科。

## 6. 学情案例

### `learning_cases`
核心业务对象。

- `id`
- `organization_id`
- `student_subject_profile_id`
- `owner_membership_id`
- `case_type`：knowledge / habit / exam_strategy / other（`new` 草稿可暂空，confirmed 前补齐）
- `taxonomy_node_id`（`new` 草稿可空，confirmed 前原则上补齐）
- `title`（快速捕捉时的最小必填业务内容）
- `description`（可选）
- `root_cause_summary`（可选；当前判断，修改要留事件）
- `priority`：low / medium / high / urgent（可有默认值）
- `status`：new / confirmed / intervening / pending_verification / stable / closed
- `pause_reason`（可选；confirmed 及后续明确暂不安排下一步时使用）
- `first_observed_at`
- `stable_at`
- `closed_at`
- `reopened_count`
- `version`
- `created_by_membership_id`
- `created_at`
- `updated_at`
- `archived_at`

“顽固问题”不单独建第二份业务台账，通过规则/标签从 learning_case 派生。

### 状态语义约束
- `new` 是快速捕捉/草稿态，可以暂时没有完整 taxonomy、原因和主行动；
- `confirmed` 表示进入正式跟进，此时必须满足正式分类和“主行动或 pause_reason”等确认条件；
- 一次 `assessment.result = passed` 不自动等于 `status = stable/closed`；
- `stable` 表示已有改善证据但仍观察；
- `closed` 表示退出主动跟进，原则上不应仍存在 pending 主行动；
- `reopen` 是命令/事件，不是 status；执行后重新进入合适 active 状态，并增加 `reopened_count`；
- 误建/不再适用的案例走受控 archive/cancel 语义，不能改历史让它“从未存在”。

### `case_events`
案例不可丢失的时间轴，原则上 append-only。

- `id`
- `organization_id`
- `learning_case_id`
- `event_type`：created / confirmed / status_changed / reopened / owner_changed / root_cause_changed / note_added / archived 等
- `actor_membership_id`
- `occurred_at`
- `metadata`（只存必要结构化信息，不无节制复制敏感正文）

普通业务流程不开放 UPDATE/DELETE 历史事件。

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
记录实际发生的教学干预事实。

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
记录实际发生的验证。

- `id`
- `organization_id`
- `learning_case_id`
- `lesson_id`（可选）
- `assessor_membership_id`
- `result`：passed / partial / failed / not_scored
- `evidence_id`（可选）
- `notes`
- `assessed_at`
- `created_at`

验证结果与案例状态是两个不同事实。

## 8. 下一步行动

### `case_actions`
它是“今日工作台”的主要事实源。

- `id`
- `organization_id`
- `learning_case_id`
- `assigned_membership_id`
- `action_type`：reteach / practice / verify / communicate / review / other
- `title`
- `due_at`（可空）
- `is_primary`
- `status`：pending / done / cancelled
- `completed_at`
- `created_at`

业务约束：
- 一个案例可以同时存在辅助行动，但通常最多只有一个 pending `is_primary = true` 的主行动；
- 用 partial unique index 或受控写入保证“当前主行动”不会互相冲突；
- `new` 草稿不强制主行动；从 `confirmed` 开始的主动跟进案例，如果没有 pending 主行动，必须有明确 `pause_reason`；
- 行动完成不是删除，保留历史。

## 9. 课程

`lessons` 在本系统表示 **实际教学会话/记录容器**，不是完整排课产品。

不要把 `student_id` 直接写死在 lessons 上，否则小班/多人课会返工。

### `lessons`
- `id`
- `organization_id`
- `organization_subject_id`
- `teacher_membership_id`
- `started_at`
- `ended_at`
- `status`：in_progress / completed / cancelled
- `summary`（可选，优先自动生成/简短补充）
- `version`
- `created_at`
- `updated_at`

如果未来需要轻量 planned 状态，应通过独立需求证明，不把它顺势扩张成收费排课 CRM。

### `lesson_students`
- `lesson_id`
- `student_id`
- `attendance_status`

一对一课程只是 lesson_students 只有一个学生。

### 课程与案例事实的单一来源
不要再建一张重复保存“本节课案例结果”的事实表。

本次课程处理了什么，通过：
- `interventions.lesson_id`
- `assessments.lesson_id`
- 必要的 `case_events.metadata.lesson_id`

关联推导。

这样避免同一件事在 `lesson_case_actions` 和 `assessments/interventions` 两处出现冲突。

## 10. 综合观察（V1.5）

### `observations`
- `id`
- `organization_id`
- `student_id`
- `observer_membership_id`
- `organization_subject_id`（可空）
- `category`：homework / attention / participation / avoidance / study_habit / other
- `fact_text`
- `observed_at`
- `visibility_scope`：subject_team / student_team / management
- `created_at`

原则：优先记录可观察事实，例如“本周 3 次作业有 2 次未完成”，避免“懒惰”“自制力差”等人格化标签。

自由文本中不得随意收集与教学目的无关的家庭、健康、身份等敏感信息。

## 11. 家校沟通（V1.1）

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

如果后期需要精确关联案例，再增加 `communication_case_links`，不要一开始塞大量可空外键。

## 12. 阶段报告（V1.1）

### `reports`
报告是派生结果的冻结快照，不是事实源。

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
- `status`：draft / finalized

报告生成后若底层事实继续变化，应明确“重新生成”，不要静默修改已经发给家长的 finalized 版本。

## 13. 审计

### `audit_logs`
系统治理审计与案例教学事件分开。原则上 append-only。

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

## 14. 派生数据与安全 View

以下优先通过 View / SQL Function / 查询层计算，而不是教师重复录入：
- 本周新增/解决案例数；
- 待验证案例；
- 超期 case_actions；
- 重复失败/复发次数；
- “重点问题/长期问题”提示；
- 家校沟通间隔；
- 阶段报告基础指标；
- 机构高频问题分布。

暴露给 Data API 的 View 必须明确安全语义；在支持的 PostgreSQL 版本中优先使用 `security_invoker = true`，让 View 遵循底层 RLS。不要默认信任由高权限 owner 创建的普通 View。

## 15. 数据一致性约束

除了外键，还必须考虑：
- 子表 `organization_id` 与父表机构一致；
- assignment 的 membership 必须属于同一机构；
- learning_case owner 必须是同一机构有效 membership；
- lesson teacher 与 lesson organization 一致；
- taxonomy node 与 student subject profile 的学科一致；
- case_action / evidence / intervention / assessment 不得跨案例机构。

实现方式可以使用 composite foreign key、约束触发器或受控函数，但不能只相信 Flutter 传对 ID。

## 16. 索引原则

RLS 和“今日”查询会频繁使用：
- `organization_id`
- `membership_id`
- `student_id`
- `organization_subject_id`
- `learning_case_id`
- `status`
- `due_at`
- assignment 的 active/status 字段

真正落 schema 时根据查询与 EXPLAIN 建立索引；尤其 RLS policy 参与的过滤列不能长期无索引。

## 17. 查重与学生合并

不要用姓名做硬唯一约束。

V1 建议：
1. 新建学生时按姓名 + 当前年级/校区 + 可选联系信息提示“可能重复”；
2. 由有权限人员确认是否使用已有学生；
3. 真正合并走受控服务端操作；
4. 合并保留 source_student_id → target_student_id 映射与审计；
5. 普通教师不能自行硬删除重复学生。

## 18. 从 Excel 到数据库的关键改变

- `students.grade` → enrollment 历史；
- “授课老师” → teacher assignment 历史；
- “班主任/学管” → staff assignment，不伪装成学科教师；
- 周度跟进 → 派生，不作为重复事实源；
- 顽固问题 → learning_case 的规则/提示；
- 三阶闭环 → evidence + intervention + assessment + event；
- 阶段复盘 → report snapshot；
- 自由问题分类 → taxonomy + 自由标题双轨；
- 一工作簿一名学生 → 一个机构统一数据库。

详见 `EXCEL_TO_PRODUCT.md`。