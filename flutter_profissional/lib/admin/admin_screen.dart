import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../billing/billing_engine.dart';
import '../ui/cf_theme.dart';
import '../ui/widgets.dart';
import 'admin_account.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';

int _i(Object? v) => (v as num?)?.toInt() ?? 0;
double _n(Object? v) => (v as num?)?.toDouble() ?? 0;

/// Painel do administrador do Léguno: contas, uso, funil, financeiro e suporte.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, this.api});

  /// Os testes passam um acesso falso; no app real usa o Supabase.
  final AdminApi? api;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final AdminApi api = widget.api ?? AdminApi.supabase(Supabase.instance.client);
  int tab = 0;
  int reload = 0;

  void _open(AdminAccount a) => openAccountDialog(context, api, a, () => setState(() => reload++));

  @override
  Widget build(BuildContext context) {
    final tabs = ['Visão geral', 'Contas', 'Funil', 'Financeiro', 'Suporte', 'Registro'];
    Widget body;
    switch (tab) {
      case 0:
        body = _OverviewTab(api: api, reload: reload, onOpen: _open);
      case 1:
        body = _AccountsTab(api: api, reload: reload, onOpen: _open);
      case 2:
        body = _FunnelTab(api: api);
      case 3:
        body = _FinanceTab(api: api);
      case 4:
        body = _SupportTab(api: api);
      default:
        body = _LogTab(api: api, reload: reload);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageTitle('Painel do Léguno',
          icon: Icons.admin_panel_settings_rounded,
          color: CF.ink,
          subtitle: 'Quem entrou, quem está testando e quem paga',
          trailing: IconButton(
            tooltip: 'Atualizar',
            onPressed: () => setState(() => reload++),
            icon: const Icon(Icons.refresh_rounded),
          )),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PillGrid(columns: 3, narrowColumns: 3, gap: 6, children: [
          for (var i = 0; i < tabs.length; i++)
            Pill(label: tabs[i], selected: tab == i, onTap: () => setState(() => tab = i)),
        ]),
      ),
      body,
    ]);
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.labels, required this.selected, required this.onSelect});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 6, children: [
        for (var i = 0; i < labels.length; i++)
          ChoiceChip(
            label: Text(labels[i]),
            selected: selected == i,
            onSelected: (_) => onSelect(i),
            selectedColor: CF.ink,
            labelStyle: CF.body(13.5, color: selected == i ? Colors.white : CF.muted, weight: FontWeight.w600),
            side: const BorderSide(color: CF.line),
            showCheckmark: false,
          ),
      ]);
}

// ---------------------------------------------------------------- Visão geral

class _OverviewData {
  _OverviewData(this.o, this.trials);
  final Map<String, dynamic> o;
  final List<AdminAccount> trials;
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab({required this.api, required this.reload, required this.onOpen});
  final AdminApi api;
  final int reload;
  final ValueChanged<AdminAccount> onOpen;

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  static const _periods = [7, 30, 90];
  int p = 1;

