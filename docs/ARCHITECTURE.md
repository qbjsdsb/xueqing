# 系统架构

## 1. 架构目标

V1 优先保证：

1. 多机构严格隔离；
2. 多教师共享同一学生事实源；
3. Auth 登录与机构授权分离；
4. 权限在数据库/服务端真正执行；
5. 教师高频操作快且保存可靠；
6. 历史连续、可追溯；
7. schema 可从 Git migrations 重建；
8. 不提前建设微服务、复杂离线、多登录体系。

## 2. 总体架构

```text
┌──────────────────────────────────────────────┐
│ Flutter Client                               │
│ Windows（深度管理） / Android（快速记录）    │
└───────────────┬──────────────────────────────┘
                │
        ┌───────┼─────────────────────┐
        │       │                     │
        ▼       ▼                     ▼
 Email OTP   普通授权读写         受控业务命令
Supabase Auth Data API            DB/Edge Functions
        │       │                     │
        └───────┴──────────┬──────────┘
                           ▼
┌──────────────────────────────────────────────┐
│ Supabase                                     │
│ Auth | PostgreSQL | RLS | Storage            │
└──────────────────────────────────────────────┘
```

GitHub 保存源码、migrations、tests、CI 和文档；真实业务数据不进入 GitHub。

## 3. Auth 与业务授权链

V1 首选 Email OTP。

```text
邮箱 OTP 验证成功
   ↓
Auth Session
   ↓
是否有 active organization_membership？
   ├─ 有 → 根据 roles / assignments / RLS 进入机构
   └─ 无 → 是否有 verified-email 匹配的 pending invitation？
             ├─ 有 → accept_invitation → membership + roles
             └─ 无 → 只显示“尚未获得机构授权”
```

因此：
- Auth User 可以存在但没有业务权限；
- pending invitation 也没有业务权限；
- active membership 才进入机构授权链；
- 用户不能通过知道 organization_id 或修改客户端状态获得权限。

OTP 登录本身由 Supabase Auth 处理；机构 invitation 是我们自己的业务对象，不把 Supabase Invite Link 当作 V1 核心 onboarding。

## 4. Flutter 客户端架构

采用关注点分离：View / ViewModel / Repository / Service，feature-first。

```text
lib/
  app/
    config/
    routing/
    theme/
  core/
    auth/
    errors/
    logging/
    persistence/
  features/
    auth/
    today/
    students/
    learning_cases/
    lessons/
```

约束：
- Widget 不拼复杂数据库查询；
- ViewModel 不直接依赖生产 Supabase client；
- Repository 暴露业务 API；
- Service 封装 Auth/Data API/Storage/Functions/本地草稿；
- Session / Current Organization 有单一事实源；
- 状态机和权限不能散落在多个页面各写一套；
- Repository/Service 可 fake，便于测试。

状态管理/DI 在正式 Flutter 初始化并做首条垂直闭环时选择，一旦选定写 ADR，不并存多套框架。

## 5. 环境模型

### Local Development
- Supabase CLI；
- migrations / seed / DB tests；
- Mailpit 检查 OTP 邮件模板；
- 全部虚构数据；
- 可以 reset。

### Remote Development
- 独立 Supabase Project；
- 虚构数据；
- Windows/Android Email OTP 真实投递；
- Session、invitation→membership、Storage、Edge Functions、公网网络测试。

### Production
- 独立 Project；
- 真实数据；
- 独立 Auth / Storage / Secret / SMTP；
- 不运行开发 seed/reset；
- 只执行已评审 migrations。

Remote Development 不是 schema 的第二事实源。

## 6. 数据库正式事实源

仓库应包含：

```text
supabase/
  config.toml
  migrations/
  seed.sql
  tests/
  functions/
```

Schema、RLS、GRANT、View、Function、Trigger、Index 的正式变化都进入 migrations。

禁止长期依赖 Dashboard/Table Editor/SQL Editor 的手工状态。

## 7. Data API 与受控命令

### Data API 适合
- 有权数据读取；
- 简单 evidence / note 等单事实追加；
- 普通查询。

前提是 RLS + GRANT + FK/约束正确。

### Database Function 适合
需要事务一致性的多表业务命令：
- accept_invitation；
- confirm/reopen/transition case；
- complete_lesson；
- handoff；
- merge_students。

### Edge Function 适合
需要 Secret 或第三方服务的操作：
- 自定义邮件通知（若未来需要）；
- AI；
- 外部系统集成；
- Auth Admin 维护类动作。

