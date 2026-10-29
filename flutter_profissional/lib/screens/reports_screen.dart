import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_store.dart';
import '../profile/profession_profile.dart';
import '../ui/cf_theme.dart';
import '../ui/widgets.dart';
import 'finance_screen.dart' show editAnnualGoal;

/// Relatórios: visão geral do mês, meta do ano, detalhe por cliente e o ano mês a mês.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final m = store.selectedMonth;
        return LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 980;
          final title = wide
              ? PageTitle('Relatórios', icon: Icons.insights_rounded, color: CF.violet, subtitle: 'Seu negócio numa leitura só', trailing: _CopyButton(month: m))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const PageTitle('Relatórios', icon: Icons.insights_rounded, color: CF.violet, subtitle: 'Seu negócio numa leitura só'),
                  Row(children: [
                    const Flexible(
                      child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: MonthSwitcher()),
                    ),
                    const SizedBox(width: 8),
                    _CopyButton(month: m, compact: true),
                  ]),
                ]);
          final overview = _Overview(month: m, wide: wide);
          final goal = _AnnualGoal(month: m);
          final clients = _ByClient(month: m);
          final year = _YearTable(year: m.year, selected: m);
          if (wide) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              title,
              const Align(alignment: Alignment.centerLeft, child: MonthSwitcher()),
              const SizedBox(height: 10),
              overview,
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(children: [goal, const SizedBox(height: 16), year])),
                const SizedBox(width: 16),
                Expanded(child: clients),
              ]),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            title,
            const SizedBox(height: 8),
            overview,
            const SizedBox(height: 14),
            goal,
            const SizedBox(height: 14),
            clients,
            const SizedBox(height: 14),
            year,
            const SizedBox(height: 8),
          ]);
        });
      },
    );
  }
}

/// Números do mês em blocos, como a visão geral do Coach Flow Pessoal.
class _Overview extends StatelessWidget {
  const _Overview({required this.month, required this.wide});
  final DateTime month;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final t = ProfessionalProfile.instance.terms;
    final f = store.forecast(month);
    final st = store.sessionStats(month);
    final active = store.activePlans;
    final discounts = active.fold(0.0, (s, p) => s + store.bill(p, month: month).discountValue);
    final billedSessions = st.charged;
    final ticket = billedSessions == 0 ? 0.0 : f.billed / billedSessions;
    final money = [
      _Kpi(Icons.trending_up_rounded, 'Receita prevista', moneyCompact(f.incomePlanned),
          f.extras > 0 ? '${t.sessionsTitle} + ${moneyCompact(f.extras)} em ganhos extras' : 'O que ${t.clients} devem pagar',
          CF.blue),
      _Kpi(Icons.savings_rounded, 'Recebido no mês', moneyCompact(f.incomeNow), 'Inclui ganhos extras', CF.green),
      _Kpi(Icons.hourglass_bottom_rounded, 'A receber', moneyCompact(f.open),
          f.open <= 0 ? 'Tudo recebido' : '${f.openRate}% das cobranças ainda em aberto', CF.amber),
      _Kpi(Icons.receipt_long_rounded, 'Despesas do mês', moneyCompact(f.expensesPlanned),
          f.expensesOpen <= 0 ? 'Todas pagas' : '${moneyCompact(f.expensesOpen)} ainda a pagar', CF.red),
      _Kpi(Icons.account_balance_wallet_rounded, 'Resultado de caixa', moneyCompact(f.resultNow), 'Recebido − despesas pagas',
          f.resultNow < 0 ? CF.red : CF.ink),
    ];
    final ops = [
      _Kpi(Icons.groups_rounded, '${t.clientsTitle} ativos', '${active.length}', '', CF.violet),
      _Kpi(Icons.event_available_rounded, '${t.sessionsTitle} cobrad${t.g('a', 'o')}s', '$billedSessions',
          st.makeUps > 0 ? '${st.makeUps} reposições' : '', CF.blue),
      _Kpi(Icons.sell_rounded, 'Ticket médio', moneyCompact(ticket), 'Por ${t.session} cobrad${t.g('a', 'o')}', CF.green),
      _Kpi(Icons.event_busy_rounded, 'Faltas e cancelamentos', '${st.cancelled}',
          st.cancelled == 0 ? '' : '${st.cancelledCharged} cobrad${t.g('a', 'o')}s, ${st.cancelledWaived} sem cobrança', CF.amber),
      _Kpi(Icons.percent_rounded, 'Descontos e créditos', moneyCompact(discounts),
          st.credits > 0 ? '${st.credits} créditos no mês' : 'Faltas do mês anterior descontadas', CF.violet),
    ];
    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 900 ? 5 : (box.maxWidth >= 560 ? 3 : 2);
      const gap = 10.0;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      Widget grid(List<_Kpi> items, {bool accent = false}) => Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (final k in items) SizedBox(width: w, child: _KpiTile(k, accent: accent))],
          );
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        grid(money, accent: true),
        const SizedBox(height: 10),
        grid(ops),
      ]);
    });
  }
}

