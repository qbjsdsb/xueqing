# 系统架构

## 1. 架构目标

V1 的技术架构优先保证：

1. 多机构数据严格隔离；
2. 多教师共享同一学生事实源；
3. 权限在数据库/服务端真正执行；
4. 教师高频操作足够快且保存可靠；
5. 历史可追溯，人员变化不破坏数据；
6. 代码可测试、可迁移、可持续由 Codex/开发者维护；
7. 不为“未来可能有的复杂功能”提前堆叠微服务；
8. Supabase 是 V1 基础设施选择，但业务代码不与具体 SDK 到处耦合；
9. 数据库 schema 和权限状态能够从 Git 中的 migration 可重复重建。

## 2. 总体架构

```text
┌─────────────────────────────────────────────┐
│ Flutter Client                              │
│ Windows（深度管理） / Android（快速记录）   │
└───────────────┬─────────────────────────────┘
                │
        ┌───────┴────────┐
        │                │
        ▼                ▼
普通授权业务读写      高权限/受控操作
Supabase Data API     Edge Functions / DB Functions
        │                │
        └───────┬────────┘
                ▼
┌─────────────────────────────────────────────┐
│ Supabase                                    │
│ Auth | PostgreSQL | RLS | Storage           │
└─────────────────────────────────────────────┘
```

GitHub 保存源码、数据库 migrations、测试、Issue、PR 与 CI；真实业务数据不进入 GitHub。

## 3. Flutter 客户端架构

采用 Flutter 官方当前推荐的关注点分离：UI 与 Data 分层，主要使用 View / ViewModel / Repository / Service；只有复杂业务确有需要时才增加 Domain Use Case。

建议 feature-first：

```text
lib/
  app/
    app.dart
    config/
    routing/
    theme/
  core/
    auth/
    errors/
    logging/
    persistence/
    utils/
  features/
    auth/
      data/
      presentation/
    today/
      data/
      presentation/
    students/
      data/
      presentation/
    learning_cases/
      data/
      presentation/
    lessons/
      data/
      presentation/
```

约束：
- Widget 不直接拼复杂数据库查询；
- ViewModel 负责 UI state 与用户动作；
- Repository 是应用数据与业务行为的入口；
- Service 封装 Supabase、Storage、Edge Function、本地草稿等外部接口；
- Repository/Service 应提供可替换接口，便于测试和未来迁移；
- 不允许业务代码在多个页面散落 `Supabase.instance.client.from(...)`；
- 状态机与权限判断不得在不同页面各写一套。

## 4. 依赖注入与状态管理

Phase 0 不为了“流行”先引入复杂框架。

最低要求：
- Repository / Service 通过构造器或明确容器注入；
- ViewModel 不直接 new 生产网络客户端；
- 测试可替换 fake repository；
- App-wide Session / Current Organization 有单一事实源。

状态管理库在正式 Flutter 初始化时结合首条垂直闭环决定；一旦选择应写入 ADR，不允许多套框架并存。

## 5. 开发环境与数据库事实源

至少区分三种语境：

### Local Development
用于 schema、RLS、View、Function、Trigger、Index 和数据库测试的主要开发环境。

正式初始化后仓库应包含 `supabase/` 目录：

```text
supabase/
  config.toml
  migrations/
  seed.sql
  tests/
  functions/
```

**Git 中的 migrations 才是数据库结构的正式开发事实源。**

本地流程应能够从空库运行 migration + 虚构 seed，重建当前开发 schema。

### Remote Development
独立 Supabase Project，仅使用虚构数据，负责本地环境难以完全覆盖的集成验证：
- Windows / Android 同一云端数据；
- Auth 邮件邀请、密码恢复；
- redirect / deep link；
- Storage；
- Edge Functions；
- 公网延迟、Session 与多设备。

Remote Development 不是 schema 的第二事实源。任何远程临时 schema 试验最终都必须回到 migration。

### Production
- 真实机构数据；
- 独立 Supabase Project；
- 独立 Auth / Storage / Secret；
- 只执行经过评审和测试的 migration；
- 禁止开发 seed 和测试 reset。

后期确有发布链路需要时再增加 Staging。

详细工作流见 `DEVELOPMENT_WORKFLOW.md`。

## 6. Flutter 配置边界

客户端公开配置（Supabase URL、Publishable Key、App Env、App Version 等）通过 typed `AppConfig` + build-time define/CI 注入。

不要为了隐藏本来就公开的 Publishable Key 引入“假安全”的客户端加密方案。

**Secret Key、service_role、数据库密码、AI 私钥、邮件服务 Secret 永远只存在受信任服务端环境。**

## 7. Data API 与受控服务端操作

### Data API 适合
- 教师读取本人有权学生；
- CRUD 学情案例/证据/干预/验证/行动；
- 读取今日待办；
- 普通课程记录。

前提：RLS + GRANT + 数据一致性约束都正确。

### Edge Functions 适合
- Auth Admin 邀请/创建/停用账号；
- 高权限角色变更；
- 调用邮件/AI/第三方服务；
- 需要 Secret 的操作。

### Database Functions 适合
- 数据密集、需要事务一致性的受控操作；
- 学生合并；
- 批量交接；
- 多表状态迁移；
- 复杂派生查询。

