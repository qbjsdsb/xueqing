# 业务命令、事务与不变量

> RLS 解决“谁能访问”，领域命令解决“这次修改是否完整、合法、可重试”。ViewModel 不得用多次普通 CRUD 拼接高风险状态。

## 1. 写入分层

### 1.1 简单事实追加
在 RLS/command policy 保护下可由 Repository → Data API：
- 合法 Evidence；
- 通过完整 Teaching Fact Gate 的本人 Intervention / Assessment；
- 允许的普通 note/event；
- 单条附件 metadata；
- Parent Communication / Report draft；
- **Quick Capture new Case，但它仍是教学 Case，必须通过完整 Teaching Fact Gate。**

简单 append 使用客户端预生成 UUID，重试复用同一 UUID。

### 1.2 不变量敏感命令
至少包括：
- identity/membership：`provision_member`、`complete_member_onboarding`、`reset_member_credential`、`disable_membership_and_handoff`；
- assignment/service：`reassign_teacher`、`revoke_teacher_subject_scope_and_handoff`、Student/Subject Profile deactivate/archive/unarchive/reactivate；
- Case：`confirm_case`、`transition_case`、`reopen_case`、`replace_primary_case_action`、`complete_case_action`；
- Lesson：`start_lesson`、`complete_lesson`；
- Lesson governance cleanup：`controlled_cancel_lesson`；
- governance：`merge_students`；
- snapshots：finalize/correct Parent Communication、Report。

具体是 DB Function 还是可信服务端留 Phase 0B；领域 command 语义现在冻结。

---

## 2. 生命周期命令统一事务契约

### 2.1 正常结果只有完整旧状态或完整新状态

对 Student / Subject Profile / assignment / owner / primary Action / lifecycle event/audit 的业务数据库变更：

> **同一 command 内全部成功一起 commit；任一失败全部 rollback。**

事务内部 staging 可以临时构造目标状态，但：
- 不对其他 Session 可见；
- 不分多次客户端 API commit；
- 不能被普通 RLS 查询观察到；
- rollback 后完全消失。

### 2.2 `operation_id + expected versions + locks`

每个高风险 command 至少：
- `operation_id`：用户意图幂等键；
- 目标 aggregate `expected_version`；
- 必要子聚合版本快照；
- deterministic row locks；
- final invariant validation；
- event/audit；
- atomic commit。

### 2.3 Student root version / child concurrency / merge-plan binding

`students.version` 的职责被严格限定为 Student root/current canonical/lifecycle snapshot 的 optimistic-concurrency token。它不是 Student 下所有 child row 的全局版本号。

成功的 Student root/lifecycle mutation 版本矩阵：

| Command | 成功 commit 的 Student.version |
| --- | --- |
| `deactivate_student` | +1 exactly once |
| `archive_student` | +1 exactly once |
| `unarchive_student` | +1 exactly once |
| `reactivate_student` | +1 exactly once |
| `merge_students` | source +1 exactly once；target +1 exactly once |

同一 `operation_id` 的重试返回第一次 committed result，不再次递增任何 root version。

普通 child mutation 不机械递增 `students.version`，包括普通 Evidence append、普通 Case transition、Assessment append、普通 Assignment current-state change。它们分别由 Evidence/Case/Profile/Assignment 自身的 current snapshot、version 或 locked current-relation predicate 承担并发检测。只有 Student root/current canonical/lifecycle snapshot 真正改变时才递增 Student.version。

如果 Student merge 将 source-only Profile safe reparent 到 target，该 Profile 的当前 aggregate identity/reference 已改变，因此 `Profile.version +1 exactly once`。若 merge 没有改变 Case 的 status、owner、Action 或其他 current mutable snapshot，不能机械递增每个 Case.version；如果 merge 确实修改了某个 Case/owner/assignee/current relationship，则只更新受影响 aggregate 的相应 version/token。

