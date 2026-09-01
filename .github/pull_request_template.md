## 变更目的

<!-- 这个 PR 解决什么真实用户/工程问题？不要只写“新增某页面”。 -->

## 影响的用户流程

<!-- 对应 docs/USER_FLOWS.md 的 Flow；如果新增流程，先说明为什么需要。 -->

## 变更范围

- [ ] Flutter / UI
- [ ] Repository / Service / ViewModel
- [ ] 数据库 schema / migration
- [ ] RLS / GRANT / View / Function / Trigger
- [ ] Auth / membership / credential / 权限
- [ ] Storage
- [ ] 本地草稿 / 幂等 / 并发
- [ ] 发布 / 运维 / 备份
- [ ] GitHub Actions / 云端开发
- [ ] 文档
- [ ] 其他

## 产品边界检查

- [ ] 没有把 V1 悄悄扩张成排课收费 CRM
- [ ] 没有创建第二份重复事实源
- [ ] 没有为了“完整”把家校/报告提前塞进 V1 主导航
- [ ] 高频教师路径没有增加不必要填写
- [ ] `new` 快速捕捉仍然足够轻
- [ ] 没有用一次 assessment passed 自动关闭案例
- [ ] 未结束正式案例仍有主行动或 pause reason
- [ ] 分类治理没有演变成庞大知识图谱/必填层级

## 数据模型与不变量

- [ ] 新字段/表有明确事实语义，不只是为了某个页面方便
- [ ] 姓名/自由文本没有被当作唯一标识
- [ ] 历史关系没有被“覆盖当前值”替代
- [ ] 核心 FK 删除行为已明确，不会意外 cascade 掉历史
- [ ] 子表与父表不会跨 organization 错配
- [ ] taxonomy / subject / student profile 关系一致
- [ ] 状态机和多表不变量不只靠 Flutter 校验
- [ ] 不变量敏感写入使用受控命令/事务

## Auth 与权限

- [ ] Auth User 无 active membership 时没有普通机构业务权限
- [ ] onboarding / disabled membership 均被普通业务 RLS 拒绝
- [ ] active membership 才进入正式授权链
- [ ] 没有把 user_metadata 当作 RLS 权限事实源
- [ ] RLS 与最小 GRANT 已同步考虑
- [ ] 跨机构 / 跨学生 / 跨学科负面权限已测试或说明
- [ ] View 不会绕过底层 RLS
- [ ] security definer Function 固定 search_path 且最小授权
- [ ] 高权限 Auth Admin / Secret 不进入 Flutter
- [ ] provision / onboarding / reset / disable 等流程可安全重试
- [ ] 临时/正式密码没有进入 DB、log、audit、fixture 或 PR 内容

## 数据库与 Migration

- [ ] schema / RLS / View / Function / Trigger / Index 变化有版本化 migration
- [ ] 没有只改 Remote Dashboard 而漏掉 migration
- [ ] Local `db reset` 能从 migrations + 虚构 seed 重建
- [ ] 数据库/RLS tests 通过
- [ ] destructive 变化有迁移/恢复方案
- [ ] 若会影响旧客户端，已考虑 expand → migrate → contract 或兼容窗口

## 隐私与密钥

- [ ] 没有引入真实学生/家长/教师隐私数据
- [ ] 测试、seed、截图均为明显虚构数据
- [ ] 没有提交 Secret / service_role / 数据库密码 / 私密 API Key
- [ ] 日志/审计没有复制不必要的敏感正文
- [ ] 新自由文本字段有明确教学用途

## 零额外付费检查

- [ ] 没有新增需要额外付费的 SMTP / 域名 / SMS / AI API / SaaS
- [ ] 没有要求 Supabase Pro/add-on 才能完成 V1
- [ ] 没有使用 GitHub Actions larger runner
- [ ] CI / artifact 策略不会无意义消耗免费额度
- [ ] 若引入任何外部服务，已说明免费层、上限、超额行为和迁出方案
- [ ] 如确实需要新增现金支出，已有单独 ADR；否则不得静默引入

## 可靠性与并发

- [ ] 网络失败不会静默丢输入
- [ ] 云端未确认前不会伪装“已保存”
- [ ] 简单 insert 重试复用 ID 或等价去重
- [ ] 多表/高权限命令考虑 operation id / 幂等
- [ ] 并发修改不会静默覆盖关键状态
- [ ] 事务/跨系统中间失败不会留下不安全半状态
- [ ] 错误/空状态对用户可理解

## 测试与执行证据

<!-- 必须区分“代码审查认为正确”和“命令真实执行过”。 -->

- [ ] format / analyze
- [ ] Flutter 单元测试
- [ ] Widget / integration 验证（如相关）
- [ ] 数据库 / RLS / Function 测试（如相关）
- [ ] 手工端到端用户流程
- [ ] 网络失败/重试场景（如相关）
- [ ] Windows / Android 双平台场景（如相关）
- [ ] 上述勾选项确实执行过；不能执行的项已明确标为未验证

### 实际执行的命令 / CI

<!-- 粘贴命令名、workflow/check 名称和结果摘要；不要粘贴 Secret/真实学生数据。 -->

## 开源参考 / 新依赖

- [ ] 如果参考外部项目，已说明“借鉴什么 / 不复制什么”
- [ ] 新依赖有真实必要性
- [ ] 许可证适合当前使用
- [ ] 没有因为 starter/开源项目而绕过本项目 RLS/不变量

## 文档与 ADR

- [ ] README / PRODUCT / USER_FLOWS / ARCHITECTURE / AUTH / DATA_MODEL / COMMANDS / ROADMAP（按需）已同步
- [ ] DEVELOPMENT_WORKFLOW / RISKS / ZERO_COST / OPEN_SOURCE_REFERENCES（按需）已同步
- [ ] 改变关键架构决定时已更新 `docs/DECISIONS.md`
- [ ] 不与现有 ADR 静默冲突

## 发布、风险与恢复

<!-- 最可能出错的地方是什么？如何发现？必要时怎么恢复？ -->

- [ ] 若涉及 Production schema/Auth，已说明 smoke test
- [ ] 若涉及附件，考虑 Storage 与 DB 一致性/恢复
- [ ] 若涉及客户端版本，考虑旧版兼容
- [ ] 若涉及真实数据，确认 DB/Storage 备份路径
- [ ] 若风险不适用，已在上方说明原因
