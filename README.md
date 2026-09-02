# 学情闭环 Xueqing

> 面向教培机构的教学协作与学生成长闭环系统

## 当前状态

**Foundation v0.3｜Final Audit / Squash Merge 已完成**

产品边界、核心数据模型、Auth / 权限、安全、本地存储、零成本云端开发、恢复与运行风险已经完成正式开发前的总审计。

**Phase 0A｜Flutter Windows + Android Bootstrap 已建立工程基线，并已取得双平台原生构建证据。** 当前实现位于 `phase0/flutter-bootstrap`，继续更新 Draft PR #4；`main` 不接收本阶段直接 push。

当前仓库已经包含正式 Flutter 工程入口、Android / Windows platform project、typed environment config、App bootstrap、内置 Navigator 路由、轻量 Theme / responsive foundation、错误 / 加载兜底、测试基线与轻量 CI。

### Phase 0A 当前执行证据

最初的 Work Linux 容器缺少 Flutter / Dart / Android SDK，因此该容器中的 `command not found` 只表示**该执行环境不可用**，不能当成项目构建失败。

最终使用 GitHub Actions 的真实工具链完成验证：

- Flutter `3.47.1` / Dart `3.13.1`；
- 轻量 CI run `33606400363`：`flutter pub get`、lockfile consistency、format、analyze、test 全部 **PASS / EXECUTED**；
- 平台 build run `33606216237`：Android `flutter build apk --debug` **PASS / EXECUTED**，生成 `build/app/outputs/flutter-apk/app-debug.apk`；
- 同一平台 build run：Windows `flutter build windows --debug` **PASS / EXECUTED**，生成 `build\windows\x64\runner\Debug\xueqing.exe`。

普通 PR CI 只保留 Linux 轻量检查；Android / Windows 原生 build workflow 在本次 milestone 验证后改为手动触发，避免每次 commit 重复消耗 native runner。

详见 `docs/PHASE0A_EXECUTION_RECORD.md`。

### Phase 0A 尚未实现

- Supabase、Auth、RLS、Realtime、secure Session 与 encrypted draft；
- Student、Learning Case、Evidence、Intervention、Assessment、Lesson、Today 等正式业务功能；
- 最终 UX/UI、正式导航信息架构、Dashboard、统计或 AI 页面；
- Production signing、发布渠道与真实机构网络 / 真机体验验证。

当前 GitHub 仓库已经是 **Private**，Wiki 与 Template repository 已关闭。用户明确选择暂不设置 Actions zero-overage budget；这是已知并接受的账户级计费风险，不再作为 Foundation / Phase 0A 阻塞项，因此 CI 必须继续保持轻量、避免重复 native build、禁止 larger runner。

> 在 Phase 0 的权限、安全、恢复、网络与合规 Go / No-Go 通过前，只允许使用虚构或严格脱敏数据，不录入真实学生、家长或教师隐私材料。

---

## 一句话定位

**不是把 Excel 搬进软件，而是让机构把“发现问题 → 干预 → 验证 → 下一步”变成多人共享、可追溯、低负担的日常教学闭环。**

系统始终回答三个问题：
1. 学生现在最需要解决什么？
2. 老师下一步做什么？
3. 前一次教学是否有证据证明有效？

---

## V1 教师端

只做 4 个核心入口：
- **今日**：到期 / 逾期行动、待验证、重点事项；
- **学生**：连续主档案、当前重点、时间线；
- **课程**：快速开始 / 完成真实教学记录；
- **学情**：Case、Evidence、Intervention、Assessment、Next Action。

家校和报告进入 V1.1。

V1 不做收费 / 课消 / 招生 CRM、完整排课、大型题库、成绩预测、学情健康分、家长 / 学生独立 App、AI 自动正式诊断、复杂 offline-first / CRDT。

---

## 学情 Case

```text
new → confirmed → intervening → pending_verification → stable → closed
```

