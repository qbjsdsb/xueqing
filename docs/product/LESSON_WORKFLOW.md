# Lesson Workflow｜课前—课中—课后教学工作台

> 状态：Phase 0A.6 产品/领域事实源。目标：让老师在真实授课过程中自然产生闭环事实，而不是课后再维护一份“学情档案”。

## 1. Lesson 的产品定位

Lesson 是一次真实教学会话的上下文容器，用来回答：
- 本节课属于哪个学科；
- 与哪些学生有关；
- 原本准备处理什么；
- 实际发生了什么；
- 哪些 Case/Action 被推进；
- 下一步是什么。

Lesson 不是完整排课、收费课消、招生 CRM 或教师绩效打卡。

---

## 2. 为什么 Lesson 是日常事实引擎

错误流程：

```text
上课
→ 记录课堂
→ 再到 Case 填整改
→ 再抄周报
→ 再重写家长反馈
```

正确方向：

```text
Lesson 中记录真实事实一次
↓
Case timeline 连续
↓
Action 进入 Today
↓
周度自动派生
↓
家校/阶段复盘获得素材
```

---

## 3. Lesson 基础关系

```text
Lesson
- organization
- subject
- teacher
- started/ended time
- status
- version

Lesson Students
- student
- attendance
```

一个 Lesson V1 对应一个主学科；一对一只是一个 participant，小班可多个。

---

## 4. 谁能开始 Lesson｜Teaching Service Gate

至少要求：

```text
live session
+ active membership
+ teacher capability
+ matching active teaching subject scope
+ target Student Subject Profile = active
+ 对 student+subject 的合法 active teacher assignment / 明确受控代课关系
+ organization/subject 一致
```

### 重要
- Subject Scope 不能代替 Student Assignment；
- Student Assignment 也不能代替 Subject Profile active；
- Profile inactive/archived 表示当前不持续该学科教学，普通流程不能启动新 Lesson；
- Subject Lead/Admin 单凭管理身份不能成为 Lesson teacher。

---

## 5. `start_lesson`

开始 Lesson 是受控 domain command，不由 Flutter 拼多次 insert。

至少：
1. 验证 Teaching Service Gate；
2. 验证所有 participants 与 organization/subject/profile 一致；
3. 创建 `lesson(in_progress)`；
4. 创建 participants；
5. 防明显重复启动；
6. audit；
7. 返回课前 context。

### 是否限制一个老师只能有一个 in-progress Lesson
暂不写死数据库唯一约束。App 可以先提示已有未完成 Lesson，真实 Pilot 再验证。

---

## 6. Pre-lesson｜课前约 30 秒

目标：

> 这节课最值得先处理什么？

每个 Student+Subject 只显示少量：
- overdue/today Action；
- pending verification；
- 上节课遗留 Next Action；
- 当前重点 Case；
- 最近关键 Evidence/Assessment。

不默认铺全历史、closed Cases、全部档案字段或 KPI。

### 小班
先给每个学生 1–3 条重点，点击再展开，不能把 8 个学生的完整 Case 全铺一屏。

---

## 7. In-lesson｜只记录新事实

高频动作：
- Action progress；
- Evidence；
- 实际 Intervention；
- Assessment；
- Quick Capture new Case。

不强迫课中：
- 写完整 root cause；
- formalize 所有 new；
- 写周报；
- 写家长反馈；
- 做阶段复盘。

---

## 8. 保存策略：课中逐步可靠，课后原子收口

不能把整节 90 分钟内容第一次保存都押在“完成课程”按钮上。

### 课中可逐步正式保存
在 RLS/幂等保护下：
- new Quick Capture；
-简单 Evidence；
- 合法、独立的 Intervention/Assessment（若不会与本次 Case transition 形成半状态）；
- attachment metadata。

客户端预生成 UUID，timeout 重试复用。

### 本机恢复
尚未云端确认的输入可进入：
- user/org/lesson/entity scoped；
- encrypted；
- TTL；
- 云端成功后清理的 local draft。

