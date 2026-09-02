# 业务命令、事务与不变量

> RLS 解决“谁能访问”，领域命令/事务解决“这次修改是否完整、合法、可重试”。V1 不允许 ViewModel 靠多次普通 CRUD 拼出高风险业务状态。

## 1. 写入分层

### 简单事实追加
在 RLS 保护下可由 Repository → Data API：
- 新增合法 Evidence；
- 新增本人真实 Intervention / Assessment（必须通过完整 Teaching Fact Gate）；
- 允许类型的普通 note/event；
- 单条附件 metadata；
- 保存 `new` Quick Capture；
- 保存 Parent Communication / Report 的 draft 当前快照（若 command policy 允许普通 draft update）。

原则：客户端预生成 UUID，重试复用；服务端时间是系统时间事实源；append-only facts 与可变 aggregate 使用不同并发策略。

### 不变量敏感命令
至少包括：

#### Identity / membership
- `provision_member`
- `complete_member_onboarding`
- `reset_member_credential`
- `disable_membership_and_handoff`

#### Subject / assignment / service lifecycle
- `reassign_teacher`
- `revoke_teacher_subject_scope_and_handoff`
- `deactivate_student_subject_profile`
- `archive_student_subject_profile`
- `unarchive_student_subject_profile`
- `reactivate_student_subject_profile`

#### Learning Case
- `confirm_case`
- `transition_case`
- `reopen_case`
- `replace_primary_case_action`
- `complete_case_action`

#### Lesson
- `start_lesson`
- `complete_lesson`

#### Student lifecycle / governance
- `merge_students`
- `deactivate_student`
- `archive_student`
- `unarchive_student`
- `reactivate_student`

#### Finalized snapshots
- `finalize_parent_communication`
- `correct_parent_communication`
- `finalize_report`
- `correct_report` / `supersede_report`

具体哪些最终实现为 DB Function、哪些组合为可信服务端 command，留 Phase 0B API/migration design；**领域 command 语义必须存在，ViewModel 不得直接改 status 拼业务。**

---

## 2. 领域生命周期命令的原子事务规则｜Phase 0A.6 硬定义

这是所有 Student / Subject Profile / Assignment / Case owner / primary Action 生命周期命令的共同规则。

### 2.1 提交态不变量，而不是“逐 SQL 中间态不变量”

以下不变量约束的是**事务提交后可见状态**：

- active teacher assignment 必须对应 active Subject Profile；
- active Subject Profile 的 formal open Case 必须有合法 owner + pending primary Action；
- inactive/archived Subject Profile 不得保留 active teacher assignment 或普通 pending primary Action；
- inactive/archived Subject Profile 不得产生普通教学事实或新 Lesson。

生命周期 command 可以在**同一个数据库事务内部**先计算/暂存 assignment、owner、Action、Profile status 的目标变化；这些中间写入不得被其他 Session 看见，也不能分多次 API/CRUD 提交。

因此本文出现的“先/后/最后”只表示**事务内部校验与构造顺序**，不表示允许把中间态提交给数据库。

### 2.2 单一逻辑事务

以下 command 的业务数据库部分必须是单一原子事务：
- `deactivate_student_subject_profile`
- `archive_student_subject_profile`
- `unarchive_student_subject_profile`
- `reactivate_student_subject_profile`
- `deactivate_student`
- `archive_student`
- `unarchive_student`
- `reactivate_student`
- `reassign_teacher`
- `revoke_teacher_subject_scope_and_handoff`
- `disable_membership_and_handoff` 的业务 DB handoff 部分
- `merge_students`

同一个 command 内对 Profile/Student、assignment、Case owner、Action、events、audit 的变化：

> **全部成功一起 commit；任一校验/写入失败全部 rollback。**

禁止：
- 先提交 assignment，再调用第二个 API 改 Profile；
- 先取消 Action，再调用第二个 API 设 inactive；
- 客户端按步骤循环补齐状态；
- 一半成功后让 UI 自己“修复剩余步骤”。

### 2.3 `operation_id + expected_version`

每个生命周期 command 至少使用：
- `operation_id`：同一用户意图的幂等键；
- `expected_version`：目标 Student/Profile/Case 聚合的乐观并发前置；
- 必要 unique constraints / operation receipt；
- 服务端事务。

