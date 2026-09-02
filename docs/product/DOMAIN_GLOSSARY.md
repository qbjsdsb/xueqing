# Xueqing Domain Glossary｜业务语言与领域语义

状态：Phase 0A.6 product foundation draft  
目标：让领导、教师、产品、设计、Flutter、数据库、RLS 和审计使用**同一套语义**，避免“同一个词不同含义”或“不同词其实是同一事实”。

---

## 1. 词汇分层原则

Xueqing 同时存在三类语言：

1. **机构教学语言**：领导和老师自然使用，例如“三阶订正、清零、跨周、顽固问题”；
2. **领域语言**：系统稳定业务概念，例如 Learning Case、Evidence、Assessment、Case Action；
3. **技术语言**：数据库/代码实现，例如 UUID、RLS、timestamptz、version。

原则：

> 教学语言可以友好，领域语义必须唯一，技术实现不能偷偷改变业务含义。

---

# 2. Student / 学生

## Student

机构内一个真实学生的稳定身份。

不是：
- 一次报名；
- 一门学科；
- 一个老师名下的学生副本；
- 一学期新建一份档案。

学生升年级、换老师、换学科、换校区，Student identity 仍连续。

## Enrollment / 就读关系

学生在某学期/校区/年级/班级的时间化关系。

用途：保存变化历史，避免 `student.grade = 九年级` 直接覆盖过去。

## Student Subject Profile / 学科学情主线

同一 Student 在某一机构学科上的连续上下文。

例如：
- 张三 · 语文；
- 张三 · 数学。

换任课教师不新建 Subject Profile。

### 当前学情定位

领导 Excel 的“基础薄弱 / 中等待提升 / 中等稳定 / 培优拔高”等表达属于**当前教学定位**，不是学生永久属性。

Phase 0A.6 尚未冻结具体存储方式，但语义要求：
- subject-scoped；
- time-sensitive；
- 不替代具体 Case/Evidence；
- 不作为人格评价。

### 学科优势 / 课堂优势

用于记录和呈现帮助教学判断的优势事实/摘要。

不是“潜能分”或“天赋值”。

---

# 3. Initial Diagnosis / 初诊

新接手学生/新学科时，对当前学情进行结构化理解的**工作流**。

Initial Diagnosis 不是独立永久台账。

它可以产生：
- Subject Profile context；
- strengths；
- candidate issues；
- confirmed Learning Cases；
- first Actions。

---

# 4. 三类问题

## Knowledge / 知识漏洞

学生对知识、概念、方法、题型等存在可独立跟进的问题。

常适合使用机构的“三阶订正”默认 workflow。

## Habit / 学习习惯

可观察、可干预、可重复观察的学习行为问题。

必须描述具体行为，不使用：
- 懒；
- 不自律；
- 态度差；
等人格化推断作为事实。

## Exam Strategy / 考试技巧

在审题、时间分配、答题规范、迁移策略、考场应用等方面的可跟进问题。

验证重点是：方法是否能在更接近真实考试的条件下独立迁移。

## Other / 其他

用于真实存在但不适合前三类的问题。

不得因为“其他”方便而让 taxonomy 失去意义。

---

# 5. Learning Case / 学情 Case

一个需要被持续跟进、可以独立解释进展与下一步的学习问题。

正式 Case 应最终能够回答：

```text
问题是什么？
凭什么这样判断？
教师怎么理解原因？
做过什么？
结果如何？
下一步是什么？
是否稳定？
是否复发？
```

Learning Case 是闭环最小业务单元。

### Case code / 可读编号

Excel 的“问题编号”表达的是引用/追踪需求。

内部主键仍使用 UUID。是否增加类似 `C-012` 的人类可读编号留待 Data Model audit；不能让老师手工维护唯一编号。

---

# 6. Case lifecycle

领域状态严格只有：

```text
new
→ confirmed
→ intervening
→ pending_verification
→ stable
→ closed
```

不得增加 `reopened` 第七状态。

---

## new / 待整理

课堂或初诊中快速捕捉的问题草稿。

可暂缺：
- 完整 taxonomy；
- owner；
- 根因；
- primary action。

教学 UI 推荐文案：**待整理**。

不是正式闭环结论。

---

## confirmed / 已确认跟进

教师确认问题值得正式持续跟进。

必须具备必要结构，例如：
- 有效 owner；
- problem type / taxonomy；
- 可解释 Evidence；
- pending primary Action。

