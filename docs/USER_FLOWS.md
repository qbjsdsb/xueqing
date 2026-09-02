# 核心用户流程

> 页面开发前先确认服务哪个真实流程；不能改善闭环的功能默认后置。

## Flow A｜机构初始化 / 管理员接管

受信任运维 bootstrap org_admin → membership onboarding → 设置新密码 → revoke old sessions → membership active → 强制重新登录。onboarding/old token 无学生业务权限。

## Flow B｜管理员开通成员

org_admin provision → Auth identity + onboarding membership + roles/scopes → 随机临时密码一次显示 → 可信渠道交付。响应丢失不找回旧密码，reissue 新凭据。

## Flow C｜App Startup Authorization Gate

secure local session → refresh/remote validation → live session → active membership → role/scope/assignment → business Shell。

revoked/onboarding/disabled 不能先闪学生页。

## Flow D｜建立 Student

最少身份信息 → duplicate hint → 确认为新 Student → Enrollment → Subject Profiles → teacher/advisor assignments。

姓名不硬唯一；升年级不新建 Student。

## Flow E｜Initial Diagnosis

Student → active Subject Profile → 合法 teacher assignment → 定位/优势 → candidate problems → Evidence → Learning Cases → primary Actions。

管理员可以建立关系，但不能代教师绕过 Teaching Fact Gate 写教学事实。

## Flow F｜Quick Capture / 课堂发现新问题

```text
lesson/student page
→ student + subject context
→ 一句标题
→ optional detail
→ new Case
```

### 云端创建 Gate
必须：

```text
live session
+ active membership
+ teacher capability
+ active teaching scope
+ active Subject Profile
+ legal active Student Assignment / controlled Lesson relationship
+ operation permission
```

因此：
- Advisor-only 不能创建 teaching Case；
- pure Subject Lead/Admin 不能 Quick Capture；
- Profile inactive/archived 拒绝；
- 无网络时只保留 encrypted local draft，恢复同步时重新验证 Gate。

目标仍是 10–20 秒，不强迫课中 root cause/taxonomy/三阶全部完成。

## Flow G｜Confirm new Case

new → 最小 Evidence → taxonomy/case type → 合法 owner → pending primary Action → `confirm_case` → confirmed event。

教学上的暂缓使用 `review + due_at`，不能没有下一步。

## Flow H｜一次 Lesson

课前：到期/逾期 Action、pending verification、重点 Case。

课中：完成/调整 Action、Intervention、Assessment、Quick Capture。

课后：汇总事实 → 教师确认状态 → old primary 收口 → new primary → `complete_lesson`。

所有教学事实通过 Teaching Fact Gate；网络/重试不重复。

## Flow I｜验证失败

Assessment failed/partial → 不自动 close → 继续 Intervention/原因复盘 → 新 primary Action → Case 继续 intervening/相应合法状态 → 原 Assessment 保留。

## Flow J｜验证通过 → Stable → Closed

passed 只是本次通过 → 教师判断 stable → stable 仍有 review/verify Action → 后续真实稳定 → closed → closed 无 pending primary。

## Flow K｜Closed Case 真实复发

唯一流程：

```text
发现复发线索
→ 创建/确认 recurrence Evidence
→ reopen_case
→ closed → confirmed
→ owner + new primary Action
→ 后续实际 Intervention 再进入 intervening
```

`reopen_case` 原子：
- Profile 必须 active；
- Case 必须 closed；
- expected_version + operation_id；
- `closed_at/stable_at` 清当前快照；
- `reopened_count +1`；
- event/audit exactly once。

### Profile inactive/archived
不能 reopen。

如果此时收到家长回复/观察到线索：先保存 Parent Communication/允许的 Observation；先恢复 Subject service，再由合法教师建立 recurrence Evidence 并 reopen。

**Resume tracking ≠ reopen。**

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

盘点 assignments/owners/pending Actions → 验证接手人 scope/Profile relationship → 单事务迁移 → no orphan → scope/membership 收口。历史 actor 保留。

## Flow O｜网络失败 / timeout

Simple insert：复用 UUID。

High-risk command：复用 operation_id。

如果 response lost：查询 operation result；不得生成新 operation_id 或用多个 CRUD 猜测补齐。

## Flow P｜跨学科查看

本科教师本科详细；Advisor 综合必要摘要；Subject Lead 本 leadership scope；无权限不显示成“没有数据”。

## Flow Q｜重复 Student / Merge

1. 管理员确认 source/target 是同一真实学生；
2. 系统生成 merge preview；
3. 按 `STUDENT_MERGE_POLICY.md` 展示 safe items 与 BLOCK conflicts；
4. 有 same-subject dual Profile / conflicting Enrollment / dual active Lead /非法 current owner 等 → **不能 merge**；
5. 管理员先用 handoff/reassign/Enrollment correction 等正常治理命令整理；
6. 重新预览；
7. `merge_students` 锁 source/target + expected versions；
8. 单事务 safe reparent/dedupe + merge record + source→merged；
9. finalized history provenance 保留；target history 通过 merge lineage 聚合；
10. response lost 用同 operation_id 查询，不重复迁移。

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
- management-only Quick Capture；
- inactive/archived Profile 新 teaching Case/Lesson；
- reopen 新增第七 status；
- passed 自动 stable/closed；
- archive/停科伪造 Case closed；
- `reactivate_student` 暗中跨事务 unarchive；
- Student command 部分学科成功、部分失败作为正常结果；
- unsafe merge 猜测处理双 Profile/双 Lead；
- timeout 后客户端多 CRUD 补状态；
- finalized communication/report 被后来事实回写；
- AI 自动正式诊断/清零/finalize。
