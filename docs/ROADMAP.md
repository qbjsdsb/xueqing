# 开发路线

## 总原则

开发顺序遵循：**先证明关键风险可控，再搭底座，再做一条完整垂直闭环，最后扩展。**

每个阶段必须有可验证用户场景，不以“写了多少页面”衡量进度。

---

## Phase 0｜工程、认证与运行风险验证

目标：在业务开发前，先证明 Windows + Android + Supabase 这条技术路线真的能稳定支撑机构使用，而且任何新环境都能从仓库重建开发基线。

### Flutter 工程
- [ ] 使用当前稳定 Flutter 正式初始化 Windows + Android 工程
- [ ] 建立 feature-first 目录与 View / ViewModel / Repository / Service 边界
- [ ] 建立统一 AppConfig 与环境切换
- [ ] 提交应用项目 `pubspec.lock`
- [ ] 配置格式化、静态分析、基础测试
- [ ] 禁止业务代码到处直接调用 `Supabase.instance.client`

### Local Supabase
- [ ] 初始化 `supabase/` 目录
- [ ] 使用 Supabase CLI 启动本地 stack
- [ ] 建立版本化 migrations
- [ ] 建立虚构 `seed.sql`
- [ ] 建立数据库/RLS测试目录
- [ ] 验证 `db reset` 能从空库重建当前 schema

### Remote Development Supabase
- [ ] 建立独立 Remote Development Project
- [ ] 配置 Auth / Redirect URLs
- [ ] 配置私有 Storage 测试 bucket
- [ ] 部署必要 Edge Function Spike
- [ ] 只使用虚构数据
- [ ] 明确 Remote Development 不是 schema 的第二事实源

### 认证技术 Spike
- [ ] 验证 Windows 新邮箱邀请/首次激活
- [ ] 验证 Android 新邮箱邀请/首次激活
- [ ] 验证邀请过期/重发/取消
- [ ] 验证密码恢复
- [ ] 验证 App 已运行/未运行时 redirect/deep link
- [ ] 验证错误 redirect allowlist 的恢复体验
- [ ] 明确首位 org_admin 一次性 bootstrap
- [ ] 验证 membership disabled 后旧 Session 仍被 RLS 拒绝
- [ ] 已 confirmed Auth User 跨机构场景若 V1 不支持，必须明确提示而不是未知失败

> 如果邮件邀请/深链在 Windows 或 Android 上体验不可接受，必须在进入 Milestone 1 前调整账号方案。

### 保存可靠性 Spike
- [ ] 表单有未保存 / 保存中 / 已保存 / 保存失败状态
- [ ] 网络请求失败不清空教师输入
- [ ] 支持本地临时草稿或等价恢复机制
- [ ] 简单 insert 重试复用同一 UUID
- [ ] 多表 command 使用 operation id 或等价幂等机制
- [ ] 云端确认成功才算正式保存

### GitHub / CI
- [ ] CI：format / analyze / test
- [ ] 数据库 migration / RLS tests 进入 CI
- [ ] PR 模板覆盖 schema / RLS / 隐私 / 恢复影响
- [ ] secrets 检查
- [ ] main 后续以 PR 合并为主

### Phase 0 验收
- [ ] 新环境仅依赖仓库文档可从零启动
- [ ] Local DB 能 migrations + seed + tests 全量重建
- [ ] Windows 与 Android 都能连接 Remote Development
- [ ] 一名非技术测试用户能完成首次登录
- [ ] 未登录用户不能读取业务表
- [ ] 网络短暂失败不会丢正在编辑记录
- [ ] 仓库不含真实业务数据和私密密钥

---

## Milestone 1｜账号、邀请、机构与租户隔离

目标：两名老师使用不同账号加入同一机构；pending invitation 没有业务权限；另一机构的数据严格不可见。

### Schema / backend
- [ ] profiles
- [ ] organizations
- [ ] roles
- [ ] organization_invitations
- [ ] organization_invitation_roles
- [ ] organization_memberships
- [ ] membership_roles
- [ ] 首位管理员 bootstrap
- [ ] create / resend / cancel invitation
- [ ] accept invitation → active membership
- [ ] 停用 membership
- [ ] Session 恢复与当前机构上下文

### 权限
- [ ] pending invitation 无业务数据权限
- [ ] active membership 才进入 RLS 授权链
- [ ] RLS：跨机构隔离
- [ ] disabled membership 拒绝访问
- [ ] 已确认邮箱不错误走 new-user invite
- [ ] invitation 重发不产生重复 invitation/member

### 验收场景
1. 初始化机构 A 管理员；
2. 管理员邀请教师甲、教师乙；
3. 两人完成激活并拥有独立 active membership；
4. pending invitation 在激活前读不到学生数据；
5. 两人属于机构 A；
6. 机构 B 测试数据完全不可见；
7. 教师乙被停用后，即使持有旧 Token 也无法访问机构 A。

