import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'professional_agenda.dart';
import 'demo_mode.dart';
import 'demo_modules.dart';
import 'demo_billing.dart';
import 'professional_dashboard.dart';
import 'professional_secretary.dart';
import 'professional_clients.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(url: url, anonKey: key);
  }
  runApp(const CoachFlowApp());
}

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
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        home: const CoachFlowEntry(),
      );
}

class CoachFlowEntry extends StatefulWidget {
  const CoachFlowEntry({super.key});
  @override
  State<CoachFlowEntry> createState() => _CoachFlowEntryState();
}

class _CoachFlowEntryState extends State<CoachFlowEntry> {
  bool demo = false;
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (demo) return const CoachFlowShell(demo: true);
    if (const String.fromEnvironment('SUPABASE_URL').isEmpty ||
        const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY').isEmpty) {
      return Scaffold(body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(padding: const EdgeInsets.all(24), child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_outlined, size: 64, color: Color(0xFFD8B56A)),
            const SizedBox(height: 18),
            const Text('Coach Flow Profissional', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Explore o dashboard e a agenda com dados fictícios, sem conectar nenhum banco.',
              textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: () => setState(() => demo = true),
              icon: const Icon(Icons.play_arrow), label: const Text('Entrar na demonstração')),
            const SizedBox(height: 16),
            const Text('MODO DEMONSTRAÇÃO • Nenhum dado real será alterado',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFFD8B56A))),
          ],
        )),
      )));
    }
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (auth.currentSession != null) return const CoachFlowShell();
        return Scaffold(body: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(padding: const EdgeInsets.all(24), child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Coach Flow Profissional', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(controller: email, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail')),
              const SizedBox(height: 12),
              TextField(controller: password, obscureText: true,
                decoration: const InputDecoration(labelText: 'Senha')),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 12),
                child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
              const SizedBox(height: 20),
              FilledButton(onPressed: busy ? null : () async {
                setState(() { busy = true; error = null; });
                try {
                  await auth.signInWithPassword(email: email.text.trim(), password: password.text);
                } catch (_) {
                  if (mounted) setState(() => error = 'Não foi possível entrar. Confira suas credenciais.');
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              }, child: Text(busy ? 'Entrando...' : 'Entrar')),
            ],
          )),
        )));
      },
    );
  }
}

enum Section { inicio, clientes, cobrancas, financeiro, agenda, secretaria, mais }

extension SectionDetails on Section {
  String get label => switch (this) {
        Section.inicio => 'Início',
        Section.agenda => 'Agenda',
        Section.secretaria => 'Secretária',
        Section.clientes => 'Clientes',
        Section.cobrancas => 'Cobranças',
        Section.financeiro => 'Financeiro',
        Section.mais => 'Mais',
      };
  IconData get icon => switch (this) {
        Section.inicio => Icons.home_outlined,
        Section.agenda => Icons.calendar_month_outlined,
        Section.secretaria => Icons.support_agent_outlined,
        Section.clientes => Icons.groups_outlined,
        Section.cobrancas => Icons.receipt_long_outlined,
        Section.financeiro => Icons.account_balance_wallet_outlined,
        Section.mais => Icons.more_horiz,
      };
}

class CoachFlowShell extends StatefulWidget {
  const CoachFlowShell({super.key, this.demo = false});
  final bool demo;

  @override
  State<CoachFlowShell> createState() => _CoachFlowShellState();
}

class _CoachFlowShellState extends State<CoachFlowShell> {
  Section selected = Section.inicio;
  static const gold = Color(0xFFD8B56A);
  static const silver = Color(0xFFCBD0D8);

  void newClient() {
    setState(() => selected = Section.clientes);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Em Clientes, selecione Novo cliente para abrir o cadastro.')));
  }

