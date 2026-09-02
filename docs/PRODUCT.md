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

Xueqing 不把这七段做成七张电子表，而是：

> **保留“发现—整改—验证—再整改—协同—复盘”的教学责任闭环，把 Excel 才需要的重复录入、跨表关联、人工统计和追踪交给系统。**

问题编号、责任人、状态、跟进日期等部分字段在 Excel 化原型中本身属于后加管理建议；Xueqing 可以在证明协作价值后采用，但不能把所有 Excel 列都冒充成“领导原始要求”。

---

## 2. 主要用户

### 任课教师
今天做什么、学生上次遗留什么、课中怎么快速记、课后怎么在约 60 秒留下可靠记录；多学科教师不需要反复切换一个“全局当前学科”。

### 学生负责人 / 学管 / 班主任
跨学科必要摘要、需要协调的事项、家校沟通；综合视角不能用来改写任课教师专业结论。

### 学科负责人
本科长期问题、高频共性问题、复杂 Case 专业审阅和教研沉淀；学科管理身份不等于实际授课教师身份。

### 教学/机构管理员
成员权限、学科范围、学生主档案、交接、异常、数据完整性与恢复。

管理端不把“老师填多少条”“家校联系多少次”做核心 KPI，避免系统退化为应付式填表。

---

## 3. 核心领域对象

### Student
同一机构一个真实学生一份主档案。姓名不是唯一标识；重复通过提示 + 受控合并治理。升年级、换老师、停读后回归不创建第二个 Student。

### Student Subject Profile
学生某学科的连续学情主线。换老师不新建。允许表达当前教学定位与已观察优势，但不把学生压缩成“能力分”。

### Membership / Subject Scope / Assignment
三层必须分开：

- Membership：这个人在机构里是谁、当前是否 active；
- Subject Scope：被授权在哪些学科承担 `teaching / leadership` 范围；
- Student Assignment：当前实际负责哪个 Student + Subject，`lead / collaborator`。

**Subject Scope 不是学生数据通行证。** 普通教师即使有语文 teaching scope，也不能自动读取全机构所有语文学生。

### Learning Case
可独立跟进的学习问题，是闭环最小业务单元。

正式 Case 至少能回答：
- 问题是什么；
- 证据来自哪里；
- 当前原因判断；
- 做过什么干预；
- 如何验证、结果如何；
- 下一步是什么；
- 是否复发。

### Evidence
试卷、作文、课堂练习、小测、作业、可观察事实，以及经教师判断后可作为教学证据的 guardian report。证据不是“附件越多越好”。

### Intervention
真正实施过的教学处理。只有具备真实 teacher + teaching scope + student/lesson relationship 的成员才能作为实际教学 actor。

### Assessment
后续验证结果；必须和 Case status 分开。

### Case Action
下一步行动，是 Today 的核心事实源。

### Lesson
真实教学会话，用来关联本节课发生的事实，不是完整排课系统。

### Parent Communication
实际家校协同事实。Draft 与真实已沟通/finalized 必须分开；家庭配合与家长回应保留在沟通快照中，不把 Guardian 假装成 staff assignee。

### Report / Stage Review
阶段事实摘要 + 教师专业判断 + finalized responsibility snapshot。系统可以整理事实，但最终专业判断由授权成员确认。

---

## 4. Case 生命周期

```text
new → confirmed → intervening → pending_verification → stable → closed
```

- `new`：课堂 10–20 秒快速捕捉，可缺完整分类/owner/action；
- `confirmed`：确认值得正式跟进，结构完整；
- `intervening`：正在干预；
- `pending_verification`：等待后续验证；
- `stable`：已有改善证据，仍观察；
- `closed`：退出主动跟进，产品语境可以表达“已清零”。

`reopen` 是受控命令/事件，不是第七状态。

一次 Assessment passed 不自动 stable/closed。

### 三类问题的默认教学 Workflow

底层生命周期统一，但前台教学方式不同：

- **知识漏洞**：当堂订正 → 相似题巩固 → 延迟/次课独立验证 → stable/review/清零；
- **学习习惯**：明确可观察行为 → 策略干预 → 多个自然场景连续观察 → 稳定/调整；
- **考试技巧**：方法训练 → 针对性应用 → 限时/模拟迁移 → 独立验证。

