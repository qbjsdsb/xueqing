# 核心用户流程

> 开发页面前先确认它服务哪个真实流程。不能改善核心流程的功能默认后置。

## Flow A｜机构首次初始化

1. 受信任运维创建 Production organization；
2. 一次性 bootstrap 建首位 org_admin Auth User + onboarding membership；
3. 设置 `onboarding_expires_at`；
4. 管理员用一次性凭据登录；
5. 只进入账号接管页；
6. 设置自己的新密码；
7. global sign-out 所有 Sessions；
8. membership→active；
9. 管理员用新密码重新登录；
10. bootstrap 关闭。

### 验收
- Flutter 没超级管理员 Secret；
- onboarding 无学生数据；
- 旧 Session 被 live-session guard 拒绝；
- bootstrap 不长期公开；
- Production 不用 development seed。

---

## Flow B｜管理员开通教师

1. org_admin 打开成员管理；
2. 输入已知教师邮箱、显示名、初始角色；
3. `provision_member` 验证管理员 live Session/机构权限；
4. 服务端生成强随机临时密码；
5. Auth Admin 创建/受控处理 Auth User；
6. 建 `membership(onboarding)` + roles + expiry；
7. audit 不含密码；
8. 临时密码只显示一次；
9. 管理员通过已建立身份关系的可信渠道交付。

### 响应丢失
如果服务端其实成功但管理员没收到响应：
- member 保持 onboarding；
- 不尝试“找回”原密码；
- UI 提示凭据交付未知；
- 管理员 reissue/reset，获得新的临时密码。

### 验收
- 密码不进 DB/log/audit/GitHub；
- 普通 teacher 不能 provision；
- 失败不留下 active 半状态；
- 同一机构不重复 member。

---

## Flow C｜教师首次接管账号

1. 教师邮箱 + 临时密码登录；
2. App 启动 Gate 识别 membership=onboarding；
3. 不挂学生业务 Shell，只显示“设置新密码”；
4. 检查 onboarding 未过期；
5. 教师输入自己的新密码；
6. `complete_member_onboarding` 更新该用户密码；
7. 服务端用当前登录 JWT global sign-out 所有 Sessions；
8. sign-out 成功后 membership→active；
9. App 清理旧 Session/机构上下文；
10. 明确提示“账号已接管，请重新登录”；
11. 教师用新密码重新登录；
12. 新 live Session + active membership 后进入机构。

### 验收
- onboarding 手工 API 也无学生权限；
- 过期凭据不能接管；
- 保存旧 JWT，在接管完成后直接调用业务 API 必须被拒；
- 半失败不提前 active；
- Windows/Android 一致。

---

## Flow D｜忘记密码 / 管理员重置

1. 教师通过机构既有渠道联系管理员；
2. 管理员确认本人；
3. `reset_member_credential` 验证 org_admin；
4. **先 membership→onboarding**，立即切断业务权限；
5. 生成新的随机临时密码；
6. Auth Admin 更新目标 Auth User 密码；
7. 刷新 onboarding expiry；
8. audit 不含密码；
9. 临时密码只显示一次；
10. 教师重新走 Flow C。

### 验收
- 不依赖 SMTP；
- reset 中间失败优先停在无业务权限；
- 旧客户端立即读不到学生数据；
- 响应丢失走 reissue，不保存原密码。

---

## Flow E｜App 启动 / Session 恢复

1. App 读取 OS 安全存储中的 Session；
2. 检查本地 Session 过期/刷新状态；
3. 必要时等待远端 Auth refresh/验证；
4. 检查 JWT `session_id` 仍是 live Session；
5. 查询 active memberships；
6. 解析 current organization；
7. 最后挂业务 Shell。

### 分支
- revoked/expired → 登录页；
- onboarding → 接管页；
- disabled/no membership → 无权限状态页；
- active → 业务页。

### 验收
任何旧/失效 Session 都不能先闪现学生页。

---

## Flow F｜建立学生主档案

1. 管理员/授权人员点新建学生；
2. 输入最少必要身份信息；
3. 系统提示可能重复；
4. 已存在则进入原主档案；
5. 确认为新学生才创建 student；
6. 创建 enrollment；
7. 启用所需 subject profile；
8. 分配任课教师/学生负责人。

验收：姓名不硬唯一；不因学科重复 student；年级/负责人变化保留历史。

---

## Flow G｜老师第一次接手学生

1. 打开学生；
2. 首屏看到当前重点 case、待验证、下一 action、最近时间线；
3. 按学科进入详细 case；
4. 必要时看获准综合摘要；
5. 不翻完整历史也能回答“现在最重要的三件事”。

无权学科详细内容不能暴露。

---

## Flow H｜课堂快速发现新问题

1. 从 lesson/学生页点“发现问题”；
2. 已知学生/学科自动带入；
3. 输入一句最小标题；
4. 可选说明/分类/evidence；
5. 系统提示明显重复 case；
6. 保存 `new`；
7. 网络异常时进入 encrypted local draft。

### 目标
- 10–20 秒；
- 不强迫完整 taxonomy；
- 不强迫上传图片；
- 不强迫课中写根因/整改/下一行动。

