# Phase 0A.6 Foundation Change Proposal

> 状态：Phase 0A.6 领域变更提案。本文集中记录对既有 `PRODUCT.md / DATA_MODEL.md / COMMANDS_AND_INVARIANTS.md / AUTH_AND_PERMISSIONS.md` 的必要修订。它不是 migration，也不授权进入真实 Auth/RLS/CRUD。

## 1. 决策纪律

每个缺口只允许归入三类：

- **ACCEPT**：已经有充分产品依据，应回写 Foundation；
- **PENDING SPIKE**：需求真实，但实现必须由 Phase 0B.0 最小实验决定；
- **REJECT / DERIVE**：不新增领域对象，继续从现有事实派生。

判断标准始终是：

> 这是新的真实业务事实，还是同一事实的另一种展示/总结？

如果只是展示/总结，默认派生；如果只是为了让表结构看起来完整，默认不建。

---

## 2. ACCEPT｜Teacher Subject Scope

### 当前缺口
现有 Foundation 能表达：
- membership / role；
- 某老师当前负责哪个 Student + Subject。

但不能独立回答：

> 这个 membership 在机构内被授权在哪些学科承担教学或学科管理工作？

这不能从当前 Student Assignment 反推。

### 建议新增

`membership_subject_scopes`

候选字段：
- `id`
- `organization_id`
- `membership_id`
- `organization_subject_id`
- **`scope_kind`：`teaching / leadership`**
- `status`：active/inactive（最终命名与 assignment 历史策略对齐）
- `active_from`
- `active_to`
- `created_at`
- `updated_at`

### 三层授权必须分开

```text
Membership
  ↓
Role / capability
  ↓
Subject Scope
  ↓
Student Subject Assignment
```

- `teacher role + teaching scope`：表示可以在该学科承担教师 assignment；
- `subject_lead role + leadership scope`：表示该学科的管理范围；
- **Subject Scope 不是学生数据通行证**；普通教师仍需有效 Student Assignment 才能读取/修改具体学生本科数据。

示例：

```text
某老师 roles = teacher + subject_lead
subject scopes:
- 语文 / teaching
- 历史 / teaching
- 语文 / leadership
```

表示他教语文和历史，但只负责语文学科管理。

### 不变量
- membership / subject / scope 必须同 organization；
- active teacher assignment 必须匹配 active `teaching` scope；
- subject lead 权限必须匹配 active `leadership` scope；
- 不能直接结束一个仍被 active assignment / Case owner / pending Action 使用的 teaching scope；
- leadership scope 本身不允许伪造教学事实。

### 命令影响
评估/冻结：

`revoke_teacher_subject_scope_and_handoff`

用于“老师仍在职，但以后不再教某一学科”。必须先交接该科 assignments、Case ownership、pending Actions，再结束 scope。

**Decision：ACCEPT。**

---

## 3. ACCEPT｜Student Subject Profile 增加当前定位与优势

领导方法中“学情定位 + 学科/课堂优势”是有教学价值的上下文；现有 `student_subject_profiles` 过于空。

建议增强候选：
- `current_positioning_code`（可选）
- `current_positioning_summary`（可选）
- `strengths_summary`（可选）
- `teaching_cadence_note`（可选，仅在真实使用证明有价值时）
- `version`

规则：
- 定位不是学生能力评分；
- 优势不强制填写；
- 当前摘要允许更新；
- 重大历史变化由 Case / Report /必要 event 解释；
- 不把 profile 变成长文本历史库。

Excel 当前四档可作为默认产品口径参考：基础薄弱 / 中等待提升 / 中等稳定 / 培优拔高，但不急于写死成 PostgreSQL ENUM。

**Decision：ACCEPT 语义；具体 code 存储形式待 migration design。**

---

## 4. PENDING PRODUCT VALIDATION｜Initial Diagnosis Snapshot

初诊工作流必须有，但**不默认新增 `initial_diagnoses` 大表**。

大部分初诊事实已有自然归属：
- Student；
- Subject Profile；
- Evidence；
- Learning Case；
- Action。

唯一仍可能有真实价值的新事实是：

> 第一次试听/正式建档时，老师当时的整体基线判断。

候选：
- A：不建独立 snapshot，只依赖当前 profile + 最早 Evidence/Case；
- B：formalize 时生成轻量、不可变 initial-baseline snapshot/event，只保存 diagnosed_at/by、positioning/strengths snapshot、source cutoff/related Cases。

