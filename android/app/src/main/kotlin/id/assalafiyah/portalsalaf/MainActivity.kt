package id.assalafiyah.portalsalaf

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        buatSaluranNotifikasi()
    }

    /**
     * Saluran notifikasi berprioritas tinggi (muncul di atas layar, berbunyi, tampil di layar kunci).
     * ID harus sama dengan FcmService::CHANNEL_ANDROID di API dan meta-data di AndroidManifest.xml.
     */
    private fun buatSaluranNotifikasi() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val saluran = NotificationChannel(
            "portal_salaf_penting",
            "Pemberitahuan Pondok",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Pengumuman, tagihan baru, dan status pembayaran"
            enableVibration(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }

        getSystemService(NotificationManager::class.java)?.createNotificationChannel(saluran)
    }
}
