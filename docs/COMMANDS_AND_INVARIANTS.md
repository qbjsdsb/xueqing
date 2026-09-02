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

### 2.3 Student aggregate concurrency

`students` 必须有 `version`。

Student 多 Profile 生命周期命令输入至少包含：
- `student_expected_version`；
- 每个受影响 Subject Profile 的 `expected_profile_version`；
- 每个会被改变的 formal Case 的 `expected_case_version`；
- 预览时记录的 current assignment IDs/roles/owner/Action IDs。

事务开始后以稳定 ID 顺序锁定并重读：
1. Student；
2. 受影响 Profiles；
3. 受影响 Cases；
4. current assignment / Action rows；
5. 目标 membership + subject scope rows。

任一版本、current relation set、目标成员状态与预览不同 → `version_conflict / stale_plan`，整个 command rollback。

Assignment 本身可以继续采用历史行 + row lock/current-state predicate，不强制每行另增 version；关键是 command 必须验证**实际 current set 与预期一致**。

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
+ legal active Student Assignment
  或受控验证的合法 Lesson relationship
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
只适用于：**已经 `closed` 的 Case 在当前 active teaching service 下真实复发，重新进入正式解决跟进。**

它不是：
- Profile inactive/archived 后的 resume；
- 第七状态；
- 只增加 reopened_count 的普通 UPDATE。

### 8.2 唯一目标状态

```text
closed --reopen_case--> confirmed
```

理由：复发已经确认值得重新正式跟进，但 command 本身不虚构“已经发生新的 Intervention”。后续实际干预再进入 `intervening`。

### 8.3 前置条件
- live session + active membership；
- teacher capability + matching teaching scope；
- target Profile=`active`；
- actor 有该 Case reopen command permission；
- case.status=`closed`；
- `expected_case_version`；
- 提供合法 `owner_membership_id`；
- 提供一个新的 pending primary Action；
- 至少关联一条支持“复发/重新达到跟进条件”的 recurrence Evidence（可以是此前由合法 Gate 创建的 Evidence）。

### 8.4 原子目标快照
同一事务：
- status staged `closed → confirmed`；
- `closed_at → null`；
- `stable_at → null`（当前快照不再处于 stable；历史 stable/close 时间保留在 Case Events）；
- `reopened_count += 1`；
- owner staged 为合法 active teacher；
- exactly one pending primary Action；
- 写 `case_reopened` event，metadata 至少引用 recurrence evidence / previous close；
- event/audit 绑定 operation_id；
- case.version +1；
- final invariant validation；
- commit。

任一步失败全部 rollback。

### 8.5 inactive/archived Profile
`reopen_case` **直接拒绝**。

此时如果发现线索：
- Parent Communication / Observation 等可以保存其自身事实；
- 不能通过 reopen 制造 active tracking；
- 先按 service lifecycle 恢复 Profile；
- 再由合法 teacher 建/确认 recurrence Evidence 并执行 reopen。

### 8.6 幂等
同 operation_id 重试只返回第一次 committed reopen result；不得重复 `reopened_count`、event、audit、primary Action。

---

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
- commit 后 Student.version +1。

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
- Student.version +1；
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
必须完整 Teaching Fact Gate；创建 lesson+participants 受控、同组织同科、Profile active。

### `complete_lesson`
使用 operation_id + lesson expected_version；收口合法 Action/Case transitions/next Action/Lesson status。课中已成功的 Evidence/Intervention/Assessment 不重复创建。

小班事务粒度留 Phase 0B.0 Spike，但无论实现都不能把非法半状态标 completed。

---

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
