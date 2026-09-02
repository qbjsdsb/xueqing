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
- **学生/学科服务生命周期与 Learning Case 解决生命周期分层，不能为了停读/归档而伪造 Case 已清零；**
- 历史优先 append/event，不覆盖当前字段抹掉过去；
- 姓名和自由文本不承担唯一性；
- 核心历史默认 RESTRICT / archived / disabled / merged / 受控更正，不随意 cascade；
- 关键可变快照使用 `version` 做乐观并发；
- 同一事实只存一次，周度、阶段、高频问题和治理提示优先派生；
- finalized 家校/报告保存当时快照，后续异步事实新增事件，不回写旧 finalized 历史；
- Provider-specific Auth/Storage 差异不得渗透到业务领域对象。

### Phase 0A.6 Cloud/Auth P0 Gate

Xueqing 当前同时评估官方 Supabase 与中国大陆 CloudBase PG。两者 Auth identity 类型与 Session 实现并非 100% 相同。

正式 migrations 前**暂不冻结**“业务 Profile 主键是否直接等于 provider `auth.users.id`”。Phase 0B.0 必须用虚构数据比较：

1. provider-specific auth PK；
2. business Profile UUID + external `auth_subject_id`；
3. text auth subject + 受控 provisioning。

任何正式业务 migration 在 Auth identity strategy 与 revoked-session security Spike 通过前不得落地。

---

# 2. 机构、身份与授权

## `profiles`

逻辑语义：一个业务 Profile 对应一个已知 Auth identity。

稳定业务字段：display name、avatar path、created/updated time。

**Auth PK/FK 的物理类型 P0 pending**。无论最终 provider 如何：
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

`time_zone` 是机构业务日期的唯一事实源。Today、Action 到期/逾期、课程所属业务日期、周度/阶段统计边界和报告周期均按 organization timezone 解释，不能直接相信设备时区。

系统事件仍保存 UTC；展示和业务日期计算时再转换为 organization timezone。V1 不做 campus 独立时区。

## `campuses`

- `id`
- `organization_id`
- `name`
- `status`

## `roles`

V1 固定能力角色：

`org_admin / academic_admin / subject_lead / teacher / student_advisor`

角色用于能力组合，不把学科/学生关系塞进 role。

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
2. V1 同一 Auth identity 在 onboarding/active 时全 project 最多属于一个 organization；
3. 其他机构 disabled 历史可以保留。

## `membership_roles`

- `membership_id`
- `role_id`

一个 membership 可以多个角色。

## `membership_subject_scopes`

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
- teacher + teaching scope：可以在该科承担 teacher assignment；
- subject_lead + leadership scope：该科管理范围；
- scope 不自动授予该学科所有学生访问权；
- leadership scope 本身不能让 Subject Lead 伪装成授课教师。

结束 teaching scope 前必须先处理该科 active assignments、Case ownership 与 pending Actions。

## Auth Session

安全目标：signOut / credential reset / disabled 后，旧 Access Token 不能继续读取学生数据。

Supabase reference 可用 JWT `session_id → auth.sessions` helper；CloudBase 等候选必须在 Phase 0B.0 证明等价保证。未验证前不得降低此不变量。

---

# 3. 学期、年级与 Student 主档案

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

姓名不能做硬唯一键。

### Student service lifecycle｜完整状态机

```text
active --deactivate_student--> inactive --archive_student--> archived
active <--reactivate_student-- inactive <--unarchive_student-- archived
```

- `active`：机构当前提供实际服务；
- `inactive`：整体服务暂停，但仍处于可管理/准备恢复状态；
- `archived`：退出普通当前业务视图，历史保留，**不是终态**；
- `merged`：重复档案被受控合并后的**终态**，不可 unarchive/reactivate 为独立 Student。

