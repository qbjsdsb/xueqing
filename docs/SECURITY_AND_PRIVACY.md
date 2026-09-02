# 安全、隐私与恢复基线

> 系统会处理未成年学生信息。V1 可以零额外付费，但不能用“先跑起来”或“免费”作为降低权限、备份、设备安全和隐私门槛的理由。

> **Phase 0B.0 provider / production hard boundary**
>
> 当前仅将 Supabase 视为 V1 reference / preferred implementation candidate；尚未无条件冻结为 production provider。正式 production business migrations、Production Auth/RLS/CRUD 与真实学生/教师/家长数据之前，必须先完成并通过：
> 1. **P0 Gate A — Auth Identity Portability Spike**；
> 2. **P0 Gate B — Revoked Session / Old Token Security Spike**。
>
> 在两项 Gate 之前，只允许用虚构数据进行 provider-specific compatibility/security spike；Spike 不构成 production migration 授权。两 Gate 通过后，才可冻结 provider、region、identity 与 session strategy，再另行执行正式 migrations、Auth/RLS/CRUD 与 Go/No-Go。

## 1. 数据最小化

只收集完成教学闭环真正需要的信息。

### 身份 / 联系（高敏感）
- 学生姓名；
- 家长姓名 / 联系方式；
- 教师邮箱 / 联系方式；
- 学校、班级等可组合识别信息。

### 教学 / 学情（敏感）
- 学情案例；
- 作业、试卷、作文、测验；
- 课堂观察；
- 家校沟通；
- 成长报告。

### 系统元数据
- Auth User ID；
- organization / membership / role / assignment ID；
- operation id、时间戳、App version。

开发、测试、截图、seed 只用明显虚构数据。不要因为“以后也许有用”收集与教学目的无关的家庭、健康、身份背景等敏感信息。

---

## 2. Auth 不等于业务授权

普通学生业务至少要求：

```text
有效 JWT user
+ JWT session_id 对应 live auth.sessions
+ membership = active
+ organization 一致
+ role / capability
+ student / subject assignment（如该操作需要）
```

无 membership、onboarding、disabled、revoked Session 均不能读取普通学生业务。

不能把可能陈旧或可由用户修改的 metadata 当正式权限事实源；正式授权以 membership / roles / assignments 为准。

---

## 3. Live Session 为什么是安全边界

若以 Supabase 作为 V1 reference candidate，global sign-out 对 Session / Refresh Token 与既有 Access Token 的行为、JWT `session_id` ↔ `auth.sessions` live-session guard 必须在 P0 Gate B 中用虚构数据实测；在 Spike 通过前不把该 provider-specific 方案写成 Production 已验证事实。

实现要求：
- helper 不放 exposed schema；
- 必须 `security definer` 时固定 `search_path = ''`；
- schema-qualified；
- revoke 默认 execute，再最小 grant；
- revoked JWT 自动化负面测试；
- 用 EXPLAIN / 实际查询观察性能；
- 不为了性能优化静默删除 live-session 安全语义。

### 性能要求

安全检查不能粗暴写成业务结果每行重复昂贵查询。Phase 0 必须验证 planner 行为、索引和 Today / Student / Case 核心查询开销。

---

## 4. 临时凭据与账号接管

### `provision_member`
- 只有有权 org_admin；
- Auth Admin / service_role 只存在可信服务端；
- 服务端使用安全随机源生成临时密码；
- membership 初始为 onboarding；
- 设置 `onboarding_expires_at`；
- 密码只在成功响应显示一次；
- 不写 DB / audit / log / error tracking / GitHub。

### 临时密码不是一次性 Token

谁先拿到临时密码，谁就可能尝试登录，所以必须同时满足：
- 可信渠道交付；
- 短有效期；
- onboarding 无普通业务权限；
- 过期只能 reissue；
- 不提供“找回原临时密码”。

### 响应丢失

