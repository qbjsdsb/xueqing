# 风险清单与运行要求

> 只记录“不提前验证就很可能造成返工或上线事故”的风险。风险不是停止开发的理由，而是要求在正确阶段实测。

## R1｜Email OTP 投递与登录体验

**等级：最高｜Phase 0**

风险：SDK 能发 OTP 不等于教师邮箱能稳定收到，也不等于 Windows/Android 输入验证码体验自然。

处理：
- 双平台真机/真邮箱 Spike；
- 新 Auth User / 已有 Auth User；
- 错误、过期 OTP；
- 429 / 频繁请求；
- Session 恢复；
- 主要教师邮箱域投递延迟；
- Production Custom SMTP/等价服务。

退出条件：非技术老师能独立登录，验证码失败时知道如何恢复。

---

## R2｜开放 Auth User 创建被滥用

**等级：中高**

V1 为统一新/旧用户 OTP 体验，可能允许无 invitation 邮箱创建一个无机构权限的 Auth User。

风险：机器人请求 OTP、制造无业务价值 Auth User、消耗邮件额度。

处理：
- active membership 才有业务数据权限；
- 无 invitation/membership 只能看到最小“未授权”页面；
- rate limits；
- CAPTCHA/等价防滥用；
- 监控 Auth 创建与 OTP 发送异常。

退出条件：滥用不会转化成数据越权或不可控邮件成本。

---

## R3｜真实机构网络与 Supabase 可用性

**等级：高｜真实数据前**

开发者网络正常不代表机构 Wi-Fi、教师移动网络稳定。

处理：实际地点测试 OTP、查询、保存、上传、Function、网络切换，记录高频流程延迟/失败。

退出条件：核心流程稳定；否则评估部署区域/网络/基础设施替代。

---

## R4｜老师不愿意填

**等级：最高｜持续验证**

风险：课后记录超过几分钟，系统最终变成应付式填表。

处理：
- `new` 捕捉 10–20 秒；
- 常规课后目标 ≤ 60 秒；
- new/confirmed 两阶段；
- 只记录新事实；
- 周度/阶段派生；
- 可用性测试看时间/点击，而不是填表量。

退出条件：连续模拟/试用一周没有明显填写阻力。

---

## R5｜分类过松数据脏，过严又拖慢老师

**等级：高**

处理：轻量 taxonomy + 自由标题；new 可暂不分类；confirmed 前补；少量默认节点 + 其他；复杂治理后置。

退出条件：既能稳定统计，又不阻塞快速捕捉。

---

## R6｜UI 权限正确，数据库实际越权

**等级：最高**

处理：
- active membership + roles + assignments；
- RLS + 最小 GRANT；
- security_invoker View；
- security definer 安全约束；
- 负面权限测试。

退出条件：未登录、只有 Auth、pending invitation、disabled、跨机构、跨学生、跨学科攻击式测试按预期失败。

---

## R7｜Invitation 被错误用户接受

**等级：最高**

风险：如果 accept_invitation 信任客户端传入 email/user_id，可能让登录用户领取别人的机构邀请。

处理：
- 服务端从 Auth Session 获取可信 user id / verified email；
- invitation 邮箱规范化比较；
- 受控事务创建 membership + roles；
- invitation 接受幂等；
- pending invitation 表不可被普通 authenticated 用户枚举。

退出条件：不同邮箱、猜 invitation id、重复重试都不能越权。

---

## R8｜网络失败导致记录丢失/重复

**等级：高**

处理：本地 draft、保存状态、client UUID、operation id、幂等 command、超时后可确认最终状态。

退出条件：断网/超时/App 重启可恢复且不重复。

---

## R9｜多人更新静默覆盖

**等级：中高**

处理：关键快照 `version/expected_version`、冲突提示、事实尽量 append-only。

退出条件：并发修改不会 silent last-write-wins。

---

## R10｜项目悄悄长成 CRM

**等级：高**

处理：lesson 是实际教学会话；今日由 actions 驱动；收费/课消/排课需求单独评审，优先集成已有系统。

退出条件：V1 不依赖完整排课仍可工作。

---

## R11｜Git migrations 与远程 schema 漂移

**等级：最高**

处理：Local Supabase CLI 开发，Git migrations 是结构事实源，Remote 临时试验必须回写，PR 从空库 reset，Production 只跑已评审 migration。

退出条件：新环境仅靠仓库能重建 schema/RLS。

---

## R12｜Development / Production 混用

**等级：最高**

处理：Local / Remote Development / Production 独立语义；Production 禁止 seed/reset；数据库、Storage、SMTP、Secret、测试账号分开。

---

## R13｜DB 有备份但附件没有

**等级：高**

处理：DB 与 Storage 分别备份/恢复、对象清单、抽样恢复、路径一致性检查。

---

## R14｜客户端版本与 schema 不兼容

**等级：中高**

处理：明确 Windows/Android 版本与分发；高风险 migration 用 expand → migrate → contract；后期最低支持版本；签名密钥安全备份。

---

## R15｜自由文本收集过度敏感信息

**等级：高**

处理：可观察教学事实、限制日志/AI 输入、不把家庭/健康推断做标签、管理员数据治理。

---

## R16｜AI 让文字漂亮但事实变差

**等级：中高（V2）**

处理：AI 只生成 draft，有来源和人工确认，不写正式 status，不把总结当 evidence，不越权。

---

## R17｜教师停用后责任项变成孤儿

**等级：高**

处理：disable 前 inventory → handoff → 验证无 orphan → 最后 disable membership。

---

## R18｜学生合并破坏历史或重复执行

**等级：中高**

处理：同机构、source→merged 而非删除、merge record、operation id、防环、合并前展示影响范围。

---

## R19｜Production 邮件服务成为单点故障

**等级：高**

OTP 登录依赖邮件。

处理：
- 可靠 Custom SMTP/邮件服务；
- 监控投递失败/延迟；
- 管理员有可理解支持手册；
- 不把 SMTP Secret 放客户端；
- 后期在真实必要时再评估备用登录策略，而不是 V1 同时维护三套登录。

退出条件：邮件异常可被发现、定位、恢复，不让机构全员“突然登不上且不知道原因”。

---

# 真实数据上线 Go / No-Go

关键项必须满足：

- [ ] GitHub 仓库 Private/等价源码访问控制
- [ ] Local / Remote Development / Production 隔离
- [ ] migrations 从空库重建 schema/RLS
- [ ] Windows / Android OTP 全矩阵验证
- [ ] Production 邮件服务、rate limits、防滥用配置
- [ ] Auth User 无 membership 无业务权限
- [ ] pending invitation 无业务权限
- [ ] accept_invitation verified-email/幂等测试
- [ ] RLS/GRANT/View/Function 越权测试
- [ ] 网络失败草稿恢复/幂等
- [ ] 真实机构网络测试
- [ ] 教师交接/停用演练
- [ ] 学生合并治理验证
- [ ] DB 恢复演练
- [ ] Storage 恢复方案抽测
- [ ] Production Secret/SMTP Secret 不在客户端/GitHub
- [ ] 日志无 OTP/Token/Secret/完整敏感正文
- [ ] 安装包签名与更新路径明确
- [ ] Production migration + smoke test 明确
- [ ] 实际部署地区隐私/未成年人数据合规评估

关键项未满足时继续使用虚构/脱敏数据。