重复同一 `operation_id`：
- 不重复结束 assignment；
- 不重复取消 Action；
- 不重复创建 owner/primary Action；
- 不重复写 tracking event；
- 返回已完成 operation 的结果或当前 committed snapshot。

### 2.4 timeout / response lost

如果客户端 timeout，不知道服务端是否已经 commit：

1. **不要**重新生成 operation_id；
2. 先按 `operation_id` / target version 查询 command 结果；
3. 已 commit → 接受 committed snapshot；
4. 明确未执行 → 使用同一 operation_id 安全重试；
5. 结果不明 → 继续查询，不用多次普通 CRUD 猜测补齐。

### 2.5 失败注入验收

Phase 0B 必须模拟在每个事务内部阶段失败：
- inventory 后失败；
- Action mutation 后失败；
- assignment mutation 后失败；
- owner mutation 后失败；
- Profile/Student status mutation 前失败；
- event/audit 写入失败；
- commit 成功但 response 丢失。

除“commit 成功但 response 丢失”外，数据库最终应与 command 开始前一致；response 丢失则查询必须返回**完整 committed 新状态**，不得半状态。

---

## 3. Provider-neutral Auth 前置 Gate

Phase 0A.6 冻结安全目标，不冻结 provider-specific 主键/Session helper。

Phase 0B.0 在任何正式业务 migration 前必须验证：
1. Auth identity strategy；
2. revoked-session / old-token security。

Supabase `auth.uid()/session_id/auth.sessions` 只是 reference；其他 provider 必须达到等价安全结果。

---

## 4. Credential 命令不是普通数据库事务

Auth Admin 与业务 PostgreSQL 可能不在同一事务域，因此 credential 命令采用 fail-closed：

> 任一步失败都优先收敛到“没有学生业务权限”。

### `provision_member`
1. 验证 live Session、org_admin 与 organization；
2. 规范化登录标识、roles；
3. 检查已有 membership/Auth identity；
4. 生成高强度临时密码；
5. Auth Admin 创建/恢复 identity；
6. 创建 profile、membership(onboarding)、roles、expiry；
7. 可预配置 subject scopes，但 onboarding 无学生业务权限；
8. audit 不含密码；
9. 临时密码只在成功响应显示一次。

Auth identity 已创建而 DB 写失败时允许留下“无 membership identity”，因为它无业务权限；后续走恢复/重新 provision。

### `complete_member_onboarding`
1. 当前 Session + membership=onboarding；
2. expiry 合法；
3. 校验新密码；
4. 更新 credential；
5. 撤销既有 Sessions；
6. revoke 成功后 membership→active；
7. audit；
8. 强制重新登录。

任何半失败不得提前 active。

### `reset_member_credential`
1. 验证 org_admin；
2. membership→onboarding，先切断普通业务；
3. 生成新临时密码；
4. 更新 credential；
5. revoke Sessions；
6. 刷新 onboarding expiry；
7. audit；
8. 临时密码只返回一次。

Auth 更新失败时 membership 保持 onboarding。

---

## 5. Live Session 是业务授权不变量

普通学生业务至少要求：
- Auth identity 有效；
- 当前 Session 仍有效；
- membership=active；
- role/capability；
- subject scope / assignment / owner 等关系；
- entity state；
- operation-specific rule。

Phase 0B.0 必须用 old-token negative test 证明 revoked Session 立即失败。

---

## 6. Teaching Fact Gate｜唯一硬定义

任何成员要以实际教学 actor 身份追加/确认：
- Intervention；
- Assessment；
- 教学型 Evidence；
- Lesson teacher 行为；

必须同时满足：

```text
live session
+ active membership
+ teacher capability
+ matching active teaching subject scope
+ target Student Subject Profile = active
+ legal active Student Assignment
  或受控 command 已验证的合法 Lesson relationship
+ operation-specific permission
```

硬规则：
- active Subject Profile 是硬条件；
- inactive/archived Profile 即使遗留旧 scope/assignment 也拒绝教学事实；
- Subject Lead/Admin/Advisor 管理身份不能 bypass；
- Initial Diagnosis 不能使用“管理员授权”绕过 Gate。

