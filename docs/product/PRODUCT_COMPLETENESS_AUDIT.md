# Product Completeness Audit｜产品完整性攻击审计

> 当前状态：**Round 2 — INTERNAL PASS / READY FOR INDEPENDENT AUDIT**  
> 日期：2026-09-02  
> 范围：Phase 0A.6 事实源 + 回写后的 Product/Data/Commands/Auth Foundation + 领导 Excel 原型。  
> 注意：本轮由实施主线自行执行，不冒充最终“独立审计”。PR #13 仍需未参与设计的模型终审。

## 1. 审计方法

不问“文档多不多”，而持续攻击：

> 如果明天真有一个机构、多个老师、多学科、停读/复课、家长异步回复、弱网、离职交接和两个云候选，系统会在哪里语义断裂？

攻击维度：
- 领导方法忠实度与来源归因；
- Student / Subject service lifecycle；
- Case resolution lifecycle；
- teacher/subject/student relationships；
- Role / Scope / Assignment / Teaching Fact permissions；
- Initial Diagnosis；
- 三类 Case workflow；
- Lesson；
- 家校事件；
- Stage Review；
- handoff / merge / governance；
- concurrency / retry / draft recovery；
- Cloud/Auth portability；
- 数据最小化与重复台账。

严重度：
- P0：任何正式 business migration 前必须有执行证据；
- P1：Phase 0A.6 文档/领域内部必须解决；
- P2：可以显式推迟，但要有原因和验证计划。

---

# 2. Round 1 发现与处理结果

## P1-01｜Subject Scope 表达不一致
问题：一处只像“教师学科列表”，另一处需要 teaching/leadership 区分。

修复：统一：

`membership_subject_scopes.scope_kind = teaching / leadership`

结果：**RESOLVED**。

---

## P1-02｜Subject Lead/Admin 可能被误读为可追加教学事实

修复：新增 Teaching Fact Gate：

```text
live session
+ active membership
+ teacher capability
+ teaching scope
+ active Subject Profile
+ Student Assignment / Lesson relationship
+ operation permission
```

Leadership/Admin/Advisor 身份本身不能写 Intervention/Assessment/Lesson teacher。

结果：**RESOLVED**。

---

## P1-03｜家校完全放 V1.1 会损失领导方法闭环

修复：
- V1 Internal Pilot：Student/Case context 内最小家校；
- V1.1：独立家校工作台/更强综合视图；
- 家长 App/微信 API 仍不做。

结果：**RESOLVED**。

---

## P1-04｜Data Model 尚未吸收 0A.6

已回写：
- subject scopes；
- Subject Profile positioning/strengths/service lifecycle；
- guardian_report Evidence source；
- Parent Communication events/recipients/replies/follow-up；
- Reports finalized/version/correction；
- governance-derived anomalies；
- Cloud/Auth P0 注记。

结果：**RESOLVED**。

---

## P1-05｜Commands 尚未吸收新工作流

已回写/冻结语义：
- start_lesson；
- revoke_teacher_subject_scope_and_handoff；
- deactivate/reactivate Student Subject Profile；
- Student deactivate/reactivate/archive reconciliation；
- finalize/correct Parent Communication；
- finalize/correct Report。

结果：**RESOLVED**。

---

## P1-06｜Student inactive/archive 会残留 Today 或假关闭 Case

Round 2 进一步发现：只讨论整个 Student 仍不够，现实会出现“继续语文、停止数学”。

最终修复：
- Student Subject Profile 自己有 `active / inactive / archived` service lifecycle；
- Case resolution lifecycle 与 service lifecycle 正交；
- Profile inactive 时 unresolved Case 保留真实 status；
- current pending Action 受控收口并退出普通 Today；
- **绝不因为停读/停科自动 closed/已清零**；
- reactivation 前 unresolved formal Case 必须重新建立 owner + pending primary Action。

结果：**RESOLVED，而且比 Round 1 方案更完整。**

---

