# 可靠性与并发语义｜Reliability & Concurrency

> 状态：Phase 0A.6 领域事实源。定义 online-first 云端多人协作的保存、事务、草稿、冲突、重试与恢复语义；不授权进入正式数据库实现。

## 1. 核心目标

Xueqing 的可靠性目标：

> **云数据库是唯一正式事实源；网络/并发/进程失败时不丢用户输入、不制造重复事实、不静默覆盖、不留下业务半状态。**

尤其禁止两类问题：
1. 写了内容，网络一抖全没；
2. 生命周期命令做了一半，Profile/Assignment/Action 互相矛盾。

---

## 2. 用户可见保存状态

至少区分：
- 未保存；
- 保存中；
- 已保存；
- 保存失败；
- 已保留草稿；
- 版本冲突；
- 无网络；
- 正在重试（若真实发生）；
- 请求结果未知（timeout unknown result）。

禁止：
- 服务端未确认就显示“已保存”；
- 本地 Draft 当成已同步；
- timeout 后盲目重复副作用；
- 保存失败清空表单；
- 生命周期 command 失败后让客户端自己按多个 CRUD 补齐。

---

## 3. 云端事实与本地 Draft 分离

### 云端正式事实
只有服务端 committed 的 Case / Evidence / Intervention / Assessment / Action / Lesson / finalized Communication / Report 才进入正式 timeline/Today/派生统计。

### 本地 Draft
只用于恢复尚未被云端确认的输入。

Draft 必须：
- user scoped；
- organization scoped；
- screen/entity/operation scoped；
- 加密；
- TTL；
- 云端确认后清理；
- logout/account switch 有明确处理；
- 不被其他老师看到；
- 不作为正式业务查询来源。

Draft key 至少包含：

`user + organization + operation_type + target_entity/temp_uuid`

避免多个学生/Case 草稿相互覆盖。

---

## 4. 简单 append-only fact 的幂等

Evidence、普通 append-only fact、Quick Capture new Case 等：
1. 客户端预生成 UUID；
2. 第一次请求使用该 UUID；
3. timeout 后重试仍使用同一 UUID；
4. PK/unique constraint 保证不重复。

不能 timeout 后重新生成 UUID。

---

## 5. 高风险 command 的统一可靠性契约

以下不能靠多个普通 CRUD：
- Case 状态/primary Action command；
- complete_lesson；
- teacher handoff；
- subject-scope handoff；
- Student/Subject Profile deactivate/archive/unarchive/reactivate；
- Student merge；
- finalized snapshot correction。

统一要求：

```text
operation_id
+ expected_version
+ authorization / entity-state validation
+ one logical business transaction
+ final invariant validation
+ audit/event
+ atomic commit
```

### 5.1 原子提交

对于同一业务数据库事务域内的生命周期 command：

> **Profile/Student status、assignment、Case owner、primary Action、events/audit 必须全部成功一起 commit，任一失败全部 rollback。**

文档中的“步骤”只描述事务内部 staging/校验顺序，不表示中间状态可以对外 commit。

### 5.2 Committed-state invariant

任何普通查询/RLS/Today 能看到的数据库状态必须满足：

#### active Profile
- active assignment 合法；
- formal open Case 有合法 owner；
- formal open Case 有 pending primary Action。

#### inactive/archived Profile
- 无 active teacher assignment；
- unresolved Case 可保留真实 status；
- 无普通 pending primary Action；
- 不进入普通 Today；
- 不产生新教学事实/新 Lesson。

**不允许正常 command commit 中间态。**

### 5.3 Reactivate staging 示例

合法事务内部：

```text
begin
  validate inactive Profile
  stage target assignment
  stage owner
  stage primary Actions
  stage resumed events
  stage Profile=active
  validate final active invariants
commit
```

其他 Session 不能在事务中途看到：

```text
inactive Profile + active assignment
```

如果任何一步失败：rollback 后仍是原完整 inactive 状态。

### 5.4 Deactivate staging 示例

```text
begin
  validate active Profile
  inventory assignments/owners/Actions/Lesson obligations
  stage Action completion/cancel
  stage assignment end
  stage owner responsibility end
  stage suspended events
  stage Profile=inactive
  validate final inactive invariants
commit
```

任何一步失败：rollback 后原 active relationship 与 Action 仍完整。

