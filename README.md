# 学情闭环 Xueqing

> 面向教培机构的教学协作与学生成长闭环系统

## 项目状态

**Foundation v0.3｜产品、架构、权限、数据模型、零成本云端开发与运行风险评审阶段。**

当前仓库已经完成正式开发前的核心设计收敛，但 **还不是完整可运行的 Flutter 工程**。`lib/` 仍是源码占位；下一步应正式初始化 Flutter Windows + Android、Supabase Local 和一个 Free Remote Development。

> 在安全、权限、备份、真实网络和合规门槛通过前，禁止录入真实学生、家长或教师隐私数据。

> 当前 GitHub 仓库仍是 Public。进入真实开发/机构试用前必须改为 **Private**。

## 一句话定位

**不是把 Excel 搬进软件，而是让机构把“发现问题 → 干预 → 验证 → 下一步”变成多人共享、可追溯、低负担的日常教学闭环。**

系统重点回答：
1. 学生现在最需要解决什么？
2. 老师下一步应该做什么？
3. 教学之后，有没有证据表明这个问题已经改善并稳定？

## 产品核心

### 一份连续学生主档案
同一机构内，一个学生只有一份主档案。升年级、换老师、换班、换校区都保留历史。

### 多学科学情线
每个学生按学科形成连续学情。任课教师深度访问负责学科，跨学科采用必要共享。

### 学情案例闭环

```text
发现 → 确认 → 干预 → 验证 → 稳定观察 → 关闭
```

课堂允许用 `new` 10–20 秒快速捕捉；`confirmed` 再要求正式分类、最小证据、负责人和下一步。复发 reopen 原案例。

### 下一步行动驱动
正式跟进案例通常有一个当前主行动；“今日”围绕行动和待验证组织，不依赖完整排课系统。

### 事实只记录一次
周度跟进、长期问题提示、阶段指标从原始教学事实派生，避免教师重复填写。

## V1 首发范围

教师端只保证 4 个核心入口：
- **今日**
- **学生**
- **课程**
- **学情**

家校和报告进入 V1.1。

V1 明确不做：收费排课 CRM、大型题库、学情健康分、成绩预测、家长/学生独立 App、AI 自动正式诊断、Google Docs 式协同、复杂离线多主同步、自助 SaaS 注册。

## V1 账号：零额外付费优先

V1 内部教师由管理员受控开通：

```text
org_admin
   ↓
可信服务端生成 Auth User + 随机临时密码
   ↓
membership = onboarding
   ↓
教师用临时凭据登录
   ↓
设置自己的新密码
   ↓
membership = active
   ↓
按 role + assignment 访问业务数据
```

关键思想：**能登录 Auth ≠ 有机构权限。**

- onboarding / disabled membership 都不能读取普通机构业务数据；
- 临时密码只返回一次，不写 DB/log/audit/GitHub；
- 忘记密码先由管理员核验后受控重置；
- reset 后 membership 回 onboarding，让旧 Session 也失去业务权限；
- Email OTP 在以后有可靠邮件基础设施时再升级，不让 SMTP/域名成为 V1 成本前置。

详见 [账号与权限模型](docs/AUTH_AND_PERMISSIONS.md)。

## 总体技术方向

```text
Windows / Android Flutter App
          │
          ├──── 普通授权读写 ─────► Supabase Data API
          │                           └─ PostgreSQL + RLS
          │
          └──── 受控命令 ─────────► Edge Functions / DB Functions

Supabase Auth     → Password / Session
Supabase Storage  → 私有附件
GitHub            → 源码、migration、Issue、PR、CI
```

关键技术边界：
- Flutter 只能持有 Publishable Key；
- Secret/service_role 不进入客户端或 GitHub；
- Repository / Service 隔离后端细节；
- RLS 负责“谁能访问”，事务命令负责“这样改是否合法”；
- V1 online-first，但网络失败不能丢教师输入；
- Realtime 只增强体验；
- **Git migrations 是数据库结构正式事实源**；
- Local Supabase 做 schema/RLS/tests，Remote Development 做 Auth/Storage/双设备公网集成。

## 零额外付费云端开发

当前 V1 目标是在不新增现金支出的条件下开发/试运行：

```text
ChatGPT Project + Work/Luna
        ↓
Private GitHub + Free Actions
        ↓
Supabase Local CLI
        ↓
Free Remote Development
        ↓
Free Production Pilot
```

