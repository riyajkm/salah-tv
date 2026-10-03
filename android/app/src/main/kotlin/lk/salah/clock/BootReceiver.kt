package lk.salah.clock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Starts the prayer clock automatically after the TV box boots (or the app is updated).
 *
 * On Android 10+ a background app may only start an activity if it holds the
 * "Display over other apps" permission, so grant that once in the TV's settings
 * (see README).
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON" -> {
                val launch = Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(launch)
            }
        }
    }
}