硬规则：
- `archive_student` 只能 `inactive → archived`；
- `unarchive_student` 只能 `archived → inactive`；
- `reactivate_student` 只能 `inactive → active`；
- 禁止 `active → archived` 和 `archived → active` 直跳；
- `unarchive` 只恢复可管理状态，不代表重新开课。

升年级/换校区使用 Enrollment 历史，不新建 Student。

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

不使用 `students.grade` 覆盖历史。

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

parent/child 必须同 organization_subject；历史已引用节点停用而不是硬删。

## `student_subject_profiles`

- `id`
- `organization_id`
- `student_id`
- `organization_subject_id`
- `status`：`active / inactive / archived`
- `current_positioning_code`（可选；存储形式在 migration design 冻结）
- `current_positioning_summary`（可选）
- `strengths_summary`（可选）
- `teaching_cadence_note`（可选，仅真实使用时）
- `version`
- `created_at`
- `updated_at`
- `archived_at`（可选）

唯一 `(organization_id, student_id, organization_subject_id)`。

### Subject Profile service lifecycle｜完整状态机

```text
active --deactivate_student_subject_profile--> inactive --archive_student_subject_profile--> archived
active <--reactivate_student_subject_profile-- inactive <--unarchive_student_subject_profile-- archived
```

- `active`：该学生当前在机构持续该学科教学；
- `inactive`：该学科当前停止/暂停持续教学，但历史仍保留；
- `archived`：该学科主线退出普通当前业务视图，历史保留，**可受控恢复，但不能直接 active**。

硬规则：
- `active → inactive` 前必须 reconcile teacher assignments、Case owner、pending Actions、Lesson/future workflow；
- `inactive → archived` 前必须已经不存在当前教学义务；
- `archived → inactive` 只恢复主线到可管理状态，不创建 assignment/Action；
- `inactive → active` 前必须重建合法 teacher assignment、owner 和 unresolved formal Case 的 pending primary Action；
- 禁止 `active → archived`、`archived → active` 直跳。

### Tracking suspended exception

Profile inactive/archived 时 unresolved Case：
- 保留真实 `confirmed/intervening/pending_verification/stable` resolution status；
- 不要求 current pending primary Action；
- 不进入普通教师 Today；
- 不允许普通教学事实写入或新 Lesson；
- 写可解释 tracking suspended/archived event；
- 不伪造 `closed=已清零`。

### Primary Action 不变量适用范围

> **只有 Student Subject Profile = active 的 formal open Case，才必须存在 pending primary Action。**

Profile inactive/archived 是明确 suspended exception。

### 定位/优势

- 定位是当前教学上下文，不是能力分/人格标签；
- 优势不强制填写；
- 当前摘要可更新；
- Initial Diagnosis 是否另存轻量 initial-baseline snapshot 待 Pilot 验证。

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
- 同一学生/学科同一时点默认最多一个 active lead；
- teacher membership 必须 active；
- 必须有 matching active teaching scope；
- **active teacher assignment 必须对应 Subject Profile=active；不是“通常要求”；**
- Subject Scope 只决定可否分配，Assignment 才决定普通教师具体学生范围。

## `student_staff_assignments`

- `id`
- `organization_id`
- `student_id`
- `membership_id`
- `assignment_role`：`advisor / homeroom / coordinator / other`
- `active_from`
- `active_to`
- `status`

班主任/学管不能伪装成学科教师。

---

# 6. 学情案例

## `learning_cases`

- `id`
- `organization_id`
- `student_subject_profile_id`
- `owner_membership_id`（new 可空；active profile 的 formal Case 起必须合法）
- `case_type`：`knowledge / habit / exam_strategy / other`
- `taxonomy_node_id`（new 可空）
- `title`
- `description`（可选）
- `root_cause_summary`（可选）
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

### Case 类型默认 workflow

- knowledge：当堂订正 → 相似题 → 延迟独立验证 → stable/review/closed；
- habit：可观察行为 → 策略干预 → 多场景连续观察 → 稳定/调整；
- exam_strategy：方法 → 针对性应用 → 限时/模拟迁移 → 独立验证。

