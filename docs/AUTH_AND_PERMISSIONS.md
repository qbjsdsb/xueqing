# 账号、邀请与权限模型

## 1. 核心原则

- **Auth User** 回答“这个登录身份是谁”；
- **Organization Invitation** 回答“这个邮箱是否正在被邀请加入机构”；
- **Organization Membership** 回答“这个账号在某机构是否已经成为有效成员”；
- **Role** 回答“这个成员具有哪类职责”；
- **Assignment** 回答“这个成员和哪些学生/学科存在业务关系”。

任何一个层级都不能单独代表完整权限。

最重要的一条：**pending invitation 没有机构业务数据访问权；只有 active membership 才进入 RLS 授权链。**

## 2. V1 账号策略：机构邀请 / 受控开通

V1 不开放“任何人自行注册后直接进入机构”。

新邮箱的推荐流程：

```text
机构管理员提交邀请
  ↓
服务端验证管理员、机构、角色
  ↓
创建 organization_invitation(pending)
  ↓
调用 Supabase Auth Admin 发送 invite
  ↓
记录 Auth User ID / sent_at
  ↓
教师完成邮箱激活并登录
  ↓
受控激活流程验证 invitation + 当前 Auth User
  ↓
创建 active organization_membership + roles
  ↓
invitation → accepted
```

这样即使邮件发送、过期、重发或取消，正式 membership 也不会被迫承担邮件工作流状态。

第一阶段优先使用邮箱身份，因为不依赖短信付费通道。

在写正式业务前，必须用技术 Spike 验证 **Android + Windows 的首次激活、密码设置/重置、邀请链接回跳体验**。

## 3. Redirect 与邀请有效期

邀请、密码恢复等邮件流程如果需要回到 App：
- redirect URI 必须加入 Supabase Auth 的允许 Redirect URLs；
- Remote Development / Production 使用不同 scheme/host 时分别配置；
- redirect 由受信任服务端按环境选择，客户端不能传任意 URL；
- 配置错误时必须有可理解的失败/恢复入口；
- Windows 与 Android 分别真测 App 已运行 / 未运行两种情况。

邀请链接有有效期，因此管理员端必须支持：
- pending invitation 查看；
- 过期/失败后的重发；
- 取消邀请；
- 重发时复用同一 invitation，而不是生成第二个“成员”。

## 4. 首位管理员如何出现

邀请制无法自己产生第一个管理员。

V1 采用受控 bootstrap：
- Local / Development：seed + 明确测试脚本创建虚构 org_admin；
- Production 首次部署：受信任运维/一次性函数创建 organization + active org_admin membership；
- bootstrap 完成后关闭/撤销一次性入口。

禁止：
- 在客户端隐藏“超级管理员密码”；
- 公开任何人可调用的建机构/提权接口；
- 把 service_role / Secret Key 放进 Flutter。

## 5. 不允许公开注册直接获得机构权限

即使未来允许普通 Auth 注册：
- Auth User 只代表登录身份；
- pending invitation 不代表已入机构；
- 没有 active membership 就看不到机构业务数据；
- 用户不能自己把自己加入机构；
- 用户不能自己给自己添加 teacher/admin 角色。

## 6. Auth User ≠ Membership

同一个 Auth User 的长期模型允许属于多个机构，每个机构拥有独立：
- membership；
- 角色；
- 学生关系；
- 权限。

因此不能把永久 `organization_id` 写死在 profile 上。

**数据库支持多机构，不等于 V1 必须做复杂多机构 UX。** 首机构试运行优先保证“一人一个主要机构”的流程清楚。

## 7. 授权事实源

正式授权以：
- `organization_memberships`
- `membership_roles`
- `student_teacher_assignments`
- `student_staff_assignments`
- 学科/学生关系

为事实源。

`organization_invitations` 只用于 onboarding 工作流，不给学生数据访问权。

不要把可由用户修改的 `user_metadata` 当作 RLS 或权限依据。

如果未来把角色写入 JWT/App Metadata，只能作为受控缓存/声明；数据库事实源仍然必须实时检查，尤其 membership disabled 场景。

## 8. V1 角色

### `org_admin`
- 成员与邀请管理
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

## 9. 权限不是只有 Role

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

例如：`teacher` 角色本身绝不能意味着读取机构全部学生。

## 10. V1 权限矩阵（概念级）

| 操作 | 任课教师 | 学生负责人/学管 | 学科负责人 | 管理员 |
|---|---|---|---|---|
| 查看本人负责学生基础档案 | 是 | 是 | 本科关系范围 | 是 |
| 查看本人负责学科详细学情 | 是 | 综合/按授权 | 本科范围 | 是 |
| 修改本人负责学科案例 | 是 | 默认否 | 按业务关系 | 受控 |
| 查看其他学科详细学情 | 默认否 | 必要综合视角 | 默认否 | 是 |
| 新建综合观察 | 后续按规则 | 是 | 按规则 | 是 |
| 创建/取消邀请 | 否 | 否 | 否 | 受控 |
| 修改机构角色 | 否 | 否 | 否 | 受控 |
| 合并重复学生 | 否 | 否 | 否 | 受控 |
| 停用成员 | 否 | 否 | 否 | 受控 |

具体 SQL policy 以自动化权限测试为准。

## 11. 创建邀请必须服务端化

客户端只提交必要参数：
- email；
- organization ID；
- 预期 role codes。

受信任服务必须：
1. 验证 Session；
2. 验证管理员对该机构的邀请权限；
3. 规范化并校验邮箱；
4. 验证角色是否允许授予；
5. 检查已有 invitation / membership / Auth 状态；
6. 创建或复用 pending invitation；
7. 执行 Auth Admin 邀请；
8. 写入 `invited_auth_user_id / sent_at / last_sent_at`；
9. 写 audit log；
10. 返回不包含秘密的结果。

