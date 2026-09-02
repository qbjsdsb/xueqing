# 业务命令、事务与不变量

> RLS 解决“谁能访问”，约束/事务命令解决“这次修改是否完整、合法、可重试”。V1 不允许 ViewModel 靠多次普通 CRUD 拼出高风险业务状态。

## 1. 两类写入

### 简单事实追加
在 RLS 保护下可由 Repository → Data API：
- 新增合法 Evidence；
- 新增本人真实 Intervention / Assessment（必须通过 Teaching Fact Gate）；
- 允许类型的普通 note/event；
- 单条附件 metadata；
- 保存 `new` Quick Capture；
- 保存 Parent Communication / Report 的 draft 当前快照（若 command policy 允许普通 draft update）。

原则：客户端预生成 UUID，重试复用；服务端时间为系统时间事实源；append-only facts 和可变 aggregate 使用不同并发策略。

### 不变量敏感命令
必须走受控 Database Function / Edge Function / 可信服务端，至少包括：

#### Identity / membership
- `provision_member`
- `complete_member_onboarding`
- `reset_member_credential`
- `disable_membership_and_handoff`

#### Subject / assignment / service lifecycle
- `reassign_teacher`
- `revoke_teacher_subject_scope_and_handoff`
- `deactivate_student_subject_profile`
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
- `reactivate_student`
- `archive_student`

#### Finalized snapshots
- `finalize_parent_communication`
- `correct_parent_communication`
- `finalize_report`
- `correct_report` / `supersede_report`

具体哪些最终实现为单独 DB Function、哪些组合为可信服务端命令，留 Phase 0B migration/API design；**领域命令语义必须存在，ViewModel 不得直接任意改 status 拼业务。**

---

## 2. Provider-neutral Auth 前置 Gate

现有 Foundation 参考 Supabase Auth，但 Phase 0A.6 已确认 CloudBase 等国内候选与 Supabase 在 Auth ID / Session 细节上并非完全一致。

因此：
- 本文继续冻结安全不变量；
- provider-specific function/API 名称不得当成领域语义；
- Phase 0B.0 在任何正式 business migration 前先验证 Auth identity strategy 与 revoked-session security；
- 不能为了使用免费国内节点降低旧 Session 失权基线。

后文出现 `auth.uid()/session_id/auth.sessions/global sign-out` 时，代表 **Supabase reference implementation**；若选其他 provider，必须实现等价安全保证并由负面测试证明。

---

## 3. Credential 命令不是普通 CRUD

Auth Admin 与业务 PostgreSQL 不在同一个事务域，所以 credential 命令的目标不是“假装原子”，而是：

> **无论在哪一步失败，都优先收敛到没有学生业务权限的状态。**

### `provision_member`

顺序：
1. 验证 live Session、org_admin 与目标 organization；
2. 规范化登录标识、验证 roles；
3. 检查已有 membership / 可恢复的既有 Auth identity；
4. 生成安全随机临时密码；
5. Auth Admin 创建/更新受控 Auth identity；
6. 创建 profile、`membership(onboarding)`、roles、`onboarding_expires_at`；
7. 可预配置 subject scopes，但 onboarding 不获得普通学生业务权限；
8. audit 不包含密码；
9. 临时密码只在成功响应显示一次。

如果 Auth identity 已创建但 DB 写入失败，允许留下**无 membership Auth identity**，因为它没有业务权限；后续必须有明确恢复路径。

### credential 的特殊幂等规则

credential 明文故意不持久化，因此不能要求“同 operation_id 再次返回同一临时密码”。

如果后端已成功但响应丢失：
- member 仍 onboarding；
- 返回/展示 `credential_delivery_unknown` 或等价状态；
- 管理员执行 reissue/reset，生成一个新的临时密码；
- 旧临时密码因 Auth 密码更新失效；
- 不保存可找回的明文密码。

### `complete_member_onboarding`

Reference 流程：
1. 验证当前 Auth Session 与 membership=onboarding；
2. 检查 `onboarding_expires_at`；
3. 校验新密码；
4. Auth Admin 更新当前用户密码；
5. 撤销该身份已有 Sessions/Refresh Tokens；
6. 撤销成功后，服务端才将 membership→active；
7. 写 audit；
8. 客户端丢弃旧业务上下文并强制重新登录。

业务 RLS/API 还必须验证当前 Session 仍然有效。

半失败：
- 密码更新失败 → onboarding；
- 密码成功、Session 撤销失败 → onboarding；
- Session 撤销成功、membership 激活失败 → onboarding；
- 不存在“半失败但 active”。

### `reset_member_credential`

