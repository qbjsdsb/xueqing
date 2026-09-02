# 安全、隐私与恢复基线

> 系统会处理未成年学生信息。V1 可以零额外付费，但不能用“先跑起来”或“免费”作为降低权限、备份、设备安全和隐私门槛的理由。

## 1. 数据最小化

只收集完成教学闭环真正需要的信息。

### 身份/联系（高敏感）
- 学生姓名；
- 家长姓名/联系方式；
- 教师邮箱/联系方式；
- 学校、班级等组合识别信息。

### 教学/学情（敏感）
- 学情案例；
- 作业、试卷、作文、测验；
- 课堂观察；
- 家校沟通；
- 成长报告。

### 系统元数据
- Auth User ID；
- organization / membership / role / assignment ID；
- operation id、时间戳、App version。

开发、测试、截图、seed 只用明显虚构数据。不因“以后也许有用”收集无关家庭、健康、身份背景等敏感信息。

---

## 2. Auth ≠ 业务授权

普通业务访问至少要求：
- JWT 可识别当前 user；
- JWT `session_id` 对应的 `auth.sessions` 记录仍存在；
- membership = active；
- organization 一致；
- role / assignment 允许该操作。

无 membership、onboarding、disabled、revoked session 都不能读取普通学生业务。

不能只相信 JWT 中可能陈旧的角色/metadata；权限事实源是数据库 membership / roles / assignments。

---

## 3. 为什么检查 live Session

Supabase global sign-out 会撤销 Session/Refresh Token，但已签发的 Access Token 在自身 `exp` 前仍可能存在。JWT 的 `session_id` 可以与 `auth.sessions` 对应；Session 行不存在即表示该 Session 已退出。

V1 对学生敏感数据因此增加 live-session guard。

实现要求：
- 非 exposed helper；
- `security definer` 时固定 `search_path = ''`；
- schema-qualified；
- 最小 execute；
- revoked JWT 的自动化负面测试；
- 用 EXPLAIN/真实负载确认性能，不因性能优化移除安全语义。

---

## 4. 临时凭据与账号接管

### `provision_member`
- 只有有权 org_admin；
- Secret/service_role 仅可信服务端；
- 服务端安全随机生成临时密码；
- membership 初始 onboarding；
- 设置 `onboarding_expires_at`；
- 密码只在成功响应显示一次；
- 不写 DB/audit/log/error tracking/GitHub。

### 临时凭据不是永久密码
- 通过已建立身份关系的可信渠道交付；
- 有短有效期；
- 过期只能 reissue；
- 不开放“找回原临时密码”；
- 响应丢失时生成新凭据，而不是保存旧明文满足幂等。

### `complete_member_onboarding`
安全顺序：
1. 验证当前 user/session + onboarding + 未过期；
2. 更新当前用户自己的密码；
3. global sign-out 所有 Session；
4. 成功后 membership→active；
5. 强制重新登录；
6. live-session guard 拒绝所有被撤销旧 JWT。

任何半失败都优先停在 onboarding。

### `reset_member_credential`
1. 管理员核验本人；
2. **先 membership→onboarding**，切断学生业务；
3. 再生成/更新临时密码；
4. 刷新 onboarding 有效期；
5. 不记录密码；
6. 教师重新完成 onboarding。

---

## 5. 客户端 Session 存储

`supabase_flutter` 默认会把 Session 持久化到 SharedPreferences 系列存储。Production 涉及学生数据时，Phase 0 必须替换为自定义安全 `LocalStorage`：

- Session/Refresh Token 使用 OS 受保护存储；
- Android 使用 Keystore 体系或经过审计的安全封装；
- Windows 使用系统受保护凭据/等价安全封装；
- 可参考 `flutter_secure_storage` 等开源实现，但在正式选型前验证 Windows + Android 当前版本行为；
- Token 不进入普通 Preferences、日志、crash dump；
- **密码不本地持久化**。

库选择在 Phase 0 写 ADR，不能因为“默认能跑”就直接进 Production。

---

## 6. App 启动授权 Gate

`supabase_flutter` v2 初始化可能先读出本地 Session，而不保证它已完成远端刷新或仍有效。

因此启动时：
1. 初始化 Auth；
2. 判断本地 Session 过期/刷新状态；
3. 必要时等待 token refresh / 远端验证；
4. 解析 live Session；
5. 解析 active membership + current organization；
6. **最后**挂载业务 Shell。

