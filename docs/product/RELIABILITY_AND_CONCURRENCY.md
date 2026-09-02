# 可靠性与并发语义｜Reliability & Concurrency

> 状态：Phase 0A.6 领域事实源。本文定义 online-first 云端多人协作必须满足的保存、草稿、冲突、重试与恢复语义；不授权进入正式数据库实现。

## 1. 核心目标

老师最不能接受两种情况：

1. 写了内容，网络一抖全没了；
2. 明明保存成功，另一个老师一操作又把它悄悄覆盖了。

因此 Xueqing 的可靠性目标不是“离线功能很多”，而是：

> **云数据库是唯一正式事实源；网络/并发失败时不丢用户输入、不制造重复事实、不静默覆盖别人的新事实。**

---

## 2. 状态必须说人话

用户可见保存状态至少区分：

- 未保存；
- 保存中；
- 已保存；
- 保存失败；
- 已保留草稿；
- 版本冲突；
- 无网络；
- 正在重试（若真实发生）。

禁止：
- 请求还没收到服务端确认就显示“已保存”；
- 本地草稿存在就显示“已同步”；
- 把 timeout 当成业务失败并立即重复 insert；
- 保存失败后清空表单。

---

## 3. 云端事实与本地草稿严格分离

### 云端正式事实
只有服务端确认成功的：
- Case；
- Evidence；
- Intervention；
- Assessment；
- Action；
- Lesson completion；
- finalized communication/report；

才进入正式 timeline / Today /派生统计。

### 本地 Draft
只用于恢复用户尚未被云端确认的输入。

Draft 必须：
- user scoped；
- organization scoped；
- screen/entity/operation scoped；
- 加密保存；
- 有 TTL；
- 云端确认后清理；
- logout / account switch 有明确处理；
- 不被其他老师看到；
- 不作为正式业务查询来源。

---

## 4. Draft key 不能只按页面名

错误示例：

`draft:case-edit`

如果老师连续打开两个学生，容易覆盖。

推荐逻辑 key 至少包含：

`user + organization + operation_type + target_entity/temp_uuid`

例如：

`teacher_1/org_a/edit_case/case_123`

`teacher_1/org_a/quick_capture/temp_uuid_456`

这样同一用户多个未完成操作可安全区分。

---

## 5. 简单追加事实的幂等

Evidence、普通 append-only fact、Quick Capture new Case 等适合：

1. 客户端预生成 UUID；
2. 第一次请求使用该 UUID；
3. timeout 后重试仍使用同一 UUID；
4. unique PK/operation constraints 保证不会生成两条。

不能 timeout 后重新生成 UUID 再 insert，否则“服务器其实成功但响应丢了”会制造重复事实。

---

## 6. 高风险命令的幂等

以下不能靠多次普通 CRUD：
- confirm_case；
- replace_primary_case_action；
- transition/reopen_case；
- complete_lesson；
- teacher handoff；
- subject-scope handoff；
- merge_students；
- finalized snapshot correction。

命令应使用：
- `operation_id`；
- expected_version；
- 唯一约束/operation receipt（按需要）；
- 数据库事务。

重复调用同 operation 不得：
- 完成 action 两次；
- 创建两个 next primary action；
- 重复增加 reopened_count；
- 重复迁移学生数据；
- 重复 finalize 同一 draft。

---

## 7. Optimistic Concurrency

关键可变聚合使用：

`version + expected_version`

典型：
- Learning Case；
- Lesson；
- editable Draft Report/Communication（若多人可编辑）；
- assignment/handoff command context。

### 场景
王老师打开 Case version=5。

期间李老师更新，云端变 version=6。

王老师再保存 expected_version=5：

**必须拒绝。**

UI：

> 李老师刚刚更新了这个学情。你当前页面不是最新版本。

提供：
- 查看最新内容；
- 保留我的输入；
- 对比后重新应用；
- 放弃我的修改。

禁止 last-write-wins。

---

## 8. Append-only 并发与可变快照不同

两位老师同时各新增一条合法 Evidence：

通常两条都可以存在，不必制造冲突。

两位老师同时“确认稳定”：

这是同一 Case 状态/primary Action 的竞争修改，必须用 version + command 决定只有一个合法事务成功。

因此不能给整个系统套一个粗暴“任何同时写都冲突”的模型。

---

## 9. Conflict UI 不要要求老师重写

发生冲突时保存：
- 用户原输入；
- 原版本上下文；
- 最新云端快照；

至少在当前操作生命周期内保留。

例如老师已经写了 300 字 Case judgment，不能因为 version conflict 只弹：

> 保存失败，请刷新重试。

然后把 300 字清掉。

---

## 10. Lesson 的中途可靠性

Lesson 特别重要，因为一次课可能持续 1–2 小时。

不应该等到“完成课程”才把所有事实第一次发送云端。

推荐：
- Evidence / Intervention / Assessment 等发生后可逐项可靠保存；
- Lesson 保持 in_progress；
- Quick Capture 独立保存；
- complete_lesson 最后原子收口剩余状态变化/Action/lesson status。

这减少 App crash 或设备掉电导致整节课数据丢失。

