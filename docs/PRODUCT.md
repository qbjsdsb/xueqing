# 产品蓝图

## 1. 定位

**学情闭环（Xueqing）｜机构教学协作与学生成长闭环系统**

不是 Excel 网页化，也不是收费排课/招生 ERP。核心是让真实教学事实形成连续、多人协作、可验证、能指导下一次教学的学生成长记录。

### 北极星

> **老师打开软件后，能否快速知道这个学生下一步做什么，并能用证据判断前一次教学是否有效？**

不能改善这个闭环、只增加填写负担的功能，默认后置、自动化或删除。

### 对领导方法的产品翻译

领导/源方案的高置信教学骨架是：

`学生档案 → 三类问题初诊 → 知识三阶闭环 → 周度跟进 → 顽固问题 → 家校沟通 → 阶段复盘`

Xueqing 不把七段做成七张电子表，而是：

> **保留“发现—整改—验证—再整改—协同—复盘”的教学责任闭环，把 Excel 才需要的重复录入、跨表关联、人工统计和追踪交给系统。**

Excel 化原型中部分“编号/责任人/状态/跟进日期”等属于后加管理建议；Xueqing 可以在证明协作价值后采用，但不能冒充成领导原始字段要求。

---

## 2. 主要用户

### 任课教师
今天做什么、上次遗留什么、课中怎么快速记、课后怎么在约 60 秒留下可靠记录；多学科教师不需要反复切换一个全局“当前学科”。

### 学生负责人 / 学管 / 班主任
跨学科必要摘要、协调事项、家校沟通；综合视角不能改写任课教师专业结论。

### 学科负责人
本科复杂/长期问题专业审阅、教研沉淀、学科治理；管理身份不等于实际授课身份。

### 教学/机构管理员
成员权限、学科范围、学生主档案、交接、异常、数据完整性与恢复。

不把“老师填多少条”“家校联系多少次”做核心 KPI。

---

## 3. 核心领域对象

### Student
同一机构一个真实学生一份主档案。姓名不是唯一标识；升年级、换老师、停读后回归不创建第二个 Student。

### Student Subject Profile
学生某学科的连续教学主线。它同时表达：
- 当前是否在持续该学科教学：active / inactive / archived；
- 当前教学定位；
- 已观察优势；
- 学科连续历史。

**Subject Profile service lifecycle 与 Learning Case resolution lifecycle 分开。** 学生暂停数学不代表数学问题已经清零。

### Membership / Subject Scope / Assignment
三层必须分开：
- Membership：这个人在机构里是谁、是否 active；
- Subject Scope：在哪些学科承担 `teaching / leadership` 范围；
- Student Assignment：当前实际负责哪个 Student + Subject，`lead / collaborator`。

Subject Scope 不是学生数据通行证。

### Learning Case
可独立跟进的学习问题，是闭环最小业务单元。

正式 Case 至少能回答：问题、证据、当前原因判断、干预、验证、下一步、是否复发。

### Evidence
试卷、作文、课堂练习、小测、作业、可观察事实，以及经教师判断后可作为教学证据的 guardian report。

### Intervention
真正实施过的教学处理。只有具备 teacher + teaching scope + 合法 Student/Lesson relationship 的成员才能作为实际教学 actor。

### Assessment
后续验证结果；与 Case status 分开。

### Case Action
下一步行动，是 Today 的核心教学行动事实源。

### Lesson
真实教学会话，用来关联本节发生的事实，不是完整排课系统。

### Parent Communication
一次实际家校沟通**事件**。Draft 与 finalized 分开；后续异步回复新增 inbound/reply event，不回头改旧 finalized event。

### Report / Stage Review
阶段事实摘要 + 教师专业判断 + finalized responsibility snapshot。

---

## 4. Case 生命周期

```text
new → confirmed → intervening → pending_verification → stable → closed
```

- new：10–20 秒快速捕捉；
- confirmed：确认值得正式跟进；
- intervening：正在干预；
- pending_verification：等待后续验证；
- stable：已有改善证据，仍观察；
- closed：问题真实退出主动解决跟进，产品语境可表达“已清零”。

`reopen` 是 command/event，不是第七状态。

```text
Assessment passed ≠ stable ≠ closed
```

### 停读不是 closed

