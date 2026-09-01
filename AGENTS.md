# AGENTS.md

本文件约束 Codex 与后续开发者在本仓库中的实现方式。它不是建议清单，而是项目默认工程规则。

## 1. 产品北极星

本项目是“机构教学协作与学生成长闭环系统”。

优先级从高到低：
1. 数据正确与权限安全；
2. 学生历史连续；
3. 教师高频工作流低负担；
4. 保存可靠；
5. 可追溯；
6. 可维护；
7. 功能数量。

不得把产品退化成 Excel 网页化、传统教务填表系统、排课收费 CRM，或为了展示 AI 而堆功能的 Demo。

## 2. 业务不可变约束

1. 同一机构内一个真实学生只有一份主档案。
2. 学生姓名不是唯一标识。
3. 升年级、换老师、换班/校区不能覆盖历史。
4. 任课教师关系与学管/班主任关系分开建模。
5. 教师离职/停用不得删除其历史教学记录。
6. 学情案例必须拥有可追溯生命周期。
7. 原始事实只录一次；周度、顽固问题、阶段摘要优先派生。
8. 未结束案例必须支持明确主行动或明确暂停理由。
9. “能看”与“能改”必须分离。
10. 跨学科默认有限共享，不默认全部开放。
11. 一次 assessment passed 不自动等于案例 stable/closed。
12. AI 不得静默修改正式学情状态。
13. “今日”不能在没有明确需求的情况下扩张成排课 CRM。
14. 数据库结构与权限变化必须进入 migration，不能依赖远程 Dashboard 隐性状态。

如果实现要求违反这些约束，先修改产品/架构文档并说明理由，再改代码。

## 3. V1 范围

V1 教师主导航只有：
- 今日
- 学生
- 课程
- 学情

家校、报告进入 V1.1。

不要为了“界面看起来完整”提前塞入占位但半可用的大模块。

## 4. 技术边界

### 客户端
- Flutter，Windows + Android 优先。
- 使用 View / ViewModel / Repository / Service 职责分层。
- 目录优先 feature-first。
- Widget 不直接承载复杂数据库、权限和状态机逻辑。
- 不允许在各页面散落 `Supabase.instance.client.from(...)`。

### 云端
- Supabase PostgreSQL + Auth + Storage + RLS。
- 普通授权业务可通过 Data API。
- Auth Admin / Secret 操作走 Edge Functions。
- 数据密集且需要事务一致性的受控操作可使用 Database Functions。

### 密钥
Flutter 只允许 Publishable Key（或旧项目 anon key）。

绝对禁止以下内容进入客户端或 GitHub：
- Secret Key
- legacy service_role key
- 数据库密码
- 私密 AI API key
- 邮件/第三方服务 Secret

## 5. 环境与数据库工作流

必须区分：

### Local Development
- 使用 Supabase CLI；
- 只使用虚构数据；
- 用于 schema / RLS / View / Function / Trigger / Index 开发与数据库测试；
- 能执行 `supabase db reset` 从 migrations + seed 重建当前开发数据库。

### Remote Development
- 独立 Supabase Project；
- 只使用虚构数据；
- 用于 Auth 邮件、redirect/deep link、Storage、Edge Functions、Android + Windows 双设备和公网联调；
- 不能成为 schema 的第二事实源。

### Production
- 独立 Supabase Project；
- 真实数据；
- 独立 Auth / Storage / Secret；
- 禁止 development seed/reset；
- 只执行已经评审和测试过的 migrations。

不得让 Development 与 Production 共用数据库、Storage、Secret 或测试账号。

公开客户端配置通过 typed AppConfig + build-time config 注入；不要引入“把 Publishable Key 藏起来”的假安全方案。

详细流程见 `docs/DEVELOPMENT_WORKFLOW.md`。

## 6. 数据库规则

### Schema 变更
- 所有正式 schema 变更必须通过版本化 migration。
- `supabase/migrations` 是 schema / RLS / View / Function / Trigger / Index 的正式开发事实源。
- 不允许只在 Dashboard/SQL Editor 手工改表或 policy 而不回写 migration。
- 如果为了试验临时改了 Remote Development，最终必须转成 migration，并从干净本地数据库重新验证。
- destructive migration 必须说明迁移与恢复策略。
- 高风险结构变化优先采用 expand → migrate → contract，避免一步破坏旧客户端。

