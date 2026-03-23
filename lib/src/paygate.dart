import 'dart:io';
import 'package:flutter/services.dart';

enum PaygatePresentationStyle {
  fullScreen,
  sheet,
}

/// Status returned from [Paygate.launchFlow] and [Paygate.launchGate].
enum PaygateLaunchStatus {
  purchased,
  alreadySubscribed,
  dismissed,
  skipped,
  channelNotEnabled,
  /// Monthly presentation quota exceeded for this project (`data` may include `used` and `limit`).
  planLimitReached,
}

/// Typed result from [Paygate.launchFlow] and [Paygate.launchGate].
class PaygateLaunchResult {
  final PaygateLaunchStatus status;
  final String? productId;
  final Map<String, dynamic>? data;

  const PaygateLaunchResult({
    required this.status,
    this.productId,
    this.data,
  });

  static PaygateLaunchResult fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const PaygateLaunchResult(status: PaygateLaunchStatus.dismissed);
    }
    final statusStr = map['status'] as String? ?? 'dismissed';
    final status = PaygateLaunchStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => PaygateLaunchStatus.dismissed,
    );
    return PaygateLaunchResult(
      status: status,
      productId: map['productId'] as String?,
      data: map['data'] != null
          ? Map<String, dynamic>.from(map['data'] as Map)
          : null,
    );
  }
}

class Paygate {
  static const MethodChannel _channel =
      MethodChannel('com.paygate.flutter/sdk');

  /// Date-based API version (Stripe-style). Matches the backend and native SDKs.
  static const String apiVersion = '2025-03-16';

  static String? _apiKey;

  /// The set of App Store product IDs for which the user has an active subscription.
  /// iOS only.
  static Future<Set<String>> getActiveSubscriptionProductIDs() async {
    if (!Platform.isIOS) return {};
    final result = await _channel
        .invokeMethod<List<dynamic>>('getActiveSubscriptionProductIDs');
    if (result == null) return {};
    return result.map((e) => e as String).toSet();
  }

  /// Initialize the Paygate SDK with your API key.
  ///
  /// Must be called before [launchFlow] or [launchGate]. Typically called in
  /// your app's `main()`. On iOS this also starts the StoreKit 2 transaction
  /// listener and loads the user's active subscriptions.
  static Future<void> initialize({
    required String apiKey,
    String? baseURL,
  }) async {
    _apiKey = apiKey;

    if (Platform.isIOS) {
      await _channel.invokeMethod<List>('initialize', {
        'apiKey': _apiKey,
        if (baseURL != null) 'baseURL': baseURL,
      });
    }
  }

  /// Purchase a product directly by its Paygate product ID.
  ///
  /// The native layer resolves the App Store product ID from the backend,
  /// then triggers the in-app purchase flow.
  /// Returns the store product ID on success, or `null` if the user cancelled.
  static Future<String?> purchase(String productId) async {
    _ensureInitialized();

    final result = await _channel.invokeMapMethod<String, dynamic>('purchase', {
      'productId': productId,
    });

    if (result == null) return null;

    final action = result['action'] as String?;
    final purchasedId = result['productId'] as String?;

    if (action == 'purchased' && purchasedId != null) {
      return purchasedId;
    }

    return null;
  }

  /// Launch a paywall flow.
  ///
  /// The native SDK fetches the flow, checks active subscriptions, and
  /// presents the paywall only if the user does not already have an active
  /// subscription for a product in this flow.
  /// Returns a typed result with status, optional productId, and optional data.
  static Future<PaygateLaunchResult> launchFlow(
    String flowId, {
    bool bounces = false,
    PaygatePresentationStyle presentationStyle = PaygatePresentationStyle.sheet,
  }) async {
    _ensureInitialized();

    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'launchFlow',
      {
        'flowId': flowId,
        'bounces': bounces,
        'presentationStyle': presentationStyle.name,
      },
    );

    return PaygateLaunchResult.fromMap(result);
  }

  /// Launch a gate, which randomly selects a flow based on configured weights.
  ///
  /// The native SDK fetches the gate flow (or uses cached content when the gate
  /// is configured for cache-on-first-launch), checks active subscriptions,
  /// and presents the paywall only if the user does not already have an
  /// active subscription for a product in that flow.
  /// Returns a typed result with status, optional productId, and optional data.
  static Future<PaygateLaunchResult> launchGate(
    String gateId, {
    bool bounces = false,
    PaygatePresentationStyle presentationStyle = PaygatePresentationStyle.sheet,
  }) async {
    _ensureInitialized();

    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'launchGate',
      {
        'gateId': gateId,
        'bounces': bounces,
        'presentationStyle': presentationStyle.name,
      },
    );

    return PaygateLaunchResult.fromMap(result);
  }

  static void _ensureInitialized() {
    if (_apiKey == null) {
      throw PlatformException(
        code: 'NOT_INITIALIZED',
        message: 'Call Paygate.initialize() first.',
      );
    }
  }
}
