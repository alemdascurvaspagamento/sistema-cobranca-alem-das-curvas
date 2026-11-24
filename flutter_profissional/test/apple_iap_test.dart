import 'package:coachflow_profissional/billing/apple_paywall.dart';
import 'package:coachflow_profissional/billing/apple_products.dart';
import 'package:coachflow_profissional/billing/apple_store_base.dart';
import 'package:coachflow_profissional/billing/billing_store.dart';
import 'package:coachflow_profissional/billing/pro_gate.dart';
import 'package:coachflow_profissional/config.dart';
import 'package:coachflow_profissional/data/subscription.dart';
import 'package:coachflow_profissional/ui/cf_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStore extends AppleStoreBase {
  final bought = <String>[];
  int restores = 0;
  @override
  bool get available => true;
  @override
  bool get busy => false;
  @override
  String? get error => null;
  @override
  String? get notice => null;
  @override
  String? priceOf(String id) => const {
        AppleProducts.essencialMensal: 'R\$ 39,90',
        AppleProducts.essencialAnual: 'R\$ 349,00',
        AppleProducts.profissionalMensal: 'R\$ 69,90',
        AppleProducts.profissionalAnual: 'R\$ 599,00',
      }[id];
  @override
  Future<void> load() async {}
  @override
  Future<void> buy(String id) async => bought.add(id);
  @override
  Future<void> restore() async => restores++;
}

/// Plano C: compra pela Apple no iPhone/iPad.
void main() {
  setUp(() => CF.useGoogleFonts = false);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AppConfig.debugAppleIap = null;
    BillingStore.instance.setSubscription(null);
  });

  test('códigos dos produtos', () {
    expect(AppleProducts.idFor('essencial', annual: false), 'br.com.alemdascurvas.coachflow.essencial.mensal');
    expect(AppleProducts.idFor('profissional', annual: true), 'br.com.alemdascurvas.coachflow.profissional.anual');
    expect(AppleProducts.planOf(AppleProducts.essencialAnual), 'essencial');
    expect(AppleProducts.isAnnual(AppleProducts.essencialAnual), isTrue);
    expect(AppleProducts.ids.length, 4);
  });

  test('iPhone: sem a chave, só a agenda; com a chave, vende pela Apple', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppConfig.debugAppleIap = false;
    expect(AppConfig.agendaOnly, isTrue);
    expect(AppConfig.appleIap, isFalse);
    expect(ProGate.canSell, isFalse);
    AppConfig.debugAppleIap = true;
    expect(AppConfig.agendaOnly, isFalse);
    expect(AppConfig.appleIap, isTrue);
    expect(ProGate.canSell, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AppConfig.appleIap, isFalse, reason: 'Android nunca usa a compra da Apple');
  });

  test('lê de onde vem a assinatura', () {
    final s = SubscriptionInfo.fromJson({'state': 'active', 'source': 'apple', 'apple_product': AppleProducts.profissionalMensal});
    expect(s.source, 'apple');
    expect(s.appleProduct, AppleProducts.profissionalMensal);
    expect(SubscriptionInfo.fromJson({'state': 'active'}).source, 'asaas');
  });

  Future<void> open(WidgetTester tester, _FakeStore store) async {
    await tester.binding.setSurfaceSize(const Size(430, 2400));
    await tester.pumpWidget(MaterialApp(theme: CF.theme(), home: ApplePaywall(store: store)));
    await tester.pump();
  }

  testWidgets('tela de planos: preços, período, compra, restaurar e termos', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppConfig.debugAppleIap = true;
    final store = _FakeStore();
    await open(tester, store);
    expect(find.text('Restaurar compras'), findsOneWidget);
    expect(find.text('Termos de uso'), findsOneWidget);
    expect(find.text('Privacidade'), findsOneWidget);
    expect(find.textContaining('renova automaticamente'), findsOneWidget);
    expect(find.textContaining('R\$ 39,90', findRichText: true), findsOneWidget);
    expect(find.textContaining('R\$ 69,90', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Assinar o Profissional'));
    expect(store.bought, [AppleProducts.profissionalMensal]);
    await tester.tap(find.text('Anual'));
    await tester.pump();
    expect(find.textContaining('R\$ 349,00', findRichText: true), findsOneWidget);
    expect(find.textContaining('por ano', findRichText: true), findsWidgets);
    await tester.tap(find.text('Assinar o Essencial'));
    expect(store.bought.last, AppleProducts.essencialAnual);
    await tester.tap(find.text('Restaurar compras'));
    expect(store.restores, 1);
    await tester.binding.setSurfaceSize(null);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('quem já paga pelo site não vê compra (evita pagar duas vezes)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppConfig.debugAppleIap = true;
    BillingStore.instance.setSubscription(
        const SubscriptionInfo(plan: 'profissional', status: 'active', state: 'active', source: 'asaas'));
    await open(tester, _FakeStore());
    expect(find.text('Sua assinatura já está ativa'), findsOneWidget);
    expect(find.textContaining('Assinar o'), findsNothing);
    await tester.binding.setSurfaceSize(null);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('quem assinou pela Apple vê o plano atual e onde gerenciar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppConfig.debugAppleIap = true;
    BillingStore.instance.setSubscription(const SubscriptionInfo(
        plan: 'profissional',
        status: 'active',
        state: 'active',
        source: 'apple',
        appleProduct: AppleProducts.profissionalMensal));
    await open(tester, _FakeStore());
    expect(find.text('Seu plano atual'), findsOneWidget);
    expect(find.text('Gerenciar assinatura'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
    debugDefaultTargetPlatformOverride = null;
  });
}