顺序必须保守：
1. 验证 org_admin；
2. **先 membership→onboarding**，立即切断普通业务；
3. 生成新随机临时密码；
4. Auth Admin 更新密码；
5. 撤销既有 Sessions；
6. 刷新 `onboarding_expires_at`；
7. 写 audit；
8. 临时密码只返回一次。

Auth 更新失败时 member 仍 onboarding。

---

## 4. Live Session 是业务授权不变量

普通学生业务至少要求：
- 当前 Auth identity 有效；
- 当前 Session 仍有效；
- organization membership = active；
- role/capability；
- subject scope / student assignment / owner 等关系；
- operation-specific rule。

Reference Supabase：`auth.uid() + JWT session_id + auth.sessions + membership`。

Phase 0B.0 必须用 old-token negative test 证明 revoked Session 立即失败。

---

## 5. Teaching Fact Gate

任何人要以“实际授课/验证教师”身份追加：
- Intervention；
- Assessment；
- 教学型 Evidence；
- Lesson teacher 行为；

至少必须满足：

```text
live session
+ active membership
+ teacher capability
+ matching active teaching subject scope
+ active Student Subject Profile
+ 对该 student+subject 的合法 active teacher assignment 或本次合法 Lesson relationship
+ operation-specific permission
```

Subject Lead leadership scope、Academic Admin、Org Admin、Student Advisor 单独存在时都不能伪造教学事实。

---

## 6. Case 解决生命周期与 Subject Service 生命周期分离

Case status 严格：

```text
new → confirmed → intervening → pending_verification → stable → closed
```

`reopen` 是命令/事件，不是状态。

Student Subject Profile status：

```text
active / inactive / archived
```

两者回答不同问题：
- Case status：问题解决到哪一步；
- Profile status：该学科当前是否持续教学。

**不得因为学生/学科停读就把未解决 Case 改成 closed/已清零。**

产品语言仍保持：

```text
Assessment passed ≠ stable ≠ closed
```

---

## 7. Active Profile 下的 Case 不变量

### `new`
10–20 秒快速草稿，可缺 taxonomy/owner/action。

### formal open Case
当 `Student Subject Profile = active` 时，`confirmed / intervening / pending_verification / stable` 必须：
- 有合法 active owner；
- owner 满足 teacher capability + teaching scope + active Student Assignment；
- 有一个 pending primary Action。

### Profile inactive/archived
未解决 formal Case 可以保留其真实 Case status，但：
- 不要求 current pending primary Action；
- 不进入普通教师 Today；
- 停用时要写 tracking suspended event/reason；
- 恢复 profile active 前必须重新 reconcile 并建立合法 primary Action。

### 暂停/稳定观察
在 active Profile 内，如果只是教学上的“暂缓/观察”，仍然必须使用 `review + due_at`；不能拿 profile inactive 逃避正常下一步责任。

---

## 8. 三类 Case Workflow 不改变生命周期

- knowledge：当堂订正 → 相似题 → 延迟独立验证 → stable/review/closed；
- habit：可观察行为 → 干预 → 多场景连续观察 → 稳定/调整；
- exam_strategy：方法 → 应用 → 限时/模拟迁移 → 独立验证。

三阶是 knowledge 默认产品 template，不是数据库三列/三状态。

---

## 9. `confirm_case`

原子检查：
1. case=new，expected_version 匹配；
2. Subject Profile=active；
3. actor 有编辑/确认权限；
4. owner active 且满足 Teaching relationship；
5. taxonomy 与 profile 一致；
6. 至少一条 Evidence；
7. 存在 pending primary Action；
8. 暂停 review 必须 due_at；
9. 写 event；
10. 更新 status/version 并返回快照。

---

## 10. Assessment 与 Case Status 分离

- passed 不自动 stable/closed；
- failed/partial 不删除历史；
- stable/closed 由授权 owner/teacher 结合证据确认；
- Collaborator 若不是合法 owner/command actor，不因自己做了 Assessment 自动获得 close 权；
- 状态变化写 Case Event。

---

## 11. 主行动不变量

- 同一 Case 最多一个 `pending + is_primary`；
- **active Profile 的 formal open Case** 必须有 pending primary；
- inactive/archived Profile 的 unresolved Case 可以无 pending primary；
- profile deactivation 时旧 pending Action 必须受控完成/取消，记录 suspension reason；
- profile reactivation 前必须为 unresolved Case 创建新的 primary Action；
- closed 不得有 pending primary；
- Guardian 不是 membership，家庭配合不能成为 assigned Case Action。

`replace_primary_case_action` 在同一事务内结束旧主行动、创建新主行动并写 event。

---

## 12. `deactivate_student_subject_profile`

用于：学生仍在机构，但暂停/停止某一学科持续教学。

