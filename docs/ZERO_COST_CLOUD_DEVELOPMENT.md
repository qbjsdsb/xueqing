# 零额外付费的云端开发方案

> 目标：使用现有 ChatGPT 方案能力 + GitHub Free + Supabase Free，把 Xueqing 做到可测试、可安装、可供少量内部教师 Pilot；不额外购买服务器、SMTP、域名、短信、AI API、CI、Supabase add-on 或 Work/Codex credits。
> **Phase 0B.0 provider / production hard boundary**
>
> 当前仅将 Supabase 视为 V1 reference / preferred implementation candidate；尚未无条件冻结为 production provider。正式 production business migrations、Production Auth/RLS/CRUD 与真实学生/教师/家长数据之前，必须先完成并通过：
> 1. **P0 Gate A — Auth Identity Portability Spike**；
> 2. **P0 Gate B — Revoked Session / Old Token Security Spike**。
>
> 在两项 Gate 之前，只允许用虚构数据进行 provider-specific compatibility/security spike；Spike 不构成 production migration 授权。两 Gate 通过后，才可冻结 provider、region、identity 与 session strategy，再另行执行正式 migrations、Auth/RLS/CRUD 与 Go/No-Go。

“0 元”是当前 Pilot 约束，不是承诺永远不为生产可靠性付费。

## 1. 总体结构

```text
ChatGPT Project：Xueqing｜学情闭环开发
    ├─ Work：研究、实现、PR、复审
    └─ Codex：需要真实终端/build/debug 时使用
              ↓
Private GitHub Repo
    ├─ source / docs / migrations
    ├─ branch / Draft PR / Issues
    └─ GitHub Actions（免费额度 + 克制触发策略）
              ↓
Supabase Local CLI
    └─ schema / RLS / DB tests / fake seed
              ↓
Supabase Free Remote Development
    └─ 虚构数据、Auth/Storage/Functions/网络测试
              ↓
Supabase reference candidate compatibility/security Spike
    └─ 仅虚构数据；不授权 production migration
Gated Production Pilot（未来）
    └─ 仅 P0 Gate A/B + provider/region/identity/session strategy + Go/No-Go 后承载真实数据
```

GitHub 是代码事实源；approved migrations 才是选定 provider 路径的数据库结构事实源；Work 是云端执行上下文，不是唯一真相。

---

## 2. ChatGPT Project

建议：`Xueqing｜学情闭环开发`。

如果要在 Project 内使用 Work，采用当前兼容 Work 的 memory 配置；不要因为追求隔离误用会禁用 Work 的 Project-only memory。

Project Instructions 保持短：

```text
维护 qbjsdsb/xueqing。
每个实现先读 AGENTS.md 和相关 docs。
GitHub 是代码事实源，较大改动使用 branch + PR。
禁止真实学生数据和 Secret 进入仓库。
遵守 V1 范围、RLS、migration、事务、安全存储、恢复和零额外付费约束。
改变关键方向先更新 ADR。
没有真实执行命令时必须明确“未验证”。
```

不要把整套工程规范反复粘进聊天；规范留在仓库。

---

## 3. Work 会话怎么拆

不要一条无限长会话从 Foundation 跑到 V2。

建议：

```text
00-Control-Tower
01-Phase0-Flutter-Bootstrap
02-Phase0-Local-Supabase
03-Auth-Org-Membership
04-Student-Master-Profile
05-Learning-Case-Vertical-Slice
06-Lesson-Today
07-Security-Recovery-Audit
08-Release-Pilot
```

原则：一个可验收目标通常一条 Work 会话 + 一个 PR。

每条会话：
- 开始：读当前 GitHub/AGENTS/相关 ADR；
- 结束：代码落 GitHub、跑能跑的检查、列未验证风险、必要时更新 ADR/Roadmap。

聊天里说“完成”不算完成。

---

## 4. Work / Codex / CI 分工

### Work 优先
- 产品/架构研究；
- GitHub 多文件实现；
- RLS/数据模型评审；
- Issue/PR；
- 代码 review；
- 文档同步；
- 风险审计。

### Codex / CI 优先
- `flutter analyze/test`；
- `supabase db reset`；
- DB/RLS/function tests；
- Android/Windows build；
- 本地运行和调试。

当前 Work 若能真实执行，也可直接做；原则是**不给未执行工作伪造执行证据**。

Work/Codex 使用现有 ChatGPT 方案内 agentic 用量；达到包含额度后等待重置，不购买 extra credits。