---

## 7. Case resolution 与 Subject service lifecycle 正交

Case status 严格：

```text
new → confirmed → intervening → pending_verification → stable → closed
```

`reopen` 是 command/event，不是状态。

Subject Profile：

```text
active --deactivate--> inactive --archive--> archived
active <--reactivate-- inactive <--unarchive-- archived
```

- Case status 回答问题解决到哪一步；
- Profile status 回答当前是否持续该学科服务。

停读/停科/archive 不得把 unresolved Case 假改成 closed。

```text
Assessment passed ≠ stable ≠ closed
```

---

## 8. Primary Action / owner 不变量

### active Profile
formal open Case（confirmed/intervening/pending_verification/stable）必须：
- 有合法 active owner；
- owner 满足 teacher capability + teaching scope + active assignment；
- 恰好有一个 pending primary Action。

### inactive/archived Profile
unresolved Case 可以保留原 resolution status，但：
- 不要求 current owner/primary Action；
- 不进入普通 Today；
- 不允许新教学事实/新 Lesson；
- lifecycle command 写 suspended/archived event；
- 恢复 active 时必须在**同一 reactivate transaction**里恢复 owner + primary Action。

active Profile 内教学上的“暂缓/稳定观察”仍用 `review + due_at`，不能把 Profile inactive 当作普通 pause。

`replace_primary_case_action` 在单一事务中结束旧 primary、创建新 primary、写 event。

---

## 9. `confirm_case`

单一事务：
1. case=new + expected_version；
2. Profile=active；
3. actor 有确认权限；
4. owner 合法；
5. taxonomy 与 profile 一致；
6. 至少一条 Evidence；
7. pending primary Action 存在；
8. review pause 时 due_at；
9. event；
10. status/version。

任一步失败 rollback。

---

## 10. Assessment 与 Case status 分离

- passed 不自动 stable/closed；
- failed/partial 不删历史；
- stable/closed 由合法 owner/teacher结合证据确认；
- Collaborator 不因自己做了 Assessment 自动获得 close 权；
- transition 写 Case Event。

---

## 11. `deactivate_student_subject_profile`

用途：暂停/停止某一学科持续教学。

**整个 business mutation 是一个原子事务。** 事务开始时 Profile 仍 active；事务 commit 时 Profile 已 inactive，且所有 committed-state 不变量同时成立。

事务内部：
1. 验证 live governance actor、`operation_id`、profile `expected_version`；
2. 要求当前 profile=active；
3. inventory active assignments、formal open Cases、owners、pending Actions、in-progress/future Lesson obligations；
4. 计算每个 Action 的完成/取消方案，reason=`subject_inactive` 或等价；
5. unresolved Case status 保持真实，不自动 closed；
6. 结束该学科 active assignments；
7. 清除/结束 current owner responsibility；
8. 写 tracking-suspended events；
9. 将 profile staged 为 inactive；
10. 在 commit 前重新验证：无 active assignment、无普通 pending Action、无非法 Lesson obligation；
11. audit；
12. **一次 commit。**

若 4–11 任一步失败：全部 rollback，Profile 仍 active，原 assignments/owners/Actions 仍保持原 committed 状态。

该命令不影响其他 Subject Profiles。

---

## 12. `archive_student_subject_profile`

前置：profile=inactive。

单一事务：
1. live governance actor + operation_id + expected_version；
2. 验证无 active assignment、pending Action、in-progress Lesson/current teaching obligation；
3. unresolved Cases 保留真实 status；
4. 写 tracking-archived event；
5. profile staged→archived；
6. audit；
7. commit。

任一步失败全部 rollback。禁止 active→archived 直跳。

---

## 13. `unarchive_student_subject_profile`

用于把历史学科主线恢复到可管理状态，但不恢复教学。

单一事务：
1. profile=archived；
2. Student 不能 merged；若 Student archived，先完成独立 `unarchive_student` command；
3. governance permission + operation_id + expected_version；
4. profile staged→inactive；
5. 写 unarchive event/audit；
6. commit。

