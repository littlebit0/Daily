package com.littlebit0.dailycalendar

import android.content.Intent
import android.net.Uri
import android.app.AlertDialog
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "daily/map_launcher")
            .setMethodCallHandler { call, result ->
                if (call.method != "openLocation") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val location = call.argument<String>("location")?.trim().orEmpty()
                if (location.isEmpty()) {
                    result.error("bad_arguments", "A location is required.", null)
                    return@setMethodCallHandler
                }
                openLocation(location, result)
            }
    }

    private fun openLocation(location: String, result: MethodChannel.Result) {
        val candidates = listOfNotNull(
            mapCandidate("카카오맵", "kakaomap://search?q=${Uri.encode(location)}"),
            mapCandidate(
                "네이버지도",
                "nmap://search?query=${Uri.encode(location)}&appname=com.littlebit0.daily",
            ),
        )
        when (candidates.size) {
            0 -> {
                startActivity(Intent(Intent.ACTION_VIEW, appleWebUrl(location)))
                result.success("handled")
            }
            1 -> {
                startActivity(candidates.first().intent)
                result.success("handled")
            }
            else -> AlertDialog.Builder(this)
                .setTitle("지도에서 열기")
                .setMessage(location)
                .setItems(candidates.map { it.title }.toTypedArray()) { _, index ->
                    startActivity(candidates[index].intent)
                    result.success("handled")
                }
                .setOnCancelListener { result.success("handled") }
                .show()
        }
    }

    private fun mapCandidate(title: String, rawUrl: String): MapCandidate? {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(rawUrl))
        return if (intent.resolveActivity(packageManager) == null) null else MapCandidate(title, intent)
    }

    private fun appleWebUrl(location: String): Uri =
        Uri.parse("https://maps.apple.com/?q=${Uri.encode(location)}")

    private data class MapCandidate(val title: String, val intent: Intent)
}