### Case lifecycle 不变量

- `new`：快速草稿；
- **当 Subject Profile=active 时**，confirmed/intervening/pending_verification/stable 必须有一个 pending primary Action；
- **当 Subject Profile=inactive/archived 时，上述 Action 要求暂停，Case 保留真实 resolution status；**
- 暂缓/稳定观察的 review Action 必须有 due_at；
- `closed` 不得有 pending primary Action；
- `reopen` 是 command/event，不是第七 status；
- `Assessment passed ≠ stable ≠ closed`；
- 产品语境只有真实解决 closure 才可以显示“已清零”；
- Subject Profile inactive/archive 不等于 Case closed。

## `case_events`

append-only 时间轴：
- `id`
- `organization_id`
- `learning_case_id`
- `event_type`
- `actor_membership_id`
- `occurred_at`
- `metadata`

普通业务不开放 UPDATE/DELETE 历史事件。

Profile deactivation/archive/unarchive/reactivation 应对相关 open Cases 写可解释 event，例如 tracking suspended/archived/unarchived/resumed；**这些不是新增 Case status。**

---

# 7. Evidence、Intervention、Assessment

## `case_evidence`

- `id`
- `organization_id`
- `learning_case_id`
- `source_type`：`exam / homework / essay / classwork / quiz / observation / guardian_report / other`
- `source_parent_communication_id`（guardian_report 时可用）
- `title`
- `observed_at`
- `summary`
- `storage_object_path`（可选）
- `created_by_membership_id`
- `created_at`

Guardian 提供的信息只有经授权教师判断与教学相关时才形成 Evidence；必须保留来源 communication event。

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

### Teaching Fact Gate｜跨事实源唯一硬条件

任何 Intervention、Assessment、教学型 Evidence、Lesson teacher 行为的实际教学 actor，**运行时必须同时满足：**

```text
live session
+ active membership
+ teacher capability
+ matching active teaching scope
+ target Student Subject Profile = active
+ 合法 active Student Assignment 或受控建立/验证的合法 Lesson relationship
+ operation-specific permission
```

说明：
- `live session` 是运行时 RLS/command 条件，不是表字段，但不能从 Data Model 语义中省略；
- inactive/archived Profile 即使遗留旧 scope/assignment，也必须拒绝新的实际教学事实；
- Leadership/Admin/Advisor 身份本身不能绕过 Gate；
- 初诊也必须先建立合法 teacher relationship，不能靠管理员“临时授权”绕过。

Assessment result 与 Case status 分离。

---

# 8. 下一步行动

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

规则：
- 同一 Case 最多一个 pending primary；
- **active Subject Profile 的 formal open Case 必须有 pending primary；**
- inactive/archived Subject Profile 的 unresolved Case 可以没有 pending primary，并退出 Today；
- profile deactivation/archive 时 pending Action 必须受控完成/取消并记录原因；
- profile reactivation 时 unresolved Case 在 profile active 前必须重新建立 next primary Action；
- closed 不得有 pending primary；
- Guardian 不是 membership，家庭配合不能成为 Case Action；
- Case-related 家校员工后续优先复用 communicate Action。

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

Lesson teacher 必须满足完整 Teaching Fact Gate，尤其 target Subject Profile=active。

## `lesson_students`

- `lesson_id`
- `student_id`
- `attendance_status`

一对一只是一个 lesson_student；小班可以多个。Lesson 创建建议走 `start_lesson`；小班最终 completion 事务粒度留 Phase 0B.0 Spike。

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

只记录必要、可观察事实。

---

# 11. Parent Communication｜家校沟通事件

## 版本边界

V1 Internal Pilot 在 Student/Case context 内提供最小家校事件能力；V1.1 再做独立工作台。

## 核心语义

