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

推荐字段：`joined_at / activated_at / disabled_at / onboarding_expires_at`。

### onboarding 的硬规则
- 可以建立 Auth Session；
- 普通学生/课程/学情 RLS 全部拒绝；
- 只允许最小账号接管能力；
- 必须有较短的接管有效期；具体时长在 Phase 0 实测后固定；
- 过期后不能自行激活，管理员必须重新签发临时凭据；
- 管理员可取消/停用未完成 onboarding。

临时密码不是“一次性 Token”，谁先拿到它谁就可能尝试接管，因此**可信交付 + 短有效期 + onboarding 无业务权限**缺一不可。

---

## 4. V1 的多租户身份边界

数据库从第一天支持多个 organization，但 **V1 不支持同一个 Auth User 同时在两个机构拥有 onboarding/active membership**。

原因：V1 Password 是全局 Supabase Auth credential，而机构 org_admin 可以做 `reset_member_credential`。如果同一账号同时属于 A/B 两机构，A 管理员重置全局密码就会影响 B，违反租户边界。

V1 因此：
- 同一 `user_id` 同时最多一个 onboarding/active membership；
- 可以保留其他机构 disabled 历史；
- schema 使用 partial unique/受控命令防双活；
- `provision_member` 发现目标 Auth User 已在另一机构非 disabled 时拒绝；
- UI 不做跨机构账号切换器。

未来确有一个教师加入多机构的需求时，先改成中央身份恢复、Email OTP/SSO 等“不由某一个机构管理员控制全局 credential”的方案，再移除限制。

这不影响“系统多租户”：不同机构仍可各自拥有不同成员，数据库/RLS 仍严格 organization 隔离。

---

## 5. 业务 Session 必须仍然存活

仅检查 `membership = active` 还不够。

Supabase JWT 带 `session_id`，对应 `auth.sessions`。用户 sign out 后相关 session 会从 `auth.sessions` 移除，但已经签发的 Access Token 在 `exp` 前仍可能被客户端携带使用。

因此 V1 对学生业务数据采用：

```text
auth.uid() 有效
+ JWT session_id 存在
+ 对应 auth.sessions 记录仍存在
+ membership = active
+ 后续 role / assignment 检查
```

实现建议：
- 少量经过审计的非 exposed `security definer` helper；
- `set search_path = ''`，schema-qualified；
- revoke 默认 execute，再最小 grant；
- RLS 中避免重复求值；
- Phase 0 用 EXPLAIN/真实查询验证开销；
- unauthenticated/revoked/onboarding/active/disabled/cross-org 全有负面测试。

这是 V1 为学生敏感数据选择的额外安全保证，不依赖付费 Session lifetime/single-session 功能。

---

## 6. 管理员开通成员：`provision_member`

输入：目标机构、教师邮箱、显示名（可选）、初始 roles。

服务端：
1. 验证调用者 live Session 与 org_admin；
2. 规范化邮箱、验证角色；
3. 检查目标机构既有 member；
4. 检查该 Auth User 是否已在另一 organization 有 onboarding/active membership；有则按 V1 规则拒绝；
5. 生成安全随机临时密码；
6. Auth Admin 创建/受控处理 Auth User；对已知内部教师可 `email_confirm=true`；
7. 建 profile、`membership(onboarding)`、roles、`onboarding_expires_at`；
8. 写**不含密码**的 audit；
9. 成功响应只返回一次临时密码。

### 禁止
- Secret/service_role 进入 Flutter；
- 固定默认密码；
- 密码进入业务表、日志、audit、错误上报、Issue/PR；
- 创建后直接给 active 权限。

### 跨系统半失败
Auth Admin 与业务 PostgreSQL 不是同一事务域。

- Auth User 已创建、membership 失败：可能留下无 membership 的 Auth User；这是安全失败，因为没有业务权限；
- membership 不得在 Auth 身份尚未安全建立时 active；
- 每种半失败必须返回可识别错误状态。

### 响应丢失
创建成功但响应丢失，管理员可能拿不到临时密码。因为不保存明文：
- member 保持 onboarding；
- 显示“凭据交付状态未知”；
- 管理员 reissue/reset 生成全新临时密码；
- 绝不为幂等保存可恢复明文凭据。

---

## 7. 首次接管：`complete_member_onboarding`

教师临时密码登录后只看到账号接管页。

流程：
1. 验证当前 Auth Session、`auth.uid()`、`session_id`；
2. membership 属于当前用户且为 onboarding；
3. `onboarding_expires_at` 未过期；
4. 校验新密码；
5. Auth Admin 更新当前用户密码；
6. 以当前有效 JWT 执行 global sign-out，撤销该用户所有 Sessions/Refresh Tokens；
7. **只有 Auth 安全操作成功后**，membership→active，写 `activated_at`/audit；
8. App 清理旧机构上下文；
9. 教师必须用新密码重新登录，新 live Session 才进入机构。

### 为什么必须重新登录
如果有人此前偷到临时密码并建立 Session，只改密码再直接 active，旧 Access Token 可能在过期前继续存在。global sign-out + live-session RLS guard 阻断这种 Session。

