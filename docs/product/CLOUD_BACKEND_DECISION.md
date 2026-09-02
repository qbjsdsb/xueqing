# 云后端决策｜Cloud Backend Decision

> 状态：Phase 0A.6 决策事实源（pre-spike）。本文记录截至 2026-09-02 的候选、官方证据、已确认差异与必须执行的兼容性验证。**尚未授权选择 production provider，也未使用真实学生数据。**

## 1. 结论先行

Xueqing 的正式目标是云端多人协作。

当前不应把产品锁死为：
- 只能官方 Supabase；
- 只能腾讯 CloudBase；
- 只能自托管。

当前推荐架构原则：

> **PostgreSQL-first + Domain/Repository isolation + migration-as-source-of-truth + provider-portable where practical.**

但“provider-portable”不是假装所有平台 100% 一样。认证、Storage、session revoke、DDL 部署等平台差异必须被显式隔离并通过 Spike 验证。

### 当前候选排序（不是 production final decision）

1. **Reference backend：官方 Supabase APAC / Singapore**
   - 当前 Foundation 与 Flutter 技术路线最一致；
   - `supabase_flutter` 官方支持 Android 与 Windows；
   - 最适合作为语义参考实现和 Phase 0B Vertical Slice 基线候选。
2. **Mainland candidate：腾讯 CloudBase PG / Shanghai**
   - 中国大陆地域；
   - PostgreSQL + PostgREST + RLS + JWT + Storage 心智与 Supabase 高度对齐；
   - 有免费体验环境；
   - 必须先通过 Xueqing 的 Auth/session、Flutter、migration、Storage 与权限 Spike。
3. **Long-term fallback：在中国大陆云自托管 Supabase**
   - 最大控制力，能保留 Supabase 原生 API/服务组合；
   - 但需要付费服务器和自行承担安全、Postgres、备份、升级、监控、高可用；
   - 不作为当前零成本首选。

---

## 2. 官方 Supabase｜已确认事实

### Region
Supabase 每个 project 有一个 primary region；APAC general region 当前落在 Southeast Asia / Singapore，specific regions 也包括 Singapore、Tokyo、Seoul 等。

Region 同时决定 primary project data 的存储位置。

当前没有中国大陆 region。

官方来源：
- https://supabase.com/docs/guides/platform/regions

### Flutter
`supabase_flutter` 官方文档明确支持：
- Web；
- iOS；
- Android；
- macOS；
- Windows。

官方来源：
- https://supabase.com/docs/guides/getting-started/quickstarts/flutter

### Free plan（截至 2026-09-02）
官方定价页当前列出：
- $0；
- 500 MB database；
- 1 GB file storage；
- 5 GB egress；
- 50,000 MAU；
- 2 active projects；
- 低活跃项目可能在约 1 周 inactivity 后暂停；
- Free 不提供 automatic backups/PITR。

官方来源：
- https://supabase.com/pricing
- https://supabase.com/docs/guides/deployment/going-into-prod

### Production backup
Pro 有 daily backups；PITR 是额外付费 add-on。

因此：
- Free 很适合开发/虚构数据；
- **Free 不能作为 Xueqing 真实学生数据唯一恢复方案。**

即使使用 managed Supabase，也必须有独立恢复策略与实际 restore drill。

---

## 3. 官方 Supabase｜Xueqing 优势

1. 与现有 Foundation 最一致：Auth、RLS、Postgres、RPC、Storage、Flutter SDK。
2. 当前 `AUTH_AND_PERMISSIONS.md` / `COMMANDS_AND_INVARIANTS.md` 已基于 Supabase session 语义做过深入安全设计。
3. 官方 Flutter SDK 成熟，Windows/Android 路线直接。
4. 数据 API、RLS、RPC、Storage 的文档与生态完整。
5. 将来可以迁移到 self-hosted Supabase，保留更多 API 心智。

---

## 4. 官方 Supabase｜Xueqing 风险

1. 无中国大陆 region；大陆老师访问 Singapore 属于跨境网络，不应假设等同于国内节点稳定性。
2. 真实学生数据涉及数据位置与生产合规 gate，不能只因“能打开”就上线。
3. Free 会暂停低活跃 project，且无 automatic backups。
4. Managed 服务的部分高级恢复能力成本明显高于早期项目需要。
5. 如果 Flutter 业务层到处直接调用 Supabase SDK，将提高未来迁移成本。

### 当前网络状态
“大陆不翻墙通常可访问”只能作为经验性可能，**不是 Xueqing 已执行证据**。

Phase 0A.6 不宣称国内稳定性已验证。

---

