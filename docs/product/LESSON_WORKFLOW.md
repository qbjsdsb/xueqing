# Lesson Workflow｜课前—课中—课后教学工作台

状态：Phase 0A.6 product foundation draft  
目标：让老师在真实授课过程中自然产生闭环事实，而不是课后再维护一份“学情档案”。

---

## 1. Lesson 的产品定位

Lesson 是：

> **一次真实教学会话的上下文容器。**

它帮助回答：
- 这节课和哪些学生有关；
- 属于哪个学科；
- 本节课原本准备处理什么；
- 实际发生了什么；
- 课后哪些 Case/Action 被推进；
- 下一步是什么。

Lesson 不是：
- 完整排课系统；
- 收费/课消；
- 招生 CRM；
- 教师绩效打卡。

---

# 2. 为什么 Lesson 是 Xueqing 的发动机

如果老师必须：

```text
上课
→ 在一个系统记录课堂
→ 再到 Case 填整改
→ 再到周报总结
→ 再到家长反馈重新写
```

系统一定会退化为行政负担。

正确方向：

```text
Lesson 中记录真实事实一次
↓
Case timeline 自动连续
↓
Action 自动进入 Today
↓
周度摘要自动派生
↓
家长反馈获得素材
↓
阶段复盘获得素材
```

---

# 3. Lesson 基础关系

现有 Foundation：

```text
lessons
  organization_id
  organization_subject_id
  teacher_membership_id
  started_at
  ended_at
  status = in_progress / completed / cancelled
  summary?
  version

lesson_students
  lesson_id
  student_id
  attendance_status
```

这使一对一与小班/多人课都可以表达。

### 一节课一个主学科

V1 推荐：一个 Lesson 对应一个 `organization_subject_id`。

如果未来真实存在跨学科联合课，再单独做 ADR；不要为了极少场景让普通 Lesson 变复杂。

---

# 4. 谁能开始 Lesson

至少要求：
- live session；
- active membership；
- teacher capability；
- matching active teaching subject scope；
- 对目标 student+subject 有合法 active teacher assignment；
- 所有 Student 与 Lesson organization 一致。

Subject Scope 不能代替 Student Assignment。

---

# 5. 新命令候选：`start_lesson`

现有 Foundation 对 `complete_lesson` 已有强事务语义，但“创建 lesson + lesson_students”本身也是一个多表且有授权关系的动作。

Phase 0A.6 建议：进入 Phase 0B 前评估新增受控命令：

```text
start_lesson(...)
```

可能负责：
1. 验证 live active teacher；
2. 验证 organization subject + teaching scope；
3. 验证每个 student 的有效 assignment；
4. 创建 lesson；
5. 创建 lesson_students；
6. 防止明显重复启动；
7. 返回课前工作上下文。

### 是否限制“一位老师只能有一个 in_progress lesson”

这是合理候选，但当前**不立即冻结硬数据库唯一约束**。

原因：
- 崩溃后残留 in_progress 需要恢复；
- 真实机构可能存在交叠记录/临时切换；
- 硬约束前应先用试点验证操作习惯。

产品可以先在开始新 Lesson 时提示已有未完成 Lesson，并要求继续/取消/明确结束。

---

# 6. Pre-lesson｜课前约 30 秒

老师进入 Lesson 后，第一屏要回答：

> **这节课最值得先处理什么？**

对每个 student+subject 显示少量：
- overdue Action；
- today Action；
- pending verification；
- 上一次 Lesson 遗留的 Next Action；
- 当前最重要 Case；
- 最近关键 Evidence/Assessment。

### 不显示

默认不铺开：
- 全部历史；
- 所有 closed Case；
- 学生所有档案字段；
- KPI。

---

# 7. 多人 Lesson 的课前组织

小班课不能把每个学生完整详情连续铺 10 屏。

推荐：

```text
本节 4 人

张三
  待验证：议论文论据
  今天：检查作文提纲

李四
  逾期：文言实词复查

王五
  无紧急事项

赵六
  待整理问题 1 个
```

点击学生再展开详细 Case context。

---

# 8. In-lesson｜课中只记录新事实

课中高频动作应非常少：

- 完成/调整已有 Action；
- 记录 Evidence；
- 记录实际 Intervention；
- 记录 Assessment；
- Quick Capture 一个 new 问题。

### 课堂中不强迫

- 写完整周总结；
- 补完整 root cause；
- formalize 每一个 new Case；
- 写家长反馈；
- 做阶段复盘。

---

# 9. 课中记录：正式事实 vs 待收口草稿

为了同时满足“不要丢”和“事务正确”，需要区分。

## 可以即时成为正式简单事实的内容

在 RLS/幂等保护下，可考虑即时保存：
- Quick Capture `new` Case；
- 简单 Evidence；
- attachment metadata。

原因：这些是追加事实，网络重试可使用客户端预生成 UUID 幂等。

## 需要课后受控收口的内容

