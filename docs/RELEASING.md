# Xueqing 发布与软件内更新

本文说明 Windows / Android 的直接分发和软件内更新流程。当前项目不使用应用商店更新。

## 更新机制

- Windows **首次安装和人工候选验收使用 Setup EXE**。安装器按用户安装到 `%LOCALAPPDATA%\Programs\Xueqing`，不要求管理员权限；安装内容包含主程序、Flutter/VC++ 运行库、`xueqing_updater.exe` 和 `xueqing_updater_bootstrap.exe`。
- Windows **应用内更新载体仍是完整目录 ZIP**，必须包含 `xueqing.exe`、`xueqing_updater.exe`、`xueqing_updater_bootstrap.exe` 以及 Flutter/VC++ 运行库。ZIP 是 updater 的机器处理载体，不要求用户手工解压。
- Windows 应用下载 ZIP 后启动更新助手；新安装从临时副本运行助手，旧安装先通过 bootstrap 完成一次助手迁移；助手等待主程序退出，校验 SHA-256，先备份再替换，失败时回滚。
- Android 发布包是使用同一长期保存的 release keystore 签名的 APK。应用下载并校验 APK 后交给系统安装器；系统会要求允许本应用安装未知来源。
- GitHub Release 资产同时上传 `update-manifest.json` 和 `SHA256SUMS.txt`。正式 Release 还应提供 Windows Setup EXE；应用从稳定版的 `releases/latest/download/update-manifest.json` 检查更新。
- 当前清单只接受 HTTPS、版本 schema 1、正整数文件大小和 64 位 SHA-256；下载完成后再次校验大小与摘要。

## 一次性配置 Android 签名

Android 的签名密钥决定“新 APK 能否覆盖旧 APK”。密钥丢失或更换后，已安装用户不能通过软件内更新升级，因此必须离线加密备份。

在安全机器上生成一次：

```bash
keytool -genkeypair -v \
  -keystore xueqing-release.jks \
  -alias xueqing \
  -keyalg RSA -keysize 4096 -validity 10000
```

把以下四项加入 GitHub 仓库 Settings → Secrets and variables → Actions → New repository secret：

- `XUEQING_ANDROID_KEYSTORE_BASE64`：`xueqing-release.jks` 的 base64 内容；
- `XUEQING_ANDROID_KEYSTORE_PASSWORD`；
- `XUEQING_ANDROID_KEY_ALIAS`；
- `XUEQING_ANDROID_KEY_PASSWORD`。

Linux/macOS 可这样复制 base64 内容（不要把输出贴到聊天）：

```bash
base64 -w 0 xueqing-release.jks
```

Windows PowerShell 可这样生成单行内容：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("xueqing-release.jks"))
```

仓库已忽略 `android/key.properties`、`*.jks` 和 `*.keystore`；不要把它们提交到 Git 或写入工作流日志。

## 发布一次新版本

1. 先在仓库创建一个已发布、非 Draft、非 Pre-release 的 GitHub Release。标签必须与版本一致，例如版本 `0.2.0+2` 使用标签 `v0.2.0`。
2. 打开 Actions → **Publish signed release assets and update manifest**。
3. 输入：
   - `release_tag`：已有 Release 标签；
   - `app_version`：三段版本号加正整数 build，例如 `0.2.0+2`；
   - `release_environment`：开发验证选 `development`，正式数据环境才选 `production`；
   - `release_notes`：每行一条更新说明。
4. 工作流会先构建并测试更新助手，再生成签名 APK、Windows 完整 ZIP、Windows Setup EXE、真实哈希和更新清单。任何密钥缺失、版本不匹配、构建失败或资产重名都会停止，不会覆盖旧资产。
5. 成功后：新设备首次安装 Windows 使用 `*-windows-setup.exe`；已安装版本在教师工作台的更新入口中选择检查更新，由应用自动下载并处理 ZIP；Android 由应用下载并校验 APK 后交给系统安装器。

## 候选包与真机验收

- Windows 候选测试优先运行 Actions → **Package Windows app**，下载生成的 installer artifact 后直接运行 Setup EXE，不把 ZIP 当成人工安装入口。
- `Package Windows app` 生成安装器前必须先通过 updater analyze/test，并把 canonical updater 与 bootstrap updater 一起装入候选包。
- 未显式指定候选版本时，Windows 打包与平台 smoke 从 `pubspec.yaml` 读取版本，避免安装器文件名、运行时版本和应用版本漂移。
- Android 功能候选可以使用 debug APK；但 debug APK **只用于功能验收**，不能证明正式覆盖升级链路。

## 首次安装与验证建议

- 先安装一个较旧的、同一 Android release keystore 签名的包；再发布更高版本测试覆盖升级。
- Android 首次安装更新可能要在系统设置中打开“允许安装未知应用”，返回应用后重新点击安装。
- Windows 首次安装使用 Setup EXE；安装完成后再用更高版本验证应用内 ZIP 更新、自动重启和失败回滚。用户不应手工解压更新 ZIP。
- 更新前保留应用目录外的用户数据；更新助手只替换安装目录，不删除业务数据。
- 不要用 debug APK 验证 Android 覆盖升级；debug 签名与 release 签名不同，且不代表正式更新链路。

## 发行边界

- 当前默认环境仍可指向虚构开发项目；开发 Release 不得录入真实学生、家长或教师隐私数据。
- GitHub Release 资产是公开下载地址；不要把 Supabase secret、service_role、数据库密码或 Android keystore 放进仓库。
- Windows 安装器当前未做商业代码签名，SmartScreen 可能提示未知发布者；只从项目自己的 GitHub Release/Actions 产物安装。Windows / Android 正式代码签名与安装器信任仍是后续发行加固项。
- 软件内更新链路的 HTTPS、摘要校验、版本比较、Android 签名覆盖关系和 Windows 备份/回滚先由本流程保证。