---

## 6. `operation_id` 与 operation receipt

高风险 command 重复调用同 operation 不得重复副作用。

operation receipt / equivalent result lookup 至少能区分：
- 已完整 commit；
- 明确未执行/已 rollback；
- 当前仍执行中（如果实现允许异步 orchestration）。

业务正常路径不允许“部分 commit，等待客户端继续”的状态。

重复调用不得：
- 完成 Action 两次；
- 创建两个 primary Actions；
- 重复 end/recreate assignment；
- 重复增加 reopened_count；
- 重复 finalize；
- 重复 merge。

---

## 7. Timeout unknown result

最危险场景：服务端已经 commit，但客户端没收到 response。

客户端必须：
1. 保留原 operation_id；
2. 查询 operation/result/target version；
3. 已完整 commit → 接受最新 committed snapshot；
4. 明确未执行/rollback → 同 operation_id 安全重试；
5. 无法判断 → 继续查询/提示，不使用普通 CRUD“猜着补”。

### 生命周期 command 的判定

只接受两种业务结果：
- 完整旧状态；
- 完整新状态。

若读取到：
- inactive Profile + active assignment；
- active Profile + formal open Case 无 owner/primary Action；

这不是“正常恢复中”，而是**数据完整性缺陷/治理异常**，应阻止继续教学并进入运维修复。

---

## 8. Optimistic Concurrency

关键 aggregate 使用：

`version + expected_version`

包括：
- Learning Case；
- Lesson；
- Student Subject Profile lifecycle；
- Student lifecycle；
- editable Draft Report/Communication；
- assignment/handoff context。

如果 A 打开 version=5，B 更新到 version=6，A 再按 expected_version=5 保存：必须拒绝。

UI 要保留 A 的输入，并允许查看最新/对比/重新应用，不可 last-write-wins。

---

## 9. Append-only 并发 ≠ Aggregate 并发

两位老师同时新增各自合法 Evidence，通常都可成功。

两位老师同时对同一 Case stable/close，或同时 reactivate 同一 Profile：必须通过 expected_version/command 只允许一个成功。

不要把全系统做成“任何同时写都冲突”，也不要把关键 aggregate 做成 last-write-wins。

---

## 10. Lifecycle command failure injection｜必须执行

Phase 0B 对 `deactivate/reactivate/archive/unarchive/handoff` 至少注入：

### Reactivate
1. assignment staging 前失败；
2. assignment staging 后失败；
3. owner staging 后失败；
4. primary Action staging 第 1 个/第 N 个后失败；
5. resumed event 写入失败；
6. Profile active staging 后、commit 前 validation 失败；
7. audit 失败；
8. commit 成功但 response 丢失。

预期：
- 1–7：全部 rollback，仍是完整 inactive old state；
- 8：查询 operation_id 得到完整 active new state，不重复副作用。

### Deactivate
1. inventory 后失败；
2. Action cancel staging 后失败；
3. assignment end staging 后失败；
4. owner end staging 后失败；
5. suspended event 写失败；
6. Profile inactive staging 后 validation 失败；
7. audit 失败；
8. commit 成功 response lost。

预期：
- 1–7：全部 rollback，仍是完整 active old state；
- 8：查询得到完整 inactive new state。

### Student multi-Profile command
任一 Subject Profile reconciliation 失败：整个 Student deactivate/reactivate command 按定义 rollback，不留下部分学科“已成功”、Student 处于模糊状态。

如果 Phase 0B 最终选择显式 saga/orchestration 而非单一数据库事务，必须另写 ADR 并证明等价的不可见中间态/补偿语义；Phase 0A.6 默认基线是**单一业务 DB transaction**。

---

## 11. Lesson 中途可靠性

Lesson 可持续 1–2 小时，不应等到 complete_lesson 才第一次写所有事实。

推荐：
- Evidence / Intervention / Assessment 发生后逐项可靠保存；
- Lesson 保持 in_progress；
- Quick Capture 独立保存；
- complete_lesson 最后原子收口剩余 Case/Action/Lesson state。

complete_lesson 不重复创建前面已成功保存的事实；payload 使用已有 entity IDs / operation IDs。

---

## 12. 小班 Lesson 冲突

小班一个 Student Case version conflict 时，整 Lesson 大事务 vs per-student reconcile 后 finalize 留 Phase 0B.0 Spike。

