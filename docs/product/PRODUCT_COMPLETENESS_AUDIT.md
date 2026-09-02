# Product Completeness Audit｜产品完整性攻击审计

> 当前状态：**INDEPENDENT AUDIT #1 — CHANGES REQUIRED → REMEDIATED / WAITING FOR RE-AUDIT**  
> 日期：2026-09-02  
> 范围：Phase 0A.6 事实源 + Product/Data/Commands/Auth Foundation + 领导 Excel 原型。  
> 本文件记录审计历史，不冒充独立最终结论。

## 1. 审计纪律

Phase 0A.6 采用两层审计：

1. 实施主线的 adversarial self-audit：负责主动找矛盾，但不能给最终 merge verdict；
2. 未参与设计的独立模型审计：最终只能给 `PASS — READY FOR MERGE` 或 `CHANGES REQUIRED`。

任何独立 `CHANGES REQUIRED` 后：
- 原 final-head / CI 证据失效；
- 必须修真实问题；
- 重新形成新 Head；
- 新 Head 重新跑 CI；
- 再做独立复审；
- 不允许沿用旧 INTERNAL PASS。

---

## 2. 内部 Round 1｜CHANGES REQUIRED

内部第一轮曾发现并修复：
- Subject Scope teaching / leadership 不一致；
- Subject Lead/Admin 可能被误读为可伪造教学事实；
- 家校完全放 V1.1 会丢领导闭环；
- Foundation 尚未吸收 0A.6；
- Commands 缺新高风险 workflow；
- Student/Subject service lifecycle 与 Case resolution 混淆；
- Parent Communication follow-up 只有日期没有责任闭环；
- Lesson start / 小班事务边界未显式。

内部修复后进入 Round 2。

---

## 3. 内部 Round 2｜曾 INTERNAL PASS，但不是最终结论

Round 2 又发现并修复：
- Parent Communication finalized 不能成为会继续长大的聊天 row；
- `closed=已清零` 与“服务停止”必须分离；
- Lesson permission 必须要求 active Subject Profile；
- Governance 文档残留第一轮旧结论。

实施主线当时给出：

`INTERNAL PASS — READY FOR INDEPENDENT AUDIT`

随后独立审计证明仍有三项 P1，因此该 INTERNAL PASS **不能作为最终证据**。

---

# 4. Independent Audit #1｜CHANGES REQUIRED

独立模型对原审阅 Head `2207290b329d3cd70737c6b5eb6d6a6a07025bea` 重新读取 PR #13、Issue #11/#12、20 个 docs changed files、diff 和 CI #99 后给出：

`CHANGES REQUIRED`

确认：
- PR Draft/Open；
- docs-only；
- CI #99 当时成功；
- 无 Phase 0B 越界。

但发现以下 P1 blocker。

---

## IA1-P1-01｜Teaching Fact Gate 跨事实源不一致

### 独立发现
部分事实源缺：
- active Subject Profile；
- live session；

Assignment 文档使用“通常要求 Profile=active”；Initial Diagnosis 还可能被误读成 admin authorization bypass。

### 唯一不变量
任何实际教学 actor 写/确认：
- Intervention；
- Assessment；
- 教学型 Evidence；
- Lesson teacher 行为；

必须同时满足：

```text
live session
+ active membership
+ teacher capability
+ matching active teaching subject scope
+ target Student Subject Profile = active
+ legal active Student Assignment / controlled validated Lesson relationship
+ operation-specific permission
```

### 修复结果
已统一到：
- `AUTH_AND_PERMISSIONS.md`
- `DATA_MODEL.md`
- `COMMANDS_AND_INVARIANTS.md`
- `PRODUCT.md`
- `ROLE_WORKFLOW_MATRIX.md`
- `INITIAL_DIAGNOSIS_WORKFLOW.md`
- `TEACHER_SUBJECT_ASSIGNMENTS.md`
- `LESSON_WORKFLOW.md`

并明确：
- active Profile 是硬条件，不是“通常要求”；
- live session 是运行时硬条件；
- Admin/Subject Lead/Advisor 不可 bypass；
- 管理员做初诊治理时必须先建立合法 active Profile + teacher relationship；
- inactive/archived Profile 的教学事实/Lesson 负向测试必须拒绝。

**状态：REMEDIATED — WAITING FOR INDEPENDENT RE-AUDIT。**

---

## IA1-P1-02｜Profile 停用后的 Case Action 规则冲突

### 独立发现
原 `CASE_WORKFLOW_TEMPLATES.md` 无条件表达 confirmed 起必须有 pending primary Action，与 Product/Data/Commands 中 inactive/archived suspended exception 冲突。

