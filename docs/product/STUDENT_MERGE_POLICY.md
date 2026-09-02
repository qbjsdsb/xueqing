# Student Merge Policy｜重复学生合并策略

> Phase 0A.6 事实源。V1 选择保守、可解释、原子、server-authoritative 的 Student merge；复杂冲突宁可拒绝，也不自动猜测。

## 1. 核心原则

`merge_students(source,target)` 只处理已经确认是同一真实学生的重复主档案。

硬规则：
- source != target；
- 同 organization；
- source/target 均不是 merged；
- target 是保留的 canonical Student；
- source 最终 `status=merged`、`merged_into_student_id=target.id`；
- source 不物理删除；
- 历史 actor/finalized snapshot 不改写；
- V1 merge 是一个业务数据库事务；
- `source_expected_version` + `target_expected_version`、`operation_id`、server-derived confirmed merge plan 都必需；这里的两个 expected version 分别绑定 source Student 与 target Student root。
- 任一冲突未解决或 plan stale → 整体拒绝/rollback。

## 2. Student root version 与 child versions

`students.version` 只表示 Student root/current canonical/lifecycle snapshot 的 optimistic concurrency token。它不是 child rows 的全局版本号。

成功 commit：
- `deactivate_student`：Student.version +1 exactly once；
- `archive_student`：Student.version +1 exactly once；
- `unarchive_student`：Student.version +1 exactly once；
- `reactivate_student`：Student.version +1 exactly once；
- `merge_students`：source Student.version +1 exactly once，target Student.version +1 exactly once。

普通 Evidence append、普通 Case transition、Assessment append、普通 Assignment current-state change 不机械递增 Student.version；它们由相关 aggregate/current relation token 检测并发。Duplicate operation 不再次递增。

Source-only Profile safe reparent 到 target 时，Profile 当前 aggregate identity/reference 改变，`Profile.version +1 exactly once`，使旧 Student context 的 Profile snapshot 失效。Case 只有在 status/owner/Action/current relation 等 current mutable snapshot 真正改变时才更新 Case.version；不能对所有 Case 级联 +1。

## 3. Server-derived merge preview

UI 可以请求 `generate_merge_preview(source,target)`，但 preview 必须由 server/domain logic 从完整 merge-relevant snapshot 生成。客户端不能自己 inventory、选择要移动的 rows，或用自己挑选的少量 rows 生成 fingerprint。

每个 preview 至少包含并绑定：

| 区域 | 必须绑定的内容 |
| --- | --- |
| Root | source/target IDs、source.version、target.version |
| Profiles | affected Profile IDs、expected Profile versions、subject identity |
| Cases | merge-relevant Case IDs、expected Case versions |
| Enrollment | relevant IDs、grade、campus、term、interval |
| Teacher Assignments | IDs、roles、active status/interval |
| Staff Assignments | current responsibility set |
| Case responsibility | owner IDs |
| Current Actions | primary/current Action IDs、assignee、status |
| Target authority | relevant membership/scope validity |
| Blockers | same-subject dual Profile、conflicting Enrollment、dual active Lead、invalid owner/assignee、unresolved mutable object、other matrix BLOCK |

Plan binding 不冻结 Phase 0A.6 的具体 API 物理形式。允许：
- server-generated opaque `merge_plan_token`；
- server-returned complete expected IDs/versions/values；
- server-generated deterministic plan fingerprint。

三者都必须由 server 根据完整 merge-relevant snapshot 生成；client 不能自己随意 hash 少量 rows。Phase 0A.6 不新增 `merge_plans` 业务表。

## 4. Merge-relevant drift 与 append-only history

Merge-relevant drift 会改变 safe/BLOCK decision、canonical relationship、Profile structure、owner、active Assignment、primary Action、Enrollment、current staff responsibility、target authority 或 Student lifecycle，必须：
`stale_plan/version_conflict` → whole rollback → 要求重新 preview。不得在事务中重新 inventory 后悄悄接受 Plan B，也不得自动接受新的 server plan。

例如以下在 preview 后发生都必须 stale 或最终 BLOCK：
- new Subject Profile / same-subject dual Profile；
- teacher reassign、owner change、new/replace primary Action；
- Assignment role/status/interval change；
- Enrollment correction；
- target scope/membership revoked；
- Student lifecycle change。

Append-only、非冲突的历史事实（例如 existing Case 普通 Evidence append、Intervention history）如果不改变 current merge decision、BLOCK matrix、canonical Profile/Case follow-up relationship，则不单独造成 stale；server 仍须保留其历史并重新验证归属。任何改变 current snapshot 的事实不属于该例外。

## 5. V1 Merge Matrix

