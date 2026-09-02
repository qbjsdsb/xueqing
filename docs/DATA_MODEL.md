# 核心数据模型

> 目标：稳定表达真实教学事实，不为页面造表。正式数据库结构以后以 migrations 为事实源；本文件定义领域语义、字段边界与必须守住的不变量。

## 1. 建模原则

- 主键默认业务 UUID；
- 系统事件时间使用 `timestamptz` 并按 UTC 存储；
- “今天 / 本周 / 到期日 / 课程所属业务日期”按机构时区解释；
- 纯业务日期使用 `date`；
- 机构业务对象明确 `organization_id`；
- 人员业务关系引用 membership，不直接把裸 Auth User 当教学责任人；
- 身份事实、教学事实、当前快照、历史事件和派生数据分层；
- 历史优先 append/event，不用覆盖当前字段抹掉过去；
- 姓名和自由文本不承担唯一性；
- 核心历史默认 RESTRICT / archived / disabled / merged / 受控更正，不随意 cascade；
- 关键可变快照使用 `version` 做乐观并发；
- 同一事实只存一次，周度、阶段、高频问题和治理提示优先派生；
- finalized 家校沟通/报告保存当时快照，不随后续底层事实静默变化；
- Provider-specific Auth/Storage 差异不得渗透到业务领域对象。

### Phase 0A.6 Cloud/Auth P0 Gate

Xueqing 当前同时评估官方 Supabase 与中国大陆 CloudBase PG。两者 Auth identity 类型与 Session 实现并非 100% 相同。

因此正式 migrations 前**暂不冻结**“业务 Profile 主键是否直接等于 provider `auth.users.id`”。Phase 0B.0 必须用虚构数据比较：

1. provider-specific auth PK；
2. business Profile UUID + external `auth_subject_id`；
3. text auth subject + 受控 provisioning。

任何正式业务 migration 在 Auth identity strategy 与 revoked-session security Spike 通过前不得落地。

---

# 2. 机构、身份与授权

## `profiles`

逻辑语义：一个业务 Profile 对应一个已知 Auth identity。

稳定业务字段：
- display name；
- avatar path；
- created/updated time。

**Auth PK/FK 的物理类型 P0 pending**，见上文 Cloud/Auth Gate。无论最终 provider 如何：
- Profile 不写死 organization；
- 不保存 Password / Token / Secret；
- Flutter 业务层不依赖 provider-specific auth ID type。

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
- Auth identity link（物理字段/类型随 Phase 0B.0 identity strategy 冻结）
- `staff_no`（可选）
- `display_name_override`（可选）
- `status`：`onboarding / active / disabled`
- `joined_at`
- `activated_at`（可空）
- `onboarding_expires_at`（onboarding 时必须有）
- `disabled_at`（可空）

业务约束：
1. 一个 Auth identity 在同机构只能有一个 membership；
2. V1 同一 Auth identity 在 `onboarding/active` 时全 project 最多属于一个 organization；
3. 其他机构 disabled 历史可以保留。

状态语义：
- `onboarding`：可以 Auth 登录，但普通学生业务 RLS 全拒绝；
- `active`：可以进入后续 role / scope / assignment 授权；
- `disabled`：无业务访问。

`onboarding_expires_at` 只控制账号接管有效期，不保存 credential。

## `membership_roles`

- `membership_id`
- `role_id`

一个 membership 可以多个角色。

## `membership_subject_scopes`

表达“这个 membership 在哪些学科具有什么 subject-scoped 能力范围”，**不能从当前 Student Assignment 反推**。

候选字段：
- `id`
- `organization_id`
- `membership_id`
- `organization_subject_id`
- `scope_kind`：`teaching / leadership`
- `status`：`active / inactive` 或等价历史状态
- `active_from`
- `active_to`
- `created_at`
- `updated_at`

语义：
- `teacher role + teaching scope`：可以在该科承担 teacher assignment；
- `subject_lead role + leadership scope`：该科的学科管理范围；
- **scope 不自动授予该学科所有学生访问权**；普通 teacher 仍需要具体 Student Assignment；
- leadership scope 本身不能让 Subject Lead 伪装成实际授课教师。

结束 teaching scope 前必须先处理该科 active assignments、Case ownership 与 pending Actions；不得普通 DELETE。

## Auth Session

Reference Supabase 方案继续要求：业务授权不能只看 `membership=active`，还要证明当前 Session 仍有效。

现有安全目标不变：

> signOut / credential reset / disabled 后，旧 Access Token 即使尚未自然过期，也不能继续读取学生数据。