## 5. 腾讯 CloudBase PG｜已确认事实

### Region
CloudBase for Supabase/PG 当前官方产品页列出：
- 上海；
- 新加坡。

上海是大陆候选。

官方来源：
- https://cloud.tencent.com/product/tcbs

### PostgreSQL / RLS / PostgREST
CloudBase PG 官方说明：
- PostgreSQL-native；
- `auth` schema；
- `storage` schema；
- JWT；
- `anon / authenticated / service_role`；
- GRANT + RLS；
- PostgREST；
- RPC；
- `auth.uid()` / `auth.role()` 等语义。

官方来源：
- https://docs.cloudbase.net/quick-start/pg-overview
- https://docs.cloudbase.net/quick-start/migration/supabase

### Flutter
CloudBase Flutter SDK 当前文档：
- package `cloudbase_flutter`；
- 支持 Android / iOS / Web / macOS / Linux / Windows；
- 提供 Auth、session、Storage、Function 等 API。

官方来源：
- https://docs.cloudbase.net/api-reference/flutter

### Free（截至 2026-09-02）
官方价格文档当前列出：
- 1 个免费体验环境/账号；
- 3000 resource points / month；
- PostgreSQL 支持；
- Storage / Function 等核心能力；
- 单次 6 个月，到期前按当前政策可续；
- 不支持超限按量/资源包；
- 免费版“数据回档”列为不可用。

官方来源：
- https://cloud.tencent.com/document/product/876/127357
- https://tcb.cloud.tencent.com/pricing

因此：
- 很适合大陆开发/虚构数据验证；
- **免费版同样不能成为真实学生数据唯一恢复方案。**

---

## 6. CloudBase 与 Supabase：已经确认的相似点

CloudBase 官方 Supabase migration 文档明确对齐：
- DB roles 名称/语义；
- `auth` schema；
- `storage` schema；
- JWT `sub / role / aud`；
- RLS Policy；
- PostgREST；
- RPC；
- Storage RLS 思路。

因此 Xueqing 的：
- PostgreSQL-first；
- GRANT + RLS；
- domain command via RPC/function；
- provider-neutral business tables；

都有现实迁移基础。

但 CloudBase 官方同时明确：**不是 Supabase 官方代理，也不承诺 100% API 兼容。**

---

## 7. CloudBase：已经确认的差异

### 7.1 SDK 不同
Supabase：`supabase_flutter`

CloudBase：`cloudbase_flutter`

因此 Flutter infra 层必须可替换；不能让 domain/view model 依赖 provider-specific client type。

### 7.2 REST endpoint 不同
Supabase：通常 `/rest/v1/...`

CloudBase PG：`/v1/rdb/rest/...`

### 7.3 Realtime
CloudBase migration 文档当前写明 Supabase-style Realtime live subscriptions 不支持/不等价。

这对 Xueqing V1 **目前不是 blocker**，因为 Foundation 已决定业务正确性不依赖 Realtime，默认使用进入页面/保存后/App resume/手动刷新。

### 7.4 Storage API
CloudBase Storage 权限心智相近，但 SDK/HTTP 形态并非当前完全与 Supabase Storage API 相同。

Xueqing business table 因此只保存 provider-neutral `storage_object_path/object_key`，不要保存厂商永久 public URL。

### 7.5 DDL / migration channel
CloudBase 官方 migration 文档指出 DDL 管理通道与 Supabase 不同；CloudBase 可通过 Console SQL / Cloud API `ExecutePGSql` 等执行。

正式 Phase 0B 必须验证：
- migration CI 如何幂等部署；
- migration history 如何记录；
- rollback/失败如何恢复。

不能只在控制台手工粘 SQL。

---

## 8. P0 portability issue：Auth User ID 类型不同

这是 Phase 0A.6 新发现的重要差异。

### Supabase
现有 Foundation 按 `auth.users.id` UUID 心智设计。

### CloudBase PG
官方文档明确：
- `auth.users.id` 类型为 `varchar(64)`；
- JWT `sub` 与之对应。

因此当前 Foundation 里的：

`profiles.id → auth.users(id)`

以及 membership 直接存 provider Auth User ID 的方式，**不能在没有迁移策略的情况下假装完全 provider-neutral。**

### Phase 0A.6 必须做的决策
正式 migrations 前比较三个方案：

#### Option A｜选择 provider 后接受 provider-specific auth ID type
优点：简单、最贴近各平台。

缺点：未来迁移需要 auth identity transformation。

#### Option B｜业务 Profile 使用自己的 UUID，额外保存 `auth_subject_id text`
例如：

