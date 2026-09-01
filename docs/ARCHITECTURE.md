# 系统架构

## 1. 架构目标

V1 的技术架构优先保证：

1. 多机构数据严格隔离；
2. 多教师共享同一学生事实源；
3. 权限在数据库/服务端真正执行；
4. 教师高频操作足够快；
5. 历史可追溯，人员变化不破坏数据；
6. 代码可测试、可迁移、可持续由 Codex/开发者维护；
7. 不为“未来可能有的复杂功能”提前堆叠微服务。

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
Supabase Data API     Supabase Edge Functions
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

采用 Flutter 官方当前推荐思路：**UI 与 Data 分层，使用 View / ViewModel / Repository / Service 的职责边界；只有业务复杂到确有需要时再增加 Domain Use Case 层。**

建议目录按 feature 组织：

```text
lib/
  app/
    app.dart
    routing/
    theme/
  core/
    auth/
    errors/
    logging/
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
- ViewModel 负责界面状态和用户动作；
- Repository 是业务数据入口；
- Service 封装 Supabase、Storage、Edge Function 等外部接口；
- 状态机和权限判断不得散落在多个页面里各写一套。

V1 暂不为了“架构漂亮”引入过多抽象层。

## 4. 客户端与服务端边界

### 4.1 Flutter 可以直接做的事
使用 Supabase Publishable Key + 用户 Session，通过 Data API 访问经过 RLS 保护的普通业务数据，例如：
- 读取本人有权查看的学生；
- 新建/更新本科负责范围内的学情案例；
- 记录课程、干预、验证和观察；
- 读取今日待办。

Publishable Key 可以存在客户端；**安全性来自 RLS + 最小数据库授权，而不是把公开 key 当秘密藏起来。**

### 4.2 必须走受信任服务端的事
Flutter 永远不能持有 Secret Key / legacy service_role key。

以下操作优先通过 Edge Functions 或其他受信任后端：
- 管理员邀请 Auth 用户；
- 高权限角色授予/撤销；
- 学生合并；
- 跨范围批量交接；
- 受控导出/删除；
- 任何需要绕过普通 RLS 的维护操作。

Edge Function 本身也必须验证调用者身份和机构权限，不能因为“在服务端”就默认可信。

## 5. 身份模型

### Auth User
由 Supabase Auth 管理“这个登录身份是谁”。

### Profile
`public.profiles.id` 只引用 `auth.users.id` 主键，存放应用需要展示的人员资料。

### Organization Membership
表示这个账号属于哪个机构、成员状态是什么。

一个账号未来可以属于多个机构，因此不要把单一 `organization_id` 写死在 profile 上。

### Roles / Capabilities
账号与角色分离；一个 membership 可以同时有多个业务角色，例如 teacher + subject_lead。

V1 可以先使用固定角色集合，但权限检查应面向“能力/关系”而不是只写 `if role == admin`。

## 6. 多租户与 RLS

### 6.1 第一层：机构隔离
任何机构业务数据都必须能确定所属 `organization_id`。

访问的第一道判断：

```text
当前 auth.uid()
   ↓
是否有 active organization_membership
   ↓
是否属于该 organization_id
```

### 6.2 第二层：业务关系
机构成员并不等于能看机构全部数据。

普通教师继续检查：
- 是否负责该学生；
- 是否负责对应学科；
- 是否是协作教师；
- 是否拥有班主任/学管/学科负责人等能力。

### 6.3 第三层：操作类型
SELECT / INSERT / UPDATE / DELETE 分开授权。

“可以看”不能自动意味着“可以改”；“可以改”也不能自动意味着“可以删除”。

### 6.4 策略实现
建议把重复的关系判断封装成数据库函数，例如：
- `is_active_org_member(org_id)`
- `can_view_student(student_id)`
- `can_edit_subject_profile(profile_id)`
- `has_org_capability(org_id, capability)`

函数本身必须经过安全审查，避免通过错误的 SECURITY DEFINER 设计绕过 RLS。

## 7. 数据互通与并发

所有客户端都读写同一云数据库，不设计“上传/下载/同步”按钮。

V1 采用 **online-first**：
- 云数据库是真实事实源；
- 本地缓存只用于体验，不是最终真相；
- 暂不支持复杂离线写入队列和离线冲突合并。

### 并发策略
V1 不做 Google Docs 式同字段实时协同。

关键可编辑对象建议包含 `updated_at`，必要对象再增加 `version` 整数做乐观并发：
- 用户打开旧版本；
- 保存前发现 version 已变化；
- 提示刷新/合并，而不是静默覆盖别人更新。

Realtime 可用于“数据已变化，请刷新”或列表自动更新，不承担复杂协同编辑。

## 8. 数据建模原则

### 事实、状态、派生分层
- **事实**：课程、证据、干预、验证、案例事件；
- **当前状态**：案例当前阶段、负责人、未完成下一步行动；
- **派生**：周度摘要、重点问题提示、阶段报告、管理指标。

派生数据可以重算，不作为唯一事实源。

### 历史优先追加
核心业务变化尽量以 event 追加历史，再更新当前快照；不通过反复覆盖一段长文本保存全部过程。

## 9. 附件存储

试卷/作文图片等进入私有 Supabase Storage：
- 默认 private bucket；
- 数据库保存 metadata/object path，不存二进制；
- 文件路径包含 organization_id 与不可猜测 UUID；
- 下载使用授权策略或短时签名 URL；
- 不把学生真实姓名作为可公开文件名。

V1 对附件大小和类型设置明确限制，避免免费额度被无意耗尽。

## 10. 审计与可追溯

关键动作进入 `audit_logs`，但不把完整敏感正文无脑复制一遍。

重点审计：
- 角色与权限变化；
- 学生合并与交接；
- 学情案例关键状态变化；
- 归档/恢复；
- 高风险管理员操作。

案例本身的教学生命周期由 `case_events` 负责；系统治理审计由 `audit_logs` 负责，二者不要混为一张表。

## 11. 环境与迁移

### Development
只允许虚构数据，用于本地/Codex/测试。

### Production
真实机构数据；生产 schema 变化必须通过版本化 SQL migration。

条件允许后增加 Staging。

禁止只在 Supabase Dashboard 手工改表后不补 migration，否则 GitHub 不再是可重建的系统真相。

## 12. 配置与秘密

可以进入客户端构建配置：
- Supabase URL
- Publishable Key

不能进入客户端或 GitHub：
- Secret Key
- legacy service_role key
- 数据库密码
- 外部 AI 私密 API Key

AI 等外部私密服务如果后续加入，优先从 Edge Functions 调用。

## 13. 备份与恢复

正式使用前必须明确：
- 数据库备份频率；
- Storage 附件备份方式；
- 数据恢复演练；
- 误删/错误迁移回滚策略。

“平台有备份”不等于产品已具备完整恢复方案，尤其数据库备份通常不自动等价于 Storage 文件备份。

## 14. 生产上线前架构门槛

- RLS 覆盖所有客户端可访问业务表；
- 分角色的权限自动化测试通过；
- 无 Secret Key/service_role 进入 Flutter；
- 管理员邀请/高权限动作已服务端化；
- 教师离职与交接场景验证通过；
- 重复学生合并有审计和回退依据；
- migration 可以从空数据库重建 schema；
- 备份/恢复方案已经演练；
- 隐私与未成年人数据合规完成独立评估。

详见 `SECURITY_AND_PRIVACY.md`。
