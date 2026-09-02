# 账号与权限模型

> V1 面向少量、已知、内部教师。目标不是搭建公开 SaaS 注册系统，而是在**零额外付费**前提下，把账号接管、机构授权和旧 Session 风险做对。

## 1. 四层身份必须分开

- **Auth User**：登录身份是谁；
- **Organization Membership**：该身份在某机构当前处于什么状态；
- **Role**：成员承担什么职责；
- **Assignment**：成员与哪些学生/学科存在业务关系。

普通业务授权至少同时满足：

```text
有效 Auth Session
+ membership = active
+ membership 属于目标 organization
+ role / capability
+ student / subject assignment（如该操作需要）
+ 操作类型允许
```

**能够登录 Auth，不等于能够读取机构数据。** 前端隐藏按钮不是权限控制，RLS / 受控服务端才是。

---

## 2. V1 登录方案：管理员受控开通 + Password

Email OTP 的体验更轻，但真实机构使用需要可靠邮件投递。V1 为了不把 SMTP、域名、短信或第三方登录变成付费前置，采用：

```text
org_admin provision_member
  ↓
Auth User + membership(onboarding)
  ↓
随机高强度临时密码，只显示一次
  ↓
教师登录，只能进入账号接管
  ↓
设置自己的新密码
  ↓
撤销旧 Sessions
  ↓
membership → active
  ↓
教师必须重新登录
```

不开放公网自助注册。以后有可靠邮件基础设施时，可以替换成 Email OTP，但不能重写 membership / roles / assignments。

---

## 3. Membership 状态

V1 使用：

- `onboarding`：账号已受控创建或刚被重置，尚未安全完成凭据接管；
- `active`：正常机构成员；
- `disabled`：离职/停用。

推荐字段：
- `joined_at`
- `activated_at`
- `disabled_at`
- `onboarding_expires_at`

### onboarding 的硬规则

- 可以建立 Auth Session；
- 普通学生/课程/学情 RLS 全部拒绝；
- 只允许最小账号接管能力；
- 必须有较短的接管有效期；具体时长在 Phase 0 实测后固定，建议按小时/天而不是长期有效；
- 过期后不能自行激活，管理员必须重新签发临时凭据；
- 管理员可取消/停用未完成 onboarding。

临时密码不是“一次性 Token”，谁先拿到它谁就可能尝试接管，因此**可信交付 + 短有效期 + onboarding 无业务权限**缺一不可。

---

## 4. 业务 Session 必须仍然存活

仅检查 `membership = active` 还不够。

Supabase 的 JWT 带 `session_id`，对应 `auth.sessions`。用户 sign out 后相关 session 会从 `auth.sessions` 移除，但已经签发的 Access Token 在 `exp` 前仍可能被客户端携带使用。

因此 V1 对学生业务数据采用“活 Session”防线：

```text
auth.uid() 有效
+ JWT session_id 存在
+ 对应 auth.sessions 记录仍存在
+ membership = active
+ 后续 role / assignment 检查
```

实现建议：
- 建少量经过审计的非 exposed `security definer` helper；
- `set search_path = ''`，所有对象 schema-qualified；
- revoke 默认 execute，再最小 grant；
- RLS 中用 `(select private.xxx(...))` 等方式减少重复求值；
- Phase 0 用 EXPLAIN 和真实查询验证开销；
- unauthenticated / revoked-session / onboarding / active / disabled / cross-org 都要有自动化负面测试。

这是 V1 为学生敏感数据选择的额外安全保证，不依赖付费的单 Session/Session lifetime 功能。

---

## 5. 管理员开通成员：`provision_member`

输入：目标机构、教师邮箱、显示名（可选）、初始 roles。

服务端必须：
1. 验证调用者当前 Session 与 org_admin 成员管理权限；
2. 规范化邮箱、验证角色；
3. 检查目标机构是否已有 member；
4. 生成安全随机临时密码；
5. Auth Admin 创建/受控处理 Auth User；对已知内部教师可 `email_confirm = true`；
6. 建 profile、`membership(onboarding)`、roles，并设置 `onboarding_expires_at`；
7. 写**不含密码**的 audit；
8. 仅在成功响应中返回一次临时密码。

