# 业务命令、事务与不变量

> RLS 解决“谁能访问哪一行”，但不能单独保证业务状态合法。本文件定义哪些写入可以直接追加，哪些必须通过受控命令完成。

## 1. 两类写入

### A. 简单事实追加
适合在 RLS 保护下通过 Repository → Data API 完成，例如：
- 新增一条 case_evidence；
- 新增允许类型的普通 note/event；
- 新增不涉及状态变化的附件 metadata；
- 保存一个 `new` 快速捕捉草稿。

这些写入应尽量：
- client 预生成 UUID；
- retry 时复用同一 UUID；
- 服务端 created_at 为准。

### B. 不变量敏感命令
必须通过受控 Database Function / 服务端 command 完成，例如：
- `confirm_case`
- `transition_case`
- `reopen_case`
- `replace_primary_case_action`
- `complete_case_action`
- `complete_lesson`
- `reassign_teacher`
- `merge_students`
- `disable_membership_and_handoff`

原因：这些操作通常需要同时校验当前状态、权限和多表一致性。

## 2. 为什么不能让客户端随便 UPDATE status

例如教师拥有某 learning_case 的 UPDATE 权限，并不意味着下面操作都合法：

```text
new → closed
closed → intervening（却没有 reopen event）
stable → closed（仍有 pending 主行动）
```

因此：
- Repository 暴露 `confirmCase()` / `reopenCase()` / `markStable()` 等业务命令；
- 不向 ViewModel 暴露“随便 update status string”；
- 数据库层使用函数、约束或 trigger 再做合法性校验；
- 对 status、owner 等敏感列考虑限制普通直接 UPDATE。

## 3. 案例状态不变量

### `new`
- 是快速捕捉/草稿态；
- 可以暂时没有完整 taxonomy、owner、原因判断或主行动；
- 可以补证据/描述；
- 不能无说明直接 closed。

### `confirmed`
必须满足：
- 有有效 owner；
- 有正式 case type / taxonomy（允许受控“其他/暂未分类”）；
- 至少一条能解释“为什么建立这个案例”的 evidence；
- 有 pending 主行动，或有明确 pause_reason。

注意：evidence 不等于必须上传文件。课堂短备注 + lesson context 可以形成最小 observation/classwork evidence。

### `intervening`
- 存在真实干预，或有明确下一步干预行动；
- owner 仍应具有有效责任关系，除非正在受控交接。

### `pending_verification`
- 应有 verify 类型主行动，或有明确等待验证的受控理由。

### `stable`
- 至少存在支持改善判断的 assessment/evidence；
- 不等于永久解决；
- 可以保留复查行动；若暂无行动，应有明确观察/暂停语义。

### `closed`
- 退出主动跟进；
- 不应存在 pending `is_primary = true` 主行动；
- 后续复发必须通过 reopen，而不是直接改回 intervening。

`reopen` 是命令/事件，不是第七个 status。

## 4. `confirm_case` 应做什么

`confirm_case` 不是“把 status 字符串从 new 改成 confirmed”。

至少应原子检查/完成：
1. 当前 case 仍为 `new` 且 expected_version 匹配；
2. actor 对该学生/学科有编辑权限；
3. owner 属于同一 organization，并具有合理 assignment/管理关系；
4. case type / taxonomy 合法且与 subject profile 对应；
5. 至少存在一条 evidence；
6. 有 pending primary action，或 pause_reason；
7. 写 `confirmed` case_event；
8. 更新 case status/version；
9. 返回最新快照。

如果用户在确认界面输入的是“课堂短备注”，命令可以在同一事务中先生成最小 evidence，再完成确认，减少多请求半成功。

## 5. 验证结果与案例状态分离

`assessment.result` 是一次检测事实；`learning_case.status` 是当前管理状态。

因此：
- passed ≠ 自动 stable；
- passed ≠ 自动 closed；
- failed 通常触发继续干预/原因复盘，但不能删除以前的 passed；
- stable/closed 应由业务命令在检查证据后转移。

## 6. 主行动不变量

一个案例可以存在多条辅助行动，但通常最多一个 pending primary action。

建议 partial unique index 类似：

```sql
unique (learning_case_id)
where status = 'pending' and is_primary = true
```

具体 SQL 以 migration 为准。

规则：
- `new` 快速草稿豁免“必须立即有主行动”；
- 从 `confirmed` 开始，如果没有 pending 主行动，必须有明确 `pause_reason` 或受控状态理由；
- pending action assignee 必须属于同一机构，并对学生/案例具有合理业务关系；
- `closed` 不应存在 pending 主行动。

## 7. 完成课程为什么应是事务命令

一次课结束可能同时发生：
- 完成旧 case_action；
- 新增 intervention；
- 新增 assessment；
- 写 case_event；
- 合法改变 case status；
- 新建下一步 action；
- lessons.status → completed。

如果客户端逐条请求，第三步失败时可能得到半套数据。

