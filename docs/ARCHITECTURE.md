# 系统架构

## 1. V1 架构目标

1. 多机构严格隔离；
2. 多教师共享同一学生事实源；
3. Auth 与机构授权分离；
4. 被撤销 Session 不能继续借旧 JWT 访问学生数据；
5. 教师高频记录快且不丢；
6. 本地 Session/草稿不成为隐私旁路；
7. 历史连续、可追溯；
8. schema 可从 Git migrations 重建；
9. Free Pilot 可恢复、可控成本；
10. 不提前建设微服务、CRDT、ERP 或多登录体系。

---

## 2. 总体结构

```text
┌──────────────────────────────────────────────┐
│ Flutter Client                               │
│ Windows：深度查看/管理   Android：快速记录   │
│                                              │
│ Secure Session Storage + Encrypted Drafts    │
└──────────────┬───────────────────────────────┘
               │
               ▼
       Startup Authorization Gate
               │
        ┌──────┼────────────────────┐
        ▼      ▼                    ▼
 Supabase Auth Data API       Controlled Commands
 Password/Session PostgreSQL   DB Functions / Edge Functions
        │      │                    │
        └──────┴──────────┬─────────┘
                          ▼
┌──────────────────────────────────────────────┐
│ Supabase                                     │
│ Auth | auth.sessions | PostgreSQL | RLS      │
│ Storage | Edge Functions                     │
└──────────────────────────────────────────────┘

GitHub：source / docs / migrations / tests / PR / CI
```

---

## 3. 业务授权链

```text
JWT user_id
  ↓
JWT session_id 仍对应 auth.sessions 行？
  ↓
organization_membership = active？
  ↓
role / capability 合法？
  ↓
student / subject assignment 合法？
  ↓
具体 read/write/admin 操作允许
```

缺任何一层都拒绝。

### 为什么 Session 也要查

Supabase global sign-out 会撤销 Sessions/Refresh Tokens，但旧 Access Token 在 `exp` 前仍可能存在。对学生敏感数据，V1 不接受“等 JWT 自然过期”作为唯一撤销机制。

用非 exposed helper 校验 JWT `session_id` ↔ `auth.sessions`；Phase 0 对性能和越权做实测。

---

## 4. V1 Auth 架构

```text
org_admin provision_member
  ↓
Auth User + membership(onboarding)
  ↓
临时密码 + onboarding_expires_at
  ↓
教师登录，只能账号接管
  ↓
更新自己的新密码
  ↓
global sign-out 全部 Sessions
  ↓
membership active
  ↓
强制重新登录
```

reset：**先 membership→onboarding，再更新 Auth 密码**。

Credential 响应丢失时 reissue 新密码；不持久化旧明文来实现“重复返回”。

---

## 5. Flutter 架构

职责：

```text
lib/
  app/
    config/
    routing/
    theme/
    startup/
  core/
    auth/
    security/
    persistence/
    errors/
    logging/
  features/
    auth/
    today/
    students/
    learning_cases/
    lessons/
```

推荐职责：
- View：渲染/输入；
- ViewModel：页面状态与用户动作；
- Repository：业务 API；
- Service：Supabase/Auth/Storage/Functions/local persistence。

Widget 不直接拼权限/事务/多表 SQL；Repository/Service 必须可 fake/test。

参考 Flutter 官方 `compass_app` 的多环境、Repository/Service、测试，不为“Clean Architecture”制造无业务价值空层。

---

## 6. Startup Authorization Gate

`supabase_flutter` v2 初始化可能先返回本地持久化 Session，不保证它已经远端刷新。

启动顺序：

```text
读取安全本地 Session
→ 检查 expired / refresh
→ 远端 Auth 状态确认
→ live-session 验证
→ active memberships
→ current organization
→ 加载业务 Shell
```

在 Gate 完成前不查询/渲染学生业务。revoked/onboarding/disabled 留在账号状态页。

---

## 7. 本地安全

### Auth Session
Production 使用 Supabase custom `LocalStorage` + OS secure storage。Password 永不持久化。

### Draft
跨重启草稿：
- ciphertext at rest；
- key 在 OS secure storage；
- user/org scope；
- TTL；
- sync 后删除；
- account switch/logout/disabled 有明确清理策略。

本地草稿不是第二业务事实源。

---

## 8. 环境模型

### Local Development
- Supabase CLI；
- fake data/Auth；
- migrations/seed/DB-RLS tests；
- reset/reseed。

### Remote Development
- 一个 Free Project；
- 只放虚构数据；
- Password Auth、Session、Edge Functions、Storage、双端、网络/region测试；
- 可重建。

### Production Pilot
- 第二个 Free Project；
- 真实数据；
- 独立 Auth/Storage/Secret；
- 禁 development seed/reset；
- 只部署评审 migration；
- 定期 off-site DB/Storage backup。

Remote Development 不是 schema 第二事实源。

---

## 9. Region / 中国大陆网络

Supabase 当前 APAC 可选 Singapore/Tokyo/Seoul 等，没有中国大陆 region；project region 不能原地更换。

Production 前必须用 Remote Dev 在实际机构 Wi‑Fi + 普通移动网络 + 无代理/VPN测试 Auth/Data/Storage/Functions。必要时重建 Dev 换 region，确认后再建 Production。