推荐教学文案根据场景可用：
- 已确认；
- 待整改；
- 已纳入跟进。

不要把 `confirmed` 翻译成“已解决”。

---

## intervening / 整改中、干预中

正在实施教学干预。

与 Excel “整改中”语义最接近。

仍必须有 primary next Action。

---

## pending_verification / 待验证

已经发生了干预或检查事实，但 Case 正在等待进一步验证/教师确认。

关键规则：

> Assessment result 与 Case status 分离。

一个 assessment passed 可以使 Case 进入“值得教师判断是否稳定”的上下文，但不能自动 stable/closed。

UI：**待验证**。

---

## stable / 已改善、稳定观察

已有足够证据支持明显改善，但仍需要观察复查。

与 Excel 中“已改善”最接近。

必须继续存在 `review` / `verify` primary Action。

推荐 UI：
- 已改善；
- 稳定观察。

禁止直接显示“已清零”。

---

## closed / 已清零

Case 退出主动跟进。

领域规则：
- 不存在 pending primary Action；
- 历史完整保留；
- 后续再次出现问题时使用 `reopen_case`。

机构教学语言推荐：**已清零**。

对于曾长期顽固的问题，UI 可以在历史/总结中使用“已彻底清零”作为强调性描述，但**不增加第二个 closed 状态**。

### 清零的硬语义

“清零”是教师的强结果判断：

> 当前没有必要继续保持主动 Case tracking。

因此：

```text
一次做对 ≠ 清零
一次满分 ≠ 清零
一次 Assessment passed ≠ 清零
stable ≠ 清零
closed ≈ 已清零
```

closed 的具体前置条件由 Commands/Data Model audit 冻结，不在 UI 中自行判断。

---

# 7. reopen / 重新打开、复发

`reopen` 是**受控命令 + event**。

用于：
- closed 后问题重新出现；
- 有新 Evidence 证明需要恢复主动跟进。

效果通常包括：
- Case 恢复到合法 active state；
- 建立新的 pending primary Action；
- `reopened_count` 增加；
- timeline 记录为什么重开。

不是：
- `reopened` status；
- 新建一个重复 Case 来绕过历史。

教学语言：
- 重新打开；
- 复发；
- 再次纳入跟进。

---

# 8. Evidence / 证据

教师**看到了什么**。

示例：
- 试卷错题；
- 作文片段；
- 课堂练习结果；
- 小测；
- 可观察课堂事实。

Evidence 不是教师判断。

### 正确

> 三道原因概括题中，两题只写出一个得分点。

### 错误混写

> 学生概括能力很差，所以不认真。

后者混合了评价、原因推断甚至人格判断。

---

# 9. Teacher Judgment / 教师判断

教师基于 Evidence 对当前问题的专业解释。

例如：

> 主要障碍不是找不到原文，而是没有按题目分值组织多点答案。

重要变化应留下历史事件，不能用不断覆盖当前摘要让过去判断无法解释。

---

# 10. Intervention / 教学干预、整改动作

教师**实际实施过**的教学处理。

例如：
- 重新讲解；
- 用数轴演示；
- 强制先列提纲；
- 练习“已知—求—关系”复述。

Intervention 不是未来计划。

未来计划属于 Action。

---

# 11. Assessment / 检查结果

一次后续检查/验证的结果事实。

Foundation result：
- passed；
- partial；
- failed；
- not_scored。

推荐教学语言：
- 本次通过；
- 部分通过 / 仍不稳定；
- 未通过；
- 本次未评分。

## 三阶结果与 Assessment

Excel 的“一阶/二阶/三阶”可以由一个或多个 Intervention/Assessment/Action 组合表达。

不得建立：

```text
assessment_result = 清零
```

因为 Assessment 是单次结果，清零是 Case lifecycle 结论。

---

# 12. Verification / 验证

“验证”是业务过程，不必等于一张独立表。

通常由：
- verify Action；
- Assessment；
- Evidence；
- Case command；
共同构成。

---

# 13. Three-stage correction / 三阶订正

领导的知识类默认教学 workflow：

```text
一阶：当堂订正
二阶：相似题巩固
三阶：延迟/次课独立验证
```

它是：
- 教学方法模板；
- 教师熟悉的工作语言。

它不是：
- Case lifecycle；
- 三个固定数据库列；
- 所有 Habit/Exam Strategy 都必须使用的流程。

---

