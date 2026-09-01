## 变更目的

<!-- 说明这个 PR 解决什么真实问题。 -->

## 变更范围

- [ ] Flutter / UI
- [ ] 数据库 schema / migration
- [ ] RLS / GRANT / Function
- [ ] Auth / 权限
- [ ] Storage
- [ ] 文档
- [ ] 其他

## 用户流程

<!-- 这个变更影响 docs/USER_FLOWS.md 中哪个流程？如果是新流程，请说明。 -->

## 数据与权限检查

- [ ] 没有引入真实学生/家长/教师隐私数据
- [ ] 没有提交 Secret / service_role / 数据库密码 / 私密 API Key
- [ ] 新业务表明确 organization_id 归属
- [ ] RLS 与 GRANT 已同步考虑
- [ ] 跨机构 / 跨学生 / 跨学科负面权限已考虑
- [ ] View / security definer Function 不会绕过 RLS
- [ ] schema 变化有版本化 migration
- [ ] 子表与父表不会出现跨机构错配

## 产品边界检查

- [ ] 没有把 V1 悄悄扩张成排课收费 CRM
- [ ] 没有创建第二份重复事实源
- [ ] 没有用一次 assessment passed 自动关闭案例
- [ ] 未结束案例仍有主行动或暂停理由
- [ ] 高频教师路径没有增加不必要填写

## 可靠性

- [ ] 网络失败不会静默丢输入
- [ ] 重试不会明显造成重复数据
- [ ] 并发修改不会静默覆盖关键状态
- [ ] 错误/空状态对用户可理解

## 测试

- [ ] format / analyze
- [ ] 单元测试
- [ ] 权限/RLS 测试（如相关）
- [ ] Widget / integration 验证（如相关）
- [ ] 手工端到端场景

## 文档

- [ ] README / PRODUCT / ARCHITECTURE / DATA_MODEL / ROADMAP / ADR（按需）已同步
- [ ] 如果改变关键架构决定，已更新 `docs/DECISIONS.md`

## 风险与回滚

<!-- 说明最可能出错的地方，以及必要时如何恢复。 -->