Parent Communication 是**一次实际沟通事件**，不是不断变化的聊天线程。

- Draft 可编辑；
- Finalized 后内容冻结；
- 后续异步家长回复新增新的 inbound/reply event；
- 电话/面谈同一现场双向交流可以一条 `conversation` event；
- Thread 是多条 events 的聚合关系，不是 mutable finalized row。

## `parent_communications`

候选字段：
- `id`
- `organization_id`
- `student_id`
- `communication_type`：`lesson_feedback / weekly_update / issue_follow_up / stage_review / urgent / other`
- `direction`：`outbound / inbound / conversation`
- `status`：`draft / finalized`
- `channel`：`phone / wechat / in_person / other`
- `occurred_at`
- `content_snapshot`
- `home_support_snapshot`
- `guardian_response_snapshot`（仅 conversation 同一 interaction 可有；后续异步回复不得回写）
- `reply_to_communication_id`（可选）
- `recorded_by_membership_id`
- `finalized_by_membership_id`
- `finalized_at`
- `follow_up_assigned_membership_id`（非 Case 的纯沟通后续可选）
- `follow_up_at`
- `follow_up_status`：`pending / done / cancelled`
- `follow_up_completed_at`
- `version`
- `created_at`
- `updated_at`

规则：Draft 不计“已联系”；finalized 普通业务不可 UPDATE；outbound finalized 后家长后来回复新增 inbound communication；reply_to 必须同 organization+student；finalized correction 保留原 snapshot；家庭配合不是 staff Action；Guardian response 不自动成为专业诊断。

## `parent_communication_recipients`

- `parent_communication_id`
- `guardian_id`

支持一个 actual event 对应一个或多个 recipients。

Communication 可以关联 Case/Evidence/Assessment/Lesson/Report 作为来源；不得复制第二套教学事实。

---

# 12. Report / Stage Review

继续复用 `reports`，不新增 `stage_reviews` 平行表。

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
- correction/supersede reference/event（具体实现待 design）

规则：系统自动整理正式事实，教师只填写真正需要专业判断的内容；finalized 不随底层事实静默改写；Report finalized ≠ 已告知家长；AI 可辅助 Draft，不能代替 finalized_by。

---

# 13. 审计、幂等与合并

## `audit_logs`

- `id`
- `organization_id`
- provider-neutral actor identity representation（最终 identity strategy 后落地）
- `actor_membership_id`
- `entity_type`
- `entity_id`
- `action`
- `changed_fields`
- `operation_id`（可选）
- `occurred_at`

不复制完整敏感正文，不记录 Password/Token/完整家校/报告正文。

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

source→merged，target 保留；旧 ID 仍能解释迁移去向。merged 是 Student service lifecycle 终态。

---

# 14. 派生数据与治理异常

优先派生：
- 本周新增/解决；
- pending verification；
- due/overdue/undated Action；
- 复发次数；
- 长期重点/顽固问题；
- 高频问题；
- orphan Case/Action；
- long overdue；
- long pending verification；
- repeated failed/reopen；
- stale Quick Capture；
- handoff remaining；
- communication follow-up due；
- stage review due；
- attachment reference inconsistency；
- duplicate Student candidates；
- inactive/archived Subject Profile 下仍残留 pending Action；
- active Subject Profile 下 formal open Case 无 primary Action；
- inactive/archived Profile 仍产生教学事实；
- archived Student/Profile 被直接尝试 active；
- merged Student 被尝试恢复为独立 active Student。

这些是可处理事实，不新增 Case status，不做教师效能分/学生风险分。

---

# 15. 数据库硬约束 / Command 不变量

