# 核心用户流程

> 开发新页面前先确认它服务哪个流程；不能改善核心流程的功能默认后置。

## Flow A｜机构首次初始化

1. 受信任运维在 Production 建立 organization；
2. 一次性 bootstrap 创建首位 active org_admin membership；
3. 首位管理员用 Email OTP 登录；
4. bootstrap 关闭；
5. 管理员进入成员管理。

### 验收
- Flutter 无超级管理员 Secret；
- 普通 Auth User 不能自行提权；
- bootstrap 不可重复滥用。

---

## Flow B｜管理员预授权教师邮箱

1. 管理员输入教师邮箱与预期角色；
2. 服务端验证管理员、机构、角色；
3. 创建或复用 `organization_invitation(pending)`；
4. 保存 invitation roles；
5. 管理员告诉教师“请使用该邮箱登录学情闭环”。

### 验收
- pending invitation 没有任何学生数据权限；
- 同机构/邮箱不会产生多个 pending invitation；
- invitation 可以取消；
- 不需要知道该邮箱是否已经存在 Auth User。

---

## Flow C｜教师 Email OTP 登录并加入机构

1. 教师打开 App，输入邮箱；
2. App 请求 Email OTP；
3. 教师收到验证码并输入；
4. `verifyOtp` 建立 Auth Session；
5. 系统查找当前 Auth User 的 active memberships；
6. 同时通过受控流程查找与 verified email 匹配的 pending invitations；
7. 若有 invitation，教师确认加入；
8. `accept_invitation` 原子创建/获取 membership + roles，并把 invitation 标为 accepted；
9. 若只有一个 active membership，直接进入机构；多个时选择机构。

### 无邀请场景
OTP 登录成功但没有 membership/invitation 时，只显示：
> 当前邮箱尚未获得机构授权，请联系机构管理员确认邀请邮箱。

不能枚举机构、教师或学生。

### 验收
- 新 Auth User 和已有 Auth User 使用同一流程；
- 不依赖 deep link 或密码；
- invitation 只能由匹配 verified email 接受；
- accept 重试不创建重复 membership；
- membership disabled 后旧 Session 仍不能访问机构数据；
- OTP 错误、过期、限流有明确 UI。

---

## Flow D｜建立学生主档案

1. 授权人员点击新建学生；
2. 输入最少必要身份信息；
3. 系统提示可能重复；
4. 若已有学生，进入已有主档案；
5. 若确认为新学生，创建 student；
6. 创建当前 enrollment；
7. 启用 subject profile；
8. 分配任课教师/学生负责人。

### 验收
- 姓名不做硬唯一键；
- 不因不同学科重复建 student；
- 年级和负责人变化保留历史。

---

## Flow E｜老师第一次接手学生

1. 打开学生；
2. 首屏看到当前重点案例、待验证、下一步行动、最近时间线；
3. 按学科进入详细案例；
4. 查看允许共享的必要摘要；
5. 不翻完整历史也能知道下一步。

### 验收
新教师能很快回答“这个学生现在最重要的 3 件事是什么”。

---

## Flow F｜课堂中快速捕捉新问题

1. 在课程/学生页点“发现问题”；
2. 已知学生/学科不重复询问；
3. 输入一句问题标题；
4. 可选补一句说明/分类/证据；
5. 系统提示明显重复案例；
6. 保存为 `new` 草稿；
7. 网络异常时保留本地草稿。

### 目标
- 10–20 秒完成常见捕捉；
- 不强迫课中选完整 taxonomy；
- 不强迫上传图片；
- 不强迫当场写根因/整改方案/下一步。

---

## Flow G｜把 `new` 确认为正式案例

1. 打开草稿；
2. 系统利用 lesson context 预填学生、学科、时间；
3. 确认 case type / taxonomy；
4. 课堂短备注可生成最小 classwork/observation evidence 草稿；
5. 教师确认 evidence，不要求上传附件；
6. 确认 owner；
7. 创建首个主行动，或明确 pause reason；
8. 执行 `confirm_case`；
9. 写 confirmed event。

