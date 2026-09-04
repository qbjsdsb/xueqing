# 学情档案项目第二次全量独立审计报告

## 1. 审计结论

本报告针对仓库 `qbjsdsb/xueqing` 的最新审计基线重新完成了一轮独立复核。结论是：当前版本不存在已确认的“全局 RLS 被绕过”或“匿名直接读写核心业务数据”问题，但仍存在多项会影响数据完整性、权限语义、治理追溯和规模可用性的真实问题，当前不宜直接作为生产版本交付。

本轮没有修改任何业务代码、SQL 迁移、测试、CI 配置或 Excel 原文件。之后提交到 GitHub 的仅是本审计报告。

## 2. 审计范围与基线

- 仓库：`qbjsdsb/xueqing`
- 复核基线：PR #39 最新 HEAD `9be75865a16557caa2f3c586a30b2cb6400bf509`
- PR：`feat: manage teacher subject scopes`，当前仍为开放草稿，未合并
- 代码范围：以该基线的累计文件清单做全量目录、关键词、调用链和结构扫描，覆盖 189 个文件（其中 47 个 Dart、38 个 SQL、57 个 Markdown、7 个 workflow 等）；PR 最新变更文件再逐文件复核
- 重点范围：Flutter 页面与 repository、Supabase 迁移/RPC/RLS/授权辅助函数、数据模型与不变量、测试、CI/打包、时间与分页、失败重试/并发、审计追溯
- 附件：`学情档案Excel化原型_v0.1_修复版.xlsx`，以只读方式检查工作表、表格、数据验证、公式 XML 和说明文档
- 当前 CI：最新 Flutter 检查成功（run #373），最新 Supabase 检查成功（run #202）；绿色 CI 不代表下面列出的业务边界和规模问题已被覆盖

## 3. 已确认的问题

### P1 / 高优先级

#### A-01 停用教师教学范围后，新增学生流程会静默重新创建范围

证据：`supabase/migrations/20260904160000_phase_0b_0_s_teacher_subject_scope_management.sql` 的停用逻辑允许将范围置为 `ended`，且界面明确提示不会自动恢复历史关系；但 `supabase/migrations/20260904110000_phase_0b_0_n_organization_student_setup.sql` 中，`list_organization_setup_options` 仍向管理端提供全部在岗老师与活跃学科组合，`create_organization_student` 在找不到 active scope 时会自动插入新的 active `membership_subject_scopes`。

触发场景：管理员结束“老师—学科”范围后，仍可在新增学生时选择同一组合；新增流程会再次建立 active 范围。结果是显式停用被后续建档动作绕过，且与页面所声明的交接/重新启用语义冲突。该问题有明确执行路径，不是单纯文档差异。

#### A-02 没有真实学生的重复识别、提示或受控合并保护

项目文档明确要求“同一机构一个真实学生只有一份主档案”，姓名不能作为唯一键，并要求重复提示与受控 merge。但当前新增流程每次生成新的随机 `student_id`，`student_code` 也不是强制唯一；`OrganizationStudentSetupDialog` 没有已有学生搜索、重复提示或合并入口，数据库也没有能承载该业务规则的唯一身份约束。

因此，即使没有快速重复点击，只要管理员重复录入同一真实学生，就能产生多份主档案、profile、enrollment 和后续教学关系。不能用“姓名唯一”简单修复，因为项目文档已经明确姓名不是唯一键；缺口在身份解析和受控合并流程。

#### A-03 新增学生的忙碌锁设置晚于异步等待，快速重复操作可产生重复学生

`lib/features/organization_management/presentation/organization_management_page.dart` 的 `_addStudent` 在进入方法时只检查 `_busy`，随后等待快照和弹窗，但没有在第一次 await 前设置忙碌状态；`_runMutation` 直到更后面才设置 `_busy`。快速连续点击可以同时打开多个新增弹窗，各弹窗生成不同的 `operation_id`。后端按相同 operation id 幂等，不能防住不同 operation id 的相同意图，且当前没有学生身份唯一约束。

同样的 UI 时序问题也出现在 `_addTeacherScope`、`_addSubject` 的异步入口；这些操作部分由数据库唯一约束兜底，主要表现为重复错误/重复弹窗，而新增学生会造成实际重复数据。

#### A-04 `academic_admin` 的机构管理能力被最终迁移意外排除，和文档/UI 角色契约不一致

早期 `20260903100000_phase_0b_0_h_organization_leadership_and_invites.sql` 的 `can_manage_organization_v2` 包含 `academic_admin`，但最终的 `20260904010000_phase_0b_0_i_invitation_security_fix.sql` 重新定义该 helper 时只保留 `org_owner`、`org_admin`。后续学生、学科、成员、教学范围等机构管理 RPC 都复用这个 helper，因此 `academic_admin` 无法使用文档声称的相应治理能力。

