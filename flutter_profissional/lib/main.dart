import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() => runApp(const CoachFlowApp());

class CoachFlowApp extends StatelessWidget {
  const CoachFlowApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Coach Flow Profissional',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0B0D10),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFD8B56A),
            brightness: Brightness.dark,
            surface: const Color(0xFF1A1D22),
          ),
          textTheme: const TextTheme(
            headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
            titleLarge: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            bodyMedium: TextStyle(color: Color(0xFFCBD0D8)),
          ),
        ),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates
            .followedBy(GlobalCupertinoLocalizations.delegates)
            .followedBy(GlobalWidgetsLocalizations.delegates)
            .toList(),
        home: const CoachFlowShell(),
      );
}

enum Section { inicio, agenda, clientes, financeiro, mais }

extension SectionDetails on Section {
  String get label => switch (this) {
        Section.inicio => 'Início',
        Section.agenda => 'Agenda',
        Section.clientes => 'Clientes',
        Section.financeiro => 'Financeiro',
        Section.mais => 'Mais',
      };
  IconData get icon => switch (this) {
        Section.inicio => Icons.home_outlined,
        Section.agenda => Icons.calendar_month_outlined,
        Section.clientes => Icons.groups_outlined,
        Section.financeiro => Icons.account_balance_wallet_outlined,
        Section.mais => Icons.more_horiz,
      };
}

class CoachFlowShell extends StatefulWidget {
  const CoachFlowShell({super.key});

  @override
  State<CoachFlowShell> createState() => _CoachFlowShellState();
}

class _CoachFlowShellState extends State<CoachFlowShell> {
  Section selected = Section.inicio;
  static const gold = Color(0xFFD8B56A);
  static const silver = Color(0xFFCBD0D8);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;
          return Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF101216),
              title: Text('Coach Flow  •  ${selected.label}'),
              actions: [
                IconButton(
                  tooltip: 'Notificações (em desenvolvimento)',
                  onPressed: null,
                  icon: const Icon(Icons.notifications_none_outlined),
                ),
              ],
            ),
            body: Row(
              children: [
                if (desktop)
                  NavigationRail(
                    backgroundColor: const Color(0xFF101216),
                    selectedIndex: selected.index,
                    onDestinationSelected: (index) =>
                        setState(() => selected = Section.values[index]),
                    extended: constraints.maxWidth >= 1150,
                    indicatorColor: gold.withValues(alpha: .18),
                    selectedIconTheme: const IconThemeData(color: gold),
                    destinations: [
                      for (final section in Section.values)
                        NavigationRailDestination(
                          icon: Icon(section.icon),
                          label: Text(section.label),
                        ),
                    ],
                  ),
                Expanded(
                  child: SafeArea(
                    child: ListView(
                      padding: EdgeInsets.symmetric(
                        horizontal: desktop ? 32 : 18,
                        vertical: 24,
                      ),
                      children: [
                        Text(selected.label, style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 6),
                        const Text('Gestão inteligente para profissionais autônomos.',
                            style: TextStyle(color: silver)),
                        const SizedBox(height: 24),
                        if (selected == Section.inicio) ...[
                          _hero(),
                          const SizedBox(height: 18),
                          _metricGrid(constraints.maxWidth),
                          const SizedBox(height: 18),
                          _panel('Agenda de hoje', 'Nenhum atendimento para exibir nesta demonstração.'),
                        ] else if (selected == Section.financeiro) ...[
                          _panel('Visão financeira', 'Recebimentos, despesas, cobranças e metas.'),
                          const SizedBox(height: 16),
                          _metricGrid(constraints.maxWidth),
                          const SizedBox(height: 16),
                          _panel('Central de cobranças', 'Os dados reais serão conectados após validação do backend.'),
                        ] else if (selected == Section.agenda)
                          _panel('Agenda profissional', 'Agendamentos e histórico de atendimentos.'),
                        if (selected == Section.clientes)
                          _panel('Clientes', 'Cadastro, contatos e situação financeira.'),
                        if (selected == Section.mais)
                          _panel('Configurações', 'Perfil, serviços, relatórios e preferências.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: desktop
                ? null
                : NavigationBar(
                    backgroundColor: const Color(0xFF101216),
                    indicatorColor: gold.withValues(alpha: .20),
                    selectedIndex: selected.index,
                    onDestinationSelected: (index) =>
                        setState(() => selected = Section.values[index]),
                    destinations: [
                      for (final section in Section.values)
                        NavigationDestination(
                          icon: Icon(section.icon),
                          selectedIcon: Icon(section.icon, color: gold),
                          label: section.label,
                        ),
                    ],
                  ),
          );
        },
      );

  Widget _hero() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1C21), Color(0xFF59472B)],
          ),
          border: Border.all(color: gold.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HOJE', style: TextStyle(color: gold, letterSpacing: 2)),
            SizedBox(height: 12),
            Text('Seu negócio em movimento',
                style: TextStyle(fontSize: 27, color: Colors.white, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('Agenda, clientes e finanças em um só lugar.',
                style: TextStyle(color: silver)),
          ],
        ),
      );

  Widget _metricGrid(double width) {
    final columns = width >= 1050 ? 4 : 2;
    const metrics = [
      ('Atendimentos', '—', Icons.calendar_month_outlined),
      ('Recebido hoje', '—', Icons.account_balance_wallet_outlined),
      ('A receber', '—', Icons.trending_up),
      ('A pagar', '—', Icons.south_east),
    ];
    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: columns == 4 ? 1.65 : 1.15,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final (label, value, icon) in metrics)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D22),
              border: Border.all(color: const Color(0xFF44474F)),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: gold, size: 26),
                const Spacer(),
                Text(label.toUpperCase(),
                    style: const TextStyle(color: silver, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                Text(value,
                    style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _panel(String title, String description) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF44474F)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(color: silver)),
          ],
        ),
      );
}
