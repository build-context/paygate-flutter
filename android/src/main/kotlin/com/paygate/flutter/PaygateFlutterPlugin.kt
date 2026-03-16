package com.paygate.flutter

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

class PaygateFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pendingResult: Result? = null

    companion object {
        var apiKey: String? = null
        var baseURL: String = "http://localhost:4000"
        const val REQUEST_CODE = 9876
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.paygate.flutter/sdk")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                apiKey = call.argument<String>("apiKey")
                call.argument<String>("baseURL")?.let { baseURL = it }
                result.success(null)
            }
            "launch" -> {
                val key = apiKey
                if (key == null) {
                    result.error("NOT_INITIALIZED", "Call initialize() first", null)
                    return
                }
                val flowId = call.argument<String>("flowId")
                if (flowId == null) {
                    result.error("INVALID_ARGS", "flowId is required", null)
                    return
                }
                val act = activity
                if (act == null) {
                    result.error("NO_ACTIVITY", "No activity available", null)
                    return
                }
                pendingResult = result
                val intent = Intent(act, PaygateActivity::class.java).apply {
                    putExtra("flowId", flowId)
                    putExtra("apiKey", key)
                    putExtra("baseURL", baseURL)
                }
                act.startActivityForResult(intent, REQUEST_CODE)
            }
            else -> result.notImplemented()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_CODE) {
            val action = data?.getStringExtra("action") ?: "dismissed"
            val productId = data?.getStringExtra("productId")
            val resultMap = mutableMapOf<String, Any>("action" to action)
            if (productId != null) {
                resultMap["productId"] = productId
            }
            pendingResult?.success(resultMap)
            pendingResult = null
            return true
        }
        return false
    }

    // ActivityAware
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
