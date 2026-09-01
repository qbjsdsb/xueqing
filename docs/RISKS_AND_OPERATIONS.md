# 风险清单与运行要求

> 本文件记录“如果不提前验证，后期最可能造成返工或上线事故”的事项。风险不是理由停止开发，而是要求在正确时间做验证。

## R1｜Windows / Android 邀请与首次登录体验

**等级：高｜Phase 0 必须验证**

风险：服务端能发邀请，不代表 Windows/Android 上的 redirect、密码设置、首次激活体验自然。

处理：
- 双平台真实 Spike；
- 验证新邀请、过期重发、取消、密码恢复；
- 验证 App 已运行/未运行时 deep link；
- 验证 Redirect URL allowlist；
- 已 confirmed Auth User 不错误走 new-user invite；
- 不合格就提前调整认证 UX。

退出条件：非技术老师能独立完成首次加入；失败/过期也知道如何恢复。

---

## R2｜真实机构网络环境与 Supabase 可用性

**等级：高｜真实数据前必须验证**

风险：开发者网络正常不等于机构办公网络、教师手机网络都稳定。

处理：
- 实际地点/网络测试登录、查询、上传、Function；
- 测试 Wi-Fi / 移动网络切换；
- 记录高频流程延迟和失败率；
- Repository/Service 隔离后端细节。

退出条件：高频教学流程在真实网络下稳定可用；否则评估部署区域、网络方案或基础设施替代。

---

## R3｜老师不愿意填

**等级：最高｜产品持续验证**

风险：功能再完整，只要每次课后要填 5 分钟，最终都会变成应付式数据。

处理：
- 课堂新问题快速捕捉目标 10–20 秒；
- 常规课后记录目标 ≤ 60 秒；
- `new` 草稿和 `confirmed` 正式案例分离；
- 只记录新事实；
- 周度/阶段自动生成；
- 真实教师可用性测试；
- 统计完成时间与操作数，而不是“填了多少条”。

退出条件：连续一周模拟/试用中，高频流程没有明显填写阻力。

---

## R4｜数据越用越脏，或分类反过来拖慢老师

**等级：高**

风险一：完全自由输入导致“阅读理解/现代文阅读/阅读”口径碎裂。

风险二：为了治理口径做一棵庞大知识树，老师每次录入要点很多层分类，反而不愿使用。

处理：
- 轻量受控 taxonomy + 自由标题双轨；
- `new` 草稿允许不选完整分类；
- confirmed 前再补；
- 默认少量稳定节点 + “其他/暂未分类”；
- 历史已引用节点优先停用，不硬删除；
- 复杂分类治理后置。

退出条件：数据可统计，同时快速捕捉不被分类阻塞。

---

## R5｜权限在 UI 看起来对，数据库实际越权

**等级：最高**

风险：隐藏按钮不阻止手工 API 请求；View/Function 也可能绕过 RLS。

处理：
- RLS + 最小 GRANT；
- membership + assignment 授权；
- security_invoker View；
- security definer 最小授权/search_path；
- 自动化负面权限测试。

退出条件：未登录、pending invitation、disabled membership、跨机构、跨学生、跨学科攻击式测试全部按预期失败。

---

## R6｜网络失败导致课后记录丢失/重复

**等级：高**

风险：移动网络切换、超时、连点重试可能导致丢数据或重复数据。

处理：
- 本地临时草稿；
- 明确保存状态；
- client UUID / operation id；
- 幂等 command；
- 超时后可查询最终状态；
- 不用“乐观 UI”伪造正式保存成功。

退出条件：断网、超时、App 重启场景下输入可恢复且不会重复创建。

---

## R7｜多人更新造成静默覆盖

**等级：中高**

风险：管理员/老师同时修改同一当前状态对象时，后保存者吞掉前者。

处理：
- 关键快照 `version` / expected_version；
- 条件更新；
- 冲突提示；
- 教学事实尽量 append-only。

退出条件：两个客户端并发修改不会 silent last-write-wins。

---

## R8｜项目悄悄长成 CRM

**等级：高**

风险：为了“今日课程”加入排课，为了排课加入课消，为了课消加入收费，最终偏离教学闭环。

处理：
- lesson 定义为实际教学会话，不是 schedule；
- 今日以 case_actions 为主；
- CRM 类需求单独产品评审；
- 优先与已有系统集成。

退出条件：V1 没有完整排课系统也能完成核心流程。

---

## R9｜Flutter/Supabase 依赖升级造成不可复现

**等级：中**

处理：
- 正式初始化锁定当前稳定 Flutter/Dart 基线；
- 提交应用 `pubspec.lock`；
- CI 使用明确 SDK；
- 升级单独 PR；
- 先跑测试再升级 Production。