class _Kpi {
  const _Kpi(this.icon, this.label, this.value, this.hint, this.color);
  final IconData icon;
  final String label, value, hint;
  final Color color;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile(this.k, {this.accent = false});
  final _Kpi k;
  final bool accent;

  @override
  Widget build(BuildContext context) => KpiCard(
        icon: k.icon,
        label: k.label,
        value: k.value,
        hint: k.hint,
        color: k.color,
        accent: accent,
        valueColor: accent ? null : CF.text,
      );
}

/// Meta do ano com projeção no ritmo atual.
class _AnnualGoal extends StatelessWidget {
  const _AnnualGoal({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final annual = store.annualGoal;
    final year = month.year;
    final today = store.today;
    final yearIn = store.yearIn(year);
    final monthIn = store.totalIn(month);
    final monthly = store.monthlyGoal;
    // Meses já vividos no ano (o mês atual conta como em andamento).
    final elapsed = year < today.year ? 12 : (year > today.year ? 0 : today.month);
    final expected = annual * elapsed / 12;
    final pace = elapsed == 0 ? 0.0 : yearIn / elapsed * 12;
    final left = (annual - yearIn).clamp(0, double.infinity).toDouble();
    final monthsLeft = year == today.year ? 12 - today.month + 1 : (year > today.year ? 12 : 0);
    final perMonth = monthsLeft == 0 ? 0.0 : left / monthsLeft;
    final yearProgress = annual <= 0 ? 0.0 : (yearIn / annual).clamp(0.0, 1.0).toDouble();
    final monthProgress = monthly <= 0 ? 0.0 : (monthIn / monthly).clamp(0.0, 1.0).toDouble();
    final ahead = yearIn >= expected;

    if (annual <= 0) {
      return Panel(
        icon: Icons.flag_rounded,
        color: CF.violet,
        title: 'Meta do ano',
        child: EmptyNote(
          icon: Icons.flag_rounded,
          text: 'Defina quanto quer receber no ano e acompanhe o ritmo mês a mês.',
          action: FilledButton(onPressed: () => editAnnualGoal(context), child: const Text('Definir meta')),
        ),
      );
    }
    return Panel(
      icon: Icons.flag_rounded,
      color: CF.violet,
      title: 'Meta de $year',
      action: TextButton.icon(
        onPressed: () => editAnnualGoal(context),
        icon: const Icon(Icons.edit_rounded, size: 16),
        label: const Text('Alterar'),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('${moneyCompact(yearIn)} de ${moneyCompact(annual)}', style: CF.score(30)),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(yearProgress * 100).toStringAsFixed(1).replaceAll('.', ',')}%',
              style: CF.score(24, color: CF.green)),
        ]),
        const SizedBox(height: 8),
        LaneTrack(progress: yearProgress),
        const SizedBox(height: 12),
        _GoalGrid(items: [
          ('Esperado até agora', moneyCompact(expected)),
          ('No ritmo atual', moneyCompact(pace)),
          ('Falta no ano', moneyCompact(left)),
          ('Meta mensal', moneyCompact(monthly)),
          ('Trimestral', moneyCompact(annual / 4)),
          ('Semestral', moneyCompact(annual / 2)),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ahead ? CF.greenBg : CF.amberBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            left <= 0
                ? 'Meta do ano atingida. Parabéns!'
                : ahead
                    ? 'Você está à frente do esperado. No ritmo atual fecha o ano com ${moneyCompact(pace)}.'
                    : 'Para bater a meta, precisa receber ${moneyCompact(perMonth)} por mês '
                        'nos $monthsLeft ${monthsLeft == 1 ? 'mês restante' : 'meses restantes'}.',
            style: CF.body(14.5, color: ahead ? CF.green : CF.amber, weight: FontWeight.w600, height: 1.35),
          ),
        ),
        const SizedBox(height: 14),
        Text('${capitalize(monthNames[month.month - 1])}: ${moneyCompact(monthIn)} de ${moneyCompact(monthly)}',
            style: CF.body(14.5, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        LaneTrack(progress: monthProgress),
        const SizedBox(height: 4),
        Text(
          monthIn >= monthly
              ? 'Meta do mês atingida.'
              : 'Faltam ${moneyCompact(monthly - monthIn)} para a meta do mês.',
          style: CF.body(13.5, color: CF.muted),
        ),
      ]),
    );
  }
}

