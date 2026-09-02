# 家校协同工作流｜Parent Communication Workflow

> 状态：Phase 0A.6 领域事实源。本文定义产品与领域语义，不授权进入正式 schema migration、微信/短信 API 或家长 App 实现。

## 1. 核心目标

领导方法中的家校沟通服务教学闭环，而不是证明“老师联系过家长”：

```text
教学事实
→ 形成可理解反馈
→ 实际沟通
→ 家庭配合
→ 家长回应
→ 必要的教学/沟通后续
→ 后续复查
```

Xueqing 必须复用已经存在的 Case / Evidence / Intervention / Assessment / Action / Lesson，而不是让老师再写一份平行学情。

核心原则：

1. **教学事实只记录一次。** 家校内容引用、整理真实事实，不重复维护第二套结构化学情。
2. **Draft 不是已沟通。** AI/系统生成、教师尚未实际发送/表达的内容只能是 draft。
3. **每次真实沟通事件独立冻结。** Finalized 代表“当时实际发生了什么”，不能随后续 Case 或后续家长回复被静默改写。
4. **家长回复是新的事实。** 上午老师已经 finalized 的 outbound，晚上家长再回复，应新增 inbound/reply communication，而不是回头修改上午记录。
5. **同一现场双向交流可以一条 conversation snapshot。** 电话/面谈中双方当场完成的一次连续对话，无需机械拆成十几条消息。
6. **家庭配合不是 staff Action。** Guardian 不是 organization membership。
7. **家长回应不是自动专业结论。** 先保留来源，再由授权教师判断是否形成 Evidence / Case / Action。
8. **少而有用。** 不做每日打卡式反馈，不以沟通次数评价教师。

---

## 2. Communication 是“事件”，不是会被不断编辑的聊天线程

### 错误模型

```text
一条 Parent Communication
上午老师发出
→ finalized
晚上家长回复
→ 修改原 finalized guardian_response
第二天又补充
→ 再修改同一记录
```

这样历史无法回答：
- 上午老师当时到底发了什么；
- 家长回复发生在什么时候；
- 哪个后续动作是由哪一次回复触发。

### 正确模型

```text
Communication A
outbound · finalized · 09:30
“本周阅读答题……家庭可配合……”

Communication B
inbound · finalized · 20:10
reply_to = A
“孩子最近在家经常拖到很晚……”

Communication C
outbound/conversation · finalized · 次日
reply_to/thread = A
“已了解，下一阶段先调整……”
```

因此 Parent Communication 主对象是**不可变历史事件 + 可编辑 Draft**。

如未来 UI 需要“一个会话线程”，线程只是多条 communication events 的聚合展示，不是不断覆盖的一条 finalized row。

---

## 3. 四类常用业务场景

### A. Lesson Feedback
有真实重要变化时使用，不要求每节课机械发送。

### B. Issue Follow-up
围绕一个或少数 Learning Cases 说明：问题、已做处理、当前证据、为什么仍需继续、家庭如何配合、何时复查。

### C. Weekly Update
从本周 Lesson / Case Event / Assessment / Action 自动整理，可由 Subject Teacher 做单科版本，也可由 Advisor 在权限允许范围做综合版本。

### D. Stage Review Communication
来源于 finalized Stage Review / Report，但对外沟通本身仍形成独立 Parent Communication event。

Finalized Report ≠ 已经告知家长。

---

## 4. Direction

至少：
- `outbound`：机构主动反馈；
- `inbound`：家长主动提供信息/回复；
- `conversation`：电话/面谈等一次现场双向交流的综合事实。

### outbound
记录机构实际表达给家长的内容。

### inbound
记录家长实际向机构提供的、与教学业务有必要保留的信息。

### conversation
适合电话/面谈中双方在同一 interaction 内完成的双向讨论；可以同时包含：
- institution message；
- home support agreed；
- guardian response。

**conversation 不是用来把几天的微信往来压成一条可变记录。**

---