禁止出现“旧 Session 先显示一瞬间学生页面，然后才被踢回登录”的隐私闪现。

---

## 7. 本地临时草稿也是敏感数据

网络失败恢复不能变成“把学生正文长期明文留在电脑/手机”。

Phase 0 必须证明：
- 草稿按 `{user_id, organization_id}` 隔离；
- 需要跨重启恢复的正文在本地**加密存储**；
- 加密 key 放 OS 安全存储，不和密文同文件；
- 不存密码、Token、Secret；
- 同步成功后及时删除；
- 有 TTL / 清理策略；
- 切换账号绝不展示上一账号草稿；
- membership disabled / 授权失效后清理或锁定相关草稿；
- 主动 logout 时若有未同步草稿，先清楚提示“同步 / 丢弃”，不能静默跨账号保留。

若加密持久化尚未完成，只允许内存临时输入，不应把敏感正文用普通 Preferences/明文文件实现“伪离线”。

---

## 8. 客户端密钥边界

Flutter 只能包含客户端 Publishable Key。它不是 Secret，安全依赖 RLS/GRANT。

客户端绝不能包含：
- Secret/service_role；
- 数据库密码；
- SMTP/AI/第三方私钥；
- 临时/正式用户密码副本；
- Production backup credential。

Auth Admin 方法只在可信服务端。

---

## 9. 数据库 / RLS / Function

客户端业务表：
1. 显式 RLS；
2. 最小 GRANT；
3. SELECT/INSERT/UPDATE/DELETE 分别验证；
4. active + live session；
5. 跨机构默认拒绝；
6. 敏感跨学科默认拒绝；
7. 高频 policy 字段有合理索引。

### View
优先 `security_invoker = true`；否则非 exposed / 受控函数。单独越权测试。

### Function
默认 `security invoker`。必须 `security definer` 时：
- 非 exposed schema；
- `set search_path = ''`；
- schema-qualified；
- revoke 默认 execute；
- 最小 grant；
- live-session/cross-org 等负面测试。

### Edge Function
- 每次验证调用者；
- 再验证 organization/capability；
- 不信任客户端传来的 user_id/organization_id；
- credential body 不进日志；
- 不把“运行在服务端”当成自动安全。

---

## 10. Storage

附件默认 Private bucket。

要求：
- `storage.objects` policy 与组织/学生/角色边界一致；
- 上传前后都校验当前 active/live member；
- 路径使用 organization/student/UUID，不用姓名；
- 限制大小与允许类型；
- signed URL 短时有效，视为 bearer credential，不写日志/公开聊天；
- 只在当前请求已授权后生成 signed URL；
- 业务代码通过 Storage API，不直接把 Storage 内部表当普通业务表随意写；
- DB metadata 删除与对象删除要有受控流程；
- Free 1GB 不是扫描件仓库，大附件严格节制。

数据库 backup 不包含文件本体。

---

## 11. 自由文本

- 记录可观察教学事实；
- 家校只保存必要摘要；
- 不长期复制完整微信聊天；
- 不把未经证实的家庭/健康推断写成正式标签；
- UI 提示不要输入与教学无关的敏感信息。

---

## 12. 审计与日志

Audit 记录：actor、organization、entity、action、changed fields、operation id、时间。

禁止记录：
- Password/临时密码；
- Access/Refresh Token；
- Authorization header；
- Secret；
- 完整家校正文；
- 完整作文/试卷；
- 无必要姓名/联系方式。

Credential audit 只记“开通/接管/重置发生过”和结果类别，不记秘密。

---

## 13. 删除、归档与人员变化

- 教师离职：交接后 disabled，不删除历史；
- 学生退班：archived；
- 重复学生：merge，保留映射；
- 普通教师不硬删核心事实；
- 真正个人信息导出/删除走管理员治理流程；
- 日常删除按钮不等于 cascade delete。

---

## 14. 环境隔离与 Region

环境：
- Local Development：虚构数据；
- Remote Development：虚构数据 + 公网/双设备验证；
- Production Pilot：真实数据。

Production 不共享 DB/Storage/Secret/测试账号，不跑 development seed/reset。

### Region 是上线前决定，不是随手选

Supabase project 建立后绑定 region，换 region 需要新项目迁移。当前 APAC 可选 Singapore、Tokyo、Seoul 等，但没有中国大陆 region。

