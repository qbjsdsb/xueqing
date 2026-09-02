# Product Completeness Audit｜产品完整性攻击审计

> 当前状态：**INDEPENDENT AUDIT #3 — CHANGES REQUIRED → REMEDIATION PREPARED / WAITING FOR NEW HEAD CI + RE-AUDIT**  
> 本文件记录历史，不冒充最终独立 PASS。

## 1. 审计纪律

Phase 0A.6 的任何独立 `CHANGES REQUIRED` 都使此前“final candidate Head/CI”失效。

流程：
1. 接受真实问题；
2. 只修真实问题；
3. 形成新 Head；
4. 新 Head 重新跑 CI；
5. 独立模型重新读 latest Head/diff/Issue/CI；
6. 只接受 `PASS — READY FOR MERGE` 或继续 `CHANGES REQUIRED`。

### Final evidence rule｜PR workflow 的 Head 与 checkout 必须区分

仓库文件不写死最终 SHA/run，避免自我改写导致证据过期；精确证据写 PR/Issue。

对 GitHub `pull_request` workflow：
- `workflow_run.head_sha` 绑定候选 PR Head；
- GitHub Actions checkout 默认可能 checkout `refs/pull/<n>/merge`，即 **candidate Head 与当时 base 合成的 merge commit**；
- 因此该 run 可以作为“这个 candidate Head 与当前 base 的 PR integration checks”证据；
- **不能称为纯 candidate Head checkout**，除非另有 exact-head workflow 明确证明。

Final evidence 必须记录两件事：
1. candidate Head SHA 与 run.head_sha 一致；
2. job 实际 checkout 是 head 还是 PR merge ref，并据实描述。

如果 Head/base 变化导致新的 merge ref，旧 integration run 按项目 gate 重新评估/重跑。

---

## 2. Independent Audit #1｜CHANGES REQUIRED

### IA1-P1-01 Teaching Fact Gate 跨事实源不一致
修复：统一 live session + active membership + teacher + teaching scope + active Profile + legal relationship + operation permission。

### IA1-P1-02 inactive/archived Case Action exception
修复：active Profile formal open Case 必须 primary；service suspended 时 unresolved Case 可无 current primary，不伪造 closed。

### IA1-P1-03 Archive/Return 状态机
修复：active→inactive→archived；恢复 archived→inactive→active；merged terminal。

状态：**REMEDIATED，后续审计继续回归。**

---

## 3. Independent Audit #2｜CHANGES REQUIRED

### IA2-P1-01 Lifecycle reconciliation 原子性
修复：Student/Profile lifecycle、handoff、merge 等业务 DB mutation 采用 one logical transaction；staging 不可见；失败 rollback；response lost 用 operation_id 查询。

状态：**REMEDIATED，后续审计继续回归。**

---

## 4. Independent Audit #3｜CHANGES REQUIRED

第三次独立审计确认此前主要方向成立，并发现六个新的 P1 + 两个 P2。

### IA3-P1-01｜`reopen_case` 缺目标状态/完整 command semantics

**修复决定：**

```text
closed --reopen_case--> confirmed
```

原因：复发已经重新达到正式跟进条件，但 reopen command 本身不虚构 Intervention 已发生。

Command 必须：
- Profile active；
- recurrence Evidence；
- legal owner；
- new pending primary Action；
- clear current closed_at/stable_at；
- reopened_count +1；
- operation-bound event/audit；
- version+1；
- one transaction；
- inactive/archived Profile 前置拒绝。

**状态：REMEDIATED — WAITING FOR RE-AUDIT。**

### IA3-P1-02｜Student lifecycle 缺 Student aggregate version/多 Profile concurrency plan

修复：
- `students.version`；
- Student command 输入 student_expected_version + affected Profile/Case expected versions + current relation IDs；
- deterministic row locks/re-read；
- target membership/scope 同事务重验证；
- drift → stale_plan/version_conflict；
- Student commit 成功 version+1。

**状态：REMEDIATED — WAITING FOR RE-AUDIT。**

### IA3-P1-03｜`reactivate_student` 未定义跨事务 unarchive orchestration

修复：**取消隐式 orchestration。**