Student multi-Profile command 仍必须绑定并验证：
- `student_expected_version`；
- 每个受影响 Profile 的 `expected_profile_version`；
- 每个实际改变的 formal Case 的 `expected_case_version`；
- current assignment IDs/roles/active intervals、Case owner IDs、current primary Action IDs/assignees/status；
- command 所需的 target membership/scope current state。

事务按稳定 ID 顺序 lock/re-read；上述 merge-relevant current snapshot 任一发生 drift → `stale_plan/version_conflict`，整体 rollback。

#### Merge preview binding

`generate_merge_preview(source,target)` 由 server/domain logic 从完整 merge-relevant snapshot 生成。客户端只能请求、查看和确认 server 返回的 plan，不能自行决定 inventory，也不能自行 hash 少量 rows 伪造 plan。

Preview 至少绑定：
- source/target Student IDs + 两个 root versions；
- affected Profile IDs、Profile versions、subject identity；
- merge-relevant Case IDs + Case versions；
- Enrollment IDs 与 grade/campus/term/interval；
- Teacher Assignment IDs、roles、active status/interval；
- Staff current responsibility set；
- Case owner IDs；
- current primary Action IDs、assignee、status；
- target membership/scope validity；
- complete BLOCK matrix result。

绑定形式可由未来 API 选择 server-generated opaque `merge_plan_token`、完整 expected snapshot/values 或 server-generated deterministic plan fingerprint；具体物理 API 留 Phase 0B，不新增 `merge_plans` 业务表。无论采用哪种形式，binding 都必须由 server 根据完整 merge-relevant snapshot 生成。

`merge_students` 执行时必须 lock/re-read source/target 及受影响 Profiles/Cases/current relations，server 重新生成当前 merge-relevant snapshot，并与用户确认的 plan binding 比较。任何会改变 safe/BLOCK decision、canonical relationship、Profile structure、owner、active assignment、primary Action、Enrollment、staff responsibility、target authority 或 Student lifecycle 的 drift 都返回 `stale_plan/version_conflict`，whole rollback，要求重新 preview；不得静默接受新 inventory，也不得自动接受新的 plan。

Append-only、非冲突的历史事实（例如同一现有 Case 的普通 Evidence append 或 Intervention history）若不改变上述 current merge decision、BLOCK matrix、canonical follow-up relationship，且自然跟随同一 canonical Profile/Case，则不单独造成 stale；server 仍须保留并重新验证其归属。任何影响 current snapshot 的追加都属于 merge-relevant drift。

### 2.4 exactly-once command side effects

高风险 command 逻辑上必须有唯一 operation result：

`(organization_id, operation_id)` 唯一。

每个由 command 产生的 lifecycle event/audit side effect 都必须携带同一 `operation_id`，并有稳定 `operation_event_key / operation_audit_key`。

逻辑唯一键：

```text
(organization_id, operation_id, operation_event_key)
(organization_id, operation_id, operation_audit_key)
```

重复同 operation_id：
- 不重复 event；
- 不重复 audit；
- 不重复 Action/assignment/merge/finalize；
- 返回原 committed result。

物理 receipt 表/索引形式由 Phase 0B migration 决定，但 exactly-once 语义不得改变。

### 2.5 timeout unknown result

服务端可能已经 commit 但 response 丢失。

客户端必须：
1. 保留原 operation_id；
2. 查询 operation result；
3. 已 commit → 接受原 committed snapshot；
4. 明确未 commit/rollback → 同 operation_id 安全重试；
5. 不生成新 operation_id；
6. 不用一串 CRUD 猜测补齐。

---

## 3. Provider-neutral Auth gate

Phase 0A.6 只冻结安全目标；Production provider 尚未冻结。

任何正式 business migration 前 Phase 0B.0 必须证明：
1. Auth Identity Portability；
2. Revoked Session / Old Token Security。

Supabase `auth.uid()/session_id/auth.sessions` 只是 reference implementation。

---

## 4. Credential / membership

