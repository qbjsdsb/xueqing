# 安全、隐私与恢复基线

> V1 最低安全门槛。系统涉及未成年学生信息，任何功能不得以“先跑起来”或“为了免费”为理由绕过这些要求。

## 1. 数据最小化

只收集完成教学目的真正需要的数据。

### A. 身份与联系信息（高敏感）
- 学生姓名
- 家长姓名与联系方式
- 教师邮箱/联系方式
- 学校、班级等可组合识别信息

### B. 教学与学情信息（敏感）
- 学情案例
- 作业、试卷、作文、测验
- 课堂观察
- 家校沟通
- 成长报告

### C. 系统元数据
- Auth User ID
- organization / membership / role / assignment ID
- 操作时间与对象 ID

开发、测试、截图、seed 仅使用明显虚构数据。

不要因为“以后可能有用”收集与教学目的无关的家庭、健康、身份背景等敏感信息。

## 2. Password Auth 与机构授权安全边界

V1 采用管理员受控开通 + Password，但登录身份与业务权限仍彻底分离。

关键原则：
- Auth Session 不等于机构权限；
- 无 membership 不能读机构业务数据；
- membership = onboarding 不能读普通业务数据；
- membership = disabled 不能读普通业务数据；
- 只有 active membership 才进入 roles/assignments/RLS；
- 密码 reset 后 membership 回 onboarding，使旧 Session 也失去业务权限。

不能只依赖 JWT 中的旧角色声明判断 active 状态。

## 3. 临时密码安全

管理员开通/重置账号时产生临时凭据。

要求：
- 服务端使用安全随机源生成；
- 不使用固定默认密码；
- 不写 PostgreSQL 业务表；
- 不写 audit；
- 不写 console/server/error-tracking 日志；
- 不写 GitHub Issue/PR；
- 只在成功响应中返回一次；
- 管理员通过已建立身份关系的可信渠道一次性交付；
- 教师首次登录后完成自己的新密码接管。

生产日志/监控的“请求 body 自动记录”必须避免抓取 credential payload。

## 4. Credential 高权限操作

### `provision_member`
- 只有有权 org_admin 可调用；
- Secret/service_role 仅在可信服务端；
- 创建/处理 Auth User 后只创建 onboarding membership；
- 失败不应留下错误 active 权限。

### `complete_member_onboarding`
- 只能更新当前 Session 自己的凭据；
- 先完成 Auth 密码更新，再允许 membership active；
- 半失败优先收敛到无业务权限状态；
- 新密码不进入日志。

### `reset_member_credential`
- 管理员先按机构制度确认本人；
- 生成新随机临时密码；
- membership → onboarding；
- 旧 Session 立刻因 RLS 失去业务权限；
- 写审计，但审计不记录密码。

Auth 和业务数据库不是同一事务域，所以实现需要明确失败恢复和幂等，而不是假设“一个 Edge Function 天然原子”。

## 5. 自由文本风险

最容易泄露隐私的地方往往是备注，而不是结构化字段。

因此：
- Observation 强调可观察事实；
- 家校沟通只保存必要摘要；
- 不鼓励长期复制聊天全文；
- 不把人格判断、未经证实的健康/家庭推断写成正式学情；
- UI 提示避免输入无关敏感信息。

## 6. 客户端密钥边界

Flutter 只允许持有 Supabase Publishable Key（或旧项目 anon key）。它是公开客户端凭据，安全依赖 RLS/GRANT，而不是“把 key 藏起来”。

客户端绝不得包含：
- Secret Key
- service_role
- 数据库密码
- 临时/正式用户密码的持久化副本
- SMTP Secret
- AI/第三方私钥

高权限凭据只放受信任服务端环境。

## 7. 数据库访问

所有客户端业务表：
1. 显式 RLS；
2. 最小 GRANT；
3. SELECT / INSERT / UPDATE / DELETE 分别验证；
4. 跨机构默认拒绝；
5. 敏感跨学科默认拒绝；
6. 普通业务要求 membership = active；
7. 高频 RLS 字段建立索引。

前端隐藏按钮不是安全控制。

## 8. View 与 Function

### View
客户端暴露 View：
- 优先 `security_invoker = true`；
- 或放非 exposed schema / 受控函数；
- 单独做越权测试。

### Database Function
默认 `security invoker`。

确需 `security definer`：
- 非 exposed schema；
- `set search_path = ''`；
- schema-qualified；
- revoke 默认 execute，再最小 grant；
- 必须有越权测试。

### Edge Function
持有 Auth Admin/Secret 的 Edge Function：
- 每次验证调用者 Session；
- 验证 organization 和能力；
- 不因为运行在服务端就默认可信输入；
- 不记录 credential 明文。

## 9. 多租户隔离

- 机构数据明确 `organization_id`；
- active membership 是机构访问第一道业务条件；
- teacher 继续检查 student/subject assignment；
- advisor 检查 staff assignment；
- 跨机构请求数据库层拒绝；
- 冗余 organization_id 防止跨机构错配。

Auth User 的存在、JWT 的存在、onboarding membership 的存在都不能替代 active membership 检查。

## 10. 高权限与不变量操作

受控操作包括：
- 首位 org_admin bootstrap；
- provision / onboarding / credential reset；
- 角色提升；
- teacher handoff + disable；
- 学生合并；
- 数据导出/删除；
- 未来需要 Secret 的第三方集成。

