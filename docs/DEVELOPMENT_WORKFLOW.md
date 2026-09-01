# 开发、数据库与发布工作流

> 定义如何从新环境开始开发、修改数据库、验证和发布，避免出现“某个人在 Dashboard 手工改过，所以别人无法复现”的隐性状态。零额外付费原则详见 `ZERO_COST_CLOUD_DEVELOPMENT.md`。

## 1. 四个事实源不要混

- **GitHub**：源码、文档、migrations、测试、CI 事实源；
- **`supabase/migrations`**：数据库 schema / RLS / View / Function / Trigger / Index 的正式事实源；
- **Supabase Production**：真实业务数据事实源；
- **ChatGPT Project / Work**：开发协作上下文，不是代码/数据库事实源。

聊天里记得的旧代码、Remote Dashboard 临时状态都不能覆盖 Git。

---

## 2. 三种运行环境

### Local Development
用于数据库结构、RLS、函数与自动化测试。

- Supabase CLI 本地 stack；
- 虚构数据；
- 可 reset / reseed；
- Auth 流程可用本地测试账号；
- 不承载真实机构数据。

### Remote Development
一个 Supabase Free Project，只放虚构数据，用于真正需要公网/双设备的集成：
- Windows + Android 连接同一后端；
- Password Auth / Session；
- provision/onboarding/reset Edge Functions；
- Storage；
- Realtime（如后续使用）；
- 网络切换；
- 双教师共享数据。

Remote Development 不是第二套 schema 源。

### Production Pilot
第二个 Supabase Free Project。

- 真实数据；
- 不允许 development seed/reset；
- 只执行已经在 Local + Remote Development 验证的 migration；
- 独立 Secret；
- 定期数据库和 Storage 离站备份；
- 进入真实数据前通过 Go/No-Go。

这样 Local + Remote Development + Production 仍只需要两个免费云项目。

---

## 3. 新环境从零开始

目标：任何 ChatGPT Work/Codex 会话、开发者或新机器都不依赖“老电脑隐藏状态”。

建议顺序：

```text
git clone
  ↓
checkout 当前 feature/review branch
  ↓
安装仓库规定 Flutter / Dart / Supabase CLI
  ↓
flutter pub get
  ↓
supabase start
  ↓
supabase db reset
  ↓
DB/RLS tests
  ↓
flutter analyze / test
  ↓
使用虚构配置运行 Development app
```

正式 Flutter 初始化后把可重复步骤写进 README/脚本，不让 Agent 每次猜命令。

---

## 4. Git 分支与 Work 会话

较大任务：
1. 明确 Issue/目标；
2. 新 feature/review branch；
3. 一条 ChatGPT Work 会话主要负责一个可验收目标；
4. 会话开头读取 `AGENTS.md` + 相关 docs + 当前 GitHub 文件；
5. 小步 commit；
6. 开 PR；
7. CI + review；
8. 通过后合并。

不要让一条长 Work 会话连续跨十几个 Milestone 后继续凭记忆修改仓库。

如果当前 Work 环境不能真实执行 Flutter/Supabase 命令，必须由 Codex 或 GitHub Actions补充执行证据；不能把“模型判断应该通过”写成“测试通过”。

---

## 5. 修改数据库的唯一正式路径

### 正确
1. 在 `supabase/migrations` 新增 migration；
2. Local `db reset`；
3. seed；
4. DB/RLS tests；
5. App/Repository 测试；
6. PR review；
7. 推到 Remote Development；
8. 集成验证；
9. 最后才进入 Production。

### 不正确
- 只在 Dashboard Table Editor 改列；
- 只在 SQL Editor 建 policy/function；
- Remote Dev 跑通后不写 migration；
- Production 直接试 SQL 再“回头补文件”。

如果为了快速实验临时改 Remote Development，最终仍必须转成 migration，并从干净 Local DB 重建验证。

---

## 6. Migration 设计

### 普通 additive 变化
优先：
- 新表；
- nullable 新列；
- 新 index；
- 新 View/Function；
- 新 policy。

### 破坏性变化
必须说明：
- 数据迁移；
- 旧客户端兼容期；
- 失败恢复；
- 是否需要 expand → migrate → contract。

不要为了省一个 migration 把生产数据一次性赌在不可逆 SQL 上。

---

## 7. RLS / Function 开发

每个业务表最少测试：
- unauthenticated；
- Auth User 无 membership；
- membership = onboarding；
- membership = active；
- membership = disabled；
- same org/no assignment；
- cross-org；
- cross-subject；
- admin/teacher 不同权限。

对 `security definer`：
- 非 exposed schema；
- `search_path = ''`；
- schema-qualified；
- revoke 默认 execute；
- 最小 grant；
- 越权测试。

View 优先 `security_invoker = true`。

RLS 高频过滤字段要建合理 index，并在真实查询出现后用 EXPLAIN 验证。

---

## 8. Auth / Credential 开发

V1 不以邮件 OTP 为发布前置。

### Local
使用明显虚构测试账号和固定测试凭据；这些只存在 Local seed/test，不得复制到 Production。

