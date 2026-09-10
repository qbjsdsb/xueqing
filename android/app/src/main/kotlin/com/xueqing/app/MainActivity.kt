package com.xueqing.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val UPDATE_CHANNEL = "com.xueqing.app/update"
        private const val UNKNOWN_SOURCES_REQUEST = 0x5841
    }

    private var pendingInstallPath: String? = null
    private var pendingInstallResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPDATE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> installApk(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun installApk(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path.isNullOrBlank()) {
            result.error("INVALID_PATH", "APK 路径为空。", null)
            return
        }

        val apk = validateUpdateApk(path, result) ?: return

        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            if (pendingInstallResult != null) {
                result.error("INSTALL_ALREADY_PENDING", "已有更新正在等待系统安装权限。", null)
                return
            }
            pendingInstallPath = apk.path
            pendingInstallResult = result
            try {
                startActivityForResult(
                    Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                        data = Uri.parse("package:$packageName")
                    },
                    UNKNOWN_SOURCES_REQUEST,
                )
            } catch (error: Exception) {
                clearPendingInstall()
                result.error("PERMISSION_SETTINGS_FAILED", error.message, null)
            }
            return
        }

        startApkInstaller(apk, result)
    }

    @Deprecated("Deprecated in Android; retained for the package-install permission round trip.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != UNKNOWN_SOURCES_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val path = pendingInstallPath
        val result = pendingInstallResult
        clearPendingInstall()
        if (path == null || result == null) {
            return
        }

        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            result.success("permission_required")
            return
        }

        val apk = validateUpdateApk(path, result) ?: return
        startApkInstaller(apk, result)
    }

    private fun clearPendingInstall() {
        pendingInstallPath = null
        pendingInstallResult = null
    }

    private fun validateUpdateApk(path: String, result: MethodChannel.Result): File? {
        val apk: File
        val updateDirectory: File
        try {
            apk = File(path).canonicalFile
            updateDirectory = File(cacheDir, "xueqing-updates").canonicalFile
        } catch (error: Exception) {
            result.error("INVALID_PATH", "APK 路径无法校验。", null)
            return null
        }

        val allowedPrefix = updateDirectory.path + File.separator
        if (!apk.path.startsWith(allowedPrefix)) {
            result.error("INVALID_PATH", "APK 不在应用更新缓存目录中。", null)
            return null
        }
        if (!apk.isFile) {
            result.error("MISSING_APK", "APK 文件不存在。", null)
            return null
        }
        return apk
    }

    private fun startApkInstaller(apk: File, result: MethodChannel.Result) {
        try {
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                apk,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success("started")
        } catch (error: Exception) {
            result.error("INSTALLER_START_FAILED", error.message, null)
        }
    }
}