## 5. Draft 与 Finalized

### Draft
可以：
- 系统根据正式事实生成；
- AI 辅助转成家长易懂语言；
- 教师/Advisor 编辑；
- 放弃/删除；
- version conflict 时保留输入。

不能：
- 计为“已联系家长”；
- 当成家长已经看过；
- 自动触发正式 Case 结论；
- 作为对外历史事实。

### Finalized
只有真实沟通发生后才形成。

至少记录：
- actor；
- recipient(s)；
- direction；
- channel；
- occurred_at；
- 实际沟通 snapshot；
- 当次家庭配合（如有）；
- 当次现场家长回应（conversation 时可有）；
- follow-up（如有）；
- finalized_by / finalized_at。

Finalized 后普通业务不允许覆盖内容。

---

## 6. Thread / Reply 关系

为了把多次沟通组织成可理解会话，可保留轻量关系：

- `reply_to_communication_id`：这次事件直接回应哪一条；
- 可选 `thread_root_communication_id` 或由递归/查询派生 thread root。

### 原则
- 关系只用于上下文组织；
- 每条 event 自己有独立 actor/time/direction/content；
- 不能把 thread 当成 mutable finalized object；
- cross-student / cross-organization reply 必须数据库拒绝。

如果 V1 UI 暂时不展示线程，也可以先只实现 `reply_to`，不要为了漂亮聊天界面过度建模。

---

## 7. 内容结构

Outound / Conversation 中家长可见内容逻辑上可包含：

1. 本次关注；
2. 可解释事实；
3. 机构已经做的处理；
4. 当前变化；
5. 机构下一步；
6. 家庭配合建议。

Inbound / Conversation 中可包含：
- guardian response summary；
- guardian-reported observation；
- 已确认/未确认的家庭配合情况。

禁止默认输出/收集：
- 人格化评价；
- 无证据能力标签；
- 潜力/风险分；
- 其他学生信息；
- 与教学无关家庭隐私；
- 大规模归档完整微信聊天原文/截图。

---

## 8. Source refs 与 snapshot 分开

Communication 可以关联：
- Learning Case；
- Assessment；
- Evidence；
- Lesson；
- finalized Report。

`source refs` 回答：

> 为什么当时这样沟通？

`content snapshot` 回答：

> 当时实际上说了什么？

底层 Case 后续变化不修改旧 communication snapshot。

---

## 9. 权限边界

### Subject Teacher
- 创建/确认自己合法 Student+Subject 范围的反馈；
- 对本科事实做专业表达；
- 记录本人实际家校沟通。

### Advisor
- 读取被允许共享的跨学科摘要；
- 整理综合家校 Draft；
- 记录本人实际沟通；
- 负责综合 follow-up。

但不能通过综合文案改写原 Subject finalized source。

### Subject Lead / Academic Admin
可以按机构规则 review/govern；不能因管理身份伪造任课教师专业事实。

### Org Admin
治理能力不等于默认家校沟通责任。

---

## 10. 多监护人

一次沟通可能：
- 父母双方同时在群里；
- 电话联系祖辈；
- 阶段反馈同时给两名监护人。

产品语义必须允许一个 communication event 有一个或多个 actual recipients。

候选数据库：

`parent_communication_recipients`
- communication_id
- guardian_id

不因为 Excel 一行只写一个对象就永久锁死为单 `guardian_id`。

---

## 11. 家庭配合不是 Case Action

例如：

> 本周写作文时，家长只提醒孩子先列 5 分钟提纲。

这是 communication 中的 home-support agreement/request，不是：

`case_action.assigned_membership_id = guardian`

如果机构员工需要后续：

> 周五由 Advisor 再联系家长确认执行情况。

才是 staff follow-up。

---

## 12. Guardian response 如何进入教学闭环

### 同一 phone/in-person interaction
可以在 `conversation` snapshot 中记录 guardian response。

### 后续异步回复
必须新增 `inbound` communication event，并 `reply_to` 原 outbound/thread。