# 14. Cross-week follow-up / 跨周跟进

Excel 中“三阶后仍有漏洞 → 跨周跟进”。

Xueqing 不新增 `cross_week` Case status。

跨周由真实事实自然表达：
- Case 仍 active；
- due Action 落在后续日期；
- timeline 跨越多周；
- assessments/interventions 持续产生。

“跨周”是时间维度的工作状态/展示标签，不是第七个生命周期状态。

---

# 15. Stubborn / 顽固问题、长期重点

不是手工永久标签。

由同一 Case 的历史事实派生，例如：
- 持续时间长；
- repeated partial/failed；
- 多轮 intervention；
- reopen；
- 长期无稳定改善。

产品推荐使用：
- 长期重点；
- 多次验证未通过；
- 建议重新分析原因。

“顽固”是领导原有语言，可以保留，但应避免对学生人格贴标签；尽量表达为“顽固问题/长期问题”，而不是“顽固学生”。

---

# 16. Case Action / 下一行动

未来明确要做什么。

例如：
- 重新讲解；
- 布置练习；
- 下次验证；
- 联系家长；
- 观察复查。

Action != Intervention：

```text
Action = 计划做
Intervention = 已经做
```

### Primary Action

正式未关闭 Case 的唯一核心下一步。

Foundation 不变量：
- new 可没有；
- confirmed/intervening/pending_verification/stable 必须有一个 pending primary；
- closed 不得有 pending primary。

---

# 17. Today / 今日

教师当前工作队列，不是 Dashboard。

普通 Action bucket：
- overdue / 已逾期；
- today / 今天到期；
- future / 未来；
- undated / 待安排。

`pending verification` 是 Case 级语义 bucket，不与普通 action queue 重复。

Today 的任务是告诉老师：

> **现在先做什么。**

不是展示“机构今天有多少数据”。

---

# 18. Lesson / 课程、教学会话

一次真实教学会话的业务上下文。

用于关联本节课发生的：
- Intervention；
- Assessment；
- Evidence；
- Action completion；
- Quick Capture。

Lesson 不是：
- 收费课消；
- 完整课表；
- 招生 CRM。

---

# 19. Teacher Subject Scope / 教师学科范围

Phase 0A.6 新增需要冻结的领域概念：

> 某 membership 在机构内被授权/配置可以在哪些 organization subjects 承担学科教师类工作。

它回答：

> **这个老师可以教/负责哪些科？**

不是：

> **这个老师当前具体负责哪些学生？**

后者属于 Student Teacher Assignment。

---

# 20. Student Teacher Assignment / 学生学科教师分配

实际业务关系：

```text
Student
+ Organization Subject
+ Teacher Membership
+ lead / collaborator
+ active period
```

回答：

> 乔老师当前是不是张三语文的 Lead？

不得从 Assignment 反推 Teacher Subject Scope。

---

# 21. Lead / 主负责教师

同一 student + subject 的主要负责教师。

Foundation 默认同一时间最多一个 active Lead。

通常可承担：
- Case owner；
- 教学结论确认；
- primary Action；
- 本学科阶段复盘。

具体权限仍由 role/capability/RLS 冻结，不因为显示为 Lead 就绕过 live session/organization checks。

---

# 22. Collaborator / 协作教师

同一 student + subject 的协作教师。

可以在被授权范围参与教学和事实记录，但不应自动获得超出 assignment/role 的组织权限。

Lead 与 Collaborator 是业务关系，不是登录角色。

---

# 23. Advisor / 学管、学生负责人

跨学科综合协调角色/assignment。

可以：
- 查看授权的综合状态；
- 组织家校沟通；
- 协调跨学科行动。

不能：
- 冒充语文/数学任课教师；
- 静默改写专业学科结论。

---

# 24. Subject Lead / 学科负责人

在某学科范围承担管理/教研能力。

角色本身不意味着读取整个机构所有学科数据。

具体 subject scope 必须能被授权模型解释。

---

# 25. Parent Communication / 家校沟通

一次真实发生的家校沟通事实。

必须区分：
- draft；
- finalized/sent/discussed snapshot；
- guardian response；
- follow-up。

“生成了一段家长反馈文案” ≠ “已经和家长沟通过”。

---

# 26. Home Support Request / 家庭配合要求

老师向家庭提出的具体配合建议/任务。

例如：

> 本周完成作文时，只监督先列 5 分钟提纲，不额外增加作文数量。