### 验收
正式案例有可解释来源，同时不把结构化负担塞进课堂。

---

## Flow H｜一次真实课程

### 课前
从“今日”或学生页快速开始，看到到期行动、待验证和重点案例。

### 课中
- 完成/调整已有行动；
- 记录真实 intervention；
- 有验证时记录 assessment；
- 新问题走 Flow F。

### 课后
1. 系统整理本节新增事实；
2. 教师确认必要状态变化；
3. 重要 `new` 可进入 Flow G，其他可暂留待整理；
4. 完成旧主行动；
5. 确认下一步主行动；
6. 通过事务化 `complete_lesson` 完成课程。

### 验收
- 常规课后记录中位时间 ≤ 60 秒；
- 不填写另一份周总结；
- 网络失败不清空输入；
- 多表写入不留下半套状态。

---

## Flow I｜验证失败

1. assessment = failed / partial；
2. 系统不自动关闭案例；
3. 提示继续干预或原因复盘；
4. 选择下一步主行动；
5. 案例回到/保持 intervening；
6. 历史 assessment 保留。

---

## Flow J｜验证通过并进入稳定观察

1. assessment = passed；
2. 系统只显示“本次验证通过”；
3. 教师结合证据决定是否进入 stable；
4. stable 可设置复查行动；
5. 观察完成后 closed。

### 验收
passed ≠ 自动 stable/closed；closed 不存在冲突 pending 主行动。

---

## Flow K｜问题复发

1. 系统提示相似 stable/closed 历史案例；
2. 教师选择 reopen，而不是重复新建；
3. 增加新 evidence；
4. `reopened_count` 增加；
5. 创建新的主行动；
6. 原历史完整保留。

---

## Flow L｜教师离职与交接

1. 管理员选择待停用成员；
2. 系统列出 active teacher/staff assignments、active case owner、pending actions；
3. 选择接手人员/受控暂停方式；
4. 事务结束旧关系、建立新关系、转交当前责任；
5. 验证无 orphan；
6. **最后** membership disabled；
7. 历史仍显示原教师。

### 验收
不会先停用再发现一堆无人负责事项；旧 Token 也无法继续访问。

---

## Flow M｜网络失败与重试

1. 教师编辑中网络断开/超时；
2. 页面显示失败/本地草稿；
3. 输入仍在；
4. 网络恢复后重试；
5. 简单 insert 复用 UUID，多表命令复用 operation id；
6. 第一次若其实成功，重试不重复副作用；
7. 云端确认后才显示已保存并清理草稿。

---

## Flow N｜跨学科查看

1. 任课教师看到本人负责学科详细学情；
2. 只看到允许共享的其他信息；
3. 不能修改其他学科专业案例；
4. 学生负责人有更广综合视角，但不能替任课教师改专业结论。

数据库手工请求也必须同样受限。

---

## Flow O｜合并重复学生

1. 管理员确认两份档案属于同一真实学生；
2. 系统展示 source / target 与影响范围；
3. 选择 target；
4. `merge_students` 验证同机构、权限、无 merge 环；
5. 迁移/重指向当前关系与必要业务引用；
6. source → merged + `merged_into_student_id`；
7. 写 merge record + audit；
8. 旧 source ID 仍可解释目标。

---

## V1 不应出现的流程

出现以下行为应先回到产品评审：
- 为了上课必须先维护完整课表；
- 老师每周重新抄周报；
- 同一问题在“初诊/顽固/周跟进”三处维护；
- 课中建问题必须填十几个字段；
- Auth 登录成功就能看机构数据；
- pending invitation 能读学生数据；
- 管理员邀请教师必须依赖 deep link；
- 普通教师可以删除历史事实；
- 页面直接任意 UPDATE case status；
- complete lesson 允许多个请求半成功；
- 网络失败后让老师重新填；
- 一次 passed 自动等于“已解决”；
- AI 自动修改正式学生状态。