领导的“三阶订正”必须作为知识类 Case 的教学语言保留，但不能硬做成数据库三列，也不能机械套给习惯/考试技巧。

---

## 5. 正式 Case 永远有下一步

最终规则：
- new 可以没有 Action；
- confirmed / intervening / pending_verification / stable 必须始终有一个 pending primary Action；
- 暂时不处理不是“没有下一步”，而是建立 `review` primary Action；
- 暂缓 `review` 必须有 `due_at`；
- `pause_reason` 只解释为什么暂缓，不替代 Action；
- closed 不存在 pending primary Action。

这样避免“暂停后没人再看”，也让 Today 只需要一个教学行动事实源。

### 无日期主行动
部分下一步可能还不知道具体日期，可暂时无 due_at，但必须在 Today 的“待安排”区域出现。暂停/稳定观察的 review Action 不允许无日期。

---

## 6. Initial Diagnosis｜初诊是入口，不是第二套台账

新 Student/新学科不应该进入一张完全空白详情页。

推荐流程：

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

不要求一次试听填写完整 ERP 档案，也不把每个一次性错误都变成正式 Case。

是否需要独立保存“第一次整体初诊基线快照”仍待 Pilot 验证；V1 不先建 `initial_diagnoses` 大表。

---

## 7. 分类：结构化但不困住老师

V1：
- 受控 taxonomy：学科 → 模块/能力，用于检索和合理统计；
- 自由 title/description：表达真实问题。

new 可暂不选完整 taxonomy；confirmed 前补齐。只做少量默认分类 + “其他/暂未分类”，不建庞大知识图谱。

---

## 8. Excel 原型怎么转成软件

Excel 的工作表不是软件页面：

- 学生档案 → Student / Enrollment / Subject Profile / Assignment；
- 学情定位/优势 → Subject Profile 当前上下文；
- 初诊问题 → Initial Diagnosis workflow → Learning Case；
- 知识闭环 → knowledge Case workflow + Evidence / Intervention / Assessment / Action / Event；
- 周度跟进 → 从真实教学事实自动派生；
- 顽固问题 → 同一 Case 的持续/失败/复发提示；
- 家校沟通 → Parent Communication draft/finalized snapshot；
- 阶段复盘 → Report / Stage Review snapshot。

事实只保存一次，展示/周度/阶段总结尽量派生。

---

## 9. 导航与版本边界

### V1 教师主导航
仍只有：
1. 今日
2. 学生
3. 课程
4. 学情

### V1 Internal Pilot 的最小家校
家校是领导方法闭环的一环，因此 Pilot 不能完全丢失。但它先作为 **Student Detail / Case context 内的上下文能力**：

- 根据已有事实生成/编辑反馈 Draft；
- 复制到微信/电话/面谈等现实渠道；
- 记录实际沟通内容、recipient、家庭配合、家长回应、follow-up；
- finalized snapshot。

**不因此增加第五个教师主导航。**

### V1.1
再增加/评估：
- 独立家校工作台；
- 更完整阶段报告工作台；
- 跨学科综合反馈协调视图。

仍不把家长 App、微信 API、短信网关作为前置。

### Today
Today 不要求完整课表，主要来自：
- 今日/逾期 Case Actions；
- 无日期待安排 Actions；
- Case-level pending verification；
- 必要的高优先级 Case；
- 最近负责学生。

多学科教师默认聚合自己所有合法 assigned 工作，可按学科过滤，不要求进入 App 先选一个全局学科。

---

## 10. Lesson 是日常事实引擎

### 课前：约 30 秒
看到：上次遗留、到期行动、待验证、当前重点、最近关键事实。

### 课中
只记录新事实：
- 完成/调整 Action；
- Evidence；
- Intervention；
- Assessment；
- new Quick Capture。

教学事实应逐步可靠保存，不等到下课才第一次发送全部内容。

### 课后：目标 30–60 秒
系统整理本课事实，教师确认：
- 处理了哪些 Cases；
- 必要的 new → confirmed；
- 旧 Action 完成/取消；
- 新 primary Action；
- 必要状态变化；
- Lesson complete。