guardian 不是 organization membership，因此家庭任务不能伪装成 `case_actions.assigned_membership_id = guardian`。

教师后续检查家庭配合情况，可形成自己的 communicate/review Action。

---

# 27. Stage Review / 阶段复盘

针对一个明确周期，对学生当前进展进行人工确认的业务快照。

系统可自动整理 source facts；教师负责：
- 整体进步判断；
- 遗留问题；
- 下一阶段计划；
- finalize。

finalized 后不随底层事实静默变化。

---

# 28. Snapshot / 冻结快照

保存“当时最终确认/发出的内容”。

适用于：
- finalized report；
- 实际发送的家长反馈。

Snapshot != 当前实时页面。

如果底层 Case 后续变化，历史 Snapshot 仍保持原样。

---

# 29. Derived View / 派生视图

由真实事实计算或聚合得到，不应要求教师重复填写。

例如：
- 本周新增 Case；
- 本周 closed；
- 长期重点；
- overdue；
- pending verification；
- 周度摘要；
- 家长反馈草稿素材。

判断规则：

> 如果删除这个派生视图，原始业务事实仍完整存在，那么它通常不应该成为第二套主数据。

---

# 30. Governance Anomaly / 治理异常

系统发现的、需要机构处理的数据/责任异常。

例如：
- active Case 无有效 owner；
- action assignee disabled；
- 长期未验证；
- handoff 未完成；
- duplicate student。

它是可处理事实条件，不是“风险指数”。

---

# 31. Draft / 草稿

尚未成为正式云端业务事实的可恢复输入。

必须清楚区分：
- local draft；
- saved formal fact。

UI 不得把本机暂存显示成“已保存到机构”。

---

# 32. Version conflict / 并发冲突

用户基于旧 version 尝试修改已经被其他人更新的关键快照。

行为：
- 拒绝 silent overwrite；
- 获取最新；
- 保留用户未提交输入；
- 让用户重新确认。

---

# 33. 禁用/容易误导的词

以下词除非有严格业务定义，否则不要进入正式产品：
- 成长指数；
- 学习潜力值；
- 综合健康分；
- 风险分；
- 教师效能分；
- AI 已判断清零；
- AI 正式诊断；
- 自动稳定；
- 自动关闭。

原因：它们容易制造伪精确、责任不清或把专业判断交给不可解释的派生逻辑。

---

# 34. 一页映射表

| 领导/教师语言 | 正式领域语义 | 备注 |
|---|---|---|
| 初诊 | Initial Diagnosis workflow | 不是第二台账 |
| 三类问题 | Case type | knowledge / habit / exam_strategy |
| 待整改 | confirmed / queued for intervention | 具体 UI 按上下文 |
| 整改中 | intervening | active Case |
| 一阶订正 | knowledge workflow intervention/assessment | 非 status |
| 二阶巩固 | knowledge workflow practice/assessment | 非 status |
| 三阶小测 | verification assessment | 非 status |
| 本次通过/满分 | Assessment passed | 不等于清零 |
| 已改善 | stable | 仍有 review/verify action |
| 稳定观察 | stable | 推荐清晰文案 |
| 已清零 | closed | 退出主动跟进 |
| 已彻底清零 | closed + 历史说明 | 不新增状态 |
| 跨周跟进 | active Case across time + future Action | 不新增 status |
| 顽固问题 | derived long-running/repeated-failure Case | 不独立表 |
| 复发 | reopen event/command | 不新增 status |
| 整改动作 | Intervention（已做）或 Action（计划） | 必须区分时态 |
| 下周重点 | future primary Actions / derived summary | 不重复录入 |
| 家校配合 | Home Support Request | guardian 非 membership |
| 家校沟通 | Parent Communication | actual event/snapshot |
| 阶段复盘 | Stage Review / Report snapshot | system facts + human judgment |
| 老师签字 | finalized_by + finalized_at | 不要求图片签名 |

---

# 35. Glossary acceptance rule

任何新功能、字段、命令、页面在进入实现前，应先确认：

1. 它使用的业务词在本 glossary 是否已经存在；
2. 若不存在，是新的真实概念还是旧概念换了一个名字；
3. 是否会制造第二套 lifecycle / next action / verification / responsibility 事实源；
4. UI 文案是否会让教师误解领域状态。

如果两个实现团队能对同一句“这个问题已经清零了”产生不同数据库解释，则 Phase 0A.6 视为**未冻结成功**。
