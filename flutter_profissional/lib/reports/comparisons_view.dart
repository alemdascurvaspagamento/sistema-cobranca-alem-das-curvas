import 'package:flutter/material.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_store.dart';
import '../ui/cf_theme.dart';
import '../ui/motion.dart';
import '../ui/widgets.dart';
import 'comparisons.dart';

/// Comparativos: mês, trimestre, semestre ou ano, contra o período anterior
/// ou o mesmo período do ano passado, com o "por que mudou".
class ComparisonsView extends StatefulWidget {
  const ComparisonsView({super.key});

  @override
  State<ComparisonsView> createState() => _ComparisonsViewState();
}

class _ComparisonsViewState extends State<ComparisonsView> {
  final store = BillingStore.instance;
  PeriodKind kind = PeriodKind.month;
  late Period period = _startPeriod(kind);

  /// true = mesmo período do ano passado; false = período anterior.
  bool lastYear = false;

  /// Abre no último período já fechado (o mês passado, por exemplo),
  /// para não comparar um mês que mal começou com um mês inteiro.
  Period _startPeriod(PeriodKind k) {
    final closed = Period.containing(k, store.today).previous;
    return PeriodNumbers.of(closed).hasData ? closed : Period.containing(k, store.today);
  }

  void _setKind(PeriodKind k) => setState(() {
        kind = k;
        period = _startPeriod(k);
        if (k == PeriodKind.year) lastYear = false;
      });

  bool get _canGoNext => !period.next.start.isAfter(DateTime(store.today.year, store.today.month));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final basePeriod = lastYear ? period.sameLastYear : period.previous;
        final cur = PeriodNumbers.of(period);
        final base = PeriodNumbers.of(basePeriod);
        final cmp = Comparison(cur, base);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PillGrid(columns: 4, narrowColumns: 4, gap: 6, children: [
            for (final k in PeriodKind.values) Pill(label: k.label, selected: kind == k, onTap: () => _setKind(k)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            IconButton.outlined(
              tooltip: 'Período anterior',
              onPressed: () => setState(() => period = period.previous),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(period.label, textAlign: TextAlign.center, style: CF.body(19, weight: FontWeight.w800)),
            ),
            IconButton.outlined(
              tooltip: 'Próximo período',
              onPressed: _canGoNext ? () => setState(() => period = period.next) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ]),
          const SizedBox(height: 10),
          Text('Comparar com', style: CF.body(14, color: CF.muted, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (kind == PeriodKind.year)
            Pill(label: 'Ano anterior (${period.previous.short})', selected: true, onTap: () {})
          else
            PillGrid(columns: 2, narrowColumns: 2, gap: 6, children: [
              Pill(
                  label: '${capitalize(kind.noun)} anterior (${period.previous.short})',
                  selected: !lastYear,
                  onTap: () => setState(() => lastYear = false)),
              Pill(
                  label: 'Mesmo ${kind.noun} de ${period.year - 1} (${period.sameLastYear.short})',
                  selected: lastYear,
                  onTap: () => setState(() => lastYear = true)),
            ]),
          const SizedBox(height: 12),
          _VersusLine(cur: period, base: basePeriod, inProgress: period.includes(store.today)),
          const SizedBox(height: 12),
          if (!base.hasData)
            Panel(
              icon: Icons.history_rounded,
              color: CF.amber,
              title: 'Ainda sem dados de ${basePeriod.label}',
              child: Text(
                'O Léguno começou a registrar em ${monthNames[Snapshots.instance.firstMonth().month - 1]} de '
                '${Snapshots.instance.firstMonth().year}. Escolha um período mais recente para comparar, '
                'ou compare com o período anterior.',
                style: CF.body(14.5, color: CF.muted, height: 1.35),
              ),
            )
          else ...[
            _Summary(cur: cur, base: base),
            const SizedBox(height: 12),
            _Metrics(cur: cur, base: base),
            const SizedBox(height: 14),
            _DriversPanel(
              icon: Icons.south_west_rounded,
              color: CF.green,
              title: 'Por que os ganhos mudaram (${basePeriod.short} → ${period.short})',
              total: cur.income - base.income,
              drivers: cmp.incomeDrivers(),
              upIsGood: true,
              empty: 'Os ganhos ficaram iguais.',
            ),
            const SizedBox(height: 14),
            _DriversPanel(
              icon: Icons.north_east_rounded,
              color: CF.red,
              title: 'Por que os gastos mudaram (${basePeriod.short} → ${period.short})',
              total: cur.expenses - base.expenses,
              drivers: [...cmp.expenseDrivers(), ...cmp.topExpenseItems()],
              upIsGood: false,
              empty: 'Os gastos ficaram iguais.',
              splitAfter: cmp.expenseDrivers().length,
            ),
            const SizedBox(height: 14),
            _MonthByMonth(cur: cur, base: base),
            const SizedBox(height: 14),
            _Indicators(cur: cur, base: base),
          ],
          const SizedBox(height: 8),
        ]);
      },
    );
  }
}

