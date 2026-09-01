# 业务命令、事务与不变量

> RLS 解决“谁能访问哪一行”，但不能单独保证“这次业务变更是否合法且完整”。本文件定义哪些写入可简单追加，哪些必须通过受控命令完成。

## 1. 两类写入

### 简单事实追加
在 RLS 保护下通过 Repository → Data API，例如：
- 新增 case_evidence；
- 允许类型的普通 note/event；
- 不涉及状态变化的附件 metadata；
- 保存一个 `new` 快速捕捉草稿。

尽量：客户端预生成 UUID；重试复用同一 UUID；系统时间以服务端为准。

### 不变量敏感命令
通过受控 Database Function / 服务端命令：
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

这些操作需要同时校验权限、当前状态、并发版本、多系统/多表一致性和失败恢复。

## 2. 账号开通不等于直接获得业务权限

### `provision_member`

管理员开通教师时：
1. 从当前 Session 确认 org_admin 身份；
2. 验证目标 organization；
3. 规范化邮箱并检查目标机构已有成员；
4. 校验要授予的 roles；
5. 生成高强度随机临时密码；
6. 使用可信 Auth Admin 创建/受控处理 Auth User；
7. 对已知内部教师可设置 email confirmed，不发送确认邮件；
8. 创建 profile / `membership(onboarding)` / roles；
9. 写不含密码的 audit；
10. 临时密码只在成功响应中返回一次。

硬约束：
- 临时密码不落 PostgreSQL 业务表；
- 不写 audit/log/error tracking；
- onboarding membership 不得读取普通机构业务数据；
- 普通 teacher 无权调用该命令。

### `complete_member_onboarding`

教师用临时密码登录后：
1. 从 Session 获取可信 user_id；
2. 验证自己的 membership = onboarding；
3. 校验新密码强度；
4. 更新**当前登录用户自己的** Auth 密码；
5. 只有密码更新成功后才允许 membership → active；
6. 写不含密码的 audit；
7. 返回当前机构上下文。

Auth 与业务数据库不是同一个 PostgreSQL 事务域，因此实现必须优先保证：

> **任何半失败都不能让尚未完成凭据接管的账号提前获得 active 业务权限。**

可以通过明确顺序、幂等 operation 和恢复流程实现，不假装跨系统原子事务天然存在。

### `reset_member_credential`

管理员确认教师本人后：
1. 验证 org_admin 权限；
2. 生成新的随机临时密码；
3. 更新目标 Auth User 密码；
4. membership → onboarding；
5. 普通业务 RLS 立即因非 active 状态拒绝旧 Session；
6. 写不含密码的 audit；
7. 临时密码只返回一次；
8. 教师重新完成 onboarding。

如果中间失败，优先收敛到**没有业务权限**的状态，而不是“凭据不确定但仍 active”。

## 3. 为什么不能让客户端随便 UPDATE Case Status

拥有某 learning_case UPDATE 权限，不代表这些转移合法：

```text
new → closed
closed → intervening（没有 reopen event）
stable → closed（仍有 pending 主行动）
```

因此 Repository 暴露业务命令，不暴露“任意 status string”；数据库层再校验合法状态和约束。

## 4. 案例状态不变量

### `new`
- 10–20 秒快速捕捉草稿；
- 可暂缺 taxonomy、owner、原因和行动；
- 不能无说明直接 closed。

### `confirmed`
必须有：
- 有效 active owner；
- 正式 case type / taxonomy（允许受控“其他/暂未分类”）；
- 至少一条能解释问题来源的 evidence；
- pending 主行动，或明确 pause_reason。

Evidence 不等于必须上传文件；课堂短备注 + lesson context 可形成最小 classwork/observation evidence。

### `intervening`
存在实际干预或明确下一步干预，并保持有效责任关系。

### `pending_verification`
有 verify 主行动，或明确等待验证的受控理由。

### `stable`
至少有支持改善判断的 assessment/evidence，但不等于永久解决。

### `closed`
退出主动跟进，不存在 pending primary action。复发必须 reopen。

`reopen` 是命令/事件，不是第七个 status。

## 5. `confirm_case` 不只是改状态字符串

至少原子检查/完成：
1. case 仍为 new 且 expected_version 匹配；
2. actor 有该学生/学科编辑权限；
3. owner 同机构、membership = active、关系有效；
4. case type / taxonomy 与 subject profile 一致；
5. 至少一条 evidence；
6. 有 primary action 或 pause_reason；
7. 写 confirmed event；
8. 更新 status/version；
9. 返回最新快照。

