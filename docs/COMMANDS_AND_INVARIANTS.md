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

#### Subject / assignment governance
- `reassign_teacher`
- `revoke_teacher_subject_scope_and_handoff`

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
- 管理员执行 reissue/reset，生成一个**新的**临时密码；
- 旧临时密码因 Auth 密码更新失效；
- 绝不为方便重试而保存可找回的明文密码。

### `complete_member_onboarding`

Reference 流程：
1. 验证当前 Auth Session 与 membership=onboarding；
2. 检查 `onboarding_expires_at`；
3. 校验新密码；
4. Auth Admin 更新当前用户密码；
5. 撤销该身份已有 Sessions/Refresh Tokens；
6. 撤销成功后，服务端才将 membership→active；
7. 写 audit；
8. 客户端丢弃旧业务上下文并**强制重新登录**。

业务 RLS/API 还必须验证当前 Session 仍然有效。这样旧 token 尚未自然过期时也不能因为 membership 已 active 而重新获得学生数据权限。

半失败：
- 密码更新失败 → onboarding；
- 密码成功、Session 撤销失败 → onboarding；
- Session 撤销成功、membership 激活失败 → onboarding；用户用新密码重新登录后重试；
- 不存在“半失败但 active”。

### `reset_member_credential`

顺序必须保守：
1. 验证 org_admin；
2. **先 membership→onboarding**，立即切断普通业务 RLS/API；
3. 生成新随机临时密码；
4. Auth Admin 更新密码；
5. 撤销既有 Sessions（按 provider 等价能力）；
6. 刷新 `onboarding_expires_at`；
7. 写 audit；
8. 临时密码只返回一次。

如果 Auth 更新失败，账号仍 onboarding，无学生业务权限；管理员重试即可。

---

## 4. Live Session 是业务授权不变量

普通学生业务至少要求：
- 当前 Auth identity 有效；
- 当前 Session 仍被 provider 视为有效；
- organization membership = active；
- role/capability 检查成立；
- subject scope / student assignment / owner 等后续关系检查成立。

Reference Supabase：`auth.uid() + JWT session_id + auth.sessions + membership`。

