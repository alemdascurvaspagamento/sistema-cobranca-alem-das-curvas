import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../data/subscription.dart';
import 'apple_products.dart';
import 'apple_store_base.dart';
import 'billing_store.dart';

/// Compra pela Apple (StoreKit 2). Fluxo:
/// 1. a pessoa toca em Assinar → a Apple mostra a confirmação dela;
/// 2. a compra volta assinada pela Apple → mandamos ao servidor (apple-verify), que confere e libera a conta;
/// 3. só então avisamos a Apple que a compra foi entregue. Se a internet cair no meio, a Apple
///    devolve a compra na próxima abertura do app e o passo 2 se repete.
class _AppleStoreIO extends AppleStoreBase {
  final Map<String, ProductDetails> _products = {};
  bool _available = false;
  bool _busy = false;
  String? _error;
  String? _notice;
  bool _ready = false;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Timer? _restoreTimer;

  @override
  bool get available => _available;
  @override
  bool get busy => _busy;
  @override
  String? get error => _error;
  @override
  String? get notice => _notice;
  @override
  String? priceOf(String productId) => _products[productId]?.price;

  InAppPurchasePlatform get _iap => InAppPurchasePlatform.instance;
  String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    InAppPurchaseStoreKitPlatform.registerPlatform();
    await InAppPurchaseStoreKitPlatform.enableStoreKit2();
    _sub = _iap.purchaseStream.listen(_onUpdates, onError: (Object e) {
      _set(busy: false, error: 'Não foi possível falar com a App Store. Tente de novo.');
    });
  }

  void _set({bool? busy, String? error, String? notice, bool clear = false}) {
    if (busy != null) _busy = busy;
    if (clear) {
      _error = null;
      _notice = null;
    }
    if (error != null) _error = error;
    if (notice != null) _notice = notice;
    notifyListeners();
  }

  @override
  Future<void> load() async {
    if (!AppConfig.appleIap) return;
    try {
      await _init();
      _available = await _iap.isAvailable();
      if (!_available) {
        _set(error: 'A App Store não está disponível agora.');
        return;
      }
      final r = await _iap.queryProductDetails(AppleProducts.ids);
      for (final d in r.productDetails) {
        _products[d.id] = d;
      }
      if (_products.isEmpty) _available = false;
      _set(error: _products.isEmpty ? 'Os planos ainda não estão disponíveis. Tente mais tarde.' : null);
    } catch (e) {
      debugPrint('Léguno: App Store indisponível: $e');
      _available = false;
      _set(error: 'Não foi possível carregar os planos agora.');
    }
  }

  @override
  Future<void> buy(String productId) async {
    final d = _products[productId];
    if (d == null) {
      _set(error: 'Plano indisponível no momento.');
      return;
    }
    _set(busy: true, clear: true);
    try {
      // O id da conta vai junto (appAccountToken): a compra fica ligada a esta conta do Léguno.
      await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: d, applicationUserName: _uid));
    } catch (e) {
      debugPrint('Léguno: compra não iniciada: $e');
      _set(busy: false, error: 'Não foi possível iniciar a compra.');
    }
  }

  @override
  Future<void> restore() async {
    _set(busy: true, clear: true);
    _restoreTimer?.cancel();
    _restoreTimer = Timer(const Duration(seconds: 10), () {
      if (_busy) _set(busy: false, notice: 'Nenhuma assinatura encontrada para restaurar.');
    });
    try {
      await _iap.restorePurchases(applicationUserName: _uid);
    } catch (e) {
      _set(busy: false, error: 'Não foi possível restaurar agora.');
    }
  }

  Future<void> _onUpdates(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _set(busy: true);
        case PurchaseStatus.canceled:
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          _set(busy: false);
        case PurchaseStatus.error:
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          _set(busy: false, error: 'A compra não foi concluída.');
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _restoreTimer?.cancel();
          final r = await _verify(p.verificationData.serverVerificationData);
          if (r.finished && p.pendingCompletePurchase) await _iap.completePurchase(p);
          _set(busy: false, error: r.error, notice: r.error == null ? 'Assinatura ativa. Obrigado!' : null);
      }
    }
  }

  /// Manda a compra ao servidor. `finished` = pode avisar a Apple que terminou (deu certo, ou é um
  /// problema que não se resolve tentando de novo). Falha de internet deixa para a próxima abertura.
  Future<({bool finished, String? error})> _verify(String signed) async {
    final db = Supabase.instance.client;
    try {
      await db.functions.invoke('apple-verify', body: {'signedTransaction': signed});
      final data = await db.rpc('cf_my_subscription');
      BillingStore.instance.setSubscription(SubscriptionInfo.fromJson(Map<String, dynamic>.from(data as Map)));
      return (finished: true, error: null);
    } on FunctionException catch (e) {
      final msg = (e.details is Map ? (e.details as Map)['error'] : null)?.toString();
      final permanent = e.status == 400 || e.status == 403 || e.status == 409;
      return (finished: permanent, error: msg ?? 'Não foi possível confirmar a compra. Ela será conferida de novo.');
    } catch (e) {
      debugPrint('Léguno: falha ao confirmar compra: $e');
      return (finished: false, error: 'Sem internet para confirmar a compra. Ela será conferida de novo.');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _restoreTimer?.cancel();
    super.dispose();
  }
}

AppleStoreBase createAppleStore() => _AppleStoreIO();
