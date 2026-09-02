# 可靠性与并发语义｜Reliability & Concurrency

> Phase 0A.6 事实源。目标：网络/并发/进程失败时不丢用户输入、不重复副作用、不 silent overwrite、不留下业务半状态。

## 1. Cloud truth vs local draft

云数据库是唯一正式事实源。只有服务端 committed 的 Case/Evidence/Intervention/Assessment/Action/Lesson/finalized snapshot 才进入 timeline/Today/派生统计。

本地 Draft：user/org/entity/operation scoped、加密、TTL、sync success 后删除，绝不作为正式业务查询来源。Gate 或 authority 失败时可安全暂存，但不能因 Draft 是 new 就绕过权限。

## 2. 保存状态

至少区分：未保存 / 保存中 / 已保存 / 保存失败 / 已保留草稿 / version conflict / 无网络 / timeout unknown result。服务端未确认不能显示“已保存”。

## 3. Simple append idempotency

Evidence 等简单 append 使用客户端预生成 UUID；timeout 重试复用同一 UUID。Quick Capture/new Case 仍是 teaching Case creation，每次同步重新验证完整 Gate。

## 4. High-risk command contract

统一：

```text
operation_id
+ expected aggregate versions
+ lock/re-read current relation set
+ authorization/entity-state validation
+ one logical business DB transaction
+ stage all mutations
+ final invariant validation
+ operation-bound events/audit
+ operation receipt/equivalent result
+ atomic commit
```

正常业务只允许完整旧状态或完整新状态。

## 5. Teaching Fact Gate / Lesson authorization

V1 所有 teaching writes（Evidence、Intervention、Assessment、Lesson teacher behavior、Quick Capture/new Case）必须：

```text
live session
+ active membership
+ teacher capability
+ active teaching scope
+ target Student Subject Profile = active
+ legal active Student Teacher Assignment
+ operation-specific permission
```

Lesson authorization 由两个独立 gate（Actor Gate / Per-Student Participant Gate）组成：执行 `start_lesson` 的 actor 必须有 live active authenticated identity、valid active session、active membership、teacher capability、matching teaching Subject Scope、operation permission；对每个 Student participant，server 另须验证 Student current/legal、Subject Profile active、actor 与该 Student+Subject 的 legal active Student Teacher Assignment，以及 organization/subject/Lesson context 一致。live identity/session 不是 Student participant 的属性。

`lesson_students` 只表示实际参与 business fact，不是 authorization grant、temporary permission、capability、scope 或 Student Teacher Assignment；self-added participant 不能自我授权。time-bounded collaborator assignment 是 V1 临时代课唯一方式，且有效期内仍需完整 Gate。assignment/membership/scope/Profile/Session 中途失效时后续 teaching writes 与 ordinary complete fail closed；治理 actor 仅可 controlled cancel/cleanup，不得继续制造 teaching facts。


## 6. Exactly-once semantics

逻辑唯一：
- operation result：(`organization_id`, `operation_id`)；
- high-risk event：(`organization_id`, `operation_id`, `operation_event_key`)；
- high-risk audit：(`organization_id`, `operation_id`, `operation_audit_key`)。

已 committed 的同 operation 重试返回原结果，不能重复 Action、event、audit、version increment、reparent、merge record。

## 7. Student root version / child concurrency

`students.version` 只表示 Student root/current canonical/lifecycle snapshot，不是 child global counter。

| Successful command | Student.version |
| --- | --- |
| deactivate_student | +1 exactly once |
| archive_student | +1 exactly once |
| unarchive_student | +1 exactly once |
| reactivate_student | +1 exactly once |
| merge_students | source +1 exactly once；target +1 exactly once |

普通 Evidence/Intervention/Assessment append、普通 Case transition、普通 Assignment current-state change不机械递增 Student.version。Source-only Profile safe reparent 使 Profile.version +1 exactly once；Case 仅在 current mutable snapshot 真正改变时更新 Case.version。Duplicate operation 不再次递增。

