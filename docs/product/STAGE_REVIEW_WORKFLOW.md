# 阶段复盘工作流｜Stage Review Workflow

> 状态：Phase 0A.6 领域事实源。目标是把领导 Excel 的“阶段复盘 + 授课老师确认”软件化；不新增第二套重复台账，不授权进入正式 schema migration。

## 1. 目标

阶段复盘回答的不是“这个月填了多少记录”，而是：

- 这个阶段学生真正发生了什么变化；
- 哪些问题已经稳定/清零；
- 哪些问题仍然存在；
- 哪些干预有效/无效；
- 下一阶段最重要的方向是什么；
- 谁对这份专业判断进行了确认。

领导 Excel 中的“复盘人 / 授课老师签字 / 总结日期”本质是**专业责任确认与历史留痕**，不是为了模拟纸质签字。

---

## 2. 不重新填写已经存在的事实

Stage Review 的事实来源优先是：
- Learning Cases；
- Case Events；
- Evidence；
- Interventions；
- Assessments；
- Case Actions；
- Lessons；
- 必要的 finalized Parent Communications。

老师不应重新抄写：
- 本阶段上了几节课；
- 哪些 Case closed；
- 哪次 assessment failed；
- 已完成哪些 Action。

这些都是系统可以确定的事实。

老师真正需要人工承担的是：
- 整体进步判断；
- 遗留问题的解释；
- 下一阶段优先级/策略；
- 必要的专业备注；
- 最终确认。

---

## 3. 复用现有 `reports`，不默认新增 `stage_reviews`

现有 Foundation 的 `reports` 已经有：
- `period_start / period_end`；
- `generated_at / generated_by`；
- `source_cutoff_at`；
- `template_version / content_schema_version`；
- `content_snapshot`；
- `draft / finalized`。

这已经很好地表达“系统整理 + 最终冻结快照”。

Phase 0A.6 默认结论：**优先增强 `reports` 语义，不为“阶段复盘”再建一张平行表。**

只有后续发现“内部复盘”和“对外报告”在权限、生命周期或内容结构上不可调和，才考虑拆分。

---

## 4. 两种视角

### Subject Stage Review
针对一个 Student Subject Profile：
- 本学科阶段变化；
- 重点 Case；
- 已稳定/已清零；
- 仍需跟进；
- 主要有效/无效干预；
- 下一阶段计划。

专业结论由对应学科有权限的教师确认。

### Comprehensive Stage Review
跨学科综合视角：
- 每科必要摘要；
- 跨学科共性问题；
- 学习节奏/协调事项；
- 家校协同事项；
- 下一阶段总体重点。

Advisor 可以组织综合内容，但不能改写各学科已经 finalized 的专业原始结论。

---

## 5. Draft 生成流程

```text
选择 period / subject context
        ↓
冻结 source_cutoff_at
        ↓
系统读取截止时间前的正式事实
        ↓
生成结构化事实摘要
        ↓
教师/Advisor 做专业判断
        ↓
Draft
        ↓
复核
        ↓
Finalized snapshot
```

`source_cutoff_at` 很重要：它让历史报告可以解释“当时依据的事实范围”，而不会因为第二天新增数据就改变昨天的报告含义。

---

## 6. 推荐内容结构

### A. 自动事实摘要
系统自动生成：
- 本阶段 active / closed / reopened Case；
- 重要 Assessment 结果；
- 主要 Intervention；
- overdue / completed Action 变化；
- 长期未解决问题；
- 有意义的稳定/清零事件。

不要展示为了“显得数据化”而制造的大量百分比。

### B. 教师人工判断
至少包括：
- `overall_progress_judgment`：本阶段整体进步；
- `remaining_issues_judgment`：现存遗留问题；
- `next_stage_plan`：下一阶段整改/教学计划。

可选：
- 特别说明；
- 家校需要配合的事项；
- 需要协调其他学科/工作人员的事项。

### C. 责任确认
Finalized 时记录：
- finalized_by_membership_id；
- finalized_at；
- subject/comprehensive context；
- source_cutoff_at；
- content_snapshot。

UI 可以显示：

> 乔老师 · 已确认 · 2026-09-30 18:42

不必模拟手写签字图片。

---

## 7. Finalized 的语义

Finalized 代表：
- 这是某一时点正式确认的阶段判断；
- 内容冻结；
- 以后底层 Case 更新不会回写历史报告；
- 可用于家校阶段反馈；
- 可以被后续报告引用作为历史背景。

Finalized **不代表**：
- 所有 Case 都必须 closed；
- 学生“阶段结束”；
- 教师以后不能改变观点；
- 报告内容永远不能纠错。