Auth Admin 与业务 DB 可能不同事务域，采用 fail-closed。

### `provision_member`
- live org_admin；
- 创建/恢复 Auth identity；
- membership=`onboarding`；
- roles/scopes 可预配置但无学生业务权限；
- 临时密码只显示一次，不持久化；
- audit 不含 credential。

### `complete_member_onboarding`
- membership=onboarding + 未过期；
- 更新 credential；
- revoke old sessions；
- revoke 成功后 membership→active；
- 强制重新登录。

### `reset_member_credential`
先 membership→onboarding 切断业务权限，再更新 credential/revoke sessions。外部步骤失败时保持 fail-closed。

---

## 5. Teaching Fact Gate｜唯一硬定义

任何人要作为实际教学 actor 创建：
- teaching Evidence；
- Intervention；
- Assessment；
- Lesson teacher 行为；
- **Quick Capture / new Learning Case**；

必须同时满足：

```text
live session
+ active membership
+ teacher capability
+ matching active teaching subject scope
+ target Student Subject Profile = active
+ legal active Student Teacher Assignment
+ operation-specific permission
```

管理身份不能 bypass。

Advisor 如果只有 staff assignment：
- 可以记录 Parent Communication；
- 可以记录被允许的 Observation（该功能上线后）；
- **不能直接创建 teaching Case / Quick Capture。**

Profile inactive/archived 时 new Case 创建在服务端前置拒绝；本地未同步 draft 只能保留输入，恢复网络/服务后重新校验 Gate。

---

## 6. Case lifecycle

唯一状态：

```text
new → confirmed → intervening → pending_verification → stable → closed
```

任何使 Case 进入 `closed` 的合法 close command，必须在同一事务写入 immutable `case_closed` lifecycle event；close transaction rollback 时不得留下该 event。该 committed event 的 `occurred_at` 是后续 recurrence 的 server-authoritative boundary。

`reopen` 是 command/event，不是状态。

`Assessment passed ≠ stable ≠ closed`。

### Active Profile
formal open Case（confirmed/intervening/pending_verification/stable）必须：
- 合法 owner；
- 恰好一个 pending primary Action。

### inactive/archived Profile
unresolved formal Case 保留真实 status，但：
- tracking suspended；
- 可以无 current owner/primary Action；
- 不进普通 Today；
- 不产生 teaching facts/new Lesson/new teaching Case。

---

## 7. `confirm_case`

原子检查：new + expected_version、Profile active、actor permission、合法 owner、最小 Evidence、taxonomy 一致、一个 pending primary Action；写 event/audit/version 后一次 commit。

---

## 8. `reopen_case`｜唯一语义

### 8.1 适用范围

只适用于：一个已经真正 `closed` 的 Case，在最近一次关闭之后出现新的、足以重新正式跟进的真实事实。

唯一业务序列：

```text
closed → post-close recurrence fact → teacher-confirmed recurrence Evidence → reopen_case → confirmed
```

`reopen` 是 command/event，不是第七个 Case status；不是 Profile resume，也不是重新选择旧 Evidence 后重开。

### 8.2 唯一目标状态

```text
closed --reopen_case--> confirmed
```

复发已经达到正式跟进条件，但 command 本身不虚构新的 Intervention。后续实际干预再进入 `intervening`。

### 8.3 Recurrence Evidence contract

`reopen_case` 的客户端输入只能包括：
- recurrence Evidence IDs；
- `expected_case_version`；
- expected recurrence Evidence versions 或 server-issued opaque freshness token；
- `operation_id`；
- proposed/legal owner；
- 一个新的 pending primary Action。

客户端不得提交 `previous_close_id`、`latest_close_id` 或 client-owned recurrence boolean 来决定边界。最近一次 close 必须由 server 在事务内自己解析。

