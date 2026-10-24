import 'package:coachflow_profissional/billing/billing_engine.dart';
import 'package:coachflow_profissional/billing/billing_screen.dart';
import 'package:coachflow_profissional/billing/billing_store.dart';
import 'package:coachflow_profissional/billing/rules_screen.dart';
import 'package:coachflow_profissional/profile/profession_profile.dart';
import 'package:coachflow_profissional/screens/agenda_screen.dart';
import 'package:coachflow_profissional/screens/clients_screen.dart';
import 'package:coachflow_profissional/screens/finance_screen.dart';
import 'package:coachflow_profissional/screens/home_screen.dart';
import 'package:coachflow_profissional/ui/cf_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta cada tela no tamanho de celular e de computador.
/// Qualquer texto ou botão que estoure a largura faz o teste falhar.
void main() {
  setUp(() => CF.useGoogleFonts = false);

  final screens = <String, Widget Function()>{
    'Início': () => HomeScreen(onAgenda: () {}, onBilling: () {}, onClients: () {}),
    'Agenda': () => const AgendaScreen(),
    'Cobranças': () => const BillingScreen(),
    'Pacientes': () => const ClientsScreen(),
    'Financeiro': () => FinanceScreen(onBilling: () {}),
    'Regras': () => const RulesScreen(),
  };

  for (final size in const [Size(390, 900), Size(1400, 1000)]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} em ${size.width.toInt()} px', (tester) async {
        BillingStore.instance.seed(professionById('personal'), BillingModel.perSession);
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(MaterialApp(
          theme: CF.theme(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: entry.value(),
            ),
          ),
        ));
        await tester.pump();
        // Se algo estourar, o próprio Flutter falha o teste mostrando o arquivo e a linha.
      });
    }
  }

  testWidgets('Agenda: visões semana e mês no computador', (tester) async {
    BillingStore.instance.seed(professionById('psico'), BillingModel.perSession);
    await tester.binding.setSurfaceSize(const Size(1400, 1400));
    await tester.pumpWidget(MaterialApp(
      theme: CF.theme(),
      home: const Scaffold(body: SingleChildScrollView(child: AgendaScreen())),
    ));
    await tester.tap(find.text('Semana'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Mês'));
    await tester.pump();
    await tester.pump();
  });
}
