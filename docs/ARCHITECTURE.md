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
8. 零额外付费 Pilot 可运行；
9. 不提前建设微服务、复杂离线、多登录体系。

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
 Password   普通授权读写         受控业务命令
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

V1 首选管理员受控开通 + Password。

```text
org_admin provision_member
   ↓
Auth User + membership(onboarding)
   ↓
教师用临时密码登录
   ↓
Auth Session
   ↓
membership = onboarding
   ↓
只允许完成账号接管，不允许读取学生业务数据
   ↓
complete_member_onboarding
   ↓
membership = active
   ↓
roles + assignments + RLS
```

因此：
- Auth User 可以存在但没有业务权限；
- onboarding / disabled membership 都没有普通业务权限；
- active membership 才进入机构授权链；
- 用户不能通过知道 organization_id 或修改客户端状态获得权限；
- 密码重置把 membership 回到 onboarding，可切断旧 Session 的业务权限。

V1 不把 Email OTP / SMTP / deep link 作为硬依赖。未来可以替换 Auth 登录体验，但不能重写 membership/roles/assignments。

## 4. Flutter 客户端架构

采用关注点分离：View / ViewModel / Repository / Service。UI 可按 feature 组织。

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
- Repository/Service 可 fake。

Flutter 官方 `compass_app` 的多环境、Repository/Service、测试是主要工程参考；不为“Clean Architecture”制造无价值空层。

状态管理/DI 在正式 Flutter 初始化和首条垂直闭环中选择，一旦选定写 ADR，不并存多套框架。

## 5. 环境模型

### Local Development
- Supabase CLI；
- migrations / seed / DB tests；
- 虚构 Auth 用户；
- 全部虚构数据；
- 可 reset。

### Remote Development
- 一个 Supabase Free Project；
- 虚构数据；
- Windows/Android Password Auth；
- provision/onboarding/reset；
- Session、Storage、Edge Functions、公网网络测试。

### Production Pilot
- 第二个 Supabase Free Project；
- 真实数据；
- 独立 Auth / Storage / Secret；
- 不运行开发 seed/reset；
- 只执行已评审 migrations；
- 定期自行 DB dump + Storage 备份。

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

禁止长期依赖 Dashboard/Table Editor/SQL Editor 手工状态。

## 7. Data API 与受控命令

### Data API 适合
- 有权数据读取；
- 简单 evidence / note 等单事实追加；
- `new` 轻量草稿；
- 普通查询。

前提：RLS + GRANT + FK/约束正确。

### Database Function 适合
需要数据库事务一致性的多表命令：
- confirm/reopen/transition case；
- complete_lesson；
- handoff；
- merge_students。

### Edge Function / 可信服务端适合
需要 Secret/Auth Admin 或跨系统编排：
- provision_member；
- complete_member_onboarding；
- reset_member_credential；
- 未来邮件/AI/外部系统集成。

Auth Admin 与 PostgreSQL 不是同一事务域，credential 命令必须设计安全的步骤顺序、幂等和失败恢复；不假装“调用一个 Edge Function 就天然原子”。

不要把所有请求机械塞进 Edge Function，也不要把所有逻辑写进 Flutter。

## 8. 零成本认证运行边界

临时密码：
- 服务端随机生成；
- provision/reset 成功后只返回一次；
- 不进 DB/log/audit/error tracking；
- 不使用固定弱默认密码。

onboarding：
- 可以登录 Auth；
- 普通业务 RLS 拒绝；
- 只允许最小账号接管能力。

reset：
- Auth 密码更新；
- membership → onboarding；
- 旧 Session 因非 active membership 失去业务访问。

Email OTP 在未来有可靠 SMTP 时再评估，不是 V1 发布门槛。

## 9. RLS、GRANT、View 与函数安全

所有客户端业务表默认：
- RLS 开启；
- 最小 GRANT；
- SELECT/INSERT/UPDATE/DELETE 分别测试；
- 跨机构默认拒绝；
- 进一步检查 membership = active、role、assignment。

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
- onboarding member 不被错误激活；
- A 机构子表不引用 B 机构父表；
- confirmed case 真有 evidence/owner/action；
- closed case 没有冲突 pending action；
- complete_lesson 不半成功；
- provision/reset 的跨系统步骤安全收敛。

因此还需要 composite FK、CHECK、partial unique index、trigger、事务命令和受控 Edge Function。

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

V1 严格控制大附件，1 GB Free Storage 不是无限素材库。

## 14. 日志与可观测性

可记录：operation id、错误类别、App version、必要非敏感 object id。

禁止记录：Password、临时凭据、Access/Refresh Token、Secret、完整学生正文、家校正文、作文/试卷全文。

生产要能定位“哪类操作失败”，不能靠泄露学生内容调试。

## 15. Windows / Android 职责

### Windows
- 学生全景；
- 深度案例；
- 管理员成员开通/治理；
- 批量查看；
- 后续报告/教研。

### Android
- 登录/Session；
- 今日；
- 学生重点；
- 快速课程；
- 快速证据/干预/验证/new 草稿；
- 30–60 秒课后记录。

两端共享同一业务模型和 API；不是把手机布局简单拉宽/缩小。

## 16. 测试架构

### Flutter Unit
- fake repositories；
- ViewModel；
- 状态机；
- 失败映射。

### Supabase Client Testing
正式工程初始化后评估 Supabase 官方 `supabase_testing`：mock HTTP/JWT/Auth Session/Realtime 等，减少 Remote Development 依赖。

### Local Supabase
- migrations；
- RLS；
- DB functions；
- constraints；
- negative tests。

### Remote Development
只验证 Local 不能证明的公网/跨设备/Auth Admin/Storage/Edge Function 行为。

## 17. ChatGPT 云端开发架构

```text
ChatGPT Project / Work
  ↓ GitHub connector
GitHub branch / PR
  ↓
GitHub Actions / Codex execution evidence
  ↓
Review / Merge
```

规则：
- GitHub 不是 Work 的附件副本，而是真实仓库；
- 一个目标通常一条 Work 会话 + 一个 PR；
- Work 不能运行某命令时必须标记未验证；
- GitHub Actions/Codex 负责真实 build/test 证据；
- 达到方案内用量后等待重置，不自动购买 credits。

## 18. 不采用的架构

V1 不采用：
- 每个老师一份数据库人工同步；
- 微服务集群；
- 全系统 Event Sourcing；
- CRDT offline-first；
- 所有请求都绕 Edge Function；
- 全部业务逻辑放 Flutter 或全部放 Trigger；
- 远程 Dashboard 作为 schema 事实源；
- Email OTP / Magic Link / Password 多套主登录并存；
- 需要付费 SMTP/SMS 才能登录；
- fork 大型教育 ERP 作为起点。

## 19. 上线前技术门槛

- GitHub 已 Private；
- migrations 从空库重建；
- RLS/GRANT/View/Function 测试；
- Auth User 无 active membership 无业务权限；
- onboarding/disabled 旧 Session 无业务权限；
- Windows/Android provision/onboarding/reset 真测；
- 临时密码不落日志/数据库；
- 网络失败恢复；
- DB dump + 实际恢复演练；
- Storage 恢复方案；
- Free Tier 使用量适合 Pilot；
- 客户端安装/更新路径；
- 真实机构网络验证；
- GitHub Actions/云端开发没有自动超额付费路径。