commit 后仍：
- 无 active teacher assignment；
- 无 primary Action；
- 不允许教学事实。

禁止 unarchive 内偷偷 reactivate。

---

## 14. `reactivate_student_subject_profile`

用途：恢复某一学科持续教学。

**assignment、owner、primary Action、Profile status 必须在同一原子事务一起恢复。**

事务开始 committed state：
- profile=inactive；
- 无 active teacher assignment；
- unresolved formal Cases 可以没有 current owner/primary Action。

事务内部 staged target：
1. 验证 live governance actor、operation_id、expected_version；
2. Student 不是 archived/merged，且处于允许恢复服务状态；
3. 验证候选教师 active + teacher capability + matching teaching scope；
4. inventory unresolved formal Cases；
5. **在事务内暂存**目标 active assignment；
6. 为每个继续跟进 Case **在同一事务内暂存**合法 owner + 新 pending primary Action；
7. 若 Case 确实已解决，只能通过合法 Case command/同事务内被明确验证的等价 transition 处理，不批量假关闭；
8. 写 tracking-resumed events；
9. profile staged→active；
10. commit 前验证完整目标快照：
   - Profile=active；
   - active assignment 与 Profile/subject/org 一致；
   - 每个 formal open Case 有合法 owner；
   - 每个 formal open Case 有恰好一个 pending primary Action；
   - 无 closed Case pending primary；
11. audit；
12. **一次 commit。**

关键解释：步骤 5–9 是**事务内部 staging**，不会产生“inactive Profile + active assignment/Action”的对外可见 committed state。

任一步失败：全部 rollback，Profile 仍 inactive，active assignment/owner/new Actions 均不存在。

禁止 archived→active；必须先 unarchive→inactive。

---

## 15. `start_lesson`

单一 command：
1. live session + active membership；
2. teacher capability + teaching scope；
3. target Profile=active；
4. legal active assignment/validated Lesson relationship；
5. organization/subject 一致；
6. operation permission；
7. 创建 lesson(in_progress)+participants；
8. audit；
9. 返回 context。

即完整 Teaching Fact Gate。

---

## 16. `complete_lesson`

课中 Evidence/Intervention/Assessment 可逐项可靠保存；每条教学事实本身也必须通过完整 Teaching Fact Gate。

最终 command 收口：Action completion/cancel、合法 Case transition、下一 primary Action、Case Event/audit、Lesson completed。

必须：
- live session；
- lesson expected_version/status；
- teacher capability/scope/assignment/Profile 仍合法；
- 不重复创建已成功事实；
- Case/Action 不变量成立；
- operation_id 幂等；
- 返回 committed snapshot。

小班 whole-lesson atomic vs per-student reconcile 后 finalize 留 Phase 0B.0 fault/transaction Spike；无论哪种方案，不能把非法半状态 commit 为 completed Lesson。

---

## 17. `reassign_teacher`

单一业务事务：
- Profile=active；
- 新教师 active + teaching scope；
- 不违反 Lead 唯一；
- 旧/新 assignment、Case owner、pending Action assignee 同事务迁移；
- history/event/audit；
- commit 前无 orphan；
- 失败全部 rollback。

---

## 18. `revoke_teacher_subject_scope_and_handoff`

老师仍在职但退出某学科。

单一业务事务：
1. inventory 该科 active assignments/owners/pending Actions；
2. 验证接手人 active + teacher + matching teaching scope + target Profile active；
3. staged 结束旧 assignments，建立新关系；
4. staged 转移 owner/Actions；
5. staged 结束目标 teaching scope；
6. commit 前验证无 orphan、其他学科不受影响；
7. audit；
8. commit。

任一步失败全部 rollback。不能误撤其他学科。

---

## 19. `disable_membership_and_handoff`

业务数据库 handoff 部分采用单一事务：
- inventory teacher/staff assignments、owners、pending Actions、subject scopes；
- staged 完成交接；
- 验证无 orphan；
- membership staged→disabled；
- audit；
- commit。

Auth Session revoke 可能是外部事务域，因此采用 fail-closed orchestration：DB 先确保 membership disabled 后，即便 revoke 外部调用暂时失败，业务 RLS 也必须因 membership disabled 拒绝学生访问；随后重试 revoke。

