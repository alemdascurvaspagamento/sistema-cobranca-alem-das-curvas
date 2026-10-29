import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'billing/billing_engine.dart';
import 'billing/billing_screen.dart';
import 'billing/billing_store.dart';
import 'billing/rules_screen.dart';
import 'booking_requests.dart';
import 'calendar_connections.dart';
import 'config.dart';
import 'data/cloud.dart';
import 'profile/profession_profile.dart';
import 'screens/agenda_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'ui/cf_theme.dart';
import 'ui/widgets.dart';
import 'ui/idle_guard.dart';
import 'ui/login_screen.dart';
import 'ui/onboarding.dart';
import 'ui/sales_entry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.cloudEnabled) {
    try {
      await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseKey);
    } catch (e) {
      debugPrint('Coach Flow: banco indisponível ($e). Só a demonstração funciona.');
    }
  }
  runApp(const CoachFlowApp());
}

class CoachFlowApp extends StatelessWidget {
  const CoachFlowApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Coach Flow Professional',
        debugShowCheckedModeBanner: false,
        theme: CF.theme(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Uri.base.queryParameters['agendar'] == 'demo' ? const BookingPublicDemo() : const CoachFlowEntry(),
      );
}

enum _Mode { entry, demoOnboarding, demo, login, loading, cloudOnboarding, cloud, newPassword, loadError }

/// Decide o que mostrar: entrada, demonstração, login ou a conta real.
class CoachFlowEntry extends StatefulWidget {
  const CoachFlowEntry({super.key});
  @override
  State<CoachFlowEntry> createState() => _CoachFlowEntryState();
}

class _CoachFlowEntryState extends State<CoachFlowEntry> {
  _Mode mode = _Mode.entry;
  CloudService? cloud;
  StreamSubscription<AuthState>? _authSub;

  bool get _cloudReady {
    if (!AppConfig.cloudEnabled) return false;
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (!_cloudReady) return;
    final auth = Supabase.instance.client.auth;
    _authSub = auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      switch (data.event) {
        case AuthChangeEvent.passwordRecovery:
          setState(() => mode = _Mode.newPassword);
        case AuthChangeEvent.signedIn:
          if (mode == _Mode.login || mode == _Mode.entry) _load();
        case AuthChangeEvent.signedOut:
          if (mode != _Mode.login) setState(() => mode = _Mode.entry);
        default:
          break;
      }
    });
    if (auth.currentSession != null) {
      mode = _Mode.loading;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => mode = _Mode.loading);
    final service = CloudService(Supabase.instance.client);
    try {
      final hasProfile = await service.load(BillingStore.instance);
      if (!mounted) return;
      setState(() {
        cloud = service;
        mode = hasProfile ? _Mode.cloud : _Mode.cloudOnboarding;
      });
    } catch (e) {
      debugPrint('Coach Flow: falha ao carregar: $e');
      if (mounted) setState(() => mode = _Mode.loadError);
    }
  }

  /// Aviso mostrado na tela de entrar (ex.: saída por inatividade).
  String? loginNotice;

  /// A tela de entrar abre no cadastro (criar conta grátis).
  bool loginSignup = false;

  Future<void> _signOut({bool idle = false}) async {
    await cloud?.flush();
    BillingStore.instance.sink = null;
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Sem internet: a sessão local é apagada mesmo assim.
    }
    BillingStore.instance.seed(professionById('personal'), BillingModel.perSession);
    if (!mounted) return;
    setState(() {
      loginNotice = idle ? 'Por segurança, saímos da sua conta depois de 30 minutos sem uso. Entre de novo.' : null;
      mode = idle ? _Mode.login : _Mode.entry;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case _Mode.entry:
        return SalesEntry(
          onStart: () => setState(() => mode = _Mode.demoOnboarding),
          onLogin: _cloudReady
              ? () => setState(() {
                    loginSignup = false;
                    mode = _Mode.login;
                  })
              : null,
          onSignup: _cloudReady
              ? () => setState(() {
                    loginSignup = true;
                    mode = _Mode.login;
                  })
              : null,
        );
      case _Mode.demoOnboarding:
        return Onboarding(
          onBack: () => setState(() => mode = _Mode.entry),
          onDone: () => setState(() => mode = _Mode.demo),
        );
      case _Mode.demo:
        return CoachFlowShell(
          demo: true,
          onLeave: () {
            BillingStore.instance.seed(professionById('personal'), BillingModel.perSession);
            setState(() => mode = _Mode.entry);
          },
          onLogin: _cloudReady
              ? () {
                  BillingStore.instance.seed(professionById('personal'), BillingModel.perSession);
                  setState(() => mode = _Mode.login);
                }
              : null,
        );
      case _Mode.login:
        return LoginScreen(
          key: ValueKey(loginSignup),
          startSignup: loginSignup,
          notice: loginNotice,
          onBack: () => setState(() {
            loginNotice = null;
            mode = _Mode.entry;
          }),
        );
      case _Mode.newPassword:
        return NewPasswordScreen(onDone: _load);
      case _Mode.loading:
        return const _Loading();
      case _Mode.loadError:
        return _LoadError(onRetry: _load, onSignOut: _signOut);
      case _Mode.cloudOnboarding:
        return Onboarding(
          onBack: _signOut,
          onChosen: (prof, model) async {
            setState(() => mode = _Mode.loading);
            try {
              await cloud!.createProfile(BillingStore.instance, prof, model);
              if (mounted) setState(() => mode = _Mode.cloud);
            } catch (_) {
              if (mounted) setState(() => mode = _Mode.loadError);
            }
          },
          onDone: () {},
        );
      case _Mode.cloud:
        return IdleGuard(
          onTimeout: () => _signOut(idle: true),
          child: CoachFlowShell(
            cloud: cloud,
            email: Supabase.instance.client.auth.currentUser?.email,
            onLeave: _signOut,
          ),
        );
    }
  }
}

