# Product Completeness Audit｜产品完整性攻击审计

> 当前状态：**INDEPENDENT AUDIT #1 — CHANGES REQUIRED → REMEDIATED / WAITING FOR FINAL-HEAD CI + RE-AUDIT**  
> 日期：2026-09-02  
> 本文件记录审计历史，不冒充独立最终结论。

## 1. 审计纪律

Phase 0A.6 使用两层审计：实施主线 adversarial self-audit + 未参与设计的独立模型终审。

任何独立 `CHANGES REQUIRED` 后：
- 原 final-head / CI 证据失效；
- 修复真实问题；
- 新 Head 重新跑 CI；
- 再做独立复审；
- 不沿用旧 INTERNAL PASS。

### Final-head evidence rule
仓库文档不写死“当前最终 SHA / CI run number”作为自我证明，因为修改证据文本本身会产生新 Head，使证据立即过期。

最终精确证据只记录在 PR / Issue 审计记录中，并必须满足：

> **审计时 PR 的 actual latest Head SHA = 成功 CI 所验证的 commit SHA。**

如果 Head 再变化，原 CI 自动失效，必须重新验证。

---

## 2. Independent Audit #1｜CHANGES REQUIRED

独立模型重新读取 PR #13、Issue #11/#12、changed files、实际 diff 和当时 CI 后给出：

`CHANGES REQUIRED`

确认 PR Draft/Open、docs-only、无 Phase 0B 越界，但存在三个 P1 blocker。

### P1-01｜Teaching Fact Gate 跨事实源不一致
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

已同步 Auth/Data/Commands/Product/Role/Initial Diagnosis/Teacher Assignments/Lesson；管理员授权不能 bypass；inactive/archived 有负向测试。

**REMEDIATED — WAITING FOR RE-AUDIT。**

### P1-02｜Profile 停用后的 Case Action 规则冲突
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

恢复 active 前重建 owner + pending primary Action。

`CASE_WORKFLOW_TEMPLATES.md` 已同步 suspended exception。

**REMEDIATED — WAITING FOR RE-AUDIT。**

### P1-03｜Archive / Return 状态机未定义
最终冻结：

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
- reactivate 前完整 reconciliation；
- Student merged 是终态。

已同步 Product/Data/Commands/Glossary/Governance/Teacher Assignments/Case Workflow。

**REMEDIATED — WAITING FOR RE-AUDIT。**

---

## 3. 同类旁支扫尾

独立审计修复过程中继续检查并统一：
- Lesson start / complete / in-lesson facts 全部使用七项 Teaching Fact Gate；
- active teacher assignment 必须匹配 active Profile；
- Initial Diagnosis admin authorization 不绕过 Gate；
- Initial Diagnosis Baseline Snapshot = **P2 Pilot validation**，不是 Phase 0B.0 migration blocker；当前不建 `initial_diagnoses`；
- Governance 明确 archive/unarchive/reactivate 与 merged terminal；
- inactive/archived Profile 的 Today / teaching write / Lesson 负向场景。

---

## 4. 仍未执行但被正确隔离的 Phase 0B.0 P0 Gates

这些不是 Phase 0A.6 文档缺陷，必须用真实 backend environment + 虚构数据执行：

1. **Auth Identity Portability**：Supabase / CloudBase identity physical strategy；
2. **Revoked Session / Old Token Security**：signOut/reset/disabled 后旧 Access Token 立即失去学生业务访问。

在它们通过前禁止正式 business migrations。

---

## 5. Scope 结论

Phase 0A.6 只允许 Foundation / product documentation 与必要领域事实源修订。

最终合并前必须重新证明：
- changed files 仍全部在允许的 docs scope；
- 没有 production migration / RLS / Auth / real CRUD；
- 没有真实 Student/Guardian data；
- 没有 Phase 0B implementation。

---

## 6. 当前待办

1. 修复后的 actual latest PR Head 对应正式 CI 全成功；
2. 核关键 steps：packages / lockfile / format / analyze / tests；
3. PR / Issue #12 记录精确 final Head/CI；
4. 独立模型重新读取 latest PR、diff、Issue #11/#12、CI；
5. 最终只接受：

`PASS — READY FOR MERGE`

或继续 `CHANGES REQUIRED`。

---

## 7. 当前 Verdict

**REMEDIATED — NOT YET READY FOR MERGE**

三项已知 P1 已修复，但修复后的最终 Head CI 与独立复审尚未共同证明通过。