新的事实/观点应进入后续 Case event 或下一份 Stage Review。

---

## 8. 纠错

普通业务不能静默编辑 finalized snapshot。

严重错误可采用：
- correction / superseded 状态或事件；
- 保存原 finalized snapshot；
- 记录更正原因、人员、时间；
- 新快照引用被更正版本。

这样历史仍然能回答：

> 当时老师实际确认了什么？后来为什么更正？

---

## 9. AI 的边界

AI 可以：
- 从正式事实中整理 draft；
- 压缩冗余；
- 改写为家长可理解语言；
- 提醒遗漏的数据来源。

AI 不可以自动：
- 宣布“学生已清零”；
- 把 assessment passed 升级为 stable/closed；
- 生成未经教师确认的正式专业判断；
- 给学生打“潜力/风险/健康分”；
- 替代 finalized_by。

Finalized 必须有人类授权成员确认。

---

## 10. 与家校沟通的关系

Stage Review 和 Parent Communication 不是同一个对象：

- Stage Review：内部/专业阶段判断；
- Parent Communication：实际对外沟通事实。

可以：

`Finalized Stage Review → 生成家长语言 Draft → 实际沟通 → Finalized Parent Communication`

不能把“生成了阶段报告”当成“已经告知家长”。

---

## 11. 权限

### Subject Teacher
- 可创建/编辑本人有学科编辑权的 subject report draft；
- 可 finalize 授权范围内的 subject review；
- 不能改其他学科 finalized 结论。

### Subject Lead
- 本学科范围内可按机构规则 review；
- 是否需要二次审批不是 V1 默认前置，避免制造行政瓶颈。

### Advisor
- 可读取权限允许的跨学科摘要；
- 创建综合 draft；
- 不能改写 subject finalized source。

### Academic Admin
- 必要的跨学科治理/纠错权限；
- 必须审计。

### Org Admin
账号与治理能力不等于默认承担教学专业确认。

---

## 12. 时间边界

`period_start / period_end` 是 organization timezone 下的业务日期。

`source_cutoff_at / generated_at / finalized_at` 是服务端权威时间点。

必须明确：
- 晚补录一条发生在上月的 Evidence，是否进入已经 finalized 的上月报告？答案默认 **不进入原快照**；
- 它可以在下一阶段解释“补录的历史事实”，或通过受控 correction 处理。

这避免历史报告被后台补录悄悄重写。

---

## 13. 什么时候生成阶段复盘

产品不强迫固定“每月底所有人填一次”。

可由机构设置轻量规则，例如：
- 月度；
- 一个教学阶段结束；
- 家长阶段沟通前；
- 教师交接前；
- 重要考试后。

但系统只提醒“需要复盘”，不复制所有事实让老师再次录入。

---

## 14. Data Model Audit 的候选调整

现有 `reports` 可能需要评估增加：
- `report_type`：subject_stage / comprehensive_stage / parent-facing 等；
- `reviewed_by` / `finalized_by` 区分是否必要；
- `finalized_at`；
- `supersedes_report_id` 或 correction event；
- source references 的规范形式。

但必须先问：这些是否为真实新事实，而不是 `content_snapshot` 内可表达的结构。

不要因为文档有章节，就把每一项变成数据库列。

---

## 15. Acceptance scenarios

1. 某学生本月有 4 个 Case，老师生成阶段复盘时不需重新填写每个 Case 的状态。
2. 一个 Assessment passed 但 Case 仍 pending_verification，自动摘要不能写成“已清零”。
3. 老师写完 draft 但未 finalize，系统不能把它当正式阶段判断。
4. Finalized 后第二天 Case reopen，旧报告仍保持当时内容；新 reopen 进入后续报告。
5. Advisor 生成综合报告时能引用各科摘要，但不能修改各科 finalized source。
6. Finalized report 生成家长反馈 draft，不自动等于已沟通。
7. 补录历史 Evidence 不静默重写已 finalized 报告。
8. 报告错误更正保留原始版本与更正历史。
9. 教师离职后，其历史 finalized report 仍能显示原确认人。
10. AI 生成的 draft 未经授权成员确认不能成为 finalized。

---

## 16. 当前冻结结论

- 阶段复盘优先复用现有 `reports`，不新增重复 `stage_reviews` 表。
- 系统自动整理事实，教师只承担真正需要专业判断的部分。
- `source_cutoff_at + content_snapshot + finalized` 是历史可解释性的核心。
- Finalized 是冻结责任快照，不随底层事实变化。
- Subject 与 comprehensive 视角必须区分专业权限。
- AI 只能协助 draft，不能代替专业确认。
- 对家长的实际沟通仍需要单独 Parent Communication 事实。