`profiles.id UUID`

`profiles.auth_subject_id TEXT UNIQUE`

Membership 引用业务 profile，而不是 provider auth PK。

优点：业务层 identity 更可迁移。

缺点：RLS 多一层 mapping；必须证明性能与安全。

#### Option C｜业务层统一使用 text auth subject，不建立到 auth.users 的强 FK
优点：Supabase UUID 可转换 text，CloudBase varchar 也可用。

缺点：丢失部分 FK 完整性，需要受控 provisioning 保证。

**当前不选。必须在 Cloud Compatibility Spike 中用 RLS/EXPLAIN/commands 测试后冻结。**

这是阻止 Phase 0B 盲目 migration 的 P0 决策点。

---

## 9. P0 security issue：Live Session / revoked JWT

现有 Xueqing Foundation 的强安全不变量是：

> 用户 sign out / reset / disabled 后，旧 Access Token 即使尚未自然过期，也不能继续读取学生数据。

Supabase 设计当前依赖：
- JWT `session_id`；
- `auth.sessions`；
- RLS live-session helper。

CloudBase 已确认：
- 有 Session 管理；
- Access/Refresh Token 双 token；
- signOut 会服务端撤销 refresh token，并标记当前 access token 无效；
- Access Token validity 可配置；
- 产品资料提到 users/sessions/provider identity data。

但是截至本文编写：**尚未验证 CloudBase 是否能原样提供 Xueqing 当前 `JWT session_id → auth.sessions` SQL/RLS helper 语义。**

因此 CloudBase Spike P0：

1. 登录获取 JWT；
2. 解析 claims；
3. 确认是否有稳定 session identifier；
4. 确认 session 数据是否可由安全 SQL helper 验证；
5. signOut 后立刻用旧 access token 请求受保护 Data API；
6. reset/password change/global revoke 场景；
7. disabled membership + old JWT；
8. RLS 是否可以可靠拒绝。

通过标准不是“UI 已退出”，而是：

> **旧 token 对业务 API 立即/在明确保证窗口内失权，且风险与 Foundation 相当或更强。**

如果 CloudBase 不能证明这一点，则不能为了大陆免费节点牺牲安全不变量。

---

## 10. 中国大陆自托管 Supabase

Supabase 官方支持 Docker self-hosting。

当前官方完整栈系统要求：
- minimum 2 cores / 4 GB RAM / 40 GB SSD；
- recommended 4 cores / 8 GB+ / 80 GB+。

Self-host 后由我们负责：
- server；
- OS/security updates；
- Supabase stack upgrade；
- Postgres maintenance；
- HA/scaling；
- backup/disaster recovery；
- monitoring/uptime。

官方来源：
- https://supabase.com/docs/guides/self-hosting
- https://supabase.com/docs/guides/self-hosting/docker

### 结论
它是非常重要的长期 fallback，但不是当前“零成本、少运维”的优先选择。

另外 2026 Supabase self-hosted stack 已发生 Postgres 15 → 17 breaking upgrade，这进一步说明自托管必须有版本 pin / migration / restore discipline，不能“装一次以后不管”。

---

## 11. Provider isolation 规则

无论最终选谁，Flutter 业务层都遵守：

```text
UI / ViewModel
      ↓
Domain Repository Interface
      ↓
Infrastructure Adapter
      ├─ Supabase adapter
      └─ CloudBase adapter（如果采用）
```

禁止：
- Widget 里直接散落 provider SDK；
- domain entity 暴露 `PostgrestResponse` / CloudBase response type；
-业务状态依赖 vendor-specific error string；
- 保存 public CDN URL 作为附件事实；
- 把 service_role/API Key 放 Flutter。

允许 provider adapter 内使用各自 SDK。

---

## 12. PostgreSQL portability rules

正式 migrations 优先：
- standard PostgreSQL；
- UUID/text/timestamptz/date 等稳定类型；
- CHECK / unique / partial index；
- RLS；
- SQL functions；
-明确 versioning；
-显式 migrations。

谨慎：
- provider-only extensions；
- storage implementation internal fields；
- auth internal table强耦合；
-不可迁移 trigger magic；
-只有某 provider dashboard 才能重建的配置。

如果必须使用 provider-specific feature，写 ADR。

---

## 13. Storage portability

业务事实层只保存：
- object key/path；
- MIME/type；
- size/hash（如需要）；
- Evidence relation；
- created_by/time。

下载由 provider adapter 获取短期 signed URL/authorized stream。

禁止：
- public permanent URL；
-把 signed URL 当永久数据库事实；
-直接暴露 bucket 管理 credential。

