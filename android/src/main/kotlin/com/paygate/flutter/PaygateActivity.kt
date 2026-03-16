package com.paygate.flutter

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class PaygateActivity : Activity() {

    private lateinit var webView: WebView
    private var flowId: String = ""
    private var apiKey: String = ""
    private var baseURL: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        flowId = intent.getStringExtra("flowId") ?: ""
        apiKey = intent.getStringExtra("apiKey") ?: ""
        baseURL = intent.getStringExtra("baseURL") ?: "http://localhost:4000"

        webView = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.mediaPlaybackRequiresUserGesture = false

            webViewClient = WebViewClient()
            webChromeClient = WebChromeClient()

            addJavascriptInterface(PaygateBridge(), "Paygate")
        }

        setContentView(webView)

        // Fetch and load flow content
        Thread {
            try {
                val url = URL("$baseURL/api/sdk/flows/$flowId")
                val conn = url.openConnection() as HttpURLConnection
                conn.setRequestProperty("X-API-Key", apiKey)
                conn.requestMethod = "GET"

                if (conn.responseCode == 200) {
                    val reader = BufferedReader(InputStreamReader(conn.inputStream))
                    val response = reader.readText()
                    reader.close()

                    val json = JSONObject(response)
                    val htmlContent = json.getString("htmlContent")

                    runOnUiThread {
                        webView.loadDataWithBaseURL(
                            baseURL,
                            htmlContent,
                            "text/html",
                            "UTF-8",
                            null
                        )
                    }
                } else {
                    finishWithResult("error", null)
                }
            } catch (e: Exception) {
                e.printStackTrace()
                finishWithResult("error", null)
            }
        }.start()
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

    private fun trackEvent(eventType: String, metadata: Map<String, String>) {
        Thread {
            try {
                val url = URL("$baseURL/api/sdk/flows/$flowId/events")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("X-API-Key", apiKey)
                conn.setRequestProperty("Content-Type", "application/json")
                conn.doOutput = true

                val body = JSONObject().apply {
                    put("eventType", eventType)
                    put("metadata", JSONObject(metadata as Map<*, *>))
                }

                conn.outputStream.use { os ->
                    os.write(body.toString().toByteArray())
                }
                conn.responseCode // trigger the request
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    inner class PaygateBridge {
        @JavascriptInterface
        fun postMessage(message: String) {
            try {
                val json = JSONObject(message)
                val action = json.getString("action")

                when (action) {
                    "close" -> {
                        runOnUiThread { finishWithResult("dismissed", null) }
                    }
                    "purchase" -> {
                        val productId = json.optString("productId")
                        trackEvent("purchase_initiated", if (productId.isNotEmpty()) mapOf("productId" to productId) else emptyMap())
                        runOnUiThread { finishWithResult("purchased", productId) }
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