class _GoalGrid extends StatelessWidget {
  const _GoalGrid({required this.items});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth >= 420 ? 3 : 2;
        const gap = 8.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final (label, value) in items)
            Container(
              width: w,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: CF.greyBg, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label.toUpperCase(), style: CF.body(11.5, weight: FontWeight.w700, color: CF.muted)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: CF.body(16, weight: FontWeight.w700)),
                ),
              ]),
            ),
        ]);
      });
}

/// Relatório do mês por cliente: cobrado, recebido, falta e situação.
class _ByClient extends StatelessWidget {
  const _ByClient({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final t = ProfessionalProfile.instance.terms;
    final rows = [
      for (final p in store.activePlans)
        (
          plan: p,
          total: store.bill(p, month: month).total,
          got: store.received(p.id, month: month),
          left: store.remaining(p, month: month),
          status: store.status(p, month: month),
        ),
    ]..sort((a, b) => b.left.compareTo(a.left) != 0 ? b.left.compareTo(a.left) : a.plan.name.compareTo(b.plan.name));
    int count(BillStatus s) => rows.where((r) => r.status == s).length;
    return Panel(
      icon: Icons.groups_rounded,
      color: CF.blue,
      title: 'Por ${t.client} em ${monthNames[month.month - 1]}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Count('Pagos', count(BillStatus.paid), CF.green, CF.greenBg),
          _Count('Em parte', count(BillStatus.partial), CF.amber, CF.amberBg),
          _Count('A receber', count(BillStatus.pending), CF.blue, const Color(0xFFE6EEFB)),
          _Count('Atrasados', count(BillStatus.overdue), CF.red, CF.redBg),
        ]),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          EmptyNote(icon: Icons.groups_rounded, text: 'Nenhum ${t.client} ativo.')
        else
          for (final r in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CF.line))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.plan.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: CF.body(15.5, weight: FontWeight.w600)),
                    Text(
                      r.left > 0
                          ? '${moneyCompact(r.got)} de ${moneyCompact(r.total)} · falta ${moneyCompact(r.left)}'
                          : '${moneyCompact(r.got)} de ${moneyCompact(r.total)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CF.body(13.5, color: CF.muted),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                StatusPill(r.status),
              ]),
            ),
      ]),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.n, this.fg, this.bg);
  final String label;
  final int n;
  final Color fg, bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text('$n $label', style: CF.body(13.5, weight: FontWeight.w700, color: fg)),
      );
}

