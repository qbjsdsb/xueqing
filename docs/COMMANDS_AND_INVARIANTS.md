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
- `accept_invitation`
- `confirm_case`
- `transition_case`
- `reopen_case`
- `replace_primary_case_action`
- `complete_case_action`
- `complete_lesson`
- `reassign_teacher`
- `merge_students`
- `disable_membership_and_handoff`

这些操作需要同时校验权限、当前状态、并发版本和多表一致性。

## 2. Auth 登录不是 Membership 创建

Email OTP 成功只建立 Auth Session。

`accept_invitation(invitation_id, operation_id)` 必须在受控事务中：
1. 从当前 Session 获取可信 `auth.uid()` 和 verified email；
2. 锁定 invitation；
3. 验证 `status = pending`；
4. 规范化比较 invitation email 与当前 verified email；
5. 验证 organization 仍有效；
6. 验证 invitation roles 仍允许授予；
7. 插入或取得唯一 `(organization_id, user_id)` membership；
8. 确保 membership 为 active；
9. 创建缺失 membership_roles；
10. invitation → accepted，记录 accepted_by_user_id/accepted_at；
11. 写 audit；
12. 返回 organization/membership context。

### 幂等要求
- 同一用户重复提交同一 invitation，返回已有结果；
- 不能创建第二个 membership；
- 不同 verified email 不能接受；
- cancelled invitation 不能接受；
- 如果已有 active membership，同一 invitation 可以安全收敛到“已加入”而不是报一半错误。

pending invitation 本身绝不能成为 RLS 业务访问凭据。

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
- 有效 owner；
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
3. owner 同机构且关系有效；
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
- assignee 同机构并有合理业务关系；
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

一个事务内：
1. 验证 membership/lesson 权限；
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

### 多表 command
携带 `operation_id`，可用 `operation_receipts` 或命令自身唯一约束。

同一 actor + operation_id 重试时返回已有结果，不重复副作用。

硬要求：**请求成功但响应丢失后，用户重试不能制造第二套事实。**

## 12. 系统时间与业务时间

### 系统时间（服务端权威）
created_at、updated_at、audit occurred_at、membership joined/disabled 等默认 `now()`。

### 业务发生时间
observed_at、assessed_at、intervention occurred_at、lesson started/ended 可由用户合理修正，但不能伪造系统创建时间。

## 13. 乐观并发

对 learning_cases、lessons、必要 assignment 快照使用 `version/expected_version`。

不一致时返回 conflict，客户端刷新并让用户重新确认；绝不静默 last-write-wins。

## 14. Function 权限

受控命令仍然必须做权限校验。

- 优先 `security invoker`；
- 需 `security definer` 时遵守非 exposed schema、空 search_path、schema-qualified、最小 grant；
- 函数内部校验 membership/organization/assignment；
- 正常和越权测试同等重要。

## 15. Repository API 应像业务

推荐：

```text
authRepository.acceptInvitation(...)
learningCaseRepository.confirmCase(...)
learningCaseRepository.reopenCase(...)
learningCaseRepository.replacePrimaryAction(...)
lessonRepository.completeLesson(...)
studentRepository.mergeStudents(...)
membershipRepository.disableAndHandoff(...)
```

不推荐 ViewModel 直接拼多张表 CRUD。

## 16. 完成定义

不变量敏感命令上线前必须有：
- 正常流程；
- 非法状态拒绝；
- 权限拒绝；
- verified-email/identity 校验（Auth 命令）；
- expected_version 冲突；
- 重复 operation；
- 事务中间失败无半套数据；
- 跨机构/跨学科关联拒绝；
- handoff/merge 历史可追溯。