---

## Milestone 2｜学生统一主档案、分类与人员关系

目标：机构里“一个学生就是同一个人”，同时保证分类可统计但不增加教师高频录入负担。

- [ ] students（含 merged 语义）
- [ ] academic_terms / student_enrollments
- [ ] subjects / organization_subjects
- [ ] 少量默认 taxonomy + “其他/暂未分类”
- [ ] student_subject_profiles
- [ ] student_teacher_assignments
- [ ] active lead 责任唯一性基础约束
- [ ] student_staff_assignments
- [ ] 学生列表 / 搜索
- [ ] 新建学生时重复提示
- [ ] 查看当前与历史负责人员
- [ ] 教师交接基础流程
- [ ] 受控学生合并设计 + merge record

### 验收场景
- 教师甲和乙打开“王同学”看到同一个 `student_id`；
- 教师甲换岗后历史仍保留；
- 学管不被伪装成某门学科教师；
- “阅读理解”等高频问题能落入稳定分类口径；
- 老师仍可用自然语言表达具体问题，不必先维护知识图谱。

---

## Milestone 3｜第一条完整学情闭环

目标：先把一个案例从快速捕捉跑到确认、干预、验证、稳定和复发，不同时开发大量半成品页面。

### 数据与命令
- [ ] learning_cases
- [ ] case_events（append-only）
- [ ] case_evidence
- [ ] interventions
- [ ] assessments
- [ ] case_actions
- [ ] `new` 快速草稿
- [ ] `confirm_case`
- [ ] 状态机与状态语义
- [ ] stable / closed / reopen
- [ ] 主行动唯一性 / pause_reason
- [ ] owner / taxonomy / evidence 确认条件
- [ ] 乐观并发 expected_version
- [ ] 多表命令幂等

### 端到端验收

```text
课堂发现“阅读概括漏点”
  ↓
10–20 秒保存 new 草稿
  ↓
课后确认分类 + 最小 evidence + owner
  ↓
创建主行动“相似题训练”
  ↓
confirm_case
  ↓
记录干预
  ↓
主行动“次课验证”
  ↓
记录 assessment
  ↓
教师确认 stable
  ↓
观察后 closed
  ↓
复发 → reopen 原案例
```

### 数据一致性验收
- `new` 可以轻量，`confirmed` 必须满足正式条件；
- 一次 passed 不自动等于 stable/closed；
- 同一案例不能存在冲突的多个当前主行动；
- case_events 普通业务流程不能随意覆盖；
- 子表 organization_id 与父对象一致；
- taxonomy 与学生学科一致；
- 非法状态跳转被数据库/命令拒绝。

---

## Milestone 4｜课程与“今日”工作流

目标：让老师每天愿意打开，而不是让老师专门“填系统”。

> 本阶段不开发完整排课系统。

- [ ] lessons / lesson_students
- [ ] 从学生页快速开始课程
- [ ] “今日”聚合到期/逾期 case_actions、待验证和重点案例
- [ ] 课前遗留摘要
- [ ] 课中完成/调整行动
- [ ] 课中快速 new 草稿
- [ ] 干预 / assessment 快速记录
- [ ] `complete_lesson` 事务命令
- [ ] 30–60 秒课后完成流程
- [ ] 自动生成下一步行动草稿，由教师确认
- [ ] 网络失败草稿恢复
- [ ] 长期未整理 new 草稿提醒，不强迫课后当场全部处理

### 验收
至少 5 个虚构学生、2 位教师连续使用一周：
- 常规课后记录中位时间 ≤ 60 秒；
- 捕捉 new 问题目标 10–20 秒；
- 不维护排课表也能完成核心闭环；
- 网络失败后恢复 App 不丢正在编辑记录；
- 教师能分辨云端已保存与本地草稿；
- 完成课程不会留下半套多表状态。

---

## Milestone 5｜权限、审计、交接与查询安全加固

- [ ] 本科详细数据权限
- [ ] 跨学科有限共享
- [ ] 学生负责人/学管综合视角
- [ ] subject_lead 权限
- [ ] audit_logs
- [ ] View `security_invoker` 审计
- [ ] security definer 固定 search_path + 最小 execute
- [ ] RLS 高频过滤列索引
- [ ] teacher handoff 事务
- [ ] disable membership 最后执行且不留 orphan
- [ ] merge_students + student_merge_records
- [ ] RLS / Function 负面自动化测试