Pilot 要专门验证：几个月后领导/教师是否真的需要“一键回看当时整体初诊”。如果不需要，不造表。

**Decision：DEFER WITH VALIDATION。**

---

## 5. ACCEPT｜三类 Case Workflow，REJECT 三套 schema

统一底层继续使用：
- Learning Case；
- Evidence；
- Intervention；
- Assessment；
- Action；
- Case Event。

产品默认 workflow：
- `knowledge`：当堂订正 → 相似题 → 延迟独立验证 → stable/review/清零；
- `habit`：可观察行为 → 策略干预 → 多场景连续观察 → 稳定/调整；
- `exam_strategy`：方法 → 针对性应用 → 限时/模拟迁移 → 独立验证。

知识“三阶订正”是产品教学模板，不是三列数据库状态。

**Decision：ACCEPT workflow；REJECT parallel tables/statuses。**

---

## 6. ACCEPT｜“清零”只映射产品语言，不改生命周期

继续保持：

```text
Assessment passed ≠ stable ≠ closed
```

产品语言：
- passed = 本次验证通过；
- pending_verification = 等待判断/待验证；
- stable = 已改善 / 稳定观察；
- closed = 已清零 / 退出主动跟进；
- reopen = command/event。

“满分通关”不能自动把 Case 改为 closed。

**Decision：生命周期不变。**

---

## 7. ACCEPT｜Lesson Workspace + `start_lesson`

Lesson 是教学事实工作台，不是排课/收费 ERP。

冻结：
- 课前约 30 秒看旧问题、到期 action、待验证、最近事实；
- 课中 Evidence / Intervention / Assessment / Quick Capture 逐步可靠保存；
- 课后 30–60 秒由 `complete_lesson` 收口 Case/Action/Lesson state；
- 周度跟进优先从这些事实派生。

因为开始 Lesson 可能同时验证 teacher/subject/student relationship 并建立 `lesson + lesson_students`，建议增加受控领域命令：

`start_lesson`

小班 Lesson 的最终事务边界（整 Lesson 一个事务 vs 逐 Student/Case reconcile 后 finalize）**PENDING Phase 0B.0 fault/transaction Spike**，不在文档阶段假定。

**Decision：ACCEPT。**

---

## 8. ACCEPT｜家校进入 V1 Internal Pilot 的最小闭环，独立工作台仍 V1.1

领导方法中家校协同是闭环一环，因此“V1 完全没有家校”会损失方法完整性；但为此提前做家长 App/微信 API 又是 scope creep。

冻结版本边界：

### V1 Internal Pilot
在 **Student Detail / Case context** 内提供最小家校能力：
- 从已有教学事实生成/整理 Draft；
- 教师/Advisor 审阅；
- 复制到微信/电话/面谈等现实渠道；
- 记录实际沟通内容、recipient、家庭配合、家长回应、follow-up；
- finalized snapshot。

**不增加第五个教师主导航。**

### V1.1
再考虑：
- 独立家校工作台；
- 更强周度/阶段综合反馈；
- 批量/协调视图。

仍明确不做：家长 App、微信 API、短信网关、已读回执等作为 V1 前置。

**Decision：ACCEPT。**

---

## 9. ACCEPT｜Parent Communication Draft 与 Finalized 必须分离

现有 `parent_communications(summary)` 语义过弱。

主对象至少要能表达：
- `communication_type`
- `direction`
- `status = draft / finalized`
- channel / occurred_at（真实沟通后）
- `content_snapshot`
- home-support snapshot
- guardian-response snapshot
- `recorded_by_membership_id`
- `finalized_by_membership_id`
- `finalized_at`
- follow-up 语义
- `version`
- correction/supersede history。

原则：
- Draft 不计“已联系”；
- finalized 是当时真实沟通快照，不随后续 Case 静默变化；
- 普通 UPDATE 不覆盖 finalized 历史。

**Decision：ACCEPT。**

---

## 10. ACCEPT｜Parent Communication 多 recipient

产品语义支持一次沟通对应一个或多个实际监护人。

推荐候选：

`parent_communication_recipients`
- `communication_id`
- `guardian_id`

如果 Pilot 证明机构永远只记一个实际联系人，可推迟 join table，但领域语义不能被单 `guardian_id` 锁死。