- ChatGPT Work 是云端主控，GitHub 是代码事实源；
- 一个可验收目标通常对应一条 Work 会话 + 一个 PR；
- 真正需要运行命令/构建时用 Codex 或 GitHub Actions 提供执行证据；
- 如果 Work UI 提供 Luna + Max reasoning，Max 留给 RLS、migration、事务、并发、安全和 Milestone 终审；
- 达到方案内 Work/Codex 用量后等待重置，不购买额外 credits；
- Supabase Free 使用一个 Remote Development + 一个 Production Pilot，Local CLI 不占云项目；
- Free Production 自行定期 DB dump + Storage 备份/恢复演练。

详见 [零额外付费云端开发方案](docs/ZERO_COST_CLOUD_DEVELOPMENT.md)。

## 开源项目借鉴

不会 fork 一个大而全学校 ERP 来删功能。

重点参考：
- Flutter 官方 `flutter/samples/compass_app`：多环境、Repository/Service、测试；
- Supabase 官方 `supabase-flutter`：Local stack 与 `supabase_testing`；
- AppFlowy：真实 Flutter 跨平台、隐私与发行；
- Frappe Education / Gibbon：教育实体、历史关系、角色和长期模块化经验。

详见 [开源项目参考与借鉴边界](docs/OPEN_SOURCE_REFERENCES.md)。

## V1 验收重点

- 两位教师独立账号共同管理同一学生；
- Auth 登录与 active membership 权限严格分离；
- 学生不会因老师/学科/年级重复建档；
- `new` 捕捉足够快，`confirmed` 结构足够可靠；
- 案例从证据、干预到验证完整可追溯；
- 正式未结束案例有主行动或暂停理由；
- 常规课后记录中位时间目标 ≤ 60 秒；
- 短暂网络失败不丢输入，重试不重复创建；
- 教师交接不丢历史或当前责任；
- 跨机构访问在数据库层拒绝；
- View/Function 不成为 RLS 后门；
- 多表命令不会半成功；
- migrations 能从空库重建；
- DB + Storage 有可恢复备份；
- V1 Pilot 不自动产生额外费用。

## 项目铁律

1. 一个学生只有一份机构主档案。
2. 事实只记录一次，派生信息尽量自动计算。
3. 重要学情结论尽量有证据。
4. `new` 允许快速捕捉；`confirmed` 开始必须进入正式闭环。
5. 数据归机构，人员变化不能破坏历史。
6. Auth 登录与机构授权分离，只有 active membership 才有业务权限。
7. 权限必须在数据库/服务端执行。
8. 状态机和多表不变量不能只靠 Flutter 自觉遵守。
9. 老师少填一次，系统多自动一次。
10. 网络失败不能让高频记录凭空消失。
11. “今日”不能偷偷扩张成收费排课 CRM。
12. AI 只做副驾驶。
13. 数据库正式变化必须进入 migration。
14. 零成本不能以牺牲 RLS、测试、备份、隐私为代价。

## 文档导航

### 产品
- [产品蓝图](docs/PRODUCT.md)
- [核心用户流程](docs/USER_FLOWS.md)
- [Excel 原型到软件模型](docs/EXCEL_TO_PRODUCT.md)

### 架构与数据
- [系统架构](docs/ARCHITECTURE.md)
- [账号与权限模型](docs/AUTH_AND_PERMISSIONS.md)
- [核心数据模型](docs/DATA_MODEL.md)
- [业务命令、事务与不变量](docs/COMMANDS_AND_INVARIANTS.md)
- [架构与产品决策](docs/DECISIONS.md)

### 开发参考
- [开源项目参考](docs/OPEN_SOURCE_REFERENCES.md)
- [零额外付费云端开发](docs/ZERO_COST_CLOUD_DEVELOPMENT.md)
- [开发、数据库与发布工作流](docs/DEVELOPMENT_WORKFLOW.md)

### 安全与交付
- [安全、隐私与恢复](docs/SECURITY_AND_PRIVACY.md)
- [风险与运行要求](docs/RISKS_AND_OPERATIONS.md)
- [开发路线](docs/ROADMAP.md)
- [Agent / 开发硬约束](AGENTS.md)

## 下一步正确顺序

1. **把仓库改成 Private**；
2. 合并 Foundation v0.3；
3. 创建 ChatGPT Project：`Xueqing｜学情闭环开发`，使用可兼容 Work 的 memory；
4. 正式初始化 Flutter Windows + Android；
5. 初始化 Local Supabase CLI + migrations / seed / DB tests；
6. 建立一个 Free Remote Development（虚构数据）；
7. 做管理员开通账号 + onboarding + password reset Spike；
8. 建立 Organization / Membership / Roles / RLS；
9. 验证网络失败草稿恢复与幂等；
10. 以“两位老师共同管理一个虚构学生”为第一条端到端场景。

不要在 Phase 0 风险尚未验证时直接大规模开发页面。