Student multi-Profile command 必须绑定 Student/Profile/Case expected versions 与 current assignment/owner/Action snapshot。按 deterministic ID 顺序 lock/re-read；drift → stale_plan/version_conflict + whole rollback。

## 8. Merge preview binding / stale plan

`generate_merge_preview(source,target)` 必须由 server/domain logic 生成完整 merge-relevant snapshot。至少包含并绑定：
- source/target IDs + root versions；
- affected Profile IDs/versions/subject identity；
- merge-relevant Case IDs/versions；
- Enrollment IDs + grade/campus/term/interval；
- Teacher Assignment IDs/roles/status/interval；
- Staff current responsibility set；
- Case owners；
- current primary/current Action IDs、assignee、status；
- target membership/scope authority；
- complete BLOCK matrix。

允许 server-generated opaque `merge_plan_token`、完整 expected snapshot/values 或 server-generated deterministic fingerprint；不新增 `merge_plans` 业务表，client 不得自己 hash 少量 rows。

Execute 必须 lock/re-read source/target/affected rows，server regenerate current snapshot，与 confirmed plan compare。Assignment/owner/Action/Enrollment/Profile structure/staff responsibility/authority/lifecycle 等 merge-relevant drift → `stale_plan/version_conflict`、whole rollback、要求重新 preview；不能重新 inventory 后静默接受 Plan B。

Existing Case 的普通 append-only Evidence/Intervention history 若不改变 current merge decision、BLOCK matrix、canonical Profile/Case relationship，不单独 stale；影响 current snapshot 的事实不享受例外。

V1 unresolved mutable Parent Communication/Report Draft、source/target `in_progress` Lesson → BLOCK；先 finalize/cancel/discard/resolve Draft，complete/controlled cancel Lesson，再 preview。

## 9. `reopen_case` server-authoritative recurrence

`reopen_case` 只能表达：

```text
closed → post-close recurrence fact → teacher-confirmed recurrence Evidence → reopen_case → confirmed
```

同一 logical DB transaction 内 lock/re-read target Case，确认 current status closed + expected_case_version；server 从 immutable committed lifecycle history 自动解析该 Case 最新 **committed** `case_closed` event。client 不得提供 close boundary/previous_close_id。

server 随后按稳定 ID 顺序 lock/re-read 每条 selected recurrence Evidence，确认其仍 committed/finalized、legally usable、属于 target Case，expected Evidence version/freshness 未漂移，且：

`evidence.observed_at > latest committed case_closed.occurred_at`

只看 observed_at，不看 created_at；late entry 合法。old Evidence 不能单独 reopen；新 Evidence 可引用旧 Evidence，但自己的 observed_at 必须 post-close。source_type 不设 recurrence 白名单，source_type 本身不证明复发。

同一 transaction 还要验证 active service、full Teaching Fact Gate、owner、new pending primary Action，stage `closed→confirmed`、clear current closed/stable timestamps、reopened_count +1、写 `case_reopened` metadata（server-resolved latest committed close event + recurrence IDs）、operation-bound audit、Case.version +1、final invariants、atomic commit。无 latest committed close event、任何合同失败、Evidence reparent/invalidation 或 authority/version/freshness drift → reject/rollback；同一 operation_id retry 返回原 committed result，不重复副作用。

### 9.1 Committed Evidence immutable history

Committed/finalized Evidence 是 append-only historical fact。Draft 可以在本地暂存，但一旦 committed，不得普通修改或删除 `case_id`、`observed_at`、`created_at`、author/source attribution、provenance 或其他 recurrence-relevant 字段；错误必须用现有 Evidence/Event 模型的 correction record、superseding Evidence 或 explicit correction/invalidation event 表达，并保留原 provenance。