**Decision：ACCEPT product semantics；schema timing 依 Pilot。**

---

## 11. ACCEPT｜Guardian response 必须保留来源语义

家长提供的新信息不能默认自动成为诊断。

流程：

`Guardian response → 有权限教师判断 → 必要时 Observation/Evidence/Case/Action`

如果进入 Case Evidence，需要明确知道来源是 guardian communication；长期塞进 `other` 会丢失语义。

优先评估：
- `case_evidence.source_type += guardian_report`
- 加 source communication reference。

Observation 当前规划较晚，因此不应把家校 V1 路线强依赖 V1.5 Observation。

**Decision：ACCEPT 显式来源语义。**

---

## 12. ACCEPT｜家庭配合不是 Case Action

Guardian 不是 organization membership。

家庭配合要求属于 communication snapshot，不允许把家长塞进 `case_actions.assigned_membership_id`。

只有机构员工需要执行的后续动作才分配 membership。

**Decision：REJECT guardian-as-assignee。**

---

## 13. ACCEPT｜Communication Follow-up 最小闭环，不建通用 Todo

仅有 `follow_up_at` 没有负责人/完成事实会形成假闭环。

冻结最小规则：

### 与 Learning Case 直接相关
复用：

`case_actions(action_type = communicate)`

### 不属于某一个 Case 的纯家校跟进
Parent Communication 自身提供轻量 follow-up：
- `follow_up_assigned_membership_id`
- `follow_up_at`
- `follow_up_status`（pending/done/cancelled 或等价）
- `follow_up_completed_at`

不建立通用 `staff_tasks` / 第二套 Todo 系统。

**Decision：ACCEPT A+B；REJECT generic Todo now。**

---

## 14. ACCEPT｜Reports 继续承载 Stage Review

**不新增 `stage_reviews` 表。**

现有 reports 已有正确基础：period、source_cutoff、template/content schema version、content_snapshot、draft/finalized。

建议增强：
- `report_type`
- `version`
- `finalized_by_membership_id`
- `finalized_at`
- correction/supersede link/event。

Subject vs comprehensive 由 report type + optional subject context 表达。

Finalized Report 不等于已告知家长；真正沟通仍需要 Parent Communication。

**Decision：ACCEPT。**

---

## 15. ACCEPT｜Finalized snapshot 的确认/纠错必须受控

至少需要领域 API/command 语义：
- `finalize_parent_communication`
- `correct_parent_communication`
- `finalize_report`
- `correct_report` / `supersede_report`

是否最终拆成四个 DB Functions 在 Commands design 决定，但 ViewModel 不能任意改 status 覆盖历史。

**Decision：ACCEPT。**

---

## 16. DERIVE｜周度跟进

旧问题进度、新问题、本周动作、验证结果、下周重点优先从 Lesson/Case/Evidence/Assessment/Action 派生。

可以让教师补一条真正有价值的周度综合 judgment，但不建立强制 `weekly_tracking` 平行表。

**Decision：DERIVE。**

---

## 17. DERIVE｜顽固 / 长期问题

由持续时间、failed/partial assessment、多轮 intervention、reopen 等事实派生。

**不建 `stubborn_cases`。**

**Decision：DERIVE。**

---

## 18. DERIVE｜机构治理异常

Orphan、长期 overdue、长期 pending verification、stale new Case、handoff remaining、duplicate candidate、附件不一致等优先由安全 query/view/function 派生。

只有未来真的需要“异常工单 lifecycle”时才单独设计 Governance Case。

**Decision：DERIVE。**

---

## 19. ACCEPT｜Student inactive/archive 必须先 reconciliation

不能裸执行：

`students.status = inactive`

因为可能留下 active Cases、pending Actions、Today 永久 overdue、无效 assignments。

受控工作流至少：
1. 结束/调整 enrollment；
2. 处理 active staff/teacher assignments；
3. 逐 active Case 决定合法处置；
4. pending Action 合理完成/取消/替换为未来 review；
5. **inactive 不自动 closed Case**；
6. 写 reason + audit；
7. 再更新 Student lifecycle state。

Restart：恢复/新增 enrollment 与 assignments，继续同一 Student/Subject Profile 历史。

Commands review 评估：
- `deactivate_student`
- `archive_student`

**Decision：ACCEPT domain workflow。**

---

## 20. ACCEPT｜Concurrency / Draft 语义

