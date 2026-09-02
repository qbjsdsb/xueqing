# Phase 0A.5｜Design Research References

> 本文件记录设计参考的来源、借鉴点和明确不借鉴点。参考是证据，不是视觉模板。后续研究继续追加，但不得把竞品视觉直接复制到 Xueqing。

## 1. Flutter｜Adaptive and responsive design

Source: https://docs.flutter.dev/ui/adaptive-responsive

官方区分：
- responsive：UI 能适配当前可用空间；
- adaptive：UI 在当前空间与输入方式下真正好用。

### 对 Xueqing 的意义

Windows 与 Android 不能只是同一页面按比例缩放。需要共享业务语义与核心组件，同时根据 window size、输入方式和任务特点选择布局。

### 借鉴
- 按可用 window size 设计；
- 同时考虑 mouse / keyboard / touch；
- responsive 与 adaptive 都要做。

### 不借鉴
- 不因为 Flutter 支持统一代码，就强迫两个平台完全相同。

---

## 2. Flutter｜Best practices for adaptive design

Source: https://docs.flutter.dev/ui/adaptive-responsive/best-practices

官方建议包括：
- 设计到不同 form factor 的优势；
- touch-first 后再增强 mouse/keyboard；
- 不用硬件类型判断布局；
- 不把大屏横向空间全部塞满；
- 支持多种输入方式。

### 对 Xueqing 的意义

- Android quick capture 要优先把触控链路做短；
- Windows 再增加 hover、keyboard、快捷操作和更高信息密度；
- Desktop 宽屏不等于内容区无限拉宽；
- breakpoint 应基于可用宽度而不是 `Platform.isAndroid` 直接决定所有布局。

---

## 3. Flutter｜General approach to adaptive apps

Source: https://docs.flutter.dev/ui/adaptive-responsive/general

官方方法：Abstract → Measure → Branch。

### 对 Xueqing 的意义

共享：
- navigation destinations；
- Student/Case/Action 的核心内容模型；
- component data contract。

根据可用空间选择：
- bottom navigation / side navigation；
- 单栏 / 双栏 / split view；
- dialog / sheet / inline panel。

### 设计要求

Phase 0A.5 的 responsive spec 必须先描述“共享什么”，再描述“在哪些宽度下改变布局”，不要写成两套完全独立产品。

---

## 4. Flutter｜User input & accessibility

Source: https://docs.flutter.dev/ui/adaptive-responsive/input

官方强调 adaptive app 还需要处理：
- mouse；
- keyboard；
- scroll wheel；
- hover；
- tab traversal；
- keyboard shortcuts；
- assistive technologies。

### 对 Xueqing 的意义

Windows 设计规格不能只画静态截图。核心交互至少要说明：
- focus；
- tab order；
- hover；
- keyboard activation；
- 长列表滚动；
- 快捷键是否值得引入。

---

## 5. Windows｜Navigation design basics

Source: https://learn.microsoft.com/en-us/windows/apps/design/basics/navigation-basics

Microsoft 的核心导航原则：
- consistency；
- simplicity；
- clarity。

### 对 Xueqing 的意义

V1 只有 Today / Students / Lessons / Cases 四个主入口，本身就是优势。

不要为了“大而全”加入：
- dashboard；
- settings as primary destination；
- reports；
- parent communication；
- AI center；
- data center。

这些不应挤占 V1 主导航。

---

## 6. Windows｜Focus navigation

Source: https://learn.microsoft.com/en-us/windows/apps/develop/input/focus-navigation

Windows 官方强调 keyboard focus 是 power users 与 accessibility 的正式交互机制，并要求 logical focus order 与文化阅读顺序一致。

### 对 Xueqing 的意义

Windows spec 至少需要：
- 可见 focus ring；
- logical Tab 顺序；
- 只有可交互元素进入 focus；
- 复杂区域需要明确方向键 / Tab 行为；
- 不因自定义视觉破坏键盘操作。

---

## 7. Windows｜NavigationView patterns

Source: https://learn.microsoft.com/en-us/windows/apps/design/controls/navigationview

### 可借鉴
- 左侧主导航是 Windows 宽屏下合理的候选；
- navigation item 需要清楚 label；
- keyboard navigation 要成立；
- compact / expanded behavior 需要根据空间设计。

### 不直接照搬

Flutter app 不需要复刻 WinUI 控件像素级视觉；借交互和空间模式即可。

---

## 8. Xueqing 自有产品事实源

优先级高于所有外部参考：

- `docs/PRODUCT.md`
- `docs/USER_FLOWS.md`
- `docs/COMMANDS_AND_INVARIANTS.md`
- `docs/AUTH_AND_PERMISSIONS.md`
- `docs/SECURITY_AND_PRIVACY.md`
- `docs/PHASE0A5_EXECUTION_BRIEF.md`
- `docs/design/DESIGN_PRINCIPLES.md`

外部设计模式如果与 Xueqing Foundation 冲突，以 Foundation 为准；若确实需要改变 Foundation，必须先新增 ADR，不得在设计稿中静默绕过。

---

# 后续研究要求

后续可以研究成熟产品的信息组织与工作流，例如专业知识工作、任务、记录、时间线、医疗/CRM/教育内部工具等，但必须逐条记录：

1. source；
2. observed pattern；
3. why it helps Xueqing；
4. what not to copy；
5. target screen/flow；
6. confidence / caveat。

Dribbble / Behance / Pinterest 等视觉展示只能作为低权重灵感，不得成为关键 UX 决策的唯一证据。