因此成熟 V1 优先提供：

```text
complete_lesson(command)
```

一个事务内：
1. 验证 teacher/membership/lesson 权限；
2. 验证 lesson version/status；
3. 验证 lesson students 与 subject/organization 一致；
4. 写本次真实事实；
5. 执行合法状态转移；
6. 完成/创建行动；
7. 写必要 event/audit；
8. 标记 lesson completed；
9. 返回最新快照。

UI 仍然可以只是简单的“完成本次课”。

### `new` 草稿如何处理
完成课程不要求所有新草稿都立刻 confirmed。

允许：
- 用户在课后确认重要草稿；
- 暂时保留少量 `new` 待整理；
- UI 在后续“今日/学情”中提醒长期未整理草稿。

不要为了“课程必须一次性清空”逼老师在下课瞬间补全所有诊断字段。

## 8. 教师交接与停用必须顺序正确

`disable_membership_and_handoff` 的目标不是简单 `membership.status = disabled`。

应先：
1. 锁定/读取该成员 active teacher/staff assignments；
2. 找到 active learning_case ownership；
3. 找到 pending case_actions；
4. 验证目标接手人员拥有正确机构/学科关系；
5. 结束旧 assignment；
6. 建立新 assignment；
7. 转移当前 owner/action；
8. 写 owner/assignment events + audit；
9. 验证没有意外 orphan 责任项；
10. 最后 membership → disabled。

如果交接中间失败，不能出现“账号已停用，但一堆当前任务无人负责”。

## 9. 学生合并不变量

`merge_students(source, target)` 至少保证：
- source != target；
- 同一 organization；
- actor 有合并权限；
- target 不是 merged source；
- 不形成 merge 环；
- 当前 enrollment / subject profile / assignment / case 等冲突有明确解决规则；
- 迁移过程事务化或有可验证恢复方案；
- source.status → merged；
- source.merged_into_student_id → target；
- 写 student_merge_record + audit；
- operation_id 重试不会重复迁移。

合并不是“删掉 source”。旧 ID 必须继续可解释。

## 10. 幂等与网络重试

移动网络下常见：
- 请求已成功；
- 响应返回前网络断开；
- 用户点击重试。

没有幂等设计会重复产生 intervention/assessment/action。

### 简单 insert
客户端预生成 UUID；重试复用同一 ID。

### 多表 command
command 带 `operation_id`。

可使用 `operation_receipts` 或命令实体上的唯一 operation id：
- `operation_id`
- `organization_id`
- `actor_membership_id`
- `operation_type`
- `status`
- `result_reference`
- `created_at`

同一 actor + operation_id 重试时返回已有结果，不重复副作用。

“重试不能制造重复事实”是硬要求，具体 receipt 结构可在实现 Spike 后确定。

## 11. 系统时间与业务时间

### 系统时间（服务器权威）
- created_at
- updated_at
- audit occurred_at
- membership joined/disabled timestamp

默认数据库 `now()`，不信任客户端随意传入。

### 业务发生时间（允许教师记录）
- evidence observed_at
- assessment assessed_at
- intervention occurred_at
- lesson started_at/ended_at

允许用户修正，但应有合理范围/审计，不能用它伪造系统创建时间。

## 12. 乐观并发

对会被多人修改的当前快照：
- learning_cases
- lessons
- 某些 assignment 当前关系

使用 `version` 或等价条件更新。

命令携带 `expected_version`：
- 一致 → 执行并 version + 1；
- 不一致 → 返回 conflict；
- 客户端刷新并让用户重新确认。

绝不静默 last-write-wins 覆盖关键状态。

## 13. 事务函数的权限

受控 command 不代表可以绕过权限。

Database Function：
- 能用 `security invoker` 就优先；
- 需要 `security definer` 时按安全基线限制；
- 内部仍检查 membership/organization/assignment；
- 只 grant 给需要角色；
- 负面权限测试与正常测试同等重要。

## 14. Repository API 应该像业务，而不是像数据库

推荐：

```text
learningCaseRepository.confirmCase(...)
learningCaseRepository.reopenCase(...)
learningCaseRepository.replacePrimaryAction(...)
lessonRepository.completeLesson(...)
studentRepository.mergeStudents(...)
membershipRepository.disableAndHandoff(...)
```

不推荐让 ViewModel 到处调用：

```text
update('learning_cases', {'status': 'closed'})
insert('case_events', ...)
update('case_actions', ...)
```

前者集中维护业务语义，后者极易让不同页面产生不同规则。

## 15. 完成定义

任何不变量敏感命令上线前必须有：
- 正常状态转移测试；
- 非法状态转移拒绝测试；
- 权限拒绝测试；
- expected_version 冲突测试；
- 网络重试/重复 operation 测试；
- 事务中间失败不会留下半套数据的验证；
- 跨机构/跨学科关联被拒绝；
- 对 handoff/merge 这类治理操作验证历史仍可追溯。