继续保留：
- version / expected_version；
- operation_id；
- append-only UUID idempotency；
- encrypted device-local draft；
- explicit conflict UX。

不做：
- last-write-wins；
- CRDT；
- offline-first；
- 本地完整学生数据库。

**Decision：维持并强化 Foundation。**

---

## 21. P0 PENDING SPIKE｜Auth identity portability

当前 Foundation 的 `profiles.id → auth.users(id)` 偏 Supabase UUID 心智；CloudBase PG 的 Auth ID 类型并不相同。

Phase 0B.0 在任何正式 business migration 前必须比较：
- provider-specific auth PK；
- business Profile UUID + `auth_subject_id text`；
- text auth subject、弱化 hard FK。

用 RLS、provisioning、EXPLAIN、migration/restore 证据决定。

**Decision：PENDING CLOUD/AUTH SPIKE；正式 migrations 的 P0 Gate。**

---

## 22. P0 PENDING SPIKE｜Revoked Session Security

安全不变量不变：

> signOut / credential reset / disabled 后，旧 access token 不能继续读取学生数据。

Supabase reference 方案使用 JWT session_id + auth.sessions live-session helper；CloudBase 是否能达到等价保证必须在 Windows/Android + old-token + RLS/API 实测。

不能为了大陆免费节点降低这一基线。

**Decision：PENDING CLOUD/AUTH SPIKE；正式 migrations 的 P0 Gate。**

---

## 23. REJECT｜Realtime 作为业务正确性基础

Provider 能力不同，但 Foundation 已决定 correctness 不依赖 Realtime。

V1 继续使用：页面进入、保存后、App resume、手动刷新等可靠路径。

Realtime 以后可作为 enhancement，需要单独 ADR/安全测试。

**Decision：REJECT Realtime-as-core。**

---

## 24. Foundation 回写清单

### `PRODUCT.md`
必须吸收：
- 三类 Case Workflow 与领导教学语言；
- teacher subject scope vs assignment；
- **V1 Internal Pilot 最小家校闭环，独立家校/报告工作台 V1.1**；
- Stage Review = 自动事实 + 人工确认；
- 机构治理异常不做伪 KPI；
- cloud/provider gate。

### `DATA_MODEL.md`
必须吸收：
- `membership_subject_scopes` + `scope_kind teaching/leadership`；
- Student Subject Profile positioning/strengths/version；
- Parent Communication draft/finalized/multi-recipient/follow-up；
- Report finalize/version/correction；
- guardian-report Evidence source；
- identity portability P0 注记；
- derived governance anomalies。

### `COMMANDS_AND_INVARIANTS.md`
必须评估/吸收：
- `start_lesson`；
- `revoke_teacher_subject_scope_and_handoff`；
- student deactivate/archive reconciliation；
- finalize/correct Parent Communication；
- finalize/correct Report；
- 新 scope 与现有 handoff/assignment/Case owner 不变量。

### `AUTH_AND_PERMISSIONS.md`
必须吸收：
- role / subject scope / student assignment 三层；
- subject lead 的 leadership scope；
- teacher teaching scope 不授予全学科学生；
- **任何人追加 Intervention/Assessment 等实际教学事实，都必须同时具备 teacher capability + teaching scope + 对应 student/lesson relationship；leadership/admin 权限本身不能伪造授课事实**；
- Advisor family/report 权限边界；
- provider identity/live-session 实现仍受 P0 Spike gate。

---

## 25. 进入 Phase 0B 前 Gate

Phase 0A.6 内部必须先：
1. Product Completeness Audit 无内部 P1 blocker；
2. ACCEPT 项与各事实源一致；
3. Foundation 核心文档完成机械回写；
4. P0 cloud/auth 未验证项明确标为 **Phase 0B.0 pre-migration hard gates**；
5. Initial Diagnosis Snapshot 保持明确的 deferred validation，不暗中建表；
6. Communication follow-up 不产生第二套 Todo；
7. 最终 PR Head CI success；
8. 独立终审通过。

随后路线：

```text
Phase 0A.6 merge
→ Phase 0B.0 Cloud/Auth Compatibility Spike（虚构数据）
→ 解决 Auth ID + revoked-session P0
→ Cloud Provider Gate
→ Phase 0B.1 正式 Auth/Membership/RLS/migrations Vertical Slice
```