Backup 必须同时覆盖：
- DB；
- Storage objects；
- DB → object reference consistency。

---

## 14. Compatibility Spike｜必须执行

全部只用明确虚构的组织/教师/学生。

### Fixture
- Org A / Org B；
- active teacher；
- onboarding teacher；
- disabled teacher；
- subject scopes；
- assigned/unassigned student；
- 一个 Learning Case + Action；
- 一个私有 Evidence object。

### Windows + Android
必须分别验证：
1. password login；
2. session persistence；
3. app restart；
4. token refresh；
5. signOut；
6. revoked/old token；
7. network failure；
8. private attachment upload/read。

### PostgreSQL / RLS
必须验证：
1. Org A 无法读 Org B；
2. teacher 无法读未 assignment student；
3. subject scope 不自动授予全学科学生；
4. onboarding 无学生数据；
5. disabled + old token 无业务权限；
6. command/RPC transaction；
7. expected_version conflict；
8. auth identity type strategy；
9. `EXPLAIN` 核心 RLS helper；
10. migration deploy/repeat behavior。

### Recovery
必须验证：
- SQL/data export；
- import 到新环境；
- Storage export/restore；
- 恢复后 reference consistency；
- 至少一次真实 restore drill。

---

## 15. 国内网络测试矩阵

不能仅测试“官网能打开”。

真实候选测试：
- Windows 客户端；
- Android Wi-Fi；
- Android cellular；
- 机构实际网络；
- 工作日白天/晚间；
- login；
- Today query；
- Student Detail query；
- transaction save；
-小文件 upload/download；
- reconnect。

记录：
- success rate；
- p50/p95 latency（如可采集）；
- timeout；
- DNS/TLS error；
- provider error；
-重试结果。

Phase 0A.6 当前没有这些实测结果，因此全部标记 **UNVERIFIED**。

---

## 16. 真实学生数据 Production Gate

无论选哪个 provider，真实学生数据上线前必须独立检查：
- data location；
- 未成年人/敏感个人信息最小化；
- RLS negative tests；
- secret management；
- secure local session；
- encrypted drafts；
- private Storage；
- backup + restore drill；
- account disable/handoff；
- audit；
- incident/recovery process；
- data export/delete/correct process；
-中国大陆网络与备案/合规事项（若使用大陆互联网服务）。

“开发环境跑通”不等于 Production Gate 通过。

---

## 17. 当前推荐执行顺序

### Phase 0A.6
1. 不创建 production project；
2. 冻结 provider-neutral domain；
3. 完成 CloudBase/Supabase compatibility plan；
4. 把 auth ID 与 live-session 两个 P0 加入 Product Completeness Audit。

### Phase 0B 第一个 Cloud Spike
建议：
- Supabase Singapore 建 reference environment；
- CloudBase Shanghai 建 comparison environment；
- 同一套 fictional fixture / RLS / command contract；
- 不实现两套完整产品，只实现最小 compatibility harness。

### 决策 Gate
若 CloudBase P0/P1 全通过且国内网络显著更合适：
- 可作为大陆 Pilot 候选。

若 CloudBase session/security/migration 不能满足 Foundation：
- 不因免费/大陆节点牺牲安全；
- 继续 Supabase reference，或进入 mainland self-hosted Supabase 评估。

---

## 18. 当前结论状态

### CONFIRMED
- Supabase APAC 有 Singapore，但没有 mainland region。
- `supabase_flutter` 支持 Windows/Android。
- Supabase self-hosting 官方支持 Docker。
- CloudBase PG 上海可用，且 PostgreSQL/RLS/PostgREST/Auth/Storage 心智高度对齐 Supabase。
- CloudBase Flutter SDK 支持 Windows/Android。
- CloudBase 免费体验目前有 3000 点/月，但无数据回档能力。
- CloudBase 与 Supabase 不是 100% API compatible。
- CloudBase `auth.users.id` 与 Supabase identity type 存在需要处理的差异。

### UNVERIFIED
- 厦门/机构真实网络下 Supabase Singapore 的稳定性与延迟。
- CloudBase Flutter PG 所有 Data/RPC/Storage API 在 Windows/Android 的真实完整表现。
- CloudBase 是否可原样实现当前 Supabase `session_id/auth.sessions` live-session RLS helper。
- 两边 migration automation 的最终 CI 方案。
- provider-to-provider auth identity migration 操作成本。
- private Storage + restore 的完整演练。

### DECISION
**Production provider 尚未冻结。**

这不是延期，而是因为关键安全/身份差异必须通过最小真实 Spike 才能负责任地决定。
