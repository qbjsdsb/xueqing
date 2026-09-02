# 风险清单与运行要求

> 只记录“不提前验证就很可能返工、越权、丢数据或无法运营”的风险。每项都应有退出条件，不把风险清单写成泛泛提醒。

## R1｜GitHub 仍为 Public
**等级：最高｜立即**

当前 `qbjsdsb/xueqing` 仍是 Public。正式开发/真实机构数据前必须 Private。

处理：
- Private；
- Secret 仍永不提交；
- Issue/PR/截图/seed 只用虚构数据。

退出：Private + 基础 secret scan。

---

## R2｜GitHub Free 私有仓库无法强制 branch protection
**等级：中高｜开发治理**

GitHub Free 的 private repo 不具备 Pro/Team 才有的私有仓库 ruleset/branch protection 强制能力。

零成本处理：
- Work/Codex 不直推 main；
- feature/review branch + Draft PR；
- PR 必须写真实执行证据；
- 只人工合并；
- 以后升级 GitHub 计划再开启平台强制保护。

退出：流程已写入 AGENTS/开发工作流且实际遵守。

---

## R3｜临时凭据泄露/长期有效
**等级：最高｜Phase 0**

临时密码不是一次性 Token，谁先拿到就可能尝试接管。

处理：
- 强随机；
- onboarding 无学生业务权限；
- `onboarding_expires_at`；
- 可信渠道一次性交付；
- 不写 DB/log/audit/GitHub；
- 过期/交付未知一律 reissue 新密码。

退出：泄露/过期/重签发测试通过。

---

## R4｜接管后旧 Session 重新获得 active 权限
**等级：最高｜Phase 0**

只“改密码 → active”存在窗口：此前偷到临时密码的人可能已经建立 Session；被撤销 Access Token 在 `exp` 前仍可能存在。

处理：
- complete onboarding：改密码 → global sign-out → active → 强制重新登录；
- RLS 检查 JWT `session_id` 对应 `auth.sessions` 仍存在；
- membership 同时必须 active。

退出：保存一个旧 JWT，完成接管后用它直接请求 Data API，必须立即被拒绝。

---

## R5｜管理员 reset 顺序错误
**等级：最高｜Phase 0**

如果先改 Auth 密码、最后才把 member 降为 onboarding，跨系统失败可能让凭据状态不确定但业务仍 active。

处理：**先 membership→onboarding，再更新 Auth 密码**；任何失败优先无业务权限。

退出：故障注入覆盖每一步。

---

## R6｜Credential 响应丢失导致系统想保存明文密码
**等级：高｜Phase 0**

provision/reset 可能成功但响应丢失。不能为了幂等把临时密码长期保存。

处理：
- member 保持 onboarding；
- 标记 credential delivery unknown；
- 管理员 reissue 新凭据；
- 旧密码失效；
- operation receipt 不保存秘密。

退出：模拟“服务端成功、客户端超时”，能够恢复且无明文秘密存储。

---

## R7｜唯一管理员锁死全机构
**等级：高｜真实 Pilot 前**

无 SMTP 自助找回时，唯一 org_admin 忘记密码会成为单点故障。

处理：
- 两个独立可信 active org_admin；或
- 已演练的 Supabase Project Owner break-glass。

退出：第二管理员/恢复演练完成。

---

## R8｜本地 Session 存储不安全
**等级：最高｜Phase 0**

`supabase_flutter` 默认持久化 Session 到 SharedPreferences 系列存储，不应直接作为学生敏感数据 Production 基线。

处理：
- 自定义 Supabase `LocalStorage`；
- OS 安全存储；
- Windows/Android 真测；
- 密码永不本地保存。

退出：Token 安全存储实现和测试通过。

---

## R9｜App 启动闪现旧权限数据
**等级：高｜Phase 0**

Supabase Flutter v2 初始化可能先提供本地 Session，但不保证它仍有效。

处理：
- 启动授权 Gate；
- Auth refresh/live Session/membership 解析完成前不挂业务 Shell。

退出：expired/revoked/disabled 本地 Session 均不会闪现学生页。

---

## R10｜本地草稿成为明文学生数据库
**等级：最高｜Phase 0**