### 多租户
新增机构业务表时默认检查：
- 是否能确定 organization_id；
- 子表 organization_id 是否能和父表保持一致；
- RLS 是否开启；
- GRANT 是否最小；
- SELECT / INSERT / UPDATE / DELETE 是否分别授权；
- 是否会跨机构泄漏；
- 是否需要师生/学科关系检查。

### 引用用户
业务表优先引用 organization_membership_id，而不是只保存 user_id，以保留机构语境。

### 时间与 ID
- 主键默认 UUID；
- 时间用 timestamptz；
- 纯日期使用 date；
- 数据库保存 UTC；
- 系统 created_at/updated_at 优先服务器生成；
- 升年级/交接使用历史关系表。

### 历史
- `case_events`：教学案例生命周期，append-only；
- `audit_logs`：系统治理与高风险修改，append-only。

不要把二者混为一张“大日志表”。

## 7. 分类数据

为了长期统计：
- 学情案例优先引用受控 taxonomy node；
- title/description 保留自由表达；
- 不用自由文本作为唯一统计口径；
- 首版提供少量稳定默认分类与“其他/暂未分类”；
- 不为了 taxonomy 先建设庞大知识图谱或复杂配置后台。

## 8. Auth 与账号边界

- 机构权限来自 membership / roles / assignments，不来自 user_metadata。
- 首位 org_admin 通过一次性受控 bootstrap，不在客户端藏超级管理员 Secret。
- 邀请/密码恢复的 redirect 必须由服务端按环境选择 allowlisted URL，不接受客户端任意 URL。
- 邀请过期重发不能产生重复 membership。
- 已确认 Auth 用户不能被简单当成“新邮箱再次 invite”；如果 V1 尚未开放跨机构 link-existing-user，应明确拒绝/提示，不用重复 Auth User 绕过去。
- membership disabled 后，即使旧 Token 尚有效，RLS 仍必须拒绝机构数据。

具体见 `docs/AUTH_AND_PERMISSIONS.md`。

## 9. RLS、View 与函数安全

任何新业务表在“可用”之前至少验证：
1. 未登录不能访问；
2. disabled membership 不能访问；
3. 同机构无关系用户是否应该可见；
4. 本科教师查看/编辑是否正确；
5. 其他学科是否只得到允许信息；
6. 管理员权限是否符合预期；
7. 跨机构访问必定失败；
8. DELETE 是否真的需要开放。

禁止只靠 Flutter 隐藏按钮实现权限。

### View
对客户端暴露的派生 View 必须显式检查 RLS 语义；优先 `security_invoker = true`。

### Function
- 默认 `security invoker`；
- `security definer` 必须放非 exposed schema；
- `set search_path = ''`；
- 名称 schema-qualified；
- revoke 默认执行权限后按需 grant；
- 有越权测试。

RLS 高频过滤列必须考虑索引。

## 10. 不变量敏感命令

RLS 只解决“谁能改”，不能单独解决“这样改是否合法”。

以下操作不得在 ViewModel 里拼多次 CRUD 或直接随便更新 status：
- confirm/transition/reopen learning case；
- 替换当前主 case_action；
- complete lesson；
- 教师交接；
- 学生合并；
- 停用成员并转交当前责任。

这些操作优先通过 Repository 暴露业务命令，并在数据库事务/受控函数中再次验证：
- 当前状态；
- 权限；
- expected version；
- 多表一致性；
- operation id / 幂等。

不要写出这种页面级逻辑：

```text
update learning_cases.status
insert case_events
update case_actions
insert assessment
```

然后假定四个请求永远全部成功。

具体规则见 `docs/COMMANDS_AND_INVARIANTS.md`。

## 11. 高权限操作

以下默认不能从 Flutter 直接用高权限凭据完成：
- 首位 org_admin bootstrap；
- 邀请 Auth 用户；
- 授予管理员/高权限角色；
- 合并学生；
- 跨教师批量交接；
- 受控导出/删除；
- 绕过 RLS 的维护。

Edge/Database Function 也必须验证调用者 Session、机构与权限。

## 12. Flutter 开发原则