如果 Student Subject Profile 变 inactive：
- 未解决 Case 保留真实 status；
- 当前 pending Actions 受控收口；
- Case 暂时退出普通教师 Today；
- **不能为了清任务把 Case 假改 closed/已清零**。

该学科恢复 active 前，未解决 formal Cases 必须重新获得合法 owner + pending primary Action，或根据真实新证据执行合法 closure。

---

## 5. 三类问题的默认教学 Workflow

底层生命周期统一，前台教学方式不同：

- **知识漏洞**：当堂订正 → 相似题巩固 → 延迟/次课独立验证 → stable/review/清零；
- **学习习惯**：明确可观察行为 → 策略干预 → 多个自然场景连续观察 → 稳定/调整；
- **考试技巧**：方法训练 → 针对性应用 → 限时/模拟迁移 → 独立验证。

领导“三阶订正”必须作为 knowledge Case 的教学语言保留，但不能硬做数据库三列，也不能机械套习惯/考试技巧。

---

## 6. 正式 Case 与下一步

### Active Subject Profile
- new 可以没有 Action；
- confirmed/intervening/pending_verification/stable 必须始终有一个 pending primary Action；
- 教学上的暂缓/稳定观察仍用 `review + due_at`；
- closed 不存在 pending primary Action。

### Inactive / Archived Subject Profile
未解决 Case 可保留真实 status，但当前服务已经暂停：
- 不要求 pending primary Action；
- 不进入普通 Today；
- 要有可解释的 tracking suspended event/reason；
- reactivation 前重新建立下一步。

这样 Case status 只表达问题解决进度，不承担“当前是否还在上这门课”的行政语义。

---

## 7. Initial Diagnosis｜初诊是入口，不是第二套台账

```text
确认/建立 Student
→ Student Subject Profile
→ 当前学情定位（可简）
→ 已观察优势（可选）
→ 候选问题
→ knowledge / habit / exam_strategy
→ 去重与证据判断
→ 确认真正需要长期跟进的 Cases
→ 第一批 primary Actions
```

不把每个一次性错误都变成 formal Case。

是否需要独立保存“第一次整体初诊基线 snapshot”待 Pilot 验证；V1 不先建 `initial_diagnoses` 大表。

---

## 8. 分类：结构化但不困住老师

V1：
- 受控 taxonomy：学科 → 模块/能力；
- 自由 title/description：表达真实问题。

new 可暂不选完整 taxonomy；confirmed 前补齐。只做少量默认分类 + “其他/暂未分类”。

---

## 9. Excel 原型怎么转成软件

- 学生档案 → Student / Enrollment / Subject Profile / Assignment；
- 学情定位/优势 → Subject Profile 当前上下文；
- 某学科是否当前持续教学 → Subject Profile lifecycle；
- 初诊问题 → Initial Diagnosis workflow → Learning Case；
- 知识闭环 → knowledge workflow + Evidence / Intervention / Assessment / Action / Event；
- 周度跟进 → 从真实教学事实派生；
- 顽固问题 → 同一 Case 的持续/失败/复发提示；
- 家校沟通 → immutable communication events + replies/recipients/follow-up；
- 阶段复盘 → Report / Stage Review snapshot。

事实只保存一次。

---

## 10. 导航与版本边界

### V1 教师主导航
1. 今日
2. 学生
3. 课程
4. 学情

### V1 Internal Pilot 最小家校
家校是领导方法的一环，但先作为 Student Detail / Case context 能力：
- 从已有事实生成/编辑 outbound Draft；
- 复制到微信/电话/面谈等现实渠道；
- 记录实际沟通 event 与 recipients；
- 家庭配合；
- 家长异步回复新增 inbound/reply event；
- 电话/面谈同一 interaction 可一条 conversation snapshot；
- follow-up。

不增加第五个教师主导航。

### V1.1
再评估：
- 独立家校工作台；
- Thread UI；
- 更完整阶段报告工作台；
- 跨学科综合反馈协调视图。

仍不把家长 App、微信 API、短信网关作为前置。

### Today
Today 主要来自 active service context：
- 今日/逾期 Case Actions；
- 无日期待安排 Actions；
- pending verification；
- 必要高优先级 Case；
- 最近负责学生。

**Inactive Subject Profile 下的 suspended unresolved Cases 不进入普通教师 Today。**

