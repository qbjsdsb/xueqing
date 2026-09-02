# 家校协同工作流｜Parent Communication Workflow

> 状态：Phase 0A.6 领域事实源。本文定义产品与领域语义，不授权进入正式 schema migration、微信/短信 API 或家长 App 实现。

## 1. 目标

领导 Excel 中的“家校沟通”不是一般通知，也不是为了证明“老师联系过家长”。它服务教学闭环：

`教学事实 → 教师/学管形成可理解反馈 → 实际沟通 → 家庭配合 → 家长回应 → 必要的下一步 → 后续复查`

Xueqing 的目标是让家校沟通复用已经存在的教学事实，而不是要求老师重新写一份平行学情。

核心原则：

1. **教学事实是来源，不重复录入。** Case / Evidence / Intervention / Assessment / Action / Lesson 已经存在的事实只引用、整理，不抄写成第二份结构化台账。
2. **草稿不是已沟通事实。** 系统/AI 生成文字、教师尚未发送的内容只能是 draft。
3. **实际沟通内容必须可追溯。** finalized/sent record 是当时真实沟通内容的冻结快照，不能随后续 Case 改变而静默变化。
4. **家庭配合是协作要求，不是假装成机构员工 Action。** Guardian 不是 organization membership；家庭任务不能塞进 `case_actions.assigned_membership_id`。
5. **家长回应不是自动专业结论。** 家长提供的新信息先作为来源事实/沟通回应，由有权限的教师判断是否成为 Observation / Evidence / Learning Case / Case Action。
6. **少而有用。** 不做每天打卡式“反馈完成率”，不以沟通次数评价教师。

---

## 2. 家校沟通的四个层次

### A. 单课反馈｜Lesson feedback
适合存在真实重要变化时使用，不要求每一节课机械发送。

典型内容：
- 本节重点；
- 与既有 Case 相关的可解释变化；
- 已做干预；
- 本次验证结果；
- 下一步；
- 必要的家庭配合。

### B. 问题跟进｜Issue follow-up
围绕一个或少数 Learning Case：
- 当前问题；
- 已经做了什么；
- 当前证据；
- 为什么还需要继续；
- 家庭如何配合；
- 何时复查。

### C. 周度综合｜Weekly update
默认由本周 Lesson / Case events / Assessment / Action 变化自动整理，不要求任课老师另填“周度台账”。

周度反馈可以是：
- 学科教师单学科版本；
- Advisor 基于权限允许的多个学科摘要形成综合版本。

### D. 阶段反馈｜Stage review communication
来源于 finalized stage report/review；对家长发送的是报告内容或其家长语言版本的冻结快照，不直接暴露内部备注、权限受限内容或不必要的专业原始字段。

---

## 3. Draft 与 Finalized 是不同事实

### Draft
Draft 可以：
- 系统根据真实事实生成；
- AI 辅助改写成家长易理解语言；
- 教师/Advisor 编辑；
- 暂存；
- 删除或放弃。

Draft **不能**：
- 作为“已联系家长”的统计事实；
- 触发“沟通完成”状态；
- 被当作家长已经看过的内容；
- 自动创建正式 Case 结论。

### Finalized / communicated
只有发生真实沟通后，才形成历史事实：
- 谁进行了沟通；
- 与谁沟通；
- 什么渠道；
- 何时；
- 实际发送/表达了什么；
- 家庭被请求配合什么；
- 家长回应什么；
- 是否需要后续动作；
- 下次跟进何时/由谁执行。

最终记录必须冻结当时内容。

---

## 4. 推荐领域语义

Phase 0A.6 先冻结语义，不立即建表。

### `communication_type`
候选：
- `lesson_feedback`
- `weekly_update`
- `issue_follow_up`
- `stage_review`
- `urgent`
- `other`

`urgent` 不是情绪标签，只用于确有必要尽快联系家庭的业务场景；不能发展成“风险评分”。

### `direction`
至少要能区分：
- `outbound`：机构主动反馈；
- `inbound`：家长主动提供信息；
- `conversation`：一次双向沟通的综合记录。

如果一次电话/面谈同时包含双方内容，优先使用 conversation snapshot，而不是人为拆成十几条消息。

### `status`
建议领域上至少有：
- `draft`
- `finalized`

是否需要额外 `sent / delivered / read` 取决于未来是否接第三方消息通道。V1/Pilot 手工微信/电话场景中，系统无法可靠证明 delivered/read，不应伪造这些状态。