## P1-07｜Parent Communication follow-up 只有日期没有责任闭环

最终：
- Case-related → `Case Action(action_type=communicate)`；
- non-case → communication 自身 lightweight assignee/due/status/completed；
- 不建通用第二套 Todo。

结果：**RESOLVED**。

---

## P1-08｜Lesson start / 小班 finalize

最终：
- `start_lesson` 冻结为 domain command；
- start 需要 teaching scope + assignment + **active Subject Profile**；
- 小班 whole-lesson atomic vs per-student reconcile 明确转 Phase 0B.0 fault/transaction Spike。

结果：**RESOLVED / IMPLEMENTATION SPIKE EXPLICIT**。

---

# 3. Round 2 新发现与修复

## R2-P1-01｜Finalized 家校记录不能成为“会继续长大的聊天线程”

攻击场景：
- 09:00 老师 outbound 已 finalized；
- 20:00 家长微信回复；
- 如果回头写进上午那条 `guardian_response`，上午 snapshot 被改变。

最终模型：
- Parent Communication = communication event；
- outbound/inbound/conversation；
- 异步 reply 新增 inbound event + `reply_to`；
- 电话/面谈同一 interaction 可以一条 conversation event；
- Thread 是 events 聚合关系，不是 mutable finalized row。

Data / Commands / Product / Parent Workflow 已同步。

结果：**RESOLVED**。

---

## R2-P1-02｜`closed=已清零` 与“服务停止”存在潜在混淆

攻击场景：学生停数学，未解决 Case 怎么清 Today？

错误答案：批量 closed。

最终语义：
- `closed` 只表达问题真实解决、退出主动解决跟进；
- `Profile inactive` 表达当前学科服务暂停；
- suspended unresolved Case 不叫 reopen，恢复叫 resume tracking；
- `student/profile inactive ≠ Case closed`。

Domain Glossary 已加硬规则：

```text
一次满分 ≠ closed
学生停读 ≠ closed
某学科停课 ≠ closed
老师离职 ≠ closed
```

结果：**RESOLVED**。

---

## R2-P1-03｜Lesson permission 未明确 Profile active

修复：`start_lesson/complete_lesson` 以及 Lesson Workflow 明确需要 target Subject Profile=active。

结果：**RESOLVED**。

---

## R2-P1-04｜Governance 文档仍保留第一轮旧结论

发现旧描述：
- Student inactive 的 Case plan 尚“待决定”；
- non-case communication follow-up “可能需要 staff task”。

修复：Governance 全量同步最终模型：Profile lifecycle、event reply、lightweight follow-up、不建 generic Todo。

结果：**RESOLVED**。

---

# 4. Round 2 场景攻击结果

## A. 领导方法/来源

### A1. 所有 Excel 列都算领导原要求？
否。`EXCEL_SOURCE_PROVENANCE.md` 分开：
- 源方法高置信七段；
- Excel 结构化口径；
- Excel 化管理建议；
- Xueqing 工程增强。

**PASS**。

### A2. 软件是否把领导三阶藏掉？
没有。Knowledge workflow 保留三阶教学语言，但底层泛化。

**PASS**。

### A3. Habit/Exam Strategy 是否被硬套三阶？
没有，各自有不同默认 workflow。

**PASS**。

---

## B. Student / Subject Lifecycle

### B1. 学生升年级？
Enrollment 历史变化，Student 不重建。

**PASS**。

### B2. 学生继续语文、停止数学？
Student active；语文 Profile active；数学 Profile inactive。

**PASS**。

### B3. 数学还有 unresolved Case？
保留原 Case status，暂停 tracking，不伪造 closed。

**PASS**。

### B4. 恢复数学？
先恢复 assignment/owner、给 unresolved Cases 建 primary Actions，再 Profile active。

**PASS**。

### B5. 整体停读/回归？
逐 Profile reconciliation，再 Student inactive/reactivate；同一 Student history 连续。

**PASS**。

---

## C. Case Lifecycle

