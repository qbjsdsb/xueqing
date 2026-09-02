# 风险清单与运行要求

> 这里只保留“不提前验证就容易返工、越权、丢数据或无法运营”的风险。每项都要求有处理方式或退出证据。

## R1｜Private 不等于可以把真实数据放进 GitHub

**等级：最高｜持续**

当前仓库已经是 Private，但 Private 只解决源码可见性，不是学生数据存储方案。

处理：
- Secret 永不提交；
- Issue / PR / screenshot / seed 只使用明显虚构数据；
- 不上传真实学生、家长、教师账号资料、试卷、作文、家校正文、Production backup；
- 发生误提交按安全事件处理，而不是只删最新 commit。

退出：持续性要求，不因仓库 Private 而关闭。

---

## R2｜GitHub Free 私有仓库缺少平台级强制保护

**等级：中高｜开发治理**

零额外付费阶段不能假设 GitHub 会替我们强制所有 PR / status checks。

处理：
- Work / Codex 禁止直推 main；
- feature / review branch + Draft PR；
- PR 写清真实执行证据；
- 人工合并；
- Foundation 优先 squash；
- 以后升级 GitHub 计划再考虑更强平台规则。

退出：流程进入 AGENTS / workflow，并在实际开发中持续遵守。

---

## R3｜临时凭据泄露或长期有效

**等级：最高｜Phase 0**

临时密码不是一次性 Token，谁先拿到都可能尝试接管。

处理：
- 强随机；
- onboarding 无学生业务权限；
- `onboarding_expires_at`；
- 可信渠道一次性交付；
- 不写 DB / log / audit / GitHub；
- 过期或交付状态未知一律 reissue 新密码。

退出：泄露、过期、重签发测试通过。

---

## R4｜账号接管后旧 Session 重新获得 active 权限

**等级：最高｜Phase 0**

仅“改密码 → active”不够；此前拿到临时密码的人可能已经建立 Session，被撤销 JWT 在自身 `exp` 前仍可能存在。

处理：
- complete onboarding：改密码 → global sign-out → active → 强制重新登录；
- RLS 验证 JWT `session_id` 对应 `auth.sessions` 仍存在；
- 同时要求 active membership。

退出：保存旧 JWT，接管后直接请求 Data API，必须立即失败。

---

## R5｜live-session guard 正确但拖垮查询

**等级：高｜Phase 0**

Session 校验是安全边界，但如果在 RLS 中对结果每行重复昂贵求值，会造成不可接受的延迟。

处理：
- 封装稳定 helper；
- 避免不必要逐行重复求值；
- 给相关字段索引；
- Today / Student / Case 查询用 EXPLAIN / 实际测量；
- 若出现瓶颈，通过 ADR 优化实现，不能静默删除安全条件。

退出：安全测试通过且核心查询性能可接受。

---

## R6｜管理员 reset 顺序错误

**等级：最高｜Phase 0**

如果先改 Auth 密码、最后才把 membership 降为 onboarding，跨系统失败可能留下仍 active 的业务权限。

处理：**先 membership → onboarding，再更新 Auth 临时密码**；任何中间失败优先落在无学生业务权限状态。

退出：故障注入覆盖每一步。

---

## R7｜Credential 响应丢失诱导系统保存明文密码

**等级：高｜Phase 0**

provision / reset 可能已经成功，但响应在网络上丢失。

处理：
- membership 保持 onboarding；
- 不为了幂等持久化明文 Secret；
- 交付状态未知时管理员直接 reissue 新密码；
- 旧临时密码失效；
- operation receipt 不保存秘密。

退出：模拟“服务端成功、客户端超时”仍能恢复且无 secret 落盘。

---

## R8｜唯一管理员锁死全机构

**等级：高｜真实 Pilot 前**

无 SMTP 自助找回时，唯一 org_admin 是单点故障。

处理：
- 至少两个独立可信 active org_admin；或
- 已演练的 Supabase Project Owner break-glass；
- 普通 UI 不允许停用最后一个可恢复 org_admin。

退出：第二管理员或 break-glass 演练完成。

---