String _signed(double v) => v >= 0 ? '+${money(v)}' : '−${money(-v)}';

String? _pct(double cur, double base) {
  if (base.abs() < 0.01) return null;
  final p = (cur - base) / base.abs() * 100;
  return '${p >= 0 ? '+' : '−'}${p.abs().toStringAsFixed(p.abs() < 10 ? 1 : 0).replaceAll('.', ',')}%';
}

/// Os números principais, lado a lado.
class _Metrics extends StatelessWidget {
  const _Metrics({required this.cur, required this.base});
  final PeriodNumbers cur, base;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, double c, double b, {bool upIsGood = true, String? hint}) {
      final d = c - b;
      final good = d == 0 ? null : (d > 0) == upIsGood;
      final color = good == null ? CF.muted : (good ? CF.green : CF.red);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CF.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CF.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$label · ${cur.period.short}', style: CF.body(13, color: CF.muted, weight: FontWeight.w700)),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: CountUpText(money(c), style: CF.score(26))),
          Text('${capitalize(base.period.short)}: ${money(b)}', style: CF.body(12.5, color: CF.muted)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(d == 0 ? Icons.remove_rounded : (d > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
                size: 16, color: color),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                '${_signed(d)}${_pct(c, b) == null ? '' : '  (${_pct(c, b)})'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CF.body(13, color: color, weight: FontWeight.w700),
              ),
            ),
          ]),
          if (hint != null) Text(hint, style: CF.body(11.5, color: CF.muted)),
        ]),
      );
    }

    final mc = cur.margin, mb = base.margin;
    final tiles = [
      tile('Ganhos', cur.income, base.income, hint: 'Recebido + extras'),
      tile('Gastos', cur.expenses, base.expenses, upIsGood: false),
      tile('Sobrou', cur.result, base.result),
      tile('Faturado', cur.billed, base.billed, hint: 'O que foi cobrado'),
      tile('Em aberto', cur.open, base.open, upIsGood: false, hint: 'Cobrado e não recebido'),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CF.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CF.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Margem · ${cur.period.short}', style: CF.body(13, color: CF.muted, weight: FontWeight.w700)),
          Text(mc == null ? '—' : '${(mc * 100).round()}%', style: CF.score(26)),
          Text('${capitalize(base.period.short)}: ${mb == null ? '—' : '${(mb * 100).round()}%'}', style: CF.body(12.5, color: CF.muted)),
          const SizedBox(height: 4),
          Text('De cada R\$ 100 que entram, quanto sobra', style: CF.body(11.5, color: CF.muted)),
        ]),
      ),
    ];
    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 900 ? 3 : 2;
      const gap = 10.0;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
    });
  }
}

/// Lista de causas, com uma barra proporcional ao tamanho de cada uma.
class _DriversPanel extends StatelessWidget {
  const _DriversPanel({
    required this.icon,
    required this.color,
    required this.title,
    required this.total,
    required this.drivers,
    required this.upIsGood,
    required this.empty,
    this.splitAfter,
  });
  final IconData icon;
  final Color color;
  final String title;
  final double total;
  final List<Driver> drivers;
  final bool upIsGood;
  final String empty;

  /// Depois de quantas linhas começa o bloco "contas que mais mudaram".
  final int? splitAfter;