尤其：
- complete/cancel primary Action；
- Case lifecycle transition；
- replace primary Action；
- 多表 Assessment/Intervention + transition 组合；
- lesson completed。

应由受控 command 完成，避免半状态。

---

# 10. Intervention / Assessment 的保存时机

现有 `complete_lesson` 允许在一个事务中写：
- Intervention；
- Assessment；
- Case Event；
- Action；
- Case transition；
- Lesson completion。

这是安全的事务边界。

但 UX 不能让老师上 90 分钟课后因为 App 崩溃失去全部尚未提交的文字。

### Phase 0A.6 推荐策略

V1 online-first：

```text
课中输入
→ 本机加密可恢复 lesson draft
→ 必要的简单 append facts 可独立正式保存
→ 课后 Review
→ complete_lesson 原子提交敏感组合
→ 成功后清理本地 draft
```

这不是 offline-first，也不把本地草稿当第二数据库。

---

# 11. Post-lesson｜课后 30–60 秒收口

结束时系统自动整理“本节发生了什么”，教师只确认关键决策。

示例：

```text
本节课待确认

✓ 完成旧 Action 2 个
✓ 新 Evidence 3 条
✓ Intervention 2 条
✓ Assessment 2 条
○ 新问题 1 个仍待整理

Case A
本次 Assessment: passed
建议：进入待验证，由教师确认是否稳定

Case B
本次 Assessment: partial
建议：继续干预
下一步：9 月 6 日做 2 道迁移题
```

教师确认后完成 Lesson。

---

# 12. `complete_lesson` 继续作为高风险事务命令

现有 Foundation 的设计继续保留：

一次 `complete_lesson` 可以原子完成：
- complete old Action；
- add Intervention；
- add Assessment；
- write Case Event；
- legal Case transition；
- create next primary Action；
- Lesson → completed。

### Command payload 原则

不传任意表 patch，而传业务意图。

例如概念上：

```text
complete_lesson(
  lesson_id,
  expected_lesson_version,
  per_case_changes[],
  operation_id
)
```

每个 Case change 带：
- expected_case_version；
- action completion/cancel intention；
- intervention facts；
- assessment facts；
- requested transition；
- next Action。

精确 API 留给 Phase 0B。

---

# 13. 多学生 Lesson 的事务策略

一个小班 Lesson 可能同时更新多个学生 Case。

### 默认原则

同一次“完成本课”提交的用户确认应有明确一致性。

但如果 8 个学生中 1 个 Case 因 version conflict 失败，直接让全部内容消失会非常差。

Phase 0A.6 建议 Phase 0B Spike 比较两种实现：

### Option A｜整个 Lesson 一次数据库事务

优点：
- 最强一致性；
- audit 清晰。

缺点：
- 任一 Case 冲突导致整次提交失败；
- 多人课冲突面更大。

### Option B｜先冻结 Lesson draft，再逐 Case 受控提交，最终完成 Lesson

优点：
- 冲突可局部处理；
- 多人课体验更稳。

缺点：
- 需要明确“部分已提交、Lesson 未完成”的可恢复状态；
- command orchestration 更复杂。

### 当前决策

**不在 Phase 0A.6 纯文档阶段假装选定。**

Phase 0B 必须用真实 PostgreSQL command spike 验证原子性、冲突和重试后再冻结。

无论选哪个，都必须：
- 重试不重复事实；
- 已保存事实不因 UI 失败消失；
- conflict 保留用户输入；
- 不 silent last-write-wins。

---

# 14. Version conflict 在 Lesson 中的 UX

例：

> 王老师在你上课期间更新了“作文审题” Case。

系统应：
- 保留本节课刚记录的 Intervention/Assessment 输入；
- 拉取最新 Case；
- 显示冲突字段/最新状态；
- 让老师重新确认 Next Action/transition。

不得：
- 自动覆盖王老师更新；
- 丢弃本地本节记录；
- 无提示地用最后保存者胜出。

---

# 15. Pending Verification 在 Lesson 中

如果课前有待验证 Case：
- 显示本次要验证什么；
- 课中记录 Assessment；
- 课后由教师决定：继续干预 / stable / 其他合法状态。

Case command 不能伪装为“完成一个 Todo”。

---

# 16. Stable Case 在 Lesson 中

stable 仍有 review/verify Action。

课前如果到期：
> “稳定观察复查”

课后：
- 若继续稳定，可根据 command policy closed/继续观察；
- 若复发，记录 Evidence 并走合法 transition/reopen semantics；
- 不因为历史 stable 自动通过。

---

# 17. New Quick Capture 的课后处理

完成 Lesson 不强迫全部 `new` 立即 confirmed。

系统只提醒：

```text
本节新增 3 个待整理问题
```

老师可以：
- 立即 formalize；
- 稍后处理；
- 判断不值得正式跟进。

机构治理会提示长期 stale new Case，而不是课堂内强制填完整。