不要求再抄一份周总结。

`start_lesson` / `complete_lesson` 属于高价值 domain commands；小班 Lesson 的最终事务粒度留 Phase 0B.0 故障/并发 Spike。

---

## 11. 网络失败、本地草稿与并发

V1 online-first，云数据库是唯一正式事实源。

必须：
- 未保存 / 保存中 / 已保存 / 失败 / 本地草稿 / version conflict 清晰；
- 网络失败不清空输入；
- 可恢复草稿加密保存；
- 草稿按 user/org/operation/entity 隔离，有 TTL，同步成功清理；
- 重试不重复事实；
- 云端未确认前不显示正式“已保存”；
- 关键聚合使用 version / expected_version；
- 多人冲突不 silent last-write-wins；
- version conflict 时保留老师原输入并允许对照最新云端内容重新确认。

这不是 offline-first，而是“不让老师白填，也不让本地明文变第二数据库”。

---

## 12. 跨学科协作与权限

**默认隔离、必要互通**：
- 本科 Lead/Collaborator：按 assignment 查看本科详细数据；
- 有 teaching scope 但未 assignment 的普通教师：不能读具体学生详细数据；
- Advisor：更广综合摘要，但不能随意改写专业学科结论；
- Subject Lead：matching leadership scope 内专业管理，不因管理身份伪造教学事实；
- Academic/Org Admin：必要治理视角，不自动成为实际授课教师或 Case owner。

“能看 / 能追加 / 能改 / 能确认 / 能治理”分开。

任何人要以实际教师身份追加 Intervention / Assessment / Lesson 教学行为，必须具备 teacher capability + teaching scope + 合法 Student Assignment / Lesson relationship。

---

## 13. 家校协同

家校不是 CRM，也不是“联系次数 KPI”。

标准链路：

```text
教学事实
→ 系统整理 Draft
→ 教师/Advisor 审阅
→ 现实渠道沟通
→ 记录实际内容与 recipients
→ 家庭配合
→ 家长回应
→ 必要的教学/沟通 follow-up
```

规则：
- Draft ≠ 已联系；
- finalized 是当时真实沟通快照；
- 历史不随后续 Case 静默改写；
- 家庭配合不是 Case Action，因为 Guardian 不是 staff membership；
- 家长新信息不自动成为诊断，需教师判断并保留来源；
- 与 Case 直接相关的员工沟通 follow-up 优先复用 `Case Action communicate`；纯家校跟进使用轻量 communication follow-up，不建立第二套通用 Todo。

---

## 14. 阶段复盘

复用 Report/Stage Review：

```text
系统按 source_cutoff_at 整理事实
→ 教师/Advisor 写真正需要人工判断的内容
→ Draft
→ 授权成员确认
→ Finalized snapshot
```

老师人工负责：
- 本阶段整体进步；
- 遗留问题；
- 下一阶段计划。

系统自动整理已存在的 Cases、Assessments、Interventions、Actions 等事实，不要求重抄。

领导 Excel 的“签字”在软件里转为 `finalized_by + finalized_at` 的责任确认，不要求手写签名图片。

Finalized Stage Review ≠ 已告知家长；真正对外沟通仍产生 Parent Communication。

---

## 15. 机构治理

管理端优先显示可处理的真实异常：
- Case/Action 没有有效 owner/assignee；
- 长期 overdue；
- 长期 pending verification；
- 多次失败/reopen 的长期重点；
- Quick Capture 长期未 formalize；
- teacher disabled / subject scope revoke 前尚未 handoff；
- duplicate Student candidate；
- 家校 follow-up 到期；
- Stage Review due；
- Attachment reference inconsistency。

这些优先从事实派生，**不新增 Case status，也不变成教师效能分/学生风险分**。

---

## 16. Student Lifecycle

- Student 一份主档案；
- 升年级/换校区用 Enrollment 历史；
- teacher 变化用 Assignment 历史；
- inactive/archive 前必须 reconcile active Cases/Actions/assignments；
- inactive 不自动 closed Case；
- restart 继续旧 Student/Subject Profile 历史；
- duplicate 通过受控 merge，source ID 仍可解释。

---

## 17. Cloud / Provider 原则

