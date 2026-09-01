# 账号、邀请与权限模型

## 1. 核心原则

V1 把“登录身份”和“机构访问权限”彻底分开：

- **Auth User**：这个邮箱对应哪个登录身份；
- **Organization Invitation**：某机构是否预授权这个邮箱加入；
- **Organization Membership**：这个 Auth User 是否已经是该机构有效成员；
- **Role**：成员承担什么职责；
- **Assignment**：成员和哪些学生/学科存在业务关系。

最重要的一条：

> **能够登录 Supabase Auth，不等于能看到任何机构数据。只有 active membership 才进入业务授权链。**

这使 V1 可以采用简单的 passwordless Email OTP，而不把账号安全和机构权限绑死在一封邀请链接上。

## 2. V1 首选登录方式：Email OTP

### 老师看到的体验

```text
打开 App
  ↓
输入邮箱
  ↓
收到一次性验证码
  ↓
在 App 输入验证码
  ↓
Auth Session 建立
  ↓
系统检查该账号有哪些 active membership / pending invitation
  ↓
进入机构，或提示“尚未获得机构授权”
```

V1 不要求老师创建/记忆密码，也不依赖 Windows/Android 自定义深链完成首次登录。

Supabase Email OTP 与 Magic Link 共用 passwordless 实现；邮件模板使用 token 变量后，用户直接输入验证码即可。

### 为什么优先 OTP

相比“邀请链接 → 浏览器 → App deep link → 设置密码”，OTP 更适合 Windows + Android 双客户端：
- 不要求操作系统正确注册 URL scheme；
- 不需要用户理解“浏览器为什么又跳回 App”；
- 新设备登录路径一致；
- 不需要密码恢复作为 V1 高频支持流程；
- 已存在 Auth User 与新用户使用同一种登录 UX。

Phase 0 仍必须双平台真测 OTP，不因为官方 SDK 支持就跳过验证。

## 3. 管理员“邀请”只代表机构预授权

管理员邀请教师时，不需要把“发送 Supabase Invite Link”作为核心流程。

管理员执行：
1. 输入教师邮箱；
2. 选择预期角色；
3. 服务端验证管理员权限；
4. 创建 `organization_invitation(pending)` + invitation roles；
5. 告诉教师“请用该邮箱登录学情闭环”。

可选：未来可以发送一封普通通知邮件/消息，但它不是 Auth 凭证，也不是 membership 本身。

因此：
- pending invitation 没有学生数据访问权；
- invitation 可以取消；
- 同一机构/邮箱不创建多个 pending invitation；
- invitation 不需要知道 Auth User 是否已经存在；
- 不再面对“confirmed Auth User 无法再次 inviteUserByEmail”的核心流程冲突。

## 4. Email OTP 的 Auth 行为

客户端调用 passwordless email OTP。

V1 建议允许 Auth 层 `shouldCreateUser = true`：
- 新邮箱第一次 OTP 登录时可创建 Auth User；
- 已有邮箱正常登录已有 Auth User；
- 无论哪种情况，没有 active membership 都读不到机构数据。

这意味着**Auth 注册可以开放，业务授权仍然严格邀请制**。

### 这是一个有意识的权衡

优点：
- 不需要管理员预创建 Auth User；
- 新用户/旧用户一个登录流程；
- 已存在 Auth User 后续被另一个机构邀请时也不需要“再邀请 Auth”；
- 大幅降低账号半状态与深链复杂度。

代价：
- 未被机构邀请的人也可能创建一个“没有任何机构权限”的 Auth User；
- 因此 Production 需要配置 Auth rate limits / CAPTCHA 或等价滥用防护；
- 无 membership 用户只能看到“尚未获得机构授权”，不能读取机构名单或邀请信息。

如果 Phase 0 发现开放 Auth 创建带来不可接受的滥用成本，再评估服务端预创建 Auth User + `shouldCreateUser = false`，但不先为假设问题增加复杂度。

## 5. Email OTP 邮件模板与邮件服务

要发送“验证码”而不是 Magic Link，Email passwordless 模板必须使用 OTP token，而不是 ConfirmationURL。

要求：
- Local Development 通过 Supabase CLI/Mailpit 测试邮件；
- Remote Development 验证真实邮箱到达、验证码输入和限流；
- Production 不依赖 Supabase 默认 best-effort 邮件服务作为机构关键登录渠道；
- 正式上线前配置可靠 Custom SMTP 或等价邮件发送能力；
- OTP 过期、错误、频繁请求、429 都要有可理解 UI。