## R9｜同一个 Auth User 跨机构同时活跃

**等级：最高｜V1 身份治理**

Password 属于全局 Auth User。如果用户同时属于 A / B 两家机构，A 管理员 reset 会影响 B。

处理：
- V1 同一 `user_id` 同一时点最多一个 onboarding / active membership；
- 其他机构仅允许 disabled 历史；
- provision 发现跨机构非 disabled membership 时拒绝；
- 真正需要跨机构账号前先采用中央身份恢复 / OTP / SSO 并新增 ADR。

退出：数据库约束 + provision 负面测试通过。

---

## R10｜本地 Session 存储不安全

**等级：最高｜Phase 0**

Production 不能直接把默认 SharedPreferences 系列 Session 存储当最终安全方案。

处理：
- Supabase custom `LocalStorage`；
- Windows / Android OS secure storage；
- Password 永不本地保存。

退出：双平台 Token 安全存储实现和设备检查通过。

---

## R11｜App 启动闪现旧权限数据

**等级：高｜Phase 0**

本地 Session 被读取出来不代表它仍然有效。

处理：
- Startup Authorization Gate；
- Session refresh / live Session / membership / organization 全解析前不挂业务 Shell。

退出：expired / revoked / disabled Session 均不会闪现学生页面。

---

## R12｜本地草稿变成明文学生数据库

**等级：最高｜Phase 0**

为了断网恢复而长期明文保存学情、作文或备注，同样是隐私事故。

处理：
- encrypted at rest；
- key 在 OS secure storage；
- user / org scope；
- TTL；
- sync 成功删除；
- logout / account switch / disabled 有明确清理；
- 不存 Token / Password。

退出：设备文件检查 + 账号切换 + TTL 测试通过。

---

## R13｜机构时区缺失导致 Today / 到期 / 报告边界错误

**等级：高｜Milestone 1**

如果业务日期直接依赖设备时区，教师出差、设备设置错误或未来跨地区部署都会让“今天”和逾期边界不一致。

处理：
- `organizations.time_zone` 使用 IANA timezone；
- 系统时间存 UTC；
- Today / action 业务日期 / lesson 所属日期 / 周度与报告周期统一按机构时区；
- V1 不做 campus 独立时区。

退出：跨午夜、设备时区错误、DST/IANA 行为测试通过（适用时）。

---

## R14｜老师不愿意填

**等级：最高｜持续**

处理：
- `new` 目标 10–20 秒；
- 常规课后目标 ≤ 60 秒；
- 只填新事实；
- 周度 / 阶段派生；
- 实际教师连续一周可用性测试。

退出不是“页面做好”，而是流程耗时和完成率达标。

---

## R15｜暂停 Case 永久失踪

**等级：高｜业务正确性**

仅有 `pause_reason`、没有下一动作，会让问题从 Today 消失。

处理：
- confirmed / intervening / pending_verification / stable 始终有 pending primary action；
- 暂缓使用 `review + due_at`；
- pause_reason 只解释。

退出：所有正式未关闭 Case 都能通过行动系统再次被找到。

---

## R16｜分类和自由文本越用越脏

**等级：高**

处理：
- 轻量 taxonomy + 自由标题；
- 默认分类 + 其他 / 暂未分类；
- 重复 Case 提示；
- 历史分类节点停用不硬删；
- 不在 V1 建庞大知识图谱。

---

## R17｜UI 权限正确、数据库实际越权

**等级：最高**

处理：
- RLS + 最小 GRANT；
- live Session + active membership；
- assignment-based authorization；
- `security_invoker` View；
- security-definer 最小权限；
- 攻击式负面测试。

退出：unauth / no-member / revoked / onboarding / disabled / cross-org / cross-student / cross-subject 全按设计失败。

---

## R18｜Storage 成为绕过业务 RLS 的旁路

**等级：最高｜真实文件前**

处理：
- private bucket；
- `storage.objects` policy 与 organization / assignment 一致；
- signed URL 仅授权后生成且 TTL 短；
- signed URL 不进入日志 / 长期缓存；
- 文件类型 / 大小限制；
- DB metadata 与 object 生命周期一致。