无论哪种：
- 不重复事实；
- 不丢已确认成功数据；
- unresolved conflict 不允许 Lesson 虚假 completed；
- 教师知道具体哪个学生需处理；
- 任何 committed state 满足 Case/Action invariants。

---

## 13. App crash / process kill

验证：
- 编辑未保存文本；
- 请求发出后 App 被杀；
- 服务端 commit、response 未收到；
- App 重启。

恢复：
1. 加载 secure local Draft；
2. 查询 entity/operation 是否已 commit；
3. 已 commit → 清理 Draft；
4. 未 commit → 恢复并用同 operation_id 重试；
5. 状态未知 → 先查询，不盲目 insert/command。

---

## 14. Device switch

正式云端事实跨设备；未同步 Draft 默认仅当前设备。

Windows 不应假装知道手机上的未同步 Draft。未来若做 cloud draft，单独安全设计。

---

## 15. Auth/session 失败与 Draft

Token refresh 失败 / Session revoked：
- 立即停止业务请求；
- 不继续显示有权限的旧业务上下文；
- 未保存输入可按安全策略暂存本地；
- 强制重新认证；
- 重新认证后重新验证 membership/scope/assignment/Profile；
- Draft 恢复不得因为旧权限自动提交到新 context。

---

## 16. Finalized snapshot 并发

Communication/Report Draft version=3 被 A/B 同时打开：
- A finalize 成功；
- B 旧 Draft 不得覆盖 finalized snapshot。

Finalization：
- expected_version；
- status=draft；
- 单事务冻结 snapshot；
- finalized_by/time；
- 后续 correction/supersede。

---

## 17. Offline 边界

V1 online-first，不做 offline-first。

无网络可：
- 保留输入；
- 加密 local Draft；
- 明示“尚未同步”；
- 恢复网络后安全重试。

不承诺：
- 离线完整学生库；
- 多实体复杂离线 merge；
- CRDT；
- 长期离线工作。

---

## 18. Error taxonomy

Infrastructure adapter 至少统一：
- `network_unavailable`
- `timeout_unknown_result`
- `unauthenticated`
- `permission_denied`
- `version_conflict`
- `validation_failed`
- `operation_already_completed`
- `transaction_rolled_back`
- `integrity_anomaly`
- `storage_failed`
- `server_unavailable`
- `unknown`

Vendor error string 不直接进入 UI。

---

## 19. Telemetry / logs

允许必要排错字段：
- operation_id；
- entity type/id（必要时脱敏）；
- error category；
- request timing；
- app version；
- provider region；
- retry count；
- transaction outcome：committed / rolled_back / unknown_result。

禁止日志：Password、access/refresh Token、service role、学生敏感正文、家校正文、Draft 明文。

---

## 20. Phase 0B 故障矩阵

至少测试：
1. 请求发出前断网；
2. commit 成功 response lost；
3. timeout 后同 operation_id 重试；
4. App 保存时 kill；
5. 两设备同时改 Case；
6. 两管理员同时 reactivate Profile；
7. Reactivate assignment/owner/Action 各阶段失败 rollback；
8. Deactivate Action/assignment/owner 各阶段失败 rollback；
9. Student 多 Profile reconciliation 中途失败 rollback；
10. revoked Session + local Draft；
11. Storage object 成功、DB metadata 失败；
12. DB metadata 成功、object 获取失败；
13. provider 5xx；
14. Android Wi-Fi/蜂窝切换；
15. Windows sleep/resume；
16. lifecycle command committed-state invariant scan。

---

## 21. 当前冻结结论

- 云端是唯一正式事实源；local Draft 只恢复输入。
- 生命周期多实体 command 默认单一业务数据库事务。
- 中间 staging 不对外可见；commit 后一次满足完整不变量。
- 任一步失败全 rollback；timeout 用 operation_id 查询，不靠客户端补半状态。
- append-only 与 mutable aggregate 使用不同并发策略。
- version + expected_version 防 last-write-wins。
- Reactivate/deactivate 必须专项 failure injection。
- Lesson 事实逐步可靠保存，completion 负责收口。
- 小班 Lesson 事务形态留 Phase 0B.0 Spike。
- Provider-specific errors 在 infrastructure 层归一化。
