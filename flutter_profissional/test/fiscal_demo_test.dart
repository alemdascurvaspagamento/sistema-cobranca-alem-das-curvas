import 'package:coachflow_profissional/fiscal/fiscal_demo.dart';
import 'package:coachflow_profissional/ui/cf_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A demonstração do Léguno Fiscal: cada aba abre sem estourar a tela,
/// e o recurso fica desligado fora do navegador (apps das lojas e testes).
void main() {
  setUp(() => CF.useGoogleFonts = false);

  test('fica desligado fora do navegador', () {
    expect(fiscalDemoEnabled, isFalse);
  });

  for (final size in const [Size(390, 900), Size(1400, 1000)]) {
    testWidgets('abas da demonstração em ${size.width.toInt()} px', (tester) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(MaterialApp(theme: CF.theme(), home: const FiscalDemoScreen()));
      await tester.pump();
      expect(find.textContaining('Demonstração'), findsWidgets);
      for (final tab in ['Emitir nota', 'Histórico', 'Configurações', 'Automação', 'Planos', 'Fechar o mês', 'Painel']) {
        await tester.tap(find.text(tab).first);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: tab);
      }
      await tester.scrollUntilVisible(find.text('Quero ser avisado'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Quero ser avisado'), findsOneWidget);
      await tester.binding.setSurfaceSize(null);
    });
  }
}