多学科教师默认聚合本人所有合法 assigned 工作，可按学科过滤。

---

## 11. Lesson 是日常事实引擎

### 课前约 30 秒
上次遗留、到期行动、待验证、当前重点、最近事实。

### 课中
只记录新事实：Action progress、Evidence、Intervention、Assessment、new Quick Capture。

事实逐步可靠保存，不等到下课才第一次发送全部内容。

### 课后 30–60 秒
系统整理，教师确认：处理 Cases、必要 new→confirmed、旧 Action 收口、新 primary Action、必要状态变化、Lesson complete。

`start_lesson / complete_lesson` 属于高价值 domain commands；小班最终事务粒度留 Phase 0B.0 故障/并发 Spike。

不再抄周报。

---

## 12. 网络失败、本地草稿与并发

V1 online-first，云数据库是唯一正式事实源。

必须：
- 未保存/保存中/已保存/失败/本地草稿/version conflict 清晰；
- 网络失败不清空输入；
- 可恢复草稿加密保存；
- draft 按 user/org/operation/entity 隔离，有 TTL；
- 重试不重复事实；
- 云端未确认前不显示正式“已保存”；
- version/expected_version；
- 多人冲突不 silent last-write-wins；
- 冲突时保留老师原输入。

不是 offline-first。

---

## 13. 跨学科协作与权限

默认隔离、必要互通：
- Lead/Collaborator：按 assignment 查看本科详细数据；
- 有 teaching scope 但未 assignment 的 Teacher：不能读具体学生详细数据；
- Advisor：跨学科必要摘要，不改专业结论；
- Subject Lead：matching leadership scope 内专业管理，不因管理身份伪造教学事实；
- Academic/Org Admin：必要治理视角，不自动成为授课教师/Case owner。

“Read / Append / Edit / Confirm / Govern”分开。

任何实际教学事实 actor 必须通过 Teaching Fact Gate。

---

## 14. 家校协同：事件而不是聊天文档

标准链路：

```text
教学事实
→ outbound Draft
→ 实际沟通
→ Finalize Event A
→ 家长后来回复？
   ↓
新增 inbound Event B (reply_to=A)
→ 教师判断是否形成 Evidence/Case/Action
```

电话/面谈同一 interaction 可：

```text
conversation Event
= institution message + home support + guardian response
```

规则：
- Draft ≠ 已联系；
- finalized event 不随后续 Case 或后续异步回复变化；
- Thread 只是多条 events 的聚合；
- 家庭配合不是 Guardian-as-Case-Action；
- guardian response 不自动成为诊断；
- Case-related 员工沟通 follow-up 优先复用 communicate Action；
- non-case follow-up 使用轻量 communication follow-up，不建通用 Todo。

---

## 15. 阶段复盘

```text
系统按 source_cutoff_at 整理事实
→ 教师/Advisor 补真正需要人工判断的内容
→ Draft
→ 授权成员确认
→ Finalized snapshot
```

人工主要负责：整体进步、遗留问题、下一阶段计划。

领导 Excel 的“签字”转为 `finalized_by + finalized_at`，不要求手写签名图片。

Finalized Stage Review ≠ 已告知家长。

V1 第一轮短周期内部 Pilot 不强迫每个学生都做阶段复盘；领域/数据结构必须已支持，V1.1 再提供独立报告工作台。

---

## 16. 机构治理

管理端优先显示可处理事实：
- orphan Case/Action；
- long overdue；
- long pending verification；
- repeated failed/reopen；
- stale Quick Capture；
- teacher disable / scope revoke 前 handoff remaining；
- duplicate Student candidate；
- communication follow-up due；
- Stage Review due；
- attachment inconsistency；
- **inactive Subject Profile 下仍残留 pending Action**；
- **active Subject Profile 下 formal open Case 无 primary Action**。

不做教师效能分/学生风险分。

---

## 17. Student / Subject Service Lifecycle

### 整体 Student
- 升年级/换校区 → Enrollment 历史；
- 整体停读 → 逐 active Subject Profile reconciliation 后 Student inactive；
- restart → 同一 Student ID。

### 单学科
学生可继续语文但停止数学：

```text
Student active
语文 Profile active
数学 Profile inactive
```

