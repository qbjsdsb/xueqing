# Xueqing V0.3.8 角色权限合同

本文件冻结当前三角色权限边界，避免后续 UI、RLS、RPC 或测试再次产生不同理解。

> 责任语义同时受 ADR-047 与 `docs/RESPONSIBILITY_MODEL.md` 约束：**机构访问/监督、实际操作者、教学责任不是同一件事。**

## 角色组合原则

小型教育机构里，管理身份与一线教学不是互斥关系。负责人和管理员可以同时承担教学工作，不需要为了“能教课”再创建另一套账号。

实现上，负责人/管理员可以拥有机构级学情监督能力，但这**不会自动生成任何可教学科、任课关系、Case owner 或学生责任**。要成为某门课的实际责任老师，仍必须明确配置有效 teaching scope，并建立对应 Student Teacher Assignment。普通老师的访问隔离规则不变。

## 负责人 `org_owner`

负责人拥有机构治理和机构级学情监督能力：

- 在 **Organization Projection** 查看并监督全机构学生、学情与 Learning Case；
- 在监督 policy 允许时推进已有 Case，同时保留原 Case owner / Action assignee，审计记录负责人本人为真实 actor；
- 管理学生、学科、任课范围和学生任课分配；
- 可以像其他教学人员一样配置自己的可教学科并承担具体学生任课；
- 查看成员与邀请；
- 创建、审批、撤销、重新发放成员邀请；
- 邀请 `teacher`、`org_admin`、`org_owner`；
- 停用/恢复成员，以及执行受控账号凭据重发等成员账号生命周期操作。

如果负责人本人存在合法当前 Assignment，则其 **Personal Projection** 只显示本人真实负责的 Today / Students / Lessons / Learning，不因负责人身份混入全机构数据。

## 管理员 `org_admin`

管理员拥有机构业务与学情监督能力，但**不拥有成员账号生命周期写权限**：

- 在 **Organization Projection** 查看并监督全机构学生、学情与 Learning Case；
- 在监督 policy 允许时推进已有 Case，同时保留原 Case owner / Action assignee，审计记录管理员本人为真实 actor；
- 管理学生、学科、任课范围和学生任课分配；
- 可以像其他教学人员一样配置自己的可教学科并承担具体学生任课；
- 可以查看成员和邀请状态，并维护成员的日常显示姓名；
- 不能创建任何角色的成员邀请；
- 不能审批、撤销或重新发放邀请；
- 不能停用/恢复成员；
- 不能重发其他成员账号凭据或执行其他负责人专属成员账号生命周期命令。

这里以最终 migration 链中的 `can_manage_member_accounts_v2` 与 owner/admin access contract tests 为准；较早 migration 曾允许管理员发起部分邀请，但已被后续安全边界收紧，不再是当前运行时事实。

如果管理员本人存在合法当前 Assignment，则其 **Personal Projection** 同样只显示自己的 Today / Students / Lessons / Learning。

成员显示姓名只是协作资料，不改变角色、登录凭据或机构成员资格，因此负责人和管理员都可维护。

## 老师 `teacher`

老师的学生与学情访问继续由有效任课关系和教学学科范围共同约束：

- Personal Projection 只能访问自己当前合法任课范围内的学生与学情；
- Today 只包含 `assigned_membership_id` 指向当前成员的 pending primary Action；
- Lessons 继续按合法任课关系与 Teaching Fact Gate 工作；
- 任课关系或教学范围结束后，相关个人教学访问与写权限必须立即失效；
- 不因普通教师身份获得机构级读取能力。

## 新 Case 的责任规则

### Personal Projection

普通老师或同时任课的管理者从个人工作区 Quick Capture：

- 当前成员必须通过完整 Teaching Fact Gate；
- 当前成员才可成为该次新 Case 的 Responsible Teacher。

### Organization Projection

负责人/管理员从机构视角发起新 Case：

- 管理身份只提供机构监督/命令资格；
- server 必须把教学责任解析到目标 Profile 的合法 active teaching assignment；
- 默认 Responsible Teacher 为 active Lead；
- 没有 active Lead 时 fail closed，先明确主责老师；
- 管理者本人只有在确实是该 Profile 的合法任课老师时才能成为 owner。

因此，“Admin-only 不能仅凭管理身份成为 teaching Case owner”与“管理员可以在机构视角为合法责任老师发起新 Case”必须同时成立。

## 导航与 Scope

责任模型不删除既有 V1 教师入口。存在个人教学责任时，Personal Projection 的产品入口仍为：

```text
今日 / 学生 / 课程 / 学情
```

同时具有机构监督能力的负责人/管理员再增加“机构”入口；如果管理者没有任何当前个人任课责任，可以直接进入机构工作区，而不是展示一组无意义的空 Personal 页面。

## 不可突破的边界

- 任何角色都不能跨机构访问数据；
- 已停用成员和失效会话必须 fail closed；
- UI 隐藏或禁用按钮只是体验层，数据库 RLS 和受保护 RPC 才是最终安全边界；
- 负责人/管理员的机构级学情权限不能破坏老师原有的 Personal Projection 任课隔离；
- 管理身份本身不能偷偷创建学科范围、任课关系、Case owner 或学生责任；
- 监督已有 Case 不得静默接管原 owner / assignee；
- 新责任人必须由 server 重新验证当前 Assignment、scope、Profile 与业务日期；
- 只有 `org_owner` 可执行成员账号生命周期写命令；
- 测试必须同时覆盖正向权限和拒绝路径。
