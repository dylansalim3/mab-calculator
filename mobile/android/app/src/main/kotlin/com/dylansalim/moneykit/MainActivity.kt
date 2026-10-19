package com.dylansalim.moneykit

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "moneykit/app")
            .setMethodCallHandler { call, result ->
                if (call.method == "info") {
                    val versionName = packageManager.getPackageInfo(packageName, 0).versionName
                    result.success(
                        mapOf(
                            "versionName" to versionName,
                            "apkPath" to applicationInfo.sourceDir,
                        )
                    )
                } else {
                    result.notImplemented()
                }
            }
    }
}