邮件服务属于运行依赖，不能在“软件做好了”之后才第一次测试。

## 6. 首位管理员如何出现

OTP 解决“怎么登录”，但第一个 org_admin 仍需要受控 bootstrap。

V1：
- Local / Development：seed + 测试 bootstrap 创建虚构 organization / active org_admin membership；
- Production 首次部署：受信任运维流程创建 organization + 首位 org_admin membership；
- 首位管理员用自己的邮箱 OTP 登录；
- bootstrap 完成后关闭/撤销一次性入口。

禁止：
- 客户端内置超级管理员密码/Secret；
- 公开任何人可调用的 org_admin 提权接口。

## 7. OTP 登录后如何获得机构权限

`verifyOtp` 成功只产生 Auth Session。

随后 App 执行受控 `resolve_access / accept_invitation` 流程：

1. 获取当前 `auth.uid()` 与已验证 email；
2. 查询该 user 已有 active memberships；
3. 查找与当前 verified email 匹配的 pending organization invitations；
4. 如果有 pending invitation，允许用户确认加入；
5. 受控事务创建 `(organization_id, user_id)` membership；
6. 根据 invitation roles 创建 membership_roles；
7. invitation → accepted；
8. 写 audit；
9. 返回可进入的 organization context。

### 安全要求
- invitation 邮箱必须和当前已验证 Auth email 匹配；
- 用户不能传另一个邮箱来接受别人的 invitation；
- invitation roles 在接受时仍要重新验证；
- 同一 org/user membership 唯一；
- 接受操作幂等；
- pending invitation 表不能因为“用户已登录”就对所有 authenticated 用户开放查询。

## 8. 新用户、已有用户、多机构用户统一了

采用 OTP 后不再需要三套 Auth onboarding。

### 新邮箱 + pending invitation
OTP 创建/登录 Auth User → 匹配 invitation → 创建 membership。

### 已有 Auth User + pending invitation
OTP 登录已有 Auth User → 匹配 invitation → 创建 membership。

### 已经是目标机构成员
OTP 登录 → 直接找到 active membership；不会重复建成员。

### 同一个 Auth User 被第二个机构邀请
数据库模型天然支持：登录后发现新的 pending invitation → 用户确认 → 创建第二个 organization membership。

V1 UI 可以先只优化“一个主要机构”；如果真的出现多个 active memberships，再展示机构选择器。但底层不再需要特殊 `link-existing-user` Auth 流程。

## 9. 没有机构权限的 Auth User

用户可能 OTP 登录成功，但没有 active membership，也没有 pending invitation。

App 只能显示类似：

> 当前邮箱尚未获得机构授权，请联系机构管理员确认邀请邮箱。

可以提供：
- 重新检查；
- 切换邮箱/退出登录；
- 最小帮助说明。

不能提供：
- 搜索机构；
- 浏览教师/学生；
- 猜测哪些邮箱已被邀请；
- 自助给自己加角色。

## 10. V1 角色

### `org_admin`
- invitation / membership 管理
- 角色管理
- 学生治理
- 交接/合并高风险操作
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
- 管理负责学科的案例、干预、验证、课程
- 查看允许共享的信息

### `student_advisor`
- 学生综合视角
- 综合观察与家校协调
- 不随意改写任课教师专业学科结论

一个 membership 可以有多个角色。

## 11. 权限不是只有 Role

最终授权至少由：

```text
用户已登录
  + active membership
  + membership 属于目标 organization
  + membership roles/capabilities
  + 与目标 student / subject 的有效 assignment
  + 操作类型（read/write/admin）
```

共同决定。

`teacher` 角色本身绝不能意味着读取机构全部学生。

## 12. V1 权限矩阵（概念级）

| 操作 | 任课教师 | 学生负责人/学管 | 学科负责人 | 管理员 |
|---|---|---|---|---|
| 查看本人负责学生基础档案 | 是 | 是 | 本科关系范围 | 是 |
| 查看本人负责学科详细学情 | 是 | 综合/按授权 | 本科范围 | 是 |
| 修改本人负责学科案例 | 是 | 默认否 | 按业务关系 | 受控 |
| 查看其他学科详细学情 | 默认否 | 必要综合视角 | 默认否 | 是 |
| 创建 invitation | 否 | 否 | 否 | 是 |
| 取消 pending invitation | 否 | 否 | 否 | 是 |
| 修改机构角色 | 否 | 否 | 否 | 受控 |
| 合并重复学生 | 否 | 否 | 否 | 受控 |
| 停用 membership | 否 | 否 | 否 | 受控 |

