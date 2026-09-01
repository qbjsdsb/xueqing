# 账号、邀请与权限模型

## 1. 核心原则

- **Auth User** 回答“这个登录身份是谁”；
- **Organization Membership** 回答“这个账号在某机构是否有效”；
- **Role** 回答“这个成员具有哪类职责”；
- **Assignment** 回答“这个成员和哪些学生/学科存在业务关系”。

任何一个层级都不能单独代表完整权限。

## 2. V1 账号策略：机构邀请 / 受控开通

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

### Redirect 不是“传了参数就一定生效”

邀请、密码恢复等邮件流程如果需要回到 App：
- 服务端传入的 redirect URI 必须加入 Supabase Auth 的允许 Redirect URLs；
- Development / Production 使用不同 scheme/host 时分别配置；
- 如果 redirect 配置错误，不能让用户落到一个无意义网页后不知道下一步；
- Phase 0 必须在 Windows 与 Android 分别真测。

邀请链接存在有效期，因此 UI/管理员流程必须支持“邀请已过期 → 重新发送”，不能把一次邀请当成永久凭证。

## 3. 首位管理员如何出现

“邀请制”存在一个天然问题：第一个管理员没有上级可以邀请他。

V1 采用受控 bootstrap：
- Local / Development：seed + 明确测试脚本创建虚构 org_admin；
- Production 首次部署：由受信任运维流程/一次性受控函数创建机构和首位 org_admin；
- bootstrap 完成后关闭/撤销一次性入口。

禁止：
- 在客户端隐藏一个“超级管理员密码”；
- 公开一个任何人都能调用的创建机构接口；
- 把 service_role / Secret Key 放进 Flutter 完成初始化。

未来如果产品变成真正自助 SaaS，再重新设计 organization provisioning 与计费，不提前塞进 V1。

## 4. 不允许公开注册直接获得机构权限

即使未来允许普通 Auth 注册：
- 注册只代表“有一个账号”；
- 没有 active organization_membership 就看不到机构业务数据；
- 用户不能自己把自己加入某机构；
- 用户不能自己给自己添加 teacher/admin 角色。

## 5. Auth User ≠ 机构成员

同一个 Auth User 的长期数据模型允许属于多个机构，每个机构拥有独立：
- membership；
- 角色；
- 学生关系；
- 权限。

因此不能把一个永久 `organization_id` 写死在 user profile 上。

**但“数据库支持多机构”不等于 V1 必须做复杂多机构账号 UX。** V1 首机构试运行优先优化“一人一个主要机构”的实际场景；跨机构加入在真实需求出现前不提前复杂化。

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
- 预期角色；
- 经过 allowlist 的 redirect 语义（由服务端按环境决定，客户端不传任意 URL）。

受信任函数必须：
1. 验证当前 Session；
2. 验证调用者拥有该机构成员管理能力；
3. 验证 email / organization / role 参数；
4. 按当前 Auth 用户状态选择正确流程；
5. 执行 Auth Admin；
6. 创建/更新 membership；
7. 写 audit log；
8. 返回不包含秘密的结果。

Secret Key 永远只存在函数环境变量中。

不接受“客户端传一个 redirect URL，服务端原样信任并发送”的设计。

## 11. 新邮箱、已有未完成邀请、已有确认账号必须分开处理

这是 V1 账号实现里必须明确的分支。

### A. 邮箱尚无 Auth User
可以执行标准邀请：
- Auth Admin 发送 invite；
- 建立 invited membership；
- 用户完成激活后 membership → active。

### B. 已经存在未完成邀请/未确认用户
不要无限制造重复 membership。

应：
- 查到现有 membership/invite 状态；
- 必要时重发邀请；
- 保持同一个业务 membership；
- 记录重发操作而不是重新造一个“同名老师”。

### C. 邮箱已经属于 confirmed Auth User
Supabase 的标准 `inviteUserByEmail` 对已确认用户会返回错误，因此不能把“再次 invite”当作加入第二机构的通用办法。