- `new`：课堂 10–20 秒快速捕捉；
- `reopen`：受控命令 / 事件，不是第七个状态；
- assessment passed 不自动等于 stable / closed。

### 正式 Case 永远有下一步

- `new` 可以没有 action；
- `confirmed / intervening / pending_verification / stable` **必须始终有一个 pending primary action**；
- 暂缓 / 观察使用 `review` primary action；该 review 必须有 `due_at`；
- `pause_reason` 只解释原因，不代替下一步；
- `closed` 不存在 pending primary action。

这样问题不会因为“先观察”永久从 Today 消失。

---

## 一份连续学生主档案

同一机构，一个真实学生只有一个 Student。

升年级、换老师、换班 / 校区都保存历史：
- `student_enrollments`
- `student_teacher_assignments`
- `student_staff_assignments`

任课教师关系与班主任 / 学管关系分开，不用一个 teacher_id 覆盖历史。

---

## 时间与“今日”

系统事件时间保存 UTC；机构业务日期由 `organizations.time_zone`（IANA timezone，例如 `Asia/Shanghai`）统一解释。

以下都按机构时区计算，而不是相信教师手机 / 电脑当前时区：
- Today；
- action 到期 / 逾期；
- lesson 属于哪一天；
- 周度 / 阶段统计；
- report period。

V1 暂不做 campus 独立时区。

---

## V1 账号与权限

为了保持零额外付费，V1 不把 SMTP / Email OTP / SMS / 域名作为登录硬依赖。

```text
org_admin provision_member
    ↓
Auth User + membership(onboarding)
    ↓
强随机临时密码 + onboarding_expires_at
    ↓
教师登录，只能进入账号接管
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
+ JWT session_id 仍对应 live auth.sessions
+ membership = active
+ organization
+ role / capability
+ student / subject assignment（如需要）
```

因此被撤销的旧 Access Token 即使自身尚未到 `exp`，也不能继续读取学生业务数据。

reset 必须**先 membership → onboarding，再更新 Auth 临时密码**。

临时密码：强随机、短有效期、只显示一次、不进 DB / log / audit / GitHub；如果成功响应丢失，不找回旧明文，而是 reissue 新凭据。

### V1 身份边界

数据库支持多个 organization，但同一个 Auth User 在 V1 同一时点最多一个 `onboarding / active` membership。未来若确需跨机构同账号，再先升级为中央身份恢复 / OTP / SSO 等不会让单一机构管理员控制全局 credential 的方案。

详见 `docs/AUTH_AND_PERMISSIONS.md`。

---

## 客户端本地安全

### Session
Production 不能把 `supabase_flutter` 默认 Session 持久化直接当最终安全方案。Phase 0 使用 custom `LocalStorage` + Windows / Android OS secure storage。Password 永不本地保存。

### Startup Gate
只有在 Session validity / refresh、live Session、active membership、current organization 全部解析后，App 才挂载业务 Shell；失效 Session 不得先闪现学生页面。

### Draft
需要跨重启恢复的敏感草稿：
- encrypted at rest；
- key 在 OS secure storage；
- user / organization 隔离；
- TTL；
- sync 成功后删除；
- logout / account switch / disabled 有明确清理；
- 不存 Password / Token。

本地草稿只用于防止老师白填，不是第二份正式数据库。

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
        live Session + RLS
                │
                ▼
PostgreSQL

