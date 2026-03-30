# paygate_flutter

Flutter plugin for Paygate (iOS + Android).

## Android setup

The Android implementation depends on **`com.paygate:paygate-sdk:0.1.0`** from **Maven Local**.

From the repo root:

```bash
cd sdks/android
gradle :paygate-sdk:publishToMavenLocal
```

Your Flutter app’s `android/build.gradle` should resolve `mavenLocal()` (default template usually includes it via `allprojects.repositories`).

Then `flutter run` / `flutter build apk` as usual.

## iOS

Keep using `PaygateSDK` via CocoaPods as documented for the Swift SDK (`paygate_flutter` pod depends on `PaygateSDK`).