V1 首机构试运行的处理原则：
- 如果账号已属于目标机构：进入“已有成员 / 恢复访问 / 重置密码”等正确流程，不重复邀请；
- 如果账号属于其他机构，而当前版本尚未实现“关联已有账号到新机构”的受控 UX：明确提示管理员该场景暂未开放，不通过 hack 重建第二个 Auth User；
- 真正出现跨机构共享账号需求时，再实现受控 **link-existing-user** 流程，通过已验证的 Auth User ID 建立新的 membership，而不是依赖再次发 invite。

数据库模型保持支持多机构，但 V1 不为尚未发生的跨机构需求牺牲账号流程清晰度。

## 12. 邀请状态与业务状态不能绑死在一封邮件上

`organization_membership` 是机构业务身份，邀请邮件只是激活渠道。

因此：
- 邮件过期不等于删除 membership；
- 重发邀请不等于创建第二个 membership；
- 管理员可以取消未完成邀请；
- 已 active 成员重置密码不改变 membership；
- Auth 邮件失败应有重试/错误状态，不留下无法解释的半激活业务数据。

涉及 Auth + membership 的多步流程要么事务化/补偿式设计清楚，要么保证失败后可安全重试。

## 13. 停用与离职

教师离职：
1. 先列出 active assignments、未完成案例 owner、pending actions；
2. 要求完成交接或显式处理责任项；
3. 结束 active assignments；
4. membership → disabled；
5. 数据库权限立即按 disabled 拒绝；
6. 历史记录保留原 creator/teacher；
7. 不因为离职删除课程、案例、沟通历史。

不允许先禁用账号，再让一批未完成行动悄悄变成无人负责。

V1 应优先“停用机构 membership”，而不是随意删除整个 Auth User。

### Session 注意
账号被停用后，客户端可能仍持有尚未过期 Token。数据库 RLS 必须每次通过 membership 事实判断 active 状态，而不能仅依赖旧 JWT 中的角色声明。

客户端在遇到 membership disabled / authorization denied 时应退出机构上下文并给出明确提示，而不是不断重试。

## 14. 当前机构上下文

如果一个用户只有一个 active membership，登录后直接进入该机构。

如果未来有多个 active memberships：
- 登录后选择当前机构；
- 客户端维护 current organization context；
- 所有查询显式处于该机构上下文；
- RLS 仍逐行验证 organization_id，不能只相信客户端选择。

## 15. RLS helper 设计

复杂权限会频繁检查“当前用户在机构中的 membership/role/assignment”。

允许建立少量、经过审计的 helper function，避免每个 policy 复制长 SQL。

要求：
- 优先简单、稳定、可索引的条件；
- `security definer` helper 放非 exposed schema；
- `set search_path = ''`；
- 显式 schema-qualified；
- revoke 默认 execute 后按角色 grant；
- 为 member / non-member / disabled / cross-org 写测试。

## 16. Phase 0 认证测试矩阵

至少验证：

| 场景 | Windows | Android |
|---|---|---|
| 新邮箱首次邀请 | 必测 | 必测 |
| 邀请过期后重发 | 必测 | 必测 |
| 已 active 用户登录 | 必测 | 必测 |
| 密码恢复 | 必测 | 必测 |
| App 已运行时回跳 | 必测 | 必测 |
| App 未运行时回跳 | 必测 | 必测 |
| 错误 redirect 配置 | 必测 | 必测 |
| membership disabled 后旧 Session | 必测 | 必测 |

跨机构 confirmed-user 关联如果 V1 不开放，需要测试“明确拒绝/提示”，而不是留成未知行为。

## 17. 权限测试最低集合

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
10. 旧 Token + disabled membership 仍然被数据库拒绝；
11. 已确认邮箱不会被错误地当成“新用户 invite”重复创建；
12. 未完成邀请重发不会产生重复 membership。