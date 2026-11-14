import 'package:flutter/material.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_store.dart';
import '../ui/cf_theme.dart';
import '../ui/widgets.dart';
import 'comparisons.dart';

/// Aba só de gráficos: o período que você escolher contra o anterior (ou o mesmo do ano passado).
/// Cada gráfico traz uma frase dizendo o que ele mostra.
class ChartsView extends StatefulWidget {
  const ChartsView({super.key});

  @override
  State<ChartsView> createState() => _ChartsViewState();
}

class _ChartsViewState extends State<ChartsView> {
  final store = BillingStore.instance;
  PeriodKind kind = PeriodKind.month;
  late Period period = _start(kind);
  bool lastYear = false;

  Period _start(PeriodKind k) {
    final closed = Period.containing(k, store.today).previous;
    return PeriodNumbers.of(closed).hasData ? closed : Period.containing(k, store.today);
  }

  void _setKind(PeriodKind k) => setState(() {
        kind = k;
        period = _start(k);
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
            Expanded(child: Text(period.label, textAlign: TextAlign.center, style: CF.body(19, weight: FontWeight.w800))),
            IconButton.outlined(
              tooltip: 'Próximo período',
              onPressed: _canGoNext ? () => setState(() => period = period.next) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ]),
          const SizedBox(height: 8),
          if (kind == PeriodKind.year)
            Pill(label: 'Comparado com ${period.previous.short}', selected: true, onTap: () {})
          else
            PillGrid(columns: 2, narrowColumns: 2, gap: 6, children: [
              Pill(label: 'Contra ${period.previous.short}', selected: !lastYear, onTap: () => setState(() => lastYear = false)),
              Pill(label: 'Contra ${period.sameLastYear.short}', selected: lastYear, onTap: () => setState(() => lastYear = true)),
            ]),
          const SizedBox(height: 12),
          if (!cur.hasData)
            const EmptyNote(icon: Icons.bar_chart_rounded, text: 'Ainda não há números neste período.')
          else ...[
            _Compare(cur: cur, base: base, hasBase: base.hasData),
            const SizedBox(height: 14),
            _PerMonth(cur: cur),
            const SizedBox(height: 14),
            _Result(cur: cur),
            const SizedBox(height: 14),
            _Where(cur: cur),
          ],
          const SizedBox(height: 8),
        ]);
      },
    );
  }
}

String _pctText(double cur, double base) {
  if (base.abs() < 0.01) return '';
  final p = (cur - base) / base.abs() * 100;
  return '${p >= 0 ? '+' : '−'}${p.abs().toStringAsFixed(p.abs() < 10 ? 1 : 0).replaceAll('.', ',')}%';
}

class _Take extends StatelessWidget {
  const _Take(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(text, style: CF.body(14.5, color: CF.text, height: 1.35, weight: FontWeight.w600)),
      );
}

class _Key extends StatelessWidget {
  const _Key(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: CF.body(12.5, color: CF.muted)),
      ]);
}

/// Uma barra vertical com valor em cima.
Widget _col(double v, double max, Color c, {double height = 130}) {
  final h = max <= 0 ? 0.0 : (v.abs() / max * height).clamp(0, height).toDouble();
  return Container(
    height: h < 2 && v != 0 ? 2 : h,
    decoration: BoxDecoration(color: c, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
  );
}

/// 1. Ganhos, gastos e resultado: o período contra a base.
class _Compare extends StatelessWidget {
  const _Compare({required this.cur, required this.base, required this.hasBase});
  final PeriodNumbers cur, base;
  final bool hasBase;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, double, double, Color)>[
      ('Ganhos', cur.income, base.income, CF.green),
      ('Gastos', cur.expenses, base.expenses, CF.red),
      ('Sobra', cur.result, base.result, CF.blue),
    ];
    var max = 1.0;
    for (final r in rows) {
      if (r.$2.abs() > max) max = r.$2.abs();
      if (hasBase && r.$3.abs() > max) max = r.$3.abs();
    }
    Widget bar(double v, Color c) => Row(children: [
          Expanded(
            child: LayoutBuilder(
              builder: (_, box) => Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 14,
                  width: (v.abs() / max * box.maxWidth).clamp(2, box.maxWidth).toDouble(),
                  decoration: BoxDecoration(color: v < 0 ? CF.red : c, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 92, child: Text(money(v), textAlign: TextAlign.end, style: CF.body(12.5, color: CF.muted))),
        ]);
    String take;
    final g = _pctText(cur.income, base.income);
    if (!hasBase) {
      take = 'Sem dados do período de comparação. Os ganhos foram ${money(cur.income)}.';
    } else if (cur.income > base.income + .005) {
      take = 'Os ganhos subiram${g.isEmpty ? '' : ' $g'} (${money(cur.income - base.income)} a mais).';
    } else if (cur.income < base.income - .005) {
      take = 'Os ganhos caíram${g.isEmpty ? '' : ' ${g.replaceFirst('−', '')}'} (${money(base.income - cur.income)} a menos).';
    } else {
      take = 'Os ganhos ficaram iguais.';
    }
    if (hasBase && cur.expenses > base.expenses + .005) take += ' Os gastos também subiram ${money(cur.expenses - base.expenses)}.';
    if (hasBase && cur.expenses < base.expenses - .005) take += ' Os gastos caíram ${money(base.expenses - cur.expenses)}.';
    return Panel(
      icon: Icons.compare_arrows_rounded,
      color: CF.blue,
      title: 'Ganhos, gastos e sobra',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 14, children: [_Key(CF.ink, cur.period.short), if (hasBase) _Key(CF.muted.withValues(alpha: .5), base.period.short)]),
        for (final r in rows) ...[
          Padding(padding: const EdgeInsets.only(top: 10, bottom: 3), child: Text(r.$1, style: CF.body(13.5, weight: FontWeight.w700))),
          bar(r.$2, r.$4),
          if (hasBase) Padding(padding: const EdgeInsets.only(top: 3), child: bar(r.$3, r.$4.withValues(alpha: .4))),
        ],
        _Take(take),
      ]),
    );
  }
}

