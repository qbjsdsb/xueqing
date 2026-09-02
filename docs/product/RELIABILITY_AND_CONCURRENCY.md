# 可靠性与并发语义｜Reliability & Concurrency

> Phase 0A.6 事实源。目标：网络/并发/进程失败时不丢用户输入、不重复副作用、不 silent overwrite、不留下业务半状态。

## 1. Cloud truth vs local draft

云数据库是唯一正式事实源。只有服务端 committed 的 Case/Evidence/Intervention/Assessment/Action/Lesson/finalized snapshot 才进入 timeline/Today/派生统计。

本地 Draft：
- user/org/entity/operation scoped；
- 加密；
- TTL；
- sync success 后删除；
- account switch 不串数据；
- 绝不作为正式业务查询来源。

## 2. 保存状态

至少区分：未保存 / 保存中 / 已保存 / 保存失败 / 已保留草稿 / version conflict / 无网络 / timeout unknown result。

服务端未确认不能显示“已保存”。

## 3. Simple append idempotency

Evidence 等简单 append：客户端预生成 UUID；timeout 重试复用同一 UUID。

### Quick Capture 特别规则
Quick Capture/new Case 虽然可以是单条 insert，但它是**教学 Case 创建**：
- 提交云端前重新执行完整 Teaching Fact Gate；
- Profile inactive/archived → 拒绝；
- Advisor-only/management-only → 拒绝；
- 本地 draft 可以保留，但不能因为“只是 new”绕过权限同步。

## 4. High-risk command contract

统一：

```text
operation_id
+ expected aggregate versions
+ lock/revalidate current relation set
+ authorization/entity-state validation
+ one logical business DB transaction
+ stage all mutations
+ final invariant validation
+ operation-bound events/audit
+ operation receipt/equivalent result
+ atomic commit
```

正常业务只允许：完整旧状态 或 完整新状态。

## 5. Exactly-once semantics

### Operation result
逻辑唯一：

```text
(organization_id, operation_id)
```

已 committed 的同 operation 重试必须返回原结果，不能再次执行 side effects。

### Lifecycle events
高风险 command 产生的 event 必须携带：
- `operation_id`
- stable `operation_event_key`

逻辑唯一：

```text
(org, operation_id, operation_event_key)
```

示例：
- `case:<id>:reopened`
- `profile:<id>:tracking_suspended`
- `profile:<id>:tracking_resumed`
- `student:<id>:merged`

### Audit
高风险 command audit 必须同样带：
- `operation_id`
- `operation_audit_key`

逻辑唯一：

```text
(org, operation_id, operation_audit_key)
```

因此 commit 成功后同 operation 重试不会多一条 event/audit。

物理 receipt/index 形式留 Phase 0B migration，但逻辑保证已经冻结。

## 6. Timeout unknown result

场景：服务器已 COMMIT，response 丢失。

客户端：
1. 保留原 operation_id；
2. 查询 operation result；
3. committed → 接受原 snapshot；
4. 明确未 commit → 同 operation_id 重试；
5. unknown → 继续查询/提示；
6. 不创建新 operation_id；
7. 不重放多条普通 CRUD。

## 7. Optimistic concurrency

关键 aggregate：
- Student；
- Student Subject Profile；
- Learning Case；
- Lesson；
- editable Communication/Report Draft。

均使用 `version + expected_version`。

### Student multi-Profile command
仅有 Student version 不够。

Command preview/input 同时包含：
- Student expected_version；
- affected Profile expected versions；
- affected Case expected versions；
- expected current assignment/owner/Action IDs。

事务开始按 deterministic ID 顺序锁定并重读这些 rows；任何 drift → stale_plan/version_conflict，整体 rollback。

目标 membership/scope 也必须锁定或至少在事务内重验证其 active 状态。

## 8. Lifecycle atomicity

### Reactivate Profile
事务内部 stage：assignment → owner → primary Actions → resumed events → Profile active；commit 前验证最终 active invariants。

### Deactivate Profile
stage：Action cancel/done → assignment end → owner end → suspended events → Profile inactive；commit 前验证最终 inactive invariants。

中间 staging 对其他 Session 不可见。

### Student multi-Profile
任一 Profile reconciliation 失败 → 整个 Student command rollback。

