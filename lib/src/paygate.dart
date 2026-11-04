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

/// Which kind of build this is, as far as a gate's per-channel settings care.
///
/// A gate decides per channel whether it shows and whether the SDK re-fetches
/// it on every launch, so this is what makes a console edit appear immediately
/// on a test build and stay cached for everyone else.
///
/// Normally detected for you. Pass one to [Paygate.initialize] only to override
/// that — see [Paygate.initialize]'s `channelOverride`, which on Android is the
/// only way to mark an internal-testing build.
enum PaygateDistributionChannel {
  /// A shipped build, installed from the App Store or Play.
  production,

  /// A build under test: TestFlight on iOS, and on Android an install that did
  /// not come from Play — or any build that says so via `channelOverride`.
  testing,

  /// A debuggable build. Detected natively; you should not need to pass this.
  debug,
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
  ///
  /// [channelOverride] forces the distribution channel instead of letting the
  /// native SDK work it out. **On Android this is the only way to mark an
  /// internal-testing build**, because Play tells an installed app nothing
  /// about which track served it — internal, closed, open and production all
  /// look identical from inside the app. So a Play test build reports
  /// `production` and takes production's caching, which is how a console edit
  /// appears not to have taken.
  ///
  /// Pass it from something known at build time — a flavor, a `BuildConfig`
  /// field, a `--dart-define`:
  ///
  /// ```dart
  /// await Paygate.initialize(
  ///   apiKey: '...',
  ///   channelOverride: const bool.fromEnvironment('INTERNAL_TESTING')
  ///       ? PaygateDistributionChannel.testing
  ///       : null,
  /// );
  /// ```
  ///
  /// Leave it null everywhere else. iOS detects TestFlight on its own, and
  /// both platforms detect a debug build, so an override is a claim you have
  /// to keep true rather than a setting to fill in.
  static Future<void> initialize({
    required String apiKey,
    String? baseURL,
    PaygateDistributionChannel? channelOverride,
  }) async {
    _apiKey = apiKey;

    if (Platform.isIOS || Platform.isAndroid) {
      await _channel.invokeMethod<List>('initialize', {
        'apiKey': _apiKey,
        if (baseURL != null) 'baseURL': baseURL,
        // Sent as the wire name the native enums parse, so adding a channel
        // later is a native change rather than a new bridge contract.
        if (channelOverride != null) 'channelOverride': channelOverride.name,
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

  /// Launch a gate, which shows one of its flows chosen by the configured
  /// weights. The choice is sticky: the same reader (see [setAppUserId]) gets
  /// the same flow every time, until the gate's weights change.
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

  /// Your own id for the signed-in user, or `null` to clear it.
  ///
  /// A gate shows each reader the same flow every time. Without an app user
  /// id that is per install — the native SDK keeps a random install id for
  /// it. With one, it follows the user instead: the same flow on their phone
  /// and their iPad, and after a reinstall.
  ///
  /// Setting it moves a reader **once**, from their install's flow to their
  /// user's, so call it as early as you know who they are — ideally before
  /// the first [launchGate]. Clearing it (sign-out) moves them back to the
  /// install's flow.
  ///
  /// Sent as a request header. Use an opaque id (a database key, a UUID), not
  /// an email address. Safe to call before [initialize].
  static Future<void> setAppUserId(String? appUserId) async {
    if (!(Platform.isIOS || Platform.isAndroid)) return;
    await _channel.invokeMethod<void>('setAppUserId', {
      'appUserId': appUserId,
    });
  }

  /// The random id the native SDK keeps for this install, which a gate uses
  /// to show this reader the same flow every time.
  ///
  /// Exposed only so you can log it alongside your own analytics or quote it
  /// in a support conversation. `null` off iOS and Android.
  static Future<String?> getInstallId() async {
    if (!(Platform.isIOS || Platform.isAndroid)) return null;
    return _channel.invokeMethod<String>('getInstallId');
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
