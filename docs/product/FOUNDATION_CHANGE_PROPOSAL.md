# Phase 0A.6 Foundation Change Proposal

> 最终领域变更提案。只记录已经 ACCEPT、明确 DEFER、或明确 REJECT/DERIVE 的结论；不授权进入 Production migration。

## 1. ACCEPT｜Role / Subject Scope / Assignment / Profile

- `membership_subject_scopes` 区分 teaching / leadership；
- teaching scope 不授予全部学生；
- active teacher assignment 必须 active membership + teacher + teaching scope + active Profile；
- management-only 不产生 teaching facts。

## 2. ACCEPT｜Subject Profile service lifecycle

```text
active → inactive → archived
active ← inactive ← archived
```

service lifecycle 与 Case resolution 分开；inactive/archived tracking suspended，不伪造 closed。

## 3. ACCEPT｜Student aggregate version / multi-Profile concurrency

`students.version` 必须存在。

Student lifecycle command 同时验证：
- Student expected_version；
- affected Profile expected versions；
- affected Case expected versions；
- current assignment/owner/Action set；
并锁定/重读 rows。任何 drift → stale_plan/version_conflict。

## 4. ACCEPT｜`reactivate_student` 不隐式 unarchive

Selected Profiles 必须在调用前已经 inactive。Archived Profile 必须先由独立用户 command `unarchive_student_subject_profile` 恢复到 inactive。

V1 不定义跨事务 unarchive Saga；未来若要“一键归档回归”另写 ADR。

## 5. ACCEPT｜三类 Case workflow / 六态 lifecycle

Knowledge/Habit/Exam Strategy 使用同一 Case/Evidence/Intervention/Assessment/Action/Event 模型。三阶不是 schema 三列。

## 6. ACCEPT｜Quick Capture 也是 Teaching Fact Gate

Quick Capture/new Case 云端创建必须：live session + active membership + teacher + teaching scope + active Profile + legal relationship + operation permission。

Advisor-only/pure management 不可创建 teaching Case；非专业事实走 Parent Communication/Observation。

## 7. ACCEPT｜`reopen_case` 唯一目标

```text
closed → confirmed
```

要求 active Profile、recurrence Evidence、legal owner、新 primary Action；current closed_at/stable_at 清空，history 通过 events 保留，reopened_count+1。

Inactive/archived Profile reopen 拒绝。

## 8. ACCEPT｜High-risk command exactly-once

- `(org, operation_id)` 唯一 command result；
- lifecycle event：operation_id + stable event key；
- high-risk audit：operation_id + stable audit key；
- duplicate operation 返回原 result，不重复 side effects。

物理 receipt/index 留 Phase 0B migration，但逻辑不变量已冻结。

## 9. ACCEPT｜Student merge conservative matrix

完整事实源：`STUDENT_MERGE_POLICY.md`。

V1 自动 merge 只做 safe reparent/dedupe；同科双 Profile、Enrollment 冲突、双 active Lead/current responsibility conflict 直接 BLOCK，先人工治理再重试。

Finalized history provenance 保留；source merged 不删除。

## 10. ACCEPT｜Lesson

`start_lesson/complete_lesson` 受控；Teaching Fact Gate；小班 transaction boundary Phase 0B.0 Spike。

## 11. ACCEPT｜Parent Communication / Stage Review

家校是 immutable communication events；异步 reply 新 inbound。Report 复用 reports snapshot，不建 stage_reviews 平行表。

## 12. DEFER｜Initial Diagnosis baseline snapshot

V1 不建 `initial_diagnoses` 大表；Pilot 验证是否需要轻量 immutable baseline snapshot。

## 13. DERIVE｜Weekly / stubborn / governance anomalies

不建 weekly_tracking、stubborn_cases、generic anomaly table；从事实派生。未来真实需要工单生命周期再单独设计。

## 14. ACCEPT｜Production provider 尚未冻结

ADR-002 由 ADR-045 supersede/qualify。Supabase 是 reference candidate；CloudBase 上海/国内自托管仍候选。

Phase 0B.0 pre-migration hard gates：
- Auth Identity Portability；
- Revoked Session / Old Token Security。

## 15. REJECT｜Realtime correctness dependency / second Todo / unsafe merge automation

V1 correctness 不依赖 Realtime；不建第二套 staff Todo；不自动猜测复杂 Student merge。

## 16. Foundation 回写范围

已/应同步：PRODUCT、DATA_MODEL、COMMANDS、AUTH、ARCHITECTURE、DECISIONS、USER_FLOWS、Role/Workflow、Reliability/Governance/Audit。

任何后续实现若与这里冲突，先新增 ADR/审计，不得静默改领域语义。