云端是正式目标，但 Phase 0A.6 不因免费服务便利锁厂商。

原则：
- PostgreSQL-first；
- migration-as-source-of-truth；
- UI/ViewModel 不散落 provider SDK；
- Domain Repository Interface 隔离 provider adapter；
- Storage 保存 object key/path，不保存永久 public URL；
- Realtime 不作为 correctness 前置。

### Phase 0B.0 硬 Gate
在任何正式 business migrations 前，用虚构数据验证：
1. Auth identity strategy（Supabase UUID 心智与 CloudBase Auth ID 差异）；
2. revoked-session/old-token 业务数据立即失权；
3. Windows/Android login/session/refresh；
4. RLS 跨机构/assignment/subject scope；
5. RPC/transaction/version conflict；
6. private Storage；
7. export/restore；
8. 国内实际网络。

Production provider 在这些证据出现前不冻结。

---

## 18. V1 / Pilot 必须有

- 安全登录/机构 membership/首位管理员；
- role + teaching/leadership subject scopes；
- 学生统一主档案与查重；
- Enrollment / teacher/staff assignment 历史；
- Student Subject Profile 当前定位/优势；
- Initial Diagnosis workflow；
- Learning Case + taxonomy；
- 三类 Case 默认 workflow；
- Evidence / Intervention / Assessment；
- Case Action；
- Lesson；
- Today；
- **Student context 内最小家校闭环**；
- RLS/审计/并发；
- network recovery；
- secure Session / encrypted draft；
- DB + Storage recovery；
- 必要 governance/handoff/merge。

### 可以简单
- 附件只支持少量私有文件；
- 管理端只做必要治理；
- 搜索只覆盖高频字段；
- 家校先生成/复制/记录，不接第三方消息平台；
- Windows/Android 内部 Pilot 分发。

### 明确不做
- 收费/课消/招生 CRM；
- 完整排课；
- 大型题库；
- 学情健康分/成绩预测/教师效能分；
- 家长/学生独立 App（V1）；
- 微信/短信 API 作为 V1 前置；
- AI 自动正式诊断；
- CRDT/offline-first；
- 多套登录方式；
- 大量第三方 SaaS；
- Realtime correctness dependency。

---

## 19. V1 成功指标

1. **低负担**：new 10–20 秒，常规课后中位 ≤60 秒；
2. **连续性**：换老师/升年级后仍能快速看懂重点/下一步；
3. **行动完整性**：正式未关闭 Case 都有主行动；
4. **证据性**：关键结论可追溯到 Evidence/Assessment；
5. **协作**：Lead/Collaborator/Advisor 在权限边界内看到同一 Student 的正确数据；
6. **方法完整性**：初诊、三类问题、知识三阶、跨周、家校、阶段复盘没有因软件化被丢失；
7. **安全**：revoked/onboarding/disabled/cross-org/unassigned 无法越权访问；
8. **可靠**：网络失败不丢，重试不重复，并发不静默覆盖；
9. **恢复**：DB/Storage 能从备份实际恢复；
10. **可运营**：教师连续一周愿意真实使用，而不是为了验收点几次。

不把“记录条数”“沟通次数”当成功指标。

---

## 20. 产品铁律

1. 一个学生一份机构主档案。
2. 同一真实事实只记录一次。
3. 重要结论尽量有证据。
4. 正式未关闭 Case 永远有下一步。
5. 学生历史不因换老师/升年级断裂。
6. Role、Subject Scope、Student Assignment 分开。
7. 数据 Read / Append / Edit / Confirm / Govern 权限分开。
8. 老师少填一次，系统多自动一次。
9. 网络失败不能让高频记录消失。
10. 本地恢复不能以明文长期留存敏感数据为代价。
11. Today 不偷偷变排课 CRM。
12. 家校不是 CRM，也不是教师 KPI。
13. Governance 异常是可处理事实，不是风险/效能分。
14. 管理身份不能伪造实际教学事实。
15. AI 只做副驾驶，不能自动正式诊断/清零/finalize。
16. 云厂商便利不能凌驾于权限安全、恢复能力和迁移成本。
17. 功能数量永远排在数据正确、权限安全、教师可用之后。
