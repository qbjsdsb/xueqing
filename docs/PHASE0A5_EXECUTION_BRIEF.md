# Phase 0A.5｜Xueqing UX/UI Design Foundation 执行任务书

> 本阶段不是“把 Flutter 页面做漂亮”，而是建立一套能长期指导产品、设计与实现的 UX/UI 事实源。所有设计必须服务真实教师工作流，并保持可实现、可测试、可审查。

## 0. 基线

- Foundation v0.3 已合并到 `main`。
- Phase 0A Flutter Windows + Android 工程基线已合并到 `main`，Squash commit：`65b36b30574b47adb13c63a1fc78132cac93985a`。
- Phase 0A 已验证 Flutter `3.47.1` / Dart `3.13.1`，Android debug build、Windows debug build、format/analyze/test 均有真实执行证据。
- 本阶段分支：`phase0/ux-ui-foundation`。
- 主 Issue：#6。
- UX research spike：#7。
- deliverables checklist：#8。

## 1. 设计北极星

Foundation 已定义产品北极星：

> 老师打开软件后，能否快速知道这个学生下一步做什么，并能用证据判断前一次教学是否有效？

因此设计优先级为：

1. 看懂现在；
2. 找到下一步；
3. 追溯证据；
4. 快速记录新事实；
5. 低负担完成闭环；
6. 最后才是视觉装饰。

如果一个视觉或交互设计不能提高教师理解、操作、判断效率，默认删除。

## 2. 设计气质

Xueqing 应当呈现：

- 克制；
- 安静；
- 专业；
- 可信；
- 中文友好；
- 有适度信息密度；
- 长时间使用不疲劳；
- 像真实工作工具，而不是展示型 Demo；
- 能在教育场景中提供温度，但不幼态、不卡通化。

可借鉴“编辑部 / 工具书 / 专业工作台”的信息秩序感，但不得照搬某一品牌视觉。

## 3. 明确禁止的 AI / SaaS 模板套路

除非有具体功能理由并经过设计审查，否则不要大量使用：

- 大面积渐变、蓝紫渐变；
- glassmorphism；
- glow / neon；
- 大量阴影与悬浮层；
- 满屏 Card；
- 每行内容都套圆角容器；
- 巨大圆角；
- 彩色胶囊标签泛滥；
- 无意义大数字 Dashboard；
- 环形图 / 雷达图堆砌；
- AI 星星、魔法棒、机器人作为默认图标语言；
- “智能洞察 / AI 赋能 / 成长指数 / 学习潜力”等营销式或伪精确表达；
- 为显得高级而加入的无意义动效；
- Dribbble 风格的高装饰低信息密度布局。

## 4. 设计研究要求

正式定视觉和页面结构前，先完成 Issue #7 的研究。

研究参考必须记录：

- 产品 / 规范名称；
- 具体借鉴的交互或信息组织模式；
- 为什么适合 Xueqing；
- 明确不借鉴什么；
- 如何映射到教师工作流；
- 若涉及平台规范，记录当前版本与来源。

优先：

- 实际成熟工作软件；
- Windows / Android 平台规范；
- Flutter / Material 当前规范；
- 可用性、可访问性、触控目标、键鼠效率、信息层级原则。

不要只看视觉展示站。

## 5. 核心业务事实不可被 UI 改写

设计必须服从以下 Foundation：

### Learning Case 生命周期

`new → confirmed → intervening → pending_verification → stable → closed`

`reopen` 是命令/事件，不是状态。

### Next Action 不变量

- `new` 可以没有 action；
- `confirmed / intervening / pending_verification / stable` 必须始终存在一个 pending primary action；
- 暂缓通过 `review + due_at` 表达；
- `pause_reason` 只解释；
- `closed` 不得有 pending primary action。

设计不得为了“页面简单”隐藏这个规则，也不得创造第二套 next review 日期事实源。

### V1 导航

教师主入口只有：

1. 今日
2. 学生
3. 课程
4. 学情

家校、报告属于 V1.1，不提前塞进主导航。

## 6. 必须重点解决的四个核心场景

### A. 今日 Today

目标：教师在课前约 30 秒内知道“现在该处理什么”。

必须能组织：

- 到期 / 逾期 primary actions；
- 待验证；
- 无日期待安排 action；
- 高优先级 case；
- 最近负责学生；
- 必要的 lesson 入口。

禁止退化为普通 Todo App，也不要做“大数据首页”。

设计要回答：