为了断网恢复而长期明文保存作文/学情同样是隐私风险。

处理：
- 加密持久化；
- key 在 OS 安全存储；
- user/org scope；
- TTL；
- sync 后删除；
- logout/account switch/disabled 清理策略；
- 不存 Token/Password。

退出：设备文件检查 + 账号切换 + TTL 测试通过。

---

## R11｜老师不愿意填
**等级：最高｜持续**

处理：
- `new` 10–20 秒；
- 常规课后 ≤60 秒；
- 只填新事实；
- 周度/阶段派生；
- 实际教师可用性测试。

退出不是“页面完成”，而是连续一周流程耗时达标。

---

## R12｜暂停 Case 永久失踪
**等级：高｜业务正确性**

仅 `pause_reason`、没有下一动作，会让问题从 Today 消失。

处理：
- confirmed/intervening/pending_verification/stable 必须有 pending primary action；
- 暂缓用 `review` action + `due_at`；
- pause_reason 只解释原因。

退出：所有正式未关闭 case 都可在行动系统中被再次找到。

---

## R13｜数据越用越脏
**等级：高**

处理：轻量 taxonomy + 自由标题；默认分类；重复 case 提示；历史分类停用不硬删。

---

## R14｜UI 权限正确、数据库实际越权
**等级：最高**

处理：
- RLS + 最小 GRANT；
- live session + active membership；
- assignment authorization；
- `security_invoker` View；
- security-definer 最小授权；
- 攻击式负面测试。

退出：unauth/no-member/revoked/onboarding/disabled/cross-org/cross-student/cross-subject 全失败。

---

## R15｜Storage 成为绕过 RLS 的旁路
**等级：最高｜真实文件前**

处理：
- private bucket；
- `storage.objects` policy 与组织/关系一致；
- signed URL 短时且只在授权后生成；
- 不记录 signed URL；
- 文件类型/大小限制；
- DB 与对象一致性治理。

退出：越权下载/签名 URL/跨机构测试通过。

---

## R16｜网络失败丢记录或重复写
**等级：高**

处理：加密草稿、保存状态、client UUID、operation id、最终状态查询、无假成功 UI。

---

## R17｜多人更新静默覆盖
**等级：中高**

处理：version/expected_version；append-only facts；冲突提示；不 last-write-wins。

---

## R18｜项目长成 ERP/CRM
**等级：高**

处理：lesson 只是教学会话；Today 由 case_actions 驱动；收费/课消/招生/完整排课先产品评审，优先外部集成。

---

## R19｜中国大陆实际网络与 Region 不匹配
**等级：最高｜Production Project 创建前**

Supabase 当前 APAC 有 Singapore/Tokyo/Seoul 等，没有中国大陆 region；项目不能原地换 region。

处理：
- Remote Development 只用虚构数据；
- 在实际机构 Wi‑Fi + 普通移动网络 + **无代理/VPN**测试 Auth/Data API/Storage/Functions；
- 不行就重建 Dev 到另一 APAC region 重测；
- 测完再创建 Production；
- 未成年人数据驻留/跨境处理单独做机构合规评估。

退出：选定 region 有真实网络测试记录 + 合规决策记录。

---

## R20｜Local / Remote Dev / Production 混用
**等级：最高**

处理：独立项目/Secret/Storage/账号；Production 禁 seed/reset；Git migrations 是结构事实源；环境视觉标识明显。

---

## R21｜Free Production 没有自动日备份保障
**等级：最高｜真实数据前**

处理：
- roles/schema/data 逻辑 dump；
- 多时间点、加密离站；
- migration history/配置清单；
- 实际恢复演练；
- 目标 Pilot RPO 默认不超过一个教学日，若机构无法接受则免费方案不合格。

退出：从实际备份恢复到新测试项目并完成 smoke test。

---

## R22｜只备份 DB，Storage/配置没恢复
**等级：最高**

处理：
- Storage 对象 + manifest 单独备份；
- Edge Functions 代码在 Git；
- Auth/Realtime/Extensions/Secrets/Project config 有重建清单；
- 恢复后做 DB path↔object 一致性检查。

---

## R23｜Free Project inactivity / quota
**等级：中高**

