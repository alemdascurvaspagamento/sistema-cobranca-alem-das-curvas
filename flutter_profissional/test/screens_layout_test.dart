import 'package:coachflow_profissional/billing/billing_engine.dart';
import 'package:coachflow_profissional/billing/billing_screen.dart';
import 'package:coachflow_profissional/billing/billing_store.dart';
import 'package:coachflow_profissional/billing/rules_screen.dart';
import 'package:coachflow_profissional/profile/profession_profile.dart';
import 'package:coachflow_profissional/screens/agenda_screen.dart';
import 'package:coachflow_profissional/screens/clients_screen.dart';
import 'package:coachflow_profissional/screens/finance_screen.dart';
import 'package:coachflow_profissional/screens/reports_screen.dart';
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
    'Financeiro': () => FinanceScreen(onBilling: () {}, onReports: () {}),
    'Relatórios': () => const ReportsScreen(),
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

  // Setinhas de mês: o título tem que acompanhar o mês escolhido (antes ficava parado).
  for (final entry in {'Financeiro': () => FinanceScreen(onBilling: () {}, onReports: () {}), 'Relatórios': () => const ReportsScreen()}.entries) {
    for (final size in const [Size(390, 900), Size(1400, 1000)]) {
      testWidgets('${entry.key}: setinhas mudam o mês em ${size.width.toInt()} px', (tester) async {
        final store = BillingStore.instance;
        store.seed(professionById('personal'), BillingModel.perSession);
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(MaterialApp(
          theme: CF.theme(),
          home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: entry.value())),
        ));
        await tester.pump();
        String label(DateTime d) => '${capitalize(monthNames[d.month - 1])} ${d.year}';
        final start = store.selectedMonth;
        expect(find.text(label(start)), findsWidgets);
        await tester.tap(find.byTooltip('Próximo mês'));
        await tester.pump();
        final next = DateTime(start.year, start.month + 1);
        expect(find.text(label(next)), findsOneWidget);
        expect(find.text(label(start)), findsNothing);
        await tester.tap(find.byTooltip('Mês anterior'));
        await tester.tap(find.byTooltip('Mês anterior'));
        await tester.pump();
        expect(find.text(label(DateTime(start.year, start.month - 1))), findsOneWidget);
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

  for (final size in const [Size(390, 900), Size(1400, 1000)]) {
    testWidgets('Pix e calendário de despesas em ${size.width.toInt()} px', (tester) async {
      final store = BillingStore.instance;
      store.seed(professionById('personal'), BillingModel.perSession);
      store.setPixInfo(key: 'daniel@exemplo.com', name: 'Daniel Barsottini', city: 'São Paulo');
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(MaterialApp(
        theme: CF.theme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(children: [
              TextButton(onPressed: () => openPixSheet(context, store.activePlans.first), child: const Text('pix')),
              TextButton(onPressed: () => openExpenseCalendar(context, store.selectedMonth), child: const Text('cal')),
            ]),
          ),
        ),
      ));
      await tester.tap(find.text('pix'));
      await tester.pumpAndSettle();
      expect(find.text('Copiar Pix copia e cola'), findsOneWidget);
      Navigator.of(tester.element(find.text('Copiar Pix copia e cola'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('cal'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Despesas de'), findsOneWidget);
    });
  }
}

