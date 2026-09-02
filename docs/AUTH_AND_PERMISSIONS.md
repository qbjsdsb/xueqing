# 账号与权限模型

> V1 面向少量、已知、内部教师。目标不是搭建公开 SaaS 注册系统，而是在尽量低成本前提下，把账号接管、机构授权、学科范围、学生分配和旧 Session 风险做对。

## 1. 五层授权必须分开

Phase 0A.6 后，业务授权明确五层：

1. **Auth Identity**：登录身份是谁；
2. **Organization Membership**：该身份在某机构当前处于什么状态；
3. **Role / Capability**：成员承担什么职责、具有什么能力上限；
4. **Subject Scope**：subject-scoped 能力在哪些学科有效；
5. **Student / Staff Assignment**：成员当前具体负责哪些学生/学科或学生综合职责。

普通业务授权至少同时满足：

```text
有效且仍存活的 Auth Session
+ membership = active
+ membership 属于目标 organization
+ role / capability
+ matching subject scope（如需要）
+ matching student/staff assignment（如需要）
+ entity state
+ owner/assignee relation（如需要）
+ operation-specific permission
```

**能够登录 Auth，不等于能够读取机构数据。** 前端隐藏按钮不是权限控制，RLS / 受控服务端 / command policy 才是。

---

## 2. Phase 0B.0 前置：Auth Provider 仍未冻结

当前候选至少包括：
- 官方 Supabase APAC；
- 腾讯 CloudBase PG；
- 中国大陆自托管 Supabase 作为后续可迁移路线。

Phase 0A.6 已确认：CloudBase 与 Supabase 在 PostgreSQL/RLS/PostgREST 心智上相近，但 Auth ID 类型、Session/revoke 细节并非 100% 相同。

因此本文件冻结**安全目标和业务权限语义**，但不在 Phase 0A.6 强行冻结 provider-specific 主键/Session helper。

### 两个正式 migration 前 P0 Gate

#### P0-A｜Auth Identity Portability
必须用虚构数据比较：
- provider-specific Auth PK；
- business Profile UUID + external Auth subject；
- text Auth subject / weak-coupled identity link。

不能在没有 Spike 的情况下把业务 `profiles.id` 永久锁死为某 provider 的 `auth.users.id` 类型。

#### P0-B｜Revoked Session Security
必须证明：

> signOut / credential reset / membership disabled 后，旧 Access Token 即使尚未自然到期，也不能继续读取学生数据。

Supabase reference 可以用 `JWT session_id → auth.sessions`；其他 provider 必须用等价机制达到相同结果。

这两个 P0 未通过前：**禁止正式业务 migration。**

---

## 3. V1 登录方案：管理员受控开通 + Password

为了不把 SMTP、短信、第三方登录变成 V1 前置，默认采用：

```text
org_admin provision_member
  ↓
Auth identity + membership(onboarding)
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

不开放公网自助注册。

以后有可靠邮件/企业身份体系时可以替换 Auth 登录方式，但不能因此重写 organization membership、roles、subject scopes、student/staff assignments、Learning Case / Lesson 业务模型。

---

## 4. Membership 状态

V1：
- `onboarding`：账号已受控创建或刚被重置，尚未安全完成凭据接管；
- `active`：正常机构成员；
- `disabled`：离职/停用。

推荐字段：`joined_at / activated_at / disabled_at / onboarding_expires_at`。

### onboarding 硬规则
- 可以建立最小 Auth Session；
- 普通学生/课程/学情 RLS/API 全部拒绝；
- 只允许账号接管能力；
- 必须有较短有效期；
- 过期后不能自行激活，管理员重新签发；
- 可以预配置 role/subject scope，但 membership active 前不授予学生业务权限。

临时密码不是“一次性 Token”，因此**可信交付 + 短有效期 + onboarding 无业务权限**缺一不可。

---

## 5. V1 多租户身份边界

数据库从第一天支持多个 organization，但 V1 默认不支持同一个 Auth identity 同时在两个机构拥有 onboarding/active membership。

原因不是 PostgreSQL 做不到，而是 V1 的机构管理员可以受控 reset 全局登录 credential；如果一个登录身份同时属于 A/B 两个机构，A 管理员可能影响 B 的登录安全边界。

V1 因此：
- 同一 Auth identity 同时最多一个 onboarding/active organization membership；
- 可保留其他机构 disabled 历史；
- provision 发现另一机构仍 onboarding/active 时拒绝；
- UI 不做跨机构切换器。

未来确有跨机构同账号需求时，先改为中央身份恢复 / Email OTP / SSO 等不由单一机构管理员控制全局 credential 的方案，再解除限制。

---

## 6. 业务 Session 必须仍然存活

仅检查 `membership=active` 不够。

安全目标：

```text
Auth identity 有效
+ 当前 Session 仍有效
+ membership = active
+ 后续 role/scope/assignment/entity/command checks
```

### Supabase Reference

```text
auth.uid()
+ JWT session_id
+ auth.sessions 中对应 Session 仍存在
+ membership active
```

### 其他 Provider
必须证明等价结果，而不是“SDK signOut 看起来成功”就算通过。

Phase 0B.0 要用真实 old-token API/RLS request 验证：unauthenticated、revoked、onboarding、active、disabled、reset 后旧 token、App restart/persisted old token。

---

## 7. Role 与 Subject Scope

V1 roles：
- `org_admin`
- `academic_admin`
- `subject_lead`
- `teacher`
- `student_advisor`

Role 回答“可以做哪一类事情”，**Subject Scope 回答“在哪个学科有效”。**

### `scope_kind = teaching`
适用于 teacher capability，表示可以在该学科承担教师类 Student Assignment / Lesson responsibility。

它**不意味着能读取该学科所有学生。**

### `scope_kind = leadership`
适用于 subject_lead capability，表示该学科的专业管理/审阅范围。

它可以扩大本科治理视角，但不自动成为 Student teacher、Case owner，也不自动允许写 Intervention/Assessment 或访问其他学科。

示例：

```text
roles = teacher + subject_lead
scopes =
  语文 / teaching
  历史 / teaching
  语文 / leadership
