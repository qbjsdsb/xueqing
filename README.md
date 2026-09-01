# 学情闭环 Xueqing

> 面向教培机构的教学协作与学生成长闭环系统

## 项目状态

**Foundation v0.3｜产品、架构、权限、数据模型与运行风险评审阶段。**

当前仓库已经完成正式开发前的核心设计收敛，但 **还不是完整可运行的 Flutter 工程**。`lib/` 只是源码占位；下一步应使用当前稳定 Flutter 初始化 Windows + Android，并建立 Supabase Local / Remote Development 环境。

> 在安全、权限、备份、真实网络和合规门槛通过前，禁止录入真实学生、家长或教师隐私数据。

## 一句话定位

**不是把 Excel 搬进软件，而是让机构把“发现问题 → 干预 → 验证 → 下一步”变成多人共享、可追溯、低负担的日常教学闭环。**

系统重点回答：

1. **学生现在最需要解决什么？**
2. **老师下一步应该做什么？**
3. **教学之后，有没有证据表明这个问题已经改善并稳定？**

## 产品核心

### 一份连续学生主档案
同一机构内，一个学生只存在一份主档案。升年级、换老师、换班、换校区都保留历史。

### 多学科学情线
每个学生按学科形成连续学情。任课教师深度访问负责学科，跨学科采用必要共享。

### 学情案例闭环
每个值得独立跟进的问题形成 `learning_case`：

**发现 → 确认 → 干预 → 验证 → 稳定观察 → 关闭**

课堂中允许先用 `new` 草稿 10–20 秒快速捕捉；进入 `confirmed` 后再补正式分类、最小证据、负责人和下一步。复发时 reopen 原案例。

### 下一步行动驱动
正式跟进案例通常有一个当前主行动，例如次课验证、相似题训练、重新讲解；暂不安排时必须有暂停理由。“今日”围绕这些行动组织，而不是依赖完整排课系统。

### 事实只记录一次
周度跟进、长期问题提示、阶段指标从原始教学事实派生，避免教师重复填写。

## V1 首发范围

教师端只保证 4 个核心入口：

- **今日**：到期行动、待验证、重点事项
- **学生**：连续档案、当前重点、时间线
- **课程**：快速开始和完成真实教学记录
- **学情**：案例、证据、干预、验证、下一步行动

家校和报告进入 V1.1。

V1 明确不做：收费排课 CRM、大型题库、学情健康分、成绩预测、家长/学生独立 App、AI 自动正式诊断、Google Docs 式协同、复杂离线多主同步。

## V1 账号方向

首选 **Passwordless Email OTP**：

```text
管理员预授权教师邮箱（organization_invitation）
        ↓
老师在 App 输入邮箱
        ↓
收到一次性验证码并完成 OTP 登录
        ↓
verified email 匹配 pending invitation
        ↓
创建 active organization membership
```

关键思想：**能登录 Auth ≠ 有机构权限**。没有 active membership 的账号看不到任何机构业务数据。

这样新用户、已有 Auth User、以后同一账号加入第二机构都能复用同一登录方式，不依赖 Windows/Android deep link，也不要求 V1 维护密码体系。

Production 真实使用前必须验证邮件投递、OTP 限流/防滥用，并配置可靠 Custom SMTP 或等价邮件能力；不能把 Supabase 默认 best-effort 邮件服务当作机构关键登录基础设施。

## 总体技术方向

```text
Windows / Android Flutter App
          │
          ├──── 普通授权读写 ─────► Supabase Data API
          │                           └─ PostgreSQL + RLS
          │
          └──── 受控命令 ─────────► Edge Functions / DB Functions

Supabase Auth     → Email OTP / Session
Supabase Storage  → 私有附件
GitHub            → 源码、migration、Issue、PR、CI
```

关键技术边界：
- Flutter 只能持有 Publishable Key；
- Secret/service_role 不进入客户端或 GitHub；
- Repository / Service 隔离后端细节；
- RLS 负责“谁能访问”，事务命令负责“这样改是否合法”；
- V1 online-first，但网络失败不能让教师刚填的内容丢失；
- Realtime 只增强体验，不承担正确性；
- **Git migrations 是 schema/RLS/View/Function/Trigger/Index 的正式事实源**；
- Local Supabase 用于可重复数据库开发，Remote Development 用于 OTP、Storage、双设备、公网集成测试。

## V1 验收重点

V1 按真实流程验收：

- 两位教师用独立账号看到同一个学生的权限化数据；
- pending invitation 或单纯 Auth User 没有业务数据权限；
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
- migrations 能从空库重建开发基线；
- 数据库和 Storage 都有恢复路径。

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

## 文档导航

### 产品
- [产品蓝图](docs/PRODUCT.md)
- [核心用户流程](docs/USER_FLOWS.md)
- [Excel 原型到软件模型的转换](docs/EXCEL_TO_PRODUCT.md)

### 架构与数据
- [系统架构](docs/ARCHITECTURE.md)
- [账号、邀请与权限模型](docs/AUTH_AND_PERMISSIONS.md)
- [核心数据模型](docs/DATA_MODEL.md)
- [业务命令、事务与不变量](docs/COMMANDS_AND_INVARIANTS.md)
- [架构与产品决策记录](docs/DECISIONS.md)

### 安全、开发与交付
- [安全、隐私与恢复基线](docs/SECURITY_AND_PRIVACY.md)
- [开发、数据库与发布工作流](docs/DEVELOPMENT_WORKFLOW.md)
- [风险清单与运行要求](docs/RISKS_AND_OPERATIONS.md)
- [开发路线](docs/ROADMAP.md)
- [Codex / 开发约束](AGENTS.md)

## 下一步正确顺序

1. 把 GitHub 仓库设为 **Private**；
2. 正式初始化 Flutter Windows + Android；
3. 初始化 Local Supabase CLI + migrations / seed / DB tests；
4. 建立独立 Remote Development（虚构数据）；
5. 做 Windows + Android Email OTP Spike：新/旧账号、验证码错误/过期、Session 恢复、邮件投递；
6. 建立 invitation → active membership 的最小受控流程；
7. 建立 Organization / Roles / RLS，并从空库重建验证；
8. 验证网络失败草稿恢复与幂等重试；
9. 以“两位老师共同管理一个虚构学生”为第一条端到端场景；
10. 再进入学生、学情案例、课程和今日工作台。

不要在 Phase 0 风险尚未验证时直接大规模开发页面。