Phase 0B.0 必须用 old-token negative test 证明 revoked Session 立即失败；不要只测试 UI 已退出。

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
+ 对该 student+subject 的合法 active teacher assignment 或本次合法 Lesson relationship
+ operation-specific permission
```

以下身份**单独存在时**都不能伪造教学事实：
- Subject Lead + leadership scope；
- Academic Admin；
- Org Admin；
- Student Advisor。

如果这些人员本人真实参与授课，必须另外满足 Teaching Fact Gate。

---

## 6. 学情 Case 状态机

状态严格：

```text
new → confirmed → intervening → pending_verification → stable → closed
```

`reopen` 是命令/事件，不是状态。

产品语言可把 `closed` 表达为“已清零”，但：

```text
Assessment passed ≠ stable ≠ closed
```

### `new`
- 10–20 秒快速草稿；
- 可缺 taxonomy、owner、原因、行动；
- 不能直接当成正式闭环结论。

### `confirmed`
必须同时有：
- 有效 active owner；
- owner 满足 teacher capability + matching teaching scope + 合法 Student Assignment；
- case type / taxonomy（允许“其他/暂未分类”）；
- 至少一条可解释来源的 Evidence；
- **一个 pending primary case_action**。

### 暂停不是没有下一步

如果业务上需要“先观察/暂缓”：
- `pause_reason` 解释原因；
- 同时建立 `action_type=review` pending primary action；
- review action **必须有 due_at**；
- 到期/逾期仍会进入 Today。

### `intervening`
正在实施干预，并保持 active owner + primary action。

### `pending_verification`
主要下一步应为 verify；若等待特定时间/条件，仍用有 due time 的行动表达。

### `stable`
已有证据支持改善，但仍观察。未 closed 时必须有下一次 review/verify 主行动。

### `closed`
退出主动跟进：
- 不存在 pending primary action；
- 不存在隐藏等待复查；
- 复发走 reopen。

---

## 7. 三类 Case Workflow 不改变生命周期

### Knowledge
当堂订正 → 相似题巩固 → 延迟独立验证 → stable/review/closed。

### Habit
定义可观察行为 → 干预 → 多个自然场景持续观察 → 调整/稳定。

### Exam Strategy
方法讲解 → 引导应用 → 限时/模拟迁移 → 无提示独立验证。

三阶是 knowledge 默认产品 template，不是数据库三列/三状态。不能为了“3/3 进度”篡改真实事实。

---

## 8. `confirm_case`

原子检查/完成：
1. case 仍为 new，expected_version 匹配；
2. actor 对学生/学科有编辑/确认权限；
3. owner 同机构、active、满足 Teaching relationship；
4. taxonomy 与 student subject profile 一致；
5. 至少一条 Evidence；
6. 存在合法 pending primary action；
7. 如果 action 表示暂停 review，则必须有 due_at；
8. 写 confirmed event；
9. 更新 status/version；
10. 返回最新快照。

课堂短备注可在同一 command 中生成最小 observation/classwork Evidence，避免先插 Evidence 再确认造成半成功。

---

## 9. Assessment 与 Case Status 分离

- `passed` ≠ 自动 stable；
- `passed` ≠ 自动 closed；
- failed/partial 不删除历史；
- stable/closed 由授权 owner/teacher 结合证据确认；
- Collaborator 如果不是合法 owner/command actor，不因自己做了 Assessment 就自动有 close 权；
- 状态变化必须写 Case Event。

---

## 10. 主行动不变量

一个案例可有辅助行动，但最多一个 `pending + is_primary`。

规则：
- new 可没有行动；
- confirmed/intervening/pending_verification/stable 必须有 pending primary action；
- 暂停 review action 必须有 due_at；
- assignee 同机构、membership=active 且关系合理；
- closed 不得有 pending primary action；
- 完成/取消行动保留历史；
- Guardian 不是 membership，家庭配合要求不能成为 assigned Case Action。

`replace_primary_case_action` 应在同一事务内结束旧主行动、创建新主行动并写 Case Event。

与某 Learning Case 直接相关的家校员工跟进，优先复用 `action_type=communicate`。

---

## 11. `start_lesson`

开始 Lesson 不应由 Flutter 自己拼 `lesson + lesson_students` 多次 insert。

命令至少：
1. 验证 live/active membership；
2. actor 满足 teacher capability + matching teaching scope；
3. 对目标学生有合法 Student Assignment / 被允许的代课关系；
4. organization / subject 一致；
5. 创建 `lesson(in_progress)`；
6. 创建 lesson_students；
7. 写 audit/必要 event；
8. 返回完整 Lesson context。

一对一是 1 个 lesson_student，小班可以多个。

---

## 12. `complete_lesson`

课中 Evidence / Intervention / Assessment 可逐项可靠保存，不要求等到课程完成才第一次写入云端。

`complete_lesson` 最终负责收口：
- 完成/取消旧 Action；
- 已有事实 IDs 与本次必要新增事实；
- 合法 Case transition；
- 创建下一主行动；
- 写 Case Event / audit；
- lesson→completed。

必须保证：
1. live/active teacher 权限；
2. lesson expected_version/status；
3. teacher/student/subject/organization 一致；
4. payload 不重复创建已经成功保存的事实；
5. Case transition 合法；
6. Action 不变量成立；
7. lesson completed 后无未处理的必需冲突；
8. 重复 operation 不重复副作用；
9. 返回最新快照。

完成课程不强迫所有 new 当场 confirmed；但系统要提醒长期未整理草稿。

### 小班事务边界

“整节课一个超大事务”与“逐 Student/Case reconcile 后 finalize Lesson”的最终选择留 Phase 0B.0 fault/transaction Spike。

必须满足：
- 一个学生冲突不导致已成功事实丢失；
- 不制造重复事实；
- Lesson 不在仍有必需冲突时虚假 completed；
- UI 明确指出具体哪个学生/Case 需要处理。

---

## 13. `reassign_teacher`

教师 assignment 调整必须：
- 新接手 membership active；
- 有 matching teaching scope；
- 同 organization/subject；
- 不违反 active Lead 唯一；
- 若涉及当前 Case owner/pending Action，显式处理责任转移；
- 写 assignment history + event/audit。

不能只改 `student_teacher_assignments.membership_id` 覆盖历史。

---

## 14. `revoke_teacher_subject_scope_and_handoff`

用于：老师仍在机构 active，但以后不再教某一学科。

顺序：
1. 验证治理权限；
2. inventory 该 membership + subject 下 active teacher assignments；
3. inventory active Case ownership；
4. inventory pending Actions；
5. 验证每个接手人 active + teacher capability + matching teaching scope；
6. 结束旧 assignments，建立/确认新 assignments；
7. 转移 owner/actions；
8. 验证该 teaching scope 下无 orphan active responsibility；
9. 结束/inactivate teaching scope；
10. 写 events/audit。

如果同一 membership 还有其他学科 scope，它们保持不变；不能误 disable 整个人。

Leadership scope 撤销也要检查该学科尚有无管理责任，但不能与 teaching handoff 混为一谈。

---

## 15. `disable_membership_and_handoff`

完整离职/停用：
1. inventory all active teacher/staff assignments；
2. inventory all active Case ownership；
3. inventory pending Actions；
4. inventory subject scopes；
5. 验证接手人 active 且 scope/relationship 有效；
6. 结束旧 assignments/scopes；
7. 建立/确认新关系；
8. 转移 owner/actions；
9. 写 events/audit；
10. 验证无 orphan；
11. **最后** membership→disabled；
12. revoked-session guard 使旧业务访问立即失败。

中间失败不得留下“账号已停用、当前事项无人负责”。

---

## 16. Student inactive / archive reconciliation

### `deactivate_student`
用于暂停/停止当前学习但保留未来恢复可能。

至少：
1. 验证治理权限与 expected_version（如 Student 使用）；
2. 结束/调整 current enrollment；
3. inventory teacher/staff assignments；
4. inventory active Cases；
5. 对每个 pending Action 明确：完成 / 取消 / 替换为未来 review /其他合法处理；
6. **inactive 不自动 close Case**；
7. 结束不再合理的 assignments；
8. 写 reason + audit/events；
9. 最后 Student→inactive。

### `archive_student`
只有在机构明确不再把该 Student 作为当前业务对象时执行。

必须先满足 deactivate/reconciliation 语义，且：
- 没有非法 active assignment；
- 没有会继续进入 Today 的孤立 pending Action；
- 历史仍可查询/审计；
- 不物理删除核心教学事实。

### Restart
Student 重新回来：
- 继续同一 Student ID；
- 新增/恢复 enrollment；
- 重建合法 assignments；
- 继续同一 Subject Profile 历史；
- 不因为“重新报名”创建重复 Student。

---

## 17. `merge_students(source, target)`

- source != target；
- 同机构；
- actor 有治理权限；
- 不形成 merge 环；
- enrollment/profile/assignment/Case 冲突有明确策略；
- 整体事务化或明确可恢复；
- source→merged + `merged_into_student_id`；
- 写 merge record + audit；
- operation 重试不重复迁移；
- source 不物理删除，旧 ID 仍可解释。

---

## 18. Parent Communication 命令语义

### Draft
Draft 可由有权限的 Subject Teacher / Advisor 等编辑，使用 version/expected_version；Draft 不是“已联系”。

### `finalize_parent_communication`
至少检查：
1. status=draft；
2. expected_version；
3. actor 对该 Student/subject/comprehensive context 有沟通确认权限；
4. recipient(s) 合法；
5. actual channel/occurred_at 满足当前 communication type 规则；
6. 冻结 `content_snapshot + home_support + guardian_response`；
7. 记录 finalized_by/finalized_at；
8. 创建/校验非 Case follow-up 或 Case communicate Action；
9. 写 audit；
10. 返回 finalized snapshot。

Draft 生成/复制到微信不等于 finalize；只有实际沟通发生后才作为正式历史。

### `correct_parent_communication`
Finalized 不普通 UPDATE。

严重错误需要：
- 保留旧 snapshot；
- correction reason；
- actor/time；
- 新版本/替代关系；
- audit。

不得删除“当时实际发过/说过什么”的历史解释能力。

---

## 19. Report / Stage Review 命令语义

### Draft
系统按 `period + source_cutoff_at` 整理正式事实，教师/Advisor 只补充真正需要专业判断的部分。

### `finalize_report`
至少：
1. status=draft；
2. expected_version；
3. actor 有对应 subject/comprehensive confirm 权限；
4. source_cutoff_at 已确定；
5. 冻结 content_snapshot；
6. 写 finalized_by/finalized_at；
7. 写 audit；
8. 返回 finalized snapshot。

Finalized Report 不等于已告知家长。

### `correct_report` / `supersede_report`
保留原 finalized snapshot + correction/supersede reason/actor/time。后续 Case reopen 或补录 Evidence 不静默重写旧报告。

---

## 20. 普通幂等与网络重试

### 简单 insert
客户端预生成 UUID，重试复用。

### 数据库多表命令
使用 `operation_id` / 唯一约束 / operation receipt 等方式，重复调用返回已有业务结果，不重复副作用。

### timeout unknown result
请求成功但响应丢失时：
- 先按 entity/operation_id 查询是否成功；
- 不盲目重新生成 UUID；
- 不重复 complete/action/reopen/finalize。

### Credential 命令
凭据响应是例外：不能为了可重复返回而保存明文秘密；响应未知就 reissue 新凭据。

---

## 21. 时间、并发与 finalized

系统时间：`created_at / updated_at / audit_at / finalized_at` 服务端权威。

业务发生时间：`observed_at / assessed_at / intervention occurred_at / lesson time / communication occurred_at` 可由授权用户合理修正并审计。

关键快照使用 `version / expected_version`。版本冲突必须刷新并重新确认，禁止静默 last-write-wins。

Append-only 两条合法 Evidence 可同时成功；同一 Case 状态/primary Action 的竞争修改必须只有一个 command 成功。

Finalized Parent Communication / Report 一旦成功，旧 Draft 不能继续覆盖。

---

## 22. Function 安全

- 优先 `security invoker`；
- 必须 `security definer` 时放非 exposed schema；
- `set search_path = ''`；
- schema-qualified；
- revoke 默认 execute；
- 最小 grant；
- live-session / no-membership / onboarding / disabled / cross-org / cross-subject / no-assignment / wrong-scope 均有负面测试；
- management role 不得借 function 绕过 Teaching Fact Gate；
- provider adapter 不把 service secret 暴露给 Flutter。

---

## 23. Repository API 要像业务

推荐：

```text
membershipRepository.provisionMember(...)
membershipRepository.completeOnboarding(...)
membershipRepository.resetCredential(...)
membershipRepository.disableAndHandoff(...)

