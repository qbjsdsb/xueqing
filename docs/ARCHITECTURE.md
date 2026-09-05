# 系统架构

## 1. V1 架构目标

1. 多机构严格隔离；
2. 多教师共享同一学生事实源；
3. Auth Identity 与 organization membership 分离；
4. revoked Session / old token 不能继续访问学生数据；
5. teacher scope、Student Assignment、Subject Profile service state 共同参与授权；
6. 高风险 lifecycle command 原子、可幂等恢复；
7. 教师高频记录快且不丢；
8. finalized history、actor、merge provenance 可解释；
9. schema 可由 Git migrations 重建；
10. Production provider 在 Phase 0B.0 compatibility gate 后才冻结。

## 2. Provider-neutral 总体结构

```text
┌──────────────────────────────────────────────┐
│ Flutter Client                               │
│ Windows：深度管理   Android：快速记录        │
│ Secure Session Storage + Encrypted Drafts    │
└──────────────┬───────────────────────────────┘
               │
               ▼
       Startup Authorization Gate
               │
        ┌──────┼──────────────────┐
        ▼      ▼                  ▼
      Auth   Data API      Controlled Commands
        │      │             DB Function / Trusted Service
        └──────┴──────────┬───────┘
                          ▼
┌──────────────────────────────────────────────┐
│ Selected PostgreSQL-backed Cloud Provider    │
│ Auth | PostgreSQL/RLS | Storage | Functions  │
└──────────────────────────────────────────────┘

GitHub：source / docs / migrations / tests / PR / CI
```

### 当前候选
- official Supabase APAC/Singapore — reference candidate；
- Tencent CloudBase PG Shanghai — mainland candidate；
- mainland self-hosted Supabase — fallback/portability path。

**Production provider 尚未冻结。** 见 ADR-045。

## 3. 授权链

```text
valid Auth identity/session
→ membership active
→ role/capability
→ subject scope
→ Student/Staff Assignment
→ Subject Profile service state
→ owner/assignee/entity state
→ operation-specific permission
```

缺一层都拒绝。

### Teaching Fact Gate
Teaching Evidence / Intervention / Assessment / Lesson teacher / Quick Capture new Case 还必须：

```text
live session
+ active membership
+ teacher capability
+ active teaching scope
+ target Profile active
+ legal active Student Teacher Assignment
+ operation permission
```

Management-only 不能 bypass。

V1 不存在以 Lesson participant 替代 Student Teacher Assignment 的授权旁路。`lesson_students` 只是实际参与的 business fact；`start_lesson` 创建前每个 participant 都必须已有 legal active Student Teacher Assignment。


## 4. Session revoke security

安全目标固定：signOut/reset/disabled 后 old access token 立即失去学生业务访问。

### Supabase reference
可使用 JWT `session_id → auth.sessions` + membership guard。

### Other provider
必须在 Phase 0B.0 用 old-token API/RLS negative test 证明等价结果；不能只看 SDK signOut UI。

## 5. V1 Auth UX

管理员 provision known member → onboarding → temporary password → user changes credential → revoke old sessions → membership active → forced re-login。

不开放 public self-register；credential 不存 DB/log/GitHub。

接受机构邀请必须在同一事务中锁定并确认目标机构仍为 active；机构已归档时失败关闭，不能创建应用身份、成员关系或角色。

物理 Auth user ID/link strategy留 Phase 0B.0 P0-A。

## 6. Flutter layer

```text
View
→ ViewModel
→ Repository (business API)
→ Service / Provider Adapter
→ Auth/Data/Storage/Functions
```

- ViewModel 不拼任意 status SQL；
- Repository API 使用 domain command；
- provider SDK 只在 adapter；
- Repository/Service 可 fake/test。

建议目录：app/config/routing/theme/startup；core/auth/security/persistence/errors/logging；features/today/students/cases/lessons/communication。

## 7. Startup Authorization Gate

```text
read secure local session
→ remote refresh/validation
→ live-session check
→ active membership
→ roles/scopes/organization
→ business shell
```

Gate 完成前不加载学生页。revoked/onboarding/disabled 留账号状态页。

## 8. Local security

Session 放 OS secure storage 或 provider-independent equivalent；Password 不持久化。

Draft：encrypted at rest、user/org/entity/operation scoped、TTL、sync 后删除、account switch 不串数据。

## 9. Environments

### Local Development
- local/fake PostgreSQL/Auth as feasible；
- migrations/seed/RLS tests；
- reset/reseed。

### Remote Development / Compatibility Spike
- 只用虚构数据；
- 允许分别创建 Supabase/CloudBase 等测试环境；
- 测 Windows/Android Auth、RLS、RPC/transaction、Storage、backup/restore、国内网络。