### Archived Profile 与 `reactivate_student`
**不允许隐式/跨事务 orchestration。**

`reactivate_student` 只能选择已经是 `inactive` 的 Profiles。若某 selected Profile archived：
- command 立即拒绝；
- 用户先显式执行独立 `unarchive_student_subject_profile`；
- 该 command committed 后 Profile 合法停在 inactive；
- 再发起新的 Student reactivate intent。

如果后续 reactivate 失败，先前显式 unarchive 留下 inactive 是合法状态，不是 reactivate partial commit。

如果未来希望“一键从 archived 全部恢复”，必须另写 Saga/ADR（durable operation state + compensation + idempotency）；V1 不提供。

## 9. `reopen_case` reliability

唯一：`closed → confirmed`。

一个 transaction 同时：
- clear current closed/stable snapshot timestamps；
- reopened_count +1；
- owner；
- exactly one primary Action；
- recurrence evidence reference；
- `case_reopened` operation-bound event；
- audit；
- Case version +1。

任一步失败 rollback。

同 operation_id 重试不能重复 reopened_count/event/audit/Action。

Profile inactive/archived 时 command 前置拒绝。

## 10. Quick Capture failure/retry

- local draft 可在无网络保留；
- sync 时重新验证 live session/membership/teacher/scope/Profile/relationship；
- Gate 失败保留 draft 并解释原因，不自动创建 new Case；
- 已 commit但 response lost：按预生成 Case UUID 查询，不再建第二条。

## 11. Student merge reliability

V1 merge 以 `STUDENT_MERGE_POLICY.md` 的 safe matrix 为准。

- source/target Student expected_version；
- lock source/target + affected rows；
- 任一 BLOCK conflict → mutation 前拒绝；
- safe reparent/dedupe + merge record + source merged 同事务；
- finalized historical provenance 不改写；
- response lost → operation_id 查询；
- same operation 重试不重复 reparent/event/audit。

## 12. Lesson reliability

Lesson 1–2 小时期间 Evidence/Intervention/Assessment 可逐项可靠保存；`complete_lesson` 只收口剩余 Case/Action/Lesson state，不重复已成功 facts。

小班 whole-lesson atomic vs per-student reconcile 留 Phase 0B.0 Spike；无论哪种都不能虚假 completed。

## 13. Conflict UX

Version conflict：
- 不清空输入；
- 显示最新云端变化；
- 允许查看/比较/重新应用/放弃；
- 高风险 command 需重新确认。

禁止 last-write-wins。

## 14. App crash / process kill

重启：
1. secure local draft；
2. 查询 entity/operation 是否 committed；
3. 已 commit 清 draft；
4. 未 commit 恢复输入；
5. unknown 先查，不盲目写。

## 15. Auth failure

Revoked/refresh failure：立即停止学生业务；local draft 只能安全暂存。重新认证后重新验证 org/membership/scope/assignment/Profile，旧 draft 不自动跨权限提交。

## 16. Error taxonomy

至少：network_unavailable / timeout_unknown_result / unauthenticated / permission_denied / version_conflict / stale_plan / validation_failed / operation_already_completed / transaction_rolled_back / integrity_anomaly / storage_failed / server_unavailable / unknown。

## 17. Failure Injection Matrix

至少测试：

### lifecycle
- assignment/owner/Action/status/event/audit 各 staging 点失败；
- final invariant validation failure；
- commit success response lost。

### concurrency
- Student version stale；
- 第 N 个 Profile version stale；
- Case version stale；
- preview 后 assignment set 变化；
- target teacher scope 被撤。

### reopen
- recurrence evidence missing；
- inactive Profile；
- Action staging failure；
- event/audit failure；
- duplicate operation。

### Quick Capture
- Advisor-only；
- Profile inactive/archived；
- old assignment only；
- response lost。

### Student reactivate
- selected Profile archived → reject；
- 第 N 个 inactive Profile reconcile failure → whole transaction rollback。

### merge
- same-subject dual Profile；
- dual active Lead；
- conflicting Enrollment；
- current assignee invalid；
- response lost；
- repeated operation。

## 18. Offline boundary

V1 online-first；不做完整离线学生库、CRDT 或长期多实体离线 merge。
