# 产品蓝图

## 1. 定位

**学情闭环（Xueqing）｜机构教学协作与学生成长闭环系统**

不是 Excel 网页化，也不是收费/排课/招生 ERP。核心是把真实教学事实变成连续、多人协作、可验证、能指导下一次教学的学生成长记录。

### 北极星

> 老师打开软件后，能否快速知道这个学生下一步做什么，并能用证据判断前一次教学是否有效？

领导方法的高置信骨架：

`学生档案 → 三类问题初诊 → 知识三阶闭环 → 周度跟进 → 顽固问题 → 家校沟通 → 阶段复盘`

Xueqing 不做七张电子表，而把发现—整改—验证—再整改—协同—复盘变成同一事实链。

## 2. 用户

- 任课教师：Today、课前/课中/课后、Case/Action；
- Advisor/班主任：跨学科必要摘要、协调、家校；
- Subject Lead：本科专业 review/治理；
- Academic/Org Admin：成员、scope、assignment、handoff、merge、完整性治理。

不以填写条数/沟通次数做核心 KPI。

## 3. Student / Subject Profile service lifecycle

Student 是机构内唯一真实学生主档案。

Student 与 Subject Profile 都使用：

```text
active → inactive → archived
active ← inactive ← archived
```

- archived 可受控 unarchive 到 inactive；
- 真正恢复服务再 reactivate；
- `merged` Student 是终态。

Subject service state 与 Case resolution 正交：停数学 ≠ 数学问题清零。

### Student concurrency
Student 有 aggregate version。整体停读/回归同时验证 Student + affected Profile/Case versions/current relation set，防止多管理员 stale plan 覆盖。

## 4. People / authorization

```text
Auth Identity
→ Membership
→ Role/Capability
→ Subject Scope (teaching/leadership)
→ Student/Staff Assignment
→ Subject Profile state
→ command permission
```

Teaching scope 不授予全学科学生访问；Student Assignment 决定普通教师具体学生范围。

### Teaching Fact Gate
以下都属于教学事实：
- teaching Evidence；
- Intervention；
- Assessment；
- Lesson teacher 行为；
- **Quick Capture/new Learning Case**。

必须：

```text
live session
+ active membership
+ teacher capability
+ active teaching scope
+ target Profile active
+ legal active Student Teacher Assignment
+ operation permission
```

Advisor/Subject Lead/Admin 的管理身份本身不能 bypass。

## 5. Learning Case

唯一 lifecycle：

```text
new → confirmed → intervening → pending_verification → stable → closed
```

`Assessment passed ≠ stable ≠ closed`。

`reopen` 是 command/event，不是状态。

### Active Profile
formal open Case 必须合法 owner + exactly one pending primary Action。

### inactive/archived Profile
unresolved Case 保留真实 status；tracking suspended；可以无 current owner/primary；退出普通 Today；不能产生 teaching facts/new Lesson/new Case。

## 6. Quick Capture

目标仍是课堂 10–20 秒：student/subject → 一句标题 → optional detail → new Case。

但“快”不等于绕过权限：云端 new Case 必须完整 Teaching Fact Gate。

- Advisor-only 不创建 teaching Case；其非专业记录走 Parent Communication/Observation；
- inactive/archived Profile 拒绝；
- 离线只保留 encrypted draft，恢复同步时重验 Gate。

## 7. Reopen｜复发

只适用于 closed Case 在 active service 下真实复发。

唯一目标：

```text
closed --reopen_case--> confirmed
```

必须有 post-close recurrence Evidence：server 在同一 transaction lock/re-read target Case、解析 latest committed `case_closed` event，并 lock/re-read selected Evidence；每条 Evidence 仍须属于目标 Case、committed/legal usable，且 `observed_at` 严格晚于该最新已提交 event 的 `occurred_at`；`created_at` 晚录不影响合法性。Committed Evidence 为 append-only historical fact，不得普通修改/删除/reparent `case_id`、`observed_at`、`created_at`、author/source attribution 或 provenance；错误通过 correction/superseding/invalidation event 保留原记录。旧 Evidence 不能单独 reopen。任一步 drift/invalidation/version conflict whole rollback；同一 operation_id retry 不重复副作用。另需 legal owner + new primary Action；清 current `closed_at/stable_at`、`reopened_count +1`，历史 close/stable 通过 immutable events 保留。

Profile inactive/archived 时不 reopen；先恢复 service，再由合法 teacher reopen。

## 8. 三类问题 workflow

- knowledge：当堂订正 → 相似题 → 延迟独立验证；
- habit：可观察行为 → 策略干预 → 多场景观察；
- exam_strategy：方法 → 应用 → 限时/模拟迁移 → 独立验证。

