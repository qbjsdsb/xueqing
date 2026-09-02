# Product Completeness Audit｜产品完整性攻击审计

> 当前状态：**INDEPENDENT AUDIT #2 — CHANGES REQUIRED → REMEDIATED / WAITING FOR FINAL-HEAD CI + RE-AUDIT**  
> 日期：2026-09-02  
> 本文件记录审计历史，不冒充独立最终结论。

## 1. 审计纪律

Phase 0A.6 使用两层审计：实施主线 adversarial self-audit + 未参与设计的独立模型终审。

任何独立 `CHANGES REQUIRED` 后：
- 原 final-head / CI 证据立即失效；
- 只修真实问题；
- 修复形成新 Head；
- 新 Head 重新跑 CI；
- 独立模型重新读取最新事实源与 diff；
- 不沿用旧 INTERNAL PASS / REMEDIATED / CI 结论。

### Final-head evidence rule

仓库文档不写死“当前最终 SHA / CI run number”作为自我证明，因为修改证据文本本身会产生新 Head，使证据立即过期。

最终精确证据只记录在 PR / Issue 审计记录中，并必须满足：

> **审计时 PR 的 actual latest Head SHA = 成功 CI 所验证的 commit SHA。**

如果 Head 再变化，原 CI 自动失效，必须重新验证。

---

## 2. Independent Audit #1｜CHANGES REQUIRED

独立模型第一次重新读取 PR #13、Issue #11/#12、changed files、实际 diff 和当时 CI 后给出：

`CHANGES REQUIRED`

确认 PR Draft/Open、docs-only、无 Phase 0B 越界，但存在三个 P1 blocker。

### IA1-P1-01｜Teaching Fact Gate 跨事实源不一致

最终统一硬定义：

```text
live session
+ active membership
+ teacher capability
+ matching active teaching subject scope
+ target Student Subject Profile = active
+ legal active Student Assignment / controlled validated Lesson relationship
+ operation-specific permission
```

修复：同步 Auth/Data/Commands/Product/Role/Initial Diagnosis/Teacher Assignments/Lesson；管理员授权不能 bypass；inactive/archived 有负向测试。

**状态：REMEDIATED。**

### IA1-P1-02｜Profile 停用后的 Case Action 规则冲突

最终：

```text
Profile active
→ formal open Case 必须 pending primary Action

Profile inactive/archived
→ unresolved Case 保留真实 status
→ tracking suspended
→ 可以无 current primary Action
→ 不进入普通 Today
→ 不产生普通教学事实/新 Lesson
```

恢复 active 前必须重新建立合法 owner + pending primary Action。

**状态：REMEDIATED。**

### IA1-P1-03｜Archive / Return 状态机未定义

Student：

```text
active --deactivate--> inactive --archive--> archived
active <--reactivate-- inactive <--unarchive-- archived
```

Subject Profile 同样。

硬规则：
- archive 只能 inactive→archived；
- unarchive 只能 archived→inactive；
- reactivate 只能 inactive→active；
- active→archived / archived→active 直跳拒绝；
- unarchive 不自动恢复 enrollment/assignment/owner/Action；
- Student merged 是终态。

**状态：REMEDIATED。**

---

## 3. Independent Audit #2｜CHANGES REQUIRED

第二次独立审计重新核对上一轮三个 P1、latest Head/CI 和完整 regression 后，确认上一轮语义修复方向成立，但发现新的 P1：

### IA2-P1-01｜Service lifecycle reconciliation 的事务原子性未冻结

#### 独立发现

原文档同时规定：
- committed active teacher assignment 必须对应 active Subject Profile；
- inactive/archived Profile 不得有普通 pending Action；

但 `reactivate_student_subject_profile` 的顺序描述又写成：

```text
Profile 仍 inactive
→ 先建立 active assignment
→ 先建立 owner / primary Action
→ 最后 Profile active
```

`deactivate` 则反过来可能被理解为：

```text
Profile 仍 active
→ 先提交结束 assignment / Action / owner
→ 最后 Profile inactive
```

如果这些步骤被实现为多次可见 CRUD/多次提交，会产生违反自身不变量的 committed 中间态；任何一步失败还可能留下 partial reconciliation。

#### 被破坏的不变量

正常业务数据库不得 commit：
- inactive/archived Profile + active teacher assignment；
- inactive/archived Profile + ordinary pending primary Action；
- active Profile + formal open Case 无合法 owner/primary Action；
- lifecycle command 失败后只完成一部分 assignment/owner/Action/Profile 变化。

#### 最终修复｜唯一事务语义

生命周期命令的“步骤”现在只表示**单一事务内部 staging/validation 顺序**，不是多次对外提交。

