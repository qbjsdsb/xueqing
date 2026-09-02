# Student Merge Policy｜重复学生合并策略

> Phase 0A.6 事实源。V1 选择“保守、可解释、原子”的 Student merge；遇到复杂冲突宁可拒绝，也不自动猜测。

## 1. 核心原则

`merge_students(source, target)` 只处理**已经确认是同一真实学生的重复主档案**。

硬规则：
- source != target；
- 同 organization；
- source/target 均不是 merged；
- target 作为保留主档案；
- source 最终 `status=merged`、`merged_into_student_id=target.id`；
- source 不物理删除；
- 历史 actor/finalized snapshot 不改写；
- 整个 V1 merge 是一个业务数据库事务；
- `operation_id + source_expected_version + target_expected_version`；
- 任一冲突未解决 → 整体拒绝/rollback。

## 2. 为什么 V1 不做“万能智能合并”

重复学生可能同时存在：
- 同学期不同 Enrollment；
- 同一学科两个 Subject Profile；
- 两个 active Lead；
- 两组 open Cases / pending Actions；
- finalized Parent Communication / Report；
- 不同 Guardian 记录。

自动判断“哪一边更对”会重写教学历史。V1 的原则是：

> **safe merge 自动做；semantic conflict 明确拒绝，由管理员先用正常领域命令整理。**

## 3. Entity-level merge matrix

| 实体 | V1 safe merge | 冲突时 |
| --- | --- | --- |
| Student 主字段 | target 当前主字段保留；source code/name 等写入 merge metadata/alias（若实现） | 不自动用 source 覆盖 target |
| Enrollment | 完全相同记录去重；互不冲突历史 reparent 到 target | 时间重叠但 grade/campus/term 语义不一致 → BLOCK |
| Subject Profile | 仅 source 有该 subject → 整个 Profile reparent 到 target；仅 target 有 → 保留 target | source 与 target 同时存在同一 subject Profile → **BLOCK V1**，先人工整理 |
| Teacher Assignment | 随被迁移 Profile/student reparent；完全重复关系去重 | 两个 active Lead、角色/时间冲突 → BLOCK，先 handoff/reassign |
| Staff Assignment | 无冲突历史可 reparent/去重 | 同角色当前责任冲突且无法机械判断 → BLOCK |
| Learning Case | 跟随其 canonical Subject Profile；Case ID/status/version 不重写 | 若 Profile 本身冲突则整体 BLOCK |
| Case Action | 跟随 Case；actor/assignee 历史保持 | 当前 assignee 在 target context 不合法 → BLOCK，先 handoff |
| Evidence/Intervention/Assessment/Event | 跟随 Case；历史 actor/time 不改 | 不自动合并两条“看起来相同”的教学事实 |
| Guardian link | `student_guardians` 取并集；相同 guardian_id 去重 | 两个疑似同一但不同 guardian 记录不自动合并身份 |
| Parent Communication finalized | **保留原 source Student 归属作为历史 provenance**；target 历史视图通过 merge lineage 聚合 | 不修改 finalized content/actor/time |
| Parent Communication draft | 可在事务内 reparent target（若权限/recipient 合法） | 非法/冲突 draft → BLOCK 或先取消 |
| Finalized Report | 保留 source provenance；target 历史视图通过 merge lineage 聚合 | 不重写 finalized snapshot |
| Draft Report | 可在事务内 reparent target（source_cutoff/subject 合法） | 冲突 → BLOCK |
| Lesson history | 历史 lesson_student 保留 source provenance；target 历史查询通过 merge lineage 聚合 | 不重写历史 attendance/teacher |
| Current operational pointers | 必须最终全部指向 canonical target 或已结束 | 任何 orphan → BLOCK |

## 4. Same-subject Profile conflict 是 V1 硬阻塞

如果：

```text
source.语文 Profile exists
AND
target.语文 Profile exists
```

V1 `merge_students` 不自动：
- 拼 positioning/strengths；
- 合并两个 Case owner 集；
- 选择哪一个 Lead；
- 合并两个 pending Action 队列。

必须先人工确认并使用受控治理流程整理成一个 canonical Profile，再重试 Student merge。

如果未来确需自动 Profile consolidation，新增独立 ADR/command；不能偷偷塞进 `merge_students`。

## 5. Enrollment conflict

允许：
- 完全相同 Enrollment 去重；
- 不重叠历史区间迁移到 target。

拒绝：
- 同一时间段存在不同 campus/grade/class/term 且无法机械证明只是重复录入。

管理员先修正 Enrollment，再重试。

## 6. Assignment / owner / Action

Merge commit 前必须验证：
- target 不产生多个 active Lead；
- active Profile 的 formal open Case 仍有合法 owner + pending primary Action；
- owner/assignee membership、scope、Profile relationship 合法；
- source 不留下 current operational obligation。

历史 actor 永不改成 target 当前老师。

## 7. Finalized history provenance

Finalized Communication / Report / Lesson history 默认不为了“看起来统一”改写原 student foreign identity。

Target 的历史读取通过 merge lineage：

```text
target Student
+ all merged source Student IDs
→ historical aggregate view
```

因此可以同时回答：
- 现在 canonical Student 是谁；
- 这条历史最初记录在哪个重复档案下。

未来若物理 reparent finalized rows，必须新增 `origin_student_id` 或等价不可变 provenance，并写 ADR；V1 不需要。

## 8. 原子性 / 幂等

单一事务：
1. live governance actor；
2. `operation_id`；
3. source/target expected_version；
4. lock source + target；
5. inventory 全部 merge matrix entities；
6. 检查所有 BLOCK 条件；
7. stage safe reparent/dedupe；
8. 写 merge record、event/audit；
9. source staged→merged；
10. final invariant validation；
11. commit。

任一步失败全部 rollback。

重复同 operation_id 返回原 committed merge result，不重复 reparent/event/audit。

## 9. UI 必须先预览

管理员确认前展示：
- source / target；
- 会迁移哪些 current entities；
- 哪些历史只通过 lineage 聚合；
- 哪些冲突阻塞；
- 需要先完成什么 handoff/reconciliation。

有 BLOCK 时按钮不可执行普通 merge。

## 10. 验收反例

必须证明：
- 同 subject 双 Profile → merge 拒绝；
- 双 active Lead → merge 拒绝；
- conflicting Enrollment → merge 拒绝；
- safe source-only Profile → 原子迁移成功；
- finalized Report/Communication 历史 provenance 保留；
- merge 中途失败 → source/target 全回旧状态；
- response lost + 同 operation_id → 不重复迁移；
- merged source 不可 reactivate/unarchive。
