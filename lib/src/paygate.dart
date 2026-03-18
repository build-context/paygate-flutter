import 'dart:io';
import 'package:flutter/services.dart';

enum PaygatePresentationStyle {
  fullScreen,
  sheet,
}

/// Returned by [Paygate.launchGate] when the current channel is not enabled for the gate.
const String channelNotEnabled = 'channel_not_enabled';

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
  ///
  /// Provide [gateIds] and/or [flowIds] to prefetch gate/flow data at launch
  /// so that [launchGate] and [launchFlow] can check subscription eligibility
  /// and present without a network round-trip.
  static Future<void> initialize({
    required String apiKey,
    String? baseURL,
    List<String>? gateIds,
    List<String>? flowIds,
  }) async {
    _apiKey = apiKey;

    if (Platform.isIOS) {
      await _channel.invokeMethod<List>('initialize', {
        'apiKey': _apiKey,
        if (baseURL != null) 'baseURL': baseURL,
        if (gateIds != null) 'gateIds': gateIds,
        if (flowIds != null) 'flowIds': flowIds,
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
  /// The native SDK fetches (or uses a prefetched) flow, checks active
  /// subscriptions, and presents the paywall only if the user does not already
  /// have an active subscription for a product in this flow.
  /// Returns the App Store product ID if purchased or already subscribed, or
  /// `null` if dismissed.
  static Future<String?> launchFlow(
    String flowId, {
    bool bounces = false,
    PaygatePresentationStyle presentationStyle = PaygatePresentationStyle.sheet,
  }) async {
    _ensureInitialized();

    final result = await _channel.invokeMethod<String?>(
      'launchFlow',
      {
        'flowId': flowId,
        'bounces': bounces,
        'presentationStyle': presentationStyle.name,
      },
    );

    return result;
  }

  /// Launch a gate, which randomly selects a flow based on configured weights.
  ///
  /// The native SDK uses a prefetched (or freshly fetched) gate flow, checks
  /// active subscriptions, and presents the paywall only if the user does not
  /// already have an active subscription for a product in that flow.
  /// Returns the App Store product ID if purchased or already subscribed,
  /// [channelNotEnabled] if the current channel is not enabled for this gate,
  /// or `null` if dismissed.
  static Future<String?> launchGate(
    String gateId, {
    bool bounces = false,
    PaygatePresentationStyle presentationStyle = PaygatePresentationStyle.sheet,
  }) async {
    _ensureInitialized();

    final result = await _channel.invokeMethod<String?>(
      'launchGate',
      {
        'gateId': gateId,
        'bounces': bounces,
        'presentationStyle': presentationStyle.name,
      },
    );

    return result;
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