| 实体 | V1 safe merge | V1 BLOCK / 处理 |
| --- | --- | --- |
| Student 主字段 | target 主字段保留；source alias/metadata 可保留 | 不自动用 source 覆盖 target |
| Enrollment | 完全相同去重；互不冲突历史 reparent | 时间重叠且 grade/campus/term 语义冲突 |
| Subject Profile | 仅 source 有该 subject → safe reparent | source 与 target 同 subject 双 Profile |
| Teacher Assignment | safe history reparent/dedupe，active 关系须合法 | 双 active Lead、角色/时间冲突 |
| Staff Assignment | 无冲突历史可 reparent/dedupe | current responsibility 冲突无法机械判断 |
| Learning Case | 跟随 canonical Profile；Case ID/status/version 不重写 | Profile/owner/current relationship conflict |
| Case Action | 跟随 Case；actor/assignee history 保持 | target context 下 assignee/owner 不合法 |
| Evidence/Intervention/Assessment/Event | 跟随 Case；历史 actor/time 不改 | 不自动合并“看起来相同”的教学事实 |
| Guardian link | union + exact duplicate dedupe | 不自动合并疑似同一 guardian 身份 |
| Parent Communication finalized | 保留 source provenance；target 通过 lineage 读取 | 不修改 content/actor/time |
| Parent Communication draft | V1 不 reparent | unresolved mutable draft → BLOCK，先 finalize/cancel/discard/resolve |
| Finalized Report | 保留 source provenance；target 通过 lineage 读取 | 不重写 snapshot |
| Draft Report | V1 不 reparent | unresolved mutable draft → BLOCK，先 finalize/cancel/discard/resolve |
| Lesson history | 保留 source Student/teacher/attendance provenance；target 通过 lineage 读取 | source/target 存在 in_progress Lesson → BLOCK |
| Current operational pointers | 最终全部指向 canonical target 或已结束 | 任一 orphan/无法保持 invariant → BLOCK |

V1 不自动 reparent mutable Parent Communication/Draft Report，也不迁移或接管 in_progress Lesson。先治理，再重新 preview。

## 6. Finalized history provenance

Finalized Communication、Report、Lesson history 不为了“看起来统一”而静默改写原 Student identity。target 历史通过：

```text
target canonical Student
+ merged source lineage
→ historical aggregate view
```

因此仍能回答当前 canonical Student、原始来源 Student、历史 actor 与发生时间。未来若要物理 reparent finalized rows，必须另写 ADR 定义不可变 `origin_student_id` 或等价 provenance；V1 不做。

## 7. Execute `merge_students`

用户确认 server preview 后，command 至少：

1. live governance actor；
2. `operation_id`；
3. 读取并验证已确认的 server plan binding；
4. 以 deterministic order lock source/target；
5. re-read source/target root；
6. deterministic order lock/re-read affected Profiles、Cases、assignments、staff responsibilities、Actions、Enrollment 与 target authority；
7. 重新验证 target membership/scope authority 仍然有效；
8. server regenerate current complete merge-relevant snapshot；
9. 与 confirmed preview plan binding 比较；
10. 任一 merge-relevant drift → `stale_plan/version_conflict`，whole rollback，要求新 preview；
11. 无 drift 时重新检查全部 BLOCK conditions，包括 mutable Draft、in_progress Lesson 与 current owner/assignee 合法性；
12. stage safe reparent/dedupe；
13. source-only Profile reparent 时对应 Profile.version +1 exactly once；
14. 不因 child history append 机械递增 Student.version；
15. 对 Student root：source Student.version +1 exactly once、target Student.version +1 exactly once；
16. 写 merge record、operation-bound event/audit；
17. source staged→merged，target canonical lineage update；
18. final invariant validation；
19. operation result 写入并 atomic commit。

失败 whole rollback；不能在事务中“重新 inventory 后觉得没事”就继续。

## 8. Exactly-once / response lost

同 `operation_id` 的 retry 返回原 committed merge result，不再次：
- reparent/dedupe；
- increment source/target root versions；
- increment Profile versions；
- 写 merge record/event/audit；
- 变更 source/target status。

Response lost 先查询 operation result；不得生成新 operation_id。

## 9. Source terminal semantics

`source.status=merged` 是 terminal current-business identity。source 不得：
- reactivate；
- unarchive；
- 建新 Subject Profile；
- 建新 Assignment；
- 建新 Case；
- 建新 Lesson；
- 执行其他 current business operations。

历史读取通过 target + merged lineage。

## 10. Acceptance / attack scenarios

- Assignment changed after preview → stale_plan；
- Case owner changed → stale_plan；
- New same-subject Profile → stale/BLOCK；
- Enrollment changed → stale/BLOCK；
- New/replace primary Action affecting responsibility → stale；
- ordinary append Evidence not affecting matrix → no automatic stale；
- unresolved mutable Draft → BLOCK before merge；
- in_progress Lesson → BLOCK before merge；
- source-only Profile safe reparent → Profile.version invalidated/+1；
- response lost same operation_id → original result, no duplicate roots/Profile/events/audit/merge record；
- merged source cannot reactivate/unarchive/create current business objects。