# 开发路线

## 总原则

开发顺序遵循：**先证明关键风险可控，再搭底座，再做完整垂直闭环，最后扩展。**

每个阶段必须有可验证用户场景，不以页面数量衡量进度。

本阶段新增硬约束：**V1 内部试运行不额外购买服务器、数据库套餐、SMTP、域名、短信、AI API、CI 或 Work/Codex credits。**

---

## Phase 0｜工程、零成本认证与运行风险验证

目标：证明 Windows + Android + Supabase + 管理员受控开通账号这条路线能稳定支撑机构使用，而且任何新环境都能从仓库重建开发基线。

### 0A. GitHub / ChatGPT 云端开发底座
- [ ] 仓库改为 Private
- [ ] 建立 ChatGPT Project：`Xueqing｜学情闭环开发`
- [ ] Project 使用可兼容 Work 的 memory 配置
- [ ] 连接 GitHub，仓库作为代码事实源
- [ ] Work 会话按一个目标/一个 PR 拆分
- [ ] Luna Max 只优先用于权限、migration、事务、安全和 Milestone 终审
- [ ] 不购买额外 Work/Codex credits，达到包含额度后等待重置
- [ ] GitHub Actions 设置零超额成本边界

### 0B. Flutter 工程
- [ ] 使用当前 stable Flutter 正式初始化 Windows + Android
- [ ] feature-oriented UI + View / ViewModel / Repository / Service
- [ ] typed AppConfig 与环境切换
- [ ] 提交应用 `pubspec.lock`
- [ ] format / analyze / test 基线
- [ ] 业务代码不散落直接 Supabase 表查询
- [ ] 参考 Flutter 官方 `compass_app` 的多环境、repository/service 与集成测试模式

### 0C. Local Supabase
- [ ] 初始化 `supabase/`
- [ ] migrations
- [ ] 虚构 seed
- [ ] DB / RLS tests
- [ ] `db reset` 能从空库重建当前 schema
- [ ] 评估 `supabase_testing` 用于 Flutter Service/Repository 测试

### 0D. Remote Development
- [ ] 建立一个 Supabase Free Remote Development，仅虚构数据
- [ ] 验证 Windows/Android 登录、Session 恢复
- [ ] 验证 Storage / Edge Functions / 双设备联调
- [ ] 记录 Free Tier 使用量基线
- [ ] 不把 Remote Dashboard 变成 schema 第二事实源

### 0E. 零成本账号开通 Spike
- [ ] `profiles`
- [ ] `organizations`
- [ ] `organization_memberships(status = onboarding/active/disabled)`
- [ ] `membership_roles`
- [ ] `provision_member`
- [ ] Auth Admin `createUser` + 随机高强度临时密码
- [ ] 临时密码不写 DB/log/audit
- [ ] onboarding 时普通业务 RLS 全部拒绝
- [ ] `complete_member_onboarding`
- [ ] 设置新密码成功后 membership → active
- [ ] `reset_member_credential`
- [ ] reset 后 membership → onboarding，旧 Session 也失去业务权限
- [ ] disabled membership 旧 Session 仍被 RLS 拒绝

### 0F. 保存可靠性 Spike
- [ ] 未保存 / 保存中 / 已保存 / 失败状态
- [ ] 网络失败不清空输入
- [ ] 本地临时草稿
- [ ] 简单 insert 重试复用 UUID
- [ ] 多表 command operation id / 幂等

### 0G. GitHub / CI
- [ ] PR：Flutter format / analyze / unit tests
- [ ] DB migrations / RLS tests
- [ ] secrets 检查
- [ ] 不在每个 commit 跑 Windows/Android release build
- [ ] Milestone/Release 再跑重构建
- [ ] artifact retention 保持精简
- [ ] main 以后以 PR 合并为主

### Phase 0 验收
- [ ] 新环境从仓库零开始可启动
- [ ] Local DB 可完整重建
- [ ] Windows / Android 密码登录可用
- [ ] onboarding Auth User 读不到学生业务数据
- [ ] active membership 才能进入业务 RLS
- [ ] 管理员重置凭据后旧 Session 失去业务权限
- [ ] 短暂网络失败不丢测试记录
- [ ] 仓库无真实数据与 Secret
- [ ] 整条 Phase 0 没有新增现金支出

---

## Milestone 1｜机构、成员与租户隔离

目标：两名老师用独立账号属于同一机构，另一机构的数据严格不可见。

