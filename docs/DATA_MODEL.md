# 核心数据模型

## 1. 建模原则

- 主键默认 UUID。
- 时间用 `timestamptz`，数据库保存 UTC，客户端按本地时区展示；纯日期用 `date`。
- 机构业务表必须能明确归属 `organization_id`。
- 人员业务关系优先引用 organization membership，而不是裸 `auth.users.id`。
- **身份事实、教学事实、当前状态、派生数据** 分层。
- 历史优先追加事件，不用不断覆盖的长文本保存全过程。
- 关键快照对象考虑 `version`，历史/归档对象考虑 `archived_at`。
- 冗余 `organization_id` 用于 RLS 与查询效率，但必须通过约束/受控写入防止跨机构错配。
- 姓名、标题、自由文本不承担唯一性或统计口径。
- 核心历史默认优先 `RESTRICT` / 归档 / 停用，不随意级联删除。
- 数据库约束与应用状态机必须一致，不能只在 Flutter 中校验。

## 2. 身份、邀请与机构

### `profiles`
全局 Auth User 的最小应用资料。

- `id` → `auth.users(id)`
- `display_name`
- `avatar_path`
- `created_at`
- `updated_at`

不要把永久 `organization_id` 写死在 profile 上。

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
V1 固定角色字典：
- `org_admin`
- `academic_admin`
- `subject_lead`
- `teacher`
- `student_advisor`

### `organization_invitations`
这是**机构对邮箱的业务预授权**，不是 Auth Invite Link，也不是正式成员。

- `id`
- `organization_id`
- `email_normalized`
- `status`：pending / accepted / cancelled
- `created_by_membership_id`
- `accepted_by_user_id`（可空）
- `accepted_at`（可空）
- `cancelled_at`（可空）
- `created_at`
- `updated_at`

建议约束：同一机构 + 同一规范化邮箱最多一个 pending invitation。

pending invitation：
- 不需要提前知道 Auth User 是否存在；
- 没有任何学生业务数据权限；
- 可以被管理员取消；
- 在 verified email 用户接受后才产生 membership。

### `organization_invitation_roles`
邀请接受后希望授予的初始角色。

- `invitation_id`
- `role_id`

接受时必须再次校验角色是否仍可授予；不能把历史 invitation 当成永久提权票据。

### `organization_memberships`
Auth User 已经加入某机构后的正式成员身份。

- `id`
- `organization_id`
- `user_id`
- `staff_no`（可选）
- `display_name_override`（可选）
- `status`：active / disabled
- `joined_at`
- `disabled_at`

唯一约束：`(organization_id, user_id)`。

**只有 active membership 才能进入机构业务 RLS 授权链。**

### `membership_roles`
- `membership_id`
- `role_id`

同一 membership 可以有多个角色。V1 不提前建设巨大 capability 平台。

### Auth 与 invitation 的关系

Email OTP 只负责证明“你拥有这个邮箱”。

`accept_invitation` 使用当前 verified Auth email 匹配 pending invitation，然后事务化创建 membership + roles，并将 invitation 标为 accepted。

因此：
- 新 Auth User / 已有 Auth User 使用同一种机构加入逻辑；
- Auth User 可以存在但没有任何机构权限；
- 同一 Auth User 后续可以被第二机构邀请，不需要重复创建 Auth 身份。

## 3. 学期、年级与在读历史

### `academic_terms`
- `id`
- `organization_id`
- `name`
- `starts_on`
- `ends_on`

### `students`
稳定学生主档案。

- `id`
- `organization_id`
- `student_code`（可选）
- `display_name`
- `status`：active / inactive / archived / merged
- `merged_into_student_id`（仅 merged 时）
- `created_at`
- `updated_at`
- `archived_at`

姓名不能作为唯一键。

### `student_enrollments`
保存阶段性的校区/年级/班级，而不是覆盖 students 当前值。

- `id`
- `organization_id`
- `student_id`
- `term_id`
- `campus_id`
- `grade_code`
- `class_name`（可选）
- `starts_on`
- `ends_on`

同一学生在同一时段不能出现互相冲突且无法判断“当前”的 enrollment。

V1 不为班级单独建设完整教务体系。

## 4. 家长/监护人（V1.1 按需启用）

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

## 5. 学科、分类与人员关系

### `subjects`
系统级稳定学科字典，例如 Chinese / Math / English。

