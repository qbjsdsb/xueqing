# 风险清单与运行要求

> 只记录“不提前验证就很可能造成返工、隐私事故或上线事故”的风险。风险不是停止开发的理由，而是要求在正确阶段实测。

## R1｜仓库仍为 Public

**等级：最高｜立即处理**

当前 `qbjsdsb/xueqing` 仍是 Public。

现在仓库主要是设计文档和虚构占位，尚不是隐私事故；但进入真实开发后，Issue、日志、截图、配置和误提交很容易带入内部信息。

处理：
- 正式 Flutter/Production 开发前改为 Private；
- Secret 永远不因“Private”而允许提交；
- 真实学生/家长数据仍禁止进入 GitHub；
- PR/Issue 只使用虚构示例。

退出条件：仓库 Private + secrets 基线检查。

---

## R2｜临时账号凭据泄露

**等级：最高｜Phase 0**

V1 为零额外付费采用管理员开通 + 临时密码。如果把临时密码长期保存、写日志或在群里随意转发，认证方案会失去意义。

处理：
- 服务端随机生成强临时密码；
- 只在 provision/reset 成功响应返回一次；
- 不写 DB/log/audit/error tracking；
- membership 初始为 onboarding；
- onboarding 普通业务 RLS 全拒绝；
- 教师首次登录必须完成自己的新密码接管；
- 管理员通过已建立身份关系的可信渠道一次性交付。

退出条件：代码/测试证明 Secret 不落盘，onboarding 无业务权限。

---

## R3｜密码重置后旧 Session 仍访问数据

**等级：最高｜Phase 0**

只更新 Auth 密码不能把安全性寄托在“旧 Token 会不会立刻失效”。

处理：
- reset 时 membership → onboarding；
- 普通业务 RLS 每次要求 membership = active；
- disabled 同理；
- 客户端遇到 authorization denied 清理机构上下文，不无限重试。

退出条件：两个客户端测试：A 端登录后，管理员在 B 端 reset/disable，A 端旧 Session 立即读不到业务数据。

---

## R4｜老师不愿意填

**等级：最高｜持续验证**

功能再完整，只要课后要填 5 分钟，最后都会变成应付式台账。

处理：
- `new` 捕捉目标 10–20 秒；
- 常规课后目标 ≤ 60 秒；
- 只记录新事实；
- 周度/阶段派生；
- 真实教师可用性测试；
- 统计完成路径耗时/操作数，不统计“老师填了多少条”。

---

## R5｜数据越用越脏

**等级：高**

不同老师自由输入“阅读理解/现代文阅读/阅读”，后期无法统计。

处理：
- 轻量 taxonomy + 自由标题；
- 默认分类 + 其他/暂未分类；
- 重复案例提示；
- 历史分类节点停用而非硬删；
- 复杂 taxonomy 管理 UI 后置。

---

## R6｜权限 UI 看起来对，数据库实际越权

**等级：最高**

隐藏按钮不能阻止手工 API；View/Function 也可能成为 RLS 后门。

处理：
- RLS + 最小 GRANT；
- assignment-based authorization；
- active membership 硬检查；
- `security_invoker` View；
- `security definer` 最小授权；
- 自动化负面权限测试。

退出条件：unauthenticated、no membership、onboarding、disabled、cross-org、cross-student、cross-subject 攻击式测试全部按设计失败。

---

## R7｜网络失败导致记录丢失/重复

**等级：高**

移动网络切换、超时、连点重试可能丢数据或生成重复事实。

处理：
- 本地临时草稿；
- 清楚保存状态；
- client UUID / operation id；
- 超时后可查询最终状态；
- 不用乐观 UI 伪造正式保存成功。

---

## R8｜多人更新造成静默覆盖

**等级：中高**

处理：
- 关键快照 `version`；
- expected_version；
- 冲突提示；
- 教学事实尽量 append-only。

---

## R9｜项目悄悄长成 ERP/CRM

**等级：高**

风险链：今日课程 → 排课 → 课消 → 收费 → 招生 → 财务，最终核心学情闭环被淹没。

处理：
- lesson = 教学会话，不是完整 schedule；
- 今日以 case_actions 为主；
- 收费/招生/复杂排课需求先产品评审；
- 优先集成成熟系统，不复制 Frappe/Gibbon 的全部 ERP 范围。

---

## R10｜Flutter/Supabase 依赖升级不可复现

**等级：中**

处理：
- 初始化时锁 stable Flutter/Dart；
- 提交 `pubspec.lock`；
- CI 使用明确 SDK；
- 依赖升级单独 PR；
- Production 升级先在 Local/Remote Development 验证。

---

## R11｜Local / Remote Development / Production 混用

**等级：最高**

风险：测试脚本误删真实数据、真实学生进入截图、Secret 混用。

处理：
- 独立 Supabase Project；
- 显著环境标识；
- Production 禁止 seed/reset；
- Git migrations 是 schema 事实源；
- 生产破坏性动作额外确认。

---

## R12｜Supabase Free 没有付费级自动备份保障

**等级：最高｜真实数据前**

0 元不能等于没有恢复能力。

处理：
- 定期 `supabase db dump` / `pg_dump`；
- 加密离站保存；
- 多时间点保留；
- 定期恢复演练；
- 记录 schema/app version。

退出条件：从实际备份成功恢复一个测试环境，而不是只看到一个 `.sql` 文件。

---

## R13｜数据库备份了，Storage 附件没备份

**等级：高**

数据库备份不包含 Storage 文件本体。

处理：
- Storage 对象清单；
- 单独文件备份；
- 抽样恢复；
- DB path ↔ object 一致性检查。

---

## R14｜Free Project 低活动暂停 / 免费额度超限

