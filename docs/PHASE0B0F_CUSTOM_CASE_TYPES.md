# Phase 0B.0-F：机构自定义问题类型

本阶段把“问题类型”做成机构级可配置项，仍处于 Supabase 虚构开发数据兼容性验证范围，不是 Production migration，也不授权导入真实学生、教师或家长资料。

## 已实现

- 四个系统基础分类继续固定存在：知识漏洞、学习习惯、考试技巧、其他。
- 机构管理员或学术管理员可以新增、重命名、归档自定义类型。
- 自定义类型必须绑定一个基础分类；它只改变分类标签，不改变 Case 的状态、Evidence、Action、Intervention、Assessment 或关闭规则。
- 新 Case 保存自定义类型 ID 与名称快照。类型重命名、归档都不会改写历史 Case 的原始名称。
- 归档类型不出现在新建问题的选择器中，也不能通过 RPC 创建新的 Case。
- 表、查询和管理命令均按机构 RLS 与 live session 约束；普通教师可以读取和使用活动类型，但不能管理机构类型。
- 开发 seed 将虚构的 Teacher A 同时设为 teacher + org_admin，用于验证设置入口；Teacher B 仍只属于另一机构。

## 验证范围

- Local cold reset：migration + fictional seed。
- SQL：表 RLS、最小权限、管理员命令、跨机构读写隔离、活动/归档状态、历史名称快照。
- Flutter：自定义类型选择会同时发送自定义类型 ID 与稳定基础分类；保存失败不清空表单。
- 未执行：本地 Flutter / Supabase CLI（当前执行环境未安装）；以 GitHub Actions 的实际结果为准。
- Remote Dev：本阶段不自动执行破坏性迁移；合并后须在确认的虚构开发项目上按顺序部署并运行安全脚本。

## 明确未做

- 类型拖拽排序、恢复归档、类型级别的自定义状态机。
- 普通教师自助修改机构配置。
- 生产 provider / region 冻结、真实数据导入和付费监控。
