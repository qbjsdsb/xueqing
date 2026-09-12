# Initial Diagnosis Workflow｜新生 / 新学科初诊工作流

> Phase 0A.6 领域事实源。Initial Diagnosis 是 Student + Subject scoped 的进入闭环工作流，不建立与 Learning Case 平行的永久“初诊问题表”。v0.3.8 起同时受 ADR-047 与 `docs/RESPONSIBILITY_MODEL.md` 约束。

## 1. 目标

教师第一次系统理解某学生某学科，并把真正值得持续跟进的问题转化为 Learning Case + Next Action。

不是招生 CRM、一次性行政表、第二套 Case 台账，也不要求试听课当场填完所有字段。

## 2. 推荐入口

```text
确认 / 建立 Student
→ 建立或恢复 Subject Profile
→ Profile = active
→ 建立合法 active Student Teacher Assignment
→ 当前定位 / 优势
→ candidate problems
→ 去重与 Evidence 判断
→ formal Cases
→ first primary Actions
```

可以跨多次真实教学会话完成。

## 3. Student identity / duplicate

Student identity 先于初诊；姓名不是唯一键。

疑似重复：提示 → 确认同一人则复用；真正 duplicate 走受控 `merge_students`，其冲突策略见 `STUDENT_MERGE_POLICY.md`。

一个学生开语文/数学只建一个 Student + 两个 Subject Profiles。

## 4. Subject Profile service state

- 不存在：受控建立并在实际教学前 active；
- active：直接进入连续主线；
- inactive：先 `reactivate_student_subject_profile`；
- archived：必须 `unarchive → inactive → reactivate → active`。

初诊不能成为绕过 service lifecycle 的后门。

## 5. 初诊 Teaching Fact Gate｜包含 Quick Capture / new Case

初诊中以下全部属于 teaching facts / teaching responsibility：
- teaching Evidence；
- Intervention；
- Assessment；
- Lesson teacher behavior；
- **Quick Capture / new Learning Case**。

### 5.1 Personal Scope｜本人作为责任老师

当前成员要以本人责任写入上述事实，必须完整满足：

```text
live session
+ active membership
+ teacher capability
+ matching active teaching subject scope
+ target Student Subject Profile = active
+ legal active Student Teacher Assignment
+ operation-specific permission
```

任何一项缺失都不能把当前成员作为 Responsible Teacher 写入云端 teaching fact/new Case。

### 5.2 Organization Scope｜管理者监督初诊

org_owner / org_admin 可以建立/恢复 Profile、scope、assignment，并在 Organization Projection 监督初诊。但管理身份本身不是 Teaching Fact Gate 的替代物。

如果管理者从机构视角发起 new Case：

- 管理身份只提供 supervisor / command capability；
- server 必须把 teaching responsibility 解析到目标 Profile 当前合法 active Assignment；
- 默认 Responsible Teacher 为 active Lead；
- 没有 active Lead 时 fail closed，先明确主责老师；
- Event/audit 记录真实 manager actor，Case owner / Action assignee 记录真实责任老师；
- 管理者本人只有在确实具有该 Profile 合法 Assignment 时才能成为 owner。

因此：

> 管理员不能“代替老师承担不存在的教学责任”，但可以在 Organization Scope 为已经明确的合法责任老师发起责任安全的 Case。

Advisor-only / pure management-only 的非专业记录，如不应进入正式教学 Case，应走 Parent Communication / Observation（对应能力上线后），不能借 Quick Capture 伪造教学责任。

## 6. Positioning / Strengths

定位是当前教学上下文，不是能力分。Excel 的四档可作为产品语言参考，不急于硬编码不可变 enum。

Strengths 可选，只记录有证据、对教学有帮助的优势，不造“天赋值/潜力分”。

## 7. Candidate Problems / Quick Capture

课堂或试听可 10–20 秒：

```text
student + subject context
→ 一句标题
→ 一句具体表现
→ new Case
```

但云端创建 new Case 前必须执行 §5 的责任解析：

### Personal Scope

- 当前成员必须通过完整 Gate；
- Profile inactive/archived → reject；
- 无合法 Assignment → reject；
- 无网络 → 只保存 encrypted local draft；同步时重新验证 Gate。

### Organization Scope

- 只有具备机构监督能力的 org_owner/org_admin 可发起；
- server 默认解析 active Lead 为 Responsible Teacher；
- 无 active Lead → reject，并提示先明确任课关系；
- 管理者可见整个机构不等于这些学生属于其 Personal Projection。

课后再判断 knowledge / habit / exam_strategy / other。一个错题不等于必须 formalize。

## 8. Formalize Case

值得持续跟进 → `confirm_case`。

Active Profile 下至少：
- 清楚问题定义；
- 可解释 Evidence；
- case type/taxonomy；
- legal owner；
- priority；
- first pending primary Action。

证据不足可保留 new 或明确 discard；一次性错误不必变 formal Case。

## 9. Root Cause / first plan

首次不强迫写确定根因。Root cause 是可修正的当前判断，重要变化留 event/audit。

初步整改不写“大段未来计划”，优先：
- strategy direction；
- first primary Action。

## 10. Initial Diagnosis Snapshot

V1 / Phase 0B 不建 `initial_diagnoses` 平行大表，也不把 baseline snapshot 当 Phase 0B.0 Gate。

已有事实源：Student、Profile positioning/strengths、Evidence、Case、Action、Lesson/actor/time。

“第一次整体基线快照”明确为 **P2 DEFER WITH PILOT VALIDATION**；若未来证明真实需要，再做轻量 immutable snapshot/event，不能成为第二套 Case。

## 11. Multi-teacher diagnosis

Lead 可做主体诊断；Collaborator 可在完整 Gate 下补本人真实 Evidence/Assessment；Organization supervisor 可以治理和监督，但不能用管理身份伪造 teaching fact responsibility。

每条事实保留真实 actor；每个 Case/Action 保留真实 Responsible Teacher；关键 Case command 按 Commands/Role Matrix。
