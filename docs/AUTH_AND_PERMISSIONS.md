# 账号、邀请与权限模型

## 1. V1 账号策略：机构邀请制

V1 不开放“任何人自行注册后进入系统”。

推荐流程：

```text
机构管理员
  ↓
邀请教师/员工
  ↓
受信任服务端调用 Supabase Auth Admin
  ↓
创建或关联 Auth User
  ↓
创建 organization_membership（invited）
  ↓
用户完成首次登录
  ↓
membership 激活
```

第一阶段优先使用 **邮箱邀请 + 密码/登录链接**，原因是实现成本低、不依赖短信付费通道。将来如果机构确实需要手机号、企业微信等登录方式，可以替换认证入口，但不应改变 organization membership 与业务权限模型。

## 2. 不允许公开注册直接获得机构权限

即使未来允许普通 Auth 注册：
- 注册只代表“有一个账号”；
- 没有 active organization_membership 就看不到机构业务数据；
- 用户不能自己把自己加入某机构；
- 用户不能自己给自己添加 teacher/admin 角色。

## 3. Auth User ≠ 机构成员

### Auth User
表示“这个登录身份是谁”。

### Organization Membership
表示“这个账号在某个机构里是什么状态”。

同一个 Auth User 将来可以属于多个机构，每个机构拥有独立：
- membership；
- 角色；
- 学生关系；
- 权限。

因此不能把一个永久 `organization_id` 写死在 user profile 上。

## 4. 授权数据放在哪里

正式授权以数据库里的：
- `organization_memberships`
- `membership_roles`
- `student_teacher_assignments`
- 学科/学生关系

为事实源。

不要把可由用户修改的 `user_metadata` 当作 RLS 或权限依据。

如果未来为性能把角色写入 JWT/App Metadata，它也只能作为受控缓存/声明，并必须考虑 JWT 不是实时刷新的问题；数据库事实源仍要保持清楚。

## 5. V1 角色

### `org_admin`
- 成员管理
- 角色管理
- 学生治理
- 交接/合并等高风险操作
- 机构级查看

### `academic_admin`
- 教学管理视角
- 跨学科查看
- 不默认拥有 Auth/系统最高权限

### `subject_lead`
- 本学科范围查看
- 教研/异常视角
- 不默认修改其他老师全部历史事实

### `teacher`
- 查看被分配学生
- 管理自己负责学科的案例、干预、验证、课程
- 查看允许共享的综合信息

### `homeroom_or_advisor`
- 学生综合视角
- 综合观察与家校协调
- 不随意改写任课教师的专业学科结论

一个 membership 可以有多个角色。

## 6. 权限不是只有 Role

最终授权至少由五个因素共同决定：

```text
用户是否已登录
  + membership 是否 active
  + 是否属于该 organization
  + membership roles/capabilities
  + 与该学生/学科是否存在有效 assignment
```

例如：

> “teacher” 这个角色本身不能意味着可以读取机构所有学生。

## 7. 建议权限矩阵（V1）

| 操作 | 任课教师 | 班主任/学管 | 学科负责人 | 管理员 |
|---|---|---|---|---|
| 查看本人负责学生基础档案 | 是 | 是 | 本科范围 | 是 |
| 查看本科详细学情 | 是 | 综合/按授权 | 本科范围 | 是 |
| 修改本人负责学科案例 | 是 | 默认否 | 按业务关系 | 是/受控 |
| 查看其他学科详细学情 | 默认否 | 必要综合视角 | 默认否 | 是 |
| 新建综合观察 | 是 | 是 | 是 | 是 |
| 修改机构角色 | 否 | 否 | 否 | 是 |
| 合并重复学生 | 否 | 否 | 否 | 受控 |
| 停用账号 | 否 | 否 | 否 | 受控 |

具体 SQL policy 以测试后的实现为准。

## 8. 管理员邀请必须服务端化

客户端发送：
- 被邀请邮箱
- 机构 ID
- 预期角色

Edge Function：
1. 验证当前 Session；
2. 验证调用者拥有该机构成员管理能力；
3. 调用 Auth Admin；
4. 创建/更新 membership；
5. 写 audit log；
6. 返回不包含秘密的结果。

Secret Key 永远只存在函数环境变量中。

## 9. 已存在账号再次加入机构

邀请服务不能假定“邮箱一定是新用户”。

如果 Auth User 已存在：
- 不重复创建用户；
- 创建新的 organization membership；
- 让用户登录后选择/进入有权机构。

因此业务身份不能和“注册时只属于一个机构”绑定死。

## 10. 停用与离职

教师离职：
1. membership → disabled；
2. RLS 立即拒绝机构数据；
3. 结束 active assignments；
4. 将未完成案例/行动交接给新负责人；
5. 历史记录保留原 creator/teacher；
6. 不因为离职删除课程、案例、沟通历史。

V1 应优先“停用机构 membership”，而不是随意删除整个 Auth User。

## 11. Session 与当前机构

如果一个用户只有一个 active membership，登录后直接进入该机构。

如果未来存在多个 active memberships：
- 登录后选择当前机构；
- 客户端所有查询显式处于该机构上下文；
- RLS 仍根据每一行 organization_id 验证，不能只相信客户端当前机构选择。

## 12. 权限测试最低集合

任何 V1 发布候选都必须验证：

1. 未登录用户读取业务表失败；
2. disabled membership 读取失败；
3. A 机构成员无法读取 B 机构学生；
4. 教师无法通过手工请求扩大到未分配学生；
5. 语文教师不能直接修改数学核心学情；
6. 班主任的综合视角符合设计但不拥有无限编辑权；
7. 普通教师调用管理员 Edge Function 被拒绝；
8. 管理员只能管理自己有权限的机构。
