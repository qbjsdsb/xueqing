# 业务命令、事务与不变量

> RLS 解决“谁能访问哪一行”，但不能单独保证业务状态合法。本文件定义哪些写入可以直接追加，哪些必须通过受控命令完成。

## 1. 两类写入

### A. 简单事实追加
适合在 RLS 保护下通过 Repository → Data API 完成，例如：
- 新增一条 case_evidence；
- 新增一条普通 note/event（按允许类型）；
- 新增一个不涉及状态变化的附件 metadata。

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
- 客户端 Repository 暴露 `confirmCase()` / `reopenCase()` / `markStable()` 等业务命令；
- 不向 ViewModel 暴露“随便 update status string”；
- 数据库层使用函数、约束或 trigger 再做一次合法性校验；
- 对 status 等敏感列考虑限制直接 UPDATE 权限。

## 3. 案例状态不变量

至少保证：

### `new`
- 是快速捕捉/草稿态；
- 可以暂时没有 taxonomy、原因判断或主行动；
- 可以补证据/描述；
- 不能无说明直接 closed。

### `confirmed`
- 应有负责人；
- 已满足正式分类等确认条件；
- 应有主行动或明确 pause_reason。

### `intervening`
- 存在真实干预或明确下一步干预。

### `pending_verification`
- 应有 verify 类型主行动，或明确等待某次验证。

### `stable`
- 至少存在支持改善判断的 assessment/evidence；
- 不等于永久解决；
- 可以保留复查行动；若暂无行动，应明确观察/暂停原因。

### `closed`
- 退出主动跟进；
- 不应存在 pending `is_primary = true` 主行动；
- 后续复发必须通过 reopen，而不是直接改回 intervening。

`reopen` 是命令/事件，不是第七个 status。

## 4. 验证结果与案例状态分离

`assessment.result` 是一次检测事实；`learning_case.status` 是当前管理状态。

因此：
- passed ≠ 自动 stable；
- passed ≠ 自动 closed；
- failed 通常触发继续干预/原因复盘，但不能删除以前的 passed；
- stable/closed 应由业务命令在检查证据后转移。

## 5. 主行动不变量

一个案例可以存在多条辅助行动，但通常最多一个 pending primary action。

建议数据库通过 partial unique index 约束类似：

```sql
unique (learning_case_id)
where status = 'pending' and is_primary = true
```

具体 SQL 以 migration 实现为准。

规则：
- `new` 快速草稿明确豁免“必须立即有主行动”；
- 从 `confirmed` 开始的主动跟进案例，如果没有 pending 主行动，必须有明确 `pause_reason` 或状态本身的受控理由；
- `closed` 不应存在 pending 主行动。

这样既保证课堂快速捕捉，又避免正式案例进入“没人知道下一步”的黑洞。

## 6. 完成课程为什么应是事务命令

一次课结束可能同时发生：
- 完成旧 case_action；
- 新增 intervention；
- 新增 assessment；
- 写 case_event；
- 改 case status；
- 新建下一步 action；
- lessons.status → completed。

如果客户端逐条请求，第三步失败时可能得到半套数据。

因此成熟 V1 优先提供类似：

```text
complete_lesson(command)
```

在一个数据库事务中：
1. 验证 teacher/membership/lesson 权限；
2. 验证 lesson 当前 version/status；
3. 写事实；
4. 执行合法状态转移；
5. 完成/创建行动；
6. 写必要 event/audit；
7. 标记 lesson completed；
8. 返回最新快照。

UI 可以仍然是简单的“完成本次课”。

## 7. 幂等与网络重试

移动网络下常见场景：
- 请求已经到数据库并成功；
- 响应回客户端前网络断了；
- 用户点击“重试”。

如果没有幂等设计，可能重复新增两条 intervention/assessment。

### 简单 insert
客户端预生成 UUID；重试复用同一 ID。

### 多表 command
command 带 `operation_id`。

可以使用 `operation_receipts` 或等价机制：
- `operation_id`
- `organization_id`
- `actor_membership_id`
- `operation_type`
- `status`
- `created_at`

同一 actor + operation_id 重试时返回已有结果，不重复执行副作用。

是否落专门表在实现 Spike 后决定，但“重试不能制造重复事实”是硬要求。

## 8. 系统时间与业务时间

区分：

### 系统时间（服务器权威）
- created_at
- updated_at
- audit occurred_at（系统动作）
- membership joined/disabled timestamp

默认数据库 `now()`，不信任客户端随意传入。

### 业务发生时间（允许教师记录）
- evidence observed_at
- assessment assessed_at
- intervention occurred_at
- lesson started_at/ended_at

允许用户修正，但应有合理范围/审计，不能用它伪造系统创建时间。

## 9. 乐观并发

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

## 10. 事务函数的权限

受控 command 不代表可以绕过权限。

Database Function：
- 能用 `security invoker` 就优先使用；
- 需要 `security definer` 时按安全基线限制；
- 函数内部仍检查 membership/organization/assignment；
- 只 grant 给需要的角色；
- 负面权限测试与正常测试同等重要。

## 11. Repository API 应该像业务，而不是像数据库

推荐：

```text
learningCaseRepository.confirmCase(...)
learningCaseRepository.reopenCase(...)
learningCaseRepository.replacePrimaryAction(...)
lessonRepository.completeLesson(...)
```

不推荐让 ViewModel 到处调用：

```text
update('learning_cases', {'status': 'closed'})
insert('case_events', ...)
update('case_actions', ...)
```

前者可以集中维护业务语义，后者极易让不同页面产生不同规则。

## 12. 完成定义

任何不变量敏感命令上线前必须有：
- 正常状态转移测试；
- 非法状态转移拒绝测试；
- 权限拒绝测试；
- expected_version 冲突测试；
- 网络重试/重复 operation 测试；
- 事务中间失败不会留下半套数据的验证。