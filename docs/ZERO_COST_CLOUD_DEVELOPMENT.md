# 零额外付费的云端开发方案

> 目标：在**不额外购买 API、Codex/Work credits、服务器、数据库套餐、SMTP、域名或 CI 时长**的前提下，把 Xueqing 做到可测试、可安装、可供少量机构内部教师试运行的 V1。

这里的“0 元”指：使用用户当前已经拥有的 ChatGPT 方案能力和各平台 Free Tier，不再产生新的现金支出。

## 1. 总体方案

```text
ChatGPT Project: Xueqing
        │
        ├── Work：研究、设计、跨文件修改、PR 规划与复审
        ├── Codex（按需）：真正需要终端/构建/调试时使用
        │
        ▼
Private GitHub Repo
        │
        ├── source / docs / migrations
        ├── PR / Issues
        └── GitHub Actions（免费额度内）
                │
                ├── Flutter format/analyze/test
                ├── DB/RLS tests
                └── milestone/release build

Supabase Local CLI
        └── schema / RLS / DB tests / fake seed

Supabase Free Remote Development
        └── 虚构数据、Auth/Storage/Functions 集成

Supabase Free Production（V1 小规模试运行）
        └── 真实数据前必须通过安全/备份/网络门槛
```

GitHub 是代码事实源，migrations 是数据库结构事实源，ChatGPT Project/Work 是**协作与执行上下文**，不是唯一事实源。

---

## 2. ChatGPT 云端 Project 怎么建

建议创建一个 ChatGPT Project：

**Xueqing｜学情闭环开发**

### Memory

如果计划在 Project 内使用 ChatGPT Work，优先使用 **Default memory**。

当前产品规则下，Project-only memory 会使 Work 在该 Project 中不可用。因此不要为了“看起来更隔离”误开 Project-only，然后失去 Work。

### 连接

至少连接：
- GitHub；

需要查公开技术资料时使用 Web；不要把整个仓库反复上传成 ZIP，因为上传副本很快会落后于 GitHub。

### Project Instructions

核心指令保持短：

```text
你正在维护 qbjsdsb/xueqing。
任何实现前先读取仓库根目录 AGENTS.md，以及本任务相关 docs/ 文档。
GitHub 是源码事实源；不要依据聊天里过时的代码猜测仓库状态。
所有较大改动使用分支/PR；不得把真实学生数据、Secret、service_role 放进仓库。
优先小而完整的垂直闭环；遵守 V1 范围、RLS、migration、事务命令和零额外付费约束。
如果外部资料与已接受 ADR 冲突，先说明并更新 ADR，不在代码里静默改方向。
```

详细规则继续放仓库，不把几百行工程规范复制到 Project Instructions。

---

## 3. 不要用“一条无限长 Work 会话”开发

长期 Agent 项目最容易失败的不是模型不聪明，而是上下文越来越混乱。

建议把 Work 会话按**一个可验收目标 / 一个 PR**拆开：

```text
00-Control-Tower
01-Phase0-Flutter-Bootstrap
02-Phase0-Local-Supabase
03-Auth-Org-Membership
04-Student-Master-Profile
05-Learning-Case-Vertical-Slice
06-Lesson-Today
07-Security-Audit
08-Release-Pilot
```

### 每条会话启动时

只给：
- 当前目标；
- 验收标准；
- 相关 Issue/PR；
- 要求读取 AGENTS.md + 对应 docs。

不要每次粘贴整个历史聊天。

### 每条会话结束时

要求：
- 写代码/文档到 GitHub；
- 跑能跑的检查或由 GitHub Actions 验证；
- 报告未解决风险；
- 更新 Roadmap/ADR（如果方向变了）；
- 不把“聊天里说完成”当作完成。

---

## 4. Work 与 Codex 的职责

OpenAI 当前产品定位：Work 适合长、多步骤工作和成品交付；Codex 专注软件开发、运行测试和命令。

因此本项目采用：

### Work 优先处理
- 公开资料研究；
- 产品/架构评审；
- GitHub 多文件阅读与修改；
- Issue / PR 规划；
- 数据模型/RLS设计；
- 代码 review；
- 文档同步；
- 复盘与风险审计。

