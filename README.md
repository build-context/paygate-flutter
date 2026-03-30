# paygate_flutter

Flutter plugin for Paygate (iOS + Android). Add it from pub.dev:

```yaml
dependencies:
  paygate_flutter: ^0.1.12
```

```dart
import 'package:paygate_flutter/paygate_flutter.dart';
```

## Android setup

The Android implementation depends on **`com.paygate:paygate:0.1.0`** from **Maven Local**.

From the repo root:

```bash
cd sdks/android
gradle :paygate:publishToMavenLocal
```

Your Flutter app’s `android/build.gradle` should resolve `mavenLocal()` (default template usually includes it via `allprojects.repositories`).

Then `flutter run` / `flutter build apk` as usual.

## iOS

The Flutter plugin uses the CocoaPods pod **`paygate_flutter`**, which depends on the native **`Paygate`** pod (Swift SDK). After upgrading, run `flutter clean` and `cd ios && pod install` so `Podfile.lock` picks up the renamed pod.
