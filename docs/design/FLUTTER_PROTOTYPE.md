# Phase 0A.5 Flutter Prototype Notes

状态：thin UX validation prototype

最后更新：2026-09-02

## 1. 入口与目的

设计预览入口：`/design-preview`。Phase 0A 的默认 `/` Bootstrap 页面和 `/route-check` smoke path 保持不变；Bootstrap 页面增加一个明确的 `打开 UX/UI 设计预览` 入口。

原型只验证：

- compact / medium / expanded 三类窗口的 shell、导航和内容重排；
- 中文字体 fallback、页面层级、spacing、border、状态标记；
- Today、Student Detail、Learning Case、Quick Capture 的核心信息顺序；
- Today action 完成反馈、detail 返回关系、Quick Capture 必填/可选字段；
- Windows keyboard/hover/scroll 的组件映射和 Android SafeArea/IME/back 的结构。

## 2. 文件映射

| 文件 | 责任 |
| --- | --- |
| `lib/app/theme/app_colors.dart` | 共享 palette 和语义状态色 |
| `lib/app/theme/app_spacing.dart` | spacing/radius/border token |
| `lib/app/theme/app_theme.dart` | Material color scheme、中文 type、input/button/navigation baseline |
| `lib/app/layout/responsive.dart` | 基于可用宽度的 WindowSizeClass |
| `lib/features/design_prototype/design_fixture.dart` | 最小、集中、虚构 fixture；不接生产数据 |
| `lib/features/design_prototype/presentation/design_components.dart` | prototype 使用的真实高频 row/section/state/input 组件 |
| `lib/features/design_prototype/presentation/design_prototype_page.dart` | adaptive shell、四个导航入口、详情和 Quick Capture |
| `test/features/design_prototype_test.dart` | Case lifecycle、Today 的 overdue/today/future/undated/pending verification 互斥、Student → Case → back、compact/expanded navigation、Case 语义边界和 Quick Capture smoke test |

## 3. Fixture 边界

fixture 只包含 `示例学生甲`、`示例学生乙` 和少量虚构 Case/Action。它不包含真实姓名、联系方式、成绩、风险概率、AI 文案或可推断真实身份的信息。

完成 action 和 Quick Capture 保存只改变 prototype 内存状态或显示 SnackBar，不写数据库、不调用网络、不模拟“已同步”的正式学情。相近 Case、offline draft、权限和 save failed 的正式流程在 screen spec 中定义，生产实现留给 Phase 0B。

## 4. 重要实现选择

- `ResponsiveLayout` 使用 `LayoutBuilder` 的 width；shell 不用 `Platform.isAndroid` 决定信息结构。
- compact 使用 `NavigationBar`，medium 使用 compact `NavigationRail`，expanded 使用 expanded rail。
- Quick Capture compact 使用不可通过背景点击/拖拽关闭的 modal bottom sheet，expanded/medium 使用不可通过背景点击关闭的 dialog；脏内容由表单的 `PopScope` 保护。
- Quick Capture 使用 `SafeArea`、`MediaQuery.viewInsetsOf`、可滚动内容和动态 bottom padding 处理软键盘。
- `PopScope` 在 detail 层处理 Android back；Case detail 返回 Student Detail，Student Detail 返回来源列表。
- Student row 保留 hover、InkWell focus、Semantic label；Case row 是静态信息容器，使用独立的查看按钮和主操作按钮，避免嵌套交互；核心操作用 Material button 以获得键盘和辅助功能基础行为。

## 5. 不能从原型推断的内容

- 原型的 fixture 状态不等于领域 command/invariant 已实现。
- Case 状态严格使用六段 Foundation 生命周期；确认稳定、安排下一次检查、重新打开只展示 command 入口，不调用普通 action completion，也不模拟领域状态变化。
- prototype save 不代表 online-first、encrypted draft、reconnect、RLS 或权限检查已实现。
- prototype 的视觉字号和断点是 foundation token，不替代真实设备上的字体、键盘、TalkBack、screen reader、高对比度和窗口 resize 测试。
- demo 的 “课程”入口只验证 lesson entry 的信息位置，不是排课/收费模块。
