package com.paygate.paygate_flutter

import android.app.Activity
import android.content.Context
import com.paygate.sdk.Paygate
import com.paygate.sdk.PaygateLaunchResult
import com.paygate.sdk.PaygateLaunchStatus
import com.paygate.sdk.PaygatePresentationStyle
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class PaygateFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.paygate.flutter/sdk")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> handleInitialize(call, result)
            "launchFlow" -> handleLaunchFlow(call, result)
            "launchGate" -> handleLaunchGate(call, result)
            "purchase" -> handlePurchase(call, result)
            "getActiveSubscriptionProductIDs" -> handleGetActive(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleInitialize(call: MethodCall, result: MethodChannel.Result) {
        val apiKey = call.argument<String>("apiKey") ?: ""
        val baseURL = call.argument<String>("baseURL")
        val ctx = applicationContext ?: run {
            result.error("NO_CONTEXT", "No application context", null)
            return
        }
        scope.launch {
            try {
                Paygate.initialize(ctx, apiKey, baseURL)
                val active = Paygate.getActiveSubscriptionProductIds()
                result.success(active.toList())
            } catch (e: Exception) {
                result.error("INIT_ERROR", e.message, null)
            }
        }
    }

    private fun handleLaunchFlow(call: MethodCall, result: MethodChannel.Result) {
        val flowId = call.argument<String>("flowId") ?: run {
            result.error("INVALID_ARGS", "flowId is required", null)
            return
        }
        val bounces = call.argument<Boolean>("bounces") ?: false
        val presentationStyle = call.argument<String>("presentationStyle") ?: "sheet"
        val act = activity ?: run {
            result.error("NO_ACTIVITY", "No Activity", null)
            return
        }
        scope.launch {
            try {
                val style = parsePresentationStyle(presentationStyle)
                val launchResult = Paygate.launchFlow(act, flowId, bounces, style)
                result.success(launchResultToMap(launchResult))
            } catch (e: Exception) {
                result.error("LAUNCH_ERROR", e.message, null)
            }
        }
    }

    private fun handleLaunchGate(call: MethodCall, result: MethodChannel.Result) {
        val gateId = call.argument<String>("gateId") ?: run {
            result.error("INVALID_ARGS", "gateId is required", null)
            return
        }
        val bounces = call.argument<Boolean>("bounces") ?: false
        val presentationStyle = call.argument<String>("presentationStyle") ?: "sheet"
        val act = activity ?: run {
            result.error("NO_ACTIVITY", "No Activity", null)
            return
        }
        scope.launch {
            try {
                val style = parsePresentationStyle(presentationStyle)
                val launchResult = Paygate.launchGate(act, gateId, bounces, style)
                result.success(launchResultToMap(launchResult))
            } catch (e: Exception) {
                result.error("LAUNCH_ERROR", e.message, null)
            }
        }
    }

    private fun handlePurchase(call: MethodCall, result: MethodChannel.Result) {
        val productId = call.argument<String>("productId") ?: run {
            result.error("INVALID_ARGS", "productId is required", null)
            return
        }
        val act = activity ?: run {
            result.error("NO_ACTIVITY", "No Activity", null)
            return
        }
        scope.launch {
            try {
                val purchased = Paygate.purchase(act, productId)
                val active = Paygate.getActiveSubscriptionProductIds()
                if (purchased != null) {
                    result.success(
                        mapOf(
                            "action" to "purchased",
                            "productId" to purchased,
                            "activeSubscriptionProductIDs" to active.toList()
                        )
                    )
                } else {
                    result.success(
                        mapOf(
                            "action" to "cancelled",
                            "activeSubscriptionProductIDs" to active.toList()
                        )
                    )
                }
            } catch (e: Exception) {
                result.error("PURCHASE_ERROR", e.message, null)
            }
        }
    }

    private fun handleGetActive(call: MethodCall, result: MethodChannel.Result) {
        if (applicationContext == null) {
            result.error("NO_CONTEXT", "No application context", null)
            return
        }
        scope.launch {
            try {
                val active = Paygate.getActiveSubscriptionProductIds()
                result.success(active.toList())
            } catch (e: Exception) {
                result.error("ERROR", e.message, null)
            }
        }
    }

    private fun parsePresentationStyle(value: String): PaygatePresentationStyle =
        if (value == "fullScreen") PaygatePresentationStyle.FULL_SCREEN
        else PaygatePresentationStyle.SHEET

    private fun launchResultToMap(r: PaygateLaunchResult): Map<String, Any?> {
        val m = mutableMapOf<String, Any?>("status" to statusToDartName(r.status))
        r.productId?.let { m["productId"] = it }
        r.data?.let { m["data"] = it }
        return m
    }

    private fun statusToDartName(s: PaygateLaunchStatus): String = when (s) {
        PaygateLaunchStatus.PURCHASED -> "purchased"
        PaygateLaunchStatus.ALREADY_SUBSCRIBED -> "alreadySubscribed"
        PaygateLaunchStatus.DISMISSED -> "dismissed"
        PaygateLaunchStatus.SKIPPED -> "skipped"
        PaygateLaunchStatus.CHANNEL_NOT_ENABLED -> "channelNotEnabled"
        PaygateLaunchStatus.PLAN_LIMIT_REACHED -> "planLimitReached"
    }
}
