/// Paygate SDK for Flutter.
///
/// Present paywalls, onboarding flows, and more in your app.
///
/// Usage:
/// ```dart
/// import 'package:paygate_flutter/paygate_flutter.dart';
///
/// // Initialize the SDK
/// await Paygate.initialize(apiKey: 'your_api_key');
///
/// // Launch a flow — returns product ID or null if dismissed
/// final product = await Paygate.launch('your_flow_id');
/// ```
library paygate_flutter;

export 'src/paygate.dart';