退出：跨机构直接下载、签名 URL、路径猜测测试通过。

---

## R19｜网络失败导致记录丢失或重复写

**等级：高**

处理：
- encrypted draft；
- 未保存 / 保存中 / 已保存 / 失败状态；
- client UUID；
- operation id；
- 超时后可查询最终状态；
- 不用乐观 UI 冒充正式保存成功。

退出：断网、超时、重复点击、重试测试不丢事实也不重复事实。

---

## R20｜多人更新静默覆盖

**等级：中高**

处理：
- version / expected_version；
- 教学事实尽量 append-only；
- 冲突显式提示；
- 不用 last-write-wins 掩盖冲突。

---

## R21｜项目悄悄长成 ERP / CRM

**等级：高**

风险链：课程 → 排课 → 课消 → 收费 → 招生 → 财务，最终学情闭环被淹没。

处理：
- lesson 只是教学会话；
- Today 由 case_actions 驱动；
- 收费 / 课消 / 招生 / 完整排课进入产品评审；
- 优先与成熟系统集成，不复制大型教育 ERP。

---

## R22｜中国大陆实际网络与 Region 不匹配

**等级：最高｜Production Project 创建前**

处理：
- Remote Development 只用虚构数据；
- 实际机构 Wi-Fi + 普通移动网络 + 无代理 / VPN 测 Auth / Data API / Storage / Functions；
- 不达标就重建 Dev 到其他 APAC region；
- 测完才创建 Production；
- 未成年人数据驻留 / 跨境单独做机构合规评估。

退出：有真实网络测试记录 + region 决策记录 + 合规评估记录。

---

## R23｜Local / Remote Development / Production 混用

**等级：最高**

处理：
- 独立 project / Secret / Storage / 测试账号；
- Production 禁 seed / reset；
- migrations 是 schema 事实源；
- 环境 UI 有明显标识。

---

## R24｜Free Production 没有付费级自动日备份保障

**等级：最高｜真实数据前**

处理：
- roles / schema / data 逻辑 dump；
- 多时间点、加密离站；
- 必要 migration history；
- 实际 restore drill；
- Pilot 默认目标 RPO ≤ 一个教学日。

如果机构不能接受这个恢复点，Free Pilot 不合格。

退出：真实备份恢复到新测试 Project 并完成 smoke / RLS tests。

---

## R25｜只恢复 DB，没有恢复 Auth / Storage / 配置

**等级：最高**

处理：
- Auth user / identity 数据按当前官方迁移流程恢复并实际登录验证；
- 默认不假定旧 JWT 在新 Project 继续有效；
- Storage objects + manifest 单独备份；
- Edge Functions 代码在 Git；
- Auth / Realtime / Extensions / Secrets 名单 / Project config 有重建清单；
- 恢复后做 DB path ↔ object 一致性检查。

退出：完整 disaster recovery drill PASS。

---

## R26｜Free Project inactivity / quota

**等级：中高**

处理：
- 记录当前额度；
- 长假前确认 backup；
- 知道 paused project 恢复流程；
- 接近 DB / Storage / Egress 上限先评审；
- 不自动开启付费升级。

---

## R27｜GitHub Actions 超额产生费用

**等级：中高**

处理：
- billing budget 设置超额停止；
- PR 默认 Linux 快速测试；
- Windows / Android heavy build 仅 Milestone / Release / 手动；
- 不用 larger runner；
- artifact retention 短。

退出：预算设置人工确认 + CI 策略落地。

---

## R28｜Flutter / Supabase 依赖升级不可复现

**等级：中**

处理：
- 锁 stable SDK；
- 正式初始化后提交 `pubspec.lock`；
- CI 固定 SDK；
- 依赖升级独立 PR；
- Production 前先 Local / Remote Dev 验证。

---

## R29｜客户端版本与 DB schema 失配

**等级：中高**

处理：
- 明确 app version；
- migration 保留合理兼容窗口；
- destructive change 优先 expand → migrate → contract；
- 最低支持版本策略；
- release smoke test。

---

## R30｜自由文本过度收集敏感信息

**等级：高**