**等级：中高**

Supabase Free Project 可能因低活动暂停；DB/Storage/Egress 也有免费上限。

处理：
- Pilot 前记录当前额度；
- 管理员知道恢复 paused project 流程；
- 长假前确认备份；
- 使用量接近阈值时先评审数据清理/附件策略；
- 不启用自动付费升级。

“系统被大量真实教师长期依赖”本身就是重新评估基础设施的触发条件。

---

## R15｜GitHub Actions 免费额度被重构建吃完

**等级：中**

处理：
- PR 默认 Linux format/analyze/unit/DB tests；
- Android/Windows release build 仅 Milestone/Release/手动；
- 不用 larger runner；
- artifact retention 短；
- GitHub billing budget 设为到上限停止使用，不自动付费。

---

## R16｜应用分发和版本失控

**等级：中高**

几十名老师装不同版本，DB 已迁移但旧客户端还在运行，会造成隐性故障。

处理：
- Windows/Android 明确 version；
- schema migration 保留必要兼容窗口；
- 后续加最低支持版本提示；
- 签名密钥独立备份；
- 发布前 smoke test。

---

## R17｜自由文本收集过度敏感信息

**等级：高**

处理：
- UI 提示记录可观察教学事实；
- 不把无关家庭/健康/身份推断作为教学标签；
- 日志/AI 输入最小化；
- 管理员按制度更正/导出/删除。

---

## R18｜AI 让数据更漂亮但事实变差

**等级：中高（V2）**

处理：
- AI 输出先是 draft；
- 保留来源与人工确认；
- AI 不写正式 status；
- AI 总结不等于 evidence；
- AI 不越权读取其他学科。

---

## R19｜ChatGPT Work 长会话上下文漂移

**等级：高｜开发过程**

风险：一条超长会话经历几十个 PR 后，会把旧方案、旧 SHA、已废弃 ADR 混在一起。

处理：
- GitHub 是代码事实源；
- 每个任务先读 `AGENTS.md` + 当前 docs；
- 一个可验收目标通常一条 Work 会话 + 一个 PR；
- 不把聊天里“记得的代码”当当前仓库；
- 方向变化写 ADR；
- milestone 完成后开新的执行线程。

---

## R20｜云端 Agent 声称“测试通过”，实际没有执行环境

**等级：最高｜开发过程**

Work 适合多步骤研究/交付，但软件发布必须区分“推理上看起来正确”和“命令真实执行”。

处理：
- 能运行就记录真实命令/结果；
- 不能运行时明确标记未验证；
- GitHub Actions 或 Codex 负责可执行证据；
- PR 不因为 Agent 说“应该可以”就视为 CI green。

---

## R21｜Luna Max 用在所有机械任务，提前耗尽包含额度

**等级：中**

用户希望使用 Luna Max，但零额外付费要求避免无意义消耗。

处理：
- Max 优先 RLS、migration、事务、并发、安全、复杂 refactor、Milestone 终审；
- 重命名、格式、简单 UI、重复 CRUD 用普通 Luna 档即可；
- 无论模型，一个 PR 目标要小；
- 达到方案内额度后等待重置，不购买 credits。

---

## R22｜为了“方便”接入隐藏付费 SaaS

**等级：高**

常见来源：SMTP、短信、监控、错误追踪、AI API、商业 UI、数据库 add-on、larger CI runner。

处理：
新增外部依赖前回答：
1. V1 不用它是否真的做不成？
2. 免费层是否足够？
3. 超额会不会自动扣费？
4. 能否迁出？
5. 是否接触学生敏感数据？

未经 ADR 不新增付费硬依赖。

---

## R23｜照搬开源项目导致产品失焦或许可证风险

**等级：中高**

处理：
- 借设计模式和经验，不大段复制未知许可证代码；
- 优先 Flutter/Supabase 官方；
- Frappe/Gibbon 只借教育领域长期经验，不 fork 成 ERP；
- AppFlowy 只借跨平台/隐私/发行经验，不带入 Rust/CRDT；
- 参考来源记录在 `docs/OPEN_SOURCE_REFERENCES.md`。

---

# 真实数据上线前 Go / No-Go

以下关键项必须全部满足：

- [ ] GitHub 仓库已 Private
- [ ] Local / Remote Development / Production 已隔离
- [ ] Production 无 development seed/reset
- [ ] 管理员开通账号流程双平台验证
- [ ] 临时密码不落 DB/log/audit/GitHub
- [ ] onboarding / disabled 旧 Session 均无业务权限
- [ ] RLS/GRANT/View/Function 越权测试通过
- [ ] 网络失败草稿恢复通过
- [ ] 实际机构网络测试通过
- [ ] 教师交接通过
- [ ] DB dump + 实际恢复演练通过
- [ ] Storage 独立备份/恢复抽测
- [ ] Production Secret 不在客户端/GitHub
- [ ] 日志无学生敏感正文、Token、密码
- [ ] 安装包签名与更新路径明确
- [ ] GitHub Actions 不会自动产生超额费用
- [ ] Supabase Free 使用量适合当前 Pilot
- [ ] 根据实际部署地区完成隐私/未成年人数据合规评估

只要关键项未满足，就继续使用虚构/脱敏数据。

## 何时必须重新评估“0 元”

出现任一情况时，不应机械坚持免费：
- 系统已经成为机构日常关键基础设施；
- 真实数据无法接受较长恢复点；
- Free 数据库/Storage/流量接近上限；
- 长假暂停对业务不可接受；
- 教师数量扩大导致管理员重置密码不可运营；
- 家长/学生端需要自助账号；
- 机构需要 SLA/专业支持。

到那时做一次新的成本/风险 ADR，而不是偷偷开付费服务。