统一规则：

```text
operation_id
+ expected_version
+ permission/entity-state validation
+ one logical business DB transaction
+ stage all target mutations
+ validate final committed-state invariants
+ event/audit
+ atomic commit
```

包括：
- `deactivate_student_subject_profile`
- `archive_student_subject_profile`
- `unarchive_student_subject_profile`
- `reactivate_student_subject_profile`
- Student deactivate/archive/unarchive/reactivate
- teacher reassign/handoff
- subject-scope handoff
- membership business handoff
- merge_students（优先同一 DB transaction）

##### Reactivate
事务开始合法旧状态：Profile=inactive、无 active assignment、unresolved Cases 可无 current owner/Action。

同一事务内部 stage：
- target assignment；
- Case owner；
- primary Actions；
- resumed events；
- Profile=active。

commit 前验证完整 active target invariants；一次 commit。

中间 staging 不对其他 Session 可见，因此不会形成 committed `inactive Profile + active assignment/Action`。

##### Deactivate
同一事务内部 stage：
- Action completion/cancel；
- assignment end；
- owner responsibility end；
- suspended events；
- Profile=inactive。

commit 前验证 inactive target invariants；一次 commit。

中间 staging 不对外提交，因此不会形成 committed `active Profile + 被拆掉一半责任关系`。

#### Failure / timeout
- 任一内部校验/写入失败 → **整个事务 rollback**；
- commit 成功但 response 丢失 → 使用同一 `operation_id` 查询完整 committed 结果；
- 客户端不得使用多个普通 CRUD 猜测补齐；
- 正常结果只能是完整旧状态或完整新状态；
- 发现半状态属于 integrity anomaly / 运维故障，而不是正常工作流。

#### Failure injection
Phase 0B 必须逐点注入：
- assignment staging 后失败；
- owner staging 后失败；
- primary Action 第 1/N 条后失败；
- Profile status staging 后、commit 前失败；
- event/audit 失败；
- commit 成功 response lost；
- Student 多 Profile reconciliation 任一子步骤失败。

修复已同步：
- `COMMANDS_AND_INVARIANTS.md`
- `DATA_MODEL.md`
- `TEACHER_SUBJECT_ASSIGNMENTS.md`
- `RELIABILITY_AND_CONCURRENCY.md`

**状态：REMEDIATED — WAITING FOR INDEPENDENT RE-AUDIT。**

---

## 4. 同类旁支扫尾

当前继续保持：
- Teaching Fact Gate 七项硬条件；
- active assignment 的 active Profile 约束是**committed-state invariant**；
- Initial Diagnosis admin authorization 不绕过 Gate；
- Initial Diagnosis Baseline Snapshot = P2 Pilot validation；
- inactive/archived Profile 不进入普通 Today；
- inactive/archived Profile 不产生教学事实/新 Lesson；
- stopped service 不伪造 Case closed；
- Parent Communication finalized event 不被异步 reply 回写；
- Student/Profile archive 恢复仍为 archived→inactive→active；
- Student merged 仍是身份终态。

---

## 5. 仍未执行但被正确隔离的 Phase 0B.0 P0 Gates

这些不是 Phase 0A.6 文档缺陷，必须用真实 backend environment + 虚构数据执行：

1. **Auth Identity Portability**：Supabase / CloudBase identity physical strategy；
2. **Revoked Session / Old Token Security**：signOut/reset/disabled 后旧 Access Token 立即失去学生业务访问。

在它们通过前禁止正式 business migrations。

---

## 6. Scope 结论

Phase 0A.6 只允许 Foundation / product documentation 与必要领域事实源修订。

最终合并前必须重新证明：
- changed files 全部在允许 docs scope；
- 没有 production migration / RLS / Auth / real CRUD；
- 没有真实 Student/Guardian data；
- 没有 Phase 0B implementation。

---

## 7. 当前待办

1. 修复后的 actual latest PR Head 对应正式 CI 全成功；
2. 核关键 steps：packages / lockfile / format / analyze / tests；
3. PR / Issue #12 记录精确 final Head/CI；
4. 独立模型重新读取 latest PR、diff、Issue #11/#12、CI；
5. 特别重新验证 IA2-P1-01 原子事务/failure recovery；
6. 最终只接受：

`PASS — READY FOR MERGE`

或继续：

`CHANGES REQUIRED`

---

## 8. 当前 Verdict

**INDEPENDENT AUDIT #2 REMEDIATED — NOT YET READY FOR MERGE**

当前已知 P1 已修复，但修复后的最终 Head CI 与下一次独立复审尚未共同证明通过。