同时，`learning_repository.dart`/工作台仍把 `academic_admin` 作为问题类型管理能力角色，`docs/product/ROLE_WORKFLOW_MATRIX.md` 也将其定义为具有部分教务配置和治理能力。当前没有 `academic_admin` 行为测试。这个问题不是越权，而是一个真实的角色能力回归：要么补齐后端/入口，要么同步修改角色契约、界面和邀请语义。

#### A-05 归档机构仍可能接受邀请并重新建立有效成员关系（条件性高风险）

`supabase/migrations/20260904080000_phase_0b_0_k_invitation_live_session_guard.sql` 的 `accept_organization_invitation` 校验邀请码、状态、过期时间、邮箱、会话和成员关系，但没有直接校验 `organizations.status = 'active'`。如果机构进入 archived 状态而邀请尚未撤销，接受邀请仍可能创建或恢复 active membership/role。

当前仓库没有归档 RPC，因此这是依赖未来归档入口的边界问题；一旦 archived 是可用状态，应视为发布前必须封住的状态机缺口。创建/普通管理路径已经由 active organization helper 约束，不能把该问题扩大描述为所有机构管理都能操作归档机构。

#### A-06 机构级读取普遍无分页，会被 Supabase `max_rows=1000` 静默截断

`lib/cloud/learning_repository.dart` 的 `loadWorkspace` 连续读取 subjects、profiles、students、enrollments、cases、actions、队列、证据、干预、评估、事件等集合，没有 `.range`、分页循环、总数/截断检测或可靠的统一排序；`lib/cloud/student_repository.dart` 的活跃学生读取也未分页。新机构管理 RPC（成员、邀请、学生、setup options、学科目录、教学范围）同样返回无界集合。`supabase/config.toml` 的 `max_rows` 为 1000。

当任一集合超过上限时，界面会得到不完整且可能不稳定的结果，学生数、案件数、待办和管理列表都可能静默少显示，没有错误提示。这是规模一上来就会触发的确定性行为，不是性能优化项。

## 4. 已确认的中优先级问题

#### A-07 业务锁顺序不一致，教学范围变更与案件操作可能死锁

`reschedule_case_action` 先锁 action/case，再锁 profile；确认案件、记录证据/干预/评估、稳定和关闭案件的命令则先锁 profile，再锁 learning case。并发下可以形成“事务一持有 Case 等 Profile、事务二持有 Profile 等 Case”的环路，Postgres 会回滚其中一个事务。Flutter 入口没有针对死锁的同操作重试，因此用户会看到一次失败。这个问题需要统一锁顺序或设计可重试边界。

#### A-08 学生归档/状态更新绕过正式生命周期和关系清理契约

`organization_student_edit_dialog.dart` 允许直接选择 `active`、`inactive`、`archived`；`20260904140000_phase_0b_0_q_organization_student_lifecycle.sql` 的 `update_organization_student` 只校验枚举后直接更新 students 行，没有检查开放案件/有效分配/待办，也没有同步 profile、assignment、enrollment 或生命周期事件。因而可以把仍有活动关系的学生直接设为 archived；重新 active 后旧关系会再次显现。

这与 `INSTITUTIONAL_GOVERNANCE.md`、`COMMANDS_AND_INVARIANTS.md`、`DATA_MODEL.md` 中“先解决义务和关系、归档后不自动恢复”的契约冲突。现有测试与现有代码一致地允许该行为，所以这是经二次核验的契约/功能缺口，不应误判成单纯测试遗漏。

#### A-09 高风险治理操作没有正式 domain audit log，只有缺少操作者身份的 operation receipt

当前 SQL 中能看到 `operation_receipts` 和案件范围内的 `case_events`，没有 `audit_logs` 表及对应插入。`operation_receipts` 主要记录 operation id、组织、命令、目标、结果和时间，不能完整回答谁在何时改变了成员状态、学生生命周期、学科范围、分配或交接；学生创建/更新、成员变更、学科设置、教学范围更新等路径也没有统一的 domain audit event。

项目治理文档明确要求成员/角色/范围/分配/交接、学生 profile 生命周期、归档/恢复/merge、已完成记录更正等操作可审计。当前功能虽有幂等回执，但仍缺事后追责和复盘所需的正式审计事实。

#### A-10 响应丢失后，操作重试可能因权限变化而拿不到原始结果

项目不变量要求：同一 `operation_id` 在响应丢失后重试，必须返回已提交的原结果。当前多个核心命令在 `claim_case_operation_v2`/receipt 查询前先执行 profile、成员、教学范围和其他权限检查；如果第一次已提交但响应丢失，随后权限/成员/profile 状态发生变化，重试会先失败，无法取回原 receipt。当前也没有通用的 receipt 查询入口来恢复结果。