每条 recurrence Evidence 必须：
1. 是目标 Case 的合法 Evidence；
2. 具有非空 `observed_at`，表示事实实际发生/被观察到的业务时间；
3. `evidence.observed_at > latest_case_closed_event.occurred_at`；
4. 事实由有权教师确认足以重新达到正式跟进条件。

`created_at` 只表示录入系统的时间，不参与 recurrence 判断。因此事实发生在 close 之后、几天后才补录仍可作为 recurrence。Evidence 的 `source_type` 不设 recurrence 白名单；exam/homework/essay/classwork/quiz/observation/guardian_report/other 等任何合法来源都必须通过同一 Evidence 合法性和专业判断门槛，source_type 本身不自动证明复发。

旧 Evidence（`observed_at` 早于或等于 close boundary）不能单独作为 recurrence。它可以被新 Evidence 引用或作为复查线索，但新 Evidence 自身的 observed_at 必须晚于最近一次 close。

Committed/finalized Evidence 是 append-only historical fact：commit 后不得普通修改 `case_id`、`observed_at`、`created_at`、author/source attribution、provenance 或其他 recurrence-relevant 字段，也不得物理删除。错误必须用 correction record、superseding Evidence 或 explicit correction/invalidation event 表达，并保留原 provenance；Draft 不属于 committed history，也不创建第二套 Evidence 模型。

### 8.4 Server-authoritative previous close and atomic command

事务从头到尾至少执行：

1. live session；
2. active membership；
3. teacher capability；
4. matching active teaching subject scope；
5. target Profile active；
6. legal active Student Teacher Assignment；
7. actor reopen permission；
8. lock/re-read target Case；
9. current Case status 必须为 `closed`；
10. 验证 `expected_case_version`；
11. 在同一事务内从不可变、只追加的 lifecycle history 解析该 Case 最近一次**已提交（latest committed）**的 `case_closed` event；不存在该 event 则拒绝并报告 integrity anomaly；
12. server 按稳定 Evidence ID 顺序 lock/re-read 每条 selected recurrence Evidence，并重新验证其 committed/finalized、legally usable、仍属于 target Case、expected Evidence version 或 server-issued opaque freshness token 未漂移；
13. 若 Evidence 已被 correction/invalidation、删除、reparent 或发生任何 provenance/current-state drift，返回明确 domain conflict / `stale_plan/version_conflict`，整笔 transaction rollback；
14. server 以该 event 作为 recurrence boundary，绝不接受客户端指定的 close ID；
15. 逐条验证 `evidence.observed_at > latest_case_closed.occurred_at`；
16. 验证 recurrence facts 确实支持重新进入正式跟进，不接受客户端自行声明的 recurrence 标记；
17. 验证 legal owner；
18. 验证新的 pending primary Action；
19. stage `closed → confirmed`；
20. current `closed_at → null`；
21. current `stable_at → null`；
22. `reopened_count += 1`；
23. stage owner + exactly one pending primary Action；
24. 写 `case_reopened` lifecycle event，其 metadata 必须引用 server-resolved `latest_previous_close_event_id` 与 recurrence Evidence IDs；
25. 写 operation-bound audit；
26. Case.version +1 exactly once；
27. final invariant validation；
28. 写 operation result 并 atomic commit。

上述步骤必须是一个 logical DB transaction；任何一步失败（包括 Case、latest committed close event、selected Evidence、Profile/owner/assignment/version 任一 drift）whole rollback。若 `operation_id` 已有 committed operation result，retry directly returns the original committed result，不重复 `case_reopened` event、audit、Action 或 version increment。若 `close A → reopen → close B`，server 必须自动选择 close B。

## 9. Subject Profile lifecycle

```text
active --deactivate--> inactive --archive--> archived
active <--reactivate-- inactive <--unarchive-- archived
```

### `deactivate_student_subject_profile`
单事务 staging：收口 pending Actions、结束 active assignments/current owner、写 suspended events、Profile inactive；commit 前验证无 current teaching obligation。

