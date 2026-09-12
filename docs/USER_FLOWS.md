# 核心用户流程

> 页面开发前先确认服务哪个真实流程；不能改善闭环的功能默认后置。

## Flow A｜机构初始化 / 管理员接管

受信任运维 bootstrap org_admin → membership onboarding → 设置新密码 → revoke old sessions → membership active → 强制重新登录。onboarding/old token 无学生业务权限。

## Flow B｜管理员开通成员

org_admin 可直接邀请 teacher，也可提名 org_owner；负责人提名进入 `pending_owner_approval`，只能由现有 org_owner 审批。org_admin 不可创建 org_admin 邀请。邀请撤销由具有机构管理能力的 owner/admin 执行。

## Flow C｜App Startup Authorization Gate

secure local session → refresh/remote validation → live session → active membership → role/scope/assignment → business Shell。

revoked/onboarding/disabled 不能先闪学生页。

## Flow D｜建立 Student

最少身份信息 → duplicate hint → 确认为新 Student → Enrollment → Subject Profiles → teacher/advisor assignments。

姓名不硬唯一；升年级不新建 Student。

## Flow E｜Initial Diagnosis

Student → active Subject Profile → 合法 teacher assignment → 定位/优势 → candidate problems → Evidence → Learning Cases → primary Actions。

管理员可以建立关系并在 Organization Scope 监督初诊过程，但管理身份不能替代 Responsible Teacher 的 Teaching Fact Gate。Organization Scope 如需建立正式 Case，责任必须由 server 解析到合法 active Lead/Assignment；无合法主责时先明确任课关系。

## Flow F｜Quick Capture / 课堂发现新问题

```text
lesson/student page
→ student + subject context
→ 一句标题
→ 一句具体表现
→ new Case
```

### Personal Scope｜本人教学责任

当前成员以本人责任创建云端 Case 时必须：

```text
live session
+ active membership
+ teacher capability
+ active teaching scope
+ active Subject Profile
+ legal active Student Teacher Assignment
+ operation permission
```

因此：
- Advisor-only 不能创建 teaching Case；
- 只有管理角色、没有真实 teaching scope/Assignment 的负责人或管理员不能在 Personal Scope 把自己作为责任老师 Quick Capture；
- Profile inactive/archived 拒绝；
- 无网络时只保留 encrypted local draft，恢复同步时重新验证 Gate。

### Organization Scope｜机构监督发起

org_owner / org_admin 可以从机构视角发起 responsibility-aware new Case，但管理身份只提供监督/命令资格：

- server 必须把 Responsible Teacher 解析到目标 Profile 当前合法 active teaching assignment；
- 默认责任人为 active Lead；
- 如未来允许显式选择 Collaborator，也必须重新验证其当前合法 Assignment；
- 没有 active Lead 时 fail closed，先明确主责老师；
- Case/Event 必须分别保留真实 actor 与真实 teaching responsibility；
- 管理者本人只有在确实拥有该 Profile 的合法 Assignment 时才能成为 Case owner。

目标仍是 10–20 秒，不强迫课中 root cause/taxonomy/三阶全部完成。

## Flow G｜Confirm new Case

new → 最小 Evidence → taxonomy/case type → 合法 owner → pending primary Action → `confirm_case` → confirmed event。

教学上的暂缓使用 `review + due_at`，不能没有下一步。

## Flow H｜一次 Lesson

课前：到期/逾期 Action、pending verification、重点 Case。

课中：完成/调整 Action、Intervention、Assessment、Quick Capture；每次云端写入重新验证 full Teaching Fact Gate。Actor Gate 先验证 `start_lesson` 执行 actor 的 live active authenticated identity、valid active session、active membership、teacher capability、Subject Scope 与 operation permission，再按 Per-Student Participant Gate 逐个验证 Student current/legal、active Profile、actor 的 legal active Student Teacher Assignment 与 context；live identity/session 不是 Student participant 属性。每个 participant 必须通过后才创建 Lesson；`lesson_students` 只表示参与事实，不能自我授权。