不要把所有请求机械塞进 Edge Function，也不要把所有逻辑写进 Flutter。

## 8. Email OTP 运行边界

Production Email OTP 必须被视为关键基础设施：
- Email template 输出验证码 token；
- Remote Development 验证真实投递；
- Production 使用可靠 Custom SMTP / 等价邮件服务；
- Auth rate limits 和必要的 CAPTCHA/滥用防护配置；
- OTP 错误、过期、429 有可理解 UX；
- SMTP Secret 仅服务端保存。

V1 不并行维护 Password / Magic Link / OTP 三套主登录流程。

## 9. RLS、GRANT、View 与函数安全

所有客户端业务表默认：
- RLS 开启；
- 最小 GRANT；
- SELECT/INSERT/UPDATE/DELETE 分别测试；
- 跨机构默认拒绝；
- 进一步检查 active membership、role、assignment。

### View
客户端暴露的派生 View 优先 `security_invoker = true`；否则放非 exposed schema 或受控函数。

### Function
默认 `security invoker`。

必须 `security definer` 时：
- 放非 exposed schema；
- `set search_path = ''`；
- schema-qualified；
- revoke 默认 execute；
- 最小 grant；
- 写越权测试。

RLS 高频过滤字段建立适当索引。

## 10. RLS 不替代业务一致性

RLS 回答“谁能访问”，但不能保证：
- invitation 被正确邮箱接受；
- A 机构子表不引用 B 机构父表；
- confirmed case 真有 evidence/owner/action；
- closed case 没有冲突 pending action；
- complete_lesson 不半成功。

因此还需要 composite FK、CHECK、partial unique index、trigger 或事务命令。

详细不变量见 `COMMANDS_AND_INVARIANTS.md`。

## 11. 保存可靠性

V1 online-first，但高频输入有最小本地持久化：

```text
教师输入
  ↓
本地 draft / memory + persistence
  ↓
提交
  ↓
云端确认
  ↓
标记 synced / 清理草稿
```

要求：
- 保存状态可见；
- 断网/超时不清空输入；
- App 异常退出后关键草稿可恢复；
- 简单 insert 重试复用 UUID；
- 多表命令使用 operation id/等价幂等；
- 云端未确认前不假装已保存。

本地草稿不是第二业务事实源。

## 12. 并发与 Realtime

关键快照可用 `version / expected_version` 乐观并发。

版本冲突：拒绝静默覆盖，刷新并让用户重新确认。

V1 正确性不依赖 Realtime：页面进入、提交后、App resume、手动刷新必须足够保证正确；Realtime 只做体验增强。

## 13. Storage

附件默认私有 bucket。

建议路径：

```text
{organization_id}/{student_id}/{object_type}/{uuid}.{ext}
```

- 不用真实姓名做路径；
- 授权访问/短时签名 URL；
- DB 保存 object path + metadata；
- DB 删除与 Storage 删除走受控流程；
- DB 备份不等于 Storage 备份。

## 14. 日志与可观测性

可记录：operation id、错误类别、App version、必要非敏感 object id。

禁止记录：OTP、Access/Refresh Token、Secret、完整学生正文、家校正文、作文/试卷全文。

生产要能定位“哪类操作失败”，不能靠泄露学生内容调试。

## 15. Windows / Android 职责

### Windows
- 学生全景；
- 深度案例；
- 管理员治理；
- 批量查看；
- 后续报告/教研。

### Android
- OTP 登录；
- 今日；
- 学生重点；
- 快速课程；
- 快速证据/干预/验证/new 草稿；
- 30–60 秒课后记录。

两端共享同一业务模型和 API。

## 16. 不采用的架构

V1 不采用：
- 每个老师一份数据库人工同步；
- 微服务集群；
- 全系统 Event Sourcing；
- CRDT offline-first；
- 所有请求都绕 Edge Function；
- 全部业务逻辑放 Flutter 或全部放 Trigger；
- 远程 Dashboard 作为 schema 事实源；
- 同时维护 Password/Magic Link/OTP 多套主登录方式。

## 17. 上线前技术门槛

- migrations 从空库重建；
- RLS/GRANT/View/Function 测试；
- Auth User 无 membership 无权限；
- pending invitation 无权限；
- Windows/Android OTP 真实投递验证；
- Production 邮件基础设施和限流策略；
- 网络失败恢复；
- DB 恢复演练；
- Storage 恢复方案；
- 客户端安装/更新路径；
- 真实机构网络验证。