---

# 18. Lesson Summary 的边界

当前 `lessons.summary` 是可选字段。

### 推荐

默认不要求老师再写一篇“本节总结”。

系统可以自动派生：
- 本节处理 Case；
- 新增 Evidence；
- Intervention；
- Assessment；
- 完成/新建 Action。

只有存在无法由这些事实表达的整体课堂信息时，老师才补充短 summary。

---

# 19. Lesson → 周度跟进

领导 Excel 的周度跟进主要由 Lesson/Case 事实派生：

```text
本周授课内容
= lessons + optional summary

旧问题整改进度
= Case events + Assessments

新增问题
= new/confirmed Cases

本周整改动作
= Interventions

下周重点
= pending primary Actions
```

周度“综合判断”可以保留人工确认，但不能要求重新抄数据。

---

# 20. Lesson → 家长反馈

课后可以提供：

> “生成本节家长反馈草稿”

来源：
- 本节 relevant Case；
- Intervention；
- Assessment；
- Next Action。

但：

```text
生成草稿 ≠ 已发送
```

实际沟通进入 Parent Communication workflow。

---

# 21. Cancelled Lesson

`cancelled` 表示这次教学会话没有按计划完成。

不得用 cancelled 自动删除：
- 之前已经正式保存的 Evidence；
- Quick Capture；
- audit。

如果错误创建且没有正式事实，可通过受控取消保留最小历史，而不是物理删除。

---

# 22. Crash / 网络中断

### 老师在课中断网

- 已正式保存的 append facts 保留；
- 未提交输入保留在加密 local lesson draft；
- UI 明确“未同步/草稿”；
- 网络恢复后重试；
- 不显示假“已保存”。

### App 被杀

重新打开时：

> “你有一节未完成课程记录，是否继续？”

恢复必须按 user/org 隔离。

---

# 23. Android 与 Windows

## Android

高频：
- 开始课程；
- 切学生；
- 完成 Action；
- Quick Capture；
- 拍/选 Evidence（后续）；
- 记录短 Assessment。

避免长篇复盘表单。

## Windows

更适合：
- 课后完整收口；
- 多学生比较；
- 编辑较长 Judgment；
- 处理 version conflict；
- 阶段复盘。

同一领域语义，不同信息密度。

---

# 24. Lesson 不进入排课 ERP 的硬边界

当前可以知道：
- 什么时候实际开始/结束；
- 谁教；
- 哪个学科；
- 哪些学生参与；
- attendance status。

当前不扩：
- 课程套餐；
- 课时余额；
- 续费；
- 排班冲突；
- 教室资源；
- 教师工资；
- 招生来源。

如果以后真有需求，作为独立边界评估，不能污染学习闭环核心。

---

# 25. Acceptance scenarios

### A. 一对一

一个 Lesson + 一个 lesson_student，正常。

### B. 四人小班

一个 Lesson + 四个 lesson_students；每个学生各自 Case/Action，不复制 Lesson。

### C. 某学生本节无任何问题

允许 Lesson 完成，不强迫生成 Case。

### D. 课堂新问题未整理

允许 Lesson 完成，new Case 留待 formalize；后续 stale governance 提醒。

### E. 课后 Assessment passed

不能自动 stable/closed。

### F. 网络在课后提交时断开

输入保留；operation_id 重试不重复 Intervention/Assessment/Action。

### G. 另一老师同时更新 Case

expected_version 拒绝覆盖；保留本课输入，重新确认。

### H. 老师有语文学科 scope 但没分配该学生

不能开始该学生的普通语文 Lesson。

---

# 26. 对 Foundation 的拟议审查

进入 Phase 0B 前需进一步评估：

1. 是否新增 `start_lesson` 受控命令；
2. `complete_lesson` 对多人课采用整课事务还是可恢复分段事务；
3. Lesson draft 的加密存储与恢复 TTL；
4. Intervention/Assessment 哪些允许课中正式 append，哪些必须 complete_lesson 统一提交；
5. 是否需要防多个 in_progress lessons 的软/硬规则；
6. 是否需要 lesson purpose，默认不加直到有真实价值。

---

# 27. 决策结论

Phase 0A.6 当前冻结：

1. Lesson 是教学事实工作台，不是排课/课消 ERP；
2. 一对一与多人课共享同一个 Lesson 模型；
3. 课前只显示能指导本节决策的少量当前事实；
4. 课中只记录新事实，不填周报/阶段报告；
5. 课后系统自动整理，教师 30–60 秒确认闭环；
6. 高风险 Case/Action 变化继续走受控 command；
7. 课中未提交输入必须可恢复，不能因崩溃/断网白填；
8. Lesson 产生的事实成为周度/家校/阶段复盘素材，不重复录入；
9. 多人 Lesson 的事务粒度必须在 Phase 0B 用真实 command spike 验证，当前不伪造结论；
10. 建议评估 `start_lesson` 受控命令。