数学 unresolved Cases 保留真实状态、暂停 current tracking，不伪造 closed。

恢复数学前重新建立合法 teacher assignment + unresolved Case next Actions。

---

## 18. Cloud / Provider 原则

云端是正式目标，但不因免费服务便利锁厂商。

原则：
- PostgreSQL-first；
- migration-as-source-of-truth；
- UI/ViewModel 不散落 provider SDK；
- Domain Repository Interface 隔离 adapter；
- Storage 保存 object key/path，不保存永久 public URL；
- Realtime 不作为 correctness 前置。

### Phase 0B.0 硬 Gate
任何正式 business migration 前，用虚构数据验证：
1. Auth identity strategy；
2. revoked-session old-token 立即失权；
3. Windows/Android login/session/refresh；
4. RLS 跨机构/assignment/subject scope；
5. RPC/transaction/version conflict；
6. private Storage；
7. export/restore；
8. 国内实际网络。

Production provider 在证据出现前不冻结。

---

## 19. V1 / Pilot 必须有

- 安全登录/机构 membership/首位管理员；
- role + teaching/leadership subject scopes；
- Student 主档案与查重；
- Enrollment / teacher/staff assignment 历史；
- Student Subject Profile lifecycle + 当前定位/优势；
- Initial Diagnosis workflow；
- Learning Case + taxonomy；
- 三类 Case workflows；
- Evidence / Intervention / Assessment；
- Case Action；
- Lesson；
- Today；
- Student context 内最小家校 event 闭环；
- RLS/审计/并发；
- network recovery；
- secure Session / encrypted draft；
- DB + Storage recovery；
- 必要 governance/handoff/merge/service-lifecycle reconciliation。

### 可以简单
- 附件少量私有文件；
- 管理端只做必要治理；
- 搜索覆盖高频字段；
- 家校先生成/复制/记录；
- Windows/Android 内部 Pilot 分发。

### 明确不做
- 收费/课消/招生 CRM；
- 完整排课；
- 大型题库；
- 学情健康分/成绩预测/教师效能分；
- 家长/学生 App（V1）；
- 微信/短信 API 作为 V1 前置；
- AI 自动正式诊断；
- CRDT/offline-first；
- 多套登录方式；
- 大量第三方 SaaS；
- Realtime correctness dependency。

---

## 20. V1 成功指标

1. 低负担：new 10–20 秒，常规课后中位 ≤60 秒；
2. 连续性：换老师/升年级/停学科后仍能解释历史；
3. 行动完整性：active Profile 的 formal open Case 都有主行动；
4. 证据性：关键结论可追溯；
5. 协作：Lead/Collaborator/Advisor 权限正确；
6. 方法连续：初诊、三类问题、三阶、跨周、家校、阶段复盘都保留明确实现路径；
7. 安全：revoked/onboarding/disabled/cross-org/unassigned 无法越权；
8. 可靠：网络失败不丢、重试不重复、并发不静默覆盖；
9. 恢复：DB/Storage 真实可恢复；
10. 可运营：教师愿意连续真实使用。

不把记录条数/沟通次数当成功指标。

---

## 21. 产品铁律

1. 一个学生一份机构主档案。
2. 同一真实事实只记录一次。
3. Case 解决生命周期与 Student/Subject 服务生命周期分开。
4. 重要结论尽量有证据。
5. active Profile 的正式未关闭 Case 永远有下一步。
6. 停读/停科不能伪造“已清零”。
7. 学生历史不因换老师/升年级/停读后回归断裂。
8. Role、Subject Scope、Student Assignment 分开。
9. Read / Append / Edit / Confirm / Govern 分开。
10. 管理身份不能伪造实际教学事实。
11. 老师少填一次，系统多自动一次。
12. 网络失败不能让高频记录消失。
13. 本地恢复不能以敏感明文长期留存为代价。
14. Today 不偷偷变排课 CRM。
15. Parent Communication 是不可变历史事件，不是不断覆盖的聊天文档。
16. 家校不是 CRM，也不是教师 KPI。
17. Governance 是可处理事实，不是风险/效能分。
18. AI 只做副驾驶，不能自动正式诊断/清零/finalize。
19. 云厂商便利不能凌驾于权限安全、恢复和迁移成本。
20. 功能数量永远排在数据正确、权限安全、教师可用之后。