- 第一视觉焦点是什么；
- 逾期与待验证如何区分；
- 同一学生多个事项如何避免噪音；
- 无日期待安排如何不丢失；
- Windows 如何支持快速扫视和批量处理；
- Android 如何支持短链路处理。

### B. 学生详情 Student Detail

Foundation 要求：第一次接手学生时，不翻完整历史也能回答“现在最重要的三件事”。

首屏至少要清楚表达：

- 学生身份最小必要信息；
- 当前重点 case；
- 待验证；
- 下一 action；
- 最近关键事实 / timeline；
- 学科上下文与权限边界。

禁止做成 ERP 档案字段瀑布或多个统计卡片拼盘。

### C. Learning Case

核心表达不是大表单，而是连续闭环：

`问题 → Evidence → 判断 → Intervention → Assessment/Verification → Next Action`

设计要支持：

- 当前状态一眼可知；
- 当前 primary action 一眼可知；
- evidence 与 teacher judgment 不混淆；
- passed assessment 不误导为 automatic stable/closed；
- 历史变化可追溯，但不淹没当前工作；
- stable 时仍能看到 review action；
- reopen 有清楚历史连续性。

### D. Android 快速记录

目标：课堂中发现新问题时，10–20 秒完成 `new` 快速捕捉。

最低链路：

`已知学生/学科 → 一句问题标题 → 可选补充 → 保存`

不得强迫：

- 完整 taxonomy；
- 根因分析；
- 正式 owner；
- 上传附件；
- 下一 action；
- 大段文字。

需要设计：

- 键盘弹起后的布局；
- 单手触控；
- 触控目标；
- 返回/误触保护；
- saving / failed / local draft 状态；
- 重复 case 提示不打断快速记录；
- 课后如何进入 confirmed 整理。

## 7. Windows 与 Android 的差异化

同一设计语言，不是同一页面缩放。

### Windows 优先场景

- 查看全貌；
- 多信息并列；
- 比较；
- 编辑；
- 复盘；
- 报告前准备；
- 键盘、鼠标、快捷键效率。

### Android 优先场景

- 搜索学生；
- 快速记录；
- 处理下一步；
- 课堂中/课后短操作；
- 拍摄或选择 evidence（后续实现）；
- 单手使用与弱网络状态。

Responsive 设计必须明确哪些是共享组件，哪些是平台级布局差异。

## 8. 中文优先排版

必须实际以中文密度设计：

- 标题长度；
- 14/16px 正文可读性；
- 行高；
- 数字与中文混排；
- 状态文案长度；
- Windows 中文字体 fallback；
- Android 中文默认字体；
- 表格/列表密度；
- 不依赖英文短词才能成立的按钮宽度。

Phase 0A 当前字体 fallback 是工程占位，不代表 Phase 0A.5 已冻结最终字体策略。

## 9. Visual Foundation 必须输出

至少定义：

- surface hierarchy；
- text hierarchy；
- border hierarchy；
- accent role；
- semantic status colors；
- typography roles；
- spacing scale；
- radius scale；
- focus / hover / pressed / disabled；
- selected state；
- divider / grouping；
- touch target；
- density rules；
- light theme baseline。

Dark mode 可以记录未来兼容原则，但本阶段不是必须做成品。

状态颜色必须服务语义，不要形成“彩虹界面”。

## 10. Components 必须输出

只定义真实高频组件，禁止为设计系统完整性制造几十个空组件。

优先研究：

- App navigation；
- page header；
- search；
- student row；
- case row / case summary；
- action row；
- status marker；
- timeline / event item；
- section header；
- inline metadata；
- text field / textarea；
- select / taxonomy picker；
- date/due action controls；
- primary / secondary / destructive actions；
- empty state；
- loading；
- error；
- save status；
- offline/draft status；
- dialog / sheet；
- Android bottom sheet / quick capture shell；
- Windows side panel / split view（如果经过验证确有必要）。

## 11. UX Copy

文案必须像真实教师工具：

优先：

- 待验证
- 下次检查
- 今天到期
- 已逾期
- 待安排
- 最近记录
- 继续跟进
- 记录问题
- 保存失败
- 已保存

避免：

- 智能洞察
- 学情引擎
- 成长驱动力
- AI 建议中心
- 综合健康指数
- 赋能
- 潜能值

## 12. Accessibility / 可用性

设计必须记录：

- 文本对比度；
- 状态不能只靠颜色；
- Windows focus 可见；
- keyboard navigation 基本策略；
- Android 触控目标；
- 不用极小灰字承载关键事实；
- 长文本和系统字体缩放的容错；
- error / success 不只用色彩表达。

## 13. Flutter 实现边界