如果确认界面只有课堂短备注，可在同一事务生成最小 evidence 后确认，避免多请求半成功。

## 6. Assessment 与 Case Status 分离

- passed ≠ 自动 stable；
- passed ≠ 自动 closed；
- failed/partial 不删除历史结果；
- stable/closed 由业务命令结合证据确认。

## 7. 主行动不变量

一个案例可有辅助行动，但通常最多一个 pending primary action。

数据库优先通过 partial unique index 或等价约束保证。

- new 豁免；
- confirmed 起无主行动时必须有 pause_reason；
- assignee 同机构、membership = active、并有合理业务关系；
- closed 不应有 pending primary action；
- 完成/取消行动保留历史。

## 8. `complete_lesson` 必须事务化

一次课结束可能同时：
- 完成旧 action；
- 新增 intervention；
- 新增 assessment；
- 写 case_event；
- 合法转移 case；
- 创建下一行动；
- lesson → completed。

一个数据库事务内：
1. 验证 active membership / lesson 权限；
2. 验证 lesson version/status；
3. 验证 lesson students / subject / organization；
4. 写本次事实；
5. 合法状态转移；
6. 完成/创建行动；
7. 写 event/audit；
8. lesson completed；
9. 返回最新快照。

完成课程不强迫所有 new 草稿立即 confirmed；少量草稿可以待整理，后续提醒。

## 9. 教师交接与停用顺序

`disable_membership_and_handoff`：
1. inventory active teacher/staff assignments；
2. active case ownership；
3. pending actions；
4. 验证接手人机构/学科关系；
5. 结束旧 assignment；
6. 建立新 assignment；
7. 转移 owner/action；
8. 写 events/audit；
9. 验证无 orphan；
10. **最后** membership → disabled。

中间失败不能留下“账号已停用但当前事项无人负责”。

密码重置与离职停用不是同一业务：重置凭据通常只把 membership 临时切回 onboarding，不删除/交接教学责任；离职才需要完整 handoff。

## 10. 学生合并不变量

`merge_students(source, target)`：
- source != target；
- 同机构；
- actor 有权限；
- 不形成 merge 环；
- current enrollment / profile / assignment / case 冲突有规则；
- 迁移事务化/可恢复；
- source → merged + merged_into_student_id；
- 写 merge record + audit；
- operation 重试不重复迁移。

合并不是删除 source，旧 ID 继续可解释。

## 11. 幂等与网络重试

### 简单 insert
客户端预生成 UUID，重试复用。

### 多表/高权限 command
携带 `operation_id`，可用 `operation_receipts` 或命令自身唯一约束。

同一 actor + operation_id 重试时返回已有结果，不重复副作用。

硬要求：**请求成功但响应丢失后，用户重试不能制造第二套事实或第二次成员开通。**

credential command 的明文密码不能放进 operation receipt；receipt 只记录非秘密结果引用/状态。

## 12. 系统时间与业务时间

### 系统时间（服务端权威）
created_at、updated_at、audit occurred_at、membership joined/activated/disabled 等默认服务端时间。

### 业务发生时间
observed_at、assessed_at、intervention occurred_at、lesson started/ended 可由用户合理修正，但不能伪造系统创建时间。

## 13. 乐观并发

对 learning_cases、lessons、必要 assignment 快照使用 `version/expected_version`。

不一致时返回 conflict，客户端刷新并让用户重新确认；绝不静默 last-write-wins。

成员管理命令也要避免两个管理员并发重复 provision/reset 造成状态互相覆盖。

## 14. Function 权限

受控命令仍必须做权限校验。

- 优先 `security invoker`；
- 需 `security definer` 时遵守非 exposed schema、空 search_path、schema-qualified、最小 grant；
- 函数内部校验 membership/organization/assignment；
- 正常和越权测试同等重要。

需要 Auth Admin Secret 的命令放 Edge Function/可信服务端，不能为了“事务方便”把 service_role 暴露给客户端。

## 15. Repository API 应像业务

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

不推荐 ViewModel 直接拼多张表 CRUD，也不把 Auth Admin API 暴露成通用客户端能力。

## 16. 完成定义

不变量敏感命令上线前必须有：
- 正常流程；
- 非法状态拒绝；
- 权限/身份拒绝；
- onboarding/active/disabled 状态测试；
- Secret/密码不进入日志的检查；
- expected_version 冲突；
- 重复 operation；
- 事务/多系统中间失败有安全恢复；
- 跨机构/跨学科关联拒绝；
- handoff/merge 历史可追溯。