### 转成教学事实

```text
Guardian response event
→ 授权教师判断
→ 与教学相关？
    ├─ 否：只保留必要沟通事实
    └─ 是：形成 guardian_report Evidence / Observation / Case补充
→ 必要 Action
```

必须保留来源 communication ID。

系统不自动把家长陈述变成诊断。

---

## 13. Follow-up

只写 `follow_up_at` 不够。

### Case-related
与某 Learning Case 直接相关的员工沟通后续，优先使用：

`Case Action(action_type=communicate)`

这样 Today 仍只有一个教学行动事实源。

### Non-case communication follow-up
例如“下周由 Advisor 再确认家庭执行情况”，但不属于某一个 Case，可使用 communication 自身轻量：
- assigned membership；
- due_at；
- status；
- completed_at。

**不建立通用第二套 staff Todo 系统。**

---

## 14. 典型流程一：老师主动反馈，家长稍后回复

```text
正式教学事实已存在
↓
系统生成 outbound Draft
↓
教师审阅
↓
微信实际发送
↓
Finalize Communication A (outbound)
↓
晚上家长回复
↓
创建 Communication B (inbound, reply_to=A)
↓
授权教师判断 B 是否成为 guardian_report Evidence
↓
必要 Case/Action
```

A 永远不因为 B 出现而被修改。

---

## 15. 典型流程二：电话/面谈

```text
教师准备 Draft / 事实摘要
↓
电话/面谈真实发生
↓
同一 interaction 内双方沟通
↓
Finalize Communication C (conversation)
  - institution message
  - home support agreed
  - guardian response
↓
必要 follow-up
```

这里不需要为了“事件模型纯粹”强拆成 outbound + inbound 两条。

---

## 16. 纠错

Finalized communication 不普通 UPDATE。

严重错误：
- 保留原 record；
- 记录 correction reason / actor / time；
- 创建更正版本/更正 communication；
- 如果错误内容已经发给家长，真实的后续更正沟通也必须成为新 communication event。

不能把过去修改成“从来没说过”。

---

## 17. V1 / V1.1 边界

### V1 Internal Pilot
Student Detail / Case context 内提供：
- Draft；
- 复制到现实渠道；
- finalize actual event；
- recipients；
- home support；
- inbound reply / conversation；
- follow-up。

不增加第五主导航。

### V1.1
再考虑：
- 独立家校工作台；
- Thread UI；
- 周度/阶段批量协调；
- 更强搜索/过滤。

仍不要求：家长账号、家长 App、微信 API、短信网关、已读回执。

---

## 18. Acceptance Scenarios

1. AI 生成 Draft 但老师没发送，不计沟通。
2. 老师 09:00 微信发送并 finalize；家长 20:00 回复，新增 inbound，不修改 09:00 snapshot。
3. 电话中双方同场交流，可以一条 conversation finalized。
4. Finalized 后 Case reopen，旧沟通不变化。
5. 一个 event 可以对应父母双方 recipients。
6. Advisor 综合多个学科摘要，但不能改原 subject professional source。
7. Guardian reply 不自动建 Case；教师确认后形成 guardian_report Evidence 时可追溯 source communication。
8. 家庭任务不能 assigned 给 guardian membership。
9. Case-related follow-up 复用 communicate Action；non-case follow-up 不引入通用 Todo。
10. Finalized 严重错误通过 correction/新沟通保留历史，不静默覆盖。

---

## 19. 当前冻结结论

- Parent Communication 是**沟通事件**，不是不断变化的聊天线程。
- Draft 与实际沟通严格分开。
- 每个 finalized event 独立冻结。
- 后续异步家长回复新增 inbound/reply event；同场电话/面谈可用 conversation snapshot。
- Thread 是事件聚合关系，不是 mutable finalized record。
- 家庭配合不是 Case Action；家长回应不是自动专业结论。
- V1 保留最小 context 能力，V1.1 再做独立工作台。
