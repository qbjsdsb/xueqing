# Phase 0A.6 Foundation Change Proposal

> 状态：产品/领域变更提案。用于集中记录 Phase 0A.6 对既有 `PRODUCT / DATA_MODEL / COMMANDS_AND_INVARIANTS / AUTH_AND_PERMISSIONS` 的必要修订。正式回写前还需 Product Completeness Audit；标为 `PENDING SPIKE` 的项不得提前进入 migration。

## 1. 原则

只允许三类结果：

- **ACCEPT**：Phase 0A.6 已有充分产品依据，应回写 Foundation。
- **PENDING SPIKE**：确有重要问题，但实现方案需要 Phase 0B 最小实验才能决定。
- **REJECT / DERIVE**：不新增领域对象，继续从已有事实派生。

目标不是“让模型更完整”，而是减少未来返工同时保持教师低负担。

---

# 2. ACCEPT｜Teacher Subject Scope

## 问题
现有模型只有：
- membership role；
- student+subject assignment。

无法明确表达：

> 这个老师在机构内被允许/被安排从事哪些学科教学？

不能从“当前恰好负责哪些学生”反推老师的学科范围。

## 建议新增

`membership_subject_scopes`

候选字段：
- `id`
- `organization_id`
- `membership_id`
- `organization_subject_id`
- `status`：active/inactive（最终命名与 assignment status 对齐）
- `active_from`
- `active_to`
- `created_at`
- `updated_at`

### 语义
Subject Scope = **可以在该学科承担被授权角色/assignment 的范围**。

它不自动授予该学科所有学生读取权。

Teacher 的具体学生范围仍来自 `student_teacher_assignments`。

Subject Lead 同样需要 subject scope；role 负责“能做什么”，scope 负责“在哪个学科”。

Academic/Admin 是否 bypass subject scope 按能力模型明确，不伪造 assignment。

## 必要约束
- 同 organization；
- membership active 才能新增 active scope；
- teacher assignment 新建时必须有 matching active subject scope；
- 不能直接删除仍被 active assignment / Case owner / pending Action 使用的 scope。

## 命令影响
评估新增：

`revoke_teacher_subject_scope_and_handoff`

用于“老师仍在职但退出某学科”。

**Decision：ACCEPT**

---

# 3. ACCEPT｜Student Subject Profile 当前定位与优势

## 问题
领导 Excel 的“学情定位 + 学科/课堂优势”是教学上下文，不应丢失；现有 `student_subject_profiles` 过于空。

## 建议增强

候选字段：
- `current_positioning_code`（可选）
- `current_positioning_summary`（可选）
- `strengths_summary`（可选）
- `teaching_cadence_note`（可选，只有机构确实使用时）
- `version`

### 规则
- 定位不是“能力分”；
- Strengths 不强制填写；
- summary 是当前快照，可更新；
- 重大历史变化由 Case/Report/必要 event 解释，不把 profile 变成长文本历史库。

### Positioning code
领导 Excel 现有粗定位可以作为默认选择：
- 基础薄弱；
- 中等待提升；
- 中等稳定；
- 培优拔高。

但正式数据库不急于硬编码不可扩展 enum。优先评估 stable code + UI label/机构配置，避免未来术语变化触发数据库 enum migration。

**Decision：ACCEPT 当前定位/优势语义；具体 code 存储形式待 migration design。**

---

# 4. PENDING SPIKE｜Initial Diagnosis Snapshot

## 真实需求
当前 profile summary 会变化，但机构可能需要明确回答：

> 第一次试听/正式建档时，老师当时如何判断这个学生？

这对：
- 后续阶段对比；
- 教师交接；
- 向领导解释初始基线；
- 纠纷/历史解释；

可能有真实价值。

## 不允许
不能再造一套“初诊问题表”，与 Learning Case 双维护。

## 候选
A. 不保存独立 snapshot，只保留当前 profile + 最早 Evidence/Case。

B. 初诊 formalize 时保存一个**轻量、一次性、不可变 snapshot/event**：
- diagnosed_at/by；
- positioning snapshot；
- strengths snapshot；
- related Case IDs/source cutoff。

## 决策 Gate
用真实机构流程回答：

> 几个月后是否确实需要“一键看到当时初诊整体基线”，而不仅是逐条翻最早 Case？

**Decision：PENDING PRODUCT VALIDATION。不得先建 `initial_diagnoses` 大表。**

---

# 5. ACCEPT｜三类 Case Workflow 只改产品模板，不改生命周期

Knowledge / Habit / Exam Strategy 共享：
- Learning Case；
- Evidence；
- Intervention；
- Assessment；
- Action；
- status lifecycle。

不新增：
- knowledge_case 表；
- habit_case 表；
- three_stage_status lifecycle。

三阶订正是 knowledge 默认 workflow template，不是 schema 三列。

**Decision：ACCEPT workflow；REJECT parallel tables/statuses。**

---

# 6. ACCEPT｜`closed` 的产品语言可映射“已清零”，但数据库仍用 closed