```

= 这个老师教语文和历史，但只负责语文学科管理。

---

## 8. Student Assignment 才决定普通教师具体学生范围

`teacher role + teaching scope` 只是“可分配资格”。

普通 Teacher 访问具体学生本科数据仍要匹配 `student_teacher_assignment`。

```text
Teacher C
role=teacher
scope=语文/teaching
但没有 张三·语文 assignment
```

结果：**不能读取张三语文详细学情。**

这条必须由 RLS 负面测试证明。

### Lead / Collaborator

#### Lead
某 Student + Subject 的主要负责教师；通常是 Case owner 的默认候选，并承担关键专业确认责任。

#### Collaborator
可以在合法 assignment 下读取协作所需事实、记录本人真实教学行为、承担 assigned Action；如果不是当前 owner，不自动拥有 stable/close/reopen 等全部关键命令。

Case owner 是责任关系，不是组织角色。

---

## 9. Teaching Fact Gate｜唯一硬定义

这是所有核心事实源必须使用的统一不变量。

任何成员要以“实际教学 actor”身份追加或确认：
- Intervention；
- Assessment；
- 教学型 Evidence；
- Lesson teacher 行为；

**必须同时满足：**

```text
live session
+ active membership
+ teacher capability
+ matching active teaching subject scope
+ target Student Subject Profile = active
+ 对该 student+subject 的合法 active teacher assignment
  或本次由受控 command 建立并验证的合法 Lesson relationship
