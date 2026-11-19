import 'package:coachflow_profissional/billing/billing_engine.dart';
import 'package:coachflow_profissional/billing/billing_store.dart';
import 'package:coachflow_profissional/billing/pro_gate.dart';
import 'package:coachflow_profissional/data/subscription.dart';
import 'package:coachflow_profissional/profile/profession_profile.dart';
import 'package:coachflow_profissional/screens/settings_screen.dart';
import 'package:coachflow_profissional/config.dart';
import 'package:coachflow_profissional/ui/cf_theme.dart';
import 'package:coachflow_profissional/ui/legal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Revisão da Apple: nos apps das lojas não pode aparecer assinatura, plano, preço
/// nem teste grátis (não vendemos pela loja). A política de privacidade precisa dizer
/// que não usamos inteligência artificial de terceiros.
void main() {
  setUp(() => CF.useGoogleFonts = false);

  const proibidas = ['assinatura', 'assinar', 'assine', 'plano', 'r\$', 'teste grátis', 'asaas', 'renova'];

  String allText(WidgetTester tester) =>
      tester.widgetList<Text>(find.byType(Text, skipOffstage: false)).map((t) => t.data ?? '').join('\n').toLowerCase();

  Future<String> legalText(WidgetTester tester, LegalDoc doc) async {
    await tester.binding.setSurfaceSize(const Size(800, 20000));
    await tester.pumpWidget(MaterialApp(theme: CF.theme(), home: LegalScreen(doc)));
    await tester.pump();
    final t = allText(tester);
    await tester.binding.setSurfaceSize(null);
    return t;
  }

  testWidgets('iPhone: termos e privacidade sem falar de assinatura', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      expect(AppConfig.hidePricing, isTrue);
      for (final doc in LegalDoc.values) {
        final t = await legalText(tester, doc);
        for (final w in proibidas) {
          expect(t.contains(w), isFalse, reason: '"$w" aparece em ${doc.name}');
        }
      }
      final priv = await legalText(tester, LegalDoc.privacy);
      expect(priv.contains('inteligência artificial'), isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iPhone: trava de recurso sem falar de plano', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(MaterialApp(
        theme: CF.theme(),
        home: Builder(builder: (ctx) => TextButton(onPressed: () => ProGate.showProDialog(ctx, 'Relatórios'), child: const Text('abrir'))),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      final t = allText(tester);
      expect(t.contains('plano'), isFalse);
      expect(t.contains('ver planos'), isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('web: a política também fala de inteligência artificial', (tester) async {
    final t = await legalText(tester, LegalDoc.privacy);
    expect(t.contains('inteligência artificial'), isTrue);
  });

  testWidgets('iPhone: Configurações com conta paga não falam de plano nem de assinatura', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final store = BillingStore.instance;
    // Aviso antigo só de modo de teste (efeito de toque escondido nos cartões); não afeta o app.
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('ink splashes may be invisible')) return;
      original?.call(d);
    };
    try {
      store.seed(professionById('personal'), BillingModel.perSession);
      for (final state in ['active', 'trialing', 'grace', 'read_only']) {
        store.setSubscription(SubscriptionInfo(plan: 'profissional', status: state == 'active' ? 'active' : 'trialing', state: state, founder: true));
        await tester.binding.setSurfaceSize(const Size(800, 6000));
        await tester.pumpWidget(MaterialApp(
          theme: CF.theme(),
          home: const Scaffold(body: SingleChildScrollView(child: SettingsScreen())),
        ));
        await tester.pump();
        final t = allText(tester);
        for (final w in proibidas) {
          expect(t.contains(w), isFalse, reason: '"$w" aparece em Configurações ($state)');
        }
        expect(t.contains('fundador'), isFalse);
        expect(t.contains('profissional'), isFalse, reason: 'nome do plano em Configurações ($state)');
      }
    } finally {
      FlutterError.onError = original;
      store.setSubscription(null);
      await tester.binding.setSurfaceSize(null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
