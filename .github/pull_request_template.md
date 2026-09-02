## 变更目的

<!-- 解决什么真实用户/工程问题？不要只写“新增某页面”。 -->

## 影响的用户流程

<!-- 对应 docs/USER_FLOWS.md；新增流程先说明必要性。 -->

## 变更范围

- [ ] Flutter / UI
- [ ] Repository / Service / ViewModel
- [ ] Auth / Session / Membership
- [ ] Database schema / migration
- [ ] RLS / GRANT / View / Function / Trigger
- [ ] Storage
- [ ] Local secure storage / encrypted draft
- [ ] Network / idempotency / concurrency
- [ ] CI / release / operations
- [ ] Docs / ADR

---

## 产品边界

- [ ] 没把 V1 扩成收费/课消/招生/完整排课 ERP
- [ ] 没创建第二份重复事实源
- [ ] 家校/报告没偷偷进入 V1 四主入口
- [ ] 高频教师路径没有不必要填写
- [ ] `new` 仍能 10–20 秒快速捕捉
- [ ] assessment passed 没自动 stable/closed
- [ ] confirmed/intervening/pending_verification/stable 都有 pending primary action
- [ ] 暂停/观察使用 `review + due_at`，不是只有 pause_reason
- [ ] closed 无 pending primary action
- [ ] 分类治理没有演变成庞大知识图谱

---

## Auth / Session / Tenant

- [ ] 普通业务要求 live Session + active membership
- [ ] revoked JWT 的 `session_id` 无 `auth.sessions` 行时被拒绝
- [ ] onboarding/disabled/no-membership 无学生业务权限
- [ ] V1 同一个 Auth User 不会跨机构同时 onboarding/active
- [ ] user_metadata 没被当权限事实源
- [ ] provision 临时密码强随机、短有效期、只显示一次
- [ ] Password/Token 不进 DB/log/audit/GitHub
- [ ] complete onboarding：改密码 → global sign-out → active → 强制重新登录
- [ ] reset：先 membership→onboarding，再更新 Auth password
- [ ] credential 响应丢失走 reissue，不保存明文 secret
- [ ] 不能停用最后一个可恢复 org_admin

---

## Flutter 本地安全

- [ ] Production Session 使用 Supabase custom LocalStorage + OS secure storage（如相关）
- [ ] Password 不本地持久化
- [ ] Startup Gate 在 Session/live membership 解析前不挂业务 Shell
- [ ] expired/revoked/disabled Session 不会闪现学生数据
- [ ] 跨重启敏感 draft 加密
- [ ] draft key 与密文分离
- [ ] draft 按 user/org 隔离
- [ ] TTL / sync success / logout / account switch 清理逻辑明确
- [ ] draft 不含 Token/Password

---

## Database / RLS / 不变量

- [ ] 新表/字段有明确事实语义
- [ ] 姓名/自由文本没当唯一标识
- [ ] 历史关系没有被当前值覆盖
- [ ] organization_id 父子不会错配
- [ ] RLS + 最小 GRANT
- [ ] live-session / membership / role / assignment 分层授权
- [ ] cross-org / cross-student / cross-subject 负面测试
- [ ] View 不绕 RLS，优先 security_invoker
- [ ] security-definer Function 非 exposed + `search_path=''` + 最小 grant
- [ ] 核心 FK 不意外 cascade 历史
- [ ] 状态机/多表不变量不只靠 Flutter
- [ ] 不变量敏感写入走事务/受控命令

---

## Storage

- [ ] private bucket
- [ ] `storage.objects` policy 与 organization/assignment 一致
- [ ] signed URL 只在授权后生成、TTL 短
- [ ] signed URL 不进入日志/长期缓存
- [ ] 文件类型/大小有限制
- [ ] DB metadata 与 object 生命周期一致
- [ ] Storage backup 影响已考虑

---

## Realtime