都必须再次验证 actor、organization、状态与参数。

## 11. 审计

记录关键治理动作：
- actor user/membership；
- organization；
- entity type/id；
- action；
- changed fields；
- operation id；
- occurred_at。

Credential audit 只记录“开通/完成接管/重置发生过”，不记录密码。

不要把 audit_logs 变成第二份学生敏感正文数据库。

`case_events` 与 `audit_logs` 原则上 append-only。

## 12. 删除、归档与更正

- 教师离职：disable membership，不删除历史；
- 学生退班：归档；
- 普通教师不硬删除核心事实；
- 误录通过更正事件/归档语义处理；
- 学生合并保留 merge mapping；
- 真正个人信息删除/导出走管理员数据治理流程。

不要把日常“删除按钮”直接映射成跨表 cascade delete。

## 13. Storage

附件默认私有 bucket：
- 不公开 bucket；
- 授权访问或短时签名 URL；
- 路径含 organization_id + 不可猜测 UUID；
- 不用真实姓名做公开路径；
- 限制文件类型/大小；
- 后续按需要评估恶意文件扫描。

DB 记录删除与 Storage 对象删除走受控一致性流程。

V1 使用 Free Storage 时应严格控制大附件，避免把系统变成原始扫描件仓库。

## 14. 环境隔离

明确：
- Local Development：虚构数据；
- Remote Development：虚构数据/真实集成；
- Production Pilot：真实机构数据。

Production 与开发环境不共享数据库、Storage、Secret、测试账号。

Schema/RLS 等正式变化必须进入 Git migrations。

Production 禁止 development reset/seed。

## 15. 日志与错误上报

不得记录：
- Password / 临时密码
- Access/Refresh Token
- Authorization header
- Secret
- 完整家校沟通
- 完整作文/试卷
- 不必要学生姓名/联系方式

优先记录：错误码、operation id、对象 UUID、App version、调用路径。

## 16. 备份与恢复：Free Tier 仍是硬要求

### PostgreSQL
Supabase Free 不具备付费计划同等级的自动备份保障，因此：
- 定期 `supabase db dump` / `pg_dump`；
- 加密离站保存；
- 保留多个时间点；
- 定期实际恢复演练。

### Storage
数据库备份不等于附件备份。

需要：
- 对象清单；
- 文件备份；
- 抽样恢复；
- DB path ↔ Storage object 一致性检查。

### Git / Schema
GitHub 保存代码和 migrations，但 migrations 不替代业务数据备份。

备份“存在”不等于可恢复；恢复演练才是证据。

## 17. 网络与可用性

真实机构上线前测试：
- Password 登录；
- provision / onboarding / reset；
- reset/disable 后旧 Session；
- 常规读写；
- 图片上传；
- Functions；
- 长时间 Session；
- Wi-Fi/移动网络切换；
- 断网/恢复后的草稿。

不能只在开发者自己的网络环境判断可上线。

## 18. 客户端保存状态

高频表单至少有：
- 未保存
- 保存中
- 已保存
- 保存失败/可重试

网络失败不得丢输入；本地 draft 只用于待提交恢复，不是第二套正式数据库。

## 19. GitHub / ChatGPT 云端开发隐私

- 仓库进入真实开发前必须 Private；
- Private 不等于可以提交真实学生数据；
- ChatGPT Work/Codex 任务只使用完成开发所需的最小信息；
- 不把真实账号凭据、学生试卷、家校正文粘到 Issue/PR/开发 seed；
- GitHub 是代码事实源，聊天历史不是；
- 云端 Agent 不能运行测试时必须明确“未执行”，不能伪造执行结果。

## 20. 免费额度与成本安全

本阶段不新增：
- SMTP/域名/SMS；
- Supabase Pro/add-on；
- AI API；
- 商业错误追踪/分析 SaaS；
- GitHub larger runner；
- Work/Codex 额外 credits。

免费额度接近上限时先限制/评审，不开启自动超额付费。

但“免费”不能成为关闭 RLS、删除备份、复用弱密码或省测试的理由。

## 21. 安装包与签名

### Android
- keystore 不进 GitHub；
- 安全备份；
- 不以 Debug 包长期生产分发。

### Windows
- 明确安装/升级渠道；
- 正式部署后评估代码签名需求，降低安装警告和篡改风险。

## 22. 真实数据 Go / No-Go

至少完成：
- GitHub 仓库已 Private；
- Local / Remote Development / Production 隔离；
- migrations 从空库重建；
- RLS/GRANT/View/Function 越权测试；
- Auth User 无 active membership 无业务权限；
- onboarding/disabled 旧 Session 无业务权限；
- Windows/Android provision/onboarding/reset 测试；
- 临时密码不进入 DB/log/audit/GitHub；
- 网络失败输入恢复与幂等；
- 教师交接演练；
- 学生合并/查重治理；
- DB dump + 恢复演练；
- Storage 恢复方案；
- 日志无 Password/Token/Secret/敏感正文；
- 实际机构网络测试；
- 安装/升级路径；
- GitHub Actions 与 Supabase 使用量不会自动产生额外费用；
- 根据部署地区完成未成年人个人信息、机构授权与数据合规评估。