### Remote Development
真实验证：
- org_admin provision 测试教师；
- 临时密码只返回一次；
- onboarding 无业务权限；
- complete onboarding；
- active Session 恢复；
- admin reset；
- reset 后旧 Session 业务访问失败；
- disable 后旧 Session 失败。

### Secret
Auth Admin / service_role 只存在 Edge Function/可信环境。

错误日志不得打印：
- password；
- Authorization header；
- Access/Refresh Token；
- Secret。

---

## 9. Flutter 测试层级

### 快速单元测试
每个 PR 高频运行：
- ViewModel；
- domain/business rules；
- Repository with fake；
- Service with mocks/`supabase_testing`（适合时）。

### Local Supabase 集成测试
验证：
- schema；
- RLS；
- RPC/DB function；
- 事务与约束。

### Remote Development 集成
只用于 Local 无法证明的：
-真实 Auth Admin/Session；
- Edge Function secrets；
- Storage；
- 两设备/两账号；
- 公网失败/恢复。

### Release 验证
- Android build；
- Windows build；
- 关键 smoke / integration；
- Production migration dry-run/兼容审查。

---

## 10. GitHub Actions 免费额度策略

Private GitHub Free 有有限 Actions 分钟，不能把重构建放在每个 commit。

### PR 默认
- format；
- analyze；
- unit tests；
- Local DB/migration/RLS tests；
- secret/static checks。

### Milestone / Release 才跑
- Android release/test artifact；
- Windows build；
- 重 integration matrix。

要求：
- 不使用 larger runner；
- artifact retention 短；
- 无价值中间构建不上传；
- billing/budget 设置为超额停止，而不是自动付费。

---

## 11. `supabase_testing` 的定位

Supabase 官方 Flutter 仓库提供测试 helper，可 mock HTTP、JWT、Auth Session、Realtime 等。

Xueqing 可以在正式 Flutter 工程初始化后评估加入为 dev dependency，用来：
- 测 Service/Repository；
- 减少 Remote Development 依赖；
- 模拟 Auth/RPC/错误；
- 提高 CI 可重复性。

不要因为有 mock 就省略真正 RLS/Local DB 测试；两者解决不同问题。

---

## 12. Remote Development 更新

正常流程：

```text
Local migrations/tests green
  ↓
PR review
  ↓
应用 migrations 到 Remote Development
  ↓
部署需要的 Edge Functions
  ↓
双平台/双账号集成验证
  ↓
记录异常
```

禁止把 Remote Development 的手工修补留在 Dashboard 不回写 Git。

---

## 13. Production Pilot 发布

前提：`RISKS_AND_OPERATIONS.md` Go/No-Go 通过。

发布顺序建议：
1. 确认最新离站备份；
2. 记录当前 DB/App version；
3. 执行已评审 migration；
4. 部署 Edge Functions；
5. smoke test 登录/权限/核心读写；
6. 发布 Windows/Android 对应版本；
7. 观察错误；
8. 发现高风险异常时停止扩大使用。

不要在 Production 现场即兴开发。

---

## 14. Free Production 备份

Supabase Free 不能代替自建备份制度。

### Database
定期：
- `supabase db dump` / `pg_dump`；
- 加密；
- 存到 Supabase 以外；
- 多版本；
- 定期恢复演练。

### Storage
单独：
- object inventory；
- 对象备份；
- DB path ↔ object 一致性；
- 抽样恢复。

备份成功的定义是“恢复过”，不是“目录里有文件”。

---

## 15. Free Project Pause / Quota

运维要知道：
- Free project 可能因低活动暂停；
- Remote Dev 停了不等于数据丢失；
- Production 长假前确认备份；
- DB/Storage/Egress 接近免费额度时先评审；
- 不设置自动付费升级。

如果系统已经关键到不能接受 Free Tier 的暂停/备份能力，这本身是重新做成本 ADR 的信号。

---

## 16. 发布兼容性

数据库先变、客户端后变时要考虑旧客户端。

高风险变更优先：
1. expand；
2. 新旧客户端兼容；
3. migrate data；
4. 发布新客户端；
5. contract。

后续可增加最低支持客户端版本，但 V1 不先建复杂更新服务。

---

## 17. 外部开源项目使用

参考 `OPEN_SOURCE_REFERENCES.md`。

规则：
- 借模式，不盲 fork；
- 许可证不清楚不复制代码；
- 官方 Flutter/Supabase 优先；
- 开源项目若与本仓库 ADR 冲突，以 ADR 为准；
- 新依赖先证明真实价值。

---

## 18. 一次 PR 的完成证据

PR 描述至少回答：
- 用户为什么需要；
- 影响哪个核心 Flow；
- schema/RLS 是否变化；
- migration 是否可从空库重建；
- 权限负面测试；
- 网络失败/幂等；
- 隐私/Secret；
- 是否增加任何付费/外部运行依赖；
- 实际跑过哪些命令；
- 哪些尚未验证；
- 回滚/恢复方式。

“ChatGPT 说已经做好”不是完成证据。