因此在创建 Production Pilot 前：
- 用虚构 Remote Development 在**实际机构 Wi‑Fi、普通手机网络、无代理/VPN**环境测试；
- 测 Password Auth、Data API、Storage 上传/下载、Edge Functions、网络切换与恢复；
- 网络不可接受时，先重建 Remote Development 到另一 APAC region 再测；
- 只在测试后创建 Production region；
- 真实未成年人数据的数据驻留/跨境处理必须由机构做单独合规评估；region 选择本身不是合规证明。

---

## 15. GitHub / ChatGPT 云端开发隐私

- 仓库进入真实开发前必须 Private；
- Private 也禁止提交真实学生数据/凭据；
- Work/Codex 只提供完成任务所需最小上下文；
- Issue/PR/seed/screenshot 使用虚构数据；
- GitHub 是代码事实源，聊天不是；
- Agent 没跑命令就必须明确“未执行”。

GitHub Free 私有仓库不能依赖付费级 branch protection/ruleset 来强制流程，因此零成本阶段用：
- AGENTS 硬规则；
- 任务分支 + Draft PR；
- 人工只合并有真实执行证据的 PR；
- Work/Codex 不直接推 main。

以后升级 GitHub 计划再开启平台强制保护。

---

## 16. 备份与恢复

Free Tier 不含付费级自动日备份保障。

数据库最小逻辑备份集：
- `roles.sql`
- `schema.sql`
- `data.sql`
- 必要时单独保存 `supabase_migrations` 历史

备份必须：
- 加密离站；
- 保留多个时间点；
- 不提交 GitHub；
- 记录 App/schema 版本；
- 实际恢复到非 Production 环境。

Storage：单独备份文件、bucket/object manifest，并抽样恢复。

Edge Functions 代码在 Git，但 Auth 设置、API Keys、Realtime/扩展、Secrets 等还需要独立“可重建配置清单”。

恢复“有文件”不算完成，**恢复演练成功**才是证据。

详细见 `DISASTER_RECOVERY.md`。

---

## 17. 零成本与计费安全

本阶段不新增：SMTP/域名/SMS、Supabase Pro/add-on、AI API、商业监控、larger runner、Work/Codex extra credits。

GitHub Actions private Free 有免费分钟，但超出额度可能计费；必须设置 budget 并启用 **Stop usage when budget limit is reached**，同时避免每个 commit 跑 Windows/Android 重构建。

Supabase Free 接近容量/业务可靠性边界时先评审，不自动升级。

---

## 18. 安装与设备

### Android
- keystore 不进 GitHub；
- 独立安全备份；
- 不长期分发 Debug build。

### Windows
- Pilot 可走受控内部发行，不把付费代码签名证书作为 V1 硬依赖；
- 仍要明确版本、哈希/来源、升级路径；
- 未来广泛分发时再评估公信代码签名。

---

## 19. 管理员 Break-glass

无 SMTP 的 Password 模式不能让唯一管理员忘记密码后全机构锁死。

真实 Pilot 前至少：
- 两名独立可信 org_admin；或
- 已演练的 Supabase Project Owner break-glass 恢复步骤。

break-glass 使用后要复核角色、撤销临时凭据并留治理记录。

---

## 20. 真实数据 Go / No-Go

以下关键项必须全部通过：
- [ ] GitHub 已 Private
- [ ] Local / Remote Development / Production 隔离
- [ ] Production region 已通过无代理真实机构网络测试
- [ ] migrations 从空库重建
- [ ] live-session + active membership RLS 负面测试
- [ ] global sign-out 后旧 JWT 立即无法业务访问
- [ ] onboarding expiry / reissue / 响应丢失路径验证
- [ ] Session 使用安全本地存储
- [ ] App 启动不会闪现失效 Session 的业务数据
- [ ] 本地敏感 draft 加密、分用户/机构、TTL/清理验证
- [ ] 网络失败草稿恢复与幂等
- [ ] Storage policy / signed URL 边界测试
- [ ] 教师交接、学生合并治理验证
- [ ] DB roles/schema/data dump + 实际恢复演练
- [ ] Storage 独立备份/恢复抽测
- [ ] 两个管理员或 break-glass 已验证
- [ ] 日志无 Password/Token/Secret/敏感正文
- [ ] 安装/升级路径明确
- [ ] GitHub Actions budget 不会自动超额付费
- [ ] Supabase Free 使用量适合 Pilot
- [ ] 部署地区的未成年人信息、数据驻留/跨境等合规评估完成

任一关键项未满足，只使用虚构/脱敏数据。
