# Xueqing Domain Glossary｜业务语言与领域语义

> 状态：Phase 0A.6 领域词汇事实源。目标：让领导、教师、产品、Flutter、数据库、RLS 和审计使用同一套语义。

## 1. 三层语言

1. **机构教学语言**：三阶订正、清零、跨周、顽固问题；
2. **领域语言**：Student、Subject Profile、Learning Case、Evidence、Assessment、Action；
3. **技术语言**：UUID、RLS、timestamptz、version。

原则：教学语言可以友好，领域语义必须唯一，技术实现不能偷偷改变业务含义。

---

## 2. Student / Enrollment / Student Subject Profile

### Student
机构内一个真实学生的稳定身份。

不是：一次报名、一门学科、一个老师名下的副本、一学期一份新档案。

升年级、换老师、停读后回归，Student identity 仍连续。

### Student service lifecycle

```text
active → inactive → archived
active ← inactive ← archived
```

实际命令语义：

```text
active --deactivate--> inactive --archive--> archived
active <--reactivate-- inactive <--unarchive-- archived
```

- `active`：机构当前提供实际服务；
- `inactive`：整体服务暂停，但仍在可管理/准备恢复状态；
- `archived`：退出普通当前业务视图，历史保留，**可受控 unarchive 到 inactive**；
- `merged`：重复档案合并后的终态，不可 unarchive/reactivate 为独立 Student。

**Archive 不是删除，也不是终态；Merged 才是不可恢复的身份终态。**

禁止：
- `active → archived` 直跳；
- `archived → active` 直跳；
- `merged → active/inactive/archived`。

### Enrollment
学生在某学期/校区/年级/班级的时间化关系。变化时新增/结束历史，不覆盖过去。

### Student Subject Profile｜学科学情主线
同一 Student 在某一学科上的连续教学上下文。换老师不新建。

其服务生命周期同样是：

```text
active --deactivate--> inactive --archive--> archived
active <--reactivate-- inactive <--unarchive-- archived
```

- `active`：当前持续该学科教学；
- `inactive`：当前暂停/停止该学科教学，历史保留；
- `archived`：退出普通当前业务视图，历史保留，可受控恢复到 inactive；
- `unarchive` 只恢复可管理状态，不代表重新教学；
- `reactivate` 才表示真正恢复持续教学，并要求 assignment / owner / primary Action reconciliation 已完成。

### 最重要的区分

> **Subject Profile status ≠ Learning Case status。**

例如学生停止数学但继续语文：

```text
Student = active
数学 Profile = inactive
语文 Profile = active
```

数学某个 Case 可以仍是 `intervening` 或 `pending_verification`，只是当前 tracking 被服务暂停；**不能因为数学停课而改成 closed/已清零。**

---

## 3. Current Positioning / Strengths

### Current Positioning
学生某学科当前教学位置的摘要，例如“中等待提升”。

不是能力分、人格标签或永久属性。

### Strengths
与教学相关、尽量可观察的优势摘要。

不是潜力值/天赋分。

---

## 4. Initial Diagnosis｜初诊

新接手 Student/新学科时，对当前学情进行结构化理解的工作流。

它可以形成：Subject Profile context、strengths、candidate issues、confirmed Cases、first Actions。

Initial Diagnosis 不是第二套永久 Case 台账。

任何初诊中的实际教学事实仍必须满足完整 Teaching Fact Gate；管理员不能用“授权初诊”跳过 active Profile / teacher relationship。

是否另存第一次整体 baseline snapshot 待 Pilot 验证。

---

## 5. 三类问题

### Knowledge｜知识漏洞
知识、概念、方法、题型等可独立跟进问题。默认适合“三阶订正”教学 workflow。

### Habit｜学习习惯
可观察、可干预、可重复观察的学习行为问题。禁止把“懒、不自律、态度差”等人格判断当事实。

### Exam Strategy｜考试技巧
审题、时间、答题规范、策略迁移、考场应用等问题。验证重点是接近真实条件下能否独立迁移。

### Other
真实存在但不适合前三类的问题；不能让“其他”吞掉 taxonomy。

---

## 6. Learning Case｜学情 Case

一个需要被持续跟进、可以独立解释进展与下一步的学习问题。

正式 Case 最终应回答：

```text
问题是什么？
凭什么这样判断？
当前原因判断是什么？
做过什么？
结果如何？
下一步是什么？
是否稳定？
是否复发？
```

Learning Case 是闭环最小业务单元。

