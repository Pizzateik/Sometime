import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

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
  late final InAppPurchase _store = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _product;
  SupportPurchaseState state = SupportPurchaseState.idle;
  VoidCallback? onEntitlementConfirmed;

  bool _disposed = false;
  Timer? _restoreTimer;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String? get price => _product?.price;
  bool get canPurchase =>
      enabled &&
      !_disposed &&
      _product != null &&
      const {
        SupportPurchaseState.ready,
        SupportPurchaseState.canceled,
        SupportPurchaseState.error,
        SupportPurchaseState.restoredNothing,
      }.contains(state);

  Future<void> initialize() async {
    if (!enabled) {
      state = SupportPurchaseState.unavailable;
      _notify();
      return;
    }
    state = SupportPurchaseState.loading;
    _notify();
    _subscription = _store.purchaseStream.listen(
      _handlePurchases,
      onError: (_) {
        state = SupportPurchaseState.error;
        _notify();
      },
    );
    try {
      if (!await _store.isAvailable()) {
        state = SupportPurchaseState.unavailable;
      } else {
        final response = await _store.queryProductDetails({
          AppConfig.supporterProductId,
        });
        _product = response.productDetails.firstOrNull;
        state = _product == null || response.error != null
            ? SupportPurchaseState.unavailable
            : SupportPurchaseState.ready;
      }
    } catch (_) {
      state = SupportPurchaseState.error;
    }
    _notify();
  }

  Future<void> purchase() async {
    final product = _product;
    if (product == null || !canPurchase) return;
    state = SupportPurchaseState.purchasing;
    _notify();
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started && !_disposed) {
        state = SupportPurchaseState.canceled;
        _notify();
      }
    } catch (_) {
      state = SupportPurchaseState.error;
      _notify();
    }
  }

  Future<void> restore() async {
    if (!enabled || _disposed) return;
    state = SupportPurchaseState.loading;
    _notify();
    try {
      await _store.restorePurchases();
      if (_disposed) return;
      _restoreTimer?.cancel();
      _restoreTimer = Timer(const Duration(seconds: 2), () {
        if (!_disposed && state == SupportPurchaseState.loading) {
          state = SupportPurchaseState.restoredNothing;
          _notify();
        }
      });
    } catch (_) {
      state = SupportPurchaseState.error;
      _notify();
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (_disposed) return;
      try {
        if (purchase.productID != AppConfig.supporterProductId) continue;
        switch (purchase.status) {
          case PurchaseStatus.pending:
            state = SupportPurchaseState.purchasing;
          case PurchaseStatus.canceled:
            state = SupportPurchaseState.canceled;
          case PurchaseStatus.error:
            state = SupportPurchaseState.error;
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            state = SupportPurchaseState.success;
            onEntitlementConfirmed?.call();
        }
        if (purchase.pendingCompletePurchase) {
          await _store.completePurchase(purchase);
        }
      } catch (_) {
        state = SupportPurchaseState.error;
      }
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    onEntitlementConfirmed = null;
    _restoreTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
