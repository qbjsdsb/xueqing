# Lesson Workflow｜课前—课中—课后教学工作台

> 状态：Phase 0A.6 产品/领域事实源。目标：让老师在真实授课过程中自然产生闭环事实，而不是课后再维护一份“学情档案”。

## 1. Lesson 的产品定位

Lesson 是一次真实教学会话的上下文容器，用来回答：
- 属于哪个学科；
- 与哪些学生有关；
- 原本准备处理什么；
- 实际发生了什么；
- 哪些 Case/Action 被推进；
- 下一步是什么。

Lesson 不是完整排课、收费课消、招生 CRM 或教师绩效打卡。

---

## 2. Lesson 是日常事实引擎

错误流程：

```text
上课 → 记录课堂 → 再填 Case → 再抄周报 → 再重写家长反馈
```

正确方向：

```text
Lesson 中记录真实事实一次
→ Case timeline 连续
→ Action 进入 Today
→ 周度自动派生
→ 家校/阶段复盘获得素材
```

---

## 3. 基础关系

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

V1 一个 Lesson 对应一个主学科；一对一只是一个 participant，小班可多个。

---

## 4. Teaching Fact Gate｜Lesson 使用同一硬定义

任何 Lesson teacher 行为，以及 Lesson 内实际 Intervention / Assessment / teaching Evidence，都必须同时满足：

```text
live session
+ active membership
+ teacher capability
+ matching active teaching subject scope
+ target Student Subject Profile = active
+ 对该 student+subject 的合法 active teacher assignment
  或本次由受控 command 建立并验证的合法 Lesson relationship
+ operation-specific permission
```

### 硬规则
- `live session`、`active Profile` 都是硬条件；
- Subject Scope 不能代替 Student Assignment；
- Student Assignment 不能代替 Profile active；
- inactive/archived Profile 不能启动普通新 Lesson，也不能继续追加普通教学事实；
- Subject Lead/Admin/Advisor 单凭管理身份不能成为 Lesson teacher；
- “临时代课/诊断”必须先通过受控关系建立与权限验证，不是 admin bypass。

---

## 5. `start_lesson`

开始 Lesson 是受控 domain command，不由 Flutter 拼多次 insert。

至少：
1. 验证完整 Teaching Fact Gate；
2. 验证所有 participants 与 organization/subject/Profile 一致；
3. Profile 必须 active；
4. 创建 `lesson(in_progress)`；
5. 创建 participants；
6. 防止明显重复启动；
7. 写 audit / operation identity；
8. 返回课前 context。

是否硬限制“一位老师同时只能一个 in-progress Lesson”暂不写死数据库唯一约束；Pilot 先验证真实操作习惯。

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

小班先给每个学生 1–3 条重点，点击再展开。

---

## 7. In-lesson｜只记录新事实

高频动作：
- Action progress；
- Evidence；
- 实际 Intervention；
- Assessment；
- Quick Capture new Case。

不强迫课中写完整 root cause、formalize 所有 new、写周报、家长反馈或阶段复盘。

每一条实际教学事实仍需在写入时通过完整 Teaching Fact Gate；不能只在 `start_lesson` 时检查一次，之后永久信任旧权限。

---

## 8. 保存策略：课中逐步可靠，课后原子收口

不能把整节 90 分钟内容第一次保存都押在“完成课程”按钮上。

### 可逐步正式保存
在 RLS/幂等保护下：
- new Quick Capture；
- 简单 Evidence；
- 合法、独立的 Intervention/Assessment；
- attachment metadata。

客户端预生成 UUID，timeout 重试复用。

### 本机恢复
未被云端确认的输入可进入 user/org/lesson/entity scoped、encrypted、TTL local draft；云端成功后清理。

### 课后敏感组合
由 `complete_lesson` 收口：
- complete/cancel primary Action；
- Case transition；
- replace primary Action；
- 本次尚未提交的组合事实；
- Lesson completed。