### Case code
内部主键使用 UUID。若未来增加 `C-012` 之类人类可读编号，由系统生成，不能让老师手工维护唯一性。

---

## 7. Case Resolution Lifecycle｜问题解决生命周期

严格只有：

```text
new → confirmed → intervening → pending_verification → stable → closed
```

`reopen` 是 command/event，不是第七状态。

### new｜待整理
快速捕捉，可缺完整 taxonomy/owner/action，不是正式结论。

### confirmed｜已确认跟进
确认值得正式持续跟进。

**当 Subject Profile=active 时**必须具备合法 owner、Evidence、pending primary Action 等正式结构。

### intervening｜整改中
正在实施干预。

### pending_verification｜待验证
已发生干预/检查事实，等待后续验证或教师判断。

`Assessment result` 与 Case status 分开。

### stable｜已改善 / 稳定观察
已有足够改善证据，但仍需观察。

在 active Profile 下仍必须有 review/verify primary Action。

### closed｜已清零
**closed 是问题解决结论，不是行政退出结论。**

只有授权教师根据真实 Evidence/Assessment 判断：

> 这个问题已经不再需要主动解决跟进，因为问题本身已达到可退出状态。

才可以 closed。

因此：

```text
一次做对 ≠ closed
一次满分 ≠ closed
Assessment passed ≠ closed
学生停读 ≠ closed
某学科停课 ≠ closed
Subject Profile archived ≠ closed
Student archived ≠ closed
老师离职 ≠ closed
```

closed：
- 无 pending primary Action；
- 历史保留；
- 问题后续真实复发走 `reopen_case`。

产品教学语言推荐“已清零”。

---

## 8. Tracking Suspended｜当前跟进暂停

这不是 Case status。

当 Subject Profile 从 active→inactive，或进一步 inactive→archived：
- unresolved Case 保留原 resolution status；
- pending current Action 受控收口；
- 写 tracking suspended/archived event/reason；
- Case 暂时退出普通教师 Today；
- 不允许新的普通教学事实或 Lesson；
- **允许 formal open Case 暂时没有 pending primary Action。**

恢复流程：

```text
Profile archived
→ unarchive 到 inactive
→ 重建合法 assignment / owner / pending primary Action
→ reactivate 到 active
→ tracking resumed
```

如果 Profile 只是 inactive，则从 reconciliation + reactivate 开始，不需要 reopen Case，因为 Case 从未 closed。

这防止“停读/归档 = 清零”的语义污染。

---

## 9. Archive / Unarchive / Reactivate

### Archive｜归档
把已 inactive 的 Student / Subject Profile 移出普通当前业务视图，同时保留完整历史。

不是删除，也不代表问题解决。

### Unarchive｜取消归档
只允许：

```text
archived → inactive
```

含义：历史对象重新进入可管理范围。

**Unarchive 不自动恢复 enrollment、teacher assignment、Case owner、Action 或 Lesson 权限。**

### Reactivate｜恢复服务
只允许：

```text
inactive → active
```

真正恢复持续教学前必须完成所需 reconciliation。

### Merged
Student merged 是终态；source Student 不能 unarchive/reactivate 为独立实体。

---

## 10. Reopen｜重新打开 / 复发

`reopen_case` 是 domain command + Case Event。

适用于已经 closed 后真实复发/重新达到跟进条件。

`reopened` 绝不是 status。

如果 Case 只是因为 Profile inactive/archived 暂停 tracking，Profile 恢复时叫 **resume tracking**，不是 reopen。

---

## 11. 三阶订正

知识类默认教学 workflow：

```text
当堂订正
→ 相似题巩固
→ 延迟/次课独立验证
→ 教师判断 stable / 继续 / closed
```

“三阶”不是数据库固定三列，也不是三次操作必然结束。

三阶小测“满分通关”是 Assessment 结果语义之一，不等于 closed。

---

## 12. Teaching Fact Gate

实际教学 actor 要产生 Intervention、Assessment、教学型 Evidence、Lesson teacher 行为，必须同时满足：

```text
live session
+ active membership
+ teacher capability
+ matching active teaching subject scope
+ target Student Subject Profile = active
+ legal active Student Assignment / controlled Lesson relationship
+ operation-specific permission
```

管理身份不能绕过该 Gate。

---

## 13. Evidence｜证据

支持 Case 判断的来源事实，例如试卷、作业、作文、课堂练习、小测、观察，以及经教师判断后进入教学证据链的 guardian report。

