package com.paygate.flutter

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import org.json.JSONObject

class PaygateActivity : Activity() {

    private lateinit var webView: WebView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val htmlContent = intent.getStringExtra("htmlContent") ?: ""

        webView = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.mediaPlaybackRequiresUserGesture = false

            webViewClient = WebViewClient()
            webChromeClient = WebChromeClient()

            addJavascriptInterface(PaygateBridge(), "Paygate")
        }

        setContentView(webView)

        webView.loadDataWithBaseURL(null, htmlContent, "text/html", "UTF-8", null)
    }

    private fun finishWithResult(action: String, productId: String?) {
        val resultIntent = Intent().apply {
            putExtra("action", action)
            if (productId != null) {
                putExtra("productId", productId)
            }
        }
        setResult(RESULT_OK, resultIntent)
        finish()
    }

    inner class PaygateBridge {
        @JavascriptInterface
        fun postMessage(message: String) {
            try {
                val json = JSONObject(message)
                when (json.getString("action")) {
                    "close" -> runOnUiThread { finishWithResult("dismissed", null) }
                    "purchase" -> {
                        val productId = json.optString("productId")
                        runOnUiThread {
                            finishWithResult("purchased", productId.ifEmpty { null })
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        finishWithResult("dismissed", null)
    }
}
