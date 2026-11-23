import 'package:coachflow_profissional/config.dart';
import 'package:coachflow_profissional/fiscal/fiscal_demo.dart';
import 'package:coachflow_profissional/ui/cf_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Léguno Fiscal (demonstração) nos apps: só para contas de teste, sem plano nem preço.
void main() {
  setUp(() => CF.useGoogleFonts = false);

  String allText(WidgetTester tester) =>
      tester.widgetList<Text>(find.byType(Text, skipOffstage: false)).map((t) => t.data ?? '').join('\n').toLowerCase();

  testWidgets('iPhone: desligado por padrão, ligado só para conta de teste', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      expect(AppConfig.hidePricing, isTrue);
      fiscalBetaAllowed.value = false;
      expect(fiscalDemoEnabled, isFalse);
      fiscalBetaAllowed.value = true;
      expect(fiscalDemoEnabled, isTrue);
    } finally {
      fiscalBetaAllowed.value = false;
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iPhone: demonstração sem aba Planos e sem falar de plano, assinatura ou Asaas', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.binding.setSurfaceSize(const Size(430, 4000));
      await tester.pumpWidget(MaterialApp(theme: CF.theme(), home: const FiscalDemoScreen()));
      await tester.pump();
      expect(find.text('Planos'), findsNothing);
      for (final tab in ['Painel', 'Emitir nota', 'Histórico', 'Configurações', 'Automação', 'Fechar o mês']) {
        await tester.tap(find.text(tab).first);
        await tester.pump();
        final t = allText(tester);
        for (final w in ['plano', 'assinatura', 'asaas', '19,90', '29,90', 'teste grátis']) {
          expect(t.contains(w), isFalse, reason: '"$w" aparece na aba $tab');
        }
      }
    } finally {
      await tester.binding.setSurfaceSize(null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
