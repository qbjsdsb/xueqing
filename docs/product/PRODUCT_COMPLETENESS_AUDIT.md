# Product Completeness Audit｜产品完整性攻击审计

> 审计状态：**Round 1 — CHANGES REQUIRED**  
> 日期：2026-09-02  
> 范围：Phase 0A.6 当前事实源 + Phase 0A.5 Foundation + 领导 Excel 原型。  
> 本文件是审计记录，不替代各主题事实源；发现问题必须回到事实源收口。

## 1. 审计方法

本轮故意不问“文档写得全不全”，而问：

> 如果明天真的有一个机构、多个老师、多学科、真实学生、弱网和人员交接，系统会在哪里断？

攻击维度：
- 领导方法忠实度；
- 人/学科/学生关系；
- 权限与责任；
- 初诊/Case/三阶；
- Lesson；
- 家校；
- 阶段复盘；
- 学生生命周期；
-并发/可靠性；
-云端与迁移；
-数据最小化；
-避免重复台账。

严重度：
- P0：不解决不能进入正式 migration/真实数据；
- P1：进入 Phase 0B 前必须有明确领域结论；
- P2：可以有意识推迟，但必须记录理由与验证方式。

---

# 2. 已通过的核心攻击

## PASS-01｜Excel 不是软件页面模板
已建立来源分级；确认七段方法骨架与 Excel 新增管理字段不是同一证据等级。

结果：PASS。

## PASS-02｜同一学生多学科
Student 唯一主档案 + Student Subject Profile 分科连续；不会因为语文/数学建立两个 Student。

结果：PASS。

## PASS-03｜一个老师教多科
Membership / Subject Scope / Student Assignment 三层分开；Today 默认聚合本人多科事项，可按学科过滤。

结果：PASS（但 Scope 表达存在 P1-01 文档冲突，见下）。

## PASS-04｜同一学生同一科 Lead + Collaborator
Assignment role 已能表达；历史实际 actor 不随 Lead 变化重写。

结果：PASS。

## PASS-05｜Advisor 不伪装学科老师
Advisor 有综合读取/家校协调权，但不能修改 subject professional conclusion / close Case。

结果：PASS。

## PASS-06｜三阶满分一次是否自动清零
明确：Assessment passed ≠ stable ≠ closed；三阶结果与最终清零分离。

结果：PASS。

## PASS-07｜习惯问题是否机械套三阶
Habit 使用可观察行为 + 多场景连续观察；不机械三阶。

结果：PASS。

## PASS-08｜考试技巧迁移
Exam strategy 要求方法 → 应用 → 限时/模拟 → 独立迁移，不只做同题复现。

结果：PASS。

## PASS-09｜顽固问题
由失败/持续/reopen 等事实派生，不新增 status/table。

结果：PASS。

## PASS-10｜周度跟进
优先由 Lesson/Case/Action/Assessment 派生，不要求第二份周表。

结果：PASS。

## PASS-11｜老师离职
现有 disable + handoff 先交接、最后 disabled，历史 actor 保留。

结果：PASS。

## PASS-12｜老师仍在职但退出某学科
已识别独立 subject-scope handoff，不会误停整个人。

结果：PASS conceptually；Commands 回写见 P1-05。

## PASS-13｜重复学生
同名非硬唯一；真正 duplicate 受控 merge；source ID/history 可解释。

结果：PASS。

## PASS-14｜学生升年级
Enrollment 历史变化，不新建 Student，不覆盖旧年级历史。

结果：PASS。

## PASS-15｜多人同时保存
关键 aggregate 使用 version/expected_version；冲突不 last-write-wins；用户输入不清空。

结果：PASS。

## PASS-16｜网络成功但响应丢失
简单 insert 预生成 UUID；command operation_id；不盲目重复副作用。

结果：PASS。

## PASS-17｜家长新信息
Guardian response 不自动变诊断；教师判断后可成为明确来源的 Evidence/Observation/Case。

结果：PASS conceptually；Evidence source 需 Foundation 回写。

## PASS-18｜阶段报告历史是否会变
source_cutoff + content_snapshot + finalized；后续 Case reopen 不改旧报告。

结果：PASS。