数据库函数默认 `security invoker`；确实需要 `security definer` 时必须：
- 放在非 exposed schema；
- `set search_path = ''`；
- 所有表名 schema-qualified；
- 显式 revoke/grant execute；
- 有越权测试。

不要把所有高权限业务都机械塞进 Edge Function，也不要把所有逻辑都堆进数据库。

## 8. RLS 与 View 安全

所有客户端可访问业务表默认：
- 启用 RLS；
- 最小 GRANT；
- 分别测试 SELECT / INSERT / UPDATE / DELETE；
- 跨机构默认拒绝；
- 进一步检查角色、学生关系、学科关系。

RLS 高频使用的成员、机构、assignment 条件必须建立合适索引。

如果通过 View 给客户端提供“今日”“周度摘要”等派生数据，必须明确 View 的权限语义。在支持的 PostgreSQL 版本上，暴露 View 优先使用 `security_invoker = true`，让底层 RLS 生效；否则放进不暴露 schema 或通过受控函数提供。

## 9. 数据一致性：不能只靠 RLS

RLS 决定“谁能访问”，但不替代业务一致性。

例如必须防止：
- A 机构 case 关联 B 机构 evidence；
- A 机构 lesson 写入 B 机构 teacher membership；
- 语文学情案例引用数学 taxonomy node；
- 已 closed 案例仍存在冲突的主行动。

因此 schema 还需要外键、组合约束、部分唯一索引、触发器或事务函数。

## 10. 保存可靠性与最小本地持久化

V1 是 online-first，不做复杂多主离线同步，但必须保护教师输入。

推荐模型：

```text
教师输入
  ↓
本地 draft / in-memory + persistence
  ↓
提交请求
  ↓
云端事务成功
  ↓
标记 synced / 清理草稿
```

要求：
- 页面明确显示保存状态；
- 短暂断网/超时不清空输入；
- App 意外退出后，高频长表单可以恢复草稿；
- 重试必须避免重复创建（使用 client operation id / idempotency 设计）；
- 云端未确认前不假装“已保存”。

本地草稿不是第二个业务事实源，只是待提交缓存。

## 11. 并发

V1 不做同字段实时协同编辑。

关键当前状态对象可使用 `version` / `updated_at` 乐观并发：
- 更新时携带已读版本；
- 版本不匹配则拒绝静默覆盖；
- UI 提示刷新并重新确认。

追加型事件/干预/验证天然更适合多人协作，尽量减少多人覆盖同一长文本字段。

## 12. Realtime 定位

**V1 正确性不能依赖 Realtime。**

先做到：
- 提交后本地刷新；
- 页面重新进入刷新；
- App resume 刷新；
- 手动刷新可用。

Realtime 只用于“别人刚更新了”的提示和体验增强。

后续若需要高频实时通知，优先评估 Supabase Broadcast/private channels；不要为了看起来“实时”就给大量表默认打开 Postgres Changes。

## 13. 网络与后端可迁移性

真实机构上线前必须在实际使用网络环境测试：
- 登录可达性；
- 常规查询延迟；
- 图片上传；
- Edge Function；
- 长时间会话；
- 网络切换后的恢复。

Repository/Service 边界应保证：如果未来因为网络、部署地区、合规或成本原因需要替换部分后端，不需要重写全部 UI 和领域逻辑。

这不是现在就做“多后端”，而是避免业务层直接绑定 Supabase 表查询细节。

## 14. Storage

附件默认私有 bucket。

建议路径：

```text
{organization_id}/{student_id}/{object_type}/{uuid}.{ext}
```

要求：
- 不用真实姓名作为对象路径；
- 客户端通过授权访问或短时签名 URL；
- DB 只保存 object path 与必要 metadata；
- 删除数据库记录与 Storage 对象需要受控一致性流程；
- 备份方案必须单独覆盖 Storage，因为数据库备份不等于附件备份。

## 15. 日志与可观测性

日志可记录：
- operation id；
- 错误类型；
- 页面/动作；
- App version；
- 非敏感对象 ID（按实际需要）。

禁止记录：
- 密码/Token/Secret；
- 完整家校沟通正文；
- 完整作文/试卷；
- 不必要的学生个人信息。

生产错误必须能定位“哪类操作失败”，但不能靠泄露学生内容来调试。

## 16. Flutter 平台职责

### Windows
偏向：
- 学生全景；
- 深度案例管理；
- 管理员操作；
- 批量查看；
- 报告与教研。

### Android
偏向：
- 今日；
- 查看学生重点；
- 快速开始课程；
- 快速证据/干预/验证；
- 课后 30–60 秒记录。

两端共享同一业务模型和 API，不维护两套规则。

## 17. 不采用的架构

V1 明确不采用：
- 每个老师一份本地数据库再人工同步；
- 自建微服务集群；
- Event Sourcing 全系统化；
- 复杂 offline-first CRDT；
- 所有请求都绕 Edge Function；
- 所有业务逻辑都写在 Flutter；
- 所有业务逻辑都写成数据库 trigger；
- 以远程 Dashboard 当前状态作为不可追溯的 schema 事实源。

## 18. 上线前技术门槛

正式真实数据上线前必须完成：
- migration 从空库重建；
- RLS/GRANT 自动化测试；
- View/Function 权限审计；
- 密钥扫描；
- 网络失败保存恢复；
- Windows/Android 登录与更新路径；
- 数据库恢复演练；
- Storage 恢复方案；
- 真实机构网络可用性验证。