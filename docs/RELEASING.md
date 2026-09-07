# Xueqing 发布与软件内更新

本文说明 Windows / Android 的直接分发和软件内更新流程。当前项目不使用应用商店更新。

## 更新机制

- Windows **首次安装和人工候选验收使用 Setup EXE**。安装器按用户安装到 `%LOCALAPPDATA%\Programs\Xueqing`，不要求管理员权限；安装内容包含主程序、Flutter/VC++ 运行库、`xueqing_updater.exe` 和 `xueqing_updater_bootstrap.exe`。
- Windows **应用内更新载体仍是完整目录 ZIP**，必须包含 `xueqing.exe`、`xueqing_updater.exe`、`xueqing_updater_bootstrap.exe` 以及 Flutter/VC++ 运行库。ZIP 是 updater 的机器处理载体，不要求用户手工解压。
- Windows 应用下载 ZIP 后启动更新助手；新安装从临时副本运行助手，旧安装先通过 bootstrap 完成一次助手迁移；助手等待主程序退出，校验 SHA-256，先备份再替换，失败时回滚。
- Android 发布包是使用同一长期保存的 release keystore 签名的 APK。应用下载并校验 APK 后交给系统安装器；系统会要求允许本应用安装未知来源。
- GitHub Release 资产同时上传 `update-manifest.json` 和 `SHA256SUMS.txt`。正式 Stable Release 还提供 Windows Setup EXE；稳定客户端从 `releases/latest/download/update-manifest.json` 检查更新。
- Stable 更新清单固定使用 `channel: stable`；Windows 资产必须是 `zip`，Android 资产必须是 `apk`，显式文件名必须匹配平台扩展名。
- 清单只接受 HTTPS、版本 schema 1、正整数文件大小和 64 位 SHA-256；下载完成后再次校验大小与摘要。旧更新缓存会在下一次下载前做 best-effort 清理。

## 两条发布轨道必须隔离

Xueqing 把“开发候选”和“稳定更新”视为两条不同轨道，禁止混用：

### Development / Candidate

- 使用 Actions → **Package Android APK** / **Package Windows app** 或明确标记为 **Pre-release** 的候选 Release。
- 只连接虚构开发环境，只用于功能、真机、安装器和升级链路验收。
- 候选 Release 必须保持 Pre-release，不能成为 GitHub `releases/latest` 的 Stable 来源。
- Debug APK 只能用于功能验收，不能证明 Android 正式覆盖升级，因为 debug 与 release 签名不同。
- 如果后续需要“开发版应用内自动更新”，必须使用独立的 `development` channel / manifest 地址，不能借用 Stable `releases/latest`。

### Production / Stable

- Actions → **Publish stable signed release assets and update manifest** 只允许 Production。
- Stable 发布采用“两阶段提升”：目标版本先以**已发布 Pre-release** 暂存；全部构建、签名、上传和资产复核成功后，工作流最后才将它提升为 Stable。
- 暂存阶段不会进入 GitHub `releases/latest`，所以构建失败或上传中断时，已安装客户端继续看到上一版 Stable，不会撞上缺少 manifest 的半成品 Release。
- `app_version` 必须是正式 `major.minor.patch+build`，不接受 `-rc`、`-beta` 等预发布标识。
- 必须配置 Production Supabase URL、publishable key 和精确 allowed hosts。
- 必须使用永久 Android release keystore，并固定其证书 SHA-256 指纹。
- Stable publisher 不提供 development 开关，也不会使用虚构开发 endpoint 的默认值。
- Stable publisher 使用全局串行锁，同一时间只允许一个稳定版本进入发布流程，避免两个版本同时竞争 `latest`。

## 一次性配置 Android 签名

Android 的签名密钥决定“新 APK 能否覆盖旧 APK”。密钥丢失或更换后，已安装用户不能通过软件内更新升级，因此必须离线加密备份；建议至少保存两份独立离线备份。

在安全机器上生成一次：

```bash
keytool -genkeypair -v \
  -keystore xueqing-release.jks \
  -alias xueqing \
  -keyalg RSA -keysize 4096 -validity 10000
```

把以下四项加入 GitHub 仓库 Settings → Secrets and variables → Actions → **Secrets**：

- `XUEQING_ANDROID_KEYSTORE_BASE64`：`xueqing-release.jks` 的 base64 内容；
- `XUEQING_ANDROID_KEYSTORE_PASSWORD`；
- `XUEQING_ANDROID_KEY_ALIAS`；
- `XUEQING_ANDROID_KEY_PASSWORD`。

再读取这把永久证书的 SHA-256 指纹：

```bash
keytool -list -v \
  -keystore xueqing-release.jks \
  -alias xueqing
```

找到输出中的 `SHA256:`，把该指纹加入 Settings → Secrets and variables → Actions → **Variables**：

- `XUEQING_ANDROID_CERT_SHA256`

这个指纹不是私钥，可以作为仓库变量保存。工作流会忽略冒号和大小写差异，但要求最终是完整 64 位十六进制 SHA-256。每次正式 APK 构建后都会运行 `apksigner verify --print-certs` 并把实际签名证书与该固定指纹比较；如果有人误换 keystore，发布会在上传资产前失败。