课后：汇总事实 → 教师确认状态 → old primary 收口 → new primary → `complete_lesson`。

如果 assignment 在课中被撤销，后续 teaching writes 与 ordinary complete 拒绝；治理 actor 只能 controlled cancel stale Lesson，不能借 cancel 写教学事实。新老师不能直接接管旧 Lesson。

## Flow I｜验证失败

Assessment failed/partial → 不自动 close → 继续 Intervention/原因复盘 → 新 primary Action → Case 继续 intervening/相应合法状态 → 原 Assessment 保留。

## Flow J｜验证通过 → Stable → Closed

passed 只是本次通过 → 教师判断 stable → stable 仍有 review/verify Action → 后续真实稳定 → closed → closed 无 pending primary。

## Flow K｜Closed Case 真实复发

唯一流程：

```text
发现复发线索
→ server lock/re-read Case
→ server resolves latest committed case_closed event
→ 创建/确认 recurrence Evidence
→ validate Evidence.observed_at > close.occurred_at
→ reopen_case
→ closed → confirmed
→ owner + new primary Action
→ 后续实际 Intervention 再进入 intervening
```

recurrence Evidence 必须属于目标 Case，且 source_type 不设白名单；只看事实 observed_at，不看 created_at。旧 Evidence 不能单独 reopen；close A→reopen→close B 时自动使用 close B。客户端不能指定 previous close。

`reopen_case` one transaction：active Profile/full Gate、lock/re-read Case、Case closed、expected Case/Evidence versions or server freshness token、server-resolved latest committed close、lock/re-read selected Evidence 并确认仍属目标 Case且 committed/legal usable、严格 `Evidence.observed_at > latest committed case_closed.occurred_at`、legal owner、新 Action、current timestamps/reopened_count、case_reopened metadata、event/audit、Case.version +1、final invariants、commit；任一步失败 whole rollback并返回 domain conflict/stale_plan/version_conflict。同一 operation_id retry 返回原 committed result，不重复副作用。Committed Evidence 是 append-only historical fact：不得普通修改/删除/reparent `case_id`、`observed_at`、`created_at`、author/source attribution 或 provenance；错误走 correction/superseding/invalidation event，保留原历史。

## Flow L｜单学科暂停 / 归档 / 恢复

```text
active --deactivate--> inactive --archive--> archived
active <--reactivate-- inactive <--unarchive-- archived
```

Deactivate：同一事务收口 assignment/owner/Action + tracking event + Profile inactive；未解决 Case 不 closed。

Unarchive：只 archived→inactive，不恢复教学。

Reactivate Profile：同一事务恢复 assignment/owner/primary Actions + Profile active。

## Flow M｜Student 整体暂停 / 回归

### deactivate_student
Student + 所有 active Profiles 在一个事务 reconciliation；第 N 科失败 → 整体 rollback。

### unarchive_student
Student archived→inactive；Profiles 保持 archived。

### 准备回归
如果要恢复的某 Profile 仍 archived：

```text
先由用户显式执行 unarchive_student_subject_profile
→ Profile 合法停在 inactive
```

### reactivate_student
只接受**已经 inactive**的 selected Profiles。

任何 selected Profile archived → 立即拒绝；命令内部不隐式调用 unarchive、不做跨事务 Saga。

随后 Student reactivate 单事务恢复 enrollment + selected Profiles assignment/owner/Actions/status；第 N 科失败 → 整体 rollback。

如果此前显式 unarchive 成功、后续 reactivate 失败，Profile=inactive 是合法独立 command 结果，不属于部分 reactivate。

## Flow N｜Teacher handoff / 离职 / 退单科

Student Teacher Assignment handoff 与 Case/Action responsibility handoff 是两个不同业务事实。

当前安全流程：

