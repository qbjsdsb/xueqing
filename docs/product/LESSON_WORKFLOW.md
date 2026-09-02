# Lesson Workflow｜课前—课中—课后教学工作台

> Phase 0A.6 产品/领域事实源。Lesson 是真实教学会话的事实容器，不是排课/收费/招生 ERP。

## 1. Lesson 的作用

回答：哪个学科、哪些学生、准备处理什么、实际发生什么、哪些 Case/Action 被推进、下一步是什么。

```text
Lesson 中只记录一次真实事实
→ Case timeline
→ Action / Today
→ 周度派生
→ 家校/阶段复用
```

## 2. 基础关系

Lesson：organization / subject / teacher / started_at / ended_at / status / version。

`lesson_students`：某次 Lesson 中实际参与的 Student 与 attendance business fact。它不表示授权，不是 temporary permission、Student Teacher Assignment、capability 或 subject scope；把 `student_id` 加入 participant 不能给 teacher 自己创造任何权限。

V1 一个 Lesson 一个主学科；一对一只是一个 participant，小班可多个。

## 3. Teaching Fact Gate｜V1 唯一授权规则

以下全部必须在**每次云端写入**时通过同一 Gate：
- Lesson teacher behavior；
- teaching Evidence；
- Intervention；
- Assessment；
- Quick Capture / new Learning Case。

```text
live session
+ active membership
+ teacher capability
+ matching active teaching subject scope
+ target Student Subject Profile = active
+ legal active Student Teacher Assignment
+ operation-specific permission
```

V1 所有教学写权限都依赖 legal active Student Teacher Assignment。Lesson 或 `lesson_students` participant 记录不能替代该 assignment，也不能在创建后补授权限。management-only / Advisor-only / pure Subject Lead 仍不能 bypass。

## 4. `start_lesson`

`start_lesson` 有两个必须同时通过、但语义分开的授权门：

### Actor Gate｜执行 command 的 member/teacher

执行 `start_lesson` 的 actor 必须由 server 在 command 事务内确认：
1. live active authenticated identity；
2. valid active session；
3. active membership；
4. teacher capability；
5. required matching teaching Subject Scope；
6. operation-specific permission；
7. 其余现有 Teaching Fact Gate 前置条件。

live identity/session 是执行者的属性，不是 Student participant 的属性。

### Per-Student Participant Gate｜每一个 Lesson participant

对 Lesson 中每一个 Student，server 必须分别确认：
1. Student 合法且为 current identity；
2. target Subject Profile = active；
3. actor 与该 Student+Subject 存在 legal active Student Teacher Assignment；
4. organization、subject、Lesson context 一致；
5. 其他既有 participant preconditions。

只有 Actor Gate 与全部 participant gates 都通过，才可在一个受控 command 中创建 `in_progress` Lesson + `lesson_students`。任何 participant 缺 assignment、只有 scope、Profile 不 active、cross-org/cross-subject、或仅由 actor 把 Student 加入 participants → 整个 start 拒绝。

`lesson_students` 只表达 participation/attendance business fact，不是 authorization source、grant、temporary permission、capability、scope 或 Student Teacher Assignment；已有 `lesson_students` participant 不能绕过当前 assignment。临时代课只能通过合法、time-bounded collaborator assignment（`active_from`/`active_to`），有效期内仍需完整 Actor/Participant Gate；不能直接继承旧 Lesson 权限。

如果 assignment、scope、membership、Profile 或 Session 在 Lesson 中途失效，后续 teaching writes 与 ordinary `complete_lesson` fail closed；具有治理权限的 actor 仅可 controlled cancel/cleanup，不能继续制造 teaching facts。新 teacher 先 controlled cancel 旧 Lesson，再以自身合法 assignment 开新 Lesson。

是否限制一名教师同时仅一个 `in_progress` Lesson 留 Pilot 验证，但不影响每次写入重新授权。

## 5. Pre-lesson｜约 30 秒

每个 Student+Subject 少量展示：
- overdue/today Action；
- pending verification；
- 上次 next Action；
- 当前重点 Case；
- 最近关键 Evidence/Assessment。

不默认铺全历史/KPI。

## 6. In-lesson｜逐步记录真实事实