  Future<_OverviewData> _load() async {
    final r = await Future.wait([widget.api.overview(_periods[p]), widget.api.accounts(filter: 'trial')]);
    return _OverviewData(r[0] as Map<String, dynamic>, r[1] as List<AdminAccount>);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Chips(labels: const ['7 dias', '30 dias', '90 dias'], selected: p, onSelect: (i) => setState(() => p = i)),
        const SizedBox(height: 12),
        AsyncBlock<_OverviewData>(
          load: _load,
          reloadKey: '$p-${widget.reload}',
          builder: (context, d) => _content(d),
        ),
      ]);

  Widget _content(_OverviewData d) {
    final o = d.o;
    final days = _periods[p];
    final total = _i(o['total']), paying = _i(o['paying']), lateCount = _i(o['late']);
    final endingSoon = _i(o['trial_ending']);
    final weekly = (o['weekly'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final f = Map<String, dynamic>.from((o['funnel'] as Map?) ?? const {});
    final now = DateTime.now();

    final weekLabels = [for (final w in weekly) dm(DateTime.tryParse(w['week'] as String? ?? '') ?? now)];
    final weekValues = [for (final w in weekly) _n(w['n'])];
    String takeaway = 'Ainda sem contas novas nas últimas semanas.';
    if (weekValues.length >= 2) {
      final last = weekValues.last, prev = weekValues[weekValues.length - 2];
      if (last > prev) {
        takeaway = 'Esta semana teve mais contas novas que a anterior.';
      } else if (last < prev) {
        takeaway = 'Esta semana teve menos contas novas que a anterior.';
      } else if (last > 0) {
        takeaway = 'O ritmo de contas novas se manteve.';
      }
    }

    final kpis = KpiGrid(children: [
      AdminKpi(label: 'Contas', value: '$total', note: '+${_i(o['new_period'])} nos últimos $days dias', noteColor: CF.green),
      AdminKpi(
          label: 'Em teste grátis',
          value: '${_i(o['trialing'])}',
          note: endingSoon > 0 ? '$endingSoon ${endingSoon == 1 ? 'acaba' : 'acabam'} em 7 dias' : 'nenhum acaba em 7 dias',
          noteColor: endingSoon > 0 ? CF.amber : CF.muted),
      AdminKpi(
          label: 'Pagantes',
          value: '$paying',
          note: total > 0 ? '${(100 * paying / total).round()}% das contas' : 'sem contas ainda',
          noteColor: CF.green),
      AdminKpi(label: 'Receita mensal', value: moneyCompact(_n(o['mrr'])), note: 'estimada pelos planos'),
      AdminKpi(
          label: 'Em atraso',
          value: '$lateCount',
          valueColor: lateCount > 0 ? CF.red : CF.text,
          note: lateCount > 0 ? '${moneyCompact(_n(o['late_amount']))} a receber' : 'ninguém em atraso',
          noteColor: lateCount > 0 ? CF.red : CF.muted),
      AdminKpi(label: 'Ativos na semana', value: '${_i(o['active_week'])}', note: 'abriram o app nos últimos 7 dias'),
    ]);

    final weeklyPanel = Panel(
      title: 'Novas contas por semana',
      icon: Icons.person_add_alt_1_rounded,
      color: CF.blue,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(takeaway, style: CF.body(14, color: CF.muted)),
        const SizedBox(height: 10),
        BarSeries(labels: weekLabels, values: weekValues),
      ]),
    );

    final steps = _funnelSteps(f);
    final funnelPanel = Panel(
      title: 'Funil de ativação',
      icon: Icons.filter_alt_rounded,
      color: CF.lap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Das contas novas, quantas chegam em cada etapa.', style: CF.body(14, color: CF.muted)),
        const SizedBox(height: 12),
        FunnelBars(steps: steps),
      ]),
    );

    final ending = [...d.trials]..sort((a, b) => (a.trialEndsAt ?? now).compareTo(b.trialEndsAt ?? now));
    final endingPanel = Panel(
      title: 'Testes acabando',
      icon: Icons.hourglass_bottom_rounded,
      color: CF.amber,
      child: ending.where((a) => !a.internal).isEmpty
          ? Text('Nenhum teste em andamento.', style: CF.body(14.5, color: CF.muted))
          : Column(children: [
              for (final a in ending.where((a) => !a.internal).take(6)) _AccountRow(account: a, onTap: () => widget.onOpen(a), dense: true),
            ]),
    );

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 820;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        kpis,
        const SizedBox(height: 12),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 5, child: weeklyPanel),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: funnelPanel),
          ])
        else ...[weeklyPanel, const SizedBox(height: 12), funnelPanel],
        const SizedBox(height: 12),
        endingPanel,
      ]);
    });
  }
}

List<(String, int)> _funnelSteps(Map<String, dynamic> f) => [
      ('Cadastraram', _i(f['registered'])),
      ('Cadastraram cliente', _i(f['with_client'])),
      ('Cobraram o primeiro cliente', _i(f['billed'])),
      ('Assinaram', _i(f['paid'])),
    ];

// -------------------------------------------------------------------- Contas

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.onTap, this.dense = false});
  final AdminAccount account;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final a = account;
    final (label, fg, bg) = accountLook(a, now);
    final sub = [
      if (a.profession != null) a.profession!,
      '${a.clients} ${a.clients == 1 ? 'cliente' : 'clientes'}',
      a.platformLabel,
    ].where((e) => e != '—').join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: dense ? 8 : 10, horizontal: 4),
        child: LayoutBuilder(builder: (context, box) {
          final narrow = box.maxWidth < 520;
          final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.email, style: CF.body(15, weight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            Text(sub, style: CF.body(13, color: CF.muted), overflow: TextOverflow.ellipsis),
          ]);
          final right = Column(crossAxisAlignment: narrow ? CrossAxisAlignment.start : CrossAxisAlignment.end, children: [
            Wrap(spacing: 6, children: [
              StatusChip(label, fg: fg, bg: bg),
              if (a.internal) const StatusChip('interna', fg: CF.grey, bg: CF.greyBg),
            ]),
            const SizedBox(height: 3),
            Text('acesso ${sinceText(a.lastActivity, now)}', style: CF.body(12.5, color: CF.muted)),
          ]);
          return narrow
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 6), right])
              : Row(children: [Expanded(child: info), const SizedBox(width: 12), right]);
        }),
      ),
    );
  }
}