### 禁止

- Secret/service_role 进入 Flutter；
- 固定默认密码如 `123456`；
- 密码进入 PostgreSQL 业务表、日志、audit、错误上报、Issue/PR；
- 创建后直接给 active 权限。

### 跨系统半失败

Auth Admin 与业务 PostgreSQL 不是同一事务域。

- Auth User 已创建、membership 失败：可能留下无 membership 的 Auth User；这是**安全失败**，因为没有业务权限。后续由受控恢复流程处理；
- membership 不得在 Auth 身份尚未安全建立时变 active；
- 每种半失败必须返回可识别的错误状态，不靠人工猜数据库。

### “响应丢失”不能靠保存明文密码解决

如果创建成功但响应丢失，管理员可能拿不到临时密码。因为系统刻意不保存明文密码，**同一 operation 不能承诺再次返回原密码**。

正确流程：
- member 保持 onboarding；
- UI 显示“凭据交付状态未知”；
- 管理员执行 `reissue/reset credential` 生成全新的临时密码并使旧临时密码失效；
- 绝不为了幂等而持久化可恢复的明文凭据。

---

## 6. 首次接管：`complete_member_onboarding`

教师用临时密码登录后只看到账号接管页。

受控流程：
1. 验证当前 Auth Session、`auth.uid()` 与当前 `session_id`；
2. membership 必须属于当前用户且为 onboarding；
3. `onboarding_expires_at` 尚未过期；
4. 校验新密码强度；
5. Auth Admin 更新**当前用户自己的**密码；
6. 以当前有效 JWT 执行 global sign-out，撤销该用户所有 Auth Sessions/Refresh Tokens；
7. **只有前两项 Auth 安全操作成功后**，服务端才把 membership → active，写 `activated_at` 和 audit；
8. 当前旧 Session 不再用于进入业务页；App 清除本地机构上下文；
9. 教师必须用新密码重新登录，获得一个新的 live Session，再进入机构。

### 为什么必须“重新登录”

如果有人在教师之前偷到临时密码并建立过 Session，只改密码再直接 active，旧 Access Token 可能在过期前继续存在。global sign-out + live-session RLS guard 可以阻断这种旧 Session。

### 半失败原则

- 密码更新失败：membership 仍 onboarding；
- 密码更新成功但 global sign-out 失败：membership 仍 onboarding；
- sign-out 成功但 membership 激活失败：membership 仍 onboarding，用户用新密码重新登录后可安全重试；
- **任何半失败都不得让 membership 提前 active。**

---

## 7. 普通登录与启动授权 Gate

完成 onboarding 后：

```text
邮箱 + 密码
  ↓
Supabase Auth
  ↓
验证本地恢复的 Session 是否仍有效/可刷新
  ↓
验证 live session
  ↓
查询 active memberships
  ↓
0 个：无机构访问
1 个：进入
多个：选择当前机构
```

`supabase_flutter` v2 初始化时可能先返回本地持久化 Session，而不保证它已经完成远端刷新。因此：

- App 启动不能因为 `currentSession != null` 就先闪出学生数据；
- 必须经过 Auth/Session + membership 的启动 Gate；
- 失效、revoked、onboarding、disabled 都留在登录/账号状态页；
- 业务 Shell 只在授权解析成功后挂载。

---

## 8. Session 本地存储

`supabase_flutter` 默认使用 SharedPreferences 系列 API 持久化 Session。Production 涉及学生敏感数据时，V1 要在 Phase 0 替换为经过验证的安全本地存储实现：

- 通过 Supabase `LocalStorage` 自定义实现；
- 优先使用操作系统安全存储（Android Keystore、Windows 受保护凭据存储等）或经过审计的跨平台开源封装；
- Refresh/Session token 不进入普通 Preferences、日志或 crash payload；
- **密码本身永不本地持久化**；
- Windows + Android 均做真机/真环境测试。

具体库在 Phase 0 选择并写 ADR，不提前锁死。

