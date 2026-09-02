# Phase 0A.6｜Product, Teaching Methodology & Institutional Workflow Foundation

> 本阶段是 Xueqing 在正式云后端/数据库落地前的最后一次产品与领域完整性冻结。
>
> 核心原则：**保留领导的教学责任闭环，删除 Excel 才需要的重复填写；老师少填一次，系统多自动一次。**

## 0. 基线与入口

- Foundation v0.3 已合并 `main`。
- Phase 0A Flutter Windows + Android Engineering Bootstrap 已完成并合并。
- Phase 0A.5 UX/UI Design Foundation 已完成独立终审并通过最终 merge PR #10 Squash Merge 到 `main`。
- Phase 0A.5 merge commit：`5542b208037f77d9833df20edac5b912f3a333da`。
- 本阶段主 Issue：#11。
- Deliverables checklist：#12。
- 工作分支：`phase0/product-completeness-foundation`。
- 本阶段必须建立 Draft PR；不允许直接 push `main`。

## 1. 为什么不能直接进入 Phase 0B

当前 Foundation 的 Case / Evidence / Intervention / Assessment / Action / Lesson / Auth / RLS 方向已经较成熟，但在真正写 migrations 前仍存在会改变领域关系的关键问题：

1. 领导 Excel 的“初诊—三阶—跨周—家校—复盘”方法论尚未正式成为产品事实源；
2. teacher membership、teacher subject scope、student-subject assignment 尚需彻底区分；
3. 多学科教师、Lead/Collaborator、Advisor、Subject Lead 的真实工作边界需要冻结；
4. Lesson 在数据模型里很重要，但完整课前/课中/课后工作流尚未冻结；
5. 家校沟通现有模型偏基础，尚未完整表达反馈草稿、实际沟通、家庭配合、家长回应与 follow-up；
6. 阶段复盘、交接、并发、异常治理需要在多人云软件语境下补全；
7. 官方 Supabase / 中国大陆候选 / 国内自托管路径需要在不锁厂商的前提下做兼容性决策。

这些问题一旦在 migration/RLS 后才修改，会显著增加返工成本，因此先做 Phase 0A.6。

> **Phase 0B.0 provider / production hard boundary**
>
> 当前仅将 Supabase 视为 V1 reference / preferred implementation candidate；尚未无条件冻结为 production provider。正式 production business migrations、Production Auth/RLS/CRUD 与真实学生/教师/家长数据之前，必须先完成并通过：
> 1. **P0 Gate A — Auth Identity Portability Spike**；
> 2. **P0 Gate B — Revoked Session / Old Token Security Spike**。
>
> 在两项 Gate 之前，只允许用虚构数据进行 provider-specific compatibility/security spike；Spike 不构成 production migration 授权。两 Gate 通过后，才可冻结 provider、region、identity 与 session strategy，再另行执行正式 migrations、Auth/RLS/CRUD 与 Go/No-Go。

## 2. 本阶段不是做什么

Phase 0A.6 **不是**：

- 再画一套 UX/UI；
- 把 Excel 原样搬成页面；
- 建正式 production schema；
- 写正式 RLS；
- 开始真实 Student/Case CRUD；
- 导入真实学生/教师/家长数据；
- 做收费/课消/招生 CRM；
- 做完整排课；
- 做家长独立 App；
- 接微信/短信；
- 做 AI 自动诊断或自动判定清零；
- 做 KPI dashboard / 风险分 / 教师效能分；
- 因为免费服务方便就把 Domain 锁死到单一云厂商。

本阶段以**研究、文档、领域决策、流程规格、必要的虚构数据 compatibility spike**为主。

## 3. 统一判断原则

### 3.1 新事实 vs 派生视图

任何新增字段、表、页面、工作流都必须先问：

> 这是一个新的真实业务事实，还是已经存在事实的另一种展示/总结？

若是后者，默认派生，不让老师重新填写。

### 3.2 人工判断 vs 系统自动化