### C1. 三阶满分一次自动清零？
不允许。

**PASS**。

### C2. stable 后没人再看？
active Profile 下 stable 仍需 review/verify Action。

**PASS**。

### C3. Profile inactive 后 Action invariant 怎么办？
active Profile 才要求 current pending primary；inactive Profile unresolved Case 可 suspended 无 current Action。

**PASS**。

### C4. Profile resume 是否叫 reopen？
不是。Case 未 closed 时只是 resume tracking；reopen 仅 closed 后真实复发。

**PASS**。

---

## D. Teacher / Permission

### D1. 一个老师教三科？
多 teaching scopes + 多 Student Assignments；Today 汇总后可 subject filter。

**PASS**。

### D2. 同学生同科两个老师？
Lead + Collaborator；默认最多一个 active Lead。

**PASS**。

### D3. 老师仍在职但退出政治？
subject-scope handoff，只转政治，不 disable 整人。

**PASS**。

### D4. Teacher 有语文 scope 但未 assignment？
不能读具体学生详细数据。

**PASS**。

### D5. 纯 Subject Lead 写 Intervention？
Teaching Fact Gate 拒绝。

**PASS**。

### D6. Org Admin 自己也授课？
必须另外有 teacher capability + teaching scope + Student/Lesson relationship。

**PASS**。

### D7. Advisor 修改语文 Case root cause / close Case？
默认不允许。

**PASS**。

---

## E. Lesson

### E1. Profile inactive 还能开始 Lesson？
不能。

**PASS**。

### E2. 课上 90 分钟后 App crash？
事实逐步可靠保存 + encrypted draft；complete_lesson 不作为第一次保存所有内容。

**PASS conceptually**。

### E3. 小班一个学生 version conflict？
领域不变量清楚，但最终事务粒度需要真实 DB fault Spike。

**PASS AS EXPLICIT PHASE 0B.0 SPIKE**。

---

## F. 家校

### F1. Draft 没发送？
不计 actual communication。

**PASS**。

### F2. 上午 outbound，晚上家长回复？
新增 inbound reply，不改旧 finalized。

**PASS**。

### F3. 电话中双方当场交流？
一条 conversation event 合法。

**PASS**。

### F4. 父母双方都收到？
多 recipients 语义支持。

**PASS**。

### F5. 家长说“孩子在家经常拖延”？
先 inbound communication；授权教师判断后才能形成 guardian_report Evidence/Case。

**PASS**。

### F6. 家庭任务能 assigned 给家长？
不能。Guardian 不是 membership。

**PASS**。

### F7. 家校 follow-up 会制造第二套 Todo？
Case-related 用 communicate Action；non-case 用轻量 communication follow-up。

**PASS**。

---

## G. Stage Review

### G1. Report finalized 后第二天 Case reopen？
旧 snapshot 不变。

**PASS**。

### G2. 补录上月 Evidence？
不静默重写旧 finalized Report。

**PASS**。

### G3. Advisor 综合多个学科会改原学科结论？
不能，只引用允许共享的 source。

**PASS**。

### G4. Finalized Report 等于家长已知？
不等于；真正沟通另有 Parent Communication event。

**PASS**。

---

## H. Governance / Reliability

### H1. Teacher disabled 前仍有 Cases？
先 handoff，最后 disabled。

**PASS**。

### H2. Request 成功但 response 丢失？
UUID/operation_id + 查询已有结果，不重复副作用。

**PASS conceptually**。

### H3. 两个老师同时修改 Case？
version/expected_version，不 last-write-wins，保留用户输入。

**PASS conceptually**。

### H4. Inactive Profile 仍有 pending Action？
治理异常；正常 deactivation command 应先阻止。

**PASS**。

### H5. 管理端变教师 KPI？
明确禁止，展示可处理事实。

**PASS**。

---

# 5. 仍然 OPEN 的 P0：不是文档缺陷，而是必须实测

## P0-01｜Auth Identity Portability