`reopen_case` 在同一 logical DB transaction 内按稳定 ID 顺序 lock/re-read target Case、latest committed `case_closed` event 与每条 selected recurrence Evidence，重新验证 committed/legal usability、target Case relationship、expected versions/freshness token 与 `evidence.observed_at > latest committed case_closed.occurred_at`。任一 reparent、invalidation、version/freshness drift 或其他前置条件失败，都返回明确 domain conflict / `stale_plan/version_conflict` 并 whole rollback；同一 `operation_id` retry 返回原 committed result，不重复 event/audit/Action/version 副作用。物理 revision/version 方案留待 Phase 0B.0 provider Spike，不新增第二套 Evidence 模型。

## 10. Lesson authority revoke / controlled cancel

Lesson 开始时合法不代表永久合法。若 assignment、scope、membership、Profile 或 Session 在 `in_progress` 期间失效：
- 后续 Evidence/Intervention/Assessment/Quick Capture/new Case 拒绝；
- ordinary `complete_lesson` 拒绝；
- 已 committed 合法历史事实保留；
- governance actor 可 controlled cancel stale Lesson，写 reason/event/audit；
- cancel 不新增 teaching fact、不新增 Case、不假装原 teacher 完成专业判断；
- V1 无自动 Lesson handoff；新 teacher 先 cancel old Lesson，再以自身合法 assignment 开 new Lesson。

## 11. Timeout unknown result / crash

response lost：
1. 保留原 operation_id/append UUID；
2. 查询 operation result/entity；
3. committed → 接受原 snapshot；
4. 明确 rollback → 同 ID 安全重试；
5. unknown → 继续查询/提示；
6. 不创建新 operation_id，不重放多条 CRUD。

App crash 先恢复 encrypted local Draft，再查 commit/operation；已 commit 清 Draft，未 commit 恢复输入。

## 12. Conflict UX

Version/stale conflict 不清空输入；显示最新变化，允许比较/重新应用/放弃；高风险 command 必须重新确认。禁止 last-write-wins。

## 13. Auth / offline boundary

Revoked/refresh failure 立即停止学生业务；重新认证后重新验证 org/membership/scope/assignment/Profile，旧 Draft 不自动跨权限提交。V1 online-first，不做完整离线学生库、CRDT 或多实体离线 merge。

## 14. Error taxonomy

至少：network_unavailable / timeout_unknown_result / unauthenticated / permission_denied / version_conflict / stale_plan / validation_failed / operation_already_completed / transaction_rolled_back / integrity_anomaly / storage_failed / server_unavailable / unknown。

## 15. Failure Injection Matrix

### Reopen
- old Evidence observed_at ≤ latest close → reject；
- new recurrence observed_at > latest close → allow if full Gate/owner/Action pass；
- late-recorded Evidence → allow by observed_at；
- close A → reopen → close B → boundary automatically close B；
- client-supplied previous close/recurrence boolean → ignore/reject；
- missing committed case_closed event → integrity anomaly/reject；
- duplicate operation → no second count/event/audit/Action/version。

### Lesson
- scope but no Student Teacher Assignment → start/Quick Capture reject；
- self-added lesson_students participant → no authorization；
- valid time-bounded collaborator assignment → allow while active；
- assignment revoked mid-Lesson → later teaching writes/ordinary complete reject；
- stale in-progress → governance controlled cancel only；
- new teacher cannot finalize old actor Lesson；
- cancel cannot create teaching facts or bypass Case invariant。

### Student / Merge
- stale Student/Profile/Case version → whole rollback；
- Assignment/owner/Action/Enrollment/authority/Profile structure changed after preview → stale_plan/BLOCK；
- new same-subject Profile → stale/BLOCK；
- ordinary non-conflicting append Evidence → no automatic stale；
- mutable Draft → BLOCK；
- in-progress Lesson → BLOCK；
- safe Profile reparent → Profile.version invalidated/+1；
- response lost same operation_id → original result, no duplicate root/Profile/reparent/event/audit/record；
- merged source → all current business operations reject。

## 16. Offline boundary

V1 online-first；不做完整离线学生库、CRDT 或长期多实体离线 merge。