---

## 5. Luna / “Luna Max”策略

仓库不把“LunaMax”写成一个固定 API model id。这里把 UI 中的 Luna + Max reasoning 理解成高推理执行档。

适合 Max：
- RLS/多租户；
- destructive migration；
- Auth/session；
- 复杂事务；
- 并发/幂等；
- 安全审查；
- Milestone 终审。

普通 Luna/较轻推理即可：
- 简单 Widget；
- 重命名；
- 文案；
- 格式修复；
- 已有模式的重复 CRUD/test scaffolding。

零成本不是不用 Max，而是把重推理留给错误代价高的地方。

---

## 6. Supabase Free 的候选分配（P0 Gate A/B 前仅 compatibility）

当前小规模 Pilot 采用：

### Project 1：Remote Development
- 只放虚构数据；
- Auth/Storage/Edge Functions/双设备/region 测试；
- 可删、可重建。

### Project 2：Gated Production Pilot（未来）
- 只有 P0 Gate A/B 通过且 provider/region/identity/session strategy 冻结后才可承载真实数据；
- 禁止 seed/reset；
- 只接受验证过的 migration。

### Local Development
Supabase CLI local stack，不占第三个云 project。

Free 当前适合早期 Pilot，但有数据库/Storage/Egress限制、低活动暂停、无付费级自动备份。接近边界时必须重新评估，而不是偷偷升级。

---

## 7. Production Region 不先拍脑袋（且必须先过 P0 Gate A/B）

Supabase 当前 APAC 有 Singapore/Tokyo/Seoul 等，没有中国大陆 region；project 不能原地换 region。

因此：
1. Remote Development 用虚构数据先选一个 APAC region；
2. 在实际机构 Wi‑Fi、普通移动网络、**无代理/VPN**测试；
3. 覆盖登录、CRUD、Storage、Edge Functions、网络恢复；
4. 不达标就重建 Dev 到另一个 APAC region；
5. 结论稳定后先完成 P0 Gate A/B 并冻结 provider/identity/session strategy；
6. 最后才按 Go/No-Go 创建 gated Production Pilot；未成年人数据驻留/跨境问题由机构单独合规评估。

Region 是生产决策，不是默认选 Singapore 就结束。

---

## 8. 0 元认证最终方案

V1 不依赖 Email OTP/SMTP。

```text
org_admin
  ↓
provision_member（可信服务端）
  ↓
Auth User + 随机临时密码
  ↓
membership(onboarding) + onboarding_expires_at
  ↓
教师临时密码登录
  ↓
只能进入账号接管
  ↓
设置自己的新密码
  ↓
global sign-out 所有 Session
  ↓
membership active
  ↓
强制用新密码重新登录
```

业务 RLS 还验证 JWT `session_id` 对应 `auth.sessions` 仍存在，避免被 global sign-out 的旧 Access Token 在 `exp` 前重新借 active membership 访问学生数据。

### 重置
- 管理员先核验本人；
- **先 membership→onboarding**；
- 再更新 Auth 临时密码；
- 刷新 onboarding expiry；
- 教师重新完整接管。

### 临时密码
- 安全随机；
- 只显示一次；
- 不进 DB/log/audit/GitHub；
- 有短有效期；
- 交付未知/响应丢失时 reissue 新密码；
- 不为了幂等保存明文秘密。

### 管理员恢复
真实 Pilot 至少两个独立 org_admin，或经过演练的 Project Owner break-glass。

以后有可靠 SMTP 再升级 Email OTP，membership/roles/assignments 不动。

---

## 9. 设备端也必须安全

零成本不代表用明文 Preferences。

### Session
若未来选择 Supabase，gated Production 不得把 `supabase_flutter` 默认持久化 Session 到 SharedPreferences 系列存储作为最终方案；必须使用自定义 `LocalStorage` + Windows/Android OS 安全存储。Password 永不本地保存。

### Startup Gate
Supabase Flutter v2 可能先读出本地 Session，而不保证它已经远端刷新。业务 Shell 只在 session valid/live + membership active 解析成功后挂载，禁止闪现旧学生数据。

### 草稿
跨重启草稿：
- 加密 at rest；
- key 在 OS 安全存储；
- user/org 隔离；
- TTL；
- sync 后删除；
- logout/disabled/account switch 有明确清理策略；
- 不存 Token/Password。

全部可以用开源/本地实现，不要求付费 SaaS。

---