### `archive_student_subject_profile`
仅 inactive→archived；无 active assignment/pending Action/in-progress Lesson；不改 unresolved Case status。

### `unarchive_student_subject_profile`
仅 archived→inactive；不创建 assignment/owner/Action；不恢复教学。

### `reactivate_student_subject_profile`
仅 inactive→active。**同一事务** stage：target assignment、formal open Case owner、primary Actions、resumed events、Profile active。commit 前验证完整 active invariants。

---

## 10. Student lifecycle

`students.version` 是 Student aggregate 乐观并发载体。

```text
active --deactivate_student--> inactive --archive_student--> archived
active <--reactivate_student-- inactive <--unarchive_student-- archived
```

`merged` 是终态。

### `deactivate_student`
- Student active + student_expected_version；
- 锁定 Student + 所有受影响 Profiles/Cases/current relations；
- 每个 active Profile 执行等价 staged deactivate；
- enrollment/staff assignment 同事务收口；
- Student staged inactive；
- 任一学科失败 → 整体 rollback；
- commit 后 Student.version +1 exactly once。

### `archive_student`
仅 inactive→archived；所有 Profiles 必须 inactive/archived；仍 inactive 的 Profiles 在**同一 Student archive transaction** staged archived；无 current obligations；整体 rollback/commit。

### `unarchive_student`
仅 archived→inactive；Profiles 保持 archived；不自动恢复 enrollment/assignment/Action；Student.version +1。

### `reactivate_student`｜不允许跨事务偷做 unarchive

前置：
- Student=`inactive`；
- 所有**本次要恢复的 Subject Profiles 必须在调用前已经是 `inactive`**；
- 任何 selected Profile 如果仍 `archived` → command 拒绝，提示先显式执行独立 `unarchive_student_subject_profile`。

因此 `reactivate_student` **不包含、不编排、不 saga 调用** Profile unarchive。

单一事务：
- student_expected_version + expected_profile_versions + expected_case_versions；
- lock/revalidate 全部 affected rows；
- staged enrollment；
- 对 selected inactive Profiles staged assignment/owner/Actions/Profile active；
- Student staged active；
- final invariant validation；
- event/audit；
- Student.version +1 exactly once；
- commit。

任一 Profile 失败 → 本次 Student reactivate 全部 rollback。

显式的“先 unarchive Profile，再稍后 reactivate Student”是两个**独立用户意图/独立 commands**。如果后者失败，前者留下 Profile=inactive 是合法、可解释的状态，不属于 reactivate partial commit。

---

## 11. Reassign / handoff

`reassign_teacher`、`revoke_teacher_subject_scope_and_handoff` 的业务 DB 变更单事务：锁定 Profile/Case/current assignments/target teacher scope；迁移 owner/Actions；验证 no orphan；写 operation-bound event/audit；commit。

`disable_membership_and_handoff` DB handoff 同理；Auth revoke 作为外部事务域采用 fail-closed，membership disabled 后业务访问已经拒绝。

---

## 12. Lesson

### `start_lesson`

`start_lesson` 是受控 domain command，必须分开验证执行 actor 与每一个 Student participant：

**Actor Gate**
1. live active authenticated identity；
2. valid active session；
3. active membership；
4. teacher capability；
5. matching active teaching Subject Scope；
6. operation-specific permission；
7. 其他现有 Teaching Fact Gate 前置条件。

**Per-Student Participant Gate**
对每一个 participant，server 必须确认：
1. Student 合法且为 current；
2. target Subject Profile active；
3. actor 与 Student+Subject 存在 legal active Student Teacher Assignment；
4. organization/subject/Lesson context 一致；
5. 其他既有 participant preconditions。

live identity/session 只属于 actor，不是 Student participant 的属性。`lesson_students` 只表示 participation business fact，不是 authorization source；已有 participant 不能绕过 assignment、scope、membership 或 Profile gate。只有 Actor Gate 与全部 participant gates 通过，才创建 `in_progress` Lesson + `lesson_students`；任何缺 assignment、scope-only、inactive Profile、cross-org/cross-subject 或 self-added participant → 整个 start 拒绝。