### Schema / backend
- [ ] profiles
- [ ] organizations
- [ ] roles
- [ ] organization_memberships
- [ ] membership_roles
- [ ] 首位 org_admin bootstrap
- [ ] provision member
- [ ] complete onboarding
- [ ] reset credential
- [ ] disable membership
- [ ] current organization context

### 权限
- [ ] Auth User 无 membership 无业务权限
- [ ] onboarding membership 无业务权限
- [ ] active membership 才进入普通业务 RLS
- [ ] disabled membership 拒绝
- [ ] 跨机构隔离
- [ ] provision/reset/admin command 普通教师不能调用

### 验收
1. 初始化机构 A 管理员；
2. 管理员受控开通教师甲、乙；
3. 两人分别用临时凭据登录并完成密码接管；
4. 两人成为 active member；
5. 机构 B 数据完全不可见；
6. 重置或停用教师乙后，其旧 Session 也无法访问机构 A 业务数据。

---

## Milestone 2｜学生统一主档案、分类与人员关系

目标：机构里一个真实学生只有一个主档案，同时分类可统计但不拖慢录入。

- [ ] students（含 merged）
- [ ] academic_terms / student_enrollments
- [ ] subjects / organization_subjects
- [ ] 少量默认 taxonomy + “其他/暂未分类”
- [ ] student_subject_profiles
- [ ] student_teacher_assignments
- [ ] active lead 唯一性基础约束
- [ ] student_staff_assignments
- [ ] 学生列表 / 搜索
- [ ] 新建学生重复提示
- [ ] 当前/历史负责人
- [ ] 教师交接基础流程
- [ ] 学生合并设计 + merge record

### 验收
- 两名老师看到同一个 student_id；
- 换老师/升年级历史不丢；
- 学管不伪装成学科教师；
- 分类可统计；
- 老师仍能自由表达具体问题。

---

## Milestone 3｜第一条完整学情闭环

目标：从快速捕捉跑到确认、干预、验证、稳定和复发。

- [ ] learning_cases
- [ ] case_events append-only
- [ ] case_evidence
- [ ] interventions
- [ ] assessments
- [ ] case_actions
- [ ] `new` 快速草稿
- [ ] `confirm_case`
- [ ] 状态机
- [ ] stable / closed / reopen
- [ ] 主行动唯一性 / pause_reason
- [ ] owner / taxonomy / evidence 确认条件
- [ ] expected_version
- [ ] command 幂等

### 端到端

```text
课堂发现问题
  ↓
10–20 秒 new 草稿
  ↓
课后补分类 + evidence + owner + 主行动
  ↓
confirm_case
  ↓
干预
  ↓
次课验证
  ↓
assessment
  ↓
教师确认 stable
  ↓
观察后 closed
  ↓
复发 reopen 原案例
```

### 数据一致性验收
- new 可轻量，confirmed 结构完整；
- passed 不自动 stable/closed；
- 主行动不冲突；
- case_events 不覆盖；
- 子表机构一致；
- taxonomy 与学科一致；
- 非法状态跳转拒绝。

---

## Milestone 4｜课程与“今日”

目标：老师每天愿意打开，不专门“填系统”。

> 不开发完整排课系统。

- [ ] lessons / lesson_students
- [ ] 从学生页快速开始课程
- [ ] 今日聚合到期/逾期 actions、待验证、重点案例
- [ ] 课前遗留摘要
- [ ] 课中 actions / intervention / assessment
- [ ] 课中快速 new 草稿
- [ ] complete_lesson 事务命令
- [ ] 30–60 秒课后流程
- [ ] 下一步行动草稿 + 教师确认
- [ ] 网络失败草稿恢复
- [ ] 长期未整理 new 草稿提醒

### 验收
5 个虚构学生、2 位教师连续使用一周：
- 捕捉 new 目标 10–20 秒；
- 常规课后中位时间 ≤ 60 秒；
- 无排课表也能完成闭环；
- 断网恢复不丢内容；
- 云端/本地草稿状态清楚；
- complete_lesson 不半成功。

---

## Milestone 5｜权限、审计、交接与治理加固

- [ ] 本科详细权限
- [ ] 跨学科有限共享
- [ ] 学生负责人综合视角
- [ ] subject_lead
- [ ] audit_logs
- [ ] credential operations 不记录密码
- [ ] View security_invoker 审计
- [ ] security definer 最小授权
- [ ] RLS 索引
- [ ] handoff 事务
- [ ] disable membership 最后执行
- [ ] merge_students + merge records
- [ ] RLS / Function 负面自动化测试