---

## 5. 内容结构：事实、解释、协作分开

家长可见内容建议逻辑上分为：

1. **本次关注**：当前最值得家长知道的 1–3 件事；
2. **观察到的事实**：来自 Evidence / Assessment / Lesson 的简洁表达；
3. **机构已做的处理**：Intervention / Action；
4. **当前变化**：改善、仍不稳定、待验证；
5. **下一步**：机构后续计划；
6. **家庭配合建议**：具体、可执行、不过度增加家庭负担；
7. **家长回应**：实际反馈；
8. **后续跟进**：如需要，由哪个机构成员何时继续联系/复查。

禁止默认输出：
- 人格化评价；
- 没有证据的能力标签；
- “潜力值/风险值”；
- 过多内部业务术语；
- 其他学生信息；
- 非必要敏感信息。

---

## 6. 来源引用而不是复制

一个沟通记录可以逻辑上关联：
- Learning Case；
- Assessment；
- Evidence；
- Lesson；
- finalized Report。

但这些关联的目的只是解释“这次沟通基于什么”。

最终发送内容本身仍需要 snapshot，因为未来底层 Case 会继续变化。

原则：

`source refs = 可追溯来源`

`finalized content snapshot = 当时真正沟通了什么`

两者缺一不可。

---

## 7. 任课教师与 Advisor 的边界

### Subject Teacher
可以：
- 创建/确认自己有权限学科的反馈；
- 对本科 Case、Evidence、Assessment 做专业表达；
- 记录与家长实际沟通结果。

不能：
- 代表其他学科修改对方教师的专业结论；
- 因为能联系家长就读取所有跨学科细节。

### Advisor / Student Advisor
可以：
- 在权限允许范围内读取跨学科摘要；
- 整理综合家校反馈；
- 协调多个任课教师已经形成的专业结论；
- 记录家庭侧综合信息与后续协调。

不能：
- 静默重写 subject teacher 的专业原始结论；
- 通过“综合反馈”绕过学科读写权限。

### Academic Admin / Org Admin
用于必要治理、权限、纠错与审计；不应成为日常内容审批瓶颈。

---

## 8. 多监护人

当前 `parent_communications.guardian_id` 只能指向一个可选 guardian，可能不足以表达：
- 父母双方都在一次群聊中；
- 一位是主要联系人、另一位也收到阶段报告；
- 电话实际联系的是祖辈监护人。

Phase 0A.6 决策：**产品语义必须支持一次沟通对应一个或多个实际 recipient。**

数据库实现候选：
- 主记录 + `parent_communication_recipients` join；或
- 如果 Pilot 已确认永远只记录一个实际联系人，再延后多 recipient。

在正式 migration 前用机构真实流程验证，不能因为当前 Excel 一行只能填一个人就把领域锁死。

---

## 9. 家庭配合要求不是 Case Action

例：

> 本周写作文时，家长只提醒孩子先列 5 分钟提纲，不额外加作文数量。

这是 `home support request`，不是：

> `case_action.assigned_membership_id = 家长`

因为 Guardian 不是 staff membership。

如果机构成员需要后续处理，例如：

> 周五由 Advisor 联系家长确认执行情况。

这才是一个可以 assigned 给 membership 的机构 Action / follow-up。

是否需要独立 `communication_follow_up` 还是复用现有 action/任务模型，留到 Data Model Audit；原则是**不制造与 Case Action 冲突的第二套“教学下一步”**。

---

## 10. 家长回应如何进入教学闭环

家长回应可能只是沟通事实，例如：

> 家长确认收到，会按建议执行。

这不需要创建 Case。

也可能带来新的可观察信息，例如：

> 最近孩子在家完成阅读作业经常拖延到凌晨。

处理流程：

`Guardian response → 教师/Advisor 查看 → 判断与教学是否相关 → 必要时形成 Observation/Evidence/新 Case/现有 Case 补充 → 下一 Action`

关键规则：
- 系统不自动把家长陈述变成正式诊断；
- 必须保留来源是 guardian communication；
- 若进入 Case，应能追溯到原沟通事实；
- 与教学无关或不必要的家庭隐私不得为了“以后也许有用”而收集。

现有 Evidence `source_type` 尚无明确 guardian-report 类型；Phase 0A.6 后续 Data Model Audit 需决定是扩展 source type，还是由 Observation/communication reference 承载，不能现在默默塞进 `other` 后永久失去语义。

