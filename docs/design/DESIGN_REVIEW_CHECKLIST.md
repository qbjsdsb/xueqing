# Xueqing Design Review Checklist

状态：Phase 0A.5 self-review record

最后更新：2026-09-02

CI 证据规则：以 PR #9 最终 Head 对应的最新成功 GitHub Actions `Flutter checks` 为合并门禁，必须真实通过 `flutter pub get`、独立 lockfile consistency gate、只读 Dart format check、`flutter analyze` 与全部 widget tests；精确 Head SHA 与 run 编号记录在 PR #9 的最终独立审计记录中，避免文档提交本身让固定 run 编号立即过期。本地环境没有 Flutter/Dart，工程通过证据以正式 workflow 为准。

这份 checklist 同时是完成门槛和本阶段自审记录。发现问题必须修正事实源或 prototype；只写一份 review report 不算完成。

## 1. 产品闭环审查

状态：已完成

- [x] Today 以互斥的 overdue / today / pending verification / future / undated bucket 为工作队列，不是 dashboard。
- [x] 同一学生多项 action 有学生簇去重规则，具体 action 仍可逐条完成。
- [x] 无日期 action 明确进入 `待安排`，不会因日期筛选消失。
- [x] Student Detail 首屏以当前重点、最多三件事、当前 Cases、待验证、最近关键事实为先。
- [x] Learning Case 明确区分问题、Evidence、教师判断、Intervention、Assessment/Verification、Next Action。
- [x] Case status 与 action status 分开表达。
- [x] Assessment passed 只表示本次检查通过，不自动 stable/closed。
- [x] stable 仍显示 review/verify action；stable 不等于 closed。
- [x] Case status 严格使用 `new → confirmed → intervening → pending_verification → stable → closed`；closed 没有 pending primary action，reopen 只作为 command/event/timeline fact 保留历史连续性。
- [x] Quick Capture 只要求已知上下文 + 问题标题；完整 formalize 延后。
- [x] 研究和附件 Excel 的有用连续性已映射为 Case/Evidence/Intervention/Assessment/Action/timeline，没有复制宽表格。

审查修正记录：初稿曾把“待验证”设想为 Today 的独立高亮卡；本轮明确它是 Case 级互斥 bucket，不重复进入普通 action queue，并在 Case 页面显示确认稳定/继续跟进。这样没有改变数据模型，也避免把待验证误读为逾期。

## 2. 教师效率审查

状态：已完成

### 10–20 秒 Quick Capture

- [x] 已知学生/学科可以直接进入标题输入。
- [x] 标题是唯一必填内容；note 可选。
- [x] taxonomy、根因、owner、evidence、action、due、附件不阻塞课堂路径。
- [x] duplicate hint 非阻塞。
- [x] 保存成功/中/失败/offline/draft 都有状态和下一步。

### 30 秒课前理解

- [x] Today 首屏先显示行动语义，不先显示统计。
- [x] overdue、today due、pending verification、future、undated 有不同文字和位置。
- [x] Student Detail 首屏最多三件当前重点，历史按需展开。
- [x] 宽屏可并列但不无限拉宽；窄屏不以缩小中文来塞信息。

### 60 秒课后闭环

- [x] 从 Today 或 Student 可进入 Case，不需先穿过空的“数据看板”。
- [x] Case 当前 action 在顶部可见，证据链按语义分段。
- [x] 一次检查结果和稳定确认分开。
- [x] 保存失败不清空文本、不生成假 timeline。

审查修正记录：为了减少 Today 重复信息，将“重点 Case”改为仅在尚未被 action queue 覆盖时出现；重点不是新增指标，而是 action 的优先级和学生上下文。

## 3. Anti-AI design review

状态：已完成

逐页检查结论：