若后台已成功但管理员没收到响应：
- 不为了幂等保存明文密码；
- member 保持 onboarding；
- 管理员 reissue 新临时密码；
- 旧临时密码随 Auth 密码更新失效。

### `complete_member_onboarding`

安全顺序：
1. 验证当前 user / session；
2. membership = onboarding；
3. `onboarding_expires_at` 未过期；
4. 更新当前用户新密码；
5. global sign-out 所有 Sessions；
6. sign-out 成功后 membership → active；
7. 强制重新登录；
8. live-session guard 拒绝所有被撤销旧 JWT。

任何半失败都优先停留在 onboarding，而不是提前 active。

### `reset_member_credential`

1. 管理员按机构流程确认本人；
2. **先 membership → onboarding**，立即切断学生业务；
3. 再生成并更新新的临时密码；
4. 刷新 onboarding expiry；
5. audit 不记录密码；
6. 教师重新完成完整 onboarding。

---

## 5. V1 跨机构账号限制

数据库可以有多个 organization，但 V1 同一个 Auth User 同一时点最多一个 onboarding / active membership。

在 Supabase reference candidate 路径中，Password 属于全局 Supabase Auth User，而 V1 org_admin 可以执行 credential reset；如果一个用户同时属于 A、B 两个机构，A 管理员重置全局密码会影响 B，这是需要由 P0 Gate A 与后续身份治理方案解决的风险。

因此：
- 其他机构只允许 disabled 历史；
- `provision_member` 遇到另一机构非 disabled membership 时拒绝；
- V1 不做跨机构账号切换器；
- 未来需要跨机构同账号时，先升级到中央身份恢复 / Email OTP / SSO 等方案并新增 ADR。

---

## 6. 客户端 Session 存储

未来 gated Production 涉及学生数据时，不能直接把候选 provider 的默认 `supabase_flutter` SharedPreferences 系列持久化当最终安全方案；provider/identity/session strategy 仍须先过 P0 Gate A/B。

Phase 0 必须实现：
- Supabase custom `LocalStorage`；
- Session / Refresh Token 使用 OS 受保护存储；
- Android 使用 Keystore 体系或经过审计的安全封装；
- Windows 使用系统受保护凭据 / 等价安全封装；
- 可参考 `flutter_secure_storage` 等开源实现，但必须验证当前 Windows + Android 行为；
- Token 不进入普通 Preferences、日志或 crash payload；
- **Password 永不本地持久化**。

具体开源库在 Phase 0 选型并记录 ADR。

---

## 7. App Startup Authorization Gate

本地 Session 被读出来，不等于它仍然有效。

启动顺序：
1. 初始化 Auth；
2. 判断本地 Session 是否过期 / 需要 refresh；
3. 必要时等待远端 Auth 状态；
4. 解析 live Session；
5. 解析 membership 状态；
6. 解析 current organization；
7. **最后**挂载业务 Shell。

分支：
- revoked / expired → 登录页；
- onboarding → 账号接管页；
- disabled / no membership → 无权限页；
- active → 业务页。

禁止“先闪现学生页面，再发现 Session 无效”。

---

## 8. 本地草稿也是敏感数据

网络失败恢复不能变成“把学生正文长期明文留在电脑 / 手机”。

需要跨重启恢复的草稿：
- `{user_id, organization_id}` scope；
- encrypted at rest；
- key 在 OS secure storage，不和密文同文件；
- 不保存 Password / Token / Secret；
- TTL；
- sync 成功及时删除；
- account switch 不串数据；
- logout 时如有未同步草稿，明确提示同步 / 丢弃；
- membership disabled / revoked 后清理或锁定。

在加密持久化完成前，只允许内存临时输入，不用普通 Preferences / 明文文件实现“伪离线”。

---

## 9. 客户端密钥边界

Flutter 只允许客户端 Publishable Key。它不是 Secret，安全来自 RLS / GRANT。