Evidence 不是附件数量 KPI。Guardian report 必须可追溯到来源 Parent Communication event。

---

## 14. Intervention｜干预

教师真实实施过的教学处理。

管理者建议“应该怎么教”不是 Intervention；只有真实发生且通过 Teaching Fact Gate 后才记录。

---

## 15. Assessment｜验证 / 检测

对 Case 后续表现的验证事实：passed / partial / failed / not_scored 等。

核心：

```text
Assessment passed ≠ stable ≠ closed
```

Assessment 描述一次验证结果；Case status 是教师基于证据做出的领域判断。

---

## 16. Case Action｜下一步行动

机构成员当前应该执行的具体下一步。

active Profile 下 formal open Case 必须有一个 pending primary Action。

### Undated
不知道具体日期的普通 Action 可以暂时 undated，并进入 Today 的“待安排”。

### Review
教学暂缓/稳定观察仍需 review；在 active Profile 下 review 应有 due_at。

### Profile inactive / archived
服务暂停后 unresolved Case 可以暂时没有 current pending Action；这不违反“active teaching service 下正式 Case 有下一步”。恢复 active 前必须重新建立下一步。

---

## 17. Owner / Assignee

### Case Owner
当前主要推进 Case 的机构教师责任人。

必须有合法 teacher capability + teaching scope + active Profile + Student relationship。

Owner 是责任关系，不是 role。

### Action Assignee
实际负责执行某 Action 的 active membership。

Guardian 不是 membership，家庭配合不能伪装成 Case Action assignee。

---

## 18. Lead / Collaborator / Advisor / Subject Lead

### Lead
Student + Subject 的主要负责教师，不等于 Subject Lead。

### Collaborator
Student + Subject 协作教师。可在完整 Teaching Fact Gate 成立时记录本人真实教学事实；关键 Case command 仍受 owner/policy。

### Advisor
跨学科必要摘要、协调、家校；不改专业学科结论。

### Subject Lead
有 matching leadership scope 的学科管理角色。Leadership scope 不等于 Teaching scope，也不允许伪造教学事实。

---

## 19. Parent Communication｜家校沟通事件

Parent Communication 是一次实际沟通 event，不是不断覆盖的一条聊天记录。

### Draft
准备沟通的可编辑内容，不算已联系。

### Finalized Event
一次实际发生的沟通历史快照。

### Direction
- outbound：机构主动表达；
- inbound：家长主动提供/回复；
- conversation：电话/面谈同一 interaction 内双方交流。

### Reply
老师上午 outbound finalized，家长晚上回复：新增 inbound event + reply_to 原 event。不能回头修改上午 finalized 的 guardian response。

### Thread
多条 communication events 的聚合展示关系，不是 mutable finalized document。

---

## 20. Home Support｜家庭配合

家长在家庭侧配合的具体建议/约定。

属于 communication snapshot，不属于 Case Action assignee。

机构员工后续联系：
- Case-related → communicate Action；
- non-case → lightweight communication follow-up。

---

## 21. Stage Review / Report

某一 period 的事实摘要 + 人类专业判断 + finalized responsibility snapshot。

系统自动整理已有事实，教师主要确认整体进步、遗留问题、下一阶段计划。

Finalized Report 不随底层 Case 改变，也不等于已经告知家长。

---

## 22. Weekly Tracking / 顽固 / Governance

### Weekly Tracking
工作节奏/派生视图，不是第二套周表。

### 顽固问题
失败、持续、reopen 等事实派生，不是 Case status/第二张表。

### Governance anomaly
orphan、long overdue、stale draft、inactive/archived Profile 残留 Action、archived→active 非法尝试等需要处理的事实，不是风险分/效能分。

---

## 23. 当前最重要的等式

```text
Auth User ≠ Membership
Role ≠ Subject Scope
Subject Scope ≠ Student Assignment
Lead ≠ Subject Lead
Advisor ≠ Subject Teacher
Subject Profile status ≠ Case status
Profile inactive/archived ≠ Case closed
Assessment passed ≠ stable ≠ closed
reopen = command/event, not status
archive ≠ delete
unarchive ≠ reactivate
archived → active = forbidden direct transition
merged Student = terminal identity state
Parent Communication thread ≠ one mutable finalized row
Finalized Report ≠ Parent informed
Guardian Home Support ≠ staff Case Action
```

这些等式是 Phase 0B Data Model / RLS / Commands / UI 的验收基线。
