# 学情闭环 Xueqing

> 面向教培机构的教学协作与学生成长闭环系统

## 当前状态

**Foundation v0.3｜Final Audit / Freeze Candidate**

产品边界、核心数据模型、权限、安全、本地存储、零成本云端开发、运行恢复和风险清单已经完成正式开发前的总审计。

**当前仍不是完整可运行 Flutter App。** `lib/` 是占位源码；还没有完成正式 `flutter create`、Supabase migrations、RLS tests 和双平台执行验证。

> 在 Phase 0 安全/恢复/网络 Go-No-Go 通过前，禁止录入真实学生、家长或教师隐私数据。

> `qbjsdsb/xueqing` 当前仍是 **Public**；进入正式开发/真实机构数据前第一步必须改为 **Private**。

---

## 一句话定位

**不是把 Excel 搬进软件，而是让机构把“发现问题 → 干预 → 验证 → 下一步”变成多人共享、可追溯、低负担的日常教学闭环。**

系统始终回答：
1. 学生现在最需要解决什么？
2. 老师下一步做什么？
3. 前一次教学是否有证据证明有效？

---

## V1 教师端

只做 4 个核心入口：
- **今日**：到期/逾期行动、待验证、重点事项；
- **学生**：连续主档案、当前重点、时间线；
- **课程**：快速开始/完成真实教学记录；
- **学情**：case、evidence、intervention、assessment、下一步 action。

家校和报告进入 V1.1。

不做收费/课消/招生 CRM、完整排课、大题库、成绩预测、学情健康分、家长/学生独立 App、AI 自动正式诊断、CRDT/offline-first。

---

## 学情 Case

```text
new → confirmed → intervening → pending_verification → stable → closed
```

- `new`：课堂 10–20 秒快速捕捉；
- `reopen`：命令/事件，不是第七状态；
- assessment passed 不自动 stable/closed。

### 最终行动规则

- new 可以没有 action；
- confirmed / intervening / pending_verification / stable **必须始终有一个 pending primary action**；
- 暂缓/观察使用 `review` action；暂停 review 必须有 `due_at`；
- `pause_reason` 只解释原因，不代替下一步；
- closed 无 pending primary action。

这样任何正式问题都不会因为“先观察”永久消失。

---

## 一份连续学生主档案

同一机构，一个真实学生只有一个 Student。

升年级、换老师、换班/校区保留历史：
- `student_enrollments`
- `student_teacher_assignments`
- `student_staff_assignments`

任课教师关系与班主任/学管关系分开。

---

## V1 账号与权限

零额外付费，不把 SMTP/域名/SMS 作为登录前置：

```text
org_admin provision_member
    ↓
Auth User + membership(onboarding)
    ↓
强随机临时密码 + onboarding expiry
    ↓
教师登录，只能账号接管
    ↓
设置自己的新密码
    ↓
global sign-out 全部 Sessions
    ↓
membership active
    ↓
强制用新密码重新登录
```

普通学生业务授权还要求：

```text
JWT user
+ JWT session_id 仍对应 auth.sessions
+ membership = active
+ organization
+ role
+ assignment
```

所以被撤销的旧 Access Token 即使尚未到 `exp`，也不能继续访问学生数据。

reset 必须**先 membership→onboarding，再更新 Auth 密码**。

临时密码：只显示一次、短有效期、不进 DB/log/audit/GitHub；交付未知时 reissue 新凭据，不保存旧明文。

详见 `docs/AUTH_AND_PERMISSIONS.md`。

---

## 客户端本地安全

### Session
`supabase_flutter` 默认会持久化 Session。Production Phase 0 必须改为 custom `LocalStorage` + Windows/Android OS secure storage。Password 永不本地保存。

### Startup Gate
Flutter 只有在 Session validity / live session / active membership / current organization 解析完成后才挂业务 Shell，避免旧本地 Session 闪现学生页。

### Draft
需要跨重启恢复的学生草稿：
- 加密 at rest；
- key 在 OS secure storage；
- user/org 隔离；
- TTL；
- sync 后删除；
- account switch/logout/disabled 有明确清理策略。

---

## 总体技术方向

```text
Windows / Android Flutter
        │
        ├─ Secure Session Storage
        ├─ Encrypted Drafts
        └─ Startup Authorization Gate
                │
                ▼
Supabase Auth + Data API + Storage
                │
        live session + RLS
                │
                ▼
PostgreSQL

高权限/跨系统：Edge Functions
数据库事务命令：DB Functions
GitHub：source/docs/migrations/tests/PR/CI
```

