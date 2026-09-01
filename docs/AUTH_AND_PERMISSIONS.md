# 账号与权限模型

> V1 的目标不是做一个公开 SaaS 注册系统，而是让一个**已知教师团队**安全、低成本地使用同一机构数据。

## 1. 核心原则

V1 把以下概念分开：

- **Auth User**：登录身份是谁；
- **Organization Membership**：这个账号在某机构当前是否可用；
- **Role**：这个成员承担什么职责；
- **Assignment**：这个成员与哪些学生/学科存在业务关系。

最重要的一条：

> **能够登录 Supabase Auth，不等于能够读取机构业务数据。只有 `active` membership 才进入业务授权链。**

权限不是 Flutter 隐藏按钮，而是数据库 RLS / 受控服务端真正执行。

---

## 2. V1 认证策略：管理员受控开通 + Password

### 为什么不用 Email OTP 做 V1 硬依赖

Passwordless Email OTP 的体验很好，但真实机构使用依赖可靠邮件投递。

Supabase 默认邮件服务适合开发/演示，不应作为机构关键登录通道；正式使用通常需要可靠 Custom SMTP。为了满足本阶段 **零额外付费** 的硬约束，V1 内部试运行不让 SMTP、域名或第三方邮件服务成为前置条件。

Email OTP 保留为未来可替换的登录体验，而不是 V1 数据模型的一部分。

### 老师实际体验

```text
管理员新增教师
  ↓
受信任服务端生成账号 + 高强度临时密码
  ↓
教师通过机构已有可信渠道拿到临时凭据
  ↓
App：邮箱 + 临时密码登录
  ↓
membership = onboarding
  ↓
只进入“设置自己的新密码”页面
  ↓
完成 onboarding
  ↓
membership = active
  ↓
按 role + assignment 读取业务数据
```

不开放公网自助注册。

---

## 3. `organization_membership.status`

V1 使用：

- `onboarding`：账号已经受控创建，但尚未完成首次密码接管；
- `active`：正常机构成员；
- `disabled`：离职/停用，不得访问机构业务数据。

### 为什么增加 onboarding

如果一创建 Auth User 就直接给 active membership，那么管理员知道的临时密码在教师修改之前已经可以访问学生数据。

因此：
- onboarding 用户可以建立 Auth Session；
- 但普通机构业务 RLS 必须要求 membership = active；
- onboarding 账号只能进入极小的账号激活流程；
- 完成新密码设置后才激活 membership。

这让“临时凭据泄露”和“正式业务权限”之间多一道边界。

---

## 4. 管理员新增成员：`provision_member`

这是受控高权限命令，默认通过 Edge Function / 可信服务端完成。

输入：
- organization_id；
- 教师邮箱；
- 显示名（可选）；
- 初始 roles。

服务端必须：
1. 验证当前 Session；
2. 验证调用者在目标机构拥有成员管理权限；
3. 规范化邮箱；
4. 验证角色合法；
5. 检查目标机构是否已有对应 member；
6. 生成足够随机的临时密码；
7. 使用 Supabase Auth Admin 创建/受控处理 Auth User；
8. 对本机构已知教师可使用 `email_confirm = true`，不触发确认邮件；
9. 创建 profile / `membership(onboarding)` / roles；
10. 写不包含密码的 audit；
11. 把临时密码**仅在成功响应中返回一次**。

### 绝对禁止

- 把 service_role / Secret 放进 Flutter；
- 把临时密码写入数据库长期保存；
- 把临时密码写入 audit / 日志 / Sentry；
- 在 GitHub Issue/PR/测试里放真实密码；
- 管理员自己手填一个弱默认密码如 `123456`。

### 临时密码交付

V1 是少量内部教师，因此由管理员通过机构现有可信渠道交付，例如当面或已经建立身份关系的内部通讯渠道。

不要把“把密码发到错误群聊”设计成产品流程；管理员界面要明确提示这是一次性敏感凭据。

---

## 5. 首次接管账号：`complete_member_onboarding`

教师用临时密码登录后，App 检测到 membership = onboarding，只显示设置新密码流程。

推荐由受控服务端完成：
1. 验证当前 Auth Session；
2. 解析当前 user_id；
3. 验证其目标 membership = onboarding；
4. 校验新密码强度；
5. 使用受信任 Auth Admin 能力把当前 Auth User 密码更新为新密码；
6. membership → active；
7. 写 audit；
8. 返回当前 organization context。

