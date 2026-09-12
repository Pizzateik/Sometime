import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../app/app_config.dart';
import 'support_purchase_service.dart';

class PlaySupportPurchaseService extends SupportPurchaseService {
  PlaySupportPurchaseService({super.enabled = AppConfig.enableSupporterPurchases});

  late final InAppPurchase _store = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _product;
  Timer? _restoreTimer;

  @override
  String? get price => _product?.price;

  @override
  bool get canPurchase =>
      enabled &&
      _product != null &&
      const {
        SupportPurchaseState.ready,
        SupportPurchaseState.canceled,
        SupportPurchaseState.error,
        SupportPurchaseState.restoredNothing,
      }.contains(state);

  @override
  Future<void> initialize() async {
    if (!enabled) {
      state = SupportPurchaseState.unavailable;
      notifyListeners();
      return;
    }
    state = SupportPurchaseState.loading;
    notifyListeners();
    _subscription = _store.purchaseStream.listen(
      _handlePurchases,
      onError: (_) {
        state = SupportPurchaseState.error;
        notifyListeners();
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
    notifyListeners();
  }

  @override
  Future<void> purchase() async {
    final product = _product;
    if (product == null || !canPurchase) return;
    state = SupportPurchaseState.purchasing;
    notifyListeners();
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        state = SupportPurchaseState.canceled;
        notifyListeners();
      }
    } catch (_) {
      state = SupportPurchaseState.error;
      notifyListeners();
    }
  }

  @override
  Future<void> restore() async {
    if (!enabled) return;
    state = SupportPurchaseState.loading;
    notifyListeners();
    try {
      await _store.restorePurchases();
      _restoreTimer?.cancel();
      _restoreTimer = Timer(const Duration(seconds: 2), () {
        if (state == SupportPurchaseState.loading) {
          state = SupportPurchaseState.restoredNothing;
          notifyListeners();
        }
      });
    } catch (_) {
      state = SupportPurchaseState.error;
      notifyListeners();
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
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
    notifyListeners();
  }

  @override
  void dispose() {
    _restoreTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