### `organization_subjects`
机构实际启用学科。

- `id`
- `organization_id`
- `subject_id`
- `display_name`
- `status`
- `sort_order`

唯一约束：`(organization_id, subject_id)`。

### `learning_taxonomy_nodes`
轻量“学科 → 模块/能力”分类。

- `id`
- `organization_id`
- `organization_subject_id`
- `parent_id`（可空）
- `code`
- `name`
- `status`
- `sort_order`

约束：
- parent/child 属于同一 organization_subject；
- 历史已引用节点优先停用，不硬删除；
- V1 提供少量稳定默认分类 + “其他/暂未分类”；
- 不要求老师维护庞大知识树才能录入。

### `student_subject_profiles`
学生某学科的连续学情主线。

- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`
- `status`
- `created_at`
- `updated_at`

唯一约束：`(organization_id, student_id, organization_subject_id)`。

### `student_teacher_assignments`
学科型教学责任历史。

- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`
- `membership_id`
- `assignment_role`：lead / collaborator
- `active_from`
- `active_to`
- `status`

默认同一学生/学科同一时点最多一个 active lead；其他教师用 collaborator。

### `student_staff_assignments`
非学科责任关系，例如学管/班主任/协调人。

- `id`
- `organization_id`
- `student_id`
- `membership_id`
- `assignment_role`：advisor / homeroom / coordinator / other
- `active_from`
- `active_to`
- `status`

不要给班主任硬填一门不存在的学科来复用 teacher assignment。

## 6. 学情案例

### `learning_cases`
核心业务对象。

- `id`
- `organization_id`
- `student_subject_profile_id`
- `owner_membership_id`（new 可空，confirmed 前必须有效）
- `case_type`：knowledge / habit / exam_strategy / other（new 可空）
- `taxonomy_node_id`（new 可空）
- `title`（快速捕捉最小必填）
- `description`（可选）
- `root_cause_summary`（可选；修改要留事件）
- `priority`：low / medium / high / urgent
- `status`：new / confirmed / intervening / pending_verification / stable / closed
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

“顽固问题”从 learning_case 的失败/复发/持续时间派生，不建第二套台账。

### 状态约束

- `new`：10–20 秒快速捕捉草稿，可以暂缺 taxonomy、owner、原因、行动；
- `confirmed`：进入正式跟进，必须有有效 owner、正式分类、至少一条可解释来源的 evidence、主行动或 pause_reason；
- `intervening`：正在实施干预；
- `pending_verification`：等待后续验证；
- `stable`：已有证据支持改善，但仍观察；
- `closed`：退出主动跟进，不应仍有 pending primary action；
- `reopen` 是命令/事件，不是第七个 status。

课堂 `new` 在课后确认时，可以用教师短备注 + lesson context 生成最小 observation/classwork evidence，不要求上传图片。

### owner 约束

confirmed 及后续 active case owner 必须：
- 属于同一 organization；
- 对该学生/学科具有有效 assignment 或明确管理权限。

人员停用前必须交接 active case ownership。

### `case_events`
案例生命周期 append-only 时间轴。

- `id`
- `organization_id`
- `learning_case_id`
- `event_type`：created / confirmed / status_changed / reopened / owner_changed / root_cause_changed / note_added / archived 等
- `actor_membership_id`
- `occurred_at`
- `metadata`（只存必要结构化信息）

普通业务不开放 UPDATE/DELETE 历史事件。

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

证据不等于必须有附件；简短课堂事实也可以是 evidence。

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
- `result`：passed / partial / failed / not_scored
- `evidence_id`（可选）
- `notes`
- `assessed_at`
- `created_at`

assessment result 与 learning_case status 是两个不同事实。

## 8. 下一步行动

### `case_actions`
“今日”主要事实源。

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

规则：
- 一个案例可有辅助行动，但通常最多一个 pending primary action；
- 用 partial unique index 或受控写入保证主行动唯一；
- new 不强制行动；confirmed 起没有主行动时必须有 pause_reason；
- assignee 必须属于同一机构并具有合理业务关系；
- 行动完成保留历史，不删除。

## 9. 课程

`lessons` 是实际教学会话/记录容器，不是完整排课产品。

### `lessons`
- `id`
- `organization_id`
- `organization_subject_id`
- `teacher_membership_id`
- `started_at`
- `ended_at`
- `status`：in_progress / completed / cancelled
- `summary`（可选）
- `version`
- `created_at`
- `updated_at`