因此副作用未必重复，但“已成功却无法可靠确认/恢复”的 exactly-once 用户契约没有闭合。

#### A-11 部分高风险 UI 操作不保留 operation id；邀请和自定义问题类型也没有一致幂等协议

`teacher_workspace_page.dart` 的关闭案件、改期行动，以及 `organization_management_page.dart` 的成员状态/教学范围停用在调用处即时生成 operation id，页面没有保留同一个 id 供响应丢失后重试。邀请创建/批准/撤销和自定义问题类型创建/重命名/归档路径没有统一 operation receipt；邀请创建响应丢失后，原邀请码也无法可靠重新取回。

这和表单类命令“草稿中提前生成并保留 operation id”的正确做法不一致，属于分散的可靠性缺口。

#### A-12 一个真实学生的多个学科 profile 会被组装成多个学生卡片

`learning_repository.dart` 的 workspace 组装按 `student_subject_profiles` 逐行创建 `WorkspaceStudent`，`_buildStudents`、今日列表和学生行没有按 root student id 合并。一个学生同时有数学和语文 profile 时，界面会重复显示姓名/卡片，人数和案件计数也按 profile 数量计算。

项目数据模型和设计文档把 Student 定义为一个根实体、多学科 profile 归属于同一学生；若产品确实要按学科显示，则需要同步修改“学生数/去重/列表”的语义，否则是已确认的 UI 与数据模型不一致。

#### A-13 当前案件区和学生计数包含 closed 案件

`teacher_workspace_page.dart` 的当前区域及学生行计数直接使用 `student.cases` 全量；只有“重要案件”辅助段落过滤了 closed。文档定义当前工作区应展示 open/current，closed 应进入历史/时间线，因此已关闭案件仍出现在当前案件数量和列表中，会误导教师当前工作量。

#### A-14 “最近/重要”排序没有使用最近性、优先级或更新时间

工作台先按学生姓名排序，今日区的“最近学生”直接取前 5 个；重要案件在数据库未保证顺序时直接取前 3 个，待办也依赖输入顺序，没有全局 due/priority 排序。用户看到的“最近/重要”可能只是字典序或数据库返回顺序，不是业务语义排序。

#### A-15 日期/时区混用可能造成选定日期偏移

工作台选择 due date 时把设备本地日期转换成 UTC noon，而服务器读模型按机构时区计算 business date。对 UTC+14 等时区，UTC noon 已经是机构次日；边界校验也部分依赖设备时钟。Quick Capture 的 observedAt 直接使用设备 `DateTime.now()`，服务器历史和复发边界可能受设备时区/时钟影响。改期路径部分使用机构 business date，但读取旧 due 时仍混用本地转换。

#### A-16 管理端 roster 对未来/已结束 enrollment 没有显式 current 标记

`list_organization_students` 在没有当前 enrollment 时会取最新的一条未来或已结束 enrollment；管理界面只展示年级、班级和校区，不展示日期或 `is_current`。未来入学或已结束关系的学生会看起来像当前在读。教师工作区的读取路径有 `is_current` 过滤，问题主要在机构管理 roster。

#### A-17 教师工作台入口登出没有网络失败时的本地 fallback

`teacher_workspace_page.dart` 入口 `_signOut` 只调用 `authRepository.signOut()`，失败后不会像 `CloudConnectionPage` 那样尝试 `signOut(global: false)`。全局登出请求网络失败时，本地 session 可能仍在，用户可能无法切换账号或退出当前设备。该问题只影响教师工作台入口，不应扩大成全应用登出都失效。

#### A-18 CI/打包流程不能证明当前范围的发布可用性

- Android/Windows 打包 workflow 只在特定旧 scope 分支 push 或手动触发，当前 PR/普通代码变更不会自动触发完整打包。
- platform smoke workflow 的 PR 触发目标只包含 `main`，堆叠 PR 不会自动获得该验证。
- 打包 workflow 执行 `flutter pub get`，但没有像主 Flutter 检查那样校验 `pubspec.lock` 无未提交变化。
- 远端安全 spike 是手动 runbook，不在 Supabase workflow 中执行；当前绿色结果主要证明本地栈测试路径。
- 当前 Android debug APK 和 Windows bundle 使用 development 环境配置/开发端点；若被当作发布物分发，会造成环境和签名风险。

这些是发布验证/工程治理缺口，不代表当前 CI 已失败。

## 5. 低优先级、条件性或体验问题

#### A-19 过期邀请仍会出现在待处理列表

`list_organization_invitations` 会把 pending 过期记录标记为 expired，但随后仍会返回未 accepted/revoked 的记录；管理界面会把过期邀请展示在待处理区域，且没有可用操作。影响主要是列表准确性和清理体验。