处理：
- 只记录必要可观察教学事实；
- 备注最小化；
- 日志 / AI 输入最小化；
- 管理员具备更正 / 导出 / 删除治理流程。

---

## R31｜AI 让文本漂亮但事实变差

**等级：中高｜V2**

处理：
- AI 只生成 draft；
- 保留来源；
- 人工确认；
- 不写正式 status；
- AI 总结不等于 Evidence；
- 不越权跨学科读取。

---

## R32｜Work 长会话上下文漂移

**等级：高｜开发过程**

处理：
- GitHub 是代码事实源；
- 每个任务先读 AGENTS + 当前 docs；
- 一个可验收目标通常一条 Work 会话 + 一个 PR；
- 方向变化写 ADR；
- milestone 后开新执行线程。

---

## R33｜Agent 声称“测试通过”但没有执行

**等级：最高｜开发过程**

处理：
- 真实命令 / CI 输出才叫执行证据；
- 无法执行必须标“未验证”；
- PR 不因模型口头判断视为 green。

---

## R34｜Max 推理预算被机械任务耗尽

**等级：中**

处理：
- Max / 高推理优先 RLS、migration、Auth、事务、并发、安全、终审；
- 格式、改名、重复 CRUD 用较轻档；
- 包含额度用完就等待重置，不购买 extra credits。

---

## R35｜隐藏付费 SaaS 破坏 0 元目标

**等级：高**

任何新外部依赖前回答：
1. V1 不用它是否真的做不成？
2. Free 是否够？
3. 超额会不会自动扣费？
4. 能否迁出？
5. 是否接触学生敏感数据？

未经 ADR 不新增付费硬依赖。

---

## R36｜照搬开源项目导致产品失焦或许可证问题

**等级：中高**

处理：
- 借设计模式和经验，不大段复制未知许可证代码；
- 优先 Flutter / Supabase 官方；
- Frappe / Gibbon 只借长期教育领域经验，不 fork 成 ERP；
- AppFlowy 只借跨平台、隐私、发行经验；
- 来源记录在 `OPEN_SOURCE_REFERENCES.md`。

---

# 真实数据 Go / No-Go

## 已完成

- [x] GitHub repository 已 Private
- [x] Foundation 明确不提交真实学生数据或 Secret

## 必须在真实数据前完成

- [ ] Actions 不会自动产生超额费用
- [ ] Local / Remote Development / Production 隔离
- [ ] organization timezone migration / 测试
- [ ] Region 经真实无代理机构网络验证
- [ ] provision / onboarding / reset 双平台通过
- [ ] onboarding expiry / reissue / 响应丢失通过
- [ ] global sign-out + revoked JWT live-session test 通过
- [ ] live-session guard 性能可接受
- [ ] Session OS 安全存储
- [ ] Startup Gate 无隐私闪现
- [ ] 本地草稿加密 / 隔离 / TTL / 清理
- [ ] RLS / GRANT / View / Function / Storage 越权测试
- [ ] 网络失败 / 幂等通过
- [ ] 教师交接 / 学生合并通过
- [ ] 两个 org_admin 或 break-glass 演练
- [ ] roles / schema / data backup + 真恢复
- [ ] Auth 登录在恢复项目验证
- [ ] Storage 独立恢复抽测
- [ ] 配置 / Secrets 重建清单
- [ ] 日志无 Password / Token / 学生敏感正文
- [ ] 安装 / 升级路径明确
- [ ] Supabase Free 容量和 RPO 能接受
- [ ] 未成年人信息 / 数据驻留 / 跨境合规评估完成

任一关键项未满足，只能使用虚构或严格脱敏数据。

---

# 何时必须重新评估“0 元”

出现任一情况时，不应机械坚持免费：
- 系统成为机构关键基础设施；
- 无法接受一个教学日左右的恢复点；
- Free DB / Storage / Egress 接近上限；
- inactivity pause 不可接受；
- 教师规模让人工账号恢复不可运营；
- 家长 / 学生需要自助账号；
- 机构需要 SLA / 专业支持。

到那时做新的成本 / 风险 ADR，而不是偷偷开启付费服务。