系统适合：
- 聚合事实；
- 计算到期/逾期；
- 整理 timeline；
- 生成草稿；
- 发现异常；
- 提醒下一步。

教师必须保留：
- 问题是否成立；
- 原因判断；
- 是否值得正式跟进；
- assessment 的专业解释；
- 是否进入 stable；
- 是否真正清零/closed；
- 阶段总体判断；
- 正式家长反馈的确认。

### 3.3 连续性优先

学生历史不能因为：
- 换老师；
- 升年级；
- 换校区；
- 跨周；
- 跨学科协作；
- 老师离职；
- Case reopen；
而断裂。

### 3.4 责任可解释

重要事实必须能回答：
- 谁记录；
- 谁负责；
- 谁验证；
- 谁确认；
- 当时依据什么；
- 后来发生什么。

但不得要求老师重复手工填写登录系统已经知道的姓名/身份。

## 4. Workstream A｜Leadership Teaching Model

完整读取用户提供的 Excel 原型，按“理念”而不是“工作表”解释。

必须正式定义：
- Student 学情定位；
- Student/Subject 优势；
- Initial Diagnosis；
- 三类问题：knowledge / habit / exam_strategy；
- 知识类三阶订正；
- 周度迭代；
- 跨周；
- 顽固/长期问题；
- 家校配合；
- 阶段复盘；
- 教师责任确认。

### 三阶订正

产品语言可保留领导熟悉的“三阶订正”，但数据库不得硬编码成三个固定列。

默认知识类 workflow：

`当堂订正 → 相似题巩固 → 延迟/次课独立验证 → stable observation → closed/清零`

一次第三阶 passed 不自动 closed。

### 清零语义

必须明确：
- assessment passed：一次检查结果；
- pending_verification：Case 等待教师确认；
- stable：已有改善证据但仍观察；
- closed：退出主动跟进；
- “清零”作为教师语言，何时对应 closed 必须有明确规则；
- reopen 为 command/event，不是 status。

## 5. Workstream B｜Case Workflow Templates

统一底层领域对象，差异化产品 workflow。

### Knowledge
- correction；
- similar practice；
- delayed independent verification；
- stable observation；
- close/reopen。

### Habit
- 定义可观察行为；
- 目标行为；
- intervention；
- 连续多次 observation；
- 调整策略；
- stable/continue。

禁止使用人格化结论。

### Exam Strategy
- strategy instruction；
- guided application；
- timed/simulated transfer；
- independent verification；
- stable/continue。

必须定义模板是 default workflow，不是强制所有 Case 使用完全相同阶段数。

## 6. Workstream C｜Teacher / Subject / Student / Staff

必须冻结三层关系：

1. `organization_membership`：这个人是谁、是否 active；
2. teacher subject scope：机构授权/配置该老师可在哪些 subject 工作；
3. student-subject assignment：该老师当前实际负责哪些学生的哪些学科。

重点评估是否新增独立映射（命名最终由数据模型审查决定），不得从 student assignment 反推 teacher subject scope。

冻结：
- multi-subject teacher；
- one student / many subjects；
- one active Lead per student+subject by default；
- Collaborator；
- Advisor / homeroom / coordinator；
- Subject Lead；
- academic admin；
- view vs edit；
- handoff before disabled。

## 7. Workstream D｜Initial Diagnosis

目标工作流：

`Student → Enrollment/Subject Profile → current positioning → strengths → problems → priority → formal Cases → first Actions`

原则：
- Student 不进入空白 ERP 档案页；
- 初诊不能阻塞式要求填完所有字段；
- strengths 与 problems 同时存在；
- confirmed Case 前补齐必要结构；
- 不制造单独“初诊问题第二台账”。

## 8. Workstream E｜Lesson Workspace

Lesson 是真实教学会话上下文，不是完整排课产品。

### Pre-lesson
目标约 30 秒理解：
- 本次负责学生；
- overdue/today actions；
- pending verification；
- 上次 next action；
- 最近关键 Evidence/Intervention。

### In-lesson
只记录新的真实事实：
- complete/adjust action；
- Evidence；
- Intervention；
- Assessment；
- Quick Capture new issue。