## 10. GitHub Free：Private 优先，流程保护 main

仓库必须 Private。

现实限制：GitHub Free private repo 没有 Pro/Team 才有的 private branch protection/ruleset 强制能力。

因此零成本阶段：
- 不直推 main；
- branch + Draft PR；
- 没有真实 CI/命令证据不合并；
- AGENTS/Work 指令明确禁止直接 main；
- 人工合并；
- 以后升级 GitHub 计划再开启 required PR/status checks。

隐私优先级高于为了免费 branch protection 保持 Public。

---

## 11. GitHub Actions：免费额度必须主动控制

GitHub Free private 当前有有限 Actions 分钟/存储；没有预算保护时更不能把“免费额度”理解成无限资源。

### 当前明确决策

用户于 2026-09-02 明确选择**暂不设置 Actions zero-overage budget**，并接受这一账户级计费风险。该设置不再作为 Foundation、Phase 0A 或真实数据 Go / No-Go 的硬阻塞项，详见 ADR-044。

因此工程侧必须：
- 普通 PR 与 `main` 默认 Linux：pub get / lockfile / format / analyze / unit/widget tests，Phase 0B 后再加入适合 Linux 的 Local DB/RLS checks；
- 不让同一 feature commit 因 `push` + `pull_request` 重复跑同一套轻量 CI；
- Windows / Android native build 仅 Milestone / Release / 手动；
- 不用 larger runner；
- artifact retention 短；
- 无价值构建不上传 artifact；
- 发现异常 Actions 消耗时先停无价值 workflow，再决定是否继续。

Phase 0A 已真实完成一次 Android + Windows 原生构建验证，之后把 native build workflow 改为 `workflow_dispatch` 手动触发。

如果未来用户改变决定，可再启用 budget stop；在此之前不要反复把它列为“未完成阻塞项”。

---

## 12. Free 最大运行风险：恢复（仅适用于未来 gated Production Pilot）

Supabase Free 不含付费级自动日备份。

数据库至少生成：

```text
roles.sql
schema.sql
data.sql
```

必要时另保存 migration history。

同时必须：
- 加密离站；
- 多时间点；
- 不提交 GitHub；
- Storage 文件 + manifest 独立备份；
- Auth/Realtime/Extensions/Secrets 等项目设置有重建清单；
- 实际恢复到非 Production 新项目。

Pilot 默认目标 RPO ≤ 一个教学日；如果机构无法接受这个恢复点，Free Pilot 不符合要求。

详见 `DISASTER_RECOVERY.md`。

---

## 13. 0 元不新增的东西

默认不购买：
- SMTP / 域名 / SMS；
- AI API；
- Supabase Pro/add-on/PITR；
- 商业 UI/监控/分析；
- paid CI/larger runner；
- Work/Codex extra credits；
- Windows 公信代码签名证书作为 Pilot 硬依赖。

确实需要时先问：
1. 不用它 V1 是否真的做不成？
2. Free 是否够？
3. 超额是否可能产生费用？
4. 能否迁出？
5. 是否触碰学生敏感数据？

---

## 14. 云端执行顺序

```text
Foundation Freeze
→ repo Private
→ merge Foundation PR
→ Flutter Windows/Android bootstrap
→ Phase 0A.5 UX/UI Design Foundation
→ Local Supabase + migrations/RLS tests
→ secure Session/draft spike
→ Remote Dev region/network compatibility spike（仅虚构数据）
→ P0 Gate A：Auth Identity Portability Spike
→ P0 Gate B：Revoked Session / Old Token Security Spike
→ freeze provider/region/identity/session strategy
→ auth provision/onboarding/reset/live-session compatibility spike
→ Organization/Membership/RLS
→ Student vertical slice
→ Learning Case vertical slice
→ Lesson/Today
→ Security/Recovery audit
→ gated Production Pilot Go/No-Go（P0 Gate A/B 后）
```

在 Phase 0 关键风险没被真实执行证明前，不批量开发漂亮页面。

---

## 15. 什么时候不再坚持 0 元

出现任一情况就重新做成本 ADR：
- 系统成为机构关键基础设施；
- 不能接受一个教学日左右的数据恢复点；
- Free DB/Storage/Egress 接近上限；
- inactivity pause 影响业务；
- 账号规模让人工 reset 不可运营；
- 家长/学生自助账号上线；
- 机构需要 SLA/专业支持。

目标是**先用 0 元验证产品价值**，不是拿真实学生数据证明“永远一分钱不花”。