/// Faixa da demonstração: deixa claro que os dados são de exemplo.
class _DemoBanner extends StatelessWidget {
  const _DemoBanner({this.onLogin});
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(color: CF.lap, borderRadius: BorderRadius.circular(16)),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          spacing: 12,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.science_rounded, color: CF.ink, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text('Demonstração: você está vendo dados de exemplo.',
                    style: CF.body(15, color: CF.ink, weight: FontWeight.w700)),
              ),
            ]),
            if (onLogin != null)
              FilledButton.icon(
                onPressed: onLogin,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Entrar na minha conta'),
              ),
          ],
        ),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: CF.ink,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: CF.lap),
            const SizedBox(height: 18),
            Text('Carregando seus dados...', style: CF.body(17, color: Colors.white)),
          ]),
        ),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry, required this.onSignOut});
  final VoidCallback onRetry, onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: CF.ink,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off_rounded, color: CF.lap, size: 48),
                const SizedBox(height: 14),
                Text('Não foi possível carregar seus dados.', textAlign: TextAlign.center,
                    style: CF.body(20, color: Colors.white, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Confira a internet e tente de novo. Nada foi perdido.', textAlign: TextAlign.center,
                    style: CF.body(16, color: Colors.white70)),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(backgroundColor: CF.lap, foregroundColor: CF.ink),
                  child: const Text('Tentar de novo'),
                ),
                TextButton(
                  onPressed: onSignOut,
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text('Sair da conta'),
                ),
              ]),
            ),
          ),
        ),
      );
}

/// Ícone do menu em quadradinho colorido (cheio quando a seção está aberta).
class _NavBadge extends StatelessWidget {
  const _NavBadge(this.section, {required this.selected});
  final Section section;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected ? section.color : section.color.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(section.icon, size: 20, color: selected ? CF.ink : Colors.white.withValues(alpha: .92)),
      );
}

enum Section { inicio, agenda, cobrancas, clientes, financeiro, relatorios, regras, mais }

extension SectionDetails on Section {
  String get label => switch (this) {
        Section.inicio => 'Início',
        Section.agenda => 'Agenda',
        Section.cobrancas => 'Cobranças',
        Section.clientes => ProfessionalProfile.instance.terms.clientsTitle,
        Section.financeiro => 'Financeiro',
        Section.relatorios => 'Relatórios',
        Section.regras => 'Regras e feriados',
        Section.mais => 'Configurações',
      };
  Color get color => switch (this) {
        Section.inicio => CF.lap,
        Section.agenda => CF.blue,
        Section.cobrancas => CF.green,
        Section.clientes => CF.violet,
        Section.financeiro => CF.green,
        Section.relatorios => CF.violet,
        Section.regras => CF.amber,
        Section.mais => CF.muted,
      };
  IconData get icon => switch (this) {
        Section.inicio => Icons.home_rounded,
        Section.agenda => Icons.calendar_month_rounded,
        Section.cobrancas => Icons.receipt_long_rounded,
        Section.clientes => Icons.groups_rounded,
        Section.financeiro => Icons.account_balance_wallet_rounded,
        Section.relatorios => Icons.insights_rounded,
        Section.regras => Icons.rule_rounded,
        Section.mais => Icons.tune_rounded,
      };
}