客户端绝不能包含：
- Secret / service_role；
- 数据库密码；
- SMTP / AI / 第三方私钥；
- 临时 / 正式用户密码副本；
- Production backup credential。

Auth Admin 只在可信服务端。

---

## 10. Database / RLS / View / Function

客户端业务表必须：
1. 显式 RLS；
2. 最小 GRANT；
3. SELECT / INSERT / UPDATE / DELETE 分别验证；
4. live Session + active membership；
5. 跨机构默认拒绝；
6. 敏感跨学科默认拒绝；
7. 高频 policy 字段有合理索引。

### View

客户端暴露 View 优先 `security_invoker = true`；否则放非 exposed schema / 受控 Function，并单独做越权测试。

### Function

默认 `security invoker`。

必须使用 `security definer` 时：
- 非 exposed schema；
- `set search_path = ''`；
- schema-qualified；
- revoke 默认 execute；
- 最小 grant；
- live-session / no-membership / onboarding / disabled / cross-org / cross-subject 负面测试。

### Edge Function
- 每次验证调用者 Session；
- 再验证 organization / capability；
- 不信任客户端传来的 user_id / organization_id；
- credential body 不进日志；
- 运行在服务端不等于自动安全。

---

## 11. 机构时区与时间安全

系统事件使用 UTC / `timestamptz`；机构业务日期使用 `organizations.time_zone`（IANA timezone）解释。

以下不能直接依赖设备时区：
- Today；
- action due / overdue；
- lesson 所属业务日期；
- 周度 / 阶段统计；
- report period。

Phase 0 / Milestone 1 要测试：
- 跨午夜；
- 设备时区错误；
- IANA timezone 转换；
- DST 行为（适用机构 / region 时）。

---

## 12. Storage

附件默认 Private bucket。

要求：
- `storage.objects` policy 与 organization / student / assignment 边界一致；
- 上传和下载都检查 active / live member；
- 路径使用 organization / student / UUID，不使用姓名；
- 限制大小和允许类型；
- signed URL 短时有效，只在当前请求授权后生成；
- signed URL 视为 bearer credential，不写日志、聊天或长期缓存；
- 业务代码通过 Storage API，不把 Storage 内部表当普通业务表随意写；
- DB metadata 删除与 object 删除有受控一致性流程；
- Free Storage 不是原始扫描件长期仓库。

数据库 backup 不包含 Storage 文件本体。

---

## 13. Realtime

V1 学生敏感业务表默认不启用 Realtime，也不让业务正确性依赖 Realtime。

正确性必须通过：
- 页面进入刷新；
- 保存后刷新；
- App resume；
- 手动刷新。

未来开启 Realtime 前必须新增 ADR，并验证 revoked Session、token refresh、reconnect、cross-org、subscription cleanup。

---

## 14. 自由文本

- 记录必要、可观察教学事实；
- 家校只保存必要摘要；
- 不长期复制完整微信聊天；
- 不把未经证实的家庭 / 健康推断写成正式标签；
- UI 明确提示不要输入与教学目的无关的敏感信息。

---

## 15. 审计与日志

Audit 记录：actor、organization、entity、action、changed fields、operation id、时间。

禁止记录：
- Password / 临时密码；
- Access / Refresh Token；
- Authorization header；
- Secret；
- 完整家校正文；
- 完整作文 / 试卷；
- 无必要姓名 / 联系方式。

Credential audit 只记录“开通 / 接管 / 重置发生过”和结果类别，不记录秘密。

---

## 16. 删除、归档与人员变化

- 教师离职：先交接，最后 membership → disabled；
- 历史作者 / 教师关系不删除；
- 学生退班：archived；
- 重复学生：merge，保留 source → target mapping；
- 普通教师不硬删核心事实；
- 真正个人信息导出 / 删除走管理员治理流程；
- 日常删除按钮不直接映射跨表 cascade delete。

普通流程不能停用最后一个可恢复 org_admin。

---

## 17. 环境隔离与 Region


