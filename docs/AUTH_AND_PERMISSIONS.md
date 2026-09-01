# 账号、邀请与权限模型

## 1. 核心原则

- **Auth User** 回答“这个登录身份是谁”；
- **Organization Membership** 回答“这个账号在某机构是否有效”；
- **Role** 回答“这个成员具有哪类职责”；
- **Assignment** 回答“这个成员和哪些学生/学科存在业务关系”。

任何一个层级都不能单独代表完整权限。

## 2. V1 账号策略：机构邀请/受控开通

V1 不开放“任何人自行注册后直接进入机构”。

推荐流程：

```text
机构管理员
  ↓
邀请/开通教师
  ↓
受信任服务端执行 Auth Admin 操作
  ↓
创建或关联 Auth User
  ↓
创建 organization_membership（invited/active）
  ↓
用户完成首次激活/登录
  ↓
membership 激活
```

第一阶段优先使用邮箱身份，因为不依赖短信付费通道。

但在写正式业务前，必须用技术 Spike 验证 **Android + Windows 的首次激活、密码设置/重置、邀请链接回跳体验**。不能只因为服务端 API 支持邀请，就假定桌面客户端体验一定顺畅。

## 3. 首位管理员如何出现

“邀请制”存在一个天然问题：第一个管理员没有上级可以邀请他。

V1 采用受控 bootstrap：
- Development：seed/migration + 明确测试脚本创建虚构 org_admin；
- Production 首次部署：由受信任运维流程/一次性受控函数创建机构和首位 org_admin；
- bootstrap 完成后关闭/撤销一次性入口。

禁止：
- 在客户端隐藏一个“超级管理员密码”；
- 公开一个任何人都能调用的创建机构接口；
- 把 service_role 放进 Flutter 完成初始化。

未来如果产品变成真正自助 SaaS，再重新设计 organization provisioning 与计费，不提前塞进 V1。

## 4. 不允许公开注册直接获得机构权限

即使未来允许普通 Auth 注册：
- 注册只代表“有一个账号”；
- 没有 active organization_membership 就看不到机构业务数据；
- 用户不能自己把自己加入某机构；
- 用户不能自己给自己添加 teacher/admin 角色。

## 5. Auth User ≠ 机构成员

同一个 Auth User 将来可以属于多个机构，每个机构拥有独立：
- membership；
- 角色；
- 学生关系；
- 权限。

因此不能把一个永久 `organization_id` 写死在 user profile 上。

V1 UI 可以暂时只重点优化“一人一个主要机构”的场景，但数据库不应把这个假设写死。

## 6. 授权事实源

正式授权以数据库里的：
- `organization_memberships`
- `membership_roles`
- `student_teacher_assignments`
- `student_staff_assignments`
- 学科/学生关系

为事实源。

不要把可由用户修改的 `user_metadata` 当作 RLS 或权限依据。

如果未来为性能把角色写入 JWT/App Metadata，只能作为受控缓存/声明；JWT 不一定实时刷新，数据库事实源仍要清楚。

## 7. V1 角色

### `org_admin`
- 成员管理
- 角色管理
- 学生治理
- 交接/合并等高风险操作
- 机构级查看

### `academic_admin`
- 教学管理视角
- 跨学科查看
- 不默认拥有 Auth 系统最高权限

### `subject_lead`
- 本学科范围查看
- 教研/异常视角
- 不默认修改其他教师全部历史事实

### `teacher`
- 查看被分配学生
- 管理自己负责学科的案例、干预、验证、课程
- 查看允许共享的综合信息

### `student_advisor`
- 学生综合视角
- 综合观察与家校协调
- 不随意改写任课教师的专业学科结论

一个 membership 可以有多个角色。

## 8. 权限不是只有 Role

最终授权至少由以下因素共同决定：

```text
用户已登录
  + membership active
  + membership 属于目标 organization
  + membership roles/capabilities
  + 与目标 student / subject 的有效 assignment
  + 操作类型（read/write/admin）
```

