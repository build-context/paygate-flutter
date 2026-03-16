/// Result returned when a Paygate flow is dismissed.
class PaygateResult {
  /// The action that caused the flow to close.
  final PaygateAction action;

  /// The product ID if a purchase was initiated.
  final String? productId;

  const PaygateResult({
    required this.action,
    this.productId,
  });

  factory PaygateResult.fromMap(Map<String, dynamic> map) {
    return PaygateResult(
      action: PaygateAction.values.firstWhere(
        (e) => e.name == map['action'],
        orElse: () => PaygateAction.dismissed,
      ),
      productId: map['productId'] as String?,
    );
  }

  @override
  String toString() => 'PaygateResult(action: $action, productId: $productId)';
}

/// Actions that can cause a Paygate flow to close.
enum PaygateAction {
  /// The user dismissed the flow.
  dismissed,

  /// The user initiated a purchase.
  purchased,

  /// An error occurred.
  error,
}