Supabase 与 CloudBase Auth ID 类型差异已确认，但最终 identity strategy 未执行 Spike。

候选：
1. provider-specific Auth PK；
2. business Profile UUID + external auth subject；
3. text auth subject / weak-coupled identity link。

**必须在任何正式 business migration 前解决。**

状态：`OPEN → Phase 0B.0 hard gate`。

---

## P0-02｜Revoked-session old-token 安全

产品不变量：signOut/reset/disabled 后旧 token 不能读学生数据。

Supabase reference 已有设计；CloudBase 等价实现尚未真实请求验证。

必须测试：
- Windows/Android；
- old access token；
- reset；
- disabled；
- app restart；
- RLS/API request。

状态：`OPEN → Phase 0B.0 hard gate`。

---

# 6. P2 明确推迟

## P2-01｜Initial Diagnosis Snapshot
不建大表。Pilot 问：几个月后是否真的需要“一键回看初始整体基线”。需要才做轻量 immutable snapshot/event。

## P2-02｜Positioning 四档物理存储
产品可先稳定 codes/labels，不急于 PostgreSQL ENUM。

## P2-03｜Realtime
不作为 correctness 基础，后续 enhancement。

## P2-04｜小班 Lesson final transaction shape
需求和验收不变量已冻结，具体数据库事务形态由 Phase 0B.0 fault Spike 决定。

这些 P2 都有明确推迟理由，不属于“忘了做”。

---

# 7. Foundation 一致性检查

当前以下文件对关键边界已给出一致答案：

### Product
`PRODUCT.md`

### Data
`DATA_MODEL.md`

### Commands
`COMMANDS_AND_INVARIANTS.md`

### Auth/RLS
`AUTH_AND_PERMISSIONS.md`

### Supporting facts
- Domain Glossary；
- Leadership Teaching Model；
- Excel Source Provenance；
- Teacher Subject Assignments；
- Role Workflow Matrix；
- Initial Diagnosis；
- Case Workflow Templates；
- Lesson Workflow；
- Parent Communication Workflow；
- Stage Review Workflow；
- Institutional Governance；
- Reliability & Concurrency；
- Cloud Backend Decision；
- Foundation Change Proposal。

关键等式一致：

```text
Role ≠ Subject Scope ≠ Student Assignment
Subject Profile status ≠ Case status
Profile inactive ≠ Case closed
Assessment passed ≠ stable ≠ closed
reopen ≠ tracking resume
Parent Communication thread ≠ mutable finalized row
Finalized Report ≠ Parent informed
management permission ≠ teaching actor permission
```

---

# 8. Scope audit

当前 Phase 0A.6 没有进入：
- production DB migrations；
- production Auth/RLS；
- 真实 Student/Case CRUD；
- 真实学生/家长数据；
- 家长 App；
- 微信/短信 API；
- billing/课消/CRM；
-完整排课；
- AI 自动正式诊断；
- KPI/风险分/效能分；
- Realtime correctness dependency。

**PASS。**

---

# 9. Round 2 Verdict

## **INTERNAL PASS — READY FOR INDEPENDENT PRODUCT COMPLETENESS AUDIT**

Phase 0A.6 内部 P1 已收口。

仍存在的 P0-01/P0-02 是被明确隔离到 **Phase 0B.0 pre-migration Cloud/Auth Compatibility Spike** 的执行 Gate；它们不能在 Phase 0A.6 通过文字“解决”，也不能被后续实现绕过。

下一步不是直接 Merge，也不是进入 Phase 0B：

1. 更新 deliverables/checklist 与 PR 证据；
2. 最终 Head 正式 CI；
3. 由**没有参与本轮设计的模型**读取最新 PR 全部事实源，做独立 Product Completeness Audit；
4. 只有独立结论 `PASS — READY FOR MERGE` 才允许合并 Phase 0A.6；
5. 合并后 Phase 0B 先开 `0B.0 Cloud/Auth Compatibility Spike`，不直接大规模建表。