```text
盘点 current Assignment / open Case owner / pending Action assignee
→ 验证接手人 membership + scope + Profile relationship
→ 如果旧老师仍承担 open Case 或 pending Action responsibility：fail closed
→ 先通过显式责任治理/交接处理 Case 与 Action
→ 重新读取最新状态
→ 再执行 Assignment handoff
→ no orphan validation
→ 收口旧 assignment / scope / membership（按对应治理命令）
```

不得因为换老师、退单科或停用成员就静默把历史 Case owner、Action 或历史 actor 整批改成新老师。历史教学事实保留原 actor；任何责任迁移必须留下显式可审计事实。

## Flow O｜网络失败 / timeout

Simple insert：复用 UUID。

High-risk command：复用 operation_id。

如果 response lost：查询 operation result；不得生成新 operation_id 或用多个 CRUD 猜测补齐。

## Flow P｜跨学科查看

本科教师本科详细；管理者 Organization Projection 按机构监督合同读取；无权限不显示成“没有数据”。Personal Projection 不因为机构可见性扩大。

## Flow Q｜重复 Student / Merge

1. 管理员确认 source/target 是同一真实学生；
2. `generate_merge_preview` 由 server/domain logic 生成完整 merge-relevant snapshot；
3. 预览绑定 source/target Student versions、affected Profile/Case versions、Enrollment、Teacher/Staff Assignments、owner、current Actions、target authority 与 BLOCK matrix；
4. 管理员确认这一个 server plan（opaque `merge_plan_token`、完整 expected snapshot/values 或 server fingerprint）；
5. 有 same-subject dual Profile / conflicting Enrollment / dual active Lead /非法 current owner、unresolved mutable Draft、in-progress Lesson 等 → **不能 merge**；
6. 管理员先用 handoff/reassign/Enrollment correction、finalize/cancel Draft、complete/controlled cancel Lesson 等正常治理命令整理；
7. 重新预览并重新确认；
8. `merge_students` 锁 source/target 与所有受影响 rows，server regenerate 当前完整 snapshot；
9. 任何 merge-relevant drift → `stale_plan/version_conflict`、whole rollback、要求重新 preview，不能静默接受 Plan B；
10. 无 drift 且无 BLOCK 时执行 safe reparent/dedupe + record + source→merged；source/target Student.version 各 +1 exactly once，safe reparent Profile.version +1 exactly once；
11. ordinary append-only Evidence/Intervention history 若不改变 merge decision 不单独 stale；
12. finalized history provenance 保留；target history 通过 merge lineage 聚合；
13. response lost 用同 operation_id 查询，不重复迁移/版本递增。

## Flow R｜Parent Communication

Draft → 人工确认 → 现实渠道沟通 → finalized event。

异步家长回复 → 新 inbound event + reply_to，不修改旧 outbound finalized。

Guardian response 经教师判断后才可成为 guardian_report Evidence。

## Flow S｜Stage Review

系统整理 source_cutoff 前事实 → 教师填写专业判断 → finalize snapshot。后续 Case reopen/补 Evidence 不修改旧 report。

## Flow T｜Backup / Restore / Provider Gate

Remote Dev 只用虚构数据。Phase 0B.0 先验证 Auth identity、old-token revoke、RLS/RPC/Storage/restore/国内网络，再冻结 Production provider。

## V1 明确不应出现

- revoked/onboarding/disabled 能读学生数据；
- management-only 在 Personal Scope 把自己当作 Responsible Teacher Quick Capture；
- Organization Scope 绕过合法 Assignment/active Lead 创建无人负责或由管理身份伪装负责的 Case；
- inactive/archived Profile 新 teaching Case/Lesson；
- reopen 新增第七 status；
- passed 自动 stable/closed；
- archive/停科伪造 Case closed；
- `reactivate_student` 暗中跨事务 unarchive；
- Student command 部分学科成功、部分失败作为正常结果；
- Assignment handoff 静默批量改写 Case/Action responsibility；
- unsafe merge 猜测处理双 Profile/双 Lead；
- timeout 后客户端多 CRUD 补状态；
- finalized communication/report 被后来事实回写；
- AI 自动正式诊断/清零/finalize。
