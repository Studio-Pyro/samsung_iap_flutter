import 'package:flutter/foundation.dart';
import 'package:samsung_iap_flutter_platform_interface/src/enums.dart';

/// Samsung's answer for one purchase in a `consume` or `acknowledge` batch.
///
/// A batch can partly fail: each purchase gets its own result even when the
/// call as a whole succeeds.
@immutable
class PurchaseAckResult {
  /// Creates a result.
  const new({
    required this.purchaseId,
    required this.status,
    required this.statusCode,
    required this.message,
  });

  /// The purchase this result is for.
  final String purchaseId;

  /// What happened to the purchase.
  final AckStatus status;

  /// Samsung's raw status code, for logs and for [AckStatus.unknown].
  final int statusCode;

  /// Samsung's description of the status. Not for end users.
  final String message;

  /// Whether the purchase is consumed or acknowledged, by this call or an
  /// earlier one.
  ///
  /// Use it to decide what to retry. [AckStatus.alreadyProcessed] means an
  /// earlier attempt went through, for example one that timed out, so it
  /// counts as done.
  bool get isProcessed =>
      status == AckStatus.success || status == AckStatus.alreadyProcessed;

  Object get _fields => (purchaseId, status, statusCode, message);

  @override
  bool operator ==(Object other) =>
      other is PurchaseAckResult && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;

  @override
  String toString() =>
      'PurchaseAckResult($purchaseId, ${status.name}, $statusCode)';
}
