# paygate_flutter

Flutter plugin for Paygate (iOS + Android). Add it from pub.dev:

```yaml
dependencies:
  paygate_flutter: ^0.6.0
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

The plugin supports both of Flutter's iOS dependency managers. Both build the same sources and pull in the same native **`Paygate`** SDK version.

### Swift Package Manager (recommended)

Turn on Flutter's Swift Package Manager support once per machine:

```bash
flutter config --enable-swift-package-manager
```

Then `flutter run` / `flutter build ios` as usual. Flutter adds the plugin's
package (`ios/paygate_flutter/Package.swift`) to your app, and that package
resolves the native SDK from
[build-context/paygate-ios](https://github.com/build-context/paygate-ios) at the
exact version this release pins. There's no `pod install`.

### CocoaPods

Apps that stay on CocoaPods keep working with no changes. The plugin's
**`paygate_flutter`** pod depends on the native **`Paygate`** pod from CocoaPods
trunk. After upgrading, run `flutter clean` and `cd ios && pod install` so
`Podfile.lock` picks up the new version.

If an app has to pin the native pod itself, use the trunk version, for example
`pod 'Paygate', '0.6.0'`, rather than a `:git` source.