> **Phase 0B.0 provider / production hard boundary**
>
> 当前仅将 Supabase 视为 V1 reference / preferred implementation candidate；尚未无条件冻结为 production provider。正式 production business migrations、Production Auth/RLS/CRUD 与真实学生/教师/家长数据之前，必须先完成并通过：
> 1. **P0 Gate A — Auth Identity Portability Spike**；
> 2. **P0 Gate B — Revoked Session / Old Token Security Spike**。
>
> 在两项 Gate 之前，只允许用虚构数据进行 provider-specific compatibility/security spike；Spike 不构成 production migration 授权。两 Gate 通过后，才可冻结 provider、region、identity 与 session strategy，再另行执行正式 migrations、Auth/RLS/CRUD 与 Go/No-Go。

环境：
- Local Development：虚构数据；
- Remote Development：虚构数据 + 公网 / 双设备验证；
- Gated Production Pilot：仅在 P0 Gate A/B、provider/region/identity/session strategy 与 Go/No-Go 全部通过后才可使用真实数据。

Gated Production 不共享 Development 的 DB / Storage / Secret / 测试账号，不运行 development seed / reset；Phase 0A.6 当前没有 Production 环境。

### Region 是上线决策，不是随手选择

未来 gated Production Project 创建前，且仅在 P0 Gate A/B 通过后，用 Remote Development 虚构数据在实际机构场景测试：
- 机构 Wi-Fi；
- 普通移动网络；
- **无代理 / VPN**；
- Password Auth；
- Data API；
- Storage；
- Edge Functions；
- 网络切换与恢复。

网络不可接受时，先重建 Remote Development 到其他 APAC region 再测。真实未成年人数据的数据驻留 / 跨境问题由机构单独评估；region 不是合规证明。

---

## 18. GitHub / ChatGPT 云端开发隐私

当前仓库已经是 **Private**。

但 Private 不改变以下规则：
- 不提交真实学生 / 家长 / 教师敏感数据；
- 不提交 Password / Token / Secret / Production backup；
- Issue / PR / seed / screenshot 只用虚构数据；
- Work / Codex 只提供完成开发所需的最小上下文；
- GitHub 是代码事实源，聊天不是；
- Agent 没跑命令必须明确“未执行”。

零成本阶段：
- Work / Codex 禁止直推 main；
- feature / review branch + Draft PR；
- 人工只合并有真实执行证据的 PR；
- 以后升级 GitHub 计划再考虑更强平台保护。

---

## 19. 备份与恢复

Free Pilot 不具备商业级自动恢复承诺，必须自己建立恢复能力。

### Database
最小逻辑备份集：
- `roles.sql`
- `schema.sql`
- `data.sql`
- 必要时 `supabase_migrations` history

### Auth
若最终选定 Supabase，恢复项目必须按**恢复当日 Supabase 官方流程**处理 Auth user / identity 数据，并真实验证；这属于 P0 Gate A/B 之后的 gated Production restore drill：
- org_admin 登录；
- 普通 teacher 登录；
- membership / RLS 正确。

新 Project 的 JWT / API 配置可能变化。旧 Token 不应被假定继续有效；恢复后要求用户重新登录是合理且安全的默认。

### Storage
数据库备份不包含文件本体。

必须：
- Storage objects 单独备份；
- manifest；
- size / checksum；
- DB path ↔ object 一致性检查；
- 抽样恢复。

### Project Configuration
仓库保存重建说明，不保存 Secret 值。至少列：
- Auth settings；
- Realtime；
- Extensions；
- Edge Functions；
- Secret names；
- Storage buckets / policies；
- client URL / Publishable Key 更新流程。

### 备份原则
- 加密离站；
- 多时间点；
- 不提交 GitHub；
- 记录 app / schema / migration version；
- 真正 restore 到非 Production 新环境并 smoke test。

恢复“有文件”不算完成，**restore drill PASS 才是证据**。