class _AccountsTab extends StatefulWidget {
  const _AccountsTab({required this.api, required this.reload, required this.onOpen});
  final AdminApi api;
  final int reload;
  final ValueChanged<AdminAccount> onOpen;

  @override
  State<_AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<_AccountsTab> {
  static const _filters = ['all', 'trial', 'paying', 'late', 'readonly', 'internal'];
  static const _labels = ['Todas', 'Em teste', 'Pagantes', 'Em atraso', 'Somente leitura', 'Internas'];
  final controller = TextEditingController();
  Timer? _debounce;
  int f = 0;
  String q = '';

  @override
  void dispose() {
    _debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _onText(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => q = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: controller,
          onChanged: _onText,
          decoration: InputDecoration(
            hintText: 'Buscar por e-mail ou profissão',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: CF.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CF.line)),
          ),
        ),
        const SizedBox(height: 10),
        _Chips(labels: _labels, selected: f, onSelect: (i) => setState(() => f = i)),
        const SizedBox(height: 12),
        AsyncBlock<List<AdminAccount>>(
          load: () => widget.api.accounts(query: q, filter: _filters[f]),
          reloadKey: '$q-$f-${widget.reload}',
          builder: (context, list) => Panel(
            title: '${list.length} ${list.length == 1 ? 'conta' : 'contas'}',
            icon: Icons.groups_rounded,
            color: CF.violet,
            child: list.isEmpty
                ? Text('Nenhuma conta com esse filtro.', style: CF.body(14.5, color: CF.muted))
                : Column(children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: CF.line),
                      _AccountRow(account: list[i], onTap: () => widget.onOpen(list[i])),
                    ],
                  ]),
          ),
        ),
      ]);
}

// --------------------------------------------------------------------- Funil

class _FunnelTab extends StatefulWidget {
  const _FunnelTab({required this.api});
  final AdminApi api;

  @override
  State<_FunnelTab> createState() => _FunnelTabState();
}

class _FunnelTabState extends State<_FunnelTab> {
  static const _days = [30, 90, 365, 3650];
  int p = 1;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Chips(labels: const ['30 dias', '90 dias', '1 ano', 'Tudo'], selected: p, onSelect: (i) => setState(() => p = i)),
        const SizedBox(height: 12),
        AsyncBlock<Map<String, dynamic>>(
          load: () => widget.api.funnel(_days[p]),
          reloadKey: p,
          builder: (context, f) {
            final steps = _funnelSteps(f);
            // Maior queda entre duas etapas seguidas.
            String hint = 'Sem contas novas neste período.';
            if (steps.first.$2 > 0) {
              var worst = 1;
              var worstRate = 2.0;
              for (var i = 1; i < steps.length; i++) {
                final prev = steps[i - 1].$2;
                final rate = prev == 0 ? 1.0 : steps[i].$2 / prev;
                if (rate < worstRate) {
                  worstRate = rate;
                  worst = i;
                }
              }
              hint = 'A maior queda é entre "${steps[worst - 1].$1}" e "${steps[worst].$1}": só ${(worstRate * 100).round()}% passam.';
            }
            return Panel(
              title: 'Funil de ativação',
              icon: Icons.filter_alt_rounded,
              color: CF.lap,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hint, style: CF.body(14.5, color: CF.muted)),
                const SizedBox(height: 14),
                FunnelBars(steps: steps),
                Text('As contas internas (suas e de teste) não entram na conta.', style: CF.body(12.5, color: CF.muted)),
              ]),
            );
          },
        ),
      ]);
}

// ----------------------------------------------------------------- Financeiro

class _FinanceTab extends StatelessWidget {
  const _FinanceTab({required this.api});
  final AdminApi api;

  static String _short(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final name = monthNames[d.month - 1];
    return '${name[0].toUpperCase()}${name.substring(1, 3)}';
  }