  @override
  Widget build(BuildContext context) {
    final maxAbs = drivers.fold(0.0, (m, d) => d.amount.abs() > m ? d.amount.abs() : m);
    final good = total == 0 ? null : (total > 0) == upIsGood;
    Widget row(Driver d) {
      final pos = d.amount >= 0;
      final rowGood = pos == upIsGood;
      final c = rowGood ? CF.green : CF.red;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.label, style: CF.body(15, weight: FontWeight.w600)),
                if (d.detail.isNotEmpty) Text(d.detail, style: CF.body(12.5, color: CF.muted)),
              ]),
            ),
            const SizedBox(width: 8),
            Text(_signed(d.amount), style: CF.body(15, color: c, weight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          GrowingBar(
            value: maxAbs == 0 ? 0 : d.amount.abs() / maxAbs,
            minHeight: 6,
            color: c,
            backgroundColor: CF.greyBg,
          ),
        ]),
      );
    }

    return Panel(
      icon: icon,
      color: color,
      title: title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          total == 0
              ? empty
              : '${total > 0 ? 'Subiram' : 'Caíram'} ${money(total.abs())} no total.',
          style: CF.body(15, weight: FontWeight.w700, color: good == null ? CF.muted : (good ? CF.green : CF.red)),
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < drivers.length; i++) ...[
          if (splitAfter != null && i == splitAfter && i > 0) ...[
            const Divider(height: 18),
            Text('Contas que mais mudaram', style: CF.body(13, color: CF.muted, weight: FontWeight.w700)),
          ],
          row(drivers[i]),
        ],
      ]),
    );
  }
}

/// Mês a mês: ganhos e gastos de cada mês contra o mês equivalente do outro período.
class _MonthByMonth extends StatelessWidget {
  const _MonthByMonth({required this.cur, required this.base});
  final PeriodNumbers cur, base;

  @override
  Widget build(BuildContext context) {
    if (cur.perMonth.length <= 1 && base.perMonth.length <= 1) return const SizedBox.shrink();
    final n = cur.perMonth.length > base.perMonth.length ? cur.perMonth.length : base.perMonth.length;
    var maxV = 1.0;
    for (final e in [...cur.perMonth, ...base.perMonth]) {
      if (e.income > maxV) maxV = e.income;
      if (e.expenses > maxV) maxV = e.expenses;
    }
    String name(DateTime m) => '${monthNames[m.month - 1].substring(0, 3)}/${m.year % 100}';
    Widget bar(double v, Color c) => GrowingBar(value: v / maxV, minHeight: 8, color: c, backgroundColor: CF.greyBg);
    return Panel(
      icon: Icons.bar_chart_rounded,
      color: CF.blue,
      title: 'Mês a mês',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 14, runSpacing: 4, children: [
          _Legend(color: CF.green, label: 'Ganhos ${cur.period.short}'),
          _Legend(color: CF.green.withValues(alpha: .35), label: 'Ganhos ${base.period.short}'),
          _Legend(color: CF.red, label: 'Gastos ${cur.period.short}'),
          _Legend(color: CF.red.withValues(alpha: .35), label: 'Gastos ${base.period.short}'),
        ]),
        const SizedBox(height: 8),
        for (var i = 0; i < n; i++) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(
              '${i < cur.perMonth.length ? name(cur.perMonth[i].month) : '—'}  ×  ${i < base.perMonth.length ? name(base.perMonth[i].month) : '—'}',
              style: CF.body(13, weight: FontWeight.w700),
            ),
          ),
          if (i < cur.perMonth.length) _barRow(bar(cur.perMonth[i].income, CF.green), money(cur.perMonth[i].income)),
          if (i < base.perMonth.length)
            _barRow(bar(base.perMonth[i].income, CF.green.withValues(alpha: .35)), money(base.perMonth[i].income)),
          if (i < cur.perMonth.length) _barRow(bar(cur.perMonth[i].expenses, CF.red), money(cur.perMonth[i].expenses)),
          if (i < base.perMonth.length)
            _barRow(bar(base.perMonth[i].expenses, CF.red.withValues(alpha: .35)), money(base.perMonth[i].expenses)),
        ],
      ]),
    );
  }

  Widget _barRow(Widget bar, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: bar),
          const SizedBox(width: 8),
          SizedBox(width: 96, child: Text(value, textAlign: TextAlign.end, style: CF.body(12.5, color: CF.muted))),
        ]),
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: CF.body(12, color: CF.muted)),
      ]);
}