Supabase 可用 JWT `session_id → auth.sessions` helper；CloudBase 等候选必须在 Phase 0B.0 实测等价保证。**未验证前不得降低此不变量。**

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

### Student lifecycle

- 升年级/换校区：更新 enrollment 历史，不新建 Student；
- inactive/archive：不能裸改 status，必须先 reconciliation active enrollment / assignments / Cases / Actions；
- inactive **不自动 close Case**；
- restart：恢复/新增 enrollment 与 assignments，继续同一 Student / Subject Profile 历史；
- merged：旧 ID 仍可解释。

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

# 4. 家长 / 监护人

V1 Internal Pilot 允许 Student context 内最小家校闭环；独立家校工作台仍放 V1.1。家长登录不是 V1/V1.1 前置。

## `guardians`

- `id`
- `organization_id`
- `name`
- `phone`（可选）
- `email`（可选）
- `notes`（严格限制用途）

默认不收集身份证、职业、收入或与教学无关的家庭隐私。

## `student_guardians`

- `student_id`
- `guardian_id`
- `relationship`
- `is_primary_contact`

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
- `current_positioning_code`（可选；存储形式在 migration design 冻结）
- `current_positioning_summary`（可选）
- `strengths_summary`（可选）
- `teaching_cadence_note`（可选，仅真实使用时）
- `version`
- `created_at`
- `updated_at`

唯一 `(organization_id, student_id, organization_subject_id)`。

### 定位/优势规则

- 定位是当前教学上下文，不是能力分/人格标签；
- 优势不强制填写；
- 当前摘要可更新；
- 重要历史变化由 Case / Report / Event 等事实解释；
- Initial Diagnosis 是否另存轻量 initial-baseline snapshot 暂不建表，待 Pilot 验证真实需求。

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

规则：
- 同一学生 / 学科同一时点默认最多一个 active lead；
- teacher 必须是同机构 active membership；
- 必须有 matching active `teaching` subject scope；
- Subject Scope 只决定“可否分配”，Assignment 才决定普通教师具体学生数据范围。

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
- `owner_membership_id`（new 可空；confirmed 起必须 active 且教学关系有效）
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

“顽固/长期问题”由失败、复发、持续时间等事实派生，不维护第二套表。

### Case 类型与默认 workflow

- knowledge：当堂订正 → 相似题 → 延迟独立验证 → stable/review/closed；
- habit：可观察行为 → 策略干预 → 多场景连续观察 → 稳定/调整；
- exam_strategy：方法 → 针对性应用 → 限时/模拟迁移 → 独立验证。

三类共享同一 Case/Evidence/Intervention/Assessment/Action 模型；知识“三阶”不是数据库三列。

### 状态不变量

- `new`：快速草稿，可以暂时没有完整结构和 action；
- `confirmed / intervening / pending_verification / stable`：始终必须有一个 pending primary action；
- 暂缓 / 观察：使用 `review` primary action，且 `due_at` 必填；`pause_reason` 只解释原因；
- `pending_verification`：通常 primary action 为 verify；
- `stable` 但未 closed：仍然有 review / verify；
- `closed`：不得存在 pending primary action；
- `reopen` 是受控命令 / event，不是第七个 status；
- `Assessment passed ≠ stable ≠ closed`；产品语言可把 `closed` 表达为“已清零”。

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
- `source_type`：`exam / homework / essay / classwork / quiz / observation / guardian_report / other`
- `source_parent_communication_id`（guardian_report 时可用；具体 FK/nullable 约束在 migration design）
- `title`
- `observed_at`
- `summary`
- `storage_object_path`（可选）
- `created_by_membership_id`
- `created_at`

Guardian response 只有在授权教师判断与教学相关时才可形成 Evidence；必须保留来源，不能自动成为专业诊断。

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

### Teaching fact gate

要成为 `teacher_membership_id` 的实际教学 actor，至少需要：
- active membership；
- teacher capability；
- matching `teaching` subject scope；
- 合法 Student Assignment / Lesson relationship。

Subject Lead 的 leadership scope、Academic Admin、Org Admin 权限本身**不能伪造 Intervention**。

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

Assessor 若以实际教学/验证教师身份写入，同样必须满足 Teaching Fact Gate。

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
- done / cancelled 保留历史；
- assignee 必须 active 且关系合理；
- 家庭配合要求不放进 Case Action，因为 Guardian 不是 organization membership。

`due_at` 是时间点；Today / overdue 判断按 organization timezone 转换成业务日期。

家校中与某 Learning Case 直接相关的员工跟进优先复用 `action_type=communicate`。

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

Lesson teacher 必须满足 Teaching Fact Gate。

## `lesson_students`

- `lesson_id`
- `student_id`
- `attendance_status`