+ operation-specific permission
```

### 解释
- `active Subject Profile` 是硬条件，不是“通常要求”；
- `live session` 是运行时权限硬条件，即使数据库模型文件没有把它当字段保存，也不能省略；
- assignment / Lesson relationship 不能由 admin role 临时口头绕过；
- inactive/archived Profile 表示当前没有持续该学科教学，普通流程不得产生新的实际教学事实或新 Lesson。

### 管理身份不能伪造教学事实
以下身份单独存在时都不够：
- Subject Lead + leadership scope；
- Academic Admin；
- Org Admin；
- Student Advisor。

如果这些人本人确实参与授课，必须另外通过完整 Teaching Fact Gate。

### 初诊也不能绕过 Gate
管理员可以执行治理动作：
- 创建/恢复 active Subject Profile；
- 为诊断教师建立合法、可审计的 teacher assignment（可以是明确期限/角色的受控关系）；
- 再由该教师执行初诊教学事实。

管理员**不能**用“明确授权初诊”作为跳过 assignment、active Profile 或 teacher capability 的后门。

---

## 10. Advisor / Subject Lead / Admin 边界

### Student Advisor
可读取被分配学生的跨学科必要摘要、协调老师、进行家校沟通、负责综合 follow-up / Stage Review draft。

默认不能修改专业 root-cause judgment、Assessment result、close/reopen 学科 Case、伪造 Intervention，也不能因 Advisor role 读取机构所有学生。

### Subject Lead
必须有 matching leadership scope。可本学科专业审阅、查看治理异常、参与复杂 Case review、执行少量明确 subject-governance command。

不能仅因 leadership scope 写实际教学事实、成为每个 Student 的教师或改其他学科。

### Academic Admin
可以有必要跨学科治理视角与 handoff/异常处理权，但管理权限不等于实际授课身份。

### Org Admin
核心是 membership/roles/scopes/Student master/merge/break-glass 治理；系统管理员身份不等于教学专家。

---

## 11. 管理员开通成员：`provision_member`

输入：目标机构、登录标识（通常 email）、显示名、初始 roles，可选预配置 subject scopes。

服务端：
1. 验证调用者 live Session 与 org_admin；
2. 规范化登录标识、验证 roles/scopes；
3. 检查目标机构既有 membership；
4. 检查该 Auth identity 是否已在另一 organization 有 onboarding/active membership；有则按 V1 拒绝；
5. 生成安全随机临时密码；
6. Auth Admin 创建/受控处理 identity；
7. 建 Profile、membership(onboarding)、roles、可选 scopes、`onboarding_expires_at`；
8. audit 不含密码；
9. 成功响应只返回一次临时密码。

禁止 provider service secret 进入 Flutter、固定默认密码、密码进入业务表/日志/audit/Issue/PR、创建后直接给 active 学生权限。

Auth identity 已创建、membership 失败时允许留下无 membership identity，因为没有业务权限；必须提供恢复流程。响应丢失时 member 保持 onboarding，管理员 reissue/reset 新临时密码，不保存旧明文。

---

## 12. 首次接管：`complete_member_onboarding`

1. 验证当前 Auth Session；
2. membership 属于当前 identity 且为 onboarding；
3. `onboarding_expires_at` 未过期；
4. 校验新密码；
5. Auth Admin 更新当前 credential；
6. 撤销该 identity 的旧 Sessions / Refresh Tokens；
7. 只有 Auth 安全操作成功后 membership→active；
8. 写 audit；
9. App 清理旧机构上下文；
10. 强制使用新 credential 重新登录。

任何半失败都不得提前 active。

---

## 13. 普通登录与启动授权 Gate

```text
登录
→ Auth provider
→ 本地 Session 恢复/远端 validity
→ live-session check
→ 唯一 active membership
→ current organization
→ role/scope/assignment context
→ 业务 Shell
```

`currentSession != null` 不能直接等于“可以渲染学生数据”。

必须区分 revoked/expired、onboarding、disabled/no membership、active。App 启动不得先闪出旧学生数据再异步发现 Session 已失效。

---

## 14. Session 本地存储

Production 涉及学生敏感数据时：
- 使用 OS secure storage；
- Android 使用 Keystore/安全封装；
- Windows 使用系统受保护凭据/安全封装；
- Refresh/Session token 不进普通 Preferences、日志、crash payload；
- **密码永不本地持久化**；
- Windows + Android 真测。

具体 SDK/库随最终 provider 选型做 ADR。

---

## 15. 忘记密码：`reset_member_credential`

1. 教师通过机构既有可信渠道联系管理员；
2. 管理员确认本人；
3. 验证 org_admin 与目标 membership；
4. 先 membership→onboarding，立即切断普通业务权限；
5. 生成新随机临时密码；
6. Auth Admin 更新目标 credential；
7. 撤销旧 Sessions；
8. 设置新 `onboarding_expires_at`；
9. audit 不含密码；
10. 新密码只返回一次；
11. 教师重新走完整 onboarding/revoke/re-login。

Auth 更新失败时 member 仍 onboarding，安全优先。响应丢失时 reissue，不找回旧明文。

---

## 16. 首位管理员 / Break-glass

首位 org_admin 通过一次性可信 bootstrap 建立，完成后关闭入口。

Production Pilot 至少满足：
- 两个由不同可信人员持有的 active org_admin；或
- 已演练的 provider project owner / break-glass。

普通 UI 不允许停用最后一个可恢复 org_admin；对另一个 org_admin 做 credential reset 必须审计；break-glass 不是长期公开 API。

---

## 17. Subject Scope 撤销与离职是两个流程

### 老师仍在职但退出某学科
使用受控 subject-scope handoff：inventory 该学科 assignments、Case ownership、pending Actions，建立接手关系，验证无 orphan，最后结束该 teaching scope。

不能因为退出政治学科把语文/历史权限一起撤掉。

### 整个人离职/停用
盘点全部 teacher/staff assignments、Case owner/pending Actions、subject scopes；完成交接、验证无 orphan；最后 membership→disabled 并 revoke Session；历史 creator/teacher/finalized_by 保留原成员。

---

## 18. Student / Subject Profile lifecycle 权限

普通 Teacher 不能直接通过 Student/Profile status 变化来“清 Today”。

### Subject Profile
- `active`：允许正常教学 tracking；
- `inactive`：服务暂停，禁止新教学事实/新 Lesson；
- `archived`：退出普通业务视图，禁止新教学事实/新 Lesson。

Profile inactive/archive/reactivate/unarchive 都是治理动作并要求 reconciliation。

### Student
Student inactive/archive 也是治理动作，必须先处理 enrollment、profiles、assignments、active Cases、pending Actions 和 audit。

**Student/Profile inactive/archive 均不自动 close Case。**

---

## 19. 家校权限

### V1 Internal Pilot
最小家校能力放在 Student/Case context，不新增教师第五主导航。

### Subject Teacher
可基于本科正式事实创建/确认本科 Parent Communication。

### Advisor
可基于被授权共享的跨学科摘要组织综合沟通，并记录本人真实完成的家校沟通。

### Subject Lead / Academic Admin
按机构规则有 review/governance 权，但不能通过家校文案回写/篡改原 subject finalized professional source。

### Org Admin
治理/纠错权限不等于默认家长沟通责任人。

### Finalized
Finalized Parent Communication 是历史快照：Draft 不等于已联系；finalized 普通 UPDATE 禁止；correction 保留旧 snapshot；家庭配合不是 Guardian-as-Case-Action；家长回应经教师判断后才形成 Evidence/Case。

---

## 20. Stage Review / Report 权限

Subject Stage Review 由对应学科有专业确认权的 Teacher 创建/finalize；Subject Lead 可 review/按机构规则做明确治理命令，但不因此成为实际授课 actor。

Comprehensive Stage Review 可由 Advisor / Academic Admin 组织授权范围内跨学科摘要，但不能修改被引用的各科 finalized source。

AI 可以整理 Draft，不能代替 finalized_by。

---

## 21. Realtime 边界

V1 学生敏感业务表默认不让业务正确性依赖 Realtime。使用页面进入、保存后刷新、App resume、手动刷新。

未来若开启 Realtime，必须新 ADR + revoked-session、token refresh、reconnect、cross-org、subscription cleanup 安全测试。

---

## 22. Phase 0B.0 Auth/RLS 必测矩阵

至少建立虚构：
- Org A / Org B；
- Teacher A：语文 teaching scope，Student 1 Lead，Profile active；
- Teacher B：语文 teaching scope，Student 1 Collaborator，Profile active；
- Teacher C：语文 teaching scope，但无 Student 1 assignment；
- Teacher D：数学 teaching scope；
- Subject Lead E：语文 leadership scope，无 teaching relationship；
- Subject Lead+Teacher F：语文 leadership + teaching scope + Student 1 assignment；
- Advisor G：Student 1 staff assignment；
- Academic Admin；
- Org Admin；
- onboarding / disabled variants；
- Student 2：语文 Profile inactive；
- Student 3：语文 Profile archived。

必须证明：

| 场景 | 结果 |
|---|---|
| onboarding 读取学生数据 | 拒绝 |
| 被撤销旧 token 请求业务数据 | 拒绝 |
| disabled 旧 Session | 拒绝 |
| Teacher C 有 scope 无 assignment | 拒绝 Student 1 详细数据 |
| Teacher D 数学 scope 访问 Student 1 语文 | 拒绝 |
| Collaborator 写本人实际 Intervention | 允许（仅完整 Gate 成立） |
| Collaborator 非 owner 执行受限 close | 拒绝/按 command policy |
| 纯 Subject Lead 写 Intervention/Assessment | 拒绝 |
| Academic/Org Admin 单凭管理身份写教学事实 | 拒绝 |
| Advisor close 语文 Case | 拒绝 |
| **Profile inactive 时，即使旧 teacher assignment/scope 仍存在，写 Intervention/Assessment/教学 Evidence** | **拒绝** |
| **Profile inactive 时 start_lesson** | **拒绝** |
| **Profile archived 时任何普通教学写入/start_lesson** | **拒绝** |
| 管理员“授权初诊”但未建立合法 teacher assignment | 拒绝教学事实写入 |
| 管理员先建立合法诊断 teacher assignment + active Profile 后教师初诊 | 允许 |
| A 机构访问 B 机构 | 拒绝 |
| subject-scope handoff | 只撤目标学科且无 orphan |
| membership disable | 全关系交接后才 disabled |

### 性能
RLS/permission helper 还必须观察 Today / Student / Case 核心查询计划；若 live-session guard 成真实瓶颈，必须 ADR 调整，不能静默删除安全条件。

---

## 23. 未来升级

有可靠 SMTP/企业身份体系，或确实需要同账号跨机构、家长/学生自助登录、企业微信/SSO，再新增 ADR。

升级原则：
- 登录/身份治理层可替换；
- membership/roles/subject scopes/assignments 继续是业务权限事实源；
- Student/Case/Lesson schema 不因登录方式重写；
- active + live Session 安全底线不降低；
- **Teaching Fact Gate 的七项条件不因管理角色、初诊场景或 provider 变化而降低。**
