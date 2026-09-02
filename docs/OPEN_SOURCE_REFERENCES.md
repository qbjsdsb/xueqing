# 开源项目参考与借鉴边界

> 本文件记录 Xueqing 可以长期参考的开源项目，以及“借什么、不借什么”。目的不是 fork 一个现成学校系统，而是吸收已经被真实项目验证的工程经验。

## 1. 参考原则

开源项目只作为三类证据：

1. **官方/高质量工程模式**：目录、环境、测试、发布、依赖管理；
2. **教育领域经验**：学生、教师、角色、历史关系、模块边界；
3. **大型跨平台产品经验**：桌面/移动一致性、升级、隐私、长期维护。

不因为某项目“功能很多”就复制其产品范围。

Xueqing 的核心仍是：

> 学生连续档案 + 学情案例闭环 + 下一步行动 + 多教师权限化协作。

---

## 2. Flutter 官方 `flutter/samples` / `compass_app`

仓库：`flutter/samples`

### 值得借鉴

Flutter 官方把 `compass_app` 定位成较接近真实产品的架构样例，包含：
- 多页面和路由；
- Development / Staging 等不同运行环境；
- `config / data / domain / ui / routing / utils` 等明确边界；
- data 层继续拆成 repositories / services；
- integration tests；
- 同一应用可以替换本地数据与远程服务。

### 对 Xueqing 的落地

- 保留 View / ViewModel / Repository / Service 的职责边界；
- 环境入口必须明确，不在代码里到处 `if production`；
- Repository 可以接 fake/local fixture，测试不依赖真实 Supabase；
- 首条垂直闭环先做到可运行、可测试，再继续铺页面；
- Android / Windows 共用业务模型，但允许平台布局不同。

### 不照搬

- 不为了“Clean Architecture”制造大量空接口、DTO、UseCase；
- Domain 层只在业务规则确实复杂时加入；
- 不把目录漂亮当成完成度。

---

## 3. Supabase 官方 `supabase/supabase-flutter`

仓库：`supabase/supabase-flutter`

### 值得借鉴

官方仓库本身使用本地 Supabase stack 做集成验证，并提供 `supabase_testing` 测试工具，可 mock HTTP、JWT、Auth Session、Realtime 等。

### 对 Xueqing 的落地

- Local Supabase CLI 是数据库/RLS测试主环境；
- Flutter Repository / Service 单测优先使用 fake 或 `supabase_testing`，不让每个测试都打 Remote Development；
- Remote Development 只验证真正需要公网的 Auth、Storage、Edge Function、跨设备行为；
- 不把 Realtime 当正确性前提。

### 不照搬

官方 SDK 仓库是库工程，不是我们的产品架构模板；只借测试与 SDK 使用边界。

---

## 4. AppFlowy

仓库：`AppFlowy-IO/AppFlowy`

### 值得借鉴

AppFlowy 是真实 Flutter 跨平台桌面/移动产品，长期强调：
- 数据隐私；
- 原生体验；
- 多平台共享核心能力；
- 可扩展模块；
- 正式 release / 安装 / 升级，而不只停留在开发运行。

### 对 Xueqing 的落地

- Windows 不是“把 Android 页面拉宽”，应有更适合深度查看/批量管理的信息密度；
- Android 专注快速记录；
- 从 V1 就保留版本号、升级路径和兼容窗口；
- 数据控制与隐私优先级高于“功能看起来丰富”。

### 不照搬

- 不引入 Rust；
- 不实现复杂本地数据库/CRDT/offline-first；
- 不做 Notion 式万能工作空间；
- 不把大型开源项目的复杂度带进 V1。

---

## 5. Frappe Education

仓库：`frappe/education`

### 值得借鉴

这是成熟教育管理系统，长期处理学生、教师、招生、课程、考试、学生门户等真实教育对象。

可借鉴：
- 人员/学生不是临时页面状态，而是长期业务实体；
- 学年、课程、责任关系要保存历史；
- 教育系统需要角色化视角，而不是所有人看到同一后台；
- 自托管/生产运行必须有明确升级与维护方案。

### 对 Xueqing 的反向提醒

Frappe Education 同时包含收费、排课、招生、门户等大量 ERP 能力。

**Xueqing 不应该沿着这条路扩张。**

若未来出现：
- 收费；
- 课消；
- 招生 CRM；
- 完整排课；
- 财务；

优先与现有系统集成，而不是复制一套 ERP。

---

## 6. Gibbon

仓库：`GibbonEdu/core`

### 值得借鉴

Gibbon 是长期维护的开源学校管理平台，核心与模块/主题分离，并有持续的 developer workflow。

### 对 Xueqing 的落地

- V1 核心保持稳定，小功能不要不断侵入核心领域；
- 后续“家校、报告、教研、AI”应在核心学情事实之上扩展；
- 功能模块可以变，但学生主档案、权限、案例历史与数据不变量必须稳定；
- 长期项目要有贡献/开发规范，而不是只靠一次提示词。

### 不照搬

- 不复制大而全学校管理功能；
- 不以“模块很多”作为成熟度指标。

---

## 7. 社区 Flutter + Supabase Starter

代表：`kenxsantos/flutter-clean-supabase-starter`

### 可以参考

- feature/core/router/shared 的基本分区；
- Supabase Auth 与 Flutter 的接入方式；
- `.env` / 配置隔离意识。

### 必须谨慎

社区 starter 的目标通常是“快速跑起来”，并不自动满足：
- 多租户 RLS；
- 学生隐私；
- 事务命令；
- 审计；
- 数据恢复；
- Windows + Android 双平台机构部署。

因此社区 starter **不能成为安全/权限架构的权威来源**。冲突时优先 Flutter / Supabase 官方文档和本仓库 ADR。

---

## 8. 最终吸收进 Xueqing 的工程模式

### 保留

- 官方 Flutter 风格的职责分离；
- feature-oriented UI + Repository/Service 数据边界；
- 多环境入口；
- fake/local/remote 分层测试；
- 稳定核心 + 后续模块；
- 历史关系，不覆盖过去；
- 正式发布/升级/恢复意识；
- 隐私优先。

### 坚决不吸收

- 大而全 ERP；
- 为架构而架构；
- 微服务；
- 复杂 offline-first；
- 多套状态管理框架；
- 多套登录方式并存；
- “先接一堆 SaaS 再说”；
- 仅凭开源项目实现方式绕过本项目 RLS/不变量。

---

## 9. 给 ChatGPT Work / Codex 的使用规则

实现某个功能前，如果准备借鉴外部项目：

1. 先说明参考了哪个项目/文件/模式；
2. 说明为什么适合 Xueqing；
3. 说明有哪些部分明确不复制；
4. 优先复用思想，不大段复制代码；
5. 许可证不清楚时不直接拷贝代码；
6. 外部实现如果与 `AGENTS.md` / ADR 冲突，以本项目规则为准；
7. 新引入依赖前证明它解决了真实问题。

开源项目是经验库，不是本项目的第二产品经理。