## PASS-19｜AI 权限
AI 仅整理 draft，不自动 stable/closed/finalized，不产生学生评分。

结果：PASS。

## PASS-20｜治理是否变教师监控
治理展示 orphan/overdue/handoff 等可处理事实，不做教师排名/效能分。

结果：PASS。

---

# 3. P0｜正式 migration 前硬 Gate

## P0-01｜Auth identity type portability 尚未冻结

现状：
- Foundation 假设 Supabase `profiles.id → auth.users(id)`；
- CloudBase PG `auth.users.id` 官方为 `varchar(64)`；
- Provider 尚未选择。

风险：
一旦 migration 用 Supabase UUID 强耦合，之后切 CloudBase 需要身份主键重构；反之亦然。

要求：
Phase 0B 的第一项必须是 Auth identity/RLS Spike，比较：
1. provider-specific auth PK；
2. business Profile UUID + external auth subject；
3. text auth subject without hard FK。

需用 RLS、provisioning、EXPLAIN、migration/restore 实测。

状态：**OPEN — external execution gate。**

说明：允许 Phase 0A.6 文档合并，但**禁止任何正式 business migration 在此项解决前落地**。

---

## P0-02｜Revoked-session 安全在 CloudBase 未执行验证

产品不变量：

> signOut/reset/disabled 后旧 access token 不能继续读取学生数据。

Supabase Foundation 有 `session_id → auth.sessions` 设计。

CloudBase 官方说明 signOut 可使 access token 失效，但尚未执行 Xueqing 的真实 RLS/API fault test。

要求：
- old token request；
- reset/password change；
- disabled membership；
- token refresh；
- app restart；
- Windows/Android；

全部用虚构数据验证。

状态：**OPEN — external execution gate。**

同 P0-01：这是 Phase 0B.0 pre-migration gate，不允许带着未知结果直接建生产 schema。

---

# 4. P1｜Phase 0A.6 内部必须收口

## P1-01｜Subject Scope 结构在事实源间不完全一致

`TEACHER_SUBJECT_ASSIGNMENTS.md` 正确识别：
- teaching scope；
- leadership scope；

需要区分，例如某老师教语文/历史，但只负责语文管理。

`FOUNDATION_CHANGE_PROPOSAL.md` 的主表候选段落却没有把 `scope_kind` 明确列入最终 ACCEPT 字段。

风险：以后实现者可能做成一张“老师学科列表”，无法表达 leadership scope。

修复：统一为 `membership_subject_scopes` + `scope_kind = teaching / leadership`（最终 enum/check 名称在 migration 决定）。

状态：OPEN。

---

## P1-02｜Subject Lead / Admin 追加教学事实的边界需要更严格

当前 Role Matrix 某些表述可能让人误读：Subject Lead “实际参与时”可以 Append Evidence/Assessment。

硬规则应是：

> 任何人要以“实际授课教师”身份追加 Intervention/Assessment，必须同时拥有 teacher capability + teaching subject scope + 对该 student+subject 的合法 assignment/lesson relation。

`leadership scope` 或 admin 权限本身不能伪造授课事实。

修复 Role Matrix。

状态：OPEN。

---

## P1-03｜家校 V1/V1.1 路线冲突

当前 `PRODUCT.md`：

> 家校、报告属于 V1.1。

但领导方法论把家校协同作为完整闭环的重要一环。

风险有两个极端：
1. V1 完全没有家校，领导会觉得原体系丢了一环；
2. 为了“完整”立刻做家长 App/微信 API，严重 scope creep。

推荐收口：
- **V1 internal Pilot：Student Detail 内提供最小 contextual Parent Communication（生成/复制/记录实际沟通/家庭配合/follow-up）；不新增主导航。**
- **V1.1：独立家校工作台、丰富阶段报告/综合反馈。**
- 家长 App/微信 API 仍不做。

状态：OPEN，需回写 PRODUCT。

---

## P1-04｜现有 Data Model 还未吸收 0A.6 已 ACCEPT 的真实事实

至少：
- membership subject scopes；
- Subject Profile positioning/strengths；
- Parent Communication draft/finalized/multi-recipient；
- Report finalized_by/time/version/correction；
- guardian-report Evidence source；
- derived governance anomalies 说明。