### 半失败
- 密码更新失败 → onboarding；
- 密码成功、global sign-out 失败 → onboarding；
- sign-out 成功、membership 激活失败 → onboarding，用户用新密码登录后可重试；
- **任何半失败都不得提前 active。**

---

## 8. 普通登录与启动授权 Gate

完成 onboarding 后：

```text
邮箱 + 密码
→ Supabase Auth
→ 本地 Session validity / refresh
→ live session
→ 唯一 active membership
→ current organization
→ 业务 Shell
```

`supabase_flutter` v2 初始化可能先返回本地持久化 Session，不保证远端刷新完成。因此：
- `currentSession != null` 不等于可以渲染学生页；
- 必须经过启动 Gate；
- revoked/expired → 登录页；
- onboarding → 接管页；
- disabled/no membership → 无权限页；
- active → 业务页。

---

## 9. Session 本地存储

`supabase_flutter` 默认使用 SharedPreferences 系列 API 持久化 Session。Production 涉及学生敏感数据时，Phase 0 替换为安全自定义 `LocalStorage`：
- OS secure storage；
- Android Keystore/安全封装；
- Windows 系统受保护凭据/安全封装；
- Refresh/Session token 不进普通 Preferences、日志、crash payload；
- **密码永不本地持久化**；
- Windows + Android 真测。

具体开源库 Phase 0 选型并写 ADR。

---

## 10. 忘记密码：`reset_member_credential`

1. 教师通过机构既有渠道联系管理员；
2. 管理员确认本人；
3. 验证 org_admin 与目标 membership；
4. **先 membership→onboarding**，立即切断业务；
5. 生成新随机临时密码；
6. Auth Admin 更新目标密码，使旧临时密码失效；
7. 设置新 `onboarding_expires_at`；
8. audit 不含密码；
9. 新密码只返回一次；
10. 教师重新走完整 onboarding/global sign-out/re-login。

Auth 更新失败时 member 仍 onboarding，安全优先。响应丢失时 reissue，不找回旧明文。

---

## 11. 首位管理员 / Break-glass

首位 org_admin 通过一次性可信 bootstrap 建立，完成后关闭入口。

Production Pilot 至少满足：
- 两个由不同可信人员持有的 active org_admin；或
- 已演练的 Supabase Project Owner break-glass。

额外规则：
- 普通 UI 不允许停用最后一个可恢复 org_admin；
- 对另一个 org_admin 做 credential reset 必须审计；
- break-glass 不是长期公开 API。

---

## 12. 角色与权限范围

V1：
- `org_admin`：成员/角色/学生治理和高风险操作；
- `academic_admin`：教学管理、必要跨学科；
- `subject_lead`：本学科范围；
- `teacher`：本人负责学生/学科；
- `student_advisor`：综合视角，不随意改写专业结论。

一个 membership 可多角色，但 `teacher` 绝不能因角色本身读取机构全学生。

---

## 13. 停用与离职

1. 盘点 active teacher/staff assignments；
2. 盘点 active case owner/pending actions；
3. 完成交接；
4. 验证无 orphan；
5. membership→disabled；
6. RLS 立即拒绝；
7. 历史记录保留原 creator/teacher。

禁止普通流程停用最后一个可恢复 org_admin。

---

## 14. Realtime 边界

V1 学生敏感业务表默认不启用 Realtime，也不让业务正确性依赖 Realtime。

使用页面进入/保存后/App resume/手动刷新。未来若开启，必须新 ADR + revoked-session、token refresh、reconnect、cross-org、subscription cleanup 安全测试。

---

## 15. Phase 0 必测矩阵

| 场景 | 结果 |
|---|---|
| provision 测试教师 | onboarding |
| onboarding 读取学生数据 | 拒绝 |
| 同 user 第二机构 provision | 拒绝（V1） |
| 临时凭据过期后激活 | 拒绝并 reissue |
| 完成接管 | 改密码 + global sign-out + active + 强制重新登录 |
| 被撤销旧 JWT 请求业务数据 | live-session guard 拒绝 |
| active 新 Session | 允许 |
| provision/reset 响应模拟丢失 | 不保存密码，走 reissue |
| reset | 先 onboarding，旧业务访问立即拒绝 |
| disabled 旧 Session | 拒绝 |
| Auth User 无 membership | 拒绝 |
| teacher 访问未分配学生 | 拒绝 |
| A 机构访问 B 机构 | 拒绝 |
| App 启动拿到失效本地 Session | 不闪业务数据 |
| Session 安全本地存储 | Windows/Android 验证 |

---

## 16. 未来升级

有可靠 SMTP/企业身份体系，或确实需要跨机构同账号、家长/学生自助登录后，再新增 ADR 评估 Email OTP / SSO / 企业微信等。

升级原则：
- 登录/身份治理层可替换；
- membership/roles/assignments 继续是业务权限事实源；
- 学生/case/lesson schema 不因登录方式重写；
- active + live Session 的安全底线不降低。