Linux/macOS 可这样复制 keystore 的 base64 内容（不要把输出贴到聊天）：

```bash
base64 -w 0 xueqing-release.jks
```

Windows PowerShell 可这样生成单行内容：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("xueqing-release.jks"))
```

仓库已忽略 `android/key.properties`、`*.jks` 和 `*.keystore`；不要把它们提交到 Git 或写入工作流日志。

## Production Stable 一次发布流程

1. 确认要发布的提交已经在 `main` 历史中，并完成对应 CI、真机与 Go / No-Go 验收。
2. 在仓库为正式标签创建一个**已发布、非 Draft、Pre-release** 的暂存 Release。标签必须与正式版本一致，例如版本 `0.2.0+2` 使用标签 `v0.2.0`。这一步只是暂存，不会进入 `releases/latest`。
3. 打开 Actions → **Publish stable signed release assets and update manifest**。
4. 输入：
   - `release_tag`：已有暂存 Pre-release 标签；
   - `app_version`：三段正式版本号加正整数 build，例如 `0.2.0+2`；
   - `release_notes`：每行一条更新说明。
5. validate job 会先检查：正式版本格式、标签关系、Production Supabase 三项配置、固定 Android 证书指纹、目标 Release 仍处于“已发布 Pre-release 暂存”状态、tag commit 可从 `main` 到达。任一不满足立即失败，不启动后续昂贵构建。
6. Android job 使用永久 release keystore 构建 APK，并用 `apksigner` 验证 APK 签名和证书 SHA-256 指纹；Windows job 构建完整 ZIP、updater、VC++ runtime 与 Setup EXE。
7. 工作流重新计算资产大小和 SHA-256，生成 `channel: stable` 的 `update-manifest.json` 与 `SHA256SUMS.txt`，上传到仍是 Pre-release 的暂存 Release。
8. 上传后再次从 GitHub Release API 检查五个必要资产均存在且非空：Android APK、Windows ZIP、Windows Setup EXE、`update-manifest.json`、`SHA256SUMS.txt`。资产重名、签名不符、哈希不符、文件缺失或上传中断都会停止；Release 继续保持 Pre-release，旧 Stable 不受影响。
9. **只有全部复核成功后**，工作流才把该暂存 Release 从 Pre-release 提升为 Stable，并标记为 latest；随后再次确认最终状态不是 Draft / Pre-release。
10. 成功后：新设备首次安装 Windows 使用 `*-windows-setup.exe`；已安装版本从应用内更新入口下载 ZIP 并由 updater 替换；Android 下载并校验 APK 后交给系统安装器。

## 候选包与真机验收

- Windows 候选测试优先运行 Actions → **Package Windows app**，下载生成的 installer artifact 后直接运行 Setup EXE，不把 ZIP 当成人工安装入口。
- `Package Windows app` 生成安装器前必须先通过 updater analyze/test，并把 canonical updater 与 bootstrap updater 一起装入候选包。
- 未显式指定候选版本时，Windows 打包与平台 smoke 从 `pubspec.yaml` 读取版本，避免安装器文件名、运行时版本和应用版本漂移。
- Android 功能候选可以使用 debug APK；但 debug APK **只用于功能验收**，不能证明正式覆盖升级链路。
- 需要长期保留的候选 Release 应标记 Pre-release；不要为了测试更新把 development 构建发布成 Stable latest。
- 正式 Stable 的“暂存 Pre-release”与 Development Candidate 虽然都使用 GitHub Pre-release 标志，但前者必须使用正式 `X.Y.Z+build`、Production 配置、永久签名和 stable publisher；两者不能交叉复用。

## 首次安装与验证建议

- 先安装一个较旧的、同一 Android release keystore 签名的包；再发布更高版本测试覆盖升级。
- Android 首次安装更新可能要在系统设置中打开“允许安装未知应用”，返回应用后重新点击安装。
- Windows 首次安装使用 Setup EXE；安装完成后再用更高版本验证应用内 ZIP 更新、自动重启和失败回滚。用户不应手工解压更新 ZIP。
- 更新前保留应用目录外的用户数据；更新助手只替换安装目录，不删除业务数据。
- 不要用 debug APK 验证 Android 覆盖升级；debug 签名与 release 签名不同，且不代表正式更新链路。

## 发行边界

- Development / Candidate 只允许虚构测试数据；Production / Stable 只有在 provider、迁移、权限、备份恢复、合规和真实设备 Gate 全部通过后才可启用。
- GitHub Release 资产是公开下载地址；不要把 Supabase secret、service_role、数据库密码或 Android keystore 放进仓库。
- Windows 安装器当前未做商业代码签名，SmartScreen 可能提示未知发布者；只从项目自己的 GitHub Release/Actions 产物安装。
- 软件内更新链路用 HTTPS、摘要校验、版本比较、Android 固定签名证书和 Windows 备份/回滚保证最低安全边界；这些不能替代 Production Go / No-Go 和真实设备最终验收。