  void openMore() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1D22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Mais opções', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            for (final entry in <(Section, String, IconData)>[
              (Section.agenda, 'Calendário e atendimentos', Icons.calendar_month_outlined),
              (Section.secretaria, 'Secretária inteligente', Icons.support_agent_outlined),
              (Section.mais, 'Configurações e relatórios', Icons.tune_outlined),
            ])
              ListTile(
                leading: Icon(entry.$3, color: gold),
                title: Text(entry.$2),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => selected = entry.$1);
                },
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;
          return Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF101216),
              centerTitle: !desktop,
              leading: desktop ? null : IconButton(
                tooltip:'Abrir opções',icon:const Icon(Icons.menu_rounded),onPressed:openMore),
              title: desktop ? Text('Coach Flow  •  ${selected.label}') :
                const Column(mainAxisSize:MainAxisSize.min,children:[
                  Text('Coach Flow',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
                  Text('PROFISSIONAL',style:TextStyle(fontSize:9,letterSpacing:1.6,
                    color:gold)),
                ]),
              bottom: null,
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
                        horizontal: desktop ? 32 : 12,
                        vertical: desktop ? 24 : 12,
                      ),
                      children: [
                        if (widget.demo) const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text('DEMONSTRAÇÃO • DADOS FICTÍCIOS',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: gold,fontSize: 10,letterSpacing: 1))),
                        if (selected == Section.inicio) ...[
                          ProfessionalDashboard(demo: widget.demo, onClients: newClient, onAgenda: () => setState(() => selected = Section.agenda), onBilling: () => setState(() => selected = Section.cobrancas), onFinance: () => setState(() => selected = Section.financeiro)),
                        ],
                        if (selected == Section.cobrancas)
                          widget.demo ? const DemoBilling() :
                            _panel('Cobranças', 'Cobranças reais disponíveis após integração segura com o banco.'),
                        if (selected == Section.financeiro)
                          widget.demo ? const DemoFinance() :
                            _panel('Visão financeira', 'Recebimentos, despesas, cobranças e metas.'),
                        if (selected == Section.agenda)
                          widget.demo ? const DemoAgenda() : const ProfessionalAgenda(),
                        if (selected == Section.clientes)
                          widget.demo ? const DemoClients() : const ProfessionalClients(),
                        if (selected == Section.secretaria)
                          ProfessionalSecretary(demo:widget.demo,
                            onAgenda:()=>setState(()=>selected=Section.agenda),
                            onBilling:()=>setState(()=>selected=Section.cobrancas),
                            onClients:()=>setState(()=>selected=Section.clientes),
                            onFinance:()=>setState(()=>selected=Section.financeiro)),
                        if (selected == Section.mais)
                          widget.demo ? const DemoMore() :
                            _panel('Configurações', 'Perfil, serviços, relatórios e preferências.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: desktop ? null : NavigationBar(
              height: 72,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              backgroundColor: const Color(0xFF101216),
              indicatorColor: gold.withValues(alpha: .18),
              selectedIndex: switch (selected) {
                Section.inicio => 0,
                Section.clientes => 1,
                Section.cobrancas => 2,
                Section.financeiro => 3,
                _ => 4,
              },
              onDestinationSelected: (index) {
                if (index == 4) { openMore(); return; }
                setState(() => selected = [
                  Section.inicio, Section.clientes,
                  Section.cobrancas, Section.financeiro,
                ][index]);
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Início'),
                NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Clientes'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Cobranças'),
                NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Financeiro'),
                NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Mais'),
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
      ('Atendimentos', '4', Icons.calendar_month_outlined),
      ('Recebido hoje', 'R\$ 510', Icons.account_balance_wallet_outlined),
      ('A receber', 'R\$ 370', Icons.trending_up),
      ('A pagar', 'R\$ 120', Icons.south_east),
    ];
    final shownMetrics = widget.demo ? metrics : [
      for (final (label, _, icon) in metrics) (label, '—', icon),
    ];
    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: columns == 4 ? 1.65 : 1.15,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final (label, value, icon) in shownMetrics)
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

  Widget _demoToday() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Agenda de hoje', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    for (final a in DemoData.appointments)
      Card(color: const Color(0xFF1A1D22), child: ListTile(
        leading: const Icon(Icons.event, color: gold),
        title: Text(a.client), subtitle: Text(a.service),
        trailing: Text(a.hour, style: const TextStyle(color: gold)),
      )),
  ]);

  Widget _demoClients() => Column(children: [
    for (final (name, service, status) in DemoData.clients)
      Card(color: const Color(0xFF1A1D22), child: ListTile(
        leading: const Icon(Icons.person_outline, color: gold),
        title: Text(name), subtitle: Text(service),
        trailing: Text(status, style: const TextStyle(color: silver, fontSize: 11)),
      )),
  ]);

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