临时代课只通过合法、time-bounded collaborator assignment（`active_from`/`active_to`），有效期间仍需完整 Gate；assignment/membership/scope/Profile/Session 中途失效时后续 teaching writes 与 ordinary complete fail closed。治理 actor 仅可 controlled cancel/cleanup，不得继续制造 teaching facts；V1 不新增 Lesson authorization model。

### `complete_lesson`

使用 `operation_id + lesson_expected_version`。每次 complete 重新验证当前 live session、membership、teacher capability、scope，以及每个相关 participant 的 active Profile 和 legal active Student Teacher Assignment；再验证 Case/Action versions、operation permission 与最终不变量。课中已成功保存的 Evidence/Intervention/Assessment 不重复创建。

如果原 teacher 的 assignment、scope、membership、Profile 或 Session 在 Lesson 进行中失效：
- 后续 Evidence、Intervention、Assessment、Quick Capture/new Case 等 teaching writes 全部拒绝；
- 普通 `complete_lesson` 也拒绝；
- Lesson 已开始不保留旧权限；
- 已 committed 的合法历史事实保留，历史 actor 不改写。

### Controlled cancel / governance recovery

具有相应治理权限的 actor 可受控结束 stale `in_progress` Lesson，并保存 reason、governance event/audit。该行为是状态治理/cleanup，不是 teaching write：
- 不新增 Evidence、Intervention、Assessment、Quick Capture/new Case；
- 不假装原 teacher 完成专业判断；
- 不利用 cancel bypass Case/Action invariant；
- V1 不支持新 teacher 直接 complete 旧 teacher 的 Lesson 或 in-progress reparent。

新 teacher 必须先让旧 Lesson 受控 cancel，再以自己的合法 Student Teacher Assignment 开新 Lesson。

## 13. Student merge

`merge_students` 的完整 V1 matrix 以 `docs/product/STUDENT_MERGE_POLICY.md` 为事实源。

关键：
- 一个业务 DB transaction；
- source/target expected_version；
- safe reparent/dedupe only；
- 同 subject 双 Profile、冲突 Enrollment、双 active Lead 等 → **BLOCK**；
- 先用正常治理 command 整理，再重试；
- source→merged，source 不删除；
- finalized history provenance 不重写；
- operation-bound merge record/event/audit；
- 重试不重复迁移。

---

## 14. Parent Communication / Report

Finalized 是不可变 snapshot/event；普通 UPDATE 不覆盖。

- outbound 后异步 reply → 新 inbound communication；
- correction/supersede 保留旧 history；
- finalization 使用 expected_version + operation_id + audit；
- Guardian 不是 Case Action assignee。

---

## 15. Function / Repository safety

- security invoker 优先；
- security definer 仅非 exposed schema + fixed search_path + least grant；
- provider secret 不进 Flutter；
- unauthenticated/revoked/onboarding/disabled/cross-org/wrong-scope/no-assignment/inactive-profile/archived-profile 负向测试；
- Repository API 用业务命名，不暴露任意 status mutation。

---

## 16. Failure Injection 最小矩阵

Phase 0B 必须验证：
- expected Student/Profile/Case version stale；
- current assignment set 在预览后变化；
- target teacher scope 被撤；
- lifecycle staging 各点失败；
- event/audit 写失败；
- `reopen_case` event/action/reopened_count 任一步失败；
- Student multi-Profile 第 N 个失败整体 rollback；
- selected archived Profile 直接 reactivate Student → 拒绝；
- Quick Capture inactive Profile / Advisor-only → 拒绝；
- merge same-subject dual Profile / dual Lead / conflicting Enrollment → 拒绝；
- command commit 后 response lost → 同 operation_id 返回原结果；
- 重复 operation 不产生第二条 lifecycle event/audit。