/// Indicadores do negócio, um período ao lado do outro.
class _Indicators extends StatelessWidget {
  const _Indicators({required this.cur, required this.base});
  final PeriodNumbers cur, base;

  @override
  Widget build(BuildContext context) {
    final t = BillingStore.instance.terms;
    String m(double? v) => v == null ? '—' : money(v);
    final rows = <(String, String, String)>[
      ('${capitalize(t.clients)} ativ${t.g('as', 'os')}', '${cur.activeClients}', '${base.activeClients}'),
      ('${capitalize(t.sessions)} cobrad${t.g('as', 'os')}', '${cur.lessons}', '${base.lessons}'),
      ('Valor médio por ${t.session}', m(cur.perLessonValue), m(base.perLessonValue)),
      ('Recebido por ${t.client}', m(cur.perClientIncome), m(base.perClientIncome)),
      ('Faltas não cobradas', '${cur.waived}', '${base.waived}'),
      ('${capitalize(t.sessions)} em feriado', '${cur.holidays}', '${base.holidays}'),
      ('Custo fixo', money(cur.expFixed + cur.expInstallment), money(base.expFixed + base.expInstallment)),
    ];
    return Panel(
      icon: Icons.speed_rounded,
      color: CF.violet,
      title: 'Indicadores',
      child: Column(children: [
        Row(children: [
          const Expanded(child: SizedBox()),
          SizedBox(width: 92, child: Text(cur.period.short, textAlign: TextAlign.end, style: CF.body(12.5, color: CF.muted, weight: FontWeight.w700))),
          SizedBox(width: 92, child: Text(base.period.short, textAlign: TextAlign.end, style: CF.body(12.5, color: CF.muted, weight: FontWeight.w700))),
        ]),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(child: Text(r.$1, style: CF.body(14.5))),
              SizedBox(width: 92, child: Text(r.$2, textAlign: TextAlign.end, style: CF.body(14.5, weight: FontWeight.w700))),
              SizedBox(width: 92, child: Text(r.$3, textAlign: TextAlign.end, style: CF.body(14.5, color: CF.muted))),
            ]),
          ),
      ]),
    );
  }
}

/// A frase grande do topo: o que está sendo comparado com o quê.
class _VersusLine extends StatelessWidget {
  const _VersusLine({required this.cur, required this.base, required this.inProgress});
  final Period cur, base;
  final bool inProgress;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: const Color(0xFFDDF3F5), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: cur.title, style: CF.body(19, weight: FontWeight.w800, color: CF.ink)),
              TextSpan(text: '  comparado com  ', style: CF.body(15, color: CF.muted)),
              TextSpan(text: base.title, style: CF.body(19, weight: FontWeight.w800, color: CF.brand)),
            ]),
          ),
          if (inProgress) ...[
            const SizedBox(height: 4),
            Text(
              '${cur.title} ainda não terminou: os números vão mudar até o fim do ${cur.kind.noun}.',
              style: CF.body(13, color: CF.amber, weight: FontWeight.w700),
            ),
          ],
        ]),
      );
}

/// Resumo em uma frase, antes dos números.
class _Summary extends StatelessWidget {
  const _Summary({required this.cur, required this.base});
  final PeriodNumbers cur, base;

  static String _em(Period p) => p.kind == PeriodKind.quarter || p.kind == PeriodKind.semester ? 'No ${p.title}' : 'Em ${p.title}';

  @override
  Widget build(BuildContext context) {
    final d = cur.income - base.income;
    final pct = _pct(cur.income, base.income);
    final change = d.abs() < 0.01
        ? 'o mesmo que'
        : '${money(d.abs())} a ${d > 0 ? 'mais' : 'menos'}${pct == null ? '' : ' ($pct)'} que';
    final where = _em(base.period).replaceFirst('Em', 'em').replaceFirst('No', 'no');
    return Text(
      '${_em(cur.period)} você ganhou ${money(cur.income)}, $change $where. '
      'Gastou ${money(cur.expenses)} e sobraram ${money(cur.result)}.',
      style: CF.body(15.5, weight: FontWeight.w600, height: 1.35),
    );
  }
}
