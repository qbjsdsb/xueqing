# AGENTS.md

本文件是 ChatGPT Work、Codex 与后续开发者的**硬约束索引**。详细设计以 `docs/` 对应专题文档为准；不要在代码里静默推翻已接受 ADR。

## 1. 优先级

从高到低：

1. 数据正确与权限安全
2. 学生历史连续
3. 教师高频流程低负担
4. 保存可靠
5. 可追溯
6. 可维护
7. 零额外付费 V1 约束
8. 功能数量

本项目不是 Excel 网页化、传统填表教务系统、收费排课 CRM，也不是为了展示 AI 的 Demo。

## 2. V1 边界

教师主导航只有：
- 今日
- 学生
- 课程
- 学情

家校、报告进入 V1.1。

V1 暂不做：收费排课 CRM、大型题库、成绩预测/学情综合分、家长/学生独立 App、AI 自动正式诊断、Google Docs 式协同、复杂离线多主同步、庞大知识图谱、自助 SaaS 注册。

## 3. 不可违反的业务规则

- 同一机构一个真实学生只有一份主档案；姓名不是唯一键。
- 升年级、换老师、换班/校区必须保留历史。
- 任课教师关系与学管/班主任关系分开建模。
- 教师离职不得删除历史教学事实。
- `new` 是 10–20 秒快速捕捉草稿；不要把完整诊断表单重新塞回课中。
- `confirmed` 开始必须满足正式分类、有效 owner、最小 evidence、主行动或 pause reason。
- assessment passed 不自动等于 stable/closed。
- 周度、长期问题提示、阶段指标优先派生，不重复录入。
- “今日”由 case_actions/待验证驱动，不以完整排课为前提。
- AI 只做草稿/建议，不静默修改正式学情。

详细语义：`docs/PRODUCT.md`、`docs/USER_FLOWS.md`、`docs/COMMANDS_AND_INVARIANTS.md`。

## 4. V1 Auth 与机构权限

V1 首选 **管理员受控开通 + Password + onboarding membership**，不把 Email OTP/SMTP 作为硬依赖。

- 不开放公网自助注册。
- org_admin 通过受信任 `provision_member` 开通已知教师。
- 服务端生成高强度临时密码；绝不写入 DB、日志、audit 或 GitHub。
- 新 membership 先是 `onboarding`。
- onboarding Auth User 可以登录，但普通机构业务 RLS 必须拒绝。
- 完成 `complete_member_onboarding` 设置自己的新密码后，membership → active。
- 只有 active membership 才进入业务授权链。
- 管理员重置凭据后 membership 回 onboarding，使旧 Session 立即失去业务数据权限。
- disabled membership 即使旧 Token 尚有效也必须被 RLS 拒绝。
- 权限事实源是 membership / roles / assignments，不是 `user_metadata`。

Email OTP 可在以后有可靠邮件基础设施时替换登录 UX，但不能重写 membership 权限模型。

详细规则：`docs/AUTH_AND_PERMISSIONS.md`。

## 5. 技术边界

### Flutter
- Windows + Android 优先。
- View / ViewModel / Repository / Service 职责分层，UI 可按 feature 组织。
- Widget 不承载复杂查询、权限、事务或状态机。
- 不允许页面散落 `Supabase.instance.client.from(...)`。
- Repository/Service 必须可 fake/test。
- 优先参考 Flutter 官方 `compass_app` 的多环境、Repository/Service、测试模式；不要为架构而制造空层。

### Supabase
- PostgreSQL + Auth + Storage + RLS。
- 普通授权读写可走 Data API。
- 需要 Secret/Auth Admin 的操作走可信服务端。
- 事务性多表命令可使用受控 Database Function。
- Flutter/Supabase 测试优先 fake/local/`supabase_testing`，不让所有测试依赖 Remote Development。

### Secret
Flutter/GitHub 绝不包含：Secret Key、service_role、数据库密码、临时/正式用户密码、SMTP/AI/第三方私钥。

## 6. 环境与 Migration

必须区分：
- **Local Development**：Supabase CLI、虚构 seed、schema/RLS/tests；
- **Remote Development**：一个 Supabase Free Project，仅虚构数据，用于 Auth/Storage/Functions/Windows+Android 公网联调；
- **Production Pilot**：第二个 Supabase Free Project，真实数据前通过发布门槛。

`supabase/migrations` 是 schema / RLS / View / Function / Trigger / Index 的正式事实源。

禁止：
- 只在 Dashboard/SQL Editor 改结构而不回写 migration；
- Production 执行 development reset/seed；
- Development/Production 共用 Secret、数据库、Storage 或测试账号。

详细流程：`docs/DEVELOPMENT_WORKFLOW.md`、`docs/ZERO_COST_CLOUD_DEVELOPMENT.md`。

## 7. 数据库与权限硬规则

