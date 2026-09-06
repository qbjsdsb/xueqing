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
    }

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

        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            try {
                startActivity(
                    Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                        data = Uri.parse("package:$packageName")
                    },
                )
                result.success("permission_required")
            } catch (error: Exception) {
                result.error("PERMISSION_SETTINGS_FAILED", error.message, null)
            }
            return
        }

        val apk = File(path).canonicalFile
        val updateDirectory = File(cacheDir, "xueqing-updates").canonicalFile
        val allowedPrefix = updateDirectory.path + File.separator
        if (!apk.path.startsWith(allowedPrefix)) {
            result.error("INVALID_PATH", "APK 不在应用更新缓存目录中。", null)
            return
        }
        if (!apk.isFile) {
            result.error("MISSING_APK", "APK 文件不存在。", null)
            return
        }

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