### `lesson_students`
- `lesson_id`
- `student_id`
- `attendance_status`

一对一只是只有一个 lesson_student。

lesson teacher、students、subject 必须在同一 organization，并满足允许的教学关系/授权。

### 单一事实源

不再建重复的 `lesson_case_actions` 结果台账。本节课处理了什么通过：
- `interventions.lesson_id`
- `assessments.lesson_id`
- 必要 `case_events.metadata.lesson_id`

推导。

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

优先记录可观察事实，避免人格化标签和与教学目的无关的敏感推断。

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

联系方式以 guardian 为事实源，不在每条沟通中复制。

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

finalized 报告不因底层事实变化而静默改写；需要明确重新生成。

## 13. 审计与命令幂等

### `audit_logs`
治理/高风险修改 append-only 日志。

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

避免复制完整敏感正文。

### `operation_receipts`（实现 Spike 后决定统一与否）

可用于多表命令的幂等重试：
- `operation_id`
- `organization_id`
- `actor_membership_id`
- `operation_type`
- `status`
- `result_reference`（可选）
- `created_at`
- `completed_at`（可选）

具体是否建统一表可后定，但同一 operation 重试不能产生两套副作用。

## 14. 派生数据与安全 View

优先派生而非教师重复录入：
- 本周新增/解决案例；
- 待验证；
- 逾期 case_actions；
- 复发次数；
- 长期/重点问题提示；
- 家校沟通间隔；
- 阶段报告指标；
- 高频问题分布。

暴露给 Data API 的 View 必须明确 RLS 语义；优先 `security_invoker = true`。

## 15. 数据一致性硬约束

必须防止：
- 子表 organization_id 与父对象不一致；
- invitation roles 与 invitation 机构/权限不一致；
- invitation 被错误邮箱接受；
- membership / assignment 跨机构；
- 同一学生/学科出现冲突 active lead；
- case owner 无有效业务关系；
- confirmed case 没有 evidence 或“主行动/pause reason”；
- lesson teacher/students 跨机构；
- taxonomy parent/child 跨学科；
- taxonomy node 与 student subject profile 学科不一致；
- case_action/evidence/intervention/assessment 跨案例机构；
- merged student 继续作为新业务主档案。

实现可使用 composite FK、CHECK、partial unique index、exclusion constraint、约束触发器或受控函数，不能只相信 Flutter 传对 ID。

## 16. 索引原则

RLS/高频查询重点关注：
- organization_id
- membership_id
- student_id
- organization_subject_id
- learning_case_id
- status
- due_at
- assignment active/status
- invitation `(organization_id, email_normalized, status)`

落 schema 时结合查询和 `EXPLAIN` 调整。

## 17. 查重与学生合并

新建学生：提示可能重复，不用姓名硬唯一。

### `student_merge_records`
- `id`
- `organization_id`
- `source_student_id`
- `target_student_id`
- `performed_by_membership_id`
- `operation_id`
- `merged_at`

合并规则：
- source/target 同机构；
- target 保留；source → merged + `merged_into_student_id`；
- 当前关系与必要业务引用按规则迁移；
- 不形成 merge 环；
- 写 merge record + audit；
- 重试不重复迁移；
- 旧 source ID 仍可解释目标。

## 18. 外键删除策略

每个 migration 显式思考 FK delete 行为。

默认：
- organization member、student、case、lesson、evidence 等核心历史不级联丢失；
- 使用 disabled / archived / merged；
- 只对无历史价值、可重建的纯连接/缓存考虑 cascade；
- 真正隐私删除/导出走受控数据治理流程。

## 19. 从 Excel 到数据库的关键改变

- 年级 → enrollment 历史；
- 授课老师 → teacher assignment 历史；
- 班主任/学管 → staff assignment；
- 管理员邀请教师 → `organization_invitations` 邮箱预授权；
- Auth 登录 → Email OTP，与机构 membership 分离；
- 周度跟进 → 派生；
- 顽固问题 → learning_case 规则/提示；
- 三阶闭环 → evidence + intervention + assessment + event；
- 阶段复盘 → report snapshot；
- 自由分类 → taxonomy + 自由标题双轨；
- 一个工作簿一学生 → 一个机构统一数据库。

详见 `EXCEL_TO_PRODUCT.md`。