Pilot 默认目标 RPO ≤ 一个教学日；如果机构无法接受，免费方案不能进入真实生产依赖。

详见 `DISASTER_RECOVERY.md`。

---

## 20. 零成本与计费安全

本阶段默认不新增：
- SMTP / 域名 / SMS；
- Supabase Pro / add-on / PITR；
- AI API；
- 商业监控 / 分析；
- larger runner；
- Work / Codex extra credits；
- Windows 付费公信代码签名作为 Pilot 硬依赖。

GitHub Actions 有有限免费额度。用户已明确选择暂不设置 zero-overage budget，并接受账户级计费风险；这不再是安全 Go / No-Go 的阻塞项，详见 ADR-044。因为没有 budget stop，工程侧必须更克制：普通 PR 只跑轻量 Linux 检查，Windows / Android 原生构建只在 milestone / release / 手动执行，不重复触发、不用 larger runner，并关注异常 Actions 消耗。

Supabase Free 接近容量或可靠性边界时先重新评审，不自动升级收费。

---

## 21. 安装与设备

### Android
- keystore 不进 GitHub；
- 独立安全备份；
- 不长期分发 Debug build。

### Windows
- Pilot 可以受控内部发行；
- 不把付费公信代码签名证书作为 V1 硬依赖；
- 仍要明确版本、来源 / hash、升级路径；
- 广泛外部分发时再评估公信代码签名。

---

## 22. 管理员 Break-glass

无 SMTP 自助恢复时，唯一管理员是单点故障。

真实 Pilot 前至少：
- 两名独立可信 active org_admin；或
- 已演练的 Supabase Project Owner break-glass。

break-glass 使用后要复核角色、撤销临时凭据并留下治理记录。

---

# 23. 真实数据 Go / No-Go

## 已完成

- [x] GitHub repository 已 Private
- [x] Wiki 已关闭
- [x] Template repository 已关闭
- [x] Foundation 禁止真实学生数据和 Secret 进入 GitHub 的规则明确
- [x] Actions zero-overage budget 已做明确决策：用户选择暂不设置，风险已记录并由 CI 触发策略缓解

## 真实数据前必须完成

- P0 Gate A：Auth Identity Portability Spike
- P0 Gate B：Revoked Session / Old Token Security Spike
- provider/region/identity/session strategy 冻结并经 Go/No-Go 批准


- [ ] Local / Remote Development / Production 隔离
- [ ] `organizations.time_zone` migration + 边界测试
- [ ] Production region 经无代理真实机构网络验证
- [ ] migrations 从空库重建
- [ ] live-session + active membership RLS 负面测试
- [ ] live-session guard 核心查询性能可接受
- [ ] global sign-out 后旧 JWT 立即无法业务访问
- [ ] onboarding expiry / reissue / 响应丢失路径验证
- [ ] V1 单 Auth User 跨机构 active/onboarding 被数据库和服务端拒绝
- [ ] Session 使用 OS 安全存储
- [ ] Startup Gate 不闪现失效 Session 的学生数据
- [ ] 本地敏感 draft 加密、user/org 隔离、TTL / 清理验证
- [ ] 网络失败草稿恢复与幂等
- [ ] Storage policy / signed URL / cross-org 下载边界测试
- [ ] 教师交接、学生合并治理验证
- [ ] 两个 org_admin 或 break-glass 已演练
- [ ] DB roles / schema / data backup + 真恢复
- [ ] Auth 用户恢复 + 实际登录验证
- [ ] Storage 独立备份 / 恢复抽测
- [ ] Project config / Secret names 重建清单
- [ ] 日志无 Password / Token / Secret / 敏感正文
- [ ] 安装 / 升级路径明确
- [ ] Supabase Free 使用量、pause 风险和 RPO 可接受
- [ ] 部署地区未成年人信息、数据驻留 / 跨境等合规评估完成

任一关键项未满足，只使用虚构或严格脱敏数据。