本阶段以文档、结构、规格为主。

允许极薄 prototype 来验证：

- token 可实现性；
- 中文排版；
- responsive breakpoint；
- navigation shell；
- 关键组件状态。

但禁止：

- Supabase；
- Auth；
- RLS；
- 正式 repository/service；
- 大规模业务 CRUD；
- 真实数据；
- 为截图制造复杂 fake dashboard。

若 prototype 需要 fixture，只允许少量明显虚构的演示数据，且应集中、易删除。

## 14. 设计事实源结构

Phase 0A.5 完成前至少形成：

```text
docs/design/
  DESIGN_PRINCIPLES.md
  RESEARCH_REFERENCES.md
  INFORMATION_ARCHITECTURE.md
  VISUAL_FOUNDATION.md
  RESPONSIVE_RULES.md
  COMPONENTS.md
  SCREEN_SPECS.md
  UX_COPY.md
  DESIGN_REVIEW_CHECKLIST.md
```

不要把同一个规则散落十份文档产生冲突。

## 15. Screen Specs 的最低要求

每个核心 screen / flow 至少记录：

- user goal；
- entry points；
- information priority；
- primary action；
- secondary actions；
- empty/loading/error/saving/offline states；
- Windows layout；
- Android layout；
- responsive transition；
- keyboard/touch considerations；
- permissions / privacy visibility；
- anti-patterns；
- acceptance scenarios。

必要时用 ASCII wireframe 辅助，但不能把 ASCII 草图当最终设计。

## 16. 评审方法

至少进行四轮独立自审：

### 产品闭环审查
有没有破坏 Foundation、Case / Next Action 事实模型？

### 教师效率审查
10–20 秒快速捕捉、30 秒课前、60 秒课后目标是否被界面支持？

### 去 AI 味审查
有没有为了“现代感”堆渐变、卡片、圆角、胶囊、图表、营销文案？

### 工程可实现性审查
Flutter Windows + Android 能否合理实现，是否为了设计稿引入大量复杂依赖？

## 17. 证据与研究纪律

如果引用外部产品或平台规范：

- 使用当前可信来源；
- 区分“官方平台规范 / 成熟产品模式 / 个人审美判断”；
- 不把竞品视觉直接复制；
- 不因某个设计流行就默认适合教育工作场景。

## 18. 完成条件

只有满足以下条件才可声明 Phase 0A.5 完成：

- [x] #7 研究完成并有来源记录
- [x] Design Principles 完成
- [x] IA 完成
- [x] Visual Foundation 完成
- [x] Responsive Rules 完成
- [x] Components 完成
- [x] Today spec 完成
- [x] Student Detail spec 完成
- [x] Learning Case spec 完成
- [x] Android Quick Capture spec 完成
- [x] UX Copy 完成
- [x] Accessibility 规则完成
- [x] Anti-AI-style checklist 完成
- [x] Windows / Android 差异明确
- [x] Flutter mapping 可实现
- [x] 无 Supabase / Auth / RLS 越界
- [x] 无真实学生数据
- [x] Draft PR 记录设计决策与未决问题
- [x] 独立自审完成

完成后停止，等待人工/ChatGPT 审计，不自动进入 Phase 0B。

## 19. 当前执行状态（2026-09-02）

本任务书的完成条件 checklist 已与最终设计事实源对齐；逐项审查证据和最终 CI 结果以 `docs/design/DESIGN_REVIEW_CHECKLIST.md` 与 Draft PR #9 为准，不以本文件单独替代审查记录。

当前状态：Phase 0A.5 的审计修复与自审已完成，等待下一轮独立复审。PR #9 保持 Draft/Open，Issue #6 保持 Open；本状态不授权进入 Phase 0B。

正式 CI 证据：最终 PR Head 对应 GitHub Actions [`Flutter checks` run #63](https://github.com/qbjsdsb/xueqing/actions/workflows/flutter.yml)，`flutter pub get`、lockfile consistency、只读 formatter check、`flutter analyze` 和 `flutter test` 已全部通过，以该 workflow 记录为准。

本次修复特别锁定以下事实：

- Case status 只使用 `new → confirmed → intervening → pending_verification → stable → closed`；`reopen` 只作为 command/event/timeline fact。
- Today 的 `overdue`、`today`、`future`、`undated` 与 Case 级 `pending verification` 互斥；future fixture 和 widget test 是可执行证据。
- prototype 的 Case 状态命令只展示设计预览提示，不伪造领域状态变化；Android 关键触控目标统一由 `AppSpacing.touchTarget = 48dp` 提供。