顺序：
1. 验证治理权限与 profile expected_version；
2. profile 当前 active；
3. inventory active teacher assignments；
4. inventory all formal open Cases；
5. 对每个 pending Action 受控完成/取消，reason=`subject_inactive` 或等价；
6. Case status **保持真实 unresolved status**，不自动 closed；
7. 写 Case tracking-suspended events；
8. 结束该学科 active assignments/owner current responsibility；
9. 验证不存在继续进入普通 Today 的 pending item；
10. profile→inactive；
11. 写 audit。

该命令不影响 Student 其他 active Subject Profiles。

---

## 13. `reactivate_student_subject_profile`

用于学生恢复某一学科。

顺序：
1. 验证治理权限与 profile expected_version；
2. profile 当前 inactive；
3. 建立/恢复合法 teacher assignment；
4. inventory unresolved formal Cases；
5. 对每个仍需继续跟进的 Case 指定合法 owner + 新 pending primary Action；
6. 如果某 Case 根据新证据确实可 closed，必须走真实合法 Case command，不得批量假关闭；
7. 写 tracking-resumed events；
8. 验证 active-profile Case 不变量全部成立；
9. 最后 profile→active；
10. 写 audit。

---

## 14. `start_lesson`

不由 Flutter 拼 `lesson + lesson_students`。

至少：
1. live/active member；
2. teacher capability + matching teaching scope；
3. target Subject Profile=active；
4. 对目标 Student 有合法 assignment/代课关系；
5. organization/subject 一致；
6. 创建 lesson(in_progress) + participants；
7. audit；
8. 返回 Lesson context。

---

## 15. `complete_lesson`

课中 Evidence/Intervention/Assessment 可逐项可靠保存。

最终 command 收口：
- Action completion/cancel；
- 合法 Case transition；
- 下一 primary Action；
- Case Event/audit；
- Lesson completed。

必须：
1. live/active teacher；
2. lesson expected_version/status；
3. teacher/student/subject/profile 仍合法；
4. 不重复创建已成功事实；
5. Case/Action 不变量成立；
6. 重复 operation 不重复副作用；
7. 返回最新快照。

小班“整 Lesson 一个大事务 vs per-student reconcile 后 finalize”留 Phase 0B.0 fault/transaction Spike。

---

## 16. `reassign_teacher`

- 新接手人 active；
- matching teaching scope；
- Subject Profile active；
- 不违反 Lead 唯一；
- owner/pending Action 显式转移；
- assignment history + audit；
- 不直接覆盖旧 membership_id 抹历史。

---

## 17. `revoke_teacher_subject_scope_and_handoff`

用于老师仍在职但退出某学科：
1. inventory 该科 active assignments；
2. Case ownership；
3. pending Actions；
4. 验证接手人 active + teacher + teaching scope；
5. 结束旧 assignments，建立新关系；
6. 转移 owner/actions；
7. 验证无 orphan；
8. 最后结束 teaching scope；
9. audit。

不能误撤其他学科。

---

## 18. `disable_membership_and_handoff`

完整离职：
1. inventory all teacher/staff assignments；
2. Case owner/pending Actions；
3. subject scopes；
4. 完成交接；
5. 验证无 orphan；
6. 最后 membership→disabled；
7. revoke old Sessions；
8. 历史 actor 保留。

---

## 19. Student 整体 lifecycle

### `deactivate_student`
用于学生整体停止机构当前服务。

至少：
1. 验证治理权限；
2. 结束/调整 enrollment；
3. 对每个 active Subject Profile 执行与 `deactivate_student_subject_profile` 等价的 reconciliation；
4. 处理 staff assignments；
5. 验证所有 active profiles/Today obligations 已收口；
6. **不自动 close unresolved Cases；**
7. 最后 Student→inactive；
8. audit。

### `reactivate_student`
1. Student inactive；
2. 恢复/新增 Enrollment；
3. 只激活实际重新开课的 Subject Profiles；
4. 每个 profile 按 `reactivate_student_subject_profile` 恢复 assignment + unresolved Case next Actions；
5. 最后 Student→active。

### `archive_student`
先满足 deactivate/reconciliation 语义；历史不物理删除。

---

## 20. `merge_students(source, target)`

- source != target；
- 同机构；
- 有治理权限；
- 不形成 merge 环；
- enrollment/profile/assignment/Case 冲突有明确策略；
- 事务化或明确可恢复；
- source→merged；
- merge record + audit；
- operation 重试不重复迁移；
- source 不物理删除。

---

## 21. Parent Communication 是事件，不是 mutable thread

### Draft
Draft 可编辑，使用 version/expected_version；Draft 不是已联系。