一对一只是一个 lesson_student。小班可多个学生；课程中发生的 Case 结果通过 Intervention / Assessment / Event 关联，不另建重复结果表。

Lesson 创建建议通过 `start_lesson` command 验证 teacher/subject/student relationships。小班最终 completion 的事务粒度留 Phase 0B.0 故障/并发 Spike。

---

# 10. 综合观察（后续）

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

V1 家长提供的、被教师认定可作为 Case Evidence 的信息不依赖 Observation 上线，可先由 `guardian_report` Evidence 明确来源。

---

# 11. 家校沟通

## 版本边界

### V1 Internal Pilot
在 Student/Case context 内提供最小能力：生成/编辑 Draft、复制到现实沟通渠道、记录实际沟通、家庭配合、家长回应、follow-up、finalized snapshot；**不新增第五个教师主导航**。

### V1.1
再考虑独立家校工作台与更强的周度/阶段综合协调。

不要求家长 App、微信 API、短信网关、已读回执。

## `parent_communications`

候选字段：
- `id`
- `organization_id`
- `student_id`
- `communication_type`：`lesson_feedback / weekly_update / issue_follow_up / stage_review / urgent / other`
- `direction`：`outbound / inbound / conversation`
- `status`：`draft / finalized`
- `channel`：`phone / wechat / in_person / other`（finalized 时按业务需要）
- `occurred_at`（真实沟通时）
- `content_snapshot`：当时实际沟通/准备沟通的结构化内容快照
- `home_support_snapshot`（可作为 content schema 的结构部分；最终是否独立列由 migration design 决定）
- `guardian_response_snapshot`（同上）
- `recorded_by_membership_id`
- `finalized_by_membership_id`（finalized 时）
- `finalized_at`（finalized 时）
- `follow_up_assigned_membership_id`（非 Case 的纯沟通跟进可选）
- `follow_up_at`（可选）
- `follow_up_status`：`pending / done / cancelled`（存在非 Case follow-up 时）
- `follow_up_completed_at`（可选）
- `version`
- `created_at`
- `updated_at`

### 规则

- Draft 不是“已联系家长”；
- finalized 是实际沟通历史快照，不随后续 Case 静默变化；
- finalized 普通业务不可 UPDATE 覆盖，纠错走 correction/supersede；
- 与 Case 直接相关的员工 follow-up 优先使用 Case Action communicate；
- 非 Case 纯家校 follow-up 才使用上述轻量 follow-up 字段；
- 不建立通用第二套 Todo；
- 家庭配合不是 staff Action；
- 家长回应不自动成为正式专业结论。

## `parent_communication_recipients`

产品语义允许一次沟通对应一个或多个实际 Guardian。

候选：
- `parent_communication_id`
- `guardian_id`

如果 Pilot 证明永远只记单联系人，可推迟 join table，但不能把产品语义永久锁死为单 recipient。

联系方式引用 Guardian，不在沟通历史里重复维护主联系方式。

---

# 12. 阶段报告 / Stage Review

继续复用 `reports`，**不新增 `stage_reviews` 平行表**。

## `reports`

- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`（综合报告可空）
- `report_type`：subject_stage / comprehensive_stage / other（最终 codes 在 migration design 冻结）
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
- `finalized_by_membership_id`（可空）
- `finalized_at`（可空）
- correction/supersede reference/event（具体实现待 Commands/Data Model design）

period_start / period_end 是机构时区下的业务日期。

### 规则
- 系统自动整理 Case/Lesson/Evidence/Assessment/Action 事实；教师主要填写整体进步、遗留问题、下一阶段计划等真正需要专业判断的内容；
- `source_cutoff_at + content_snapshot + finalized` 保证历史可解释；
- finalized 不随底层事实静默改写；
- finalized Report 不等于已告知家长；真正对外沟通仍形成 Parent Communication；
- AI 可以辅助 Draft，但不能代替 `finalized_by`。

---

# 13. 审计、幂等与合并

## `audit_logs`

- `id`
- `organization_id`
- `actor_user_id` / provider-neutral actor identity representation（最终 identity strategy 后落地）
- `actor_membership_id`
- `entity_type`
- `entity_id`
- `action`
- `changed_fields`
- `operation_id`（可选）
- `occurred_at`

不复制完整敏感正文，不记录 Password / Token /完整家校/报告正文。

## `operation_receipts`

是否统一使用由 Phase 0B Spike 决定。只服务普通多表命令幂等，绝不保存 credential 明文响应。

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

# 14. 派生数据与治理异常

优先派生而不是另存台账：
- 本周新增 / 解决；
- 待验证；
- 到期 / 逾期 action；
- 无日期待安排 action；
- 复发次数；
- 长期重点 / 顽固问题；
- 报告摘要指标；
- 高频问题；
- orphan Case/Action；
- long overdue；
- long pending verification；
- repeated failed verification / reopen；
- stale Quick Capture / long-running new Case；
- handoff remaining；
- communication follow-up due；
- stage review due；
- attachment reference inconsistency；
- duplicate student candidates。

这些是“可处理事实”，**不新增 Learning Case status，不建立教师效能分/学生风险分**。

客户端 View 必须明确安全语义，优先 `security_invoker = true` 或等价安全机制。

---

# 15. 数据库硬约束

必须防止：
- child organization 与 parent 错配；
- 一个 Auth identity 在 V1 跨机构 onboarding / active 双活；
- membership / subject scope / assignment 跨机构；
- teacher assignment 没有 matching active teaching scope；
- subject lead 作用于没有 matching leadership scope 的学科；
- 非 active owner / assignee；
- Case owner 没有合法 teacher capability + teaching scope + student relationship；
- leadership/admin 权限被用来伪造 Intervention/Assessment/Lesson teacher；
- 同一学生 / 学科冲突 active lead；
- confirmed+ case 无 primary action；
- 暂停 review 无 due_at；
- closed 仍有 pending primary；
- lesson teacher / students / subject 跨机构/教学关系非法；
- taxonomy parent / child 跨学科；
- taxonomy 与 subject profile 学科不一致；
- evidence / intervention / assessment / action 跨 Case 机构；
- guardian_report Evidence 指向跨机构 communication；
- finalized Parent Communication / Report 被普通业务静默覆盖；
- merged Student 继续作为新业务主档案；
- Student inactive/archive 后留下未经 reconciliation 的非法 active 业务关系。

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
- subject scope `(membership_id, organization_subject_id, scope_kind, status)`
- Parent Communication follow-up / status
- Report period / status
- active identity membership unique lookup（物理字段待 Auth identity strategy）

Reference Supabase live-session helper 关注 `auth.sessions.id = jwt session_id`；其他 provider 必须以等价安全保证替代。

Phase 0B 要求：
- helper 语义由自动化测试证明；
- RLS 中避免同一语句无意义逐行重复昂贵 helper；
- 对核心 Today / Student / Case 查询使用 `EXPLAIN (ANALYZE, BUFFERS)` 或等价证据；
- Subject Scope + Assignment 多层过滤需真实观测计划；
- 若 live-session 校验成为真实瓶颈，必须通过 ADR 调整实现，不能静默删除安全条件。

---

# 17. 删除、停用与纠错策略

默认：
- member → disabled，且先 handoff；
- teaching subject scope → inactive/end，且先学科级 handoff；
- Student → inactive/archived/merged，且先 reconciliation；
- Case / Lesson / Evidence → archived / 受控更正，不随意物理删除；
- finalized Parent Communication / Report → correction/supersede，不静默覆盖；
- 核心历史不 cascade 丢失；
- 纯连接或可重建缓存才考虑 cascade；
- 真正个人信息删除 / 导出 / 更正走管理员治理流程。

---

# 18. Excel / 领导方法 → 软件映射

高置信方法骨架：

`学生档案 → 三类问题初诊 → 知识三阶闭环 → 周度跟进 → 顽固问题 → 家校沟通 → 阶段复盘`

软件映射：
- 一工作簿一学生 → 机构统一 Student；
- 年级/校区 → Enrollment 历史；
- 学情定位/优势 → Student Subject Profile 当前上下文；
- 授课老师 → Teacher Subject Scope + Student Teacher Assignment；
- 学管 → Student Staff Assignment；
- 初诊 → Initial Diagnosis workflow → Learning Case，不建平行初诊台账；
- 三阶闭环 → knowledge Case workflow + Evidence / Intervention / Assessment / Action / Event；
- 学习习惯/考试技巧 → 各自默认 workflow，不机械套三阶；
- 下周重点 → Case Action；
- 周度跟进 → 从真实事实派生；
- 顽固问题 → 同一 Case 的长期/失败/复发派生提示；
- 家校沟通 → Parent Communication draft/finalized snapshot + 家庭配合/回应；
- 阶段复盘 → Report snapshot + 人工 finalized responsibility；
- 自由分类 → taxonomy + 自由标题。

### 来源纪律

问题编号、优先级、状态、责任人、下次跟进、记录人等部分字段在 Excel 化原型中明确属于管理建议，并非都能归因于源 Word。Xueqing 可以在证明多人协作价值后采用，但应称为“软件化增强”，不能误称“领导原始字段要求”。