三阶是 knowledge 教学语言，不是 schema 三列/状态，也不机械套其他类型。

## 9. Initial Diagnosis

Student → active Subject Profile → legal teacher assignment → 定位/优势 → candidate problems → Evidence → Cases → first Actions。

管理员可以建立关系，不能代教师写教学事实。

独立 initial baseline snapshot 是 P2 Pilot validation；V1 不建平行 `initial_diagnoses` 台账。

## 10. Lesson

Lesson 是实际教学会话，不是完整排课 CRM。V1 所有 teaching writes 依赖 legal active Student Teacher Assignment。`start_lesson` 有分开的 Actor Gate 与 Per-Student Participant Gate：执行 actor 必须有 live active authenticated identity、valid active session、active membership、teacher capability、matching Subject Scope 与 operation permission；每个 participant 另须是 current/legal Student、active Profile，且 actor 对 Student+Subject 有 legal active assignment、organization/subject/Lesson context 一致。live identity/session 不是 Student participant 属性；`lesson_students` 只表示参与事实，不是 authorization source，scope-only 或 self-added participant 一律拒绝。

课中 assignment 被撤销后，新的 Evidence/Intervention/Assessment/Quick Capture 与普通 `complete_lesson` 全部拒绝；有治理权限的 actor 只能 controlled cancel stale Lesson，不能借 cleanup 写教学事实。新教师不能直接接管旧 Lesson，需取消旧 Lesson 后按自己的合法 assignment 开新 Lesson。

课前看重点/Action/待验证；课中记录事实；课后约 60 秒收口。小班最终事务粒度留 Phase 0B.0 Spike，但不能出现非法半状态。

## 11. Student lifecycle transaction

Deactivate/Reactivate 等 multi-Profile command 必须：operation_id + Student expected_version + affected Profile/Case versions + locks + one transaction。

### Reactivate Student
只处理调用前**已经 inactive**的 selected Profiles。

`students.version` 只代表 Student root/current canonical/lifecycle snapshot；deactivate/archive/unarchive/reactivate 成功各 +1 exactly once，merge 时 source/target 各 +1 exactly once。普通 child append/transition 不机械递增 Student.version。

如果 selected Profile archived：命令拒绝；用户先显式独立 unarchive Profile。Reactivate command 不暗中跨事务 unarchive，也不使用未定义 Saga。

## 12. Reliability / exactly-once

High-risk command：

```text
operation_id
+ expected versions
+ locks/revalidation
+ one DB transaction
+ final invariants
+ operation-bound events/audit
+ atomic commit
```

同 operation 重试返回原 committed result；event/audit 不重复。

Timeout response lost → 查询 operation result，不用多个 CRUD 猜测补齐。

## 13. Student duplicate / merge

V1 conservative safe merge，完整矩阵见 `docs/product/STUDENT_MERGE_POLICY.md`。

- same-subject dual Profile；
- conflicting Enrollment；
- dual active Lead；
- current owner/assignee 无法保持合法；

这些全部 BLOCK。管理员先用正常治理命令整理，再重试。

source→merged，不删除；finalized history provenance 保留；target history 通过 merge lineage 聚合。

## 14. Parent Communication

一次实际沟通是 immutable finalized event。Draft 可编辑；outbound 后异步家长 reply 新增 inbound event；电话/面谈同一 interaction 可 conversation snapshot。

Guardian response 经教师判断后才可形成 guardian_report Evidence。家庭配合不是 Guardian-as-Case-Action。

V1 Internal Pilot 在 Student/Case context 提供最小家校；独立工作台 V1.1。

## 15. Stage Review

复用 reports：source_cutoff + content_snapshot + version + finalized_by/time + correction/supersede。

Finalized Report 不随后续 reopen/Evidence 自动改写，也不等于 Parent informed。

## 16. Today / IA

V1 主导航：Today / Students / Lessons / Learning。

Today 只聚合 active service context 的 action/pending verification 等；inactive/archived tracking 不继续冒普通任务。

## 17. Cloud / Provider boundary

Production provider 尚未冻结。Supabase 是 reference candidate；CloudBase 上海和国内自托管路线仍在候选。

Phase 0B.0 在任何正式 business migration 前必须通过：
1. Auth Identity Portability；
2. Revoked Session / Old Token Security；
并验证 Windows/Android、RLS/RPC/Storage/restore/大陆网络。

## 18. V1 不做

- billing/课消/招生 CRM；
- 完整排课；
- 家长 App/微信短信 API 前置；
- AI 自动正式诊断/清零/finalize；
- KPI/学生风险分/教师效能分；
- Realtime correctness dependency；
- offline-first/CRDT；
- unsafe automatic Student merge。
