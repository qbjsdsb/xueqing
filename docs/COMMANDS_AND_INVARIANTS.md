# 业务命令、事务与不变量

> RLS 解决“谁能访问”，约束/事务命令解决“这次修改是否完整、合法、可重试”。V1 不允许 ViewModel 靠多次普通 CRUD 拼出高风险业务状态。

## 1. 两类写入

### 简单事实追加
在 RLS 保护下可由 Repository → Data API：
- 新增 evidence；
- 允许类型的普通 note/event；
- 单条附件 metadata；
- 保存 `new` 快速捕捉草稿。

原则：客户端预生成 UUID，重试复用；服务端时间为系统时间事实源。

### 不变量敏感命令
必须走受控 Database Function / Edge Function / 可信服务端：
- `provision_member`
- `complete_member_onboarding`
- `reset_member_credential`
- `confirm_case`
- `transition_case`
- `reopen_case`
- `replace_primary_case_action`
- `complete_case_action`
- `complete_lesson`
- `reassign_teacher`
- `merge_students`
- `disable_membership_and_handoff`

---

## 2. Credential 命令不是普通 CRUD

Auth Admin 与业务 PostgreSQL 不在同一个事务域，所以 credential 命令的目标不是“假装原子”，而是：

> **无论在哪一步失败，都优先收敛到没有学生业务权限的状态。**

### `provision_member`

顺序：
1. 验证 live Session、org_admin 与目标 organization；
2. 规范化邮箱、验证 roles；
3. 检查已有 member / 可恢复的既有 Auth User；
4. 生成随机临时密码；
5. Auth Admin 创建/更新受控 Auth User；
6. 创建 profile、`membership(onboarding)`、roles、`onboarding_expires_at`；
7. audit 不包含密码；
8. 临时密码只在成功响应显示一次。

如果 Auth User 已创建但 DB 写入失败，允许留下**无 membership Auth User**，因为它没有业务权限；后续必须有明确恢复路径。

### provision 的特殊“幂等”规则

credential 明文故意不持久化，因此不能要求“同 operation_id 再次返回同一临时密码”。

如果后端已成功但响应丢失：
- member 仍 onboarding；
- 返回/展示 `credential_delivery_unknown` 或等价状态；
- 管理员执行 reissue/reset，生成一个**新的**临时密码；
- 旧临时密码因 Auth 密码更新失效；
- 绝不为方便重试而保存可找回的明文密码。

### `complete_member_onboarding`

1. 验证当前 JWT、`auth.uid()`、`session_id` 与 membership=onboarding；
2. 检查 `onboarding_expires_at`；
3. 校验新密码；
4. Auth Admin 更新当前用户密码；
5. 使用当前登录 JWT 执行 **global sign-out**；
6. global sign-out 成功后，服务端才将 membership→active；
7. 写 audit；
8. 客户端丢弃旧业务上下文并**强制重新登录**。

业务 RLS 还必须验证当前 JWT `session_id` 对应的 `auth.sessions` 记录仍存在。这样 global sign-out 后，即使 Access Token 尚未到 `exp`，也不能因为 membership 已 active 而重新获得学生数据权限。

半失败：
- 密码更新失败 → onboarding；
- 密码成功、global sign-out 失败 → onboarding；
- sign-out 成功、membership 激活失败 → onboarding；用户用新密码重新登录后重试；
- 不存在“半失败但 active”。

### `reset_member_credential`

顺序必须保守：
1. 验证 org_admin；
2. **先 membership→onboarding**，立即切断普通业务 RLS；
3. 生成新随机临时密码；
4. Auth Admin 更新密码；
5. 刷新 `onboarding_expires_at`；
6. 写 audit；
7. 临时密码只返回一次。

如果 Auth 更新失败，账号仍 onboarding，无学生业务权限；管理员重试即可。

reset 响应丢失时也走重新签发，不保存明文凭据来满足重复返回。

---

## 3. Live Session 是业务授权不变量

普通学生业务至少要求：
- `auth.uid()` 存在；
- JWT 有合法 `session_id`；
- `auth.sessions` 中对应 Session 仍存在；
- organization membership = active；
- 后续 role / assignment 检查成立。

Phase 0 要用非 exposed helper + RLS tests 验证 revoked Session 立即失败；不要只测试 UI 已退出。

---

## 4. 学情 Case 状态机

状态：

```text
new → confirmed → intervening → pending_verification → stable → closed
```

`reopen` 是命令/事件，不是状态。

### `new`
- 10–20 秒快速草稿；
- 可缺 taxonomy、owner、原因、行动；
- 不能直接当成正式闭环结论。

### `confirmed`
必须同时有：
- 有效 active owner；
- case type / taxonomy（允许“其他/暂未分类”）；
- 至少一条可解释来源的 evidence；
- **一个 pending primary case_action**。

不再允许“只填 pause_reason、没有下一次检查”这种会永远从 Today 消失的正式案例。

### 暂停不是没有下一步

如果业务上需要“先观察/暂缓”：
- 可填写 `pause_reason` 解释为什么暂缓；
- 同时建立 `action_type = review` 的 pending primary action；
- 该 review action **必须有 `due_at`**；
- 到期/逾期仍会进入 Today。

因此 `pause_reason` 是解释，不是替代下一步行动的第二套事实源。

### `intervening`
正在实施干预，并保持 active owner + primary action。

### `pending_verification`
主要下一步应为 `verify` action；若等待特定时间/条件，仍用有到期时间的行动表达。

