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