### `finalize_parent_communication`
至少检查：
1. status=draft；
2. expected_version；
3. actor 有该 Student/context 沟通权限；
4. recipient(s) 合法；
5. direction/channel/occurred_at 合法；
6. reply_to（如有）同 organization + Student；
7. 冻结当次 event 的 content/home-support/现场 response snapshot；
8. 记录 finalized_by/finalized_at；
9. 创建/校验 non-case follow-up 或 Case communicate Action；
10. audit。

### 异步家长回复
老师 outbound 已 finalized 后，家长后来回复：
- **新增 inbound communication event**；
- 可 `reply_to` 原 outbound；
- 不允许修改旧 outbound finalized row 的 guardian_response。

### conversation
同一电话/面谈 interaction 中双方当场交流，可以一条 `conversation` event 同时冻结机构表达、家庭配合与 guardian response。

### `correct_parent_communication`
Finalized 不普通 UPDATE。严重错误保留旧 snapshot + correction reason/actor/time；如果已向家长发送错误内容，后续真实更正也应形成新的 communication event。

---

## 22. Report / Stage Review 命令

### `finalize_report`
1. status=draft；
2. expected_version；
3. actor 有 subject/comprehensive confirm 权限；
4. source_cutoff_at 已确定；
5. 冻结 content_snapshot；
6. finalized_by/time；
7. audit。

### `correct_report` / `supersede_report`
保留原 finalized snapshot + reason/actor/time。后续 Case reopen/补录 Evidence 不静默重写旧报告。

Finalized Report 不等于已告知家长。

---

## 23. 幂等、网络重试与 timeout unknown result

### 简单 insert
客户端预生成 UUID，重试复用。

### 多表 command
使用 `operation_id` / 唯一约束 / operation receipt 等，重复调用不重复副作用。

### timeout unknown result
- 先按 entity/operation_id 查询是否已成功；
- 不盲目重新生成 UUID；
- 不重复 complete/reopen/finalize。

### Credential
不保存明文秘密满足幂等；响应未知则 reissue。

---

## 24. 时间、并发与 finalized

系统时间：created/updated/audit/finalized 服务端权威。

业务发生时间：observed/assessed/intervention/lesson/communication occurred_at 可由授权用户合理修正并审计。

关键快照使用 version/expected_version。版本冲突禁止 silent last-write-wins，并保留用户输入。

Append-only 两条合法 Evidence 可同时成功；同一 Case 状态/primary Action 竞争只能一个 command 成功。

Finalized Communication/Report 成功后旧 Draft 不得覆盖。

---

## 25. Function 安全

- 优先 security invoker；
- security definer 放非 exposed schema；
- `set search_path=''`；
- schema-qualified；
- revoke 默认 execute；
- 最小 grant；
- live-session / no-membership / onboarding / disabled / cross-org / wrong-scope / no-assignment 均有负面测试；
- management role 不得绕过 Teaching Fact Gate；
- provider secret 不进 Flutter。

---

## 26. Repository API 像业务

```text
membershipRepository.provisionMember(...)
membershipRepository.completeOnboarding(...)
membershipRepository.resetCredential(...)
membershipRepository.disableAndHandoff(...)

assignmentRepository.reassignTeacher(...)
assignmentRepository.revokeSubjectScopeAndHandoff(...)

studentSubjectRepository.deactivate(...)
studentSubjectRepository.reactivate(...)

learningCaseRepository.confirmCase(...)
learningCaseRepository.reopenCase(...)
learningCaseRepository.replacePrimaryAction(...)

lessonRepository.startLesson(...)
lessonRepository.completeLesson(...)

studentRepository.deactivateStudent(...)
studentRepository.reactivateStudent(...)
studentRepository.archiveStudent(...)
studentRepository.mergeStudents(...)

parentCommunicationRepository.finalize(...)
parentCommunicationRepository.correct(...)
reportRepository.finalize(...)
reportRepository.correct(...)
```

不要把数据库表名/任意 status string/provider API 暴露给 ViewModel 拼业务。

---

## 27. 完成定义

高风险命令上线前至少有：
- 正常路径；
- 非法状态拒绝；
- revoked Session；
- wrong scope；
- no assignment；
- management-only actor 伪造 teaching fact 拒绝；
- expected_version 冲突；
- duplicate operation；
- response lost；
- cross-org/cross-subject；
- subject scope handoff 不影响其他学科；
- **Subject Profile inactive 不伪造 Case closed；**
- inactive Profile 不再产生普通 Today pending item；
- reactivation 前 unresolved formal Cases 全部重新有合法 next Action；
- Student deactivate/reactivate 逐 profile reconciliation；
- communication outbound finalized 后异步 reply 形成新 inbound event；
- finalized correction 保留旧历史；
- 小班 Lesson 故障边界由 Phase 0B.0 Spike 证明。