新增/修改业务表必须检查：
- organization_id 归属与父子机构一致性；
- RLS 开启；
- GRANT 最小；
- SELECT/INSERT/UPDATE/DELETE 分别授权；
- unauthenticated / no-membership / onboarding / disabled / cross-org / cross-subject 负面测试；
- 核心历史 FK 不意外 cascade 删除；
- RLS 高频过滤列有必要索引。

对客户端暴露 View：优先 `security_invoker = true`。

`security definer` Function：
- 放非 exposed schema；
- `set search_path = ''`；
- schema-qualified；
- revoke 默认 execute，再按需 grant；
- 有越权测试。

## 8. 事务与不变量

RLS 只回答“谁能改”，不回答“这样改是否合法”。

以下不得由 ViewModel 拼多次 CRUD：
- provision / reset / complete member onboarding
- confirm / transition / reopen case
- replace primary action
- complete lesson
- teacher handoff + disable
- merge students

受控命令至少考虑：权限、当前状态、expected_version、多表原子性、operation_id/幂等、失败恢复。

不要写：

```text
update case.status
insert event
update action
insert assessment
```

然后假设四次请求永远全部成功。

## 9. 保存、网络与并发

V1 online-first，但高频输入不能白填：
- 未保存 / 保存中 / 已保存 / 失败状态明确；
- 网络失败保留输入；
- 必要时持久化本地临时 draft；
- 简单 insert 重试复用 UUID；
- 多表 command 使用 operation id/等价幂等；
- 云端确认前不显示正式“已保存”。

关键快照使用 expected_version/乐观并发；冲突不静默覆盖。

Realtime 只增强体验，正确性不能依赖它。

## 10. 零额外付费硬约束

V1 内部试运行默认不新增现金支出的：
- SMTP/域名/SMS；
- AI API；
- 商业 UI/监控/分析 SaaS；
- GitHub Actions larger runner；
- Supabase Pro/add-ons；
- Work/Codex 额外 credits。

如果某功能声称“必须付费服务才能实现”，先提出免费替代/人工运营流程，并更新 ADR 后再决定。

达到 ChatGPT Work/Codex 方案内用量后等待重置；不要自行购买 credits。

GitHub Actions 必须控制在 Free 私有仓库额度内；重构建只在 Milestone/Release 跑。

Supabase Free Production 必须自行定期 DB dump + Storage 备份和恢复演练；不能因为免费就省略数据安全。

详细规则：`docs/ZERO_COST_CLOUD_DEVELOPMENT.md`。

## 11. ChatGPT Work / Codex 工作方式

- 一个 ChatGPT Project 作为 Xueqing 长期上下文。
- 若要在 Project 中使用 Work，不启用当前会禁用 Work 的 Project-only memory。
- GitHub 是代码事实源，聊天记忆不是。
- 一个可验收目标通常对应一条 Work 会话 + 一个 PR。
- 新会话先读取本文件与相关 docs，不复制整段旧聊天当真相。
- Work 适合研究、跨文件修改、PR/文档/复审；需要真正运行 Flutter/Supabase 命令时用 Codex 或 GitHub Actions 提供执行证据。
- 用户界面若提供 Luna + Max reasoning，优先留给 RLS、migration、事务、并发、安全、Milestone 终审；机械任务不要无脑 Max。

## 12. 隐私

开发、测试、截图、seed 只使用明显虚构数据。

不得提交真实学生/家长联系方式、试卷作文照片、家校正文、真实账号密码。

自由文本只收集必要教学事实；日志/审计不复制完整敏感正文。

仓库进入真实开发前必须改为 Private。

## 13. 开源参考规则

外部项目只借经验，不成为第二事实源。

优先级：
1. Flutter / Supabase 官方资料；
2. 本仓库 ADR 与业务不变量；
3. 成熟开源项目的模式；
4. 社区 starter。

不得直接 fork 大型学校 ERP 来“删功能”；不得因为某 starter 方便就绕过 RLS/事务/隐私规则。

参考清单：`docs/OPEN_SOURCE_REFERENCES.md`。

## 14. 测试与完成定义

数据库相关 PR 至少证明：
- Local 从空库执行 migrations + seed 成功；
- DB/RLS tests 通过；
- 未登录、无 membership、onboarding、disabled、跨机构等负面场景按预期拒绝。

业务命令至少测试：
- 合法/非法状态；
- expected_version 冲突；
- 事务/多系统中间失败；
- 重复 operation；
- 网络重试不重复副作用。

Flutter 关键 ViewModel/Repository 有单元测试；高频流程有 widget/integration 验证策略。

一个功能只有在正常路径、错误路径、权限、网络失败、测试、migration、文档都同步后才算完成。

## 15. Git / PR

- 较大功能使用 feature/review branch + PR。
- schema、migration、RLS、代码和受影响文档同 PR。
- 应用正式初始化后提交 `pubspec.lock`。
- 依赖升级单独 PR。
- 不把大重构和无关 UI 修改混在一起。
- 若改变关键方向，先更新 `docs/DECISIONS.md`。
- 不把真实 Secret/账号凭据贴进 PR/Issue。

PR 检查项见 `.github/pull_request_template.md`。