### Production Pilot
只有 ADR-045 Phase 0B.0 gates 通过后才创建/冻结：
- provider/region；
- identity strategy；
- session revoke implementation；
- private Storage；
- off-site backup/restore。

真实数据不得进入 Compatibility Spike。

## 10. Region / 中国大陆

Region 选择必须基于实际机构 Wi-Fi/移动网络无代理测试 + 数据驻留/合规评估。

Supabase 没有大陆 region；CloudBase 上海是候选；这不代表后者自动满足所有 Auth/session/SDK/security requirements。

## 11. Data API / DB Function / Trusted Service

### Data API
适合授权读取、简单 append、Draft。**Quick Capture 即使是单 insert，也必须由 RLS/command policy执行完整 Teaching Fact Gate。**

集合读取必须使用稳定排序并分页面拉取，不能依赖 PostgREST/Supabase 的单次默认行数上限。当前客户端每页 500 行，每页返回后重新确认登录账号未变化；服务端列表的最终排序字段必须包含唯一 ID，避免并列值跨页时重复或遗漏。

### DB Function / single DB transaction
适合：
- confirm/transition/reopen Case；
- replace primary Action；
- Subject Profile/Student lifecycle；
- reassign/handoff；
- Student safe merge；
- complete Lesson。

High-risk command contract：operation_id + expected versions + locks + final invariant validation + operation-bound events/audit + atomic commit。

### Trusted Service / Edge Function
适合 Auth Admin/Secret/跨系统。Auth +业务 DB 不是同事务域时采用 fail-closed，不假装原子。

## 12. Student aggregate concurrency

`students.version` 只承担 Student root/current canonical/lifecycle snapshot 的 optimistic concurrency；不做所有 child rows 的全局版本号。

成功 root/lifecycle mutation：
- deactivate/archive/unarchive/reactivate：Student.version +1 exactly once；
- merge_students：source.version +1 exactly once、target.version +1 exactly once；
- 同 operation retry 不重复递增。

普通 Evidence/Assessment/Intervention append、普通 Case transition、普通 Assignment current-state change 不机械递增 Student.version；Profile/Case/Assignment 自身 current snapshot/version 或 locked predicate 负责并发检测。Source-only Profile safe reparent 使 Profile.version +1 exactly once；Case 仅在 current mutable snapshot 真正改变时更新。

Student multi-Profile command 必须携带 Student/Profile/Case expected versions 与 current assignment/owner/Action relation snapshot。事务按 deterministic ID 顺序 lock/re-read；任何 merge-relevant drift → stale_plan/version_conflict whole rollback。

Student merge preview 由 server/domain logic 根据完整 merge-relevant snapshot生成，至少绑定 root/Profile/Case versions、Enrollment、Teacher/Staff Assignment、owner、current Action、target authority 与 BLOCK matrix。允许 server-generated opaque merge_plan_token、完整 expected snapshot/values 或 server-generated fingerprint；不新增 merge_plans 表。Execute 时 server 重新生成并与 confirmed plan 比较；相关 drift 必须 stale_plan，要求重新 preview，不能静默接受新 inventory。Existing Case 的非冲突 append-only Evidence/Intervention history 若不改变 current merge decision/matrix/relationship，不单独造成 stale。

## 13. Operation exactly-once

高风险 command 逻辑 operation result 唯一 `(org, operation_id)`。

Command-generated lifecycle event/audit 使用 operation-bound stable keys，重复同 operation 不重复副作用。

Timeout unknown result：查询 operation result；不创建新 operation_id，不由客户端多 CRUD 补齐。

## 14. Student merge

V1 保守 safe merge；完整矩阵见 `docs/product/STUDENT_MERGE_POLICY.md`。

- preview 与 plan binding 必须 server-derived；
- source/target root versions + affected Profile/Case/current relation snapshots 必须在 execute 时重读比较；
- merge-relevant drift → stale_plan/version_conflict + whole rollback + new preview；
- unresolved mutable Draft 与 in-progress Lesson → BLOCK；
- source-only Profile reparent 使 Profile.version +1 exactly once；
- finalized history provenance 保留，target 历史通过 merge lineage 聚合；
- source merged 是 terminal current-business identity。

## 15. Realtime

V1 correctness 不依赖 Realtime。默认 page enter/save/resume/manual refresh；以后启用前必须另做 revoked-session/reconnect/cross-org 安全审计。

## 16. Schema truth / migration gate

正式 schema/RLS/Function/Trigger/Index 全部 Git migrations。

但 **ADR-045 两个 Phase 0B.0 P0 未通过前，不允许写会锁死 Production provider identity/session 物理策略的正式 business migration。**

## 17. Backup / restore

Production 前必须完成：DB schema/data、Storage manifest/objects、配置清单、加密离站、非 Production restore drill。Free ≠ 可恢复/有 SLA。