风险：如果不回写，Phase 0B 模型会继续按旧 Foundation 建表。

状态：OPEN。

---

## P1-05｜Commands 尚未吸收新高风险工作流

需评估/回写：
- start_lesson；
- revoke_teacher_subject_scope_and_handoff；
- student deactivate/archive reconciliation；
- finalize/correct Parent Communication；
- finalize/correct Report。

不是所有都一定成为独立 DB Function，但必须有 domain command 语义，避免 UI 任意 CRUD。

状态：OPEN。

---

## P1-06｜Student inactive/archive 的 Case/Action plan 需要冻结

问题：学生停读时不能只改 `students.status`，否则 Today 可永久出现 overdue。

推荐：
- 结束当前 enrollment；
- 处理 active assignment；
- 对每个 active Case 选择：保持未来 review / 有理由 cancel pending action / close（只有真实满足）/其他合法处理；
- 记录 reason + audit；
- inactive 不等于 Case 自动 closed。

需要把这套 reconciliation 写入 Commands/Foundation。

状态：OPEN。

---

## P1-07｜Parent Communication follow-up 不能只剩一个日期

当前 Foundation `follow_up_at` 无 owner/完成事实。

推荐最小方案：
- Case 相关 follow-up → Case Action communicate；
- 非 Case 家校跟进 → communication 内轻量 `follow_up_assigned_membership_id + follow_up_at + follow_up_completed_at/status`；
- 不建立通用 Todo 系统。

需要在 Data Model/Command 中冻结。

状态：OPEN。

---

## P1-08｜Lesson start 与小班 finalize 边界

Lesson start 可能跨 lesson + participants + permission checks，不应裸 inserts。

建议 `start_lesson` domain command。

小班 `complete_lesson`：整 Lesson 大事务 vs per-student reconcile 尚需 Phase 0B fault/transaction Spike。

收口方式：
- Phase 0A.6 冻结 start command；
- 小班 atomic boundary 标为 explicit Phase 0B Spike，不阻塞文档 merge，但禁止未经测试写死。

状态：OPEN。

---

# 5. P2｜允许有意识推迟

## P2-01｜Initial Diagnosis Snapshot

问题：是否需要几个月后“一键看到第一次建档时整体判断”。

领导 Excel 有试听/建档日期，但没有充分证据说明必须维护一张独立历史初诊对象。

推荐 V1：
- 不新增 `initial_diagnoses` 大表；
- 保存当前 Subject Profile positioning/strengths；
- earliest Case/Evidence 保留历史；
- Pilot 专门问领导/教师是否需要“初始基线快照”。

如果真实需要，再采用轻量 immutable snapshot/event，而不是第二套 Case。

状态：**DEFER WITH VALIDATION**。

---

## P2-02｜定位四档是否数据库硬 enum

Excel 当前：基础薄弱 / 中等待提升 / 中等稳定 / 培优拔高。

建议：作为默认 UI 口径/稳定 code，不急于 PostgreSQL ENUM 硬编码；Pilot 后确认术语稳定性。

状态：DEFER implementation detail。

---

## P2-03｜Realtime

当前业务 correctness 不依赖 Realtime；CloudBase 与 Supabase 能力不同。

继续 page enter/save/resume/manual refresh。

状态：INTENTIONALLY DEFERRED。

---

# 6. 版本与交付策略审计

推荐调整路线：

```text
Phase 0A.6
产品/领域冻结
        ↓
Final independent audit
        ↓
Merge
        ↓
Phase 0B.0
Cloud/Auth Compatibility Spike（仅虚构数据）
        ↓
解决 P0-01 / P0-02
        ↓
Cloud Provider Gate
        ↓
Phase 0B.1
正式 Auth / Membership / RLS / migrations vertical slice
```

这样“进入 Phase 0B”不再等于“立刻建全部表”。

---

# 7. Round 1 verdict

**CHANGES REQUIRED**

原因：P1-01 ～ P1-08 尚需在 Phase 0A.6 事实源/Foundation 中收口。

P0-01/P0-02 因缺少真实 provider environment，允许明确转交 Phase 0B.0，但必须成为任何正式 migration 前的硬 Gate。

修复 P1 后重新执行 Round 2；不得因为文档很多就宣布完成。
