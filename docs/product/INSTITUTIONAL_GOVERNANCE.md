# 机构治理与异常工作流｜Institutional Governance

> Phase 0A.6 事实源。治理目标是发现会让教学闭环断裂、历史失真、权限失控或数据无法恢复的真实异常；不做教师排名/风险分。

## 1. 治理异常不是 Case status

Case 仍严格六态：

`new → confirmed → intervening → pending_verification → stable → closed`

stale/orphan/stubborn/handoff_needed 等均由事实派生，不新增 status。

## 2. Orphan / current responsibility

Active Profile 必须检测：
- formal open Case owner disabled/失去 teaching scope/assignment；
- pending Action assignee invalid；
- active Profile formal Case 无 primary；
- Lead 唯一冲突；
- scope revoke 后残留 current responsibility。

Inactive/archived Profile unresolved Case 暂无 owner/primary 是合法 suspended state，不算 orphan。

## 3. Teaching Fact integrity

治理必须检测：
- inactive/archived Profile 仍出现 new teaching Case/Intervention/Assessment/Lesson；
- Advisor-only / management-only 创建 Quick Capture；
- operation-bound lifecycle event/audit 重复；
- high-risk command 没有 operation result provenance。

## 4. Whole member disable vs subject-scope exit

`disable_membership_and_handoff`：整人 assignments/owners/Actions/scopes 收口，membership disabled；历史 actor 保留。

`revoke_teacher_subject_scope_and_handoff`：只处理目标 subject；其他学科不受影响。

## 5. Subject Profile service lifecycle

```text
active → inactive → archived
active ← inactive ← archived
```

- deactivate 不伪造 Case closed；
- unarchive 只 archived→inactive；
- reactivate Profile 在单事务恢复 assignment/owner/primary Actions/status；
- archived→active 直跳拒绝。

## 6. Student lifecycle / multi-Profile

Student 也 active/inactive/archived；merged 终态。

### Student aggregate concurrency
治理预览必须绑定：
- Student version；
- affected Profile versions；
- affected Case versions；
- current assignment/owner/Action set。

实际 command 若这些关系已变化，返回 stale_plan/version_conflict，不能覆盖。

### Student reactivate
Selected Profile 必须在调用前已经 inactive。

如果 archived：先由管理员**显式独立** unarchive Profile。`reactivate_student` 不暗中跨事务 unarchive，不使用未定义 Saga。

## 7. Reopen / resume governance

`reopen_case` 只 closed + active Profile：目标 `confirmed`。

Profile inactive/archived 时发现复发线索：
- 保留 Parent Communication/Observation 等来源事实；
- 不直接 reopen；
- 先恢复 service；
- 再由合法 teacher 建 recurrence Evidence + reopen。

Tracking resume 与 Case reopen 是两个不同动作。

Reopen recurrence integrity：server 在 `reopen_case` 同一 logical transaction 内 lock/re-read target Case，解析该 Case 最新已提交 `case_closed` event，并 lock/re-read 每条 selected recurrence Evidence；Evidence 必须仍 committed、合法且属于 target Case，`observed_at` 必须严格满足 `evidence.observed_at > latest committed case_closed event.occurred_at`。旧 Evidence 不能单独 reopen，late entry 只按 observed_at 判断。Evidence commit 后为 append-only historical fact：不得静默修改/删除 `case_id`、`observed_at`、`created_at`、author/source attribution、provenance 或其他 recurrence-relevant 字段；correction 必须保留原 provenance。任一 drift/invalidation/version conflict → whole rollback；同一 operation_id retry 不重复副作用。


## 8. Long-running / repeated failure

由 duration、failed/partial Assessment、reopened_count、多轮 Intervention 等派生。治理推动重新分析/调整，不给学生贴伪科学风险分。

## 9. Quick Capture / new Case governance

长期 new 可以提示 formalize/merge/discard。

创建时硬检查完整 Teaching Fact Gate；Profile inactive/archived 或 Advisor-only 不应进入数据库形成 new Case。

## 10. Duplicate Student / Merge｜V1 保守策略

完整事实源：`docs/product/STUDENT_MERGE_POLICY.md`。

### Safe merge 原则
只有可机械证明不丢语义的关系才自动迁移/去重；任何 semantic conflict 直接 BLOCK。

### V1 BLOCK 至少包括
- source/target 同时存在同 subject Profile；
- overlapping conflicting Enrollment；
- 双 active Lead；
- current owner/Action 在 target context 不合法；
- staff current responsibility 冲突无法机械判断。

管理员必须先用正常 handoff/reassign/Enrollment correction 等治理命令整理，再重试。

### Provenance
- source 最终 merged，不物理删除；
- finalized Parent Communication/Report/Lesson history 默认保留原 source provenance；
- target 历史视图通过 merge lineage 聚合；
- 历史 actor 不改写。

### Atomicity
source/target expected_version + operation_id + locks；所有 safe mutation + merge record + source merged 同事务。任一失败 rollback。

### Merge concurrency / conservative blockers

Preview 由 server 生成并绑定完整 merge-relevant snapshot。Assignment、owner、primary Action、Enrollment、Profile structure、staff responsibility、authority、Student lifecycle 等 drift → stale_plan/version_conflict，要求重新 preview；不能静默接受 Plan B。

V1 unresolved mutable Parent Communication/Report Draft 与 in-progress Lesson 都 BLOCK。Assignment 被撤的 Lesson 走 controlled governance cancel，不由新 teacher 冒充完成。Source-only Profile safe reparent 使 Profile.version +1 exactly once；Student merge source/target root version 各 +1 exactly once。


## 11. Concurrency / integrity anomaly

正常命令只应留下完整旧/新状态。

若发现：
- inactive Profile + active assignment；
- active formal Case 无 owner/primary；
- event/audit duplicate under same operation；
- Student command 只部分 Profiles 改变；

视为 integrity anomaly，阻止继续高风险操作并进入运维修复，不让客户端自动补 CRUD。

## 12. Parent Communication

Case-related follow-up 复用 communicate Action；non-case 用 communication 轻量 follow-up，不建第二套 Todo。

异步家长回复是新 inbound event；如果教学上重要，后续由合法教师判断是否形成 Evidence/Case/Action。

## 13. Stage Review

系统可提示 due，但不强迫数量 KPI。Finalized report 是历史 snapshot，后续 reopen 不回写。

## 14. Attachment / Evidence

Private Storage、object/metadata consistency、orphan objects、retention、backup/restore 都纳入治理。真正个人信息删除走专门治理流程。

## 15. Audit purpose

Audit 用于：
- role/scope/assignment/handoff；
- Student/Profile lifecycle；
- reopen/merge；
- finalized correction；
- high-risk command integrity。

高风险 audit 必须 operation_id + stable audit key；不记录 Password/Token/完整敏感正文，不用于教师绩效评分。

## 16. Governance queue examples

可以展示：
- 3 个 active Profile formal Case 无 primary；
- 2 个 inactive Profile 残留 pending Action；
- 1 个 operation 出现 event/audit integrity mismatch；
- 2 个 duplicate Student merge 被 same-subject Profile conflict 阻塞；
- 4 个家校 follow-up overdue。

每条说明“为什么 + 原始事实 + 处理动作”，不转成红黄绿评分。
