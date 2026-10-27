import 'package:flutter/material.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_store.dart';
import 'cf_theme.dart';

/// Título de página com ação opcional à direita.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle, this.trailing, this.icon, this.color = CF.blue});
  final String title;

  /// Ícone em quadradinho colorido ao lado do título.
  final IconData? icon;
  final Color color;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (icon != null) ...[IconBadge(icon!, color: color, size: 46), const SizedBox(width: 12)],
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
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.action,
    this.icon,
    this.color = CF.blue,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final String? title;

  /// Ícone do título, dentro de um quadradinho colorido.
  final IconData? icon;
  final Color color;
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
              if (icon != null) ...[IconBadge(icon!, color: color, size: 34), const SizedBox(width: 10)],
              Expanded(child: Text(title!, style: CF.body(18, weight: FontWeight.w700))),
              if (action != null) action!,
            ]),
            const SizedBox(height: 12),
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

/// Coluna de uma [WideTable]: título, largura relativa e alinhamento.
class TableCol {
  const TableCol(this.label, {this.flex = 2, this.end = false, this.width});
  final String label;
  final int flex;

  /// Alinha à direita (bom para valores em reais).
  final bool end;

  /// Largura fixa em pixels (substitui o [flex]).
  final double? width;
}

/// Tabela para telas grandes (computador). Cada linha pode ser tocada.
class WideTable extends StatelessWidget {
  const WideTable({super.key, required this.columns, required this.rows, this.onTapRow, this.footer, this.highlight});
  final List<TableCol> columns;
  final List<List<Widget>> rows;
  final void Function(int index)? onTapRow;

  /// Linha de totais, opcional.
  final List<Widget>? footer;

  /// Linhas com fundo de alerta (ex.: atrasados).
  final bool Function(int index)? highlight;

  Widget _cell(TableCol c, Widget child) {
    final aligned = Align(alignment: c.end ? Alignment.centerRight : Alignment.centerLeft, child: child);
    final padded = Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: aligned);
    return c.width != null ? SizedBox(width: c.width, child: padded) : Expanded(flex: c.flex, child: padded);
  }

  Widget _row(List<Widget> cells) => Row(children: [
        for (var i = 0; i < columns.length; i++) _cell(columns[i], i < cells.length ? cells[i] : const SizedBox()),
      ]);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CF.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CF.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: CF.bg,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: _row([
            for (final c in columns) Text(c.label, style: CF.body(13, color: CF.muted, weight: FontWeight.w700)),
          ]),
        ),
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const Divider(height: 1),
          Material(
            color: (highlight?.call(r) ?? false) ? CF.redBg.withValues(alpha: .45) : CF.surface,
            child: InkWell(
              onTap: onTapRow == null ? null : () => onTapRow!(r),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: _row(rows[r]),
              ),
            ),
          ),
        ],
        if (footer != null)
          Container(
            decoration: const BoxDecoration(color: CF.bg, border: Border(top: BorderSide(color: CF.line))),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: _row(footer!),
          ),
      ]),
    );
  }
}

/// Alternância Cartões / Tabela, mostrada só em telas grandes.
class LayoutToggle extends StatelessWidget {
  const LayoutToggle({super.key, required this.table, required this.onChanged});
  final bool table;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: true, icon: Icon(Icons.table_rows_rounded), label: Text('Tabela')),
          ButtonSegment(value: false, icon: Icon(Icons.grid_view_rounded), label: Text('Cartões')),
        ],
        selected: {table},
        onSelectionChanged: (v) => onChanged(v.first),
        style: ButtonStyle(
          foregroundColor:
              WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : CF.ink),
          backgroundColor:
              WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? CF.ink : CF.surface),
          side: const WidgetStatePropertyAll(BorderSide(color: CF.line)),
        ),
      );
}

/// Ícone dentro de um quadradinho de cantos arredondados com fundo suave.
/// É a "assinatura" visual do app: aparece nos números, nos títulos e no menu.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color = CF.blue, this.size = 38});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(size * .32),
        ),
        child: Icon(icon, color: color, size: size * .54),
      );
}

/// Cartão de número: ícone, rótulo em maiúsculas, valor grande e uma linha de explicação.
/// A faixa colorida no topo é opcional (usada nos números de dinheiro).
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.hint = '',
    this.color = CF.blue,
    this.accent = false,
    this.valueColor,
    this.onTap,
  });
  final IconData icon;
  final String label, value, hint;
  final Color color;
  final Color? valueColor;

  /// Mostra a faixa colorida no topo.
  final bool accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: CF.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CF.line),
      ),
      foregroundDecoration: accent
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border(top: BorderSide(color: color, width: 3)),
            )
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconBadge(icon, color: color, size: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: CF.body(12, weight: FontWeight.w700, color: CF.muted, height: 1.2)),
          ),
        ]),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: CF.score(28, color: valueColor ?? (accent ? CF.text : color))),
        ),
        if (hint.isNotEmpty)
          Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: CF.body(12.5, color: CF.muted, height: 1.25)),
      ]),
    );
    if (onTap == null) return card;
    return InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: card);
  }
}

/// Fileira de [KpiCard]: 2 por linha no celular, todos lado a lado no computador.
class KpiRow extends StatelessWidget {
  const KpiRow(this.cards, {super.key});
  final List<KpiCard> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth >= 700 ? cards.length.clamp(1, 5) : 2;
        const gap = 10.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final c in cards) SizedBox(width: w, child: c),
        ]);
      });
}
