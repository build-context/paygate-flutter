import 'package:flutter/services.dart';
import 'paygate_result.dart';

/// Main entry point for the Paygate SDK.
///
/// Initialize with [initialize], then present flows with [launch].
class Paygate {
  static const MethodChannel _channel = MethodChannel('com.paygate.flutter/sdk');

  /// Initialize the Paygate SDK with your API key.
  ///
  /// Must be called before [launch]. Typically called in your app's `main()`.
  ///
  /// [apiKey] - Your Paygate API key from the dashboard.
  /// [baseURL] - Optional custom API base URL. Defaults to production.
  static Future<void> initialize({
    required String apiKey,
    String? baseURL,
  }) async {
    await _channel.invokeMethod('initialize', {
      'apiKey': apiKey,
      if (baseURL != null) 'baseURL': baseURL,
    });
  }

  /// Launch a Paygate flow.
  ///
  /// Presents a full-screen modal with the flow content.
  /// Returns a [PaygateResult] when the flow is dismissed.
  ///
  /// [flowId] - The ID of the flow to present (from the Paygate dashboard).
  static Future<PaygateResult> launch({required String flowId}) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'launch',
      {'flowId': flowId},
    );

    if (result != null) {
      return PaygateResult.fromMap(result);
    }

    return const PaygateResult(action: PaygateAction.dismissed);
  }
}