可以逐项保存合法的 Evidence、Intervention、Assessment、Action progress、Quick Capture/new Case。每次云端写入都重新执行 Gate；start 时合法不等于整节课永久合法。

Quick Capture 仍可保持 10–20 秒。没有权限、assignment 过期/撤销、Profile 停用或 Session revoked 时，只能安全保留 user/org/lesson/entity-scoped encrypted local Draft，不能写教学事实/new Case。

## 7. 保存策略

简单 append/new Case 使用预生成 UUID；response lost 时复用同一 ID 查询，不重复创建。

尚未云端确认的输入只进 encrypted local Draft，TTL 后清理；重新同步时按当前 actor、membership、scope、assignment、Profile 重新验证，不跨权限自动提交。

## 8. Post-lesson｜目标 30–60 秒

系统整理已保存事实、Cases、Assessment、Quick Captures、Action progress；教师只确认真正需要专业判断的 formalize/transition/next Action/complete，不复制周总结。

## 9. `complete_lesson`

普通 complete 每次重新验证：
- current live session/membership/teacher capability/scope；
- 每个相关 participant 的 active Profile + legal active Student Teacher Assignment；
- lesson expected_version/status；
- operation-specific permission；
- Case/Action current versions与最终不变量。

如果原 teacher 的 assignment 在 Lesson 进行中被撤销/结束：
- 新 Evidence、Intervention、Assessment、Quick Capture/new Case 等后续 teaching writes 全部拒绝；
- 普通 `complete_lesson` 也拒绝；
- Lesson 已开始不构成旧权限；
- 已经 committed 的合法历史事实保留，不由新老师冒充。

## 10. Controlled cancel / governance recovery

assignment/session/profile 异常导致 `in_progress` Lesson 无法由原 teacher 合法完成时，具有治理权限的 actor 可以执行受控 cancel/recovery：
- 这是状态治理/cleanup，不是 teaching write；
- 只能结束 stale `in_progress` Lesson，保存 reason、governance event/audit；
- 不能新增 Evidence、Intervention、Assessment、Quick Capture/new Case；
- 不能假装原 teacher 做专业判断；
- 不能利用 cancel 绕过 Case/Action invariant。

V1 没有自动 Lesson handoff。新 teacher B 不能直接 complete A 的 Lesson；先 controlled cancel old Lesson，B 再以自己的合法 assignment 开新 Lesson，历史 teacher actor 保留为 A。

## 11. 小班事务边界｜Phase 0B.0 Spike

比较 Whole-Lesson Atomic 与 Per-Student/Case Reconcile Then Finalize。无论哪种都必须：
- 不丢已确认事实；
- 不重复；
- unresolved conflict 不虚假 completed；
- UI 指出具体 student；
- timeout/retry 可恢复；
- committed state 满足 Case/Action invariant。

## 12. Cancel / crash

Cancelled Lesson 不级联删除已经合法发生的 Evidence 等事实。stale `in_progress` 只能继续（先重新 Gate）或 controlled cancel；不自动 completed。

## 13. Acceptance Scenarios

- teaching scope 但无 Student Teacher Assignment → start Lesson/Quick Capture 拒绝；
- 把 Student 加入 `lesson_students` 不能创造权限；
- time-bounded collaborator assignment 有效 → 按完整 Gate 允许；
- assignment revoked mid-lesson → 后续 teaching writes 与 ordinary complete 拒绝；
- stale Lesson → governance controlled cancel allowed；
- new teacher 不能冒充 old Lesson actor finalize；
- Profile inactive/archived、Session revoked、cross-org participant → 拒绝；
- response lost → 不重复 Lesson/Action/Assessment/new Case；
- 小班 participants 每个都必须通过 Gate；
- 周度/家校/阶段复盘复用 Lesson 事实。

## 14. 冻结结论

- Lesson 是日常事实引擎；
- `start_lesson/complete_lesson` 是受控 command；
- V1 所有 teaching writes 依赖 legal active Student Teacher Assignment；
- `lesson_students` 只是参与事实，不是 authorization grant；
- assignment 撤销后 fail-closed；controlled cancel 仅治理清理；
- V1 不支持自动 Lesson handoff 或 in-progress Lesson reparent；
- 小班 transaction boundary 留 Phase 0B.0 Spike。