## 0.4.0

- **`Paygate.initialize` takes `channelOverride`**, a new
  `PaygateDistributionChannel`. **On Android this is the only way to mark an
  internal-testing build**: Play tells an installed app nothing about which
  track served it, so a Play test build otherwise reports `production` and takes
  production's caching — which is how a console edit appears not to have taken.
  Pass it from a `--dart-define`, a flavor, or any build-time signal; leave it
  null everywhere else, since both platforms detect debug builds and iOS detects
  TestFlight on its own.
- **Breaking, indirectly.** The `testflight` channel is now `testing` across the
  suite. No Dart symbol changes — this plugin never named the channel — but a
  gate configured for `testflight` in the console is now configured for
  `testing`, and the API migration handles that.
- Bumps the native pins (iOS 0.4.0, Android 0.5.0). Android also gains
  install-source detection: a release build that did not come from Play now
  reports `testing` on its own, so a locally built AAB stops silently taking
  production caching.
- An unrecognized `channelOverride` name is logged and ignored on both
  platforms rather than throwing — version skew between Dart and a native pin
  must not take the paywall down.

## 0.3.0

- Bump dependencies (iOS 0.3.0, Android 0.4.0), which brings per-channel gate
  caching and storefront-aware pricing to Flutter apps. No Dart API changes:
  this plugin forwards `launchGate` to the native SDKs and never touches gate
  metadata, so both features arrive through the native pins.
- Requires a Paygate API deployed on or after 2026-09-07, since the native SDKs
  now send `Paygate-Version: 2026-09-07`.

## 0.2.1

- Bumps the Android dependency to 0.3.1, which fixes a crash at
  `Paygate.initialize` on Play Billing 8. Apps pairing this plugin with
  `in_app_purchase` were affected: that package requires `billing:8.0.0`, and
  the native SDK called an `enablePendingPurchases()` overload removed in 8.
  The result was a `NoSuchMethodError` that killed the app at launch.

## 0.2.0

- Gates can pin a flow's colour scheme. A WebView reads `prefers-color-scheme`
  from the system night mode rather than from your app, so an app with its own
  light/dark setting could show a paywall that disagreed with the screen behind
  it. The gate's `appearance` now decides, and the app can override it per
  launch — only the app knows whether it has a theme preference of its own.
- `appearance` defaults to `system`, which is exactly what every existing gate
  already does, so nothing restyles without being asked.
- Bumps the native dependencies to Android 0.3.0 and iOS 0.2.0. Android 0.3.0
  also carries the base-plan purchase fix from 0.2.0.

## 0.1.15

- Bump Android dependency to 0.2.0, which fixes subscription purchases using the
  wrong base plan. The billing flow took the first entry of Play's
  `subscriptionOfferDetails`, which spans every base plan on a subscription id
  and every offer within each — so on a subscription with more than one base plan
  the cadence charged was whatever Play listed first, and a promotional offer
  could be selected in place of the standing price.
- Products can now carry `playBasePlanId`, which pins that selection.

## 0.1.14

- Bump dependencies (iOS 0.1.8, Android 0.1.8)

## 0.1.13

- Bump dependencies (iOS 0.1.7, Android 0.1.7)
- Updates

## 0.1.12

- Rename Dart package to **`paygate_flutter`** (use `import 'package:paygate_flutter/paygate_flutter.dart'`).
- Rename CocoaPods pod to **`paygate_flutter`** to avoid conflicts with other `paygate` pods; still depends on **`Paygate`**.

## 0.1.11

- Bump dependencies (iOS 0.1.7, Android 0.1.7)

## 0.1.10

- Bump dependencies (iOS 0.1.7, Android 0.1.7)

## 0.1.9

- Bump dependencies (iOS 0.1.7, Android 0.1.7)
- Updates

## 0.1.8

- Version bump

## 0.1.7

- Automated publishing via GitHub Actions OIDC
- Add LICENSE and CHANGELOG

## 0.1.6

- Rename package from `paygate_flutter` to `paygate`
- Pin iOS dependency to `Paygate ~> 0.1`
- Pin Android dependency to `com.paygate:paygate:0.1.6`

## 0.1.5

- Initial public release
- Flutter plugin for iOS (StoreKit) and Android (Google Play Billing)
- WebView-based paywall presentation
- Gate and flow launching via `Paygate.launchGate` / `Paygate.launchFlow`
