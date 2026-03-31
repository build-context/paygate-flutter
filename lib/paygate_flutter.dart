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
/// // Launch a gate (or use launchFlow for a single flow)
/// final result = await Paygate.launchGate('your_gate_id');
/// ```
library paygate_flutter;

export 'src/paygate.dart';