  @override
  Widget build(BuildContext context) => AsyncBlock<Map<String, dynamic>>(
        load: api.finance,
        builder: (context, f) {
          final real = f['source'] == 'asaas';
          final months = (f['months'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final recent = (f['recent'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final overdue = _n(f['overdue']);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!real)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: CF.amberBg, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: CF.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Estimativa pelos planos. Os pagamentos reais aparecem quando o Asaas estiver ligado.',
                        style: CF.body(14, color: CF.ink, weight: FontWeight.w600)),
                  ),
                ]),
              ),
            KpiGrid(children: [
              AdminKpi(label: 'Receita mensal', value: moneyCompact(_n(f['mrr'])), note: 'assinaturas ativas'),
              AdminKpi(label: 'Recebido no mês', value: moneyCompact(_n(f['received_month'])), valueColor: CF.green, note: real ? 'confirmado pelo Asaas' : 'sem dados do Asaas'),
              AdminKpi(label: 'A receber até o fim do mês', value: moneyCompact(_n(f['to_receive_month']))),
              AdminKpi(label: 'Em atraso', value: moneyCompact(overdue), valueColor: overdue > 0 ? CF.red : CF.text),
              AdminKpi(label: 'Cancelamentos no mês', value: '${_i(f['canceled_month'])}'),
            ]),
            const SizedBox(height: 12),
            Panel(
              title: 'Receita por mês',
              icon: Icons.bar_chart_rounded,
              color: CF.green,
              child: months.isEmpty || months.every((m) => _n(m['received']) == 0)
                  ? Text('Ainda não há pagamentos confirmados.', style: CF.body(14.5, color: CF.muted))
                  : BarSeries(
                      labels: [for (final m in months) _short(m['month'] as String? ?? '')],
                      values: [for (final m in months) _n(m['received'])],
                      valueText: (v) => moneyCompact(v),
                      color: CF.green,
                    ),
            ),
            const SizedBox(height: 12),
            Panel(
              title: 'Últimos pagamentos',
              icon: Icons.receipt_long_rounded,
              color: CF.blue,
              child: recent.isEmpty
                  ? Text('Nenhum pagamento registrado.', style: CF.body(14.5, color: CF.muted))
                  : Column(children: [
                      for (final r in recent)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text((r['email'] as String?) ?? 'conta removida', style: CF.body(14.5, weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                Text(_payStatus(r['status'] as String?), style: CF.body(12.5, color: CF.muted)),
                              ]),
                            ),
                            Text(money(_n(r['amount'])), style: CF.body(15, weight: FontWeight.w700)),
                          ]),
                        ),
                    ]),
            ),
          ]);
        },
      );

  static String _payStatus(String? s) => switch (s) {
        'received' || 'confirmed' => 'Pago',
        'pending' => 'Aguardando',
        'overdue' => 'Em atraso',
        'refunded' => 'Estornado',
        _ => s ?? '',
      };
}

// -------------------------------------------------------------------- Suporte

class _SupportTab extends StatelessWidget {
  const _SupportTab({required this.api});
  final AdminApi api;

  @override
  Widget build(BuildContext context) => AsyncBlock<List<Map<String, dynamic>>>(
        load: api.support,
        builder: (context, list) => Panel(
          title: 'Pedidos de ajuda',
          icon: Icons.support_agent_rounded,
          color: CF.violet,
          child: list.isEmpty
              ? Text('Nenhum pedido de ajuda até agora.', style: CF.body(14.5, color: CF.muted))
              : Column(children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(height: 18, color: CF.line),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((list[i]['email'] as String?) ?? '', style: CF.body(14, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(list[i]['message'] as String? ?? '', style: CF.body(14.5)),
                        const SizedBox(height: 2),
                        Text(
                          '${whenText(list[i]['created_at'])} · ${list[i]['platform'] ?? '—'}${list[i]['app_version'] == null ? '' : ' · versão ${list[i]['app_version']}'}',
                          style: CF.body(12.5, color: CF.muted),
                        ),
                      ]),
                    ),
                  ],
                ]),
        ),
      );
}

// ------------------------------------------------------------------- Registro

class _LogTab extends StatelessWidget {
  const _LogTab({required this.api, required this.reload});
  final AdminApi api;
  final int reload;

  @override
  Widget build(BuildContext context) => AsyncBlock<List<Map<String, dynamic>>>(
        load: api.log,
        reloadKey: reload,
        builder: (context, list) => Panel(
          title: 'Registro de ações',
          icon: Icons.history_rounded,
          color: CF.grey,
          child: list.isEmpty
              ? Text('Nenhuma ação feita ainda.', style: CF.body(14.5, color: CF.muted))
              : Column(children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(height: 16, color: CF.line),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${actionText(list[i]['action'] as String?, list[i]['detail'])} · ${list[i]['target'] ?? ''}',
                            style: CF.body(14.5, weight: FontWeight.w600)),
                        Text('${whenText(list[i]['created_at'])} · por ${list[i]['admin'] ?? '—'}', style: CF.body(12.5, color: CF.muted)),
                      ]),
                    ),
                  ],
                ]),
        ),
      );
}