### 发布门槛
- [ ] 跨机构严格隔离
- [ ] read/write 权限分离
- [ ] Auth User / onboarding member 无业务权限
- [ ] Secret 不在客户端
- [ ] 教师交接不留 orphan
- [ ] 历史可追溯
- [ ] migrations 从空库重建
- [ ] View/Function 不绕 RLS

---

## Milestone 6｜内部发行、备份与免费额度运行

- [ ] Windows 安装/升级
- [ ] Android 签名 APK/AAB 与升级
- [ ] 签名密钥安全备份
- [ ] Local / Remote Development / Production 隔离
- [ ] 一个 Free Remote Development + 一个 Free Production Pilot
- [ ] 监控 DB / Storage / Egress / Actions 免费额度
- [ ] 崩溃/错误日志无敏感正文/Token/密码
- [ ] Free Production 定期 `db dump` / `pg_dump`
- [ ] DB 恢复演练
- [ ] Storage 单独备份/恢复
- [ ] Free project inactivity/pause 应对流程
- [ ] 真实机构网络测试
- [ ] Production migration + smoke test
- [ ] 故障应急流程
- [ ] 最低支持客户端版本策略

---

# V1｜机构内部试运行

Milestone 0–6 核心门槛达成后才进入真实机构内部试运行。

### 教师导航
- 今日
- 学生
- 课程
- 学情

### V1 核心验收
1. 两位教师独立账号共同管理同一学生；
2. Auth 登录与机构权限分离正确；
3. onboarding/disabled 不等于 active；
4. 学生不因学科/教师/年级重复；
5. new 快速、confirmed 可靠；
6. 学情从证据到验证可追溯；
7. 正式未结束案例有主行动或暂停理由；
8. 教师记录足够快；
9. 网络失败不丢高频输入；
10. 教师交接历史和当前责任完整；
11. 跨机构拒绝；
12. 普通教师无法越权修改其他学科；
13. migrations 可重建，不依赖 Dashboard；
14. DB 与 Storage 有可验证的免费备份/恢复路径；
15. 试运行没有自动产生额外费用。

---

## V1.1｜家校与阶段输出

- [ ] guardians / student_guardians
- [ ] parent_communications
- [ ] 家长反馈结构化草稿
- [ ] 周度自动摘要
- [ ] report draft / finalized snapshot
- [ ] 基础可分享报告
- [ ] 家校 / 报告成为一级入口

---

## V1.5｜机构协作与教学洞察

- [ ] observations
- [ ] 跨学科综合观察
- [ ] 超期行动 / 长期案例提醒
- [ ] 高频问题分析
- [ ] taxonomy 轻量治理
- [ ] 学科负责人视角
- [ ] 管理端教学异常

不做“教师填表量排行榜”。

---

## V2｜教研资产、AI 与可选现代认证

- [ ] 自然语言转结构化草稿
- [ ] 相似/重复案例提示
- [ ] 自动摘要
- [ ] 家长反馈辅助生成
- [ ] 同类案例/方案检索
- [ ] 教研资产沉淀
- [ ] AI 输出来源 + 人工确认
- [ ] 如果已有可靠邮件基础设施，再评估 Email OTP / self-service invitation

---

## Schema 稳定后｜Excel 导入

- [ ] Excel 预览
- [ ] 字段映射
- [ ] 学生查重
- [ ] 导入验证
- [ ] 导入报告
- [ ] 回滚机制

---

## 暂不做

- 收费排课 CRM
- 大型题库
- 成绩预测 / 学情综合分
- 家长/学生独立 App
- Google Docs 式协同
- 复杂离线双向同步
- 多平台第三方登录大全
- 庞大知识图谱
- Email OTP / Magic Link / SSO 多套登录同时维护
- 需要新增现金支出的第三方 SaaS

---

## 每个 Milestone 的完成定义

同时满足：
- 正常流程可用；
- 错误/空状态可理解；
- 权限负面路径验证；
- 网络失败可恢复；
- 核心逻辑有测试；
- schema/RLS/View/Function/Trigger/Index 变化有 migration；
- Local DB 可从空库重建；
- 必要 Remote Development 集成场景已验证；
- 不引入真实隐私数据；
- 不引入未经 ADR 批准的付费硬依赖；
- 文档同步；
- 不破坏既有端到端流程。