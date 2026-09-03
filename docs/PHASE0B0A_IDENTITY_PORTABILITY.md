# P0 Gate A｜Auth Identity Portability Spike

**状态：PASS（2026-09-03，身份契约与本地迁移模拟）**

## 目的

在写正式业务 migration、Production Auth/RLS/CRUD 或接入真实学生资料前，确认业务身份不会被某一个认证供应商的用户主键绑死。

本分支只做兼容性证明，使用本地数据库中的虚构数据和临时表。它不修改 Remote Development 项目，也不构成 Production 部署授权。

## 研究结论

Supabase 的业务示例通常会把 public 用户表的 id 定义为 uuid，并通过 auth.uid() 参与 RLS；腾讯 CloudBase 的安全规则和数据结构文档把 auth.uid / Uid 描述为用户 ID 字符串。因此，业务层不能假定所有候选 provider 的 subject 都是 UUID，也不能把 provider auth 主键直接当作业务主键。

参考：

- Supabase [User Management](https://supabase.com/docs/guides/auth/managing-user-data)
- Supabase [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- 腾讯云 [CloudBase 安全规则](https://cloud.tencent.com/document/product/876/41802)
- 腾讯云 [CloudBase 数据结构](https://cloud.tencent.com/document/product/876/34822)

## 方案比较

| 方案 | 结果 | 原因 |
| --- | --- | --- |
| provider auth 主键直接作为业务 Profile 主键 | 否决 | 认证迁移会迫使所有业务外键、历史事实和审计 actor 一起改主键 |
| 业务 UUID + provider/subject 放在同一行 | 仅适合早期单 provider spike | 可以暂时工作，但难以保存旧身份映射、处理 provider instance，也不利于受控迁移 |
| 业务 UUID + 独立 identity link | 采用候选 | 业务事实只引用稳定 UUID；外部身份以 provider、issuer、subject 三元组精确解析；迁移只切换 link |

## 本分支冻结的候选契约

1. 业务身份（最终可命名为 Profile / App User）由应用生成稳定 UUID。
2. 学生、成员、教师责任、Case、Evidence、Intervention、Assessment、Action 等业务事实不得把 provider auth PK 当作外键。
3. 外部身份至少由以下三项组成：
   - provider_key，例如 supabase / cloudbase；
   - issuer，例如具体项目、环境或租户；
   - external_subject，类型固定为 text，禁止 cast 成 UUID。
4. V1 同一个业务身份只保留一个 active identity link；迁移在一个受控事务里先 retire 旧 link，再 activate 新 link。
5. 唯一性是 provider_key + issuer + external_subject；不能只按 subject，也不能按邮箱自动匹配。
6. 旧 link 保留为 retired 历史，不物理删除；真实身份切换需要可信迁移映射和审计，不能由客户端自行改绑。

## 自动化验收

supabase/tests/identity_portability_spike.sql 会验证：

- 当前 compatibility app_users 的业务 id 是 uuid；
- auth subject 和 provider key 是 text；
- app_users.id 不直接 foreign-key 到 auth.users；
- UUID-shaped Supabase subject 和非 UUID candidate-provider subject 都可存储；
- provider 切换后业务 UUID 与 child fact 不变；
- 旧 link 不能继续作为 active link；
- 同一 provider issuer subject 不能绑定第二个业务身份；
- 相同字符串 subject 在不同 issuer 下不会误碰撞；
- child fact 只引用业务 Profile UUID。

## Gate 通过条件（已满足）

本分支已通过 GitHub Supabase workflow 的空库重建、pgTAP 测试和旧 token 回归，并记录了实际执行证据：

- Supabase checks：`https://github.com/qbjsdsb/xueqing/actions/runs/33741847279`
- Flutter checks：`https://github.com/qbjsdsb/xueqing/actions/runs/33741847275`
- 验证 head：`8efba87d553deafe3e6011e140a30f1cebd6d44c`
- 身份契约测试：18/18 通过；既有 RLS 与 old-token 回归同时通过。

因此，P0 Gate A 的身份物理建模/迁移契约已通过。候选 provider 的真实地区网络、Storage、backup/restore 与 Production Go/No-Go 仍是后续边界，不在本 Gate 中伪装成已完成。

Gate 通过后仍继续遵守：

- Supabase 只作为 reference candidate；
- 只用虚构数据；
- 不创建正式 Production business migration；
- 不将 Supabase provider/region/session strategy 宣布为最终冻结；身份解耦契约已由 ADR-046 冻结；
- 不实现 Student / Case 的正式远程 CRUD。

下一条 PR 进入 Phase 0B.0-B：把本契约落实到 provider-neutral 的正式身份表和最小 Student / Subject Profile 基础，并再次单独验证 RLS、时间语义、命令幂等和恢复路径。