- [ ] V1 没把学生敏感表默认加入 Realtime publication
- [ ] 正确性不依赖 Realtime
- [ ] 如果确实新增 Realtime：已有 ADR + revoked-session/reconnect/cross-org 测试

---

## Migration / Environment

- [ ] schema/RLS/View/Function/Trigger/Index 变化有 migration
- [ ] 没只改 Remote Dashboard/SQL Editor
- [ ] Local `db reset` 可从 migrations + fake seed 重建
- [ ] DB/RLS tests 通过
- [ ] destructive 变化有迁移/恢复方案
- [ ] Production 不运行 dev seed/reset
- [ ] 若影响旧客户端，考虑 expand → migrate → contract / 兼容窗口

---

## Region / Network（如相关）

- [ ] Remote Development 只用虚构数据
- [ ] 实际机构 Wi‑Fi 无代理/VPN验证
- [ ] 普通移动网络无代理/VPN验证
- [ ] Auth/Data/Storage/Functions 均验证
- [ ] Production region 没在测试前拍脑袋创建
- [ ] 数据驻留/跨境问题没有被“选了 region”错误当成合规完成

---

## 隐私 / Secret

- [ ] 测试、seed、截图均为明显虚构数据
- [ ] 没有真实学生/家长/教师敏感数据
- [ ] 没提交 Secret/service_role/DB password/backup credential
- [ ] 日志/audit 没复制不必要敏感正文
- [ ] 新自由文本字段有教学用途

---

## 可靠性 / 并发

- [ ] 网络失败不丢输入
- [ ] 云端未确认前不伪装已保存
- [ ] 简单 insert 重试复用 UUID
- [ ] DB command 考虑 operation id / 幂等
- [ ] credential command 没为幂等保存 secret
- [ ] expected_version 冲突不静默覆盖
- [ ] 中间失败不留下越权半状态
- [ ] 错误/空状态可理解

---

## 零额外付费

- [ ] 没新增 SMTP/域名/SMS/AI API/Supabase add-on/商业 SaaS/larger runner 硬依赖
- [ ] 新第三方服务已说明免费额度、超额是否计费、迁出成本、数据隐私
- [ ] GitHub Actions 不依赖自动超额付费
- [ ] heavy Windows/Android build 不在每个普通 PR 无脑运行
- [ ] Work/Codex extra credits 不是完成前提

---

## Backup / Recovery（如影响 Production 数据）

- [ ] migration 前有适当 backup
- [ ] roles/schema/data 恢复影响已考虑
- [ ] Storage 文件恢复影响已考虑
- [ ] Auth/Realtime/Extensions/Secrets config 重建影响已考虑
- [ ] 若是 release/milestone，restore/smoke 计划明确

---

## 测试

- [ ] format
- [ ] analyze
- [ ] Flutter unit tests
- [ ] Widget/integration（如相关）
- [ ] DB/RLS/Function tests（如相关）
- [ ] old JWT revoked-session 测试（Auth 相关）
- [ ] Windows/Android 双平台（如相关）
- [ ] network failure / response loss（如相关）

### 执行证据

<!-- 只写真正运行过的命令/CI。没有运行必须写“未执行”。 -->

```text
Executed:
- ...

Not executed / still needs verification:
- ...
```

“模型判断应该通过”不等于 CI green。

---

## Docs / ADR

- [ ] 受影响的 PRODUCT/ARCHITECTURE/AUTH/DATA_MODEL/COMMANDS/ROADMAP 已同步
- [ ] SECURITY/RISKS/DEVELOPMENT/RECOVERY 按需同步
- [ ] 改关键方向已更新 `docs/DECISIONS.md`
- [ ] 不与 `docs/FOUNDATION_FINAL_AUDIT.md` 的 Freeze Gate 冲突

---

## 最可能失败的地方 / 恢复方式

<!-- 用几句话写出本 PR 最值得担心的失败模式，以及如何发现/恢复。 -->