处理：记录当前额度；长假前备份；知道恢复 paused project；接近 DB/Storage/Egress 上限先评审，不自动付费。

---

## R24｜GitHub Actions 超额扣费
**等级：中高**

Private Free 有免费分钟，但超额可计费。

处理：
- budget 设置 `Stop usage when budget limit is reached`；
- PR 默认 Linux format/analyze/unit/DB tests；
- Windows/Android release build 仅 Milestone/Release/手动；
- 不用 larger runner；
- artifact retention 短。

---

## R25｜Flutter/Supabase 依赖升级不可复现
**等级：中**

处理：锁 stable SDK、提交 `pubspec.lock`、CI 固定 SDK、依赖升级独立 PR、Production 前先 Dev 验证。

---

## R26｜客户端版本与 DB schema 失配
**等级：中高**

处理：版本号、兼容窗口、expand→migrate→contract、最低支持版本策略、release smoke test。

---

## R27｜自由文本过度收集敏感信息
**等级：高**

处理：记录可观察事实；备注最小化；日志/AI 最小化；数据更正/导出/删除治理。

---

## R28｜AI 让文本漂亮但事实变差
**等级：V2 中高**

处理：AI 只 draft；保留来源；人工确认；不写正式 status；不把总结当 evidence；不越权跨学科。

---

## R29｜Work 长会话上下文漂移
**等级：高｜开发**

处理：GitHub 是事实源；任务先读 AGENTS + 当前 docs；一个可验收目标一条 Work 会话/PR；方向变化写 ADR。

---

## R30｜Agent 声称“测试过”但没有执行
**等级：最高｜开发**

处理：真实命令/CI 输出才叫执行证据；无法执行必须标“未验证”；PR 不因模型口头判断视为 green。

---

## R31｜Max 推理预算被机械任务耗尽
**等级：中**

处理：Luna Max 优先 RLS/migration/事务/并发/安全/终审；格式/改名/重复 CRUD 用较轻档；包含额度用完就等待重置。

---

## R32｜隐藏付费 SaaS 破坏 0 元目标
**等级：高**

任何新 SaaS 前回答：
1. V1 不用是否做不成？
2. Free 是否够？
3. 超额会不会扣费？
4. 能否迁出？
5. 是否接触学生数据？

未经 ADR 不新增付费硬依赖。

---

## R33｜照搬开源项目/许可证风险
**等级：中高**

借模式和经验，不复制大段未知许可证代码；优先官方；不 fork 大型教育 ERP；参考来源记录在 `OPEN_SOURCE_REFERENCES.md`。

---

# 真实数据 Go / No-Go

- [ ] GitHub Private
- [ ] 无自动超额 Actions 费用
- [ ] Local/Remote/Production 隔离
- [ ] Region 经真实无代理机构网络验证
- [ ] provision/onboarding/reset 双平台通过
- [ ] onboarding expiry/reissue/响应丢失通过
- [ ] global sign-out + revoked JWT live-session test 通过
- [ ] Session 安全本地存储
- [ ] 启动 Gate 无隐私闪现
- [ ] 本地草稿加密/隔离/TTL/清理
- [ ] RLS/GRANT/View/Function/Storage 越权测试
- [ ] 网络失败/幂等通过
- [ ] 教师交接/学生合并通过
- [ ] 两个 org_admin 或 break-glass 演练
- [ ] roles/schema/data DB backup + 真恢复
- [ ] Storage 独立恢复抽测
- [ ] 配置/Secrets 重建清单
- [ ] 日志无 Password/Token/学生敏感正文
- [ ] 安装/升级路径明确
- [ ] Supabase Free 容量/RPO 能接受
- [ ] 未成年人信息/数据驻留/跨境合规评估完成

任一关键项未满足，只用虚构/脱敏数据。

## 何时必须重新评估“0 元”

- 系统成为机构关键基础设施；
- 无法接受一个教学日左右的恢复点；
- Free DB/Storage/Egress 接近上限；
- inactivity pause 不可接受；
- 教师规模让人工账号恢复不可运营；
- 家长/学生需要自助账号；
- 机构需要 SLA/专业支持。

到那时做新的成本/风险 ADR，不偷偷开启付费服务。
