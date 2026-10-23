import 'package:flutter/material.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_store.dart';
import 'cf_theme.dart';

/// Título de página com ação opcional à direita.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: CF.body(28, weight: FontWeight.w700)),
            if (subtitle != null) Text(subtitle!, style: CF.body(15, color: CF.muted)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]);
}

/// Caixa branca com borda suave, usada em todas as telas.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.title, this.action, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final String? title;
  final Widget? action;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: CF.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CF.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title != null) ...[
            Row(children: [
              Expanded(child: Text(title!, style: CF.body(18, weight: FontWeight.w700))),
              if (action != null) action!,
            ]),
            const SizedBox(height: 10),
          ],
          child,
        ]),
      );
}

/// Seletor de mês compartilhado (o mesmo mês em Cobranças e Financeiro).
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final m = store.selectedMonth;
    final isCurrent = m.year == store.today.year && m.month == store.today.month;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        tooltip: 'Mês anterior',
        onPressed: () => store.shiftMonth(-1),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isCurrent ? null : () => store.goToMonth(DateTime(store.today.year, store.today.month)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(children: [
            Text('${capitalize(monthNames[m.month - 1])} ${m.year}', style: CF.body(16, weight: FontWeight.w700)),
            if (!isCurrent) Text('voltar para hoje', style: CF.body(12, color: CF.blue)),
          ]),
        ),
      ),
      IconButton(
        tooltip: 'Próximo mês',
        onPressed: () => store.shiftMonth(1),
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ]);
  }
}

/// Mensagem de lista vazia que convida a agir.
class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Column(children: [
          Icon(icon, size: 32, color: CF.muted),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: CF.body(16, color: CF.muted)),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ]),
      );
}

/// Linha de atendimento (agenda e início): horário, cliente e situação.
class SessionRow extends StatelessWidget {
  const SessionRow({super.key, required this.plan, required this.line, required this.onTap, this.trailing});
  final StudentPlan plan;
  final LessonLine line;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = BillingStore.instance.terms;
    final (fg, bg) = CF.forOutcome(line.outcome);
    final struck = line.outcome == LessonOutcome.cancelledWaived ||
        line.outcome == LessonOutcome.movedOut ||
        line.outcome == LessonOutcome.holiday;
    final label = line.isExtra && line.outcome == LessonOutcome.charged
        ? t.g('Marcada', 'Marcado')
        : line.outcome.label(t);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          SizedBox(
            width: 58,
            child: Text(line.time.isEmpty ? '—' : line.time, style: CF.score(22, color: struck ? CF.muted : CF.text)),
          ),
          Container(width: 4, height: 40, decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CF.body(16, weight: FontWeight.w700, color: struck ? CF.muted : CF.text)
                      .copyWith(decoration: struck ? TextDecoration.lineThrough : null)),
              Text(plan.service, maxLines: 1, overflow: TextOverflow.ellipsis, style: CF.body(14, color: CF.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
            child: Text(label, style: CF.body(13, color: fg, weight: FontWeight.w700)),
          ),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}

/// Texto curto da forma de cobrança e do valor de um cliente.
String planPriceText(StudentPlan p, Terms t) => switch (p.model) {
      BillingModel.perSession => '${moneyCompact(p.rate)} por ${t.session}',
      BillingModel.hourly => '${moneyCompact(p.rate)} por hora · ${durationText(p.durationMinutes)}',
      BillingModel.monthly => '${moneyCompact(p.rate)} por mês',
      BillingModel.package => 'Pacote de ${p.packageSize} por ${moneyCompact(p.rate)}',
    };

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Bom dia';
  if (h < 18) return 'Boa tarde';
  return 'Boa noite';
}

String fullDate(DateTime d) =>
    '${weekdayLong[d.weekday - 1]}, ${d.day} de ${monthNames[d.month - 1]}';
