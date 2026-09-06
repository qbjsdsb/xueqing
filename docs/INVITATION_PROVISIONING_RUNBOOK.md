# 成员账号开通与接管运行手册

> 这是 Phase 0B.0 的虚构开发环境运行手册。PR、CI、远端 migration 和真实设备验收全部通过前，不得录入真实学生、家长或教师隐私资料。

## 先确认仓库和密钥边界

当前代码仓库是公开可见状态。正式操作前应在 GitHub 的 `Settings → Danger Zone → Change repository visibility` 改回 `Private`，并确认没有把 Supabase service key、临时密码、Access Token 或真实数据提交到 Git 历史。

Auth Admin 的 `service_role` / secret key 只能配置在 Supabase Edge Function 的服务端环境变量中。Flutter 客户端只使用 publishable/anon key；任何客户端、日志、审计记录、migration 和 GitHub 内容都不能保存临时密码。

## 首次部署顺序（只对虚构开发项目）

1. 合并成员开通 PR，并等待 Flutter 与 Supabase CI 通过。
2. 在 Supabase 项目设置中关闭公开自注册；客户端账号只能由受控的成员开通流程创建。远端项目设置不会因为本地 `supabase/config.toml` 自动改变，需要在项目设置中单独核对。
3. 先在开发项目应用数据库 migration，再部署 `organization-member-credentials` Edge Function。
4. 给 Edge Function 配置 Supabase URL、publishable key 和 service key。service key 只通过 Supabase Secrets/环境变量配置，不要写入命令历史、聊天或代码。
5. 用虚构的负责人、管理员和老师账号完成下面的验收清单；通过前不发布安装包，也不切换生产项目。

## 管理员开通成员

在工作台进入「机构管理 → 邀请成员」：

- 新邮箱没有 Auth 账号：系统创建 Auth User，建立 `onboarding` membership，临时密码只在成功响应中显示一次。管理员应通过可信渠道交付邮箱、临时密码和有效期。
- 邮箱已有 Auth 账号：系统不触碰原密码，只返回一次性邀请代码；受邀人必须用完全匹配的邮箱登录后接受代码。
- 管理员不能直接把 `onboarding` 成员改成 `active`；受邀人必须先完成首次接管。
- 负责人角色由管理员提名后，必须由现有负责人审批，审批后才能开通。

## 受邀人首次接管

1. 用管理员交付的临时密码登录。
2. 系统只显示「首次接管账号」页面，不挂载学生业务工作台。
3. 设置符合要求的新密码。
4. 系统退出临时会话，使用新密码重新登录并完成接管。
5. 成功后 membership 才变为 `active`，再进入学生业务。

临时密码丢失或响应没有交付成功时，不能找回旧明文。管理员在成员列表点击「重新发放临时密码」，旧密码立即失效，成员仍保持 `onboarding`。

## 最小验收清单

- [ ] 新邮箱能被开通，临时密码只显示一次，数据库和日志中没有明文密码。
- [ ] 临时密码登录后不能读取学生业务，只能看到首次接管页面。
- [ ] 新密码更新后必须重新登录；完成接管后才进入工作台。
- [ ] 保存接管前旧 Access Token，接管后调用学生业务 API 必须被 live-session guard 拒绝。
- [ ] 重复开通同一邮箱、跨机构 active/onboarding、停用成员绕过接管均被拒绝。
- [ ] 响应丢失后重新发放新密码，旧密码不能登录，新密码可以接管。
- [ ] 已有 Auth 用户走邀请代码，原密码未被修改。
- [ ] 负责人提名在审批前不能开通；撤销、过期邀请不能接受。
- [ ] 全局退出、应用重启、网络失败和账号切换后，不闪现学生页面或其他账号数据。
- [ ] Android 与 Windows 各完成一次真实点击验收；仍只使用虚构数据。

## 出现异常时

- 账号创建成功但业务 membership 失败：不要继续重复创建同邮箱，先检查 Edge Function 的清理结果；必要时由维护人员清理带有 `xueqing_provisioning` 标记的孤立 Auth User。
- 管理员没有收到临时密码：不要查数据库或日志找密码，直接重新发放。
- 接管失败：成员应保持 `onboarding`；先检查有效期、密码更新时间和重新登录，再尝试重新发放。
- CI 或本地 migration 失败：停止远端部署，修复 migration/test 后重新从空库重建验证。

任何真实生产迁移、真实账号创建、签名发布或生产数据导入，都必须在本手册验收完成并单独获得放行后进行。
