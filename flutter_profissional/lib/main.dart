import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'professional_agenda.dart';
import 'booking_requests.dart';
import 'calendar_connections.dart';
import 'demo_modules.dart';
import 'billing/billing_screen.dart';
import 'billing/billing_store.dart';
import 'billing/rules_screen.dart';
import 'screens/agenda_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/home_screen.dart';
import 'ui/cf_theme.dart';
import 'ui/sales_entry.dart';
import 'ui/onboarding.dart';
import 'profile/profession_profile.dart';
import 'professional_dashboard.dart';
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
        theme: CF.theme(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        home: Uri.base.queryParameters['agendar']=='demo'
      ? const BookingPublicDemo() : const CoachFlowEntry(),
      );
}

class CoachFlowEntry extends StatefulWidget {
  const CoachFlowEntry({super.key});
  @override
  State<CoachFlowEntry> createState() => _CoachFlowEntryState();
}

class _CoachFlowEntryState extends State<CoachFlowEntry> {
  bool demo = false;
  bool onboarding = false;
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
      if (onboarding) {
        return Onboarding(
          onBack: () => setState(() => onboarding = false),
          onDone: () => setState(() {
            onboarding = false;
            demo = true;
          }),
        );
      }
      return SalesEntry(onStart: () => setState(() => onboarding = true));
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

enum Section { inicio, agenda, cobrancas, clientes, financeiro, regras, mais }

extension SectionDetails on Section {
  String get label => switch (this) {
        Section.inicio => 'Início',
        Section.agenda => 'Agenda',
        Section.cobrancas => 'Cobranças',
        Section.clientes => ProfessionalProfile.instance.terms.clientsTitle,
        Section.financeiro => 'Financeiro',
        Section.regras => 'Regras e feriados',
        Section.mais => 'Configurações',
      };
  IconData get icon => switch (this) {
        Section.inicio => Icons.home_rounded,
        Section.agenda => Icons.calendar_month_rounded,
        Section.cobrancas => Icons.receipt_long_rounded,
        Section.clientes => Icons.groups_rounded,
        Section.financeiro => Icons.account_balance_wallet_rounded,
        Section.regras => Icons.rule_rounded,
        Section.mais => Icons.tune_rounded,
      };
}

/// Itens da barra inferior no celular. Os demais ficam em "Mais".
const _bottomSections = [Section.inicio, Section.agenda, Section.cobrancas, Section.clientes];

class CoachFlowShell extends StatefulWidget {
  const CoachFlowShell({super.key, this.demo = false});
  final bool demo;

  @override
  State<CoachFlowShell> createState() => _CoachFlowShellState();
}

class _CoachFlowShellState extends State<CoachFlowShell> {
  Section selected = Section.inicio;
  bool calendarSettings = false;

  void go(Section s) => setState(() {
        selected = s;
        calendarSettings = false;
      });