### 唯一不变量

```text
Subject Profile = active
→ formal open Case 必须有 pending primary Action

Subject Profile = inactive / archived
→ unresolved Case 保留真实 resolution status
→ current tracking suspended
→ 可以没有 pending primary Action
→ 不进入普通 Today
→ 不允许普通教学事实 / 新 Lesson
```

### 恢复
真正恢复 active 前，仍需跟进的 formal Cases 必须重新获得合法 owner + pending primary Action。

### 修复结果
`CASE_WORKFLOW_TEMPLATES.md` 已新增明确 Service-suspended exception，并与 Product/Data/Commands/Glossary/Governance 一致。

**状态：REMEDIATED — WAITING FOR INDEPENDENT RE-AUDIT。**

---

## IA1-P1-03｜Archived Student/Profile 的归档—回归状态机未定义

### 独立发现
原模型声明 active/inactive/archived，但只定义 deactivate/reactivate；archive 后是否可回归、如何回归不明确。

### 最终决策
Archive **可恢复但不能直接恢复教学**。

Student：

```text
active --deactivate_student--> inactive --archive_student--> archived
active <--reactivate_student-- inactive <--unarchive_student-- archived
```

Subject Profile：

```text
active --deactivate_profile--> inactive --archive_profile--> archived
active <--reactivate_profile-- inactive <--unarchive_profile-- archived
```

硬规则：
- archive 只能 inactive→archived；
- unarchive 只能 archived→inactive；
- reactivate 只能 inactive→active；
- active→archived 直跳拒绝；
- archived→active 直跳拒绝；
- unarchive 不自动恢复 enrollment / assignment / owner / Action；
- reactivate 前必须完成完整 reconciliation；
- Student `merged` 是身份终态，不允许 unarchive/reactivate。

### 修复结果
已同步到：
- `PRODUCT.md`
- `DATA_MODEL.md`
- `COMMANDS_AND_INVARIANTS.md`
- `DOMAIN_GLOSSARY.md`
- `INSTITUTIONAL_GOVERNANCE.md`
- `TEACHER_SUBJECT_ASSIGNMENTS.md`
- `CASE_WORKFLOW_TEMPLATES.md`
- 相关 acceptance scenarios。

**状态：REMEDIATED — WAITING FOR INDEPENDENT RE-AUDIT。**

---

# 5. 额外扫尾修复

在处理独立审计时，实施主线继续检查同类旁支残留并统一：

### Lesson
`start_lesson / complete_lesson / in-lesson facts` 均使用完整七项 Teaching Fact Gate；权限变化不能因 Lesson 已启动而被绕过。

### Teacher Assignment
active teacher assignment 必须同时匹配 active membership、teacher capability、active teaching scope、**active Subject Profile**。

### Initial Diagnosis
管理员“允许初诊”不是 bypass；baseline snapshot 明确为 **P2 Pilot validation**，不是 Phase 0B.0 migration blocker，也不预建 `initial_diagnoses` 表。

### Governance
archive/unarchive/reactivate、merged terminal、inactive/archived negative teaching scenarios 已进入治理异常与验收语义。

---

# 6. 当前仍然明确未完成的外部 P0 Gates

以下不是 Phase 0A.6 文档缺陷，而是必须拿真实 backend environment + 虚构数据执行的 Phase 0B.0 pre-migration gates：

## P0-A｜Auth Identity Portability
Supabase / CloudBase Auth identity 物理类型差异，正式 migration 前通过 Spike 冻结方案。

## P0-B｜Revoked Session / Old Token Security
必须证明 signOut/reset/disabled 后旧 Access Token 立即失去学生业务访问。

这两项未执行不允许正式 business migrations；也不能在 Phase 0A.6 文档中伪装成已通过。

---

# 7. 当前待办

当前**不能**宣称 `PASS — READY FOR MERGE`。

还必须：

1. 对修复后的 PR #13 最新 Head 重新做 scope check；
2. 修复后的最终 Head 跑正式 CI；
3. CI 的 pub/lockfile/format/analyze/tests 全成功；
4. Issue #12 / PR 描述同步到同一 final Head；
5. 让独立模型重新读取最新 Head 和实际 diff；
6. 独立复审给出唯一可合并结论：

`PASS — READY FOR MERGE`

如果独立复审仍为 `CHANGES REQUIRED`，继续修复，不自动进入 Phase 0B。

---

# 8. 当前 Verdict

**REMEDIATED — NOT YET READY FOR MERGE**

原因不是仍已知存在 P1，而是修复后的新 Head 尚需最终 CI 与独立复审重新证明。
