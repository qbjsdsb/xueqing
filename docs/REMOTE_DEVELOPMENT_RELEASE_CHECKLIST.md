# Remote Development 发布检查清单

这份清单用于把客户端代码、Supabase migration 和远程开发库保持在同一个可验证状态。当前 Remote Development 只允许使用虚构数据；它不是 Production 发布流程。

## 什么时候使用

在以下任一情况后使用一次：

- 客户端开始读取或写入新的表、字段、View 或 RPC；
- 新增或修改 migration、RLS、函数、触发器、索引；
- 重新打 Android / Windows 包；
- 发现 Data API 返回 404、PGRST205、权限错误或工作台加载失败。

## 发布顺序

1. **确认源码完整**

   - migration 文件已经提交到当前 feature branch；
   - 客户端字段、表名和 RPC 名称与 migration 原文一致；
   - 没有只在 Dashboard / SQL Editor 中存在、但 GitHub 没有记录的 schema 改动。

2. **先跑本地检查**

   - supabase db reset；
   - migration / RLS / function 的本地测试；
   - flutter format --set-exit-if-changed .；
   - flutter analyze；
   - flutter test。

3. **再部署 Remote Development**

   只对确认的虚构开发项目按顺序部署 migration。不要跳过中间 migration，也不要为了让客户端暂时可用而手工补一张未提交的表。

4. **核对远端 schema**

   部署后确认：

   - migration history 包含本分支全部 migration；
   - 新增表、列、View、RPC、索引存在；
   - RLS 已开启，policy / grant 与 migration 原文一致；
   - 不要把“能打开 Dashboard”当作部署成功证据。

5. **做一次最小公网 smoke test**

   使用真实的开发环境登录流程验证：

   - 登录账号 A，只能看到 A 的机构、学科、学生和 Case；
   - 工作台首次加载、重试、空数据和网络失败都可恢复；
   - 新增/修改的问题类型能在新记录中使用，历史 Case 的类型快照不变；
   - 退出后登录账号 B，页面、缓存和输入不会沿用账号 A；
   - 同一操作重复点击不会生成重复事实；
   - 必要时再检查 Android 和 Windows 各一遍。

6. **最后才打包**

   只有远端 migration history、schema 核对和 smoke test 都通过后，才手动触发 Android / Windows 打包。普通代码修改不自动消耗 native build 额度。

## 常见症状的处理

| 症状 | 优先检查 | 不要做 |
| --- | --- | --- |
| Data API 访问新表返回 404 或 PGRST205 | 远端 migration 是否已部署 | 先反复重装客户端 |
| 工作台显示加载失败 | API 日志中第一个非 2xx 请求 | 只凭网络感觉改 RLS |
| 账号切换后内容不对 | Auth state、当前用户 ID、页面 Future 是否重建 | 只清 UI 文本，不清当前页面状态 |
| 远端数据与本地 seed 不同 | 当前环境、migration history 和账号 | 把 Remote Dashboard 手改当成正式变更 |
| 本地测试通过、远端失败 | session / region / Data API smoke test | 把本地固定 UUID 当成远端登录会话 |

## 记录证据

每次 Remote Development 变更至少记录：

- branch / commit SHA；
- migration 文件名和远端 migration history；
- schema / RLS 核对结果；
- smoke test 账号角色（不要记录密码、Token 或学生正文）；
- 未执行的检查及原因。

这份清单不能替代 P0 Gate、Production Go/No-Go、数据备份或真实未成年人数据合规评估。
