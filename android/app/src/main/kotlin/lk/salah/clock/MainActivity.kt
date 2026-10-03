package lk.salah.clock

import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Besides hosting Flutter, exposes a few system shortcuts used by the Settings screen so
 * the app can be made the TV's default home app (auto-start at power-on) and so the TV's own
 * settings stay reachable while SalahLK is the home screen.
 */
class MainActivity : FlutterActivity() {
    private val channel = "lk.salah.clock/system"
    private val roleRequestCode = 4711

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDefaultHome" -> result.success(isDefaultHome())
                "requestHomeRole" -> result.success(requestHomeRole())
                "openHomeSettings" -> result.success(openHomeSettings())
                "canDrawOverlays" -> result.success(Settings.canDrawOverlays(this))
                "openOverlaySettings" -> result.success(
                    launch(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                )
                "openAndroidSettings" -> result.success(launch(Intent(Settings.ACTION_SETTINGS)))
                else -> result.notImplemented()
            }
        }
    }

    /** True when the system's current home app is this app. */
    private fun isDefaultHome(): Boolean {
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val info = packageManager.resolveActivity(home, PackageManager.MATCH_DEFAULT_ONLY)
        return info?.activityInfo?.packageName == packageName
    }

    /**
     * Asks Android to make this app the home app (a system dialog; the user confirms).
     * Returns "already", "requested", or "unavailable" when the system has no such dialog.
     */
    private fun requestHomeRole(): String {
        if (isDefaultHome()) return "already"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val rm = getSystemService(RoleManager::class.java)
            if (rm != null && rm.isRoleAvailable(RoleManager.ROLE_HOME)) {
                return try {
                    startActivityForResult(rm.createRequestRoleIntent(RoleManager.ROLE_HOME), roleRequestCode)
                    "requested"
                } catch (e: Exception) {
                    "unavailable"
                }
            }
        }
        return "unavailable"
    }

    /** The system screen where the default home app is chosen (not present on every TV). */
    private fun openHomeSettings(): Boolean = launch(Intent(Settings.ACTION_HOME_SETTINGS))

    private fun launch(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: Exception) {
        false
    }
}