`reactivate_student` 只接受调用前已经 `inactive` 的 selected Profiles。任何 selected Profile archived → command 拒绝，用户先显式独立执行 `unarchive_student_subject_profile`。

因此 reactivate transaction 内不调用 unarchive、不需要未定义 Saga；如果未来要一键从 archive 恢复，另写 Saga ADR。

**状态：REMEDIATED — WAITING FOR RE-AUDIT。**

### IA3-P1-04｜Quick Capture Teaching Fact Gate bypass

修复：Quick Capture/new Learning Case 明确纳入完整 Teaching Fact Gate。Advisor-only / pure Subject Lead/Admin 不可创建 teaching Case；其非专业事实走 Parent Communication/Observation。Profile inactive/archived 服务端前置拒绝；离线 Draft 同步时重验 Gate。

**状态：REMEDIATED — WAITING FOR RE-AUDIT。**

### IA3-P1-05｜operation_id 未覆盖 lifecycle event/audit exactly-once

修复逻辑：
- high-risk operation result `(org, operation_id)` 唯一；
- command lifecycle event 必须 operation_id + stable operation_event_key；
- high-risk audit 必须 operation_id + stable operation_audit_key；
- 逻辑 unique `(org, operation_id, key)`；
- duplicate operation 返回原 committed result，不再 append side effects。

物理 receipt/index schema Phase 0B migration 冻结，但 exactly-once 业务语义已冻结。

**状态：REMEDIATED — WAITING FOR RE-AUDIT。**

### IA3-P1-06｜Student merge 只有“有策略”没有 matrix

修复：新增 `STUDENT_MERGE_POLICY.md`，V1 采用 conservative safe merge。

BLOCK：
- same-subject dual Profile；
- conflicting Enrollment；
- dual active Lead；
- target context 下非法 current owner/assignee；
- 无法机械判断的 current responsibility 冲突。

Safe relations 才在 one transaction reparent/dedupe；source→merged；finalized history provenance 保留；target history 通过 merge lineage 聚合。

**状态：REMEDIATED — WAITING FOR RE-AUDIT。**

---

## 5. Independent Audit #3 P2

### IA3-P2-01｜旧 ADR-002 锁死 Supabase

修复：ADR-002 标记 `Superseded / Qualified by ADR-045`；新增 ADR-045，Production provider 延迟到 Phase 0B.0 compatibility gates 后冻结；ARCHITECTURE provider-neutral。

Supabase 继续是 reference candidate，不是 Production 已定事实。

### IA3-P2-02｜CI evidence wording 高于实际 checkout

修复：本文 §1 明确区分 `workflow_run.head_sha` 与 PR merge-ref actual checkout。PR/Issue 的精确 final evidence 在新 Head CI 完成后必须同时记录 candidate Head/run 与实际 checkout 类型，不再称“纯 Head checkout”。

---

## 6. 仍然明确未验证的 Phase 0B.0 P0

1. Auth Identity Portability；
2. Revoked Session / Old Token Security。

它们只能在真实 backend environment + 虚构数据执行，不能靠文档勾选。

---

## 7. Scope gate

Phase 0A.6 允许 docs/Foundation 修订；不允许：
- production migrations/RLS/Auth；
- real Student/Guardian CRUD/data；
- Phase 0B implementation；
- provider lock-in implementation。

---

## 8. 下一次独立复审必须重点攻击

- reopen closed→confirmed 是否所有事实源一致；
- inactive Profile reopen/Quick Capture 是否都拒绝；
- Student version + affected Profile/Case versions/locks 是否足够防 stale plan；
- reactivate_student 是否彻底没有 implicit unarchive/Saga；
- operation event/audit duplicate 是否逻辑上 exactly once；
- conservative merge matrix 是否真的定义 BLOCK/rollback/provenance；
- ADR-002/Architecture 是否不再把 Supabase 当已锁定 Production；
- GitHub CI evidence 是否正确描述 merge-ref checkout。

---

## 9. 当前 Verdict

**INDEPENDENT AUDIT #3 REMEDIATION PREPARED — NOT READY FOR MERGE**

必须等：新 Head → 对应 CI → PR/Issue 准确证据 → Independent Audit #4 或等价最终 re-audit。
