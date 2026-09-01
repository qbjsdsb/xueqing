# 安全、隐私与恢复基线

> V1 最低安全门槛。系统涉及未成年学生信息，任何功能不得以“先跑起来”为理由绕过这些要求。

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

## 2. Email OTP 与机构授权安全边界

V1 首选 Passwordless Email OTP。

关键原则：
- OTP 只证明用户控制某邮箱；
- Auth Session 不等于机构权限；
- 没有 active membership 的 Auth User 不能读取机构业务数据；
- pending invitation 也不能读取机构业务数据；
- invitation 只能由 verified email 匹配的当前用户接受；
- membership disabled 后，旧 Token 仍必须被数据库拒绝。

### OTP 本身
- App 日志不得记录验证码；
- 错误上报不得包含 OTP、Access Token、Refresh Token；
- Production 配置合理 Auth rate limits；
- 根据暴露程度启用 CAPTCHA/等价防滥用；
- OTP 错误/过期/频繁请求只返回必要信息，避免账号枚举提示；
- 未授权 Auth User 只能看到“尚未获得机构授权”，不能搜索机构/教师/学生。

### 邮件基础设施
Production 登录依赖邮件投递，因此：
- 使用可靠 Custom SMTP 或等价邮件服务；
- SMTP Secret 只在受信任服务端配置；
- 不进入 Flutter/GitHub；
- 定期验证主要教师邮箱域的投递和延迟；
- 邮件模板不泄露机构敏感数据。

## 3. Invitation 数据也是个人信息

`organization_invitations` 包含教师邮箱，属于需要保护的身份信息。

要求：
- 普通 authenticated 用户不能枚举 pending invitations；
- 管理员只管理自己机构 invitations；
- 接受 invitation 使用当前 verified email 服务端匹配；
- 不把“某邮箱是否被某机构邀请”作为公开查询接口；
- 取消/接受后的 invitation 保留期限按实际制度确定，不无限保留无业务价值数据。

## 4. 自由文本风险

最容易泄露隐私的地方往往是备注，而不是结构化字段。

因此：
- Observation 强调可观察事实；
- 家校沟通只保存必要摘要；
- 不鼓励长期复制聊天全文；
- 不把人格判断、未经证实的健康/家庭推断写成正式学情；
- UI 提示避免输入无关敏感信息。

## 5. 客户端密钥边界

Flutter 只允许持有 Supabase Publishable Key（或旧项目 anon key）。它是公开客户端凭据，安全依赖 RLS/GRANT，而不是“把 key 藏起来”。

客户端绝不得包含：
- Secret Key
- service_role
- 数据库密码
- SMTP Secret
- AI/第三方私钥

高权限凭据只放受信任服务端环境。

## 6. 数据库访问

所有客户端业务表：
1. 显式 RLS；
2. 最小 GRANT；
3. SELECT / INSERT / UPDATE / DELETE 分别验证；
4. 跨机构默认拒绝；
5. 敏感跨学科默认拒绝；
6. 高频 RLS 字段建立索引。

前端隐藏按钮不是安全控制。

## 7. View 与 Function

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

## 8. 多租户隔离

- 机构数据明确 `organization_id`；
- active membership 是机构访问第一道业务条件；
- teacher 继续检查 student/subject assignment；
- advisor 检查 staff assignment；
- 跨机构请求数据库层拒绝；
- 冗余 organization_id 防止跨机构错配。

Auth User 的存在、JWT 的存在、pending invitation 的存在都不能替代 active membership 检查。

## 9. 高权限与不变量操作

受控操作包括：
- 首位 org_admin bootstrap；
- 创建/取消 invitation；
- accept_invitation；
- 角色提升；
- teacher handoff + disable；
- 学生合并；
- 数据导出/删除；
- 需要 Secret 的第三方集成。

其中不是所有操作都需要 service_role，但都必须在服务端/数据库命令中再次验证 actor、organization、状态与参数。

## 10. 审计

记录关键治理动作：
- actor user/membership；
- organization；
- entity type/id；
- action；
- changed fields；
- operation id；
- occurred_at。

不要把 audit_logs 变成第二份学生敏感正文数据库。

`case_events` 与 `audit_logs` 原则上 append-only。

## 11. 删除、归档与更正

- 教师离职：disable membership，不删除历史；
- 学生退班：归档；
- 普通教师不硬删除核心事实；
- 误录通过更正事件/归档语义处理；
- 学生合并保留 merge mapping；
- 真正个人信息删除/导出走管理员数据治理流程。

不要把日常“删除按钮”直接映射成跨表 cascade delete。

## 12. Storage

附件默认私有 bucket：
- 不公开 bucket；
- 授权访问或短时签名 URL；
- 路径含 organization_id + 不可猜测 UUID；
- 不用真实姓名做公开路径；
- 限制文件类型/大小；
- 后续按需要评估恶意文件扫描。

DB 记录删除与 Storage 对象删除要走受控一致性流程。

## 13. 环境隔离

明确三种环境：
- Local Development：虚构数据；
- Remote Development：虚构数据/真实集成；
- Production：真实机构数据。

Production 与开发环境不共享数据库、Storage、Secret、SMTP、测试账号。

Schema/RLS 等正式变化必须进入 Git migrations。

## 14. 日志与错误上报

不得记录：
- OTP
- Access/Refresh Token
- Secret
- 完整家校沟通
- 完整作文/试卷
- 不必要学生姓名/联系方式

优先记录：错误码、operation id、对象 UUID、App version、调用路径。

## 15. 备份与恢复

### PostgreSQL
- 明确备份能力/保留周期；
- 定期恢复演练。

### Storage
数据库备份不等于附件备份。

需要：
- 对象清单；
- 文件备份；
- 抽样恢复；
- DB path ↔ Storage object 一致性检查。

### Git / Schema
GitHub 保存代码和 migrations，但 migrations 不替代业务数据备份。

## 16. 网络与可用性

真实机构上线前测试：
- Email OTP 投递和验证；
- 常规读写；
- 图片上传；
- Functions；
- 长时间 Session；
- Wi-Fi/移动网络切换；
- 断网/恢复后的草稿。

不能只在开发者自己的网络环境判断可上线。

## 17. 客户端保存状态

高频表单至少有：
- 未保存
- 保存中
- 已保存
- 保存失败/可重试

网络失败不得丢输入；本地 draft 只用于待提交恢复，不是第二套正式数据库。

## 18. 安装包与签名

### Android
- keystore 不进 GitHub；
- 安全备份；
- 不以 Debug 包长期生产分发。

### Windows
- 明确安装/升级渠道；
- 正式部署评估代码签名，降低安装警告和篡改风险。

## 19. 真实数据 Go / No-Go

至少完成：
- 仓库私有/等价源码控制；
- Local / Remote Development / Production 隔离；
- migrations 从空库重建；
- RLS/GRANT/View/Function 越权测试；
- Auth User 无 membership 无业务权限；
- pending invitation 无业务权限；
- Windows/Android OTP 测试；
- Production SMTP/邮件服务、rate limits、防滥用配置；
- 网络失败输入恢复与幂等；
- 教师交接演练；
- 学生合并/查重治理；
- DB 恢复演练；
- Storage 恢复方案；
- 日志无 OTP/Token/Secret/敏感正文；
- 实际机构网络测试；
- 安装/升级路径；
- 根据部署地区完成未成年人个人信息、机构授权与数据合规评估。