要求：
- 新密码不进入业务日志；
- 失败后可安全重试；
- membership 激活前不能读取学生数据；
- 不允许客户端传另一个 user_id 来修改别人密码。

> Auth 密码修改与业务 membership 更新不完全属于同一 PostgreSQL 事务，因此实现时要设计可恢复顺序。最重要的不变量是：**任何半失败都不能让未完成接管的账号获得 active 业务权限。**

---

## 6. 普通登录

完成 onboarding 后：

```text
邮箱 + 密码
   ↓
Supabase Auth Session
   ↓
查询当前用户 active memberships
   ↓
0 个：无机构访问
1 个：直接进入
多个：选择当前机构
```

V1 UI 优先优化单机构使用，但数据模型不把 organization_id 永久写死在 profile 上。

---

## 7. 忘记密码：V1 管理员协助重置

为了不依赖 SMTP，V1 内部试运行不提供邮件“忘记密码”主流程。

管理员先通过机构现有流程确认教师本人，然后执行受控 `reset_member_credential`：

1. 验证 org_admin 权限；
2. 生成新的随机临时密码；
3. 使用 Auth Admin 更新目标 Auth User 密码；
4. membership → onboarding；
5. 旧 Session 即使仍存在，也因为 membership 非 active 被 RLS 拒绝业务数据；
6. 写 audit（不写密码）；
7. 临时密码仅返回一次；
8. 教师重新登录并完成 onboarding。

这个设计利用 membership 状态切断旧 Session 的业务权限，而不把“Token 是否立即失效”作为唯一安全保证。

---

## 8. 首位管理员 Bootstrap

第一个 org_admin 没有上级管理员。

### Local / Remote Development
使用虚构 seed / 明确开发脚本建立测试 organization、Auth User 与 active org_admin。

### Production 首次部署
通过一次性受信任运维流程：
1. 创建 organization；
2. 创建首位管理员 Auth User；
3. 建立 onboarding 或受控 active org_admin membership；
4. 交付一次性凭据；
5. 完成后关闭 bootstrap 入口。

禁止：
- Flutter 内置超级管理员 Secret；
- 公开“创建第一个管理员”的长期 API；
- Production 使用 Development seed。

---

## 9. 已存在 Auth User

长期模型允许一个 Auth User 属于多个 organization，但 V1 首机构试运行不为稀有场景增加复杂 UI。

### 已经是目标机构成员
管理员进入已有成员详情，不重复建 Auth User/member。

### 同一平台账号需要加入第二机构
实现时可增加受控 `link_existing_user_to_org`，但必须：
- 管理员有目标机构权限；
- 能可靠确定目标 Auth User；
- 不通过重复创建 Auth User 绕过去；
- 新 membership 从 onboarding/active 的合适状态开始；
- 写 audit。

V1 没有真实需求时可以先明确拒绝该场景，而不是猜测实现。

---

## 10. V1 角色

### `org_admin`
- 成员开通/停用/重置；
- 角色管理；
- 学生治理；
- 交接/合并高风险操作；
- 机构级查看。

### `academic_admin`
- 教学管理视角；
- 跨学科查看；
- 不默认拥有 Auth 系统最高权限。

### `subject_lead`
- 本学科范围查看；
- 教研/异常视角；
- 不默认改写其他教师全部历史事实。

### `teacher`
- 查看被分配学生；
- 管理负责学科案例、干预、验证、课程；
- 查看允许共享的信息。

### `student_advisor`
- 学生综合视角；
- 综合观察与家校协调；
- 不随意改写任课教师专业结论。

一个 membership 可以有多个角色。

---

## 11. 权限不是只有 Role

最终授权至少由：

```text
用户已登录
  + membership = active
  + membership 属于目标 organization
  + membership roles/capabilities
  + 与目标 student / subject 的有效 assignment
  + 操作类型（read/write/admin）
```

共同决定。

`teacher` 角色绝不能意味着机构全量学生可见。

`onboarding` 与 `disabled` membership 对普通业务表都必须像“无业务权限”处理。

---

## 12. V1 权限矩阵（概念级）