  void _changeProfession() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (routeContext) => Onboarding(
        onBack: () => Navigator.of(routeContext).pop(),
        onDone: () {
          Navigator.of(routeContext).pop();
          if (mounted) go(Section.inicio);
        },
      ),
    ));
  }

  void openMore() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text('Mais', style: CF.body(22, weight: FontWeight.w700)),
            ),
            for (final (section, detail) in <(Section, String)>[
              (Section.financeiro, 'Entradas, despesas e meta do mês'),
              (Section.regras, 'Faltas, feriados, remarcações e profissão'),
              (Section.mais, 'Chave Pix e sincronização de agenda'),
            ])
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: Icon(section.icon, color: CF.ink),
                title: Text(section.label, style: CF.body(17, weight: FontWeight.w700)),
                subtitle: Text(detail, style: CF.body(14, color: CF.muted)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(sheetContext);
                  go(section);
                },
              ),
          ]),
        ),
      ),
    );
  }

  Widget _content() {
    final demo = widget.demo;
    switch (selected) {
      case Section.inicio:
        return demo
            ? HomeScreen(
                onAgenda: () => go(Section.agenda),
                onBilling: () => go(Section.cobrancas),
                onClients: () => go(Section.clientes),
              )
            : ProfessionalDashboard(
                demo: false,
                onClients: () => go(Section.clientes),
                onAgenda: () => go(Section.agenda),
                onBilling: () => go(Section.cobrancas),
                onFinance: () => go(Section.financeiro),
                onSecretary: () => go(Section.inicio),
              );
      case Section.agenda:
        return demo
            ? const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AgendaScreen(),
                SizedBox(height: 18),
                BookingManagementDemo(),
              ])
            : const ProfessionalAgenda();
      case Section.cobrancas:
        return demo
            ? BillingScreen(onOpenRules: () => go(Section.regras))
            : _panel('Cobranças', 'Disponível após conectar o banco de dados.');
      case Section.clientes:
        return demo ? const ClientsScreen() : const ProfessionalClients();
      case Section.financeiro:
        return demo
            ? FinanceScreen(onBilling: () => go(Section.cobrancas))
            : _panel('Financeiro', 'Disponível após conectar o banco de dados.');
      case Section.regras:
        return demo
            ? RulesScreen(onChangeProfession: _changeProfession)
            : _panel('Regras de cobrança', 'Disponível após conectar o banco de dados.');
      case Section.mais:
        if (calendarSettings) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => calendarSettings = false),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar às configurações'),
              ),
            ),
            const CalendarConnections(),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Configurações', style: CF.body(28, weight: FontWeight.w700)),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sync_rounded, color: CF.ink),
              title: const Text('Sincronização de calendários'),
              subtitle: const Text('Apple, Google e privacidade dos compromissos'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => setState(() => calendarSettings = true),
            ),
          ),
          if (demo)
            const DemoMore()
          else
            _panel('Configurações', 'Perfil, serviços, relatórios e preferências.'),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: ProfessionalProfile.instance,
        builder: (context, _) => LayoutBuilder(builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;
          final narrowPhone = constraints.maxWidth < 380;
          final bottomIndex = _bottomSections.indexOf(selected);
          return Scaffold(
            appBar: AppBar(
              backgroundColor: CF.ink,
              foregroundColor: Colors.white,
              centerTitle: !desktop,
              automaticallyImplyLeading: false,
              title: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 30, height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: CF.lap, borderRadius: BorderRadius.circular(9)),
                  child: Text('cf', style: CF.score(18, color: CF.ink)),
                ),
                const SizedBox(width: 10),
                Text('Coach Flow', style: CF.body(19, color: Colors.white, weight: FontWeight.w700)),
                if (!narrowPhone) ...[
                  const SizedBox(width: 6),
                  Text('Profissional', style: CF.body(19, color: Colors.white60)),
                ],
              ]),
            ),
            body: Row(children: [
              if (desktop)
                NavigationRail(
                  backgroundColor: CF.ink,
                  selectedIndex: selected.index,
                  onDestinationSelected: (i) => go(Section.values[i]),
                  extended: constraints.maxWidth >= 1150,
                  indicatorColor: CF.inkSoft,
                  selectedIconTheme: const IconThemeData(color: CF.lap),
                  unselectedIconTheme: const IconThemeData(color: Color(0xFFC9D6E8)),
                  selectedLabelTextStyle: CF.body(15, color: Colors.white, weight: FontWeight.w700),
                  unselectedLabelTextStyle: CF.body(15, color: const Color(0xFFC9D6E8)),
                  destinations: [
                    for (final s in Section.values)
                      NavigationRailDestination(icon: Icon(s.icon), label: Text(s.label)),
                  ],
                ),
              Expanded(
                child: SafeArea(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: desktop ? 24 : (narrowPhone ? 12 : 16),
                      vertical: desktop ? 20 : 14,
                    ),
                    children: [
                      if (widget.demo)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text('Demonstração com dados fictícios',
                              textAlign: TextAlign.center, style: CF.body(13, color: CF.muted)),
                        ),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: _content(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
            bottomNavigationBar: desktop
                ? null
                : NavigationBar(
                    height: narrowPhone ? 66 : 72,
                    labelBehavior: narrowPhone
                        ? NavigationDestinationLabelBehavior.onlyShowSelected
                        : NavigationDestinationLabelBehavior.alwaysShow,
                    backgroundColor: CF.surface,
                    indicatorColor: CF.ink.withValues(alpha: .12),
                    selectedIndex: bottomIndex < 0 ? 4 : bottomIndex,
                    onDestinationSelected: (i) {
                      if (i == 4) {
                        openMore();
                      } else {
                        go(_bottomSections[i]);
                      }
                    },
                    destinations: [
                      for (final s in _bottomSections) NavigationDestination(icon: Icon(s.icon), label: s.label),
                      const NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'Mais'),
                    ],
                  ),
          );
        }),
      );

  Widget _panel(String title, String description) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: CF.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CF.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: CF.body(22, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(description, style: CF.body(15, color: CF.muted)),
        ]),
      );
}