#### A-20 Quick Capture 同一段文本同时写入 Case 描述和 evidence summary

`teacher_workspace_page.dart` 的 Quick Capture 保存逻辑把同一输入写到 description 和 finalized evidence summary。它可能是为了同时保留叙事与证据，但会使时间线和导出内容重复；当前判定为低优先级设计/体验问题，不是数据破坏。

#### A-21 归档机构的直接元数据读取边界需要在归档状态存在时补验

`private.can_read_organization_v2` 主要判断 active membership，部分 membership/role/scope/active subject 的直接策略没有额外检查 organization status。如果机构归档时仍保留 active membership，成员可能仍能查询自己的组织元数据。当前没有归档命令，故列为条件性发布边界，不列为当前已发生的核心数据越权。

#### A-22 本地配置仍开启公开 signup

`supabase/config.toml` 的 auth signup 为 enabled；仓库文档把该配置描述为本地开发/CI 使用，同时产品约定是管理员控制入驻。若远端生产配置照搬本地配置，任意人可以创建账户，虽不自动获得机构数据访问权，但会带来账户滥用和身份污染。应在共享/生产环境单独核对，而不把本地配置直接认定为生产漏洞。

#### A-23 旧版 memberships/teacher_assignments 表和策略仍保留

早期迁移创建的旧表主要被开发回填使用，当前应用读写 canonical 表；因此没有确认当前主路径的 RLS 绕过。若生产数据同时保留旧表且仍授予旧策略，后续状态迁移可能留下旧元数据可读边界，属于上线前架构清理项。

#### A-24 少数异步初始化在 await 后未再次检查 mounted

`CloudConnectionPage` 和 `TeacherWorkspaceEntryPage` 的初始化在等待 `CloudClient.initialize` 后才设置订阅，期间页面若被销毁，可能产生未被取消的订阅。触发窗口较小，列为低优先级生命周期泄漏风险。

#### A-25 时间线同时呈现 case event 和同一操作产生的 fact

Case 命令同时写 `case_events` 与 evidence/intervention/assessment fact；界面又把两者都映射成时间线条目。一次操作可能显示两条相近记录。这不是数据库重复写入，而是历史呈现的重复，需要产品确定“事件+事实”是否都应展示。

#### A-26 改期事件没有专用展示文案

数据库写入 `action_rescheduled`，但工作台事件类型映射没有该类型，最终退化为通用“记录/记录了一条 Case 事件”。改期日期和原因在历史中不够直观。

#### A-27 Excel 说明文字声称有阶段复盘公式，但文件实际没有公式

附件 `07_阶段复盘` 的汇总单元格是静态 `0`，整个 workbook XML 没有 `<x:f>` 公式节点；`00_说明与规则` 又写有“阶段复盘公式使用绝对范围”。`docs/product/EXCEL_SOURCE_PROVENANCE.md` 已将这些指标说明为原型阶段的静态占位，因此本项判定为低优先级的原型文档一致性问题，不把“没有公式”误报成当前业务代码缺陷。其他空白行、50 行模板和数据验证属于原型设计约定。

## 6. 二次复核后明确排除的误报

- 没有确认 canonical 核心表存在广泛 RLS 绕过：身份 helper、active app user、live session、active organization/member 校验和 SECURITY DEFINER 的空 search path 均已复核；当前 CI 的 Flutter/Supabase 检查也成功。
- `can_manage_case_types_v2` 最终仍包含 `academic_admin`；角色问题仅是机构管理 helper 排除了该角色，不能扩大为所有后台能力失效。
- `CloudConnectionPage` 已有本地登出 fallback；登出问题只在教师工作台入口。
- 一个用户只能有一个 active organization membership 是文档已知的 V1 设计取舍，不作为遗漏缺陷。
- Excel 阶段复盘静态 0 是当前原型约定；真正可确认的是说明文字与实际 XML 不一致。
- 未发现需要单独报告的 TODO/FIXME 代码缺陷；迁移顺序、旧表兼容和公开 signup 均按实际环境条件保留边界说明。

## 7. 建议处理顺序（不包含本次提交的代码修改）

1. 先封住 A-01、A-02、A-03、A-04、A-06；它们分别影响权限语义、学生唯一性、重复写入、角色可用性和规模数据完整性。
2. 随后处理 A-05、A-07、A-08、A-09、A-10、A-11，补齐归档状态、锁顺序、生命周期、审计和可恢复重试契约。
3. 再处理工作台显示语义、日期/排序、roster 状态和发布流水线问题（A-12 至 A-18）。
4. 在远端归档/生产配置启用前，重新验证 A-21 至 A-23 的条件性边界。

**提交边界：本次只提交此报告文件，不包含任何项目代码或 Excel 修改。**
