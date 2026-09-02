# Domain Glossary｜领域词汇

> Phase 0A.6 统一业务语言。产品文案可以更口语，但不得改变这里的领域含义。

## 1. Student / Subject Profile

Student：机构内真实学生的唯一主档案。

Student Subject Profile：某学生某学科的连续教学主线，包含 service lifecycle：

```text
active → inactive → archived
active ← inactive ← archived
```

inactive/archived 表示当前服务暂停/归档，不代表学习问题解决。

Student `merged` 是重复档案合并后的身份终态。

## 2. Learning Case

可独立跟进的学习问题。唯一生命周期：

```text
new → confirmed → intervening → pending_verification → stable → closed
```

不增加 reopened/stale/stubborn 等状态。

## 3. new

快速捕捉草稿状态。可以暂缺完整 taxonomy/root cause/action。

**new 仍然是 teaching Case。云端创建必须完整 Teaching Fact Gate。** Advisor-only/management-only 不能借 Quick Capture 创建 new Case。

## 4. confirmed

已经确认值得正式跟进。Active Profile 下必须合法 owner + pending primary Action。

## 5. intervening

正在实施干预。不能因为准备干预就提前伪造 Intervention fact。

## 6. pending_verification

已经完成一轮处理，等待后续验证。不是“马上会通过”。

## 7. stable｜稳定观察

已有改善证据，但仍需后续 review/verify。Active Profile 下仍有 primary Action。

## 8. closed｜已清零

只有问题真实退出主动解决跟进时才 closed。

```text
Assessment passed ≠ stable ≠ closed
```

停科/停读/archive/老师离职均不等于 closed。

Current snapshot：closed 无 pending primary Action；历史 close 时间保存在 Case Events。

## 9. Tracking Suspended

不是 Case status。

Profile inactive/archived 时：
- unresolved Case status 保留；
- current owner/primary Action 可受控收口；
- 不进普通 Today；
- 不产生 teaching facts/new Lesson/new Case。

恢复 service 叫 resume tracking，不叫 reopen。

## 10. Reopen｜真实复发

`reopen_case` 是 domain command + Case Event，只用于已经 closed 的同一问题，在最近一次关闭后出现新的真实复发事实，并在 active Subject Profile 下重新达到正式跟进条件。

```text
closed → post-close recurrence fact → teacher-confirmed recurrence Evidence → reopen_case → confirmed
```

Server 在 `reopen_case` transaction 内从 immutable committed Case Events 解析该 Case 最新 committed `case_closed` lifecycle event；客户端不能指定 previous close。每条 recurrence Evidence 必须属于目标 Case，并满足：

`evidence.observed_at > latest committed case_closed.occurred_at`

`observed_at` 是事实实际发生/被观察到的业务时间；`created_at` 是录入时间。晚录合法。旧 Evidence 只能作为引用/复查线索，不能单独 reopen。source_type 不设 recurrence 白名单，合法 source type 仍需 Evidence 合法性与教师专业判断。

Committed/finalized Evidence 是 append-only historical fact；不得普通修改/删除 `case_id`/case relationship、observed_at、created_at、author/source attribution 或 provenance。错误通过 correction/superseding/invalidation event 保留原记录；reopen_case 同一事务 lock/re-read selected Evidence 并验证 committed、归属、freshness/version 与 post-close boundary。

唯一目标：

```text
closed --reopen_case--> confirmed
```

原子结果：legal owner、exactly one pending primary Action、current `closed_at/stable_at → null`、`reopened_count +1`、Case.version +1、operation-bound event/audit；`case_reopened` metadata 引用 server-resolved latest committed close event 与 recurrence Evidence IDs。无 committed `case_closed` event 或任何合同失败 → reject/rollback。Profile inactive/archived 时拒绝；先恢复 service，再 reopen。

## 11. Three-stage correction｜三阶订正

Knowledge 默认教学 workflow：当堂订正 → 相似题 → 延迟独立验证。不是数据库三列/状态，也不机械套 Habit/Exam Strategy。

## 12. Teaching Fact Gate

Teaching Evidence / Intervention / Assessment / Lesson teacher 行为 / Quick Capture new Case 必须：

```text
live session
+ active membership
+ teacher capability
+ active teaching scope
+ target Profile active
+ legal active Student Teacher Assignment
+ operation permission
```

V1 所有 teaching writes 必须有 legal active Student Teacher Assignment。Lesson/`lesson_students` participant 只表示实际参与 business fact，不是 authorization grant、temporary permission、capability、scope 或 Student Teacher Assignment；不能自我授权。

## 13. Evidence / Intervention / Assessment / Action

Evidence：支持判断的来源事实。

Intervention：真实实施过的教学处理。

Assessment：一次验证结果，和 Case status 分开。

Case Action：机构成员当前下一步。Active formal Case 必须一个 pending primary；Guardian 不是 Action assignee。

## 14. Archive / Unarchive / Reactivate

Archive：inactive→archived，退出普通当前视图但历史保留。

Unarchive：archived→inactive，只恢复可管理状态，不恢复教学。

Reactivate：inactive→active，恢复真实服务前完成 assignment/owner/Action reconciliation。

`reactivate_student` 不允许暗中把 archived Profile 跨事务 unarchive；selected Profiles 必须调用前已经 inactive。

## 15. operation_id

高风险 command 的用户意图幂等键。

同 operation_id 重试必须返回同一次 committed result；lifecycle events/audit 同样使用 operation-bound stable keys，不能重复写副作用。

## 16. Student aggregate version

`students.version` 只表达 Student root/current canonical/lifecycle snapshot。deactivate/archive/unarchive/reactivate 成功各 +1 exactly once；merge 时 source/target 各 +1 exactly once；普通 child append/transition/Assignment change 不机械递增。多 Profile command 仍须验证 affected Profile/Case versions 与 current relation set。

Source-only Profile safe reparent 时 `Profile.version +1 exactly once`；Case 仅在 current mutable snapshot 真正改变时更新，不做全量 child cascade。

Merge preview/execute 必须使用 server-derived complete merge-relevant plan binding；相关 drift → `stale_plan/version_conflict`，append-only non-conflicting history 不自动 stale。

## 17. Student Merge

只合并已确认同一真实学生的重复主档案。

V1 是 conservative safe merge：semantic conflict（同科双 Profile、冲突 Enrollment、双 active Lead 等）直接 BLOCK，先人工治理再重试。

source 最终 merged，不删除；历史 provenance 保留。

## 18. Parent Communication / Stage Review

Parent Communication finalized 是一次不可变实际沟通 event；异步 reply 新增 inbound。

Report finalized 是阶段 snapshot；后续 Case reopen 不回写旧 report。
