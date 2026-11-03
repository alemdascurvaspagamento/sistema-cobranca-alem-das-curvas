import 'package:flutter/material.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_store.dart';
import 'cf_theme.dart';
import 'confirmations.dart';
import 'motion.dart';

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
    this.ringing = false,
  });
  final Widget child;
  final String? title;

  /// O ícone do título "toca" de tempos em tempos (há algo pendente).
  final bool ringing;

  /// Ícone do título, dentro de um quadradinho colorido.
  final IconData? icon;
  final Color color;
  final Widget? action;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => FadeInUp(child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: CF.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CF.line),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border(top: BorderSide(color: color, width: 3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title != null) ...[
            Row(children: [
              if (icon != null) ...[
                ringing
                    ? RingingLoop(child: IconBadge(icon!, color: color, size: 34))
                    : IconBadge(icon!, color: color, size: 34),
                const SizedBox(width: 10),
              ],
              Expanded(child: Text(title!, style: CF.body(18, weight: FontWeight.w700))),
              if (action != null) action!,
            ]),
            const SizedBox(height: 12),
          ],
          child,
        ]),
      ));
}

/// Seletor de mês compartilhado (o mesmo mês em Cobranças e Financeiro).
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuta o mês escolhido por conta própria: nas telas ele é `const`,
    // e o Flutter não redesenha widget `const` quando o pai muda.
    final store = BillingStore.instance;
    return AnimatedBuilder(animation: store, builder: (context, _) => _content(store));
  }

  Widget _content(BillingStore store) {
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
    final note = line.record?.note.trim() ?? '';
    final store = BillingStore.instance;
    final quick = line.outcome == LessonOutcome.charged &&
        line.record?.status != LessonStatus.completed &&
        !dateOnly(line.date).isAfter(store.today);

    void register(LessonStatus status, String done) {
      final err = store.saveLesson(
        plan.id,
        line.date,
        LessonRecord(status: status, extra: line.isExtra, time: line.record?.time, note: line.record?.note ?? ''),
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: err != null
              ? Text(err)
              : Row(children: [
                  if (status == LessonStatus.completed) ...[const PopCheck(), const SizedBox(width: 10)],
                  Expanded(child: Text('${plan.name}: $done. Toque no atendimento para mudar.')),
                ]),
        ));
    }

    final confirm = Confirmations.canConfirm(plan, line, store.today);

    return ListenableBuilder(listenable: Confirmations.instance, builder: (context, _) => LayoutBuilder(builder: (context, box) {
    // Em colunas estreitas (semana no computador) fica só o essencial.
    final compact = box.maxWidth < 300;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: CF.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CF.line),
      ),
      // Na agenda a cor fica na lateral: lê-se como uma linha do tempo.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: fg, width: 5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(children: [
            SizedBox(
              width: 58,
              child: Text(line.time.isEmpty ? '—' : line.time, style: CF.score(22, color: struck ? CF.muted : CF.text)),
            ),
            Container(width: 1, height: 36, color: CF.line),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CF.body(16, weight: FontWeight.w700, color: struck ? CF.muted : CF.text)
                        .copyWith(decoration: struck ? TextDecoration.lineThrough : null)),
                Text(plan.service, maxLines: 1, overflow: TextOverflow.ellipsis, style: CF.body(14, color: CF.muted)),
                if (note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      const Icon(Icons.sticky_note_2_rounded, size: 14, color: CF.amber),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CF.body(13, color: CF.text, weight: FontWeight.w600)),
                      ),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
              child: Text(label, style: CF.body(13, color: fg, weight: FontWeight.w700)),
            ),
            if (trailing != null) trailing!,
            if (!compact) ...[
              const SizedBox(width: 2),
              const Icon(Icons.edit_note_rounded, color: CF.muted, size: 24),
            ],
          ]),
        ),
      ),
      if ((quick || confirm) && !compact)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Wrap(spacing: 8, runSpacing: 6, children: [
            if (confirm)
              Confirmations.instance.sent(plan.id, line.date)
                  ? OutlinedButton.icon(
                      onPressed: () => Confirmations.instance.send(context, plan, line),
                      icon: const Icon(Icons.done_all_rounded, size: 18, color: CF.whatsapp),
                      label: const Text('Confirmação enviada'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CF.whatsapp,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: () => Confirmations.instance.send(context, plan, line),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: const Text('Confirmar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: CF.whatsapp,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
            if (quick) ...[
            OutlinedButton.icon(
              onPressed: () => register(LessonStatus.completed, t.g('realizada', 'realizado')),
              icon: const Icon(Icons.check_rounded, size: 18, color: CF.green),
              label: Text(t.g('Realizada', 'Realizado')),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 12)),
            ),
            OutlinedButton.icon(
              onPressed: () => register(LessonStatus.cancelled, 'falta registrada'),
              icon: const Icon(Icons.close_rounded, size: 18, color: CF.red),
              label: const Text('Faltou'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 12)),
            ),
            ],
          ]),
        ),
    ]),
    );
    }));
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
              WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? CF.brand : CF.surface),
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
    this.selected,
  });
  final IconData icon;
  final String label, value, hint;

  /// Quando o quadro funciona como filtro: true = filtro ativo (destacado).
  final bool? selected;
  final Color color;
  final Color? valueColor;

  /// Mostra a faixa colorida no topo.
  final bool accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = selected == true;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: on ? Color.alphaBlend(color.withValues(alpha: .08), CF.surface) : CF.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: on ? color : CF.line, width: on ? 2 : 1),
        boxShadow: on ? [BoxShadow(color: color.withValues(alpha: .18), blurRadius: 12, offset: const Offset(0, 4))] : null,
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
                style: CF.body(12, weight: FontWeight.w700, color: on ? color : CF.muted, height: 1.2)),
          ),
          if (on) Icon(Icons.check_circle_rounded, size: 18, color: color),
        ]),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: CountUpText(value, style: CF.score(28, color: valueColor ?? (accent ? CF.text : color))),
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