/// Itens da barra inferior no celular. Os demais ficam em "Mais".
const _bottomSections = [Section.inicio, Section.agenda, Section.cobrancas, Section.clientes];

class CoachFlowShell extends StatefulWidget {
  const CoachFlowShell({super.key, this.demo = false, this.cloud, this.email, this.onLeave, this.onLogin});
  final bool demo;

  /// Demonstração: ir para a tela de entrar na conta real.
  final VoidCallback? onLogin;

  /// Conta real conectada (null na demonstração).
  final CloudService? cloud;
  final String? email;

  /// Sair da conta ou da demonstração.
  final VoidCallback? onLeave;

  @override
  State<CoachFlowShell> createState() => _CoachFlowShellState();
}

class _CoachFlowShellState extends State<CoachFlowShell> {
  Section selected = Section.inicio;
  bool calendarSettings = false;

  @override
  void initState() {
    super.initState();
    BillingStore.instance.onLocked = _showLocked;
  }

  @override
  void dispose() {
    if (BillingStore.instance.onLocked == _showLocked) BillingStore.instance.onLocked = null;
    super.dispose();
  }

  void _showLocked(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Não foi possível salvar'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              go(Section.mais);
            },
            child: const Text('Ver minha assinatura'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendi')),
        ],
      ),
    );
  }

  /// Faixa da assinatura: teste grátis, atraso ou somente leitura.
  bool _betaDismissed = false;

  /// Faixa discreta avisando que o app está em teste e como mandar sugestões.
  Widget _betaBanner() {
    if (widget.demo || _betaDismissed) return const SizedBox.shrink();
    final c = AppConfig.supportContact.trim();
    Uri? link;
    if (c.contains('@')) {
      link = Uri(scheme: 'mailto', path: c, queryParameters: {'subject': 'Coach Flow Professional: feedback'});
    } else if (c.isNotEmpty) {
      link = Uri.parse('https://wa.me/${c.replaceAll(RegExp(r'[^0-9]'), '')}');
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(color: CF.violetBg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const IconBadge(Icons.science_rounded, color: CF.violet, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Versão em teste. Achou algo estranho ou tem uma ideia? Conta pra gente.',
              style: CF.body(14, color: CF.ink, weight: FontWeight.w600, height: 1.3)),
        ),
        if (link != null)
          TextButton(
            onPressed: () => launchUrl(link!, mode: LaunchMode.externalApplication),
            child: const Text('Enviar'),
          ),
        IconButton(
          tooltip: 'Fechar',
          onPressed: () => setState(() => _betaDismissed = true),
          icon: const Icon(Icons.close_rounded, size: 18),
        ),
      ]),
    );
  }

  Widget _subscriptionBanner() {
    if (widget.demo) return const SizedBox.shrink();
    final store = BillingStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final sub = store.subscription;
        if (sub == null) return const SizedBox.shrink();
        final now = DateTime.now();
        final (String text, Color fg, Color bg, IconData icon)? look = switch (sub.state) {
          'trialing' => (
              sub.trialDaysLeft(now) <= 1
                  ? 'Último dia do teste grátis. Tudo continua liberado até o fim do dia.'
                  : 'Teste grátis: faltam ${sub.trialDaysLeft(now)} dias. Tudo liberado.',
              CF.ink,
              CF.amberBg,
              Icons.hourglass_bottom_rounded,
            ),
          'grace' => (
              'Pagamento em atraso. Seu acesso continua por mais ${sub.graceDaysLeft(now)} '
                  '${sub.graceDaysLeft(now) == 1 ? 'dia' : 'dias'}.',
              CF.red,
              CF.redBg,
              Icons.warning_amber_rounded,
            ),
          'read_only' => (
              'Modo somente leitura: você vê e baixa seus dados, mas não lança nada novo.',
              CF.red,
              CF.redBg,
              Icons.lock_rounded,
            ),
          _ => null,
        };
        if (look == null) return const SizedBox.shrink();
        final (text, fg, bg, icon) = look;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: CF.body(14.5, color: fg, weight: FontWeight.w600))),
            TextButton(
              onPressed: () => go(Section.mais),
              style: TextButton.styleFrom(foregroundColor: fg),
              child: const Text('Assinatura'),
            ),
          ]),
        );
      },
    );
  }

  void go(Section s) => setState(() {
        selected = s;
        calendarSettings = false;
      });

  void _changeProfession() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (routeContext) => Onboarding(
        onBack: () => Navigator.of(routeContext).pop(),
        // Na conta real só muda profissão e vocabulário; os dados continuam.
        onChosen: widget.demo
            ? null
            : (prof, model) {
                ProfessionalProfile.instance.choose(prof, model);
                BillingStore.instance.applyProfession(prof, model);
                Navigator.of(routeContext).pop();
              },
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
              (Section.financeiro, 'Previsão do mês, entradas e despesas'),
              (Section.relatorios, 'Meta do ano, relatório do mês e ano mês a mês'),
              (Section.regras, 'Faltas, feriados, remarcações e profissão'),
              (Section.mais, 'Chave Pix e sincronização de agenda'),
            ])
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: IconBadge(section.icon, color: section == Section.mais ? CF.ink : section.color, size: 40),
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
    switch (selected) {
      case Section.inicio:
        return HomeScreen(
          onAgenda: () => go(Section.agenda),
          onBilling: () => go(Section.cobrancas),
          onClients: () => go(Section.clientes),
          onFinance: () => go(Section.financeiro),
          onReports: () => go(Section.relatorios),
        );
      case Section.agenda:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const AgendaScreen(),
          // O link de agendamento ainda é só demonstração.
          if (widget.demo) ...[const SizedBox(height: 18), const BookingManagementDemo()],
        ]);
      case Section.cobrancas:
        return BillingScreen(onOpenRules: () => go(Section.regras));
      case Section.clientes:
        return const ClientsScreen();
      case Section.financeiro:
        return FinanceScreen(
          onBilling: () => go(Section.cobrancas),
          onReports: () => go(Section.relatorios),
        );
      case Section.relatorios:
        return const ReportsScreen();
      case Section.regras:
        return RulesScreen(onChangeProfession: _changeProfession);
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
        return SettingsScreen(
          onCalendarSync: () => setState(() => calendarSettings = true),
          email: widget.email,
          onSignOut: widget.demo ? null : widget.onLeave,
          onLeaveDemo: widget.demo ? widget.onLeave : null,
        );
    }
  }

  /// Aviso discreto quando uma gravação falha.
  Widget _syncBanner() {
    final cloud = widget.cloud;
    if (cloud == null) return const SizedBox.shrink();
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: cloud.status,
      builder: (context, st, _) {
        if (st.error == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: CF.redBg, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.cloud_off_rounded, color: CF.red),
            const SizedBox(width: 10),
            Expanded(child: Text(st.error!, style: CF.body(15, color: CF.red, weight: FontWeight.w600))),
          ]),
        );
      },
    );
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
                  Text('Professional', style: CF.body(19, color: Colors.white60)),
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
                  indicatorColor: Colors.transparent,
                  selectedIconTheme: const IconThemeData(color: CF.lap),
                  unselectedIconTheme: const IconThemeData(color: Color(0xFFC9D6E8)),
                  selectedLabelTextStyle: CF.body(15, color: Colors.white, weight: FontWeight.w700),
                  unselectedLabelTextStyle: CF.body(15, color: const Color(0xFFC9D6E8)),
                  destinations: [
                    for (final s in Section.values)
                      NavigationRailDestination(
                        icon: _NavBadge(s, selected: false),
                        selectedIcon: _NavBadge(s, selected: true),
                        label: Text(s.label),
                      ),
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
                      if (widget.demo) _DemoBanner(onLogin: widget.onLogin),
                      _betaBanner(),
                      _subscriptionBanner(),
                      _syncBanner(),
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

}