### V1 发布门槛
- [ ] 不同机构严格隔离
- [ ] “能看”和“能改”测试分离
- [ ] pending invitation 无业务权限
- [ ] Secret/service_role 不在客户端
- [ ] 教师交接不丢历史/责任项
- [ ] 关键状态变化可追溯
- [ ] 数据库可从 migrations 从空库重建
- [ ] 高风险操作不可由普通教师直接调用
- [ ] View/Function 不能成为 RLS 后门

---

## Milestone 6｜内部发行与可运维性

在“能用”之后、真实机构扩大使用之前补齐运行能力。

- [ ] Windows 安装/升级方案
- [ ] Android 签名 APK/AAB 与升级方案
- [ ] 签名密钥安全备份，不进入 GitHub
- [ ] Local / Remote Development / Production 语义明确
- [ ] Production 与开发环境完全隔离
- [ ] 崩溃/错误日志不含学生敏感正文或 Token
- [ ] 数据库备份与恢复演练
- [ ] Storage 附件单独备份/恢复策略
- [ ] 真实机构网络连通性与延迟测试
- [ ] Production migration 发布和 smoke test
- [ ] 故障时人工应急流程
- [ ] 最低支持客户端版本/兼容策略形成方案

---

# V1｜机构内部试运行

当 Milestone 0–6 达成核心发布门槛，才算 V1 内部试运行。

### V1 首发教师导航
- 今日
- 学生
- 课程
- 学情

管理员通过二级入口完成人员、邀请、权限和学生治理。

建议先使用虚构/脱敏数据完成试运行；通过安全、网络、备份与合规门槛后，再录入真实学生数据。

## V1 核心验收标准

1. 两名教师使用独立账号共同管理同一学生；
2. pending invitation 不等于机构成员；
3. 学生主档案不因学科/老师/年级重复创建；
4. new 草稿能快速捕捉，confirmed 案例结构完整；
5. 案例从证据到验证全程可追溯；
6. 未结束正式案例有主行动或明确暂停理由；
7. 教师日常记录足够快；
8. 网络失败不会丢高频输入；
9. 教师离职/交接后历史与当前责任完整；
10. 跨机构访问数据库层拒绝；
11. 普通教师不能越权修改其他学科核心结论；
12. 高权限动作不在 Flutter 直接执行；
13. migrations 可重建数据库，不依赖 Dashboard 手工状态；
14. 无真实学生信息进入 GitHub；
15. Production 数据与 Storage 都存在可验证恢复路径。

---

## V1.1｜家校与阶段输出

- [ ] guardians / student_guardians（按实际需要）
- [ ] parent_communications
- [ ] 家长反馈结构化草稿
- [ ] 周度自动摘要
- [ ] report draft / finalized snapshot
- [ ] 基础可分享阶段报告
- [ ] “家校”“报告”成为正式一级入口

目标：让已有教学事实自然生成服务输出，不增加重复录入。

---

## V1.5｜机构协作与教学洞察

- [ ] observations
- [ ] 跨学科综合观察流
- [ ] 超期行动 / 长期案例提醒
- [ ] 高频问题分析
- [ ] 分类节点轻量治理（停用/合并）
- [ ] 学科负责人视角
- [ ] 管理端教学异常

注意：管理指标用于发现教学问题，不做“教师填表量排行榜”。

---

## V2｜教研资产与 AI 副驾驶

- [ ] 自然语言转结构化案例草稿
- [ ] 相似/重复案例提示
- [ ] 阶段自动摘要
- [ ] 家长反馈辅助生成
- [ ] 同类案例与干预方案检索
- [ ] 教研资产沉淀
- [ ] AI 输出可追溯与人工确认

---

## Schema 稳定后再做｜Excel 导入

- [ ] Excel 预览
- [ ] 字段映射
- [ ] 学生查重
- [ ] 导入验证
- [ ] 导入报告
- [ ] 回滚机制

不要在数据库模型尚未稳定前，为迁就旧 Excel 结构提前固化 schema。

---

## 暂不做

- 收费排课 CRM
- 大型题库
- 成绩预测
- 人为构造学情综合分
- 家长独立 App
- 学生独立 App
- Google Docs 式协同编辑
- 复杂离线双向同步
- 多平台第三方登录大全
- 复杂多机构账号切换/自助加入
- 庞大知识图谱/分类管理后台

---

## 每个 Milestone 的完成定义

功能只有同时满足以下条件才算完成：
- 正常流程可用；
- 权限路径验证；
- 错误/空状态可理解；
- 网络失败路径可恢复；
- 核心逻辑有测试；
- schema / RLS / View / Function 变化有 migration；
- 本地数据库可从空库重建；
- RLS / GRANT 与 schema 同步；
- Remote Development 集成场景需要时已验证；
- 不引入真实隐私数据；
- 文档同步更新；
- 不破坏已有端到端验收场景。