---

## 11. Follow-up

`follow_up_at` 只有日期并不足以保证执行。

正式产品至少要能回答：
- 是否真的需要机构后续动作；
- 谁负责；
- 什么时候；
- 是否已完成；
- 它关联哪个 Case/沟通。

但不能因此随意新造第二套 Todo 系统。

推荐原则：
- 与 Learning Case 教学闭环直接相关 → 尽量使用 Case Action；
- 纯沟通行政 follow-up → 评估轻量 communication follow-up 事实；
- 无需后续 → 不强迫填写日期。

---

## 12. 一次典型流程

```text
本周教学事实已经存在
        ↓
系统整理可用于家校的事实
        ↓
生成 Draft
        ↓
教师/Advisor 审阅并编辑
        ↓
复制到微信 / 电话 / 面谈
        ↓
记录实际沟通内容与 recipient
        ↓
Finalized snapshot
        ↓
记录家长回应 / 家庭配合
        ↓
必要时形成机构 follow-up 或教学事实
```

V1/Pilot **不要求**：
- 家长账号；
- 家长 App；
- 微信机器人/API；
- 短信网关；
- 已读回执；
- 自动催促家长。

---

## 13. 历史与纠错

Finalized communication 是历史事实，原则上不允许普通用户静默覆盖。

如果发现严重错误，推荐：
- 保留原记录；
- 受控 correction / superseded event；
- 记录谁、为什么、更正何时；
- 如已向家长发出错误内容，明确记录后续更正沟通。

不能直接把过去内容改成“从来没说过”。

---

## 14. 数据最小化

Guardian 信息只收集业务必要内容。

默认不需要：
- 身份证号；
- 职业；
- 收入；
- 精确家庭画像；
- 与教学无关的家庭隐私；
- 微信聊天完整原文/截图的大规模归档。

更适合保存的是：
- 实际联系人；
- 沟通渠道；
- 与教学相关的摘要；
- 家庭配合要求；
- 对教学有用的回应；
- follow-up。

附件如未来需要，必须私有存储、最小权限、明确保留期。

---

## 15. 对现有 Foundation 的潜在影响

正式 Data Model Audit 需要评估：

1. `parent_communications` 是否增加：
   - type；
   - direction；
   - status；
   - finalized_at；
   - content snapshot；
   - home-support snapshot；
   - guardian-response snapshot；
   - version / correction semantics。
2. 单一 `guardian_id` 是否升级为 recipients relation。
3. 如何保存 source refs，而不复制业务事实。
4. guardian response 进入 Observation/Evidence 的来源语义。
5. follow-up 是复用 Case Action 还是新增非教学型轻量任务。
6. 谁可以 draft / finalize / correct 的 RLS 与 command 边界。

本文件**不直接决定最终表结构**。

---

## 16. Acceptance scenarios

Phase 0A.6 Product Completeness Audit 至少验证：

1. 任课老师从本周两个 Case 生成反馈草稿，不需重新录入本周干预。
2. 草稿保存后退出，系统不能显示“已联系家长”。
3. Advisor 汇总三科内容，只能整理权限允许的摘要，不能改写数学老师原始专业结论。
4. 一次微信同时发给父母双方，历史能够表达实际 recipients。
5. 家长反馈带来一个新的学习相关事实，教师可以在保留来源的前提下建立/补充 Case。
6. 家长反馈只是“收到”，不会制造无意义 Case。
7. 家庭配合任务不被错误 assigned 给 staff membership。
8. 三个月后 Case 已 closed，过去发送给家长的内容仍保持当时 snapshot。
9. finalized 内容发现错误，有纠错历史，不静默覆盖。
10. 没有家校沟通权限的教师不能通过 source refs 越权读取其他学科细节。

---

## 17. 当前冻结结论

- 家校沟通属于教学闭环，不是独立 CRM。
- Draft 与真实 communicated/finalized fact 必须严格分离。
- Finalized 内容必须冻结快照并保留来源引用。
- Subject Teacher 与 Advisor 的专业边界必须保留。
- 家庭配合不是 staff Case Action。
- Guardian response 不自动成为专业结论。
- 产品语义支持多 recipient；最终 schema 在 migration 前再冻结。
- V1/Pilot 优先“生成/复制 + 记录实际结果”，不做第三方消息平台集成。