Region 决定数据主要驻留位置，但不是合规证明；真实未成年人数据另做机构合规评估。

---

## 10. 数据库结构事实源

```text
supabase/
  config.toml
  migrations/
  seed.sql
  tests/
  functions/
```

Schema/RLS/GRANT/View/Function/Trigger/Index 正式变化全部进入 migrations。

禁止长期依赖 Dashboard/Table Editor/SQL Editor 的手工状态。

---

## 11. Data API / DB Function / Edge Function

### Data API
适合：
- 授权读取；
- evidence/note 等简单事实追加；
- `new` 草稿；
- 普通查询。

前提：RLS + GRANT + FK/约束正确。

### Database Function
适合同一 Postgres 事务内的多表不变量：
- confirm/reopen/transition case；
- replace primary action；
- complete lesson；
- handoff；
- merge students。

### Edge Function / 可信服务端
适合 Secret/Auth Admin/跨系统：
- provision；
- complete onboarding；
- reset credential；
- 未来邮件/AI/外部集成。

Auth + PostgreSQL 不是一个事务域，必须设计安全失败顺序，不假装 Edge Function 天然原子。

---

## 12. RLS / GRANT / View / Function

业务表：
- RLS 开启；
- 最小 GRANT；
- live session + active membership；
- organization/assignment 检查；
- 高频 policy 列索引。

View：客户端暴露优先 `security_invoker=true`。

Security-definer helper：
- 非 exposed schema；
- `search_path=''`；
- schema-qualified；
- revoke 默认 execute；
- 最小 grant；
- 越权测试。

RLS 只回答“谁能访问”，状态机/多表一致性仍靠约束和业务命令。

---

## 13. Case / Action 架构

Case 生命周期：

```text
new → confirmed → intervening → pending_verification → stable → closed
```

`reopen` 是命令/事件。

行动规则：
- new 可没有 action；
- confirmed/intervening/pending_verification/stable 必须有一个 pending primary action；
- 暂停/观察 = review primary action；暂停 review 必须 due_at；
- pause_reason 仅解释；
- closed 无 pending primary action。

这样 Today 只需要消费 case_actions，不再维护第二套 `next_review_at`。

---

## 14. 保存可靠性 / 并发

```text
教师输入
→ encrypted local draft
→ 提交
→ 云端确认
→ synced
→ 删除 local draft
```

- 未保存/保存中/已保存/失败清晰；
- 简单 insert 重试复用 UUID；
- DB command 使用 operation id；
- credential 响应未知走 reissue，不保存 secret；
- 关键快照 version/expected_version；
- 冲突不静默覆盖。

Realtime 只增强体验。

---

## 15. Storage

Private bucket + `storage.objects` RLS。

建议路径：

```text
{organization_id}/{student_id}/{object_type}/{uuid}.{ext}
```

- 不用姓名；
- signed URL 短时、授权后生成、视作 bearer credential；
- 不进日志；
- 文件类型/大小限制；
- DB metadata 与对象生命周期一致；
- DB backup ≠ Storage backup。

---

## 16. Backup / Recovery

Free Production 至少：
- roles/schema/data DB dump；
- 必要 migration history；
- Storage objects + manifest；
- Auth/Realtime/Extensions/Secrets 等配置清单；
- 加密 off-site；
- restore drill。

Git migrations 不是业务数据备份。详见 `DISASTER_RECOVERY.md`。

---

## 17. GitHub / Work / CI

```text
Work/Codex
→ feature/review branch
→ Draft PR
→ CI / real command evidence
→ human review
→ merge
```

Repo 必须 Private。GitHub Free private 没有付费级 branch protection 强制能力，所以零成本阶段靠 AGENTS + PR + 人工纪律，禁止 Work/Codex 直推 main。

Actions budget 必须设置 Stop usage at limit；重型 Windows/Android build 只在 Milestone/Release。

---

## 18. Windows / Android 职责

### Windows
- 学生全景；
- 深度 case；
- 管理员治理；
- 批量查看；
- 后续报告/教研。

### Android
- 登录/Session；
- Today；
- 学生重点；
- 快速 lesson；
- evidence/intervention/assessment/new；
- 30–60 秒课后记录。

两端共享业务模型，不是简单拉伸同一布局。

---

## 19. 不采用

- 每老师一库人工同步；
- 微服务集群；
- 全系统 Event Sourcing；
- CRDT/offline-first；
- 所有请求 Edge Function；
- 所有业务逻辑 Flutter/Trigger；
- Dashboard 作为 schema 源；
- Password/Magic Link/OTP 多套主登录并存；
- 需要付费 SMTP/SMS 才能登录；
- fork 大型教育 ERP；
- 为 0 元牺牲权限/恢复/隐私。

---

## 20. 技术 Go / No-Go

真实学生数据前：
- migrations 从空库重建；
- live-session/RLS/GRANT/View/Function/Storage tests；
- secure Session storage；
- Startup Gate；
- encrypted drafts；
- onboarding/global sign-out/reset/expiry/reissue；
- region/network tests；
- DB+Storage restore drill；
- GitHub Private + zero-overage budget；
- 安装/升级路径；
- 合规评估。