### Post-lesson
目标 30–60 秒：
- 收口旧 action；
- 必要 Case command；
- formalize 必要 new Case；
- 创建下一 primary action；
- complete lesson。

审查 `complete_lesson` 如何原子化，但本阶段不写正式数据库 function。

周度跟进应优先由这些事实派生，不要求教师重填“本周做了什么”。

## 9. Workstream F｜Parent Communication

把家校从“备注”升级为闭环，但不做家长 App。

必须区分：
- generated/drafted feedback；
- teacher/advisor confirmed content；
- actual sent/discussed communication snapshot；
- guardian response；
- home support request；
- follow-up date；
- related Cases/Evidence；
- incoming family fact 如何进入教学闭环。

支持的产品层级：
- post-lesson feedback；
- weekly feedback；
- stage feedback。

任课教师维护专业学科结论；Advisor 可以在授权范围整理跨学科摘要，但不能静默重写任课教师专业结论。

历史已发送内容必须可解释“当时说了什么”，不能随后续 Case 编辑静默变化。

## 10. Workstream G｜Stage Review

阶段复盘不是自动 KPI 报告。

系统负责整理：
- period facts；
- key Cases；
- interventions；
- assessments；
- stable/closed/reopened；
- unresolved items。

教师负责确认：
- overall progress；
- remaining issues；
- next-stage plan。

finalized report/review 必须是冻结 snapshot，包含 finalized_by / finalized_at 等责任事实。

## 11. Workstream H｜Institutional Governance

管理端优先显示可处理异常，而不是 dashboard vanity metrics。

至少设计：
- active Case 无有效 owner；
- pending primary action 无有效 assignee；
- overdue 超过治理阈值；
- pending verification 长期未确认；
- repeated failed assessment；
- repeated reopen / long-running Case；
- stale Quick Capture；
- disabled teacher 未完成 handoff；
- duplicate student；
- merge history；
- student inactive/archive/restart；
- attachment/evidence lifecycle；
- data integrity anomaly。

阈值用于治理提醒，不生成“学生风险分”。

## 12. Workstream I｜Concurrency / Reliability / Drafts

结合现有 version/expected_version 设计用户可理解的冲突行为：

> “另一位老师刚更新了该 Case。请查看最新内容；你的未提交文字已保留。”

禁止 silent last-write-wins。

必须区分：
- unsaved；
- saving；
- saved；
- failed；
- local recoverable draft；
- syncing；
- conflict；
- synced（若后续真的引入同步队列）。

本阶段定义语义，不实现完整 offline-first。

## 13. Workstream J｜Cloud Backend Decision

云端是产品正式目标；多人机构数据互通不能依赖单机数据库，但 Phase 0A.6 不冻结 production provider 或执行 production business migration。

### 候选

A. Official Supabase APAC（优先新加坡作为基准候选）  
B. Mainland China PostgreSQL/Supabase-compatible candidate（例如腾讯 CloudBase PG）  
C. Self-hosted Supabase on mainland cloud as portability/future-control path

### 评价维度

- Flutter Windows / Android support；
- PostgreSQL compatibility；
- migrations；
- RLS；
- Auth/session semantics；
- session revoke / old JWT denial；
- RPC / transactions；
- private object storage；
- backup / restore；
- mainland network quality；
- free-tier constraints；
- operational burden；
- vendor lock-in；
- migration/export path。

### Spike discipline

- 只能使用 fictional data；
- 不建立 production student database；
- 未真实执行的项目必须写“未验证”；
- 不用网页宣传语替代可执行安全验证；
- 不因当前免费额度而牺牲 RLS、备份、恢复或迁移能力。

架构原则：

**PostgreSQL-first / migration-as-source-of-truth / repository abstraction / provider-portable**。

## 14. 数据模型修订规则

Phase 0A.6 可以提出对 `DATA_MODEL.md`、`COMMANDS_AND_INVARIANTS.md`、`AUTH_AND_PERMISSIONS.md` 等 Foundation 文档的小范围修订，但必须：