### Codex 或 CI 处理
- `flutter analyze/test`；
- `supabase db reset`；
- migration/RLS 自动化测试；
- APK/Windows build；
- 本地运行后才能确认的问题。

如果当前 Work 环境本身能够执行所需命令，也可以直接完成；原则是不“假装跑过测试”。

**不需要为了使用 Codex 再购买 API。** Work/Codex 使用用户 ChatGPT 方案的对应 agentic 用量；达到包含额度后就等待重置，不购买额外 credits。

---

## 5. Luna / “Luna Max”使用策略

OpenAI 官方当前把 GPT-5.6 Luna 定位为 GPT-5.6 家族中速度最快、成本最低的型号，并在 Work/Codex 对符合条件的付费方案开放。

本项目把用户界面中可能出现的“Luna + Max reasoning”简称为 **Luna Max 执行档**；它不是仓库需要绑定的独立模型 ID。

### 适合 Luna Max
- RLS / 多租户权限；
- destructive migration；
- 复杂事务命令；
- 大型重构；
- 并发/幂等；
- 安全审查；
- 一个 Milestone 的最终复审。

### 不值得长期 Max
- 改文案；
- 文件重命名；
- 简单 Widget；
- 格式修复；
- 已有清晰模式的重复 CRUD；
- 批量补测试样板。

零额外付费策略不是“永远不用 Max”，而是：

> **把 Max 留给错误代价高的地方，不拿最贵的推理预算做机械劳动。**

如果用户坚持全程 Luna Max，也应继续按“一任务一会话/一PR”拆分，避免长上下文浪费用量。

---

## 6. Supabase Free 如何刚好够 V1

当前 Free Tier 对小规模内部试运行足够宽松：
- 2 个 active Free projects；
- 每项目 500 MB database；
- 1 GB file storage；
- 50,000 MAU；
- 5 GB egress；
- Free project 低活动时可能被暂停。

我们刚好这样分：

### Project 1：Remote Development
- 只放虚构数据；
- Auth / Storage / Edge Functions / 双设备测试；
- 可以被重置。

### Project 2：Production Pilot
- 真实数据；
- 严禁 seed/reset；
- 只接受测试过的 migration。

### Local Development
Supabase CLI 在本地/CI 起容器，不占第三个云项目。

这让“Local + Remote Dev + Production”仍可在 2 个免费云项目限制内完成。

---

## 7. 0 元认证：V1 不把 Email OTP 作为硬依赖

### 为什么改变

Email OTP UX 很漂亮，但真实机构使用必须依赖可靠邮件投递。

Supabase 默认 SMTP 是开发/演示级：
- 默认邮件发送限额很低；
- 非 Production SLA；
- 正式使用官方建议配置 Custom SMTP。

如果为了 OTP 再购买域名/SMTP，就违反了“本阶段不额外花钱”的硬约束。

### V1 免费首选：管理员受控创建账号 + 密码

```text
org_admin
   ↓
受信任服务端 create staff account
   ↓
Supabase Auth Admin createUser
   ├── email
   ├── 随机高强度临时密码
   └── email_confirm = true
   ↓
同一受控流程创建 active membership + roles
   ↓
管理员通过既有可信渠道把账号/临时密码交给已知教师
   ↓
教师登录
   ↓
建议立即修改为自己的强密码
```

Supabase Admin `createUser` 不会自动发确认邮件；受信任服务端可以确认已知教师邮箱。用户登录后可通过 Auth `updateUser` 修改自己的密码。

### 忘记密码

V1 内部试运行先采用**管理员协助重置**：
- 管理员在线下/微信/电话确认教师身份；
- 受控管理函数生成新随机临时密码；
- 写 audit；
- 教师登录后再改密码。

这样完全不依赖 SMTP。

### 安全边界

这个方案只适用于：
- 已知、少量、内部教师；
- 管理员能线下确认本人；
- 不开放公共注册；
- 临时密码高强度、私下交付；
- 密码重置有审计。

它**不适合公开 SaaS**。

### 未来升级