例如：`teacher` 角色本身绝不能意味着可以读取机构全部学生。

## 9. V1 权限矩阵（概念级）

| 操作 | 任课教师 | 学生负责人/学管 | 学科负责人 | 管理员 |
|---|---|---|---|---|
| 查看本人负责学生基础档案 | 是 | 是 | 本科关系范围 | 是 |
| 查看本人负责学科详细学情 | 是 | 综合/按授权 | 本科范围 | 是 |
| 修改本人负责学科案例 | 是 | 默认否 | 按业务关系 | 受控 |
| 查看其他学科详细学情 | 默认否 | 必要综合视角 | 默认否 | 是 |
| 新建综合观察 | 后续按规则 | 是 | 按规则 | 是 |
| 修改机构角色 | 否 | 否 | 否 | 受控 |
| 合并重复学生 | 否 | 否 | 否 | 受控 |
| 停用账号 | 否 | 否 | 否 | 受控 |

具体 SQL policy 以自动化权限测试为准。

## 10. 管理员邀请必须服务端化

客户端只提交必要参数，例如：
- 被邀请邮箱；
- organization ID；
- 预期角色。

受信任函数必须：
1. 验证当前 Session；
2. 验证调用者拥有该机构成员管理能力；
3. 执行 Auth Admin；
4. 创建/更新 membership；
5. 写 audit log；
6. 返回不包含秘密的结果。

Secret Key 永远只存在函数环境变量中。

## 11. 已存在账号再次加入机构

服务不能永远假定“邮箱一定是新用户”。

长期模型应支持：
- 已存在 Auth User；
- 新增另一个 organization membership；
- 用户登录后进入/选择有权机构。

但 V1 首机构试运行不必为了少见跨机构场景把邀请 UI 做得很复杂。实现时应先验证 Supabase Auth Admin 对“新邮箱/已有邮箱”的真实行为，再决定用户体验，不凭文档猜测。

## 12. 停用与离职

教师离职：
1. membership → disabled；
2. 数据库权限立即按 disabled 拒绝；
3. 结束 active assignments；
4. 未完成案例/行动交接给新负责人；
5. 历史记录保留原 creator/teacher；
6. 不因为离职删除课程、案例、沟通历史。

V1 应优先“停用机构 membership”，而不是随意删除整个 Auth User。

### Session 注意
账号被停用后，客户端可能仍持有尚未过期 Token。数据库 RLS 必须每次通过 membership 事实判断 active 状态，而不能仅依赖旧 JWT 中的角色声明。

## 13. 当前机构上下文

如果一个用户只有一个 active membership，登录后直接进入该机构。

如果未来有多个 active memberships：
- 登录后选择当前机构；
- 客户端维护 current organization context；
- 所有查询显式处于该机构上下文；
- RLS 仍逐行验证 organization_id，不能只相信客户端选择。

## 14. RLS helper 设计

复杂权限会频繁检查“当前用户在机构中的 membership/role/assignment”。

允许建立少量、经过审计的 helper function，避免每个 policy 复制长 SQL。

要求：
- 优先简单、稳定、可索引的条件；
- `security definer` helper 放非 exposed schema；
- `set search_path = ''`；
- 显式 schema-qualified；
- revoke 默认 execute 后按角色 grant；
- 为 member / non-member / disabled / cross-org 写测试。

## 15. 权限测试最低集合

任何 V1 发布候选都必须验证：
1. 未登录用户读取业务表失败；
2. disabled membership 读取失败；
3. A 机构成员无法读取 B 机构学生；
4. 教师无法通过手工请求扩大到未分配学生；
5. 语文教师不能直接修改数学核心学情；
6. 学生负责人综合视角符合设计但不拥有无限编辑权；
7. 普通教师调用管理员函数被拒绝；
8. 管理员只能管理自己有权限的机构；
9. View/Function 不成为绕过 RLS 的后门；
10. 旧 Token + disabled membership 仍然被数据库拒绝。