历史 actor 保留。

---

## 20. Student lifecycle｜完整状态机

```text
active --deactivate_student--> inactive --archive_student--> archived
active <--reactivate_student-- inactive <--unarchive_student-- archived
```

`merged` 是独立终态。

### `deactivate_student`

**整个 Student + 各 Subject Profile reconciliation 是单一逻辑事务。**

事务内部：
1. Student=active + expected_version + operation_id；
2. inventory enrollment、staff assignments、所有 active Profiles 及其 assignment/owner/Action/Lesson obligations；
3. 对每个 active Profile执行与 profile deactivate 相同的 staged reconciliation；
4. staged 结束/调整 enrollment、staff assignments；
5. unresolved Cases 不自动 closed；
6. Student staged→inactive；
7. commit 前验证无 active Profile/current Today obligation；
8. audit；
9. commit。

任一 Profile reconciliation 失败 → 整个 Student command rollback，不能出现“部分学科已停、Student 仍 active/半停”的意外状态。

### `archive_student`
前置 Student=inactive。单一事务：
- 所有 Profiles 必须 inactive/archived；
- 对仍 inactive Profiles staged archive；
- 无 active enrollment/teacher/staff assignment/pending Action/in-progress Lesson；
- unresolved Cases 保持真实 status；
- Student staged→archived；
- audit；
- commit。

禁止 active→archived。

### `unarchive_student`
单一事务：
- Student=archived，且非 merged；
- Student staged→inactive；
- Subject Profiles 保持 archived；
- 不自动恢复 enrollment/assignment/Action；
- audit；
- commit。

### `reactivate_student`
**Student 与被选择恢复的 Subject Profiles 必须作为一个受控逻辑事务完成。**

事务内部：
1. Student=inactive + expected_version + operation_id；
2. staged 恢复/新增 Enrollment；
3. 选择实际恢复学科；
4. archived Profile 不允许直接 active；必须在 command 前先独立 unarchive 到 inactive，或由同一可信 orchestration 先完成并确认其 inactive committed state；
5. 对每个待恢复 inactive Profile，在同一 Student reactivate transaction 内 staged assignment + owner + Actions + Profile active；
6. Student staged→active；
7. commit 前验证每个恢复 Profile 的 active invariants，未恢复 Profile 仍 inactive/archived；
8. audit；
9. commit。

任何学科恢复失败 → 本次 Student reactivate 的所有 staged 业务变化 rollback。

### `merged`
`merge_students` 后 source Student=merged：不可 unarchive/reactivate；旧 ID 只用于历史解释/重定向。

---

## 21. `merge_students(source, target)`

- source != target；
- 同机构；
- governance permission；
- expected versions + operation_id；
- 不形成 merge 环；
- enrollment/profile/assignment/Case 冲突策略明确；
- 单一业务事务或经过明确证明的可恢复 orchestration；V1 默认优先单事务；
- source→merged；
- merge record + audit；
- 重试不重复迁移；
- source 不物理删除。

---

## 22. Parent Communication 是事件，不是 mutable thread

### Draft
Draft 可编辑，version/expected_version；Draft 不是已联系。

### `finalize_parent_communication`
单一事务至少检查：status=draft、expected_version、actor 权限、recipient(s)、direction/channel/occurred_at、reply_to 同 org+student；冻结当次 content snapshot；创建/校验 follow-up；finalized_by/time；audit。

### async reply
outbound finalized 后家长后来回复：新增 inbound event，可 reply_to 原 outbound；不修改旧 finalized row。

### conversation
同一电话/面谈 interaction 中双方当场交流，可以一条 conversation event 冻结双方内容。

### correction
Finalized 不普通 UPDATE；保留旧 snapshot + correction reason/actor/time。已发错误内容若现实中更正，也应形成新的 communication event。

---

## 23. Report / Stage Review

### `finalize_report`
单一事务：draft + expected_version + confirm permission + source_cutoff + content snapshot + finalized_by/time + audit。

### `correct_report` / `supersede_report`
保留原 finalized snapshot + reason/actor/time；Case reopen/补录 Evidence 不静默改旧报告。

Finalized Report ≠ Parent informed。