---

## Flow I｜确认 new 为正式 Case

1. 打开 new；
2. lesson context 预填学生/学科/时间；
3. 确认 taxonomy + case type；
4. 确认/补最小 evidence；
5. 确认 active owner；
6. 创建一个 pending primary action；
7. 执行 `confirm_case`；
8. 写 confirmed event。

### 暂缓
如果暂时观察：
- 填 pause_reason；
- 建 `review` primary action；
- review 必须有 due_at。

不能只填“先观察”然后没有下一次检查。

---

## Flow J｜一次真实课程

### 课前
1. 从 Today/学生页开始 lesson；
2. 看到到期/逾期 action、待验证、重点 case。

### 课中
3. 完成/调整 action；
4. 记录 intervention；
5. 有验证则 assessment；
6. 新问题走 Flow H。

### 课后
7. 系统汇总本节新增事实；
8. 教师确认必要状态变化；
9. new 可进入 Flow I 或留待整理；
10. 完成/取消旧 primary action；
11. 创建新的 primary action；
12. `complete_lesson` 原子完成课程。

### 验收
- 常规课后中位 ≤60 秒；
- 不再填一份周总结；
- 网络失败不丢/不重复；
- 正式未关闭 case 没有 action 空窗。

---

## Flow K｜验证失败

1. assessment=failed/partial；
2. 系统不自动 close；
3. 提示继续干预/原因复盘；
4. 教师创建下一 primary action；
5. case 回到/保持 intervening；
6. 原 assessment 保留。

---

## Flow L｜验证通过 → Stable → Closed

1. assessment=passed；
2. 显示“本次验证通过”，不自动改 stable/closed；
3. 教师确认 stable；
4. stable 同时创建后续 `review/verify` primary action；
5. 到期再检查；
6. 满足退出条件后 closed；
7. close 时 pending primary action 必须清零。

---

## Flow M｜问题复发

1. 发现和历史 stable/closed case 高度相同；
2. 系统提示历史；
3. 选择 reopen；
4. 新 evidence；
5. reopened_count +1；
6. 建新的 primary action；
7. 原历史保留。

---

## Flow N｜教师离职 / 交接

1. 管理员选择成员；
2. 盘点 active teacher/staff assignments；
3. 盘点 active case owner；
4. 盘点 pending actions；
5. 选择接手人/处理方式；
6. 受控事务结束旧关系、建立新关系、转交责任；
7. 验证无 orphan；
8. membership→disabled；
9. 历史作者保持原教师。

旧 JWT 也必须被业务授权拒绝。

---

## Flow O｜网络失败 / 草稿

1. 教师填写；
2. 网络断开/超时；
3. 显示失败/待同步；
4. 输入以 user/org scope 加密草稿保存；
5. 网络恢复后重试；
6. insert 复用 UUID，DB command 复用 operation id；
7. 云端已成功则不重复副作用；
8. 云端确认后删除本地 draft。

### Logout / Account Switch
若仍有未同步草稿，明确让用户同步或丢弃；绝不把上一账号草稿展示给下一账号。

---

## Flow P｜跨学科查看

- 本科教师：本科详细数据；
- 其他教师：必要摘要；
- advisor：综合视角；
- 不越权修改其他学科专业 case。

手工 API 与前端行为一致。

---

## Flow Q｜合并重复学生

1. 管理员确认同一真实学生；
2. 展示 source/target 与受影响数据；
3. 选择 target；
4. `merge_students` 检查同机构/权限/无 merge 环；
5. 迁移/重指向必要关系；
6. source→merged；
7. merge record + audit；
8. 旧 source ID 可追溯到 target。

---

## Flow R｜Production 备份 / 恢复演练

1. 导出 roles/schema/data；
2. 必要时 migration history；
3. 加密保存到 Supabase/GitHub 之外；
4. 导出 Storage objects + manifest；
5. 保存 Project config checklist；
6. 新建非 Production 测试项目；
7. 恢复 DB；
8. 恢复 Storage/config；
9. 跑 smoke test；
10. 记录恢复结果/RPO。

“文件存在”不等于可恢复。

---

## Flow S｜Production Region 决策

1. Remote Development 使用虚构数据；
2. 在实际机构 Wi‑Fi 无代理测试；
3. 普通移动网络无代理测试；
4. Auth/Data API/Storage/Functions/恢复全部覆盖；
5. 不合格则重建 Dev 换 APAC region；
6. 测试合格后才创建 Production；
7. 机构完成数据驻留/跨境合规评估。

---

## V1 不应出现

- onboarding/disabled/revoked Session 可以读学生数据；
- 改密码后旧 Session 未撤销就直接 active；
- 临时密码无有效期；
- 为响应重试长期保存明文临时密码；
- App 启动先闪学生页再验证 Session；
- 敏感草稿明文长期落盘；
- 暂停 case 没 review action/due_at；
- 为开始 lesson 必须先排完整课表；
- 老师每周再抄一份周报；
- 一个问题多套台账；
- 一次 passed 自动“已解决”；
- 网络失败后要求重填；
- AI 自动改正式 status；
- 为参考开源项目把系统扩成收费/招生 ERP。
