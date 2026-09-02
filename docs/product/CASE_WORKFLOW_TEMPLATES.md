# Case Workflow Templates｜三类问题默认教学闭环

> Phase 0A.6 产品事实源。三类问题共享同一 Case lifecycle，不把领导“三阶”机械写成数据库状态。

## 1. 唯一 Case lifecycle

```text
new → confirmed → intervening → pending_verification → stable → closed
```

`reopen` 是 command/event，不是第七状态。

`Assessment passed ≠ stable ≠ closed`。

## 2. 共通不变量

### Active Subject Profile
- new 可快速捕捉；
- confirmed 前有可解释 Evidence；
- formal open Case 必须合法 owner + pending primary Action；
- stable 仍有 review/verify Action；
- closed 无 pending primary。

### inactive/archived Profile
- unresolved Case 保留真实 resolution status；
- tracking suspended；
- 可无 current owner/primary Action；
- 不进普通 Today；
- 不产生教学事实/new Lesson/**new Quick Capture Case**；
- 恢复 active 前通过 lifecycle command 重新建立 owner + primary Action。

## 3. Knowledge｜知识漏洞

默认教学语言：

```text
当堂订正
→ 相似题巩固
→ 延迟/次课独立验证
→ 教师判断继续 / stable / 最终 closed
```

一阶/二阶/三阶可重复；三阶 passed 不自动 closed。

## 4. Habit｜学习习惯

不写人格标签；必须是可观察行为。

```text
定义当前行为/目标行为
→ 策略干预
→ 多个自然场景连续观察
→ 调整或 stable
→ 后续 review
→ 真实稳定后 closed
```

不机械套“三阶题目”。

## 5. Exam Strategy｜考试技巧

```text
方法显性化
→ guided application
→ timed/simulated transfer
→ independent verification
→ stable/review/closed
```

必须验证真实迁移，不以同题记忆代替。

## 6. Other

仍遵守统一 lifecycle/Evidence/Action；UI 不强制三阶。如果 Other 大量增长，后续审查 taxonomy，而不是运行时不断加 enum。

## 7. Quick Capture｜唯一权限与服务边界

课堂 10–20 秒：

```text
student/subject context
→ 一句标题
→ optional detail
→ new Case
```

但 **Quick Capture 是 Learning Case 创建，不是管理便签**。

云端创建前必须完整 Teaching Fact Gate：

```text
live session
+ active membership
+ teacher capability
+ active teaching scope
+ target Profile active
+ legal active Student Assignment / controlled Lesson relationship
+ operation permission
```

因此：
- Advisor-only 不能 Quick Capture teaching Case；
- pure Subject Lead/Admin 不能借管理权限 Quick Capture；
- inactive/archived Profile 一律拒绝；
- 本地离线 draft 可以保留输入，但同步时必须重新验证 Gate；
- 无权限的 Advisor 事实改走 Parent Communication 或 Observation（该能力实现后）。

Quick Capture 当场不要求 taxonomy/root cause/三阶任务；课后 formalize 再补。

## 8. Confirm Case

```text
new
→ 确认 Evidence
→ taxonomy/case_type
→ owner
→ pending primary Action
→ confirm_case
```

Profile 必须 active。

## 9. Reopen｜复发

仅 closed Case + active Profile。

唯一：

```text
closed --reopen_case--> confirmed
```

必须有 recurrence Evidence、合法 owner、新 pending primary Action；`closed_at/stable_at` 清当前快照，历史通过 Case Events 保留，`reopened_count +1`。

Profile inactive/archived 时不 reopen；那是 service resume 问题，不是 Case reopen。

## 10. Template 是派生视图

V1 不把 `current_stage=1/2/3` 做权威状态。Knowledge 三阶进度从 Actions/Assessments/Events 派生，避免与真实 lifecycle 打架。