- 优先小而完整的垂直闭环。
- 页面状态与业务状态分开。
- Repository 暴露面向业务的 API，不让页面知道具体表结构。
- Service 封装 Supabase/Storage/Functions/本地草稿等外部接口。
- Repository/Service 应可 fake，便于测试。
- 状态机转移集中管理，不允许不同页面各自猜测下一状态。
- 错误必须能转成用户可理解的信息。
- 高频路径优先减少输入和点击。
- 重要状态不能只依赖颜色表达。
- 添加第三方依赖前先说明解决了什么问题；不为“流行”引包。
- 状态管理/DI 方案一旦选定写 ADR，不允许多个框架无序混用。

## 13. 保存可靠性

V1 online-first，但“网络失败不丢当前输入”是硬要求。

高频编辑必须：
- 展示未保存/保存中/已保存/失败；
- 网络失败保留输入；
- 必要时本地持久化临时 draft；
- 简单 insert 重试复用同一 client-generated UUID；
- 多表命令考虑 operation id / idempotency；
- 云端成功前不显示为正式已保存。

本地 draft 不是第二套业务数据库。

## 14. 并发与 Realtime

- 关键当前状态对象可使用 `version` 乐观并发；
- command 携带 expected_version；
- 冲突时不静默覆盖；
- 追加型事实优先追加而不是覆盖长文本；
- V1 正确性不能依赖 Realtime；
- Realtime 只做体验增强；
- 不实现 Google Docs 式同字段协作。

## 15. 隐私

禁止提交真实：
- 学生姓名与联系方式；
- 家长姓名/联系方式；
- 真实试卷、作文、照片；
- 家校沟通正文；
- 机构内部真实账号密码。

开发 seed、截图、测试全部使用明显虚构数据。

自由文本避免收集与教学目的无关的家庭、健康、身份等敏感信息。

日志与审计不要复制完整敏感正文。

## 16. 测试最低要求

### 数据库可复现
- 从空 Local DB 跑 migrations 成功；
- 虚构 seed 成功；
- DB/RLS tests 成功；
- 不依赖某个远程 Dashboard 手工状态。

### 业务逻辑
- 状态机；
- 非法状态跳转拒绝；
- stable / closed / reopen；
- 主行动唯一性/暂停理由；
- 教师交接；
- 派生指标；
- expected_version 冲突；
- 网络失败重试与防重复提交；
- 多表事务中间失败不留半套数据。

### 权限
至少覆盖：
- 跨机构拒绝；
- 同机构不同角色；
- 不同学科；
- 停用 membership；
- View/Function 越权；
- 高权限操作拒绝普通教师。

### Flutter
重要 ViewModel / Repository 有单元测试；关键高频流程至少有 widget/integration 验证策略。

## 17. UI 原则

- “今日”优先展示下一步，而不是统计大屏。
- V1 今日以 case_actions/待验证为主，不假设完整排课存在。
- 学生主页先展示当前重点与连续时间线。
- 表格只用于真正适合批量管理的场景。
- 手机端优先快速记录；Windows 端优先深度查看和管理。
- 不制造没有可靠依据的“学情健康分”。
- 保存状态必须明确可见。

## 18. Git 与提交

较大功能应：
- 使用 feature/review branch；
- 小步提交；
- 清楚的 commit message；
- schema 与代码同 PR；
- migration 与 RLS policy 同步；
- 文档受影响时同步更新。

不要把大规模重构和无关 UI 修改混在一个提交里。

`main` 进入真实开发后应以 PR 合并为主，不长期直接写入。

应用项目正式初始化后提交 `pubspec.lock`；CI 使用明确 Flutter stable 版本，不依赖 runner 当前偶然版本。

## 19. 完成定义

一个功能只有同时满足以下条件才算完成：
- 正常路径可用；
- 错误/空状态可理解；
- 网络失败路径可恢复；
- 权限验证通过；
- 不变量敏感写入有事务/命令保障；
- 关键逻辑有测试；
- migration 可从空库执行；
- Remote Development 集成场景需要时已验证；
- 不含真实隐私和秘密；
- 文档同步；
- 不破坏既有端到端场景。

## 20. V1 暂不做

- 排课收费 CRM
- 大型题库
- 成绩预测
- 学情综合分
- AI 自动正式诊断
- 家校/报告一级模块（V1.1）
- 家长独立 App
- 学生独立 App
- Google Docs 式协同编辑
- 复杂离线同步
- 大量第三方登录
- 复杂多机构账号切换/自助加入 UX

如需改变范围，先更新 `docs/PRODUCT.md`、`docs/ROADMAP.md` 与必要 ADR。