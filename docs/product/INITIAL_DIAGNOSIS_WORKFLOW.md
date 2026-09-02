# Initial Diagnosis Workflow｜新生 / 新学科初诊工作流

> Phase 0A.6 领域事实源。Initial Diagnosis 是 Student + Subject scoped 的进入闭环工作流，不建立与 Learning Case 平行的永久“初诊问题表”。

## 1. 目标

教师第一次系统理解某学生某学科，并把真正值得持续跟进的问题转化为 Learning Case + Next Action。

不是招生 CRM、一次性行政表、第二套 Case 台账，也不要求试听课当场填完所有字段。

## 2. 推荐入口

```text
确认 / 建立 Student
→ 建立或恢复 Subject Profile
→ Profile = active
→ 建立合法诊断 teacher relationship
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

初诊中以下全部需要完整 Teaching Fact Gate：
- teaching Evidence；
- Intervention；
- Assessment；
- Lesson teacher behavior；
- **Quick Capture / new Learning Case**。

```text
live session
+ active membership
+ teacher capability
+ matching active teaching subject scope
+ target Student Subject Profile = active
+ legal active Student Assignment
  OR controlled validated Lesson relationship
+ operation-specific permission
```

任何一项缺失都不能写云端 teaching fact/new Case。

### 管理员授权不是 bypass
管理员可以建立/恢复 Profile、assignment、治理关系；但不能以“允许初诊”替代 teacher capability、active Profile 或合法 relationship，也不能直接替老师创建教学 Case。

Advisor-only / pure Subject Lead / Admin-only 的非专业记录应走 Parent Communication 或 Observation（该能力上线后），不能用 Quick Capture。

## 6. Positioning / Strengths

定位是当前教学上下文，不是能力分。Excel 的四档可作为产品语言参考，不急于硬编码不可变 enum。

Strengths 可选，只记录有证据、对教学有帮助的优势，不造“天赋值/潜力分”。

## 7. Candidate Problems / Quick Capture

课堂或试听可 10–20 秒：

```text
student + subject context
→ 一句标题
→ optional detail/evidence
→ new Case
```

但云端创建 new Case 前必须执行 §5 完整 Gate。

- Profile inactive/archived → reject；
- Advisor-only/management-only → reject；
- 无网络 → 只保存 encrypted local draft；同步时重新验证 Gate。

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

Lead 可做主体诊断；Collaborator 可在完整 Gate 下补本人真实 Evidence/Assessment；Subject Lead 可专业 review，但仅 leadership scope 时不能伪造 teaching fact/new Case。

每条事实保留真实 actor；关键 Case command 按 Commands/Role Matrix。

## 12. Lesson / Family

真实试听/诊断可以 Lesson context：Lesson → Evidence / Quick Capture → post-lesson formalize。Lesson 和 Quick Capture 各自写入时都重新验证 Gate。

初诊后可生成家校 Draft，但真实沟通遵守 Parent Communication finalized-event 语义；家校不是初诊完成的强制 blocker。

## 13. Acceptance Scenarios

- 第一次试听只发现一个值得跟进的问题 → 只建一个 Case；
- 根因不确定 → 不编造；
- 同名 Student 已存在 → 复用/查重；
- 新开数学 → Profile active + legal teacher relationship 后才可 Quick Capture/teaching fact；
- Profile inactive/archived + 管理员“允许初诊” → new Case/Intervention/Assessment/Lesson 全拒绝；
- Advisor-only → Quick Capture/new Case 拒绝，可记 Parent Communication/允许的 Observation；
- pure Subject Lead → 可 review，不可伪造 teaching fact；
- Pilot 无人需要首次整体基线页 → 继续不建 snapshot 表。

## 14. 冻结结论

1. Initial Diagnosis 是 workflow，不是第二台账；
2. Student identity / Subject Profile service state 先于教学事实；
3. positioning/strengths 属于 Profile 当前上下文；
4. candidate problem 不等于 formal Case；
5. **Quick Capture/new Case 与其他 teaching facts 使用完全相同的 Teaching Fact Gate**；
6. 管理身份不能 bypass；
7. inactive/archived Profile 不能通过初诊建立 teaching Case；
8. baseline snapshot 为 P2 Pilot validation。
