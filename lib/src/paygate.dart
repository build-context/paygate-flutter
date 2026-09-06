import 'dart:io';
import 'package:flutter/services.dart';

enum PaygatePresentationStyle {
  fullScreen,
  sheet,
}

/// Which color scheme a flow renders in.
///
/// The paywall is HTML in a WebView, and a WebView's `prefers-color-scheme`
/// follows the device — not your app. An app whose users can pick light or
/// dark independently of the OS (a `ThemeMode` setting of its own) will show a
/// paywall that disagrees with the screen behind it unless it passes its own
/// value here.
///
/// Set a default on the gate in the Paygate console; anything passed to
/// [Paygate.launchGate] overrides it.
enum PaygateAppearance {
  /// Follow the device's light/dark setting.
  system,

  /// Render light regardless of the device setting.
  light,

  /// Render dark regardless of the device setting.
  dark,
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

  /// Store product IDs (App Store on iOS, Google Play on Android) with an active entitlement.
  static Future<Set<String>> getActiveSubscriptionProductIDs() async {
    if (!(Platform.isIOS || Platform.isAndroid)) return {};
    final result = await _channel
        .invokeMethod<List<dynamic>>('getActiveSubscriptionProductIDs');
    if (result == null) return {};
    return result.map((e) => e as String).toSet();
  }

  /// Initialize the Paygate SDK with your API key.
  ///
  /// Must be called before [launchFlow] or [launchGate]. Typically called in
  /// your app's `main()`. On native platforms this starts billing listeners
  /// and loads active subscriptions.
  static Future<void> initialize({
    required String apiKey,
    String? baseURL,
  }) async {
    _apiKey = apiKey;

    if (Platform.isIOS || Platform.isAndroid) {
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
  ///
  /// [appearance] pins the flow's color scheme. Flows carry no appearance of
  /// their own — that setting lives on the gate — so this defaults to
  /// [PaygateAppearance.system], which follows the device.
  static Future<PaygateLaunchResult> launchFlow(
    String flowId, {
    bool bounces = false,
    PaygatePresentationStyle presentationStyle = PaygatePresentationStyle.sheet,
    PaygateAppearance appearance = PaygateAppearance.system,
  }) async {
    _ensureInitialized();

    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'launchFlow',
      {
        'flowId': flowId,
        'bounces': bounces,
        'presentationStyle': presentationStyle.name,
        'appearance': appearance.name,
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
  ///
  /// [appearance] overrides the appearance configured on the gate. Pass it when
  /// your app has its own light/dark setting — a WebView follows the device,
  /// not your app, so leaving it to the gate means the paywall can disagree
  /// with the screen behind it. `null` (the default) uses the gate's setting.
  static Future<PaygateLaunchResult> launchGate(
    String gateId, {
    bool bounces = false,
    PaygatePresentationStyle presentationStyle = PaygatePresentationStyle.sheet,
    PaygateAppearance? appearance,
  }) async {
    _ensureInitialized();

    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'launchGate',
      {
        'gateId': gateId,
        'bounces': bounces,
        'presentationStyle': presentationStyle.name,
        // Omitted rather than sent as "system": the native side distinguishes
        // "the app has no opinion" from "the app asked for system", and only
        // the first defers to the gate.
        if (appearance != null) 'appearance': appearance.name,
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
