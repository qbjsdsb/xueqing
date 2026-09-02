# Lesson Workflow｜课前—课中—课后教学工作台

> Phase 0A.6 产品/领域事实源。Lesson 是真实教学会话的事实容器，不是排课/收费/招生 ERP。

## 1. Lesson 的作用

回答：哪个学科、哪些学生、准备处理什么、实际发生什么、哪些 Case/Action 被推进、下一步是什么。

正确方向：

```text
Lesson 中只记录一次真实事实
→ Case timeline
→ Action / Today
→ 周度派生
→ 家校/阶段复盘复用
```

## 2. 基础关系

Lesson：organization / subject / teacher / started_at / ended_at / status / version。

Lesson Students：student / attendance。

一对一只是一个 participant，小班可多个；V1 一个 Lesson 一个主学科。

## 3. Teaching Fact Gate｜包含 Quick Capture

以下全部必须在**每次云端写入时**通过同一 Gate：
- Lesson teacher behavior；
- teaching Evidence；
- Intervention；
- Assessment；
- **Quick Capture / new Learning Case**。

```text
live session
+ active membership
+ teacher capability
+ matching active teaching subject scope
+ target Student Subject Profile = active
+ legal active Student Assignment
  OR controlled validated Lesson relationship
+ operation-specific permission
```

硬规则：
- start Lesson 时检查一次不代表整节课永久授权；
- Profile/assignment/session 课中变化后，后续写入重新校验；
- inactive/archived Profile 不可新 Lesson、teaching fact 或 Quick Capture；
- Advisor/Subject Lead/Admin 单凭管理身份不能成为 Lesson teacher 或创建 teaching Case。

## 4. `start_lesson`

受控 domain command：
1. 完整 Gate；
2. participants 与 org/subject/Profile 一致且 active；
3. 创建 Lesson(in_progress) + participants；
4. operation identity/idempotency；
5. 返回课前 context。

是否限制教师同时仅一个 in-progress Lesson 留 Pilot 验证。

## 5. Pre-lesson｜约 30 秒

每个 Student+Subject 少量展示：
- overdue/today Action；
- pending verification；
- 上次 next Action；
- 当前重点 Case；
- 最近关键 Evidence/Assessment。

不默认铺全历史/KPI。

## 6. In-lesson｜只记新事实

高频：
- Action progress；
- Evidence；
- Intervention；
- Assessment；
- Quick Capture new Case。

Quick Capture 目标仍 10–20 秒，但云端创建前必须 §3 Gate。没有权限或 Profile 已停用时，只能安全保留本地 Draft，不得插入 new Case。

不强迫课中写 root cause、formalize 全部 new、周报、家校反馈。

## 7. 保存策略

### 逐步正式保存
合法的 Evidence/Intervention/Assessment/Quick Capture 可在课中分别保存，避免 90 分钟内容全部押在结束按钮。

简单 append/new Case 使用预生成 UUID；response lost 复用同 ID/查询，不重复创建。

### Local Draft
尚未云端确认的输入：user/org/lesson/entity scoped、encrypted、TTL；重新同步时重新验证当前 Gate。

### Post-lesson sensitive combination
由 `complete_lesson` 收口：Action completion/cancel、Case transition、new primary Action、Lesson completed 等敏感组合。

## 8. Post-lesson｜目标 30–60 秒

系统整理本节已保存事实、处理 Cases、Assessment、Quick Captures、Action progress；教师只确认真正需要专业判断的 formalize/transition/next Action/complete。

不再复制周总结。

## 9. `complete_lesson`

必须：
- 重新验证 live session / membership / teacher / scope / Profile / relationship / permission；
- lesson expected_version；
- 已保存 facts 通过 ID 引用，不重复 insert；
- Case transition 合法；
- active Profile formal Cases 满足 primary Action invariant；
- operation_id 幂等；
- 必需冲突未解决时不能虚假 completed。

课中 Profile/assignment/session 被治理动作改变时，必须明确冲突/恢复，不能以“Lesson 已开始”为 bypass。

## 10. 小班事务边界｜Phase 0B.0 Spike

比较 Whole-Lesson Atomic vs Per-Student/Case Reconcile Then Finalize。

无论哪种必须：
- 不丢已确认事实；
- 不重复；
- unresolved conflict 不虚假 completed；
- UI 指出具体学生；
- timeout/retry 可恢复；
- committed state 满足 Case/Action invariants。

## 11. Cancel / crash

Cancelled Lesson 不级联删除已合法发生的 Evidence 等事实。

stale in-progress：提示继续/受控取消；继续写入前重新 Gate；不自动 completed。

## 12. Acceptance Scenarios

- teaching scope 但无 Student Assignment → start Lesson/Quick Capture 拒绝；
- Profile inactive + old assignment → start/teaching fact/new Case 拒绝；
- Profile archived → 全部教学写入拒绝；
- pure Subject Lead/Admin/Advisor → 不能成为 Lesson teacher 或 Quick Capture teaching Case；
- 小班 participants 必须同 org/subject 且 Profiles active；
- 课中 Profile deactivate → 后续 Intervention/Assessment/Quick Capture 拒绝并保留本地输入；
- Session revoked → 后续写入/complete 拒绝；
- response lost → 不重复 Lesson/Action/Assessment/new Case；
- complete 时 assignment/profile 已变化 → conflict；
- completed 后 active formal Cases 仍有 next Action；
- 周度/家校/阶段复盘复用 Lesson 事实。

## 13. 冻结结论

- Lesson 是日常事实引擎；
- start/complete 是受控 command；
- **Quick Capture/new Case 与 Lesson 内其他 teaching facts 使用完全相同的 Gate**；
- inactive/archived Profile 无普通 Lesson/教学写入；
- 课中事实逐步可靠保存，课后收口敏感组合；
- 小班 transaction boundary 留 Phase 0B.0 Spike。