| 检查项 | Today | Student | Case | Quick Capture |
| --- | --- | --- | --- | --- |
| 渐变/蓝紫渐变 | [x] 无 | [x] 无 | [x] 无 | [x] 无 |
| 玻璃/glow/neon | [x] 无 | [x] 无 | [x] 无 | [x] 无 |
| 满屏悬浮 Card | [x] 无 | [x] 无 | [x] 无 | [x] 无 |
| 大圆角/大量阴影 | [x] 无 | [x] 无 | [x] 无 | [x] 无 |
| 彩色胶囊泛滥 | [x] 无 | [x] 无 | [x] 无 | [x] 无 |
| KPI/环形/雷达图 | [x] 无 | [x] 无 | [x] 无 | [x] 无 |
| AI 星星/魔法棒/机器人 | [x] 无 | [x] 无 | [x] 无 | [x] 无 |
| 伪风险/成长指数 | [x] 无 | [x] 无 | [x] 无 | [x] 无 |
| AI 营销式文案 | [x] 无 | [x] 无 | [x] 无 | [x] 无 |
| 无意义装饰动效 | [x] 无 | [x] 无 | [x] 无 | [x] 无 |

保留的视觉元素都有功能原因：selected indicator 表达导航位置；低饱和语义色辅助状态；divider 表达叙事分段；单层 dialog/sheet 表达当前短任务；focus ring 表达键盘位置。

## 4. 工程可实现性审查

状态：已完成

- [x] 原型只使用 Flutter SDK/Material 和现有主题/layout 基础，没有新增 UI package。
- [x] fixture 集中管理，数量最小，明显是虚构数据。
- [x] adaptive 由 `LayoutBuilder`/window size class 决定，不以 Android/Windows 平台名静默改业务语义。
- [x] Windows rail、compact rail、bottom navigation、dialog/sheet 都有轻量 Flutter 映射。
- [x] Android SafeArea、IME padding、共享 `AppSpacing.touchTarget = 48dp`、back/脏内容保护都有规格，并由 Flutter theme 实现。
- [x] Windows hover、focus、Tab、Enter/Space、Ctrl+Enter、滚轮都有规格。
- [x] 文档、theme、prototype 可独立审查，未触碰 Supabase/Auth/RLS/真实 CRUD/Realtime/AI API。
- [x] 所有修改完成后执行 format、analyze、test；若环境缺少 Android/Windows 工具链，记录为环境限制而非绕过检查。

审查修正记录：保留 Phase 0A 的 Bootstrap smoke tests，不把设计预览替换为默认启动页面；新增独立 design-preview 路由以保持工程启动证据和设计验证并存。

## 5. Accessibility gate

- [x] 文字/状态不只靠颜色；状态有文字、结构或图标冗余。
- [x] 主题默认正文 15–16px，metadata 13px；核心信息不使用极小浅灰。
- [x] focus ring 明确；只有可操作元素进入 focus。
- [x] Tab 顺序按阅读顺序，输入时全局快捷键不抢文本。
- [x] Android 关键目标按 ≥48dp 设计。
- [x] 长中文、text scale 1.3/1.5、失败/错误文案允许自然增高和滚动。
- [x] SafeArea 和键盘 inset 规则已写进 screen spec。
- [x] Case row 的导航按钮与主操作按钮是独立 focus/semantics 边界；静态 row 不伪装为父级 button。
- [ ] 真实 Windows screen reader、TalkBack 和高对比度模式：需要在 Phase 0B 真机/系统环境中补测。
- [ ] 真实键盘布局（中文输入法、Alt/Command 组合）需要在目标设备上补测。

未完成项不阻塞 foundation 文档，因为它们需要真实设备/真实权限接入；已在 `Known risks` 中交接。

## 6. State coverage gate

- [x] empty
- [x] loading
- [x] error
- [x] no permission
- [x] saving
- [x] save failed
- [x] offline
- [x] local draft
- [x] long content
- [x] many Cases
- [x] many Actions
- [x] no Cases
- [x] no due date
- [x] many overdue actions
- [x] student just created
- [x] Case closed
- [x] Case has a reopen command/event/timeline fact（不作为额外 status）

每个 state 在 `SCREEN_SPECS.md` 有 screen-level 行为，在 `UX_COPY.md` 有可见文案或说明。

