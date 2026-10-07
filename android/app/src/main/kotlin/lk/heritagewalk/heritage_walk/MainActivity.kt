package lk.heritagewalk.heritage_walk

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "heritagewalk/auth_configuration")
            .setMethodCallHandler { call, result ->
                if (call.method == "facebookConfigured") {
                    result.success(resources.getBoolean(R.bool.facebook_configured))
                } else {
                    result.notImplemented()
                }
            }
    }
}