1. 说明当前缺口；
2. 说明为什么领导理念或真实机构工作流要求修订；
3. 区分新增事实与派生视图；
4. 评估 RLS/命令/历史迁移影响；
5. 不直接写 production migration；正式 migration/Auth/RLS/CRUD 仍须等待 P0 Gate A/B；
6. 有 independent audit。

## 15. 计划交付文件

```text
docs/
  PHASE0A6_EXECUTION_BRIEF.md
  product/
    LEADERSHIP_TEACHING_MODEL.md
    DOMAIN_GLOSSARY.md
    CASE_WORKFLOW_TEMPLATES.md
    TEACHER_SUBJECT_ASSIGNMENTS.md
    INITIAL_DIAGNOSIS_WORKFLOW.md
    LESSON_WORKFLOW.md
    PARENT_COMMUNICATION_WORKFLOW.md
    STAGE_REVIEW_WORKFLOW.md
    INSTITUTIONAL_GOVERNANCE.md
    CLOUD_BACKEND_DECISION.md
    PRODUCT_COMPLETENESS_AUDIT.md
```

不要为了文件齐全创建空洞文档。可以合并高度重叠文件，但最终每个主题必须有唯一事实源。

## 16. 必须进行的反例审计

完成前至少逐一回答：

1. 一个老师教三科怎么办？
2. 同一学生同一科 Lead + Collaborator 怎么办？
3. 学管能看什么、能改什么？
4. 学科负责人边界是什么？
5. 知识问题第三阶通过一次是否清零？为什么？
6. 习惯问题怎么证明稳定？
7. 考试技巧如何验证迁移？
8. Case 多次失败后如何升级而不造第二张“顽固表”？
9. 老师离职后 Case/Action/Student assignment 怎么交接？
10. 两个老师同时改 Case 怎么办？
11. 学生重名/重复档案怎么办？
12. 学生升年级、停读、回归怎么办？
13. 家长反馈带来新的学情事实怎么办？
14. 过去发给家长的内容以后还能还原吗？
15. 阶段报告能否解释 source cutoff？
16. 断网后老师输入是否丢失？
17. provider 更换是否迫使 Flutter 大面积重写？
18. 哪些东西系统应该自动做而不再要求老师填写？

## 17. 审计门槛

至少进行：

### Teaching fidelity audit
领导 Excel 的理念是否被技术抽象抹掉？

### Teacher burden audit
有没有新功能要求重复输入已经存在的事实？

### Institutional collaboration audit
多人、多学科、交接、权限是否真实成立？

### Data/domain audit
事实、snapshot、派生视图是否分清？

### Failure-mode audit
离职、冲突、断网、重复学生、长期未验证是否有明确行为？

### Cloud portability/security audit
云候选是否支持所需安全语义，是否存在未经验证的兼容假设？

### Scope audit
是否偷偷进入 Phase 0B？

## 18. 完成条件

Phase 0A.6 只有在以下全部成立时才可声明完成：

- [ ] Leadership Teaching Model 已冻结；
- [ ] Domain glossary 与业务语言映射完成；
- [ ] 三类 Case workflow 完成；
- [ ] teacher subject scope 决策完成；
- [ ] teacher/student/advisor assignment 完成；
- [ ] Initial Diagnosis 完成；
- [ ] Lesson workflow 完成；
- [ ] Parent Communication 完成；
- [ ] Stage Review 完成；
- [ ] Institutional Governance 完成；
- [ ] concurrency/draft/failure semantics 完成；
- [ ] Cloud Backend Decision 有证据等级与未验证项；
- [ ] 必要 Foundation 文档修订完成；
- [ ] Product Completeness Audit 无 P0/P1；
- [ ] Final PR Head 正式 CI 成功；
- [ ] 无 production migrations/RLS/Auth/real CRUD 越界；
- [ ] 无真实学生/家长数据；
- [ ] Draft PR 保持 Open 等待独立终审。

完成后停止。**不得自动进入 Phase 0B。**