## 7. Evidence and engineering log

- [x] 官方 Flutter/Windows/Android/WCAG 研究链接和结论已写入 `RESEARCH_REFERENCES.md`。
- [x] Linear、Notion、Todoist 的具体模式已写明“解决什么、借鉴什么、为何适合、什么不复制、如何映射教师场景”。
- [x] 用户提供的 Excel 原型已读；只提取连续性线索，未把它作为生产 schema 或界面模板。
- [x] 现有 `app_colors.dart`、`app_spacing.dart`、`app_theme.dart` 已按 Visual Foundation 审计后再修改，而非盲目换色。
- [x] Android 关键触控目标由 `AppSpacing.touchTarget` 单一事实源提供，theme button/icon constraints 与文档一致。
- [x] Draft PR #9 保持 Draft/open；不 push main、不自动 merge。
- [x] Phase 0B 范围明确不实现：Supabase migrations、schema、RLS、Auth、onboarding、secure session、encrypted draft 正式实现、repositories、真实 CRUD、Realtime、AI API、Report、家校。

## 8. Phase 0B handoff

下一阶段可以基于本 foundation 继续：

- 把 prototype fixture 替换为权限过滤后的真实查询结果。
- 把 Case/Action 表单接到已冻结的 command/invariant 层。
- 设计并实现 secure session、encrypted draft、online-first/reconnect 状态。
- 在真实 Windows/Android 设备上测量 10–20 秒记录、30 秒学生理解、60 秒课后闭环。
- 由真实教师做可用性审查，重点验证“现在最重要的三件事”是否可被正确说出。

本阶段明确不提前实现以上业务和安全能力；这里的 handoff 是设计接口和测试假设，不是 Phase 0B 开工许可。

## 9. Open design questions / known risks

1. 教师同时负责多个学科时，Student Detail 的学科上下文默认值需要真实使用测试；当前规则是进入来源优先，跨学科摘要不默认展开。
2. Windows 侧栏在 1024–1199px 之间是否足够宽，需要真实 Case 长文本数据复测；不能以截图判断。
3. “当前最重要的三件事”排序需要 Phase 0B 的明确产品规则；foundation 只定义展示上限，不发明排序分数。
4. Android 软键盘、中文输入法和 edge-to-edge 行为需要目标 Android 版本复测。
5. no permission 与 empty 的文案需要结合真实权限模型做隐私 review。
6. 离线草稿的加密、生命周期和正式同步语义留给 Phase 0B；prototype 不能暗示已经实现。

## 10. Independent audit remediation

状态：审计整改已完成；最终独立复审结论与精确 CI 证据以 PR #9 的 final audit record 为准。

- [x] P0：`PrototypeCaseStatus` 恢复六段 Foundation 生命周期，移除 `reopened` status。
- [x] P0：Today 使用显式 overdue/today/future/undated due bucket；pending verification 作为 Case 级互斥 bucket，并有 future fixture 与 executable widget test。
- [x] P1：确认稳定/安排下一次检查/重新打开等 Case command 不调用普通 `_completeAction`；prototype 明确提示“不改变领域状态”。
- [x] P1：AppTheme 提供浅色/深色 ColorScheme，应用根使用 `ThemeMode.system`；页面语义色统一从当前主题读取。
- [x] P1：compact Quick Capture 的学生和问题类型选择器使用 SafeArea bottom sheet；expanded/medium 保留下拉控件，选择结果与业务 ID 不变。
- [x] P1：48dp touch target 由 `AppSpacing.touchTarget` 统一提供并映射到 Flutter theme。
- [x] P1：Case row 改为静态信息容器 + 独立导航/主操作按钮，消除嵌套交互与父级 button semantics。
- [x] P1：补充生命周期、Today bucket、Student → Case → back、compact/expanded navigation 与语义边界测试。
- [x] P2：IA、Screen Specs、prototype 的 Today bucket 定义已统一。
- [x] P2：本任务书的完成 checklist 与本 checklist/最终 CI 证据关系已明确。