## 13. Invitation 的服务端规则

管理员创建 invitation 是业务高权限操作，但不需要 Auth Admin Secret。

受控函数/事务需要：
1. 验证当前 active membership；
2. 验证 org_admin 成员管理权限；
3. 规范化 email；
4. 验证 role codes；
5. 检查同机构是否已有 active member 使用该 email（若能安全解析）；
6. 检查是否已有 pending invitation；
7. 创建/复用 invitation；
8. 写 audit。

如果未来增加“发送普通邀请通知邮件”，邮件服务 Secret 仍放服务端；通知失败不改变 invitation 的业务真实性。

## 14. 接受 invitation 是事务命令

`accept_invitation(invitation_id)` 应：
1. 验证当前 Auth Session；
2. 获取可信 verified email；
3. 锁定 invitation；
4. 验证 status = pending；
5. email 匹配；
6. 验证 invitation roles；
7. 插入或获取唯一 membership；
8. 创建缺失 membership_roles；
9. invitation → accepted；
10. 写 audit；
11. 返回 organization context。

重复执行同一 invitation 应返回已有结果，而不是创建第二个 membership。

## 15. 停用与离职

教师离职：
1. 列出 active teacher/staff assignments；
2. 列出未结束 learning_case owner；
3. 列出 pending case_actions；
4. 完成交接或显式处理责任项；
5. 结束旧 assignments；
6. membership → disabled；
7. RLS 立即拒绝；
8. 历史记录保留原 creator/teacher。

**不允许先停用，再让责任项悄悄变成无人负责。**

### Session 注意
旧 Access Token 可能尚未过期。RLS 每次都必须通过数据库 membership 检查 active 状态，而不是只相信 JWT 中陈旧角色。

客户端遇到 disabled/authorization denied 应退出机构上下文并明确提示。

## 16. 当前机构上下文

一个用户只有一个 active membership 时直接进入。

多个 active memberships 时：
- 展示机构选择；
- 客户端维护 current organization context；
- RLS 仍逐行验证 organization_id；
- 不能只相信客户端当前机构选择。

V1 可以暂时只对单机构场景做完整 UX，但数据层和路由不能假定永远只有一个 membership。

## 17. RLS helper 设计

允许建立少量经过审计的 helper，避免 policy 复制大段 SQL。

要求：
- 优先简单、可索引；
- `security definer` helper 放非 exposed schema；
- `set search_path = ''`；
- schema-qualified；
- revoke 默认 execute，再按需 grant；
- member / non-member / disabled / cross-org 均有测试。

## 18. Phase 0 OTP 测试矩阵

| 场景 | Windows | Android |
|---|---|---|
| 新邮箱首次 OTP | 必测 | 必测 |
| 已有 Auth User OTP | 必测 | 必测 |
| 错误验证码 | 必测 | 必测 |
| 过期验证码 | 必测 | 必测 |
| 60 秒内重复请求/限流 | 必测 | 必测 |
| App 重启后 Session 恢复 | 必测 | 必测 |
| 无 membership / 无 invitation | 必测 | 必测 |
| pending invitation 接受 | 必测 | 必测 |
| 同账号第二机构 invitation | 集成测试 | 集成测试 |
| membership disabled 后旧 Session | 必测 | 必测 |

如果 Email OTP 在真实机构邮箱投递或用户体验上不可靠，再回到 ADR 重新评估 Magic Link/Password/SSO；不要并行维护四套登录方式。

## 19. Auth / 权限测试最低集合

1. 未登录不能读取业务表；
2. 仅有 Auth User、无 membership 不能读取业务表；
3. pending invitation 不能读取业务表；
4. disabled membership 不能读取业务表；
5. A 机构成员无法读取 B 机构学生；
6. 教师无法扩大到未分配学生；
7. 语文教师不能修改数学核心学情；
8. 学生负责人综合视角不等于无限编辑；
9. 普通教师不能创建 invitation/提权；
10. invitation 只能由匹配 verified email 的用户接受；
11. accept invitation 重试不产生重复 member；
12. 旧 Token + disabled membership 仍被拒绝；
13. View/Function 不成为 RLS 后门；
14. OTP 登录的无授权用户看不到机构枚举信息；
15. Auth rate limit / CAPTCHA 失败有安全、可理解 UI。