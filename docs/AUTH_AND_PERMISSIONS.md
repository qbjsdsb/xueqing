# 账号与权限模型

> V1 面向少量已知内部教师。目标：账号接管、机构授权、学科范围、学生分配、Session revoke 与 teaching-fact 权限全部可解释、可测试。

## 1. 授权五层

```text
Auth Identity / live Session
→ Organization Membership
→ Role / Capability
→ Subject Scope
→ Student / Staff Assignment
→ entity state / owner / command policy
```

能登录不等于能读学生数据；前端隐藏按钮不是权限控制。

## 2. Provider status

Production provider 尚未冻结。ADR-045：Supabase reference candidate、CloudBase mainland candidate、自托管 fallback。

Phase 0B.0 pre-migration P0：
1. Auth Identity Portability；
2. Revoked Session / Old Token Security。

## 3. Membership

status：onboarding / active / disabled。

onboarding：可最小 Auth 接管，但普通学生业务全部拒绝；可以预配置 roles/scopes，不等于 active。

disabled：所有学生业务拒绝，历史 actor 保留。

## 4. V1 Auth UX

org_admin provision known member → temporary password once → membership onboarding → user changes credential → revoke old sessions → membership active → forced re-login。

Password/Token/高权限 Secret 不进业务 DB/log/GitHub/Flutter。

## 5. Live Session hard rule

普通学生业务必须同时有：有效 Auth identity + 当前 Session still live + membership active + 后续权限关系。

Supabase `JWT session_id → auth.sessions` 只是 reference；其他 provider 必须 old-token negative test 证明等价。

## 6. Role vs Subject Scope

Roles：org_admin / academic_admin / subject_lead / teacher / student_advisor。

`scope_kind=teaching`：可承担该科 teacher assignment；不自动访问全学科学生。

`scope_kind=leadership`：Subject Lead 本科治理范围；不自动成为教师/owner/teaching actor。

## 7. Student Assignment

普通 teacher 访问具体学生本科数据需要 active `student_teacher_assignment` + active Profile。

Lead：主要责任；Collaborator：协作。Case owner 是责任关系，不是 Role。

Advisor 使用 `student_staff_assignment` 获得综合必要摘要/家校职责，不自动获得学科专业写权限。

## 8. Teaching Fact Gate｜唯一硬定义

以下**全部**属于 teaching facts / teaching Case creation：
- teaching Evidence；
- Intervention；
- Assessment；
- Lesson teacher behavior；
- **Quick Capture / new Learning Case**。

必须同时：

```text
live session
+ membership active
+ teacher capability
+ matching active teaching subject scope
+ target Student Subject Profile active
+ legal active Student Teacher Assignment
+ operation-specific permission
```

### V1 Lesson authorization rule

V1 所有教学写权限必须依赖 legal active Student Teacher Assignment。Lesson 或 `lesson_students` participant 记录只表达实际参与事实，不能替代 assignment、grant temporary permission 或创建 capability/scope。

`start_lesson` 创建前必须为每个 participant 验证完整 Gate；仅有 teaching scope、把 Student 自己加入 participants、或 Lesson 已经 `in_progress` 都不能形成授权。临时代课统一用 time-bounded collaborator assignment（`active_from`/`active_to`），在有效期间按同一 Gate 工作。

### 绝对禁止 bypass
- Advisor-only → 不可 Quick Capture/new teaching Case；
- pure Subject Lead → 不可 teaching facts/new Case；
- Academic/Org Admin-only → 不可 teaching facts/new Case；
- inactive/archived Profile → 即使残留旧 assignment 也拒绝；
- Initial Diagnosis 的“管理员授权”不能替代 legal active Student Teacher Assignment。

如果 Advisor 需要非专业记录：Parent Communication / Observation（该能力上线后），不是 Learning Case。

## 9. Case command permissions

confirm/stable/close/reopen 等关键 command 除 Gate 外还需要 owner/command-specific permission。

`reopen_case`：closed + active Profile；默认由通过完整 Teaching Fact Gate 的合法 Lead/owner-capable teacher 执行。Server 在事务内解析最新已提交 `case_closed` event；recurrence Evidence 必须满足 `observed_at > latest case_closed.occurred_at`。Management-only actor 不能直接 reopen。

## 10. Subject service suspension

Profile inactive/archived：
- 普通 teaching reads/writes 按最小必要原则限制；
- teaching fact/new Case/new Lesson 全拒绝；
- unresolved Case 可保留 history，但不进普通 Today。

reactivate command 恢复 relationship 后才重开教学写入。

## 11. Student lifecycle / merge governance

Student deactivate/archive/unarchive/reactivate/merge 是 governance commands，需要 operation_id、expected versions、locks 与 audit。

Student merge 的 semantic conflict 不由 admin 超权自动猜测；遵守 `STUDENT_MERGE_POLICY.md`。

## 12. RLS / command test matrix

至少：
- teacher scope but no assignment → no detail/new Case；
- Advisor-only Quick Capture → deny；
- pure Subject Lead/Admin teaching fact → deny；
- inactive/archived Profile old assignment → deny；
- closed Case + inactive Profile reopen → deny；
- collaborator non-owner critical command → deny unless explicit policy；
- revoked/reset/disabled old token → deny；
- Org A/B isolation；
- onboarding → no student data；
- Student merged source → no new current business operations。

## 13. Function security

RLS + GRANT + command checks。security invoker 优先；security definer 仅非 exposed schema、fixed search_path、least grants。Provider service/admin Secret 只在可信服务端。

## 14. Historical actor

Handoff/disable/merge/service suspension 不重写过去 Evidence/Intervention/Assessment/finalized snapshot actor。当前责任与历史责任分开。