机构以后已有自己的域名/可靠 SMTP，或者免费邮件方案经过真实验证，再升级为 Email OTP。因为 Auth User 与 membership 已经分离，升级登录 UX 不需要重做学生/权限模型。

---

## 8. GitHub Free 怎么用才不会超额

仓库必须改为 **Private**，但 GitHub Free 私有仓库仍有 GitHub Actions 免费额度。

CI 原则：

### 每个 PR 跑
- `dart format --set-exit-if-changed`；
- `flutter analyze`；
- unit tests；
- Local Supabase migration / DB / RLS tests（真正开始 schema 后）；
- secrets/basic static checks。

### 不要每个小 commit 都跑
- Windows release build；
- Android release bundle；
- 大型 integration matrix；
- 多 Flutter 版本矩阵。

### Milestone / Release 再跑
- Android signed test build；
- Windows build；
- 关键 integration tests。

### 成本保护
- 不使用 larger runner；
- artifact retention 尽量短；
- build artifact 只保留需要的版本；
- GitHub billing/budget 设置为超额时停止，而不是自动付费。

---

## 9. 免费 Supabase 最大风险：备份

Free Plan 不提供与付费计划相同的自动日备份保障。

Supabase 官方建议 Free 项目自行定期使用 CLI `db dump` 并把备份保存在平台外。

因此 V1 Pilot 必须补：

### Database
- 定期 `supabase db dump` / `pg_dump`；
- 加密保存；
- 至少保留多个时间点；
- 定期实际恢复到测试库验证。

### Storage
数据库 dump 不包含 Storage 文件本体。

附件必须：
- 单独导出对象；
- 有 object manifest；
- 抽样恢复；
- DB path 与文件对象做一致性检查。

### 现实结论

0 元方案适合开发和少量内部 Pilot，但**不能把 Free Tier 包装成商业级 SLA**。

如果未来机构已经高度依赖本系统、真实学生数据不可承受一天以上损失，就应该重新评估付费基础设施，而不是为了“永远 0 元”牺牲数据安全。

---

## 10. 其他 0 元原则

V1 不新增需要付费订阅的：
- Sentry 付费功能；
- AI API；
- SMS；
- 域名；
- 邮件服务；
- 商业 UI Kit；
- 商业图标库；
- 收费 CI；
- 数据分析 SaaS。

确实需要时先用：
- Flutter/Dart 原生能力；
- GitHub Issues / Actions；
- Supabase Free；
- 本地/CI 测试；
- 开源库；
- 手工运营流程。

任何新外部 SaaS 依赖先回答：
1. 不用它 V1 是否真的做不成？
2. 免费层是否足够？
3. 超额会不会自动扣费？
4. 能否随时迁出？
5. 会不会接触学生敏感数据？

---

## 11. 推荐的第一阶段云端执行顺序

### PR 0｜Foundation 合并
- 把仓库改 Private；
- 合并 Foundation v0.3；
- 保证 README / AGENTS / docs 一致。

### PR 1｜正式 Flutter Bootstrap
- 官方 stable Flutter；
- Windows + Android；
- dev/prod AppConfig；
- 基础 theme/router；
- CI format/analyze/test。

### PR 2｜Local Supabase Bootstrap
- `supabase/`；
- migrations；
- fake seed；
- DB/RLS test harness；
- `db reset` 验证。

### PR 3｜账号 + Organization
- admin-provisioned password account；
- organization / membership / roles；
- 登录 / Session / logout；
- 无 membership 绝对无业务权限；
- admin reset password。

### PR 4｜第一条共享学生
- Student；
- teacher/student/subject assignment；
- 两位虚构教师权限；
- cross-org negative tests。

之后按 Roadmap 继续。

---

## 12. 0 元并不等于“省测试”

最不应该省的是：
- RLS；
- migration；
- 自动测试；
- 备份；
- 隐私；
- 事务；
- 审计；
- Git 分支/PR。

真正该省的是：
- 过早 SaaS；
- 大而全功能；
- 复杂认证 UX；
- 不必要的 AI API；
- 不必要的云构建矩阵；
- 过度架构。

**用工程纪律换现金成本，而不是用数据安全换现金成本。**