| 操作 | 任课教师 | 学生负责人/学管 | 学科负责人 | org_admin |
|---|---|---|---|---|
| 查看本人负责学生基础档案 | 是 | 是 | 本科关系范围 | 是 |
| 查看本人负责学科详细学情 | 是 | 综合/按授权 | 本科范围 | 是 |
| 修改本人负责学科案例 | 是 | 默认否 | 按业务关系 | 受控 |
| 查看其他学科详细学情 | 默认否 | 必要综合视角 | 默认否 | 是 |
| 新增成员账号 | 否 | 否 | 否 | 是 |
| 重置成员凭据 | 否 | 否 | 否 | 是 |
| 修改机构角色 | 否 | 否 | 否 | 受控 |
| 合并重复学生 | 否 | 否 | 否 | 受控 |
| 停用 membership | 否 | 否 | 否 | 受控 |

具体 SQL policy 以自动化负面权限测试为准。

---

## 13. 停用与离职

教师离职：
1. 列出 active teacher/staff assignments；
2. 列出未结束 learning_case owner；
3. 列出 pending case_actions；
4. 完成交接或显式处理责任项；
5. 结束旧 assignments；
6. membership → disabled；
7. RLS 立即拒绝业务访问；
8. 历史记录保留原 creator/teacher。

**不允许先停用，再让责任项悄悄变成无人负责。**

旧 Access Token 可能尚未过期，所以 RLS 每次必须查询数据库 membership 状态，不能只相信 JWT 中陈旧角色。

---

## 14. 当前机构上下文

一个用户只有一个 active membership 时直接进入。

多个 active memberships 时：
- 展示机构选择；
- 客户端维护 current organization context；
- RLS 仍逐行验证 organization_id；
- 不相信客户端“我现在选了机构 A”就自动授权。

---

## 15. RLS Helper

允许少量经过审计的 helper function，避免每条 policy 复制大段 SQL。

要求：
- 简单、稳定、可索引；
- `security definer` helper 放非 exposed schema；
- `set search_path = ''`；
- schema-qualified；
- revoke 默认 execute 后按需 grant；
- unauthenticated / onboarding / active / disabled / cross-org 均有测试。

---

## 16. Phase 0 认证测试矩阵

Windows 与 Android 均至少验证：

| 场景 | 必测 |
|---|---|
| 管理员创建测试教师 | 是 |
| 临时密码登录 | 是 |
| onboarding 时读取学生数据被拒绝 | 是 |
| 设置新密码并激活 | 是 |
| active 登录 / Session 恢复 | 是 |
| 密码错误 | 是 |
| 管理员重置密码 | 是 |
| reset 后旧 Session 读取业务数据被拒绝 | 是 |
| disabled membership 旧 Session 被拒绝 | 是 |
| 无 membership Auth User 被拒绝 | 是 |
| 跨机构访问被拒绝 | 是 |

不把 Email OTP / deep link / SMTP 作为 V1 发布门槛。

---

## 17. 未来升级 Email OTP

当机构已经拥有可靠邮件基础设施，或经过验证的零成本 SMTP 能满足真实使用时，可以新增 ADR 把登录体验升级为 Email OTP。

升级时应尽量只替换 Auth onboarding/login 层：
- Auth User 仍是身份；
- membership/roles/assignments 仍是权限事实源；
- 学生、案例、课程 schema 不变；
- RLS 仍只认可 active membership。

**登录方式可以换，机构授权模型不能跟着重写。**

---

## 18. 权限测试最低集合

任何 V1 发布候选至少验证：
1. 未登录读取失败；
2. Auth User 无 membership 失败；
3. onboarding membership 业务读取失败；
4. disabled membership 失败；
5. A 机构成员无法读取 B 机构学生；
6. teacher 不能扩大到未分配学生；
7. 语文 teacher 不能修改数学核心学情；
8. student_advisor 有综合视角但没有无限编辑权；
9. 普通 teacher 调用 provision/reset/role admin command 被拒绝；
10. org_admin 只能管理自己有权机构；
11. View/Function 不绕过 RLS；
12. 旧 Token + onboarding/disabled membership 仍被数据库拒绝。

---

## 19. 真实机构上线前再评估

V1 零成本认证适合少量、已知、内部教师。

如果未来出现：
- 大量公开注册；
- 教师跨机构自助加入；
- 大量忘记密码；
- 家长/学生账号；
- 无管理员介入的自助 onboarding；

再评估 Email OTP、SSO、企业微信等方案，不提前把复杂度塞入 V1。