assignmentRepository.reassignTeacher(...)
assignmentRepository.revokeSubjectScopeAndHandoff(...)

learningCaseRepository.confirmCase(...)
learningCaseRepository.reopenCase(...)
learningCaseRepository.replacePrimaryAction(...)

lessonRepository.startLesson(...)
lessonRepository.completeLesson(...)

studentRepository.deactivateStudent(...)
studentRepository.archiveStudent(...)
studentRepository.mergeStudents(...)

parentCommunicationRepository.finalize(...)
parentCommunicationRepository.correct(...)
reportRepository.finalize(...)
reportRepository.correct(...)
```

不要把数据库表名/任意 status string/provider API 直接暴露给 ViewModel 组合。

---

## 24. 完成定义

高风险命令上线前至少有：
- 正常路径；
- 非法状态拒绝；
- 权限拒绝；
- wrong subject scope 拒绝；
- no student assignment 拒绝；
- management-only actor 伪造 teaching fact 拒绝；
- revoked Session 拒绝；
- expected_version 冲突；
- 重复 operation；
- 响应丢失模拟；
- 跨系统/事务中间失败无越权半状态；
- 跨机构/跨学科关联拒绝；
- handoff/merge/deactivate 历史可追溯；
- finalized snapshot 不能普通 UPDATE；
- finalized correction 保留原历史；
- Student inactive/archive 后不残留 orphan Today item；
- subject scope handoff 不影响同一老师其他学科；
- 小班 Lesson 故障边界由 Phase 0B.0 Spike 证明。
