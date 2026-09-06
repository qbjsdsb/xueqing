# Xueqing 发布与软件内更新

本文说明 Windows / Android 的直接分发和软件内更新流程。当前项目不使用应用商店更新。

## 更新机制

- Windows 发布包是完整目录 ZIP，必须包含 `xueqing.exe`、`xueqing_updater.exe` 以及 Flutter 运行库。
- Windows 应用下载 ZIP 后启动更新助手；助手等待主程序退出，校验 SHA-256，先备份再替换，失败时回滚。
- Android 发布包是使用同一长期保存的 release keystore 签名的 APK。应用下载并校验 APK 后交给系统安装器；系统会要求允许本应用安装未知来源。
- GitHub Release 资产同时上传 `update-manifest.json` 和 `SHA256SUMS.txt`。应用从稳定版的 `releases/latest/download/update-manifest.json` 检查更新。
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
4. 工作流会先构建并测试更新助手，再生成签名 APK、Windows 完整 ZIP、真实哈希和更新清单。任何密钥缺失、版本不匹配、构建失败或资产重名都会停止，不会覆盖旧资产。
5. 成功后，已安装的旧版本在教师工作台的更新入口中选择检查更新，即可下载并安装。

## 首次安装与验证建议

- 先安装一个较旧的、同一 Android release keystore 签名的包；再发布更高版本测试覆盖升级。
- Android 首次安装更新可能要在系统设置中打开“允许安装未知应用”，返回应用后重新点击安装。
- Windows 首次安装应使用包含 `xueqing_updater.exe` 的完整 ZIP；很早的旧包没有更新助手时，应用会提示先手动安装一次最新完整包。
- 更新前保留应用目录外的用户数据；更新助手只替换安装目录，不删除业务数据。
- 不要用 debug APK 验证 Android 覆盖升级；debug 签名与 release 签名不同，且不代表正式更新链路。

## 发行边界

- 当前默认环境仍可指向虚构开发项目；开发 Release 不得录入真实学生、家长或教师隐私数据。
- GitHub Release 资产是公开下载地址；不要把 Supabase secret、service_role、数据库密码或 Android keystore 放进仓库。
- Windows / Android 代码签名证书和安装器信任仍是后续发行加固项；软件内更新链路的 HTTPS、摘要校验、版本比较、签名覆盖关系和 Windows 回滚先由本流程保证。