/// Marca do Leguno: o "L" dobrado (haste âmbar e base turquesa) no quadrado azul-marinho, igual ao ícone do app.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 30});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: CF.ink,
          borderRadius: BorderRadius.circular(size * .24),
          border: Border.all(color: Colors.white.withValues(alpha: .14)),
        ),
        child: CustomPaint(painter: const _LegunoGlyph()),
      );
}

class _LegunoGlyph extends CustomPainter {
  const _LegunoGlyph();

  @override
  void paint(Canvas canvas, Size size) {
    // Desenho feito numa caixa de 1024, com o "L" ocupando 86% (como no ícone).
    final k = size.width / 1024 * .86;
    final dx = size.width / 2 - 512 * k, dy = size.height / 2 - 512 * k;
    Offset o(double x, double y) => Offset(dx + x * k, dy + y * k);
    Path poly(List<List<double>> pts) {
      final path = Path()..moveTo(o(pts[0][0], pts[0][1]).dx, o(pts[0][0], pts[0][1]).dy);
      for (final p in pts.skip(1)) {
        path.lineTo(o(p[0], p[1]).dx, o(p[0], p[1]).dy);
      }
      return path..close();
    }

    final base = poly([[250, 840], [228, 806], [298, 660], [800, 660], [816, 690], [766, 812], [726, 840]]);
    canvas.drawPath(
      base,
      Paint()
        ..shader = LinearGradient(colors: const [Color(0xFF0A7E8C), Color(0xFF22C7D6)])
            .createShader(Rect.fromPoints(o(228, 660), o(816, 840))),
    );
    canvas.drawPath(poly([[298, 660], [522, 660], [506, 702], [282, 702]]), Paint()..color = const Color(0x7306343B));
    final stem = poly([[478, 168], [512, 146], [690, 146], [707, 172], [522, 660], [298, 660]]);
    canvas.drawPath(
      stem,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFFFFD36B), Color(0xFFF2A516)],
        ).createShader(Rect.fromPoints(o(298, 146), o(707, 660))),
    );
  }

  @override
  bool shouldRepaint(_LegunoGlyph old) => false;
}

/// Páginas 1, 2, 3 no fim de listas longas.
class Pager extends StatelessWidget {
  const Pager({super.key, required this.page, required this.pages, required this.onChanged, this.total, this.perPage});
  final int page, pages;
  final ValueChanged<int> onChanged;
  final int? total, perPage;

  @override
  Widget build(BuildContext context) {
    if (pages <= 1) return const SizedBox.shrink();
    // Mostra no máximo 5 números em volta da página atual.
    var first = (page - 2).clamp(0, (pages - 5).clamp(0, pages));
    final last = (first + 5).clamp(0, pages);
    Widget num(int i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: i == page
              ? FilledButton(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor: CF.brand,
                    disabledForegroundColor: Colors.white,
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text('${i + 1}'),
                )
              : OutlinedButton(
                  onPressed: () => onChanged(i),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44), padding: EdgeInsets.zero),
                  child: Text('${i + 1}'),
                ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(children: [
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 6, children: [
          IconButton(
            tooltip: 'Página anterior',
            onPressed: page > 0 ? () => onChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          for (var i = first; i < last; i++) num(i),
          IconButton(
            tooltip: 'Próxima página',
            onPressed: page < pages - 1 ? () => onChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
        if (total != null && perPage != null)
          Text('${page * perPage! + 1} a ${((page + 1) * perPage!).clamp(0, total!)} de $total',
              style: CF.body(13, color: CF.muted)),
      ]),
    );
  }
}

/// Leva a tela até o começo da lista quando muda de página.
void scrollToKey(GlobalKey key) {
  final ctx = key.currentContext;
  if (ctx != null) {
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }
}

/// Botão em forma de pílula, para opções e filtros em grade alinhada.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.onTap, this.selected = false, this.count, this.color = CF.brand});
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final String? count;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? color : CF.surface,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? color : CF.line, width: 1.5),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: label),
                  if (count != null)
                    TextSpan(text: '  $count', style: TextStyle(color: selected ? Colors.white70 : CF.muted)),
                ]),
                maxLines: 1,
                style: CF.body(15, weight: FontWeight.w600, color: selected ? Colors.white : CF.text),
              ),
            ),
          ),
        ),
      );
}

/// Grade de pílulas com a mesma largura, sem rolar para o lado.
/// [columns] por linha (no celular estreito pode diminuir com [narrowColumns]).
class PillGrid extends StatelessWidget {
  const PillGrid({super.key, required this.children, this.columns = 3, this.narrowColumns, this.gap = 8});
  final List<Widget> children;
  final int columns;
  final int? narrowColumns;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cols = (narrowColumns != null && box.maxWidth < 380) ? narrowColumns! : columns;
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          final slice = children.sublist(i, (i + cols).clamp(0, children.length));
          rows.add(Row(children: [
            for (var j = 0; j < cols; j++) ...[
              if (j > 0) SizedBox(width: gap),
              Expanded(child: j < slice.length ? slice[j] : const SizedBox.shrink()),
            ],
          ]));
        }
        return Column(children: [
          for (var i = 0; i < rows.length; i++) ...[if (i > 0) SizedBox(height: gap), rows[i]],
        ]);
      });
}