必须防止：
- organization 错配；
- Auth identity 在 V1 跨机构 onboarding/active 双活；
- membership / subject scope / assignment 跨机构；
- active teacher assignment 没有 matching teaching scope 或 active Subject Profile；
- subject lead 越过 leadership scope；
- Case owner 没有合法 Teaching relationship；
- leadership/admin 权限伪造教学事实；
- **任何 Teaching Fact Gate 缺少 live session / active membership / teacher capability / teaching scope / active Profile / legal relationship / operation permission；**
- 同 student+subject 冲突 active lead；
- active Subject Profile + formal open Case 无 pending primary Action；
- inactive/archived Subject Profile 仍有普通 pending Action 持续进入 Today；
- profile reactivation 时 unresolved Case 没有新 primary Action；
- archived Profile 直接 active；
- archived Student 直接 active；
- merged Student 被 unarchive/reactivate；
- 暂停/稳定观察 review 无 due_at；
- closed 仍有 pending primary；
- lesson teacher/student/subject 关系非法；
- taxonomy 跨学科；
- Evidence/Intervention/Assessment/Action 跨 Case/organization；
- guardian_report 指向跨机构/跨学生 communication；
- communication reply_to 跨 organization/student；
- finalized Communication/Report 被普通业务静默覆盖。

实现手段按适用性选择：composite FK、CHECK、partial unique index、exclusion constraint、trigger / 受控 Function / RLS helper。跨表和 live-session 不变量不要假装一个 CHECK 就能解决。

---

# 16. 索引与性能

重点：organization_id、membership_id、student_id、organization_subject_id、student_subject_profile_id+status、learning_case_id/status、due_at、active assignments、subject scope composite lookup、communication status/occurred_at/reply_to/follow-up、Report period/status、active identity membership lookup。

Phase 0B 对 Today / Student / Case / RLS 多层过滤使用 EXPLAIN 或等价证据，不能为了性能静默删除安全条件。

---

# 17. 删除、停用、暂停、归档、恢复与纠错策略

默认：
- member → disabled，先 handoff；
- teaching subject scope → inactive/end，先学科级 handoff；
- Subject Profile：`active → inactive → archived`；恢复只能 `archived → inactive → active`；
- Student：`active → inactive → archived`；恢复只能 `archived → inactive → active`；
- Student `merged` 是终态；
- archive 不是删除；unarchive 不是 reactivate；
- Profile inactive/archived 只暂停当前服务，不改写未解决 Case status；
- archived/inactive 下不允许新教学事实或新 Lesson；
- Case/Lesson/Evidence → archived/受控更正，不随意物理删除；
- finalized Communication/Report → correction/supersede，不静默覆盖；
- 核心历史不 cascade 丢失；
- 真正个人信息删除/导出/更正走管理员治理流程。

---

# 18. Excel / 领导方法 → 软件映射

高置信方法骨架：

`学生档案 → 三类问题初诊 → 知识三阶闭环 → 周度跟进 → 顽固问题 → 家校沟通 → 阶段复盘`

软件映射：
- 一工作簿一学生 → 机构统一 Student；
- 年级/校区 → Enrollment 历史；
- 学情定位/优势 → Student Subject Profile；
- 某学科是否仍在持续教学 → Subject Profile lifecycle；
- 授课老师 → Subject Scope + Student Teacher Assignment；
- 学管 → Student Staff Assignment；
- 初诊 → active Subject Profile + legal teacher assignment + Initial Diagnosis workflow → Learning Case；
- 知识三阶 → knowledge workflow + Evidence/Intervention/Assessment/Action/Event；
- 习惯/考试技巧 → 各自 workflow；
- 下周重点 → Case Action；
- 周度 → 派生；
- 顽固 → 同一 Case 长期/失败/复发派生；
- 家校 → immutable communication events + recipients/replies/follow-up；
- 阶段复盘 → Report snapshot + human finalization。

### 来源纪律

问题编号、优先级、状态、责任人、下次跟进、记录人等部分字段在 Excel 化原型中明确属于管理建议，并非都能归因于源 Word。Xueqing 可以在证明多人协作价值后采用，但应称为软件化增强。