### 课后敏感组合
以下由 `complete_lesson` 收口：
- complete/cancel primary Action；
- Case transition；
- replace primary Action；
- 本次尚未提交的组合事实；
- Lesson completed。

---

## 9. Post-lesson｜目标 30–60 秒

系统自动整理本节：
- 已保存教学事实；
- 处理的 Cases；
- Action progress；
- Assessment results；
- new Quick Captures；
- 可能的下一步。

教师只确认真正需要专业判断的内容：
- new 是否 formalize；
- Case 是否合法 transition；
- 旧 primary Action 如何收口；
- 新 primary Action；
- Lesson complete。

不要求再写一份周总结。

---

## 10. `complete_lesson`

必须：
1. live/active teacher；
2. lesson expected_version/status；
3. Subject Profile 仍 active；
4. teacher/student/subject relationships 仍合法；
5. 已经成功保存的事实通过 ID 引用，不重复 insert；
6. Case transition 合法；
7. active-profile primary Action 不变量成立；
8. operation_id 防重复副作用；
9. Lesson 只有在必需冲突已处理后才能 completed；
10. 返回最新快照。

如果课程进行中 Profile/assignment 被治理动作停用，complete 必须进入明确冲突/治理恢复流程，不能静默绕过新权限。

---

## 11. 小班事务边界｜PENDING SPIKE

场景：4 个学生中 1 个 Case 发生 version conflict。

需要在 Phase 0B.0 比较：

### Whole Lesson Atomic
一个大事务。

优点：整体一致。
缺点：一个学生冲突可能导致全班 finalize 失败。

### Per-Student/Case Reconcile Then Finalize
先逐学生解决/确认，再最终 Lesson complete。

优点：失败范围小、恢复清晰。
缺点：要严谨定义“尚未完成”的中间状态。

最终必须证明：
- 不丢已确认事实；
- 不重复；
- 不虚假 completed；
- UI 能指出具体冲突学生；
- timeout/retry 可恢复。

Phase 0A.6 不假装已经选择。

---

## 12. Lesson 与周度/家校/报告

Lesson 产生的 Case/Evidence/Intervention/Assessment/Action 是后续事实源。

- Weekly view：派生；
- Parent Communication：引用/整理这些事实后形成独立沟通 event；
- Stage Review：按 source cutoff 汇总后形成人类确认 snapshot。

不得复制第二套 Lesson summary 事实表。

---

## 13. 取消 / 残留 Lesson

### Cancelled
真实未进行/中止的 Lesson 可 cancelled，但已产生的合法 Evidence 等不能因取消 Lesson 被级联删除。

### Stale in-progress
App crash 等可能留下 in-progress Lesson；系统应：
- 提示继续；
- 允许受控取消/恢复；
- 不自动假 completed；
- 不因为残留 Lesson 阻塞所有未来使用而无恢复路径。

---

## 14. Acceptance Scenarios

1. Teacher 有语文 scope 但无 Student Assignment，不能 start Lesson。
2. Teacher 有旧 assignment，但 Subject Profile 已 inactive，不能 start Lesson。
3. 纯 Subject Lead 无 Teaching relationship，不能成为 Lesson teacher。
4. 小班多个 participants 必须同 subject/org 且 profiles active。
5. 课中 App crash 后未同步输入可恢复，已同步事实不重复。
6. response lost 后重试不会创建两次 Lesson/Action/Assessment。
7. complete 时 assignment/profile 已变化，明确冲突而不是绕过。
8. Lesson complete 后 active formal Cases 仍满足 next Action invariant。
9. cancelled Lesson 不删除已经合法发生的教学事实。
10. 周度/家校/阶段复盘从 Lesson 事实复用，不要求老师重抄。

---

## 15. 当前冻结结论

- Lesson 是日常事实引擎，不是排课 ERP。
- `start_lesson` / `complete_lesson` 是受控 domain commands。
- 能开课必须同时满足 teaching scope + assignment + **active Subject Profile**。
- 课中事实逐步可靠保存，课后只收口敏感组合。
- 小班 transaction boundary 明确留 Phase 0B.0 Spike。
- 周度、家校、阶段复盘复用同一套教学事实。