### `stable`
已有证据支持改善，但仍观察。若尚未关闭，必须有下一次 `review/verify` 主行动；不能“稳定后无人再看”。

### `closed`
退出主动跟进：
- 不存在 pending primary action；
- 不存在“暂停等待复查”的隐含状态；
- 复发走 reopen。

---

## 5. `confirm_case`

原子检查/完成：
1. case 仍为 new，expected_version 匹配；
2. actor 对学生/学科有编辑权限；
3. owner 同机构、active、关系有效；
4. taxonomy 与 student subject profile 一致；
5. 至少一条 evidence；
6. 存在合法 pending primary action；
7. 如果 action 表示暂停 review，则必须有 due_at；
8. 写 confirmed event；
9. 更新 status/version；
10. 返回最新快照。

课堂短备注可在同一事务中生成最小 observation/classwork evidence，避免先插 evidence 再确认造成半成功。

---

## 6. Assessment 与 Case Status 分离

- `passed` ≠ 自动 stable；
- `passed` ≠ 自动 closed；
- failed/partial 不删除历史；
- stable/closed 由授权教师结合证据确认；
- 状态变化必须写 case event。

---

## 7. 主行动不变量

一个案例可有辅助行动，但最多一个 `pending + is_primary`。

数据库优先用 partial unique index/受控命令保证。

规则：
- new 可没有行动；
- confirmed/intervening/pending_verification/stable 必须有 pending primary action；
- 暂停 review action 必须有 due_at；
- assignee 同机构、membership=active 且关系合理；
- closed 不得有 pending primary action；
- 完成/取消行动保留历史。

`replace_primary_case_action` 应在同一事务内结束旧主行动、创建新主行动并写 case event，不能出现两个当前主行动。

---

## 8. `complete_lesson`

一次课结束可能同时：
- 完成旧 action；
- 新增 intervention；
- 新增 assessment；
- 写 case event；
- 合法转移 case；
- 创建下一主行动；
- lesson → completed。

必须一个数据库事务内完成：
1. active/live member 权限；
2. lesson version/status；
3. teacher/student/subject/organization 一致；
4. 写教学事实；
5. 合法 case transition；
6. 替换/完成行动；
7. 写 event/audit；
8. lesson completed；
9. 返回最新快照。

完成课程不强迫所有 `new` 当场 confirmed；但系统要提醒长期未整理草稿。

---

## 9. 教师交接与停用

`disable_membership_and_handoff`：
1. inventory active teacher/staff assignments；
2. active case ownership；
3. pending case_actions；
4. 验证接手人 active/live 且机构/学科关系有效；
5. 结束旧 assignment；
6. 建立新 assignment；
7. 转移 owner/action；
8. 写 events/audit；
9. 验证无 orphan；
10. **最后** membership→disabled。

中间失败不得留下“账号已停用、当前事项无人负责”。

---

## 10. 学生合并

`merge_students(source, target)`：
- source != target；
- 同机构；
- actor 有治理权限；
- 不形成 merge 环；
- enrollment/profile/assignment/case 冲突有明确策略；
- 整体事务化或明确可恢复；
- source→merged + `merged_into_student_id`；
- 写 merge record + audit；
- operation 重试不重复迁移。

source 不物理删除，旧 ID 仍可解释。

---

## 11. 普通幂等与网络重试

### 简单 insert
客户端预生成 UUID，重试复用。

### 数据库多表命令
使用 `operation_id` / 唯一约束 / operation receipt 等方式，重复调用返回已有业务结果，不重复副作用。

### Credential 命令
凭据响应是例外：**不能为了可重复返回而保存明文秘密。** 响应未知就 reissue 新凭据。

硬要求：请求成功但响应丢失，重试不得制造两套教学事实；credential 则不得制造“找回旧密码”的秘密存储。

---

## 12. 时间与并发

系统时间：`created_at / updated_at / audit_at` 服务端权威。

业务发生时间：`observed_at / assessed_at / intervention occurred_at / lesson time` 可由授权用户合理修正。

关键快照使用 `version / expected_version`。版本冲突必须刷新并重新确认，禁止静默 last-write-wins。

---

## 13. Function 安全

- 优先 `security invoker`；
- 必须 `security definer` 时放非 exposed schema；
- `set search_path = ''`；
- schema-qualified；
- revoke 默认 execute；
- 最小 grant；
- live-session / no-membership / onboarding / disabled / cross-org / cross-subject 均有负面测试。

---

## 14. Repository API 要像业务

推荐：

```text
membershipRepository.provisionMember(...)
membershipRepository.completeOnboarding(...)
membershipRepository.resetCredential(...)
learningCaseRepository.confirmCase(...)
learningCaseRepository.reopenCase(...)
learningCaseRepository.replacePrimaryAction(...)
lessonRepository.completeLesson(...)
studentRepository.mergeStudents(...)
membershipRepository.disableAndHandoff(...)
```

不要把数据库表名/任意 status string 直接暴露给 ViewModel 组合。

---

## 15. 完成定义

高风险命令上线前至少有：
- 正常路径；
- 非法状态拒绝；
- 权限拒绝；
- revoked Session 拒绝；
- expected_version 冲突；
- 重复 operation；
- 响应丢失模拟；
- 跨系统/事务中间失败无越权半状态；
- 跨机构/跨学科关联拒绝；
- handoff/merge 历史可追溯。