但 complete_lesson 不能重复创建前面已经成功保存的事实；payload 必须使用已有 entity IDs / operation IDs。

---

## 11. 小班 Lesson 冲突

小班场景：Lesson 同时关联多个学生。

风险：
- A 学生 Case version conflict；
- B/C/D 学生没有冲突；
- 整个 Lesson 是否因此不能完成？

Phase 0A.6 暂不武断冻结“一个超大事务”。

Phase 0B Spike 必须比较：

### 方案 1｜整 Lesson 原子
优点：整体一致。
缺点：一个学生冲突导致全班完成失败，重试复杂。

### 方案 2｜逐 Student/Case reconcile，再 finalize Lesson
优点：失败范围小、可恢复。
缺点：必须明确部分完成状态和最终 gate。

验收原则：
- 不产生重复事实；
- 不丢已经确认成功的数据；
- Lesson 不在 Case 未处理完时虚假 completed；
- 教师知道具体哪个学生需要处理冲突。

最终方案留 Phase 0B transaction Spike。

---

## 12. App Crash / Process Kill

需要验证：
- 正在编辑未保存文本；
- 请求发送后 App 被杀；
- 请求服务端成功但客户端未收到；
- App 重启。

恢复策略：
1. 加载 secure local draft；
2. 查询目标 entity/operation 是否已在云端成功；
3. 已成功 → 清理 draft，不重复写；
4. 未成功 → 提示恢复并重试；
5. 状态不确定 → 先查询，不盲目 insert。

---

## 13. Device switch

Online-first 意味着正式事实跨设备可见。

本地未同步 draft **不默认跨设备**。

如果老师手机有一个未同步 draft，Windows 不应该假装知道它。

产品要明确：
- 云端事实：跨设备；
- 未同步草稿：当前设备；
- 用户离开设备前尽量提示未保存内容。

未来若做 cloud draft，需要单独安全设计；V1 不默认引入。

---

## 14. Auth/session 失败与业务 Draft

Token refresh 失败 / Session revoked 时：
- 立即停止业务请求；
- 不继续显示有权限的旧业务界面；
- 尚未保存输入可按安全策略暂存本地 draft；
- 强制重新认证；
- 重新认证后必须重新验证 membership/assignment；
- 不能因为 draft 来源于旧权限就自动提交到新 organization/context。

Draft 恢复必须校验：
- 同 user；
- 同 organization；
- 当前仍有目标 entity 权限。

---

## 15. Finalized snapshot 的并发

Parent Communication / Report：

如果 draft version=3 被 A/B 同时打开：
- A finalize 成功；
- B 的旧 draft 不能继续覆盖已 finalized snapshot。

Finalization 应：
- expected_version；
- status=draft 前置条件；
- 一次事务冻结 snapshot；
- finalized_by/time；
- 后续只走 correction/supersede。

---

## 16. Offline 行为边界

V1 不是 offline-first。

无网络时可以：
- 保留当前输入；
- 建立加密 local draft；
- 明确显示“尚未同步”；
- 网络恢复后由用户/安全重试机制提交。

不承诺：
- 离线浏览完整学生数据库；
- 离线修改多个实体后自动复杂合并；
- CRDT；
- 长期离线工作。

这是安全与复杂度的主动边界。

---

## 17. Error taxonomy

Infrastructure adapter 不应把 vendor error string 直接暴露给 UI。

至少映射：
- `network_unavailable`
- `timeout_unknown_result`
- `unauthenticated`
- `permission_denied`
- `version_conflict`
- `validation_failed`
- `operation_already_completed`
- `storage_failed`
- `server_unavailable`
- `unknown`

Domain/UI 根据统一错误类别显示一致恢复动作。

---

## 18. Telemetry / logs

为了排错可以记录：
- operation_id；
- entity type/id（必要时脱敏）；
- error category；
- request timing；
- app version；
- provider region；
- retry count。

禁止日志：
- Password；
- access/refresh Token；
- service_role；
- 完整学生敏感正文；
- 完整家长沟通正文；
- 本地 draft 明文。

---

## 19. Phase 0B 必测故障注入

至少模拟：
1. 请求发出前断网；
2. 服务端成功、response 丢失；
3. timeout 后重试；
4. App 保存时被 kill；
5. 两设备同时更新 Case；
6. complete_lesson version conflict；
7. revoked Session + local draft；
8. Storage 上传完成、DB metadata 失败；
9. DB metadata 成功、object 获取失败；
10. provider 5xx；
11. Android 网络切 Wi-Fi/蜂窝；
12. Windows sleep/resume 后继续编辑。

---

## 20. 当前冻结结论

- 云端是唯一正式事实源；local draft 只用于恢复。
- 请求结果不确定时先查询，不能盲目重复副作用。
- append-only facts 和 mutable aggregate 使用不同并发策略。
- 高风险 command 必须 version + operation id + transaction。
- 冲突不能清空教师输入。
- Lesson 事实应逐步可靠保存，最终 completion 负责收口而不是第一次写入所有数据。
- 小班 Lesson 原子边界留 Phase 0B 故障/并发 Spike。
- Provider-specific errors 必须在 infrastructure 层归一化。
