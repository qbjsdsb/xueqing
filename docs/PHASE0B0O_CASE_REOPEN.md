# Phase 0B.0-O｜Closed Case Reopen

## 目标

把已关闭 Case 的复发处理做成可审计、可重试的事务闭环：

closed → 关闭后的新 Evidence → reopen_case → confirmed

重新打开不是新增状态，而是一个带有明确 Evidence、Action、事件和版本变化的命令。

## 服务端契约

- 关闭 Case 只能接受 observed_at 严格晚于服务器解析出的最新已提交 case_closed 事件的 Evidence。
- 客户端不能选择旧的关闭边界；服务器会锁定并重新读取 Case、最新关闭事件和选中的 finalized Evidence。
- Evidence 必须属于同一机构和同一 Case，状态必须是 finalized，版本必须与客户端期望版本一致。
- 旧 Evidence 单独不能重新打开；补录的 Evidence 依据 observed_at 判断，不依据 created_at 判断。
- 只有 active Profile、完整 Teaching Fact Gate 和当前可执行的 lead teacher 才能操作。
- 成功后原子地把 Case 变成 confirmed，重新指定合法 owner，创建一个 pending primary Action，清空 stable_at/closed_at，递增 reopened_count 和 version，并写入不可变 case_reopened 事件。
- operation_id 保证重复请求返回原结果，不重复创建 Action、事件或版本；任何校验失败都会回滚。

## 客户端交互

客户端先用一个 operation_id 追加复发 Evidence，再用另一个 operation_id 调用 reopen_case。任一响应丢失时必须重试原 operation_id，并锁定首次提交的输入；如果 Evidence 已提交但重新打开失败，只重试 reopen_case，不重复追加 Evidence。

## 验证

case_reopen_access_test 覆盖：

- 旧 Evidence、关闭前时间和跨关闭边界的拒绝；
- 关闭后补录 Evidence 与重新打开；
- 状态、版本、reopened_count、owner、Action 和事件元数据；
- 重试幂等、正常二次教学闭环和公共 RPC 权限边界。

## 发布前人工门槛

在 development 环境使用虚构账号和数据完成 Android、Windows 两端的：

1. 稳定 Case 关闭；
2. 关闭后记录真实复发 Evidence；
3. 重新打开并继续 Intervention/Assessment；
4. 断网或响应丢失后的原 operation_id 重试；
5. 第二轮关闭、复发和重新打开。