Secret Key 永远只存在函数环境变量中。

由于 Auth 调用和 public schema 写入不能简单假设为一个数据库事务，流程必须 **幂等、可恢复、可重试**。例如邮件发送成功但后续状态写入失败时，管理员重新操作不应制造第二条 invitation/member。

## 12. 新邮箱、未完成邀请、已有正式成员、已有确认 Auth User 分开处理

### A. 新邮箱
- 创建 pending invitation；
- Auth Admin 发送 invite；
- 用户激活后通过受控流程创建 membership。

### B. 已有 pending invitation
- 不创建第二条 invitation；
- 必要时重发邮件并更新 last_sent_at；
- 可由管理员取消；
- 不存在 active membership 之前仍无业务数据权限。

### C. 已经是目标机构 active member
- 不再发送加入邀请；
- 根据实际问题进入登录、密码恢复、角色调整等流程。

### D. 邮箱已经是 confirmed Auth User，但不是目标机构成员
Supabase 标准 `inviteUserByEmail` 不能被当成“已确认账号加入第二机构”的通用入口。

V1 首机构试运行：
- 若尚未实现受控 `link-existing-user`，明确提示“该邮箱已有平台账号，当前版本暂不支持跨机构关联”；
- 不重复创建第二个 Auth User；
- 真正有业务需求后，设计受控 link-existing-user：验证目标 Auth User、机构管理员权限、账号归属/确认流程，再创建新 membership。

数据库模型保留多机构能力，但 UI 不提前为少见场景增加复杂度。

## 13. 接受邀请 / 激活 membership

用户通过邮件完成 Auth 激活并进入 App 后，不能仅凭“登录成功”自动获得机构权限。

受控激活流程应验证：
1. 当前 auth.uid()；
2. 当前已确认邮箱；
3. 存在与该邮箱/organization 匹配的 pending invitation；
4. invitation 未取消；
5. 预期角色仍可授予；
6. 不存在冲突 active membership。

然后：
- 创建 active membership；
- 创建 membership_roles；
- invitation → accepted；
- 写 audit；
- 返回机构上下文。

这一步应尽量事务化；如果 Auth/email 与 DB 之间仍有不可原子边界，必须设计安全重试和补偿。

## 14. 邀请邮件不是业务身份

因此：
- 邮件过期不等于删除 invitation；
- 重发邀请不等于创建第二条 invitation/member；
- 取消 invitation 不等于删除 Auth User；
- 已 active member 重置密码不影响 membership；
- pending invitation 绝不能通过 RLS 读机构业务数据。

## 15. 停用与离职

教师离职：
1. 列出 active teacher/staff assignments；
2. 列出未结束 learning_case owner；
3. 列出 pending case_actions；
4. 完成交接或显式处理责任项；
5. 结束旧 assignments；
6. membership → disabled；
7. 数据库权限立即拒绝；
8. 历史记录保留原 creator/teacher。

**不允许先停用，再让责任项悄悄变成无人负责。**

V1 优先停用 membership，而不是删除整个 Auth User。

### Session 注意
旧 Access Token 可能尚未过期。RLS 必须每次通过数据库 membership 检查 active 状态，而不是只相信旧 JWT 中的角色声明。

客户端遇到 membership disabled / authorization denied 时应退出机构上下文并明确提示，不反复死循环重试。

## 16. 当前机构上下文

一个用户只有一个 active membership 时，直接进入该机构。

未来若有多个 active memberships：
- 登录后选择当前机构；
- 客户端维护 current organization context；
- 查询显式处于机构上下文；
- RLS 仍逐行验证，不相信客户端选项本身。

## 17. RLS helper 设计

允许建立少量、经过审计的 helper，避免 policy 复制大段 SQL。

要求：
- 优先简单、稳定、可索引；
- `security definer` helper 放非 exposed schema；
- `set search_path = ''`；
- 显式 schema-qualified；
- revoke 默认 execute，再按需 grant；
- member / non-member / disabled / cross-org 都有测试。

## 18. Phase 0 认证测试矩阵

| 场景 | Windows | Android |
|---|---|---|
| 新邮箱首次邀请 | 必测 | 必测 |
| pending invitation 重发 | 必测 | 必测 |
| 邀请取消 | 必测 | 必测 |
| 邀请链接过期 | 必测 | 必测 |
| active 用户登录 | 必测 | 必测 |
| 密码恢复 | 必测 | 必测 |
| App 已运行时回跳 | 必测 | 必测 |
| App 未运行时回跳 | 必测 | 必测 |
| redirect 不在 allowlist | 必测 | 必测 |
| membership disabled 后旧 Session | 必测 | 必测 |
| 已 confirmed Auth User 跨机构但 V1 未开放 | 明确提示 | 明确提示 |

## 19. 权限/账号测试最低集合

任何 V1 发布候选至少验证：
1. 未登录不能读取业务表；
2. pending invitation 不能读取业务表；
3. disabled membership 不能读取业务表；
4. A 机构成员无法读取 B 机构学生；
5. 教师无法扩大到未分配学生；
6. 语文教师不能修改数学核心学情；
7. 学生负责人综合视角不等于无限编辑权；
8. 普通教师调用管理员函数被拒绝；
9. 管理员只能管理有权机构；
10. View/Function 不成为 RLS 后门；
11. 旧 Token + disabled membership 仍被数据库拒绝；
12. 已确认邮箱不会错误走“新用户 invite”；
13. pending invitation 重发不会产生重复 invitation/member；
14. 接受 invitation 后 membership/roles/invitation 状态保持一致；
15. 邀请失败/中断后可以安全重试。