Flutter 只持有 Publishable Key。Secret/service_role/DB password/backup credential 不进入客户端或 GitHub。

---

## 零额外付费开发

```text
ChatGPT Project + Work/Luna
→ Private GitHub + Free Actions
→ Supabase Local CLI
→ Free Remote Development
→ Free Production Pilot
```

- 一个可验收目标通常一条 Work 会话 + 一个 PR；
- GitHub 是代码事实源；
- Luna Max 优先 RLS/migration/Auth/事务/并发/安全/终审；
- 包含额度用完等待重置，不买 extra credits；
- GitHub Actions budget 开启 **Stop usage when budget limit is reached**；
- Private GitHub Free 没有付费级 branch protection 强制能力，因此 Work/Codex 禁直推 main，靠 Draft PR + 执行证据 + 人工合并；
- Supabase Free：一个 Dev + 一个 Production Pilot。

详见 `docs/ZERO_COST_CLOUD_DEVELOPMENT.md`。

---

## Region / 实际网络

Supabase 当前 APAC 有 Singapore/Tokyo/Seoul 等，没有中国大陆 region，而且 project region 不能原地更换。

创建 Production 前必须：
- Remote Development 使用虚构数据；
- 实际机构 Wi‑Fi；
- 普通移动网络；
- **无代理/VPN**；
- 测 Auth/Data API/Storage/Functions/网络恢复；
- 不合格则换 Dev region 重测；
- 测完再定 Production region；
- 真实未成年人数据另做数据驻留/跨境合规评估。

---

## 备份 / 恢复

Supabase Free 不含付费级自动日备份保障。

Production Pilot 必须有：
- `roles.sql`
- `schema.sql`
- `data.sql`
- 必要 migration history
- Storage objects + manifest
- Auth/Realtime/Extensions/Secrets 等重建清单
- 加密 off-site backup
- **实际 restore drill**

Pilot 默认目标 RPO ≤ 一个教学日；如果机构不能接受，0 元 Production 方案不合格。

详见 `docs/DISASTER_RECOVERY.md`。

---

## 开源经验

参考但不 fork：
- Flutter 官方 `flutter/samples/compass_app`：多环境、Repository/Service、测试；
- `supabase/supabase-flutter`：Local stack、测试、安全存储扩展；
- AppFlowy：真实 Flutter 跨平台、隐私、发行；
- Frappe Education / Gibbon：教育实体、历史关系、角色、长期模块化。

详见 `docs/OPEN_SOURCE_REFERENCES.md`。

---

## 文档导航

### 产品
- `docs/PRODUCT.md`
- `docs/USER_FLOWS.md`
- `docs/EXCEL_TO_PRODUCT.md`

### 架构 / 权限 / 数据
- `docs/ARCHITECTURE.md`
- `docs/AUTH_AND_PERMISSIONS.md`
- `docs/DATA_MODEL.md`
- `docs/COMMANDS_AND_INVARIANTS.md`
- `docs/DECISIONS.md`

### 安全 / 开发 / 运维
- `docs/SECURITY_AND_PRIVACY.md`
- `docs/RISKS_AND_OPERATIONS.md`
- `docs/DEVELOPMENT_WORKFLOW.md`
- `docs/ZERO_COST_CLOUD_DEVELOPMENT.md`
- `docs/DISASTER_RECOVERY.md`
- `docs/ROADMAP.md`
- `AGENTS.md`

### 外部经验
- `docs/OPEN_SOURCE_REFERENCES.md`

---

## Foundation 冻结后的正确顺序

1. **把 GitHub repo 改为 Private**；
2. 审核/合并 Foundation v0.3 PR；
3. 建 ChatGPT Project：`Xueqing｜学情闭环开发`；
4. 正式初始化 Flutter Windows + Android；
5. 初始化 Local Supabase migrations/seed/RLS tests；
6. 完成 secure Session + encrypted draft + Startup Gate Spike；
7. 建 Free Remote Development，完成 region/无代理网络 Spike；
8. 完成 provision/onboarding/global sign-out/live-session/reset Spike；
9. 完成 DB + Storage recovery drill；
10. 再进入 Organization → Student → Learning Case → Lesson/Today 的业务开发。

**现在继续提升质量的主要方式已经不是再写更多理论，而是让 Phase 0 用真实执行结果验证这些假设。**