---

## R10｜Local / Remote Development / Production 混用

**等级：最高**

风险：测试脚本误删真实数据、真实学生进入开发截图、Secret 混用。

处理：
- Remote Development 与 Production 独立项目；
- Local 只用虚构 seed；
- Production 禁止 seed reset；
- CI/CD 变量分开；
- UI/日志显著标记当前环境；
- 生产破坏性操作额外确认。

---

## R11｜数据库有备份，但附件没备份

**等级：高**

处理：
- DB 与 Storage 分开设计恢复；
- 定期对象清单；
- 抽样恢复附件；
- 检查 DB path ↔ Storage object 一致性。

---

## R12｜应用分发和更新失控

**等级：中高**

风险：几十个老师各自装不同版本，schema 已升级但旧客户端仍在使用。

处理：
- Windows/Android 明确版本号与分发渠道；
- schema 迁移保留必要向后兼容窗口；
- 高风险变化采用 expand → migrate → contract；
- 后期加入最低支持客户端版本；
- 签名密钥独立备份。

---

## R13｜自由文本收集过度敏感信息

**等级：高**

处理：
- UI 提示“记录可观察教学事实”；
- 不把无关家庭/健康推断作为教学标签；
- 限制日志/AI 输入范围；
- 管理员按制度处理更正/导出/删除请求。

---

## R14｜AI 让数据看起来更漂亮，但事实变差

**等级：中高（V2）**

处理：
- AI 输出先是 draft；
- 保留来源与人工确认；
- AI 不写正式 status；
- AI 总结不等于 evidence；
- AI 不越权跨学科读取。

---

## R15｜邀请邮件、Auth User、membership 出现半状态

**等级：高**

风险：Auth invite 是外部管理操作，不能假定与业务数据库写入天然一个事务。可能出现邮件已发但后续 DB 更新失败，或重复重试产生多条业务记录。

处理：
- `organization_invitations` 独立于 membership；
- pending invitation 无业务权限；
- 同机构/邮箱最多一个 pending invitation；
- create/resend/accept 流程幂等；
- membership 只在受控激活后成为 active；
- 失败可恢复，不通过重复 Auth User 解决。

退出条件：模拟每一步网络/服务失败，最终都能重试到一致状态且不产生重复 member。

---

## R16｜Git migrations 与远程 Dashboard schema 漂移

**等级：最高｜工程持续约束**

风险：某次“临时修一下”只改了远程 Table Editor/SQL Editor，随后本地、CI、另一位开发者和 Production 都出现不同 schema。

处理：
- Local Supabase CLI 为 schema/RLS 主要开发环境；
- Git migrations 为正式事实源；
- Remote Development 临时试验必须回写 migration；
- PR 中从空库 `db reset` 验证；
- Production 只跑已评审 migration。

退出条件：新环境可以只依赖仓库重建当前数据库结构与权限。

---

## R17｜教师停用后当前责任变成“孤儿”

**等级：高**

风险：管理员先 disable 账号，才发现该教师仍是案例 owner、行动 assignee 或唯一 lead。

处理：
- 停用前 inventory；
- handoff 事务优先；
- 验证接手人权限；
- 不留 orphan current responsibility；
- 最后一步才 disable membership。

退出条件：离职演练后，所有历史保留，所有当前责任都有明确接手或受控暂停。

---

## R18｜学生合并破坏历史或重复执行

**等级：中高**

处理：
- source/target 同机构；
- source 变 merged 而非硬删除；
- 保存 merged_into + merge record；
- 事务/operation id；
- 防 merge 环；
- 合并前展示影响范围。

---

# 真实数据上线前 Go / No-Go 清单

必须满足关键项才进入真实学生数据：

- [ ] 仓库已 Private 或有等价源码访问控制
- [ ] Local / Remote Development / Production 边界明确
- [ ] Git migrations 可从空库重建当前 schema/RLS
- [ ] 双平台认证、redirect、邀请过期/重发验证
- [ ] pending invitation 无业务权限
- [ ] RLS/GRANT/View/Function 越权测试通过
- [ ] 网络失败草稿恢复和幂等重试通过
- [ ] 实际机构网络测试通过
- [ ] 教师交接/停用演练通过
- [ ] 学生合并基础治理验证
- [ ] 数据库恢复演练通过
- [ ] Storage 恢复方案存在并抽测
- [ ] Production Secret 不在客户端/GitHub
- [ ] 日志无敏感正文和 Token
- [ ] 安装包签名与更新路径明确
- [ ] Production migration + smoke test 流程明确
- [ ] 根据实际部署地区完成隐私/未成年人数据合规评估

只要关键项未满足，就继续使用虚构/脱敏数据。