/// 2. Ganhos e gastos mês a mês (colunas).
class _PerMonth extends StatelessWidget {
  const _PerMonth({required this.cur});
  final PeriodNumbers cur;

  @override
  Widget build(BuildContext context) {
    final pm = cur.perMonth;
    if (pm.length < 2) return const SizedBox.shrink();
    var max = 1.0;
    for (final m in pm) {
      if (m.income > max) max = m.income;
      if (m.expenses > max) max = m.expenses;
    }
    final best = pm.reduce((a, b) => a.income >= b.income ? a : b);
    final worst = pm.reduce((a, b) => a.income <= b.income ? a : b);
    String nm(DateTime m) => monthNames[m.month - 1].substring(0, 3);
    return Panel(
      icon: Icons.bar_chart_rounded,
      color: CF.green,
      title: 'Mês a mês',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 14, children: const [_Key(CF.green, 'Ganhos'), _Key(CF.red, 'Gastos')]),
        const SizedBox(height: 10),
        SizedBox(
          height: 170,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final m in pm)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(moneyCompact(m.income), style: CF.body(10.5, color: CF.muted)),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 130,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const SizedBox(width: 3),
                      Expanded(child: _col(m.income, max, CF.green)),
                      const SizedBox(width: 2),
                      Expanded(child: _col(m.expenses, max, CF.red)),
                      const SizedBox(width: 3),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  Text(nm(m.month), style: CF.body(12, weight: FontWeight.w700)),
                ]),
              ),
          ]),
        ),
        _Take('Melhor mês de ganhos: ${capitalize(monthNames[best.month.month - 1])} (${money(best.income)}). '
            'Mais fraco: ${capitalize(monthNames[worst.month.month - 1])} (${money(worst.income)}).'),
      ]),
    );
  }
}

/// 3. Quanto sobrou em cada mês.
class _Result extends StatelessWidget {
  const _Result({required this.cur});
  final PeriodNumbers cur;

  @override
  Widget build(BuildContext context) {
    final pm = cur.perMonth;
    if (pm.length < 2) return const SizedBox.shrink();
    final vals = [for (final m in pm) m.income - m.expenses];
    var max = 1.0;
    for (final v in vals) {
      if (v.abs() > max) max = v.abs();
    }
    final negatives = vals.where((v) => v < 0).length;
    String nm(DateTime m) => monthNames[m.month - 1].substring(0, 3);
    return Panel(
      icon: Icons.savings_rounded,
      color: CF.blue,
      title: 'Quanto sobrou em cada mês',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 150,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < pm.length; i++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(moneyCompact(vals[i]), style: CF.body(10.5, color: vals[i] < 0 ? CF.red : CF.muted)),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 100,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(widthFactor: .55, child: _col(vals[i], max, vals[i] < 0 ? CF.red : CF.blue, height: 100)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(nm(pm[i].month), style: CF.body(12, weight: FontWeight.w700)),
                ]),
              ),
          ]),
        ),
        _Take(negatives == 0
            ? 'Em todos os meses os ganhos cobriram os gastos.'
            : negatives == 1
                ? 'Em 1 mês os gastos passaram dos ganhos (barra vermelha).'
                : 'Em $negatives meses os gastos passaram dos ganhos (barras vermelhas).'),
      ]),
    );
  }
}

/// 4. Para onde vai o dinheiro: maiores gastos do período.
class _Where extends StatelessWidget {
  const _Where({required this.cur});
  final PeriodNumbers cur;

  @override
  Widget build(BuildContext context) {
    final items = cur.expenseItems.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    if (items.isEmpty) return const SizedBox.shrink();
    final top = items.take(6).toList();
    final total = cur.expenses <= 0 ? 1.0 : cur.expenses;
    return Panel(
      icon: Icons.pie_chart_outline_rounded,
      color: CF.red,
      title: 'Para onde vai o dinheiro',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final e in top)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: CF.body(13.5, weight: FontWeight.w600))),
                Text('${money(e.value)} · ${(e.value / total * 100).round()}%', style: CF.body(12.5, color: CF.muted)),
              ]),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: (e.value / total).clamp(0, 1).toDouble(), minHeight: 8, color: CF.red, backgroundColor: CF.greyBg),
              ),
            ]),
          ),
        _Take('${top.first.key} é o maior gasto: ${(top.first.value / total * 100).round()}% de tudo que saiu.'),
      ]),
    );
  }
}