---

## 9. 忘记密码：管理员协助 `reset_member_credential`

为了不依赖 SMTP，V1 先走人工身份核验。

安全顺序：
1. 验证 org_admin 权限与目标 member；
2. **先把 membership → onboarding**，立即切断普通业务权限；
3. 生成新的随机临时密码；
4. Auth Admin 更新目标 Auth User 密码，使旧临时密码失效；
5. 设置新的 `onboarding_expires_at`；
6. 写不含密码的 audit；
7. 新临时密码只返回一次；
8. 教师重新执行完整 onboarding；在完成接管时 global sign-out 所有 Session，再重新登录。

如果 Auth 更新失败，member 仍是 onboarding——这是保守且安全的失败状态。管理员可以重试/重新签发。

若 reset 响应丢失，同样重新签发新凭据，不保存旧明文以便“找回”。

---

## 10. 首位管理员与锁死风险

首位 org_admin 使用一次性受信任 bootstrap 建立，完成后关闭入口。

Production Pilot 不应只有一个无法恢复的管理员。上线前至少满足其一：

- 两个由不同可信人员持有的 active org_admin；或
- 一份经过演练的 break-glass 运维流程，由 Supabase Project Owner 在受控环境恢复管理员账号。

break-glass 不是长期公开 API；每次使用都必须留下治理记录并立即复核权限。

---

## 11. 角色与权限范围

V1 角色：
- `org_admin`：成员/角色/学生治理及高风险操作；
- `academic_admin`：教学管理和必要跨学科视角；
- `subject_lead`：本学科范围；
- `teacher`：本人负责学生/学科；
- `student_advisor`：学生综合视角，不随意改写任课教师专业结论。

一个 membership 可以多角色。

`teacher` 绝不能因为角色本身读到机构全量学生。

---

## 12. 停用与离职

正确顺序：
1. 盘点 active teacher/staff assignments；
2. 盘点未结束 case owner、pending actions；
3. 完成交接；
4. 验证无意外 orphan；
5. membership → disabled；
6. RLS 立即拒绝业务访问；
7. 历史记录保留原 creator/teacher。

旧 Access Token 仍可能存在，因此 active membership + live-session guard 都必须成立。

---

## 13. 当前机构上下文

- 一个 active membership：直接进入；
- 多个：展示机构选择器；
- 客户端 current organization 只是 UI 上下文；
- RLS 逐行验证 organization_id，不相信客户端自己声称“当前机构”。

V1 UI 可优先优化单机构，但数据层不能把 organization_id 写死到 global profile。

---

## 14. Phase 0 必测矩阵

Windows 与 Android 至少覆盖：

| 场景 | 结果 |
|---|---|
| 管理员 provision 测试教师 | onboarding |
| onboarding 读取学生数据 | 拒绝 |
| 临时凭据过期后尝试激活 | 拒绝并要求 reissue |
| 临时密码登录后完成接管 | global sign-out + active + 强制重新登录 |
| 被 global sign-out 的旧 Access Token 再请求业务数据 | live-session guard 拒绝 |
| active 新 Session 登录/恢复 | 允许 |
| provision/reset 成功但响应模拟丢失 | 不保存密码，走 reissue |
| 管理员 reset | 先 onboarding，旧业务访问立即拒绝 |
| disabled 旧 Session | 拒绝 |
| Auth User 无 membership | 拒绝 |
| teacher 访问未分配学生 | 拒绝 |
| A 机构访问 B 机构 | 拒绝 |
| App 启动拿到过期/被撤销本地 Session | 不闪现业务数据 |
| 本地 Session 安全存储 | Windows/Android 均验证 |

---

## 15. 未来升级

有可靠 SMTP、企业身份体系或家长/学生自助账号需求后，再新增 ADR 评估 Email OTP / SSO / 企业微信等。

升级原则：
- 只替换登录/账号接入层；
- membership / roles / assignments 继续是业务权限事实源；
- 学生、案例、课程 schema 不跟着重写；
- live Session 与 active membership 的授权底线不降低。