冻结：
- assessment passed = 本次验证通过；
- stable = 已改善/稳定观察；
- closed = 退出主动跟进，产品语境可显示“已清零”；
- reopen = command/event。

“满分通关”不直接把 status 改 closed。

**Decision：不改 Foundation lifecycle。**

---

# 7. ACCEPT｜Lesson Workspace 与 start command review

现有 `complete_lesson` 是正确方向。

Phase 0A.6 新增：开始 Lesson 可能同时验证 teacher/subject/student 并创建 lesson + lesson_students，因此评估受控：

`start_lesson`

而不是 Flutter 自己拼多个 inserts。

### 已冻结
- Lesson 不是完整排课；
- Evidence/Intervention/Assessment 可课中逐步可靠保存；
- `complete_lesson` 最后收口 Action/Case/Lesson state；
- 小班 transaction boundary 需 Phase 0B Spike。

**Decision：ACCEPT workflow；`start_lesson` command 候选 ACCEPT，具体事务边界在 Commands review 固定。**

---

# 8. ACCEPT｜Parent Communication 必须区分 Draft 与真实沟通

现有 `parent_communications(summary)` 语义过弱。

至少需要表达：
- communication type；
- direction；
- draft vs finalized；
- actual channel/time；
- content snapshot；
- finalized_by/time；
-家庭配合内容；
- guardian response；
- follow-up；
- version（draft 并发）；
- correction/supersede 语义。

### 推荐实现方向
继续一个 `parent_communications` 主对象，不拆“草稿表/已发送表”。

主记录候选字段：
- `communication_type`
- `direction`
- `status: draft/finalized`
- `channel`（finalized 时）
- `occurred_at`（finalized 时）
- `content_snapshot` / structured content
- `recorded_by_membership_id`
- `finalized_by_membership_id`
- `finalized_at`
- `follow_up_at`（可选）
- `follow_up_assigned_membership_id`（若最终采用）
- `version`
- `created_at / updated_at`

不要因为字段名字就把完整家长聊天原文塞进系统。

**Decision：ACCEPT 语义增强。**

---

# 9. ACCEPT｜Parent Communication 多 recipient 语义

当前单 `guardian_id` 无法稳定表达一次沟通给父母双方/多监护人。

产品语义支持多个实际 recipient。

数据库候选：

`parent_communication_recipients`
- communication_id
- guardian_id
- recipient_role/metadata（如真实需要）

只有 Pilot 明确永远单联系人，才可以暂缓 join table。

**Decision：ACCEPT product semantics；schema timing 可随 V1/Pilot。**

---

# 10. ACCEPT｜Guardian response 来源语义

家长提供的教学相关事实不能永远塞 `case_evidence.source_type = other`。

候选：
- Evidence 增加 `guardian_report`；或
- 使用 future Observation + communication source reference。

### 判断
如果家长回应被教师认定足以作为 Case Evidence，应明确保留来源。

考虑 Observation 当前规划为 V1.5，而家校可能更早，因此 V1.1 最小路线优先评估：

`case_evidence.source_type += guardian_report`

并提供 source communication id/reference。

**Decision：ACCEPT 显式来源语义；最终 FK/link 结构待 Data Model revision。**

---

# 11. ACCEPT｜Home support request 不是 Case Action

Guardian 不是 organization membership。

家庭配合要求属于 Parent Communication snapshot/协作语义。

只有机构员工需要执行的后续，例如“周五由 Advisor 再联系”，才产生 staff follow-up/Case Action。

**Decision：REJECT guardian-as-case-assignee。**

---

# 12. PENDING MODEL｜Communication Follow-up

现有 `follow_up_at` 没有负责人/完成事实，闭环不够。

但新增全局 `staff_tasks` 会让产品滑向第二套 Todo。

候选：

A. 与 Learning Case 直接相关 → 使用 `case_actions(action_type=communicate)`。

B. 非 Case 的沟通跟进 → parent communication 自带一个轻量 follow-up owner/status。

C. 真正出现大量跨领域任务后，再设计通用 staff task。

**Decision：当前优先 A+B；REJECT 现在建立通用 Todo 系统。**

---

# 13. ACCEPT｜Reports 继续承载 Stage Review

不新增 `stage_reviews` 表。

现有 reports 已有：
- period；
- source_cutoff；
- schema/template version；
- content_snapshot；
- draft/finalized。

建议增强候选：
- `report_type`
- `version`
- `finalized_by_membership_id`
- `finalized_at`
- correction/supersede link/event。

### 原则
Subject review 与 comprehensive review 可由 report_type + organization_subject_id 表达。

Parent Communication 仍是对外真实沟通事实，不能用 report status 替代。

**Decision：ACCEPT。**

---

# 14. ACCEPT｜Finalized snapshot correction 是受控动作

Finalized Report / Parent Communication 不允许普通 UPDATE 静默覆盖。

候选命令：
- `finalize_parent_communication`
- `correct_parent_communication`
- `finalize_report`
- `supersede_report` / `correct_report`

