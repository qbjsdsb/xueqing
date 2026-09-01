# 开发路线

## 总原则

开发顺序遵循：**先证明关键风险可控，再搭底座，再做完整垂直闭环，最后扩展。**

每个阶段必须有可验证用户场景，不以页面数量衡量进度。

---

## Phase 0｜工程、OTP 认证与运行风险验证

目标：在业务开发前，证明 Windows + Android + Supabase + Email OTP 这条路线能稳定支撑机构使用，而且任何新环境都能从仓库重建开发基线。

### Flutter 工程
- [ ] 使用当前稳定 Flutter 正式初始化 Windows + Android
- [ ] feature-first + View / ViewModel / Repository / Service
- [ ] typed AppConfig 与环境切换
- [ ] 提交应用 `pubspec.lock`
- [ ] format / analyze / test 基线
- [ ] 业务代码不散落直接 Supabase 表查询

### Local Supabase
- [ ] 初始化 `supabase/`
- [ ] migrations
- [ ] 虚构 seed
- [ ] DB / RLS tests
- [ ] Mailpit 检查 Email OTP 模板
- [ ] `db reset` 能从空库重建当前 schema

### Remote Development
- [ ] 独立 Supabase Project，仅虚构数据
- [ ] Email OTP 模板使用验证码 token
- [ ] Windows 新/旧 Auth User OTP 登录
- [ ] Android 新/旧 Auth User OTP 登录
- [ ] 错误 / 过期验证码
- [ ] 请求频率限制 / 429
- [ ] Session 恢复
- [ ] 真实邮箱投递延迟
- [ ] Storage / Edge Functions / 双设备联调

### Invitation / Membership Spike
- [ ] `organization_invitations`
- [ ] invitation roles
- [ ] OTP 登录后无 membership 时无业务权限
- [ ] `accept_invitation`
- [ ] verified email 必须匹配 invitation
- [ ] 同一 invitation 重试幂等
- [ ] 同一 Auth User 第二机构 invitation 基础验证
- [ ] membership disabled 后旧 Token 仍被 RLS 拒绝

### 邮件与防滥用 Spike
- [ ] 验证 Remote Development 邮箱投递
- [ ] 评估 Production Custom SMTP / 等价邮件服务
- [ ] Auth rate limits
- [ ] CAPTCHA / 等价防滥用方案是否需要启用
- [ ] “验证码未收到”用户恢复路径

### 保存可靠性 Spike
- [ ] 未保存 / 保存中 / 已保存 / 失败状态
- [ ] 网络失败不清空输入
- [ ] 本地临时草稿
- [ ] 简单 insert 重试复用 UUID
- [ ] 多表 command operation id / 幂等

### GitHub / CI
- [ ] Flutter format / analyze / test
- [ ] DB migrations / RLS tests
- [ ] PR 模板
- [ ] secrets 检查
- [ ] main 以后以 PR 合并为主

### Phase 0 验收
- [ ] 新环境从仓库零开始可启动
- [ ] Local DB 可完整重建
- [ ] Windows / Android OTP 均可用
- [ ] Auth User 无 active membership 读不到机构数据
- [ ] pending invitation 读不到机构数据
- [ ] invitation 接受幂等
- [ ] 短暂网络失败不丢测试记录
- [ ] 仓库无真实数据与 Secret

---

## Milestone 1｜机构、成员与租户隔离

目标：两名老师用独立账号加入同一机构，另一机构的数据严格不可见。

### Schema / backend
- [ ] profiles
- [ ] organizations
- [ ] roles
- [ ] organization_invitations
- [ ] organization_invitation_roles
- [ ] organization_memberships
- [ ] membership_roles
- [ ] 首位 org_admin bootstrap
- [ ] create / cancel invitation
- [ ] accept invitation
- [ ] disable membership
- [ ] current organization context

### 权限
- [ ] Auth User 无 membership 无业务权限
- [ ] pending invitation 无业务权限
- [ ] active membership 才进入 RLS
- [ ] disabled membership 拒绝
- [ ] 跨机构隔离
- [ ] invitation verified-email 匹配

### 验收
1. 初始化机构 A 管理员；
2. 管理员预授权教师甲、乙邮箱；
3. 两人分别 OTP 登录；
4. 两人接受 invitation 并成为 active member；
5. 机构 B 数据完全不可见；
6. 停用教师乙后旧 Session 也无法访问机构 A。

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
- [ ] Auth User 无 membership 无业务权限
- [ ] pending invitation 无业务权限
- [ ] Secret 不在客户端
- [ ] 教师交接不留 orphan
- [ ] 历史可追溯
- [ ] migrations 从空库重建
- [ ] View/Function 不绕 RLS

---

## Milestone 6｜内部发行与可运维性

- [ ] Windows 安装/升级
- [ ] Android 签名 APK/AAB 与升级
- [ ] 签名密钥安全备份
- [ ] Local / Remote Development / Production 隔离
- [ ] Production Custom SMTP / 等价邮件能力
- [ ] OTP 投递与 Auth 限流监控
- [ ] 崩溃/错误日志无敏感正文/Token
- [ ] DB 备份与恢复演练
- [ ] Storage 单独恢复策略
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
1. 两位教师独立 OTP 登录并共同管理同一学生；
2. Auth 登录与机构权限分离正确；
3. pending invitation 不等于 member；
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
14. Production OTP 邮件基础设施可用；
15. DB 与 Storage 有恢复路径。

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

## V2｜教研资产与 AI 副驾驶

- [ ] 自然语言转结构化草稿
- [ ] 相似/重复案例提示
- [ ] 自动摘要
- [ ] 家长反馈辅助生成
- [ ] 同类案例/方案检索
- [ ] 教研资产沉淀
- [ ] AI 输出来源 + 人工确认

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
- 同时维护 Password / Magic Link / OTP 多套登录方式

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
- Remote Development 集成场景已验证；
- 不引入真实隐私数据；
- 文档同步；
- 不破坏既有端到端流程。