import 'package:flutter/foundation.dart';

import '../app/app_config.dart';

enum SupportPurchaseState {
  idle,
  loading,
  ready,
  purchasing,
  success,
  canceled,
  unavailable,
  error,
  restoredNothing,
}

class SupportPurchaseService extends ChangeNotifier {
  SupportPurchaseService({this.enabled = AppConfig.enableSupporterPurchases});

  final bool enabled;
  SupportPurchaseState state = SupportPurchaseState.idle;
  VoidCallback? onEntitlementConfirmed;

  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String? get price => null;
  bool get canPurchase => false;

  Future<void> initialize() async {
    state = SupportPurchaseState.unavailable;
    _notify();
  }

  Future<void> purchase() async {}

  Future<void> restore() async {}

  @override
  void dispose() {
    _disposed = true;
    onEntitlementConfirmed = null;
    super.dispose();
  }
}