是否每个都单独 function，留 Commands design；至少必须有明确 domain API，不暴露任意 status update。

**Decision：ACCEPT command semantics。**

---

# 15. DERIVE｜Weekly tracking

周度：
- 旧问题进展；
- 新问题；
- 本周动作；
- 验证；
- 下周重点；

全部优先从 Lesson/Case/Evidence/Assessment/Action 派生。

可允许教师加一条周度综合 judgment，但不建立必须填写的 `weekly_tracking` 表。

**Decision：DERIVE。**

---

# 16. DERIVE｜Stubborn / long-running problems

不建 `stubborn_cases`。

由：
- duration；
- failed/partial assessments；
- intervention count/context；
- reopen count；
-跨周期；

派生。

**Decision：DERIVE。**

---

# 17. DERIVE｜Governance anomalies

Orphan / long overdue / stale draft / long pending verification / handoff remaining 等优先 query/view 派生。

如果未来确实需要异常工单 lifecycle，再单独设计 Governance Case。

**Decision：DERIVE，当前不建 anomaly tables。**

---

# 18. ACCEPT｜Student inactive/archive 不能裸改 status

学生停止学习时，直接：

`students.status = inactive`

可能留下：
- pending Actions；
- active Cases；
- Today 永久 overdue；
- assignments 不一致。

Commands review 需要定义受控流程，候选：
- `deactivate_student`
- `archive_student`

至少要求 reconciliation：
- enrollment；
- assignments；
- Case/Action plan；
- future review（如需要）；
- audit。

Restart 则重建 enrollment/assignments，不新建 Student。

**Decision：ACCEPT domain workflow；命令名称待收口。**

---

# 19. ACCEPT｜Concurrency / Draft 语义，不新增第二数据库

保留：
- version / expected_version；
- operation_id；
- append-only UUID idempotency；
- encrypted local draft；
- explicit version conflict。

不做：
- CRDT；
- offline-first；
-本地完整学生数据库。

**Decision：维持 Foundation，补 UX/故障测试。**

---

# 20. P0 PENDING SPIKE｜Auth identity portability

当前 Foundation：

`profiles.id → auth.users(id)`

Supabase `auth.users.id` 与 CloudBase PG `auth.users.id varchar(64)` 类型心智不同。

在正式 migrations 前必须决定：
- provider-specific auth PK；
- business profile UUID + external auth_subject_id；
- text auth subject without hard FK。

必须用 RLS/EXPLAIN/provisioning complexity 决定。

**Decision：PENDING CLOUD SPIKE；这是 Phase 0B migration 前 P0 gate。**

---

# 21. P0 PENDING SPIKE｜Revoked Session Security

产品不变量：revoked/reset/disabled Session 不能继续读学生数据。

Supabase 当前设计使用 JWT session_id + auth.sessions helper。

CloudBase 已有 token revoke/session，但是否可原样达到该 RLS guarantee 未验证。

**Decision：PENDING CLOUD SPIKE；不能为了国内免费节点降低安全基线。**

---

# 22. REJECT｜Realtime dependency

CloudBase 与 Supabase Realtime 能力不同。

Foundation 已决定业务正确性不依赖 Realtime。

因此继续：
- save 后 refresh；
- page enter；
- app resume；
- manual refresh；

未来 Realtime 是 enhancement，不是 correctness foundation。

**Decision：REJECT Realtime-as-core。**

---

# 23. Foundation 回写清单

## `PRODUCT.md`
应补：
-领导教学语言/三类 workflow；
- teacher subject scope vs assignment；
-家校最小闭环可能需要进入 Pilot 而不是完全忽略；
- Stage Review 人工确认；
- governance anomaly；
- provider portability gate。

## `DATA_MODEL.md`
应补/改：
- membership_subject_scopes；
- student_subject_profile positioning/strengths/version；
- parent communication draft/finalized/recipients；
- report finalize/version/correction；
- guardian-report evidence source；
- identity portability 注记/P0；
- derived anomalies。

## `COMMANDS_AND_INVARIANTS.md`
应评估/补：
- start_lesson；
- revoke_teacher_subject_scope_and_handoff；
- student deactivate/archive reconciliation；
- finalize/correct communication；
- finalize/correct report；
- current handoff/merge semantics 与新 scope 一致。

## `AUTH_AND_PERMISSIONS.md`
应补：
- subject scope 是授权维度，不等于 assignment；
- subject lead 必须 scoped；
- teacher scope 不授予全学科学生；
- advisor family/report rights；
- Cloud provider identity/session implementation 仍需 P0 Spike。

---

# 24. 不允许进入 Phase 0B 的剩余 Gate

1. Product Completeness Audit 完成；
2. 本 proposal 中 ACCEPT 与 Foundation 无冲突；
3. P0 cloud/auth issues 明确进入 Phase 0B Spike 前置；
4. Initial Diagnosis Snapshot 做产品决定或明确推迟理由；
5. Communication follow-up 模型不能形成第二套混乱 Todo；
6. 最终 PR Head CI success；
7. 独立审计无 P0/P1 blocker。