---

## 24. 幂等、重试与 timeout unknown result

### simple insert
客户端预生成 UUID；重试复用。

### multi-entity command
使用 operation_id + expected_version + transaction + 必要 unique constraint / receipt。

### timeout
先查询 operation result，不盲目重放副作用。

### lifecycle command 特别规则
任何 deactivate/reactivate/archive/unarchive/handoff/merge 的 timeout 后都必须先查询：
- operation receipt；
- target entity version/status；
- committed assignments/Actions。

只能接受完整旧状态或完整新状态；若看到半状态即视为系统缺陷/治理异常，不由客户端自动补齐。

---

## 25. 时间、并发与 finalized

- system timestamps 由服务端权威；
- observed/assessed/intervention/lesson/communication occurred_at 可由授权用户合理修正并审计；
- 关键快照使用 version/expected_version；
- version conflict 禁止 silent last-write-wins；
- 两条独立 append-only Evidence 可以并发成功；
- 同一 Case state/primary Action/lifecycle command 竞争只能一个成功；
- finalized Communication/Report 不被旧 Draft 覆盖。

---

## 26. Function 安全

- 优先 security invoker；
- security definer 放非 exposed schema；
- `set search_path=''`；
- schema-qualified；
- revoke 默认 execute；
- 最小 grant；
- unauthenticated/revoked/onboarding/disabled/cross-org/wrong-scope/no-assignment/inactive-profile/archived-profile 均有负向测试；
- management role 不得绕过 Teaching Fact Gate；
- provider secret 不进 Flutter。

---

## 27. Repository API 像业务

```text
membershipRepository.provisionMember(...)
membershipRepository.completeOnboarding(...)
membershipRepository.resetCredential(...)
membershipRepository.disableAndHandoff(...)

assignmentRepository.reassignTeacher(...)
assignmentRepository.revokeSubjectScopeAndHandoff(...)

studentSubjectRepository.deactivate(...)
studentSubjectRepository.archive(...)
studentSubjectRepository.unarchive(...)
studentSubjectRepository.reactivate(...)

learningCaseRepository.confirmCase(...)
learningCaseRepository.reopenCase(...)
learningCaseRepository.replacePrimaryAction(...)

lessonRepository.startLesson(...)
lessonRepository.completeLesson(...)

studentRepository.deactivateStudent(...)
studentRepository.archiveStudent(...)
studentRepository.unarchiveStudent(...)
studentRepository.reactivateStudent(...)
studentRepository.mergeStudents(...)

parentCommunicationRepository.finalize(...)
parentCommunicationRepository.correct(...)
reportRepository.finalize(...)
reportRepository.correct(...)
```

不要把数据库表名/任意 status string/provider API 暴露给 ViewModel 拼业务。

---

## 28. 完成定义 / Failure Injection Matrix

高风险命令上线前至少证明：
- 正常路径；
- 非法状态拒绝；
- revoked Session；
- wrong scope / no assignment；
- inactive/archived Profile teaching fact 拒绝；
- management-only actor 伪造 teaching fact 拒绝；
- expected_version 冲突；
- duplicate operation；
- response lost；
- cross-org/cross-subject；
- subject-scope handoff 不影响其他学科；
- deactivate 事务中 assignment/Action/owner 任一步失败 → 全回滚；
- reactivate 事务中 assignment/owner/Action/Profile 任一步失败 → 全回滚；
- commit 成功 response lost → 同 operation_id 查询得到完整新状态；
- **永远不出现 committed `inactive Profile + active assignment/普通 pending Action`；**
- **永远不出现 committed `active Profile + formal open Case 无合法 owner/primary Action`；**
- Student multi-profile deactivate/reactivate 任一子步骤失败 → 整单回滚；
- archive 只能 inactive→archived；unarchive 只能 archived→inactive；reactivate 只能 inactive→active；
- archived→active 直跳拒绝；
- merged Student unarchive/reactivate 拒绝；
- communication outbound finalized 后 async reply 创建新 inbound event；
- finalized correction 保留旧历史；
- 小班 Lesson transaction shape 由 Phase 0B.0 Spike 证明，但无论方案都禁止非法半状态 commit。