高权限 / 跨系统：Edge Functions
数据库事务命令：Database Functions
GitHub：source / docs / migrations / tests / PR / CI
```

Flutter 只持有客户端 Publishable Key。Secret / service_role / DB password / backup credential 不进入客户端或 GitHub。

V1 不在学生敏感业务表默认启用 Realtime，也不让业务正确性依赖 Realtime。

---

## 零额外付费开发

```text
ChatGPT Project + Work / Luna
→ Private GitHub + Free Actions
→ Supabase Local CLI
→ Free Remote Development
→ Free Production Pilot
```

原则：
- 一个可验收目标通常一条 Work 会话 + 一个 branch / PR；
- GitHub 是源码事实源；
- migrations 是数据库结构事实源；
- Agent 没真实执行命令时必须明确“未执行 / 未验证”；
- Luna / Max 高推理优先 RLS、migration、Auth / Session、事务、并发、安全和 Milestone 终审；
- 机械 UI、改名、重复 CRUD 不无脑使用 Max；
- 包含额度用完等待重置，不购买 extra credits；
- Actions zero-overage budget 当前未设置，这是用户明确接受的账户级风险；
- 普通 PR 只跑轻量 Linux 检查，Windows / Android native build 只在 milestone / release / 手动执行；
- Work / Codex 禁止直推 main，使用 Draft PR + 执行证据 + 人工合并。

详见 `docs/ZERO_COST_CLOUD_DEVELOPMENT.md`。

---

## Region / 实际网络

Production region 不提前拍脑袋决定。

创建 Production 前必须用仅含虚构数据的 Remote Development，在真实机构场景测试：
- 机构 Wi-Fi；
- 普通移动网络；
- **无代理 / VPN**；
- Auth；
- Data API；
- Storage；
- Edge Functions；
- 网络切换与恢复。

不合格就换 Dev region 重测，结论稳定后再创建 Production。真实未成年人数据的数据驻留 / 跨境合规另外评估；region 选择本身不是合规证明。

---

## 备份 / 恢复

Free Pilot 不把“有 SQL 文件”当成恢复能力。

完整恢复至少考虑：
- `roles.sql`
- `schema.sql`
- `data.sql`
- 必要 migration history
- Auth user / identity 按当时官方流程恢复并实际登录验证
- Storage objects + manifest
- Auth / Realtime / Extensions / Edge Functions / Secret 名单 / Project config checklist
- 加密 off-site backup
- **真实 restore drill**

新 Supabase Project 的 JWT / API 配置可能变化，旧 Token 不应被假定继续有效；恢复后重新登录是可接受的安全默认。

Pilot 默认目标 RPO ≤ 一个教学日；如果机构不能接受这个恢复点，0 元 Production 方案不合格，应重新评估基础设施。

详见 `docs/DISASTER_RECOVERY.md`。

---

## 开源经验

参考但不直接 fork：
- Flutter 官方 `flutter/samples/compass_app`：多环境、Repository / Service、测试；
- `supabase/supabase-flutter`：Local stack、测试、custom LocalStorage；
- AppFlowy：真实 Flutter 跨平台、隐私、发行；
- Frappe Education / Gibbon：教育实体、历史关系、角色、长期模块化。

只借模式和踩坑经验，不把 Xueqing 做成大型学校 ERP。

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
- `docs/FOUNDATION_FINAL_AUDIT.md`
- `docs/PHASE0A_EXECUTION_RECORD.md`
- `docs/ROADMAP.md`
- `AGENTS.md`

### 外部经验
- `docs/OPEN_SOURCE_REFERENCES.md`

---

## Foundation 冻结后的正确顺序

1. Foundation v0.3 已完成最终审计并 **Squash merge 到 `main`**；
2. Phase 0A 完成 Flutter 工程、轻量 CI 与 Android / Windows 原生构建验证；
3. 进行 **Phase 0A 最终审计 → Phase 0A.5 UX/UI Design Foundation**；
4. 初始化 Local Supabase migrations / fake seed / RLS tests；
5. 实现 `organizations.time_zone` 和最小 Organization / Membership schema；
6. 完成 secure Session + Startup Gate + encrypted draft Spike；
7. 建 Free Remote Development，完成无代理真实网络 / Region Spike；
8. 完成 provision / onboarding / global sign-out / live-session / reset Spike；
9. 完成 DB + Auth + Storage recovery drill；
10. 再进入 Organization → Student → Learning Case → Lesson / Today 的业务开发。

**从这里开始，提高质量的主要方式应该是 Phase 0 的真实执行证据，而不是继续无限增加 Foundation 文档。**