/// O ano mês a mês: entrou, saiu e sobrou.
class _YearTable extends StatelessWidget {
  const _YearTable({required this.year, required this.selected});
  final int year;
  final DateTime selected;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final months = [for (var mo = 1; mo <= 12; mo++) DateTime(year, mo)];
    final ins = [for (final m in months) store.totalIn(m)];
    final outs = [for (final m in months) store.expensesPaid(m)];
    final sumIn = ins.fold(0.0, (a, b) => a + b);
    final sumOut = outs.fold(0.0, (a, b) => a + b);
    Widget cell(String text, {bool bold = false, Color? color, bool end = true}) => Expanded(
          flex: end ? 3 : 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: end ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(text,
                style: CF.body(14, weight: bold ? FontWeight.w700 : FontWeight.w500, color: color ?? CF.text)),
          ),
        );
    Widget row(List<Widget> cells, {Color? bg}) => Container(
          color: bg,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Row(children: cells),
        );
    return Panel(
      icon: Icons.table_chart_rounded,
      color: CF.green,
      title: '$year mês a mês',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        row([
          cell('Mês', bold: true, color: CF.muted, end: false),
          cell('Entrou', bold: true, color: CF.muted),
          cell('Saiu', bold: true, color: CF.muted),
          cell('Sobrou', bold: true, color: CF.muted),
        ]),
        for (var i = 0; i < 12; i++)
          if (ins[i] > 0 || outs[i] > 0 || months[i].month == selected.month)
            row([
              cell(capitalize(monthNames[i]).substring(0, 3), end: false, bold: months[i].month == selected.month),
              cell(moneyCompact(ins[i]), color: CF.green),
              cell(moneyCompact(outs[i]), color: CF.red),
              cell(moneyCompact(ins[i] - outs[i]), bold: true, color: ins[i] - outs[i] < 0 ? CF.red : CF.text),
            ], bg: months[i].month == selected.month ? CF.greyBg : null),
        const Divider(height: 1, color: CF.line),
        row([
          cell('Total', bold: true, end: false),
          cell(moneyCompact(sumIn), bold: true, color: CF.green),
          cell(moneyCompact(sumOut), bold: true, color: CF.red),
          cell(moneyCompact(sumIn - sumOut), bold: true),
        ]),
      ]),
    );
  }
}

/// Copia um resumo do mês para colar no WhatsApp ou numa planilha.
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.month, this.compact = false});
  final DateTime month;
  final bool compact;

  String _summary() {
    final store = BillingStore.instance;
    final t = ProfessionalProfile.instance.terms;
    final f = store.forecast(month);
    final st = store.sessionStats(month);
    final name = '${capitalize(monthNames[month.month - 1])}/${month.year}';
    return [
      'Coach Flow · Resumo de $name',
      'Receita prevista: ${money(f.incomePlanned)}',
      'Recebido: ${money(f.incomeNow)}',
      'A receber: ${money(f.open)} (${f.openRate}% em aberto)',
      'Despesas: ${money(f.expensesPlanned)} (pagas ${money(f.expensesPaid)})',
      'Resultado previsto: ${money(f.resultPlanned)}',
      'Resultado até agora: ${money(f.resultNow)}',
      '${t.clientsTitle} ativos: ${store.activePlans.length}',
      '${t.sessionsTitle} cobrad${t.g('a', 'o')}s: ${st.charged} · faltas e cancelamentos: ${st.cancelled}',
      if (store.annualGoal > 0)
        'Meta do ano: ${money(store.yearIn(month.year))} de ${money(store.annualGoal)}',
    ].join('\n');
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _summary()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resumo copiado. É só colar.')));
    }
  }

  @override
  Widget build(BuildContext context) => compact
      ? IconButton(
          tooltip: 'Copiar resumo do mês',
          onPressed: () => _copy(context),
          icon: const Icon(Icons.copy_rounded),
        )
      : OutlinedButton.icon(
          onPressed: () => _copy(context),
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copiar resumo'),
        );
}
