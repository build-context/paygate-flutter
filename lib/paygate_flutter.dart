/// Paygate SDK for Flutter.
///
/// Present paywalls, onboarding flows, and more in your app.
///
/// Usage:
/// ```dart
/// import 'package:paygate/paygate.dart';
///
/// // Initialize the SDK
/// await Paygate.initialize(apiKey: 'your_api_key');
///
/// // Launch a flow — returns product ID or null if dismissed
/// final product = await Paygate.launch('your_flow_id');
/// ```
library paygate;

export 'src/paygate.dart';
