# Phase 0B.1-E｜Evidence 图片附件最小闭环

## 目标

在不增加独立“照片”一级导航的前提下，让教师可以在 Quick Capture 或
Case 的 Evidence 区补充一张现场图片。图片只是 Evidence 的补充，文字
说明仍然是必填的教学事实。

本切片只使用虚构开发数据，不代表 Production 数据上线许可。

## 已落地

- `case_evidence_attachments`：只保存附件元数据，不保存 base64 或图片二进制；
- `case-evidence-private`：Supabase 私有 Storage bucket，单文件上限 10 MB；
- 路径约定：`org/{organization}/cases/{case}/evidence/{evidence}/{attachment}.{ext}`；
- JPEG / PNG / WEBP 白名单；客户端只允许相同格式；
- Storage 上传、元数据 RPC、signed URL 读取均检查机构、Case、Evidence 和当前教师分配；
- 已登记的历史附件不能由客户端删除；上传登记失败时只能清理未登记对象；
- Android 支持拍照或相册，Windows 使用系统图片选择器；
- Android 从相机返回时尝试恢复系统因内存压力暂存的选图结果；
- Quick Capture 在文字 Case 成功后登记图片，登记失败会保留窗口和输入供重试；
- Case 详情按 Evidence 显示缩略图，点击后用短时 signed URL 查看大图。

## 为什么采用两阶段上传

Supabase Storage 的对象写入和业务元数据写入不是同一个数据库事务，因此客户端按以下顺序执行：

1. 生成随机附件 UUID 和受约束的私有路径；
2. 用当前登录会话上传对象；
3. 调用 `create_case_evidence_attachment`，由服务端重新核验 Case/Evidence 归属、当前教师分配、MIME、大小和对象是否存在；
4. RPC 失败时尝试删除对象；Storage 的删除策略只允许删除尚未登记的对象，避免网络歧义时误删已提交附件。

## 验证状态

- `xueqing-dev` 已应用 `phase_0b_1_e_case_evidence_attachments` 和后续路径字面量修正迁移；
- 远端结构核验：私有 bucket、10 MB 限制、附件表、元数据读取策略、Storage 三条策略和 RPC 均存在；
- Flutter/Dart 静态分析：通过；
- 真实 Android 相机、Windows 选择器、真实图片上传和 signed URL 访问：待在设备 / 可访问远端网络上执行；
- 本地 Supabase 全量重建测试：待 CI 或具备 Supabase CLI 的环境执行。

## 运行边界

- 仓库保持公开是零成本 CI 决策；公开仓库中不得出现 service key、访问令牌、真实学生资料、真实照片或敏感导出；
- Storage bucket 必须保持 private，不能通过公开 URL 或 CDN 直接暴露；
- 目前不支持批量相册、独立照片时间线、视频、OCR、AI 诊断或离线图片队列；
- Case 关闭后不允许新增附件；附件清理和异常对象审计仍属于后续运维 drill。