---

## 9. Post-lesson｜目标 30–60 秒

系统整理：已保存教学事实、处理 Cases、Action progress、Assessment results、new Quick Captures、可能下一步。

教师只确认真正需要专业判断的：
- new 是否 formalize；
- Case 是否合法 transition；
- 旧 primary Action 如何收口；
- 新 primary Action；
- Lesson complete。

不再写一份周总结。

---

## 10. `complete_lesson`

必须：
1. **重新验证完整 Teaching Fact Gate**，包括 live session、active Profile、operation permission；
2. lesson expected_version/status；
3. teacher/student/subject relationships 仍合法；
4. 已成功保存事实通过 ID 引用，不重复 insert；
5. Case transition 合法；
6. active Profile primary Action 不变量成立；
7. operation_id 防重复副作用；
8. Lesson 只有在必需冲突已处理后才能 completed；
9. 返回最新快照。

如果课程进行中 Profile/assignment/session 被治理动作停用，complete 必须进入明确冲突/恢复流程，不能使用“Lesson 已经开始”绕过新权限。

---

## 11. 小班事务边界｜PENDING Phase 0B.0 Spike

场景：4 个学生中 1 个 Case version conflict。

需要比较：
- Whole Lesson Atomic；
- Per-Student/Case Reconcile Then Finalize。

最终必须证明：不丢已确认事实、不重复、不虚假 completed、UI 能指出冲突学生、timeout/retry 可恢复。

Phase 0A.6 不假装已经选择。

---

## 12. Lesson 与周度/家校/报告

Lesson 产生的 Case/Evidence/Intervention/Assessment/Action 是后续事实源：
- Weekly view：派生；
- Parent Communication：引用/整理后形成独立 event；
- Stage Review：按 source cutoff 汇总后形成人类确认 snapshot。

不得复制第二套 Lesson summary 事实表。

---

## 13. Cancelled / Stale in-progress

Cancelled Lesson 不级联删除已经合法发生的 Evidence 等事实。

App crash 造成 stale in-progress 时：
- 提示继续；
- 允许受控取消/恢复；
- 不自动 completed；
- 恢复/继续写入前重新验证当前 Teaching Fact Gate。

---

## 14. Acceptance Scenarios

1. Teacher 有语文 scope 但无 Student Assignment → start Lesson 拒绝。
2. Teacher 有旧 assignment，但 Profile inactive → start Lesson 拒绝。
3. Profile archived → start Lesson / teaching fact 拒绝。
4. 纯 Subject Lead 无 Teaching relationship → 不能成为 Lesson teacher。
5. Academic/Org Admin 单凭管理身份 → 不能成为 Lesson teacher。
6. 小班所有 participants 必须同 subject/org 且 profiles active。
7. 课中 Profile 被 deactivate 后继续写 Intervention → 拒绝并保留本地输入用于安全处理。
8. 课中 Session revoked 后继续写 Assessment/complete → 拒绝。
9. response lost 后重试不会创建两次 Lesson/Action/Assessment。
10. complete 时 assignment/profile 已变化 → 明确冲突而不是绕过。
11. Lesson complete 后 active formal Cases 仍满足 next Action invariant。
12. cancelled Lesson 不删除已合法发生教学事实。
13. 周度/家校/阶段复盘复用 Lesson 事实，不重抄。

---

## 15. 当前冻结结论

- Lesson 是日常事实引擎，不是排课 ERP。
- `start_lesson / complete_lesson` 是受控 domain commands。
- **Lesson 与 Lesson 内教学事实始终使用和 Auth/Data/Commands 完全一致的七项 Teaching Fact Gate。**
- inactive/archived Profile 无普通新 Lesson/教学写入。
- 课中事实逐步可靠保存，课后只收口敏感组合。
- 小班 transaction boundary 留 Phase 0B.0 Spike。
- 周度、家校、阶段复盘复用同一套教学事实。
