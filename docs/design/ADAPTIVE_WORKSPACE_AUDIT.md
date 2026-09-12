# Xueqing Adaptive Workspace Audit

状态：implementation candidate  
日期：2026-09-13

## 目标

本轮不是重新设计导航或机构权限，而是把 V2 已经存在的多套结构断点收口到共享 `ResponsiveBreakpoints`，恢复 Personal / Organization 在 Android、平板分屏和 Windows 窄窗口中的同一套空间语法。

## 调研结论

历史 V2 在机构管理接入前只有一套清楚的宽窄布局关系；机构管理接入后，V2 `<720`、共享 `<600 / 600–1023 / >=1024`、以及 `900 / 1280` 等局部阈值逐渐叠加。最典型的问题是 650px：外层 V2 会按“手机”组织，而嵌入的机构管理会按“medium”组织，即使没有 overflow，信息密度、导航和 modal 形态也会互相冲突。

结构尺寸现在统一为：

| Window size | Shell | Student | Modal |
| --- | --- | --- | --- |
| `<600` Compact | Bottom Navigation | 单栏逐级进入 | Bottom Sheet |
| `600–1023` Medium | 72px Navigation Rail | 单栏逐级进入 | Dialog |
| `>=1024` Expanded | Navigation Rail | master-detail | Dialog |

`>=1280` 只作为 density threshold：展开 rail label，并让学生 master pane 从 288px 增至 320px。它不改变窗口类别。

## Local constraints 原则

窗口类别与嵌套内容宽度必须分开：

- Shell 和 modal/sheet 可以按完整应用窗口判断。
- rail 后的 Today / Student / Learning 等页面必须继续按剩余 pane 宽度适配。
- Organization workspace 与 Organization Learning 使用各自 `LayoutBuilder.constraints.maxWidth`，避免 600px 窗口减去 rail 后只剩约 527px，却仍被当成宽页面。
- Organization Management 本身已经使用共享 `ResponsiveLayout`，因此不再另外发明 breakpoint。

## 冻结的业务边界

本轮不修改：

- Personal / Organization 投影；
- Owner / Admin / Teacher 权限；
- Case owner、Profile Lead、Action assignee；
- Organization Quick Capture 的 active Lead / fail-closed 行为；
- Today Action bucket；
- Supabase / RLS / RPC / migration；
- Personal 主导航语义 `今日 / 学生 / 学情`。

## 验收矩阵

自动化至少覆盖：

- 599px → Compact shell + Bottom Navigation；
- 600px → Medium rail，Quick Capture 使用 Dialog；
- 800px → Medium Student 单工作面 drill-down；
- 800px manager → Organization 可从 rail 进入；
- 1024px → Expanded Student master-detail；
- source contract：V2 结构代码不再出现私有 `width < 720`；
- 历史 Desktop / Compact workspace、Organization navigation、Organization Learning tests 保持通过。

后续人工视觉复核重点是 600–1023px：Windows 窄窗口、平板横竖屏与分屏。目标不是让 Medium 看起来像缩小的 desktop，而是保留 rail 的键鼠效率，同时维持单一工作焦点。
