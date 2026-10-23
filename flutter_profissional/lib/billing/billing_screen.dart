import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../demo_ledger.dart';
import '../ui/cf_theme.dart';
import 'billing_engine.dart';
import 'billing_store.dart';

enum _Filter { all, open, overdue, paid }

/// Tela de Cobranças: placar do mês e a conta de cada aluno.
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key, this.onOpenRules});
  final VoidCallback? onOpenRules;

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final store = BillingStore.instance;
  _Filter filter = _Filter.all;

  bool _matches(StudentPlan p) {
    final s = store.status(p);
    return switch (filter) {
      _Filter.all => true,
      _Filter.open => s == BillStatus.pending || s == BillStatus.partial,
      _Filter.overdue => s == BillStatus.overdue,
      _Filter.paid => s == BillStatus.paid,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final plans = store.activePlans;
        final shown = plans.where(_matches).toList()
          ..sort((a, b) => _order(store.status(a)).compareTo(_order(store.status(b))));
        final counts = {
          _Filter.all: plans.length,
          _Filter.open: store.countStatus(BillStatus.pending) + store.countStatus(BillStatus.partial),
          _Filter.overdue: store.countStatus(BillStatus.overdue),
          _Filter.paid: store.countStatus(BillStatus.paid),
        };
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Header(store: store),
          const SizedBox(height: 14),
          _Scoreboard(store: store),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in _Filter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${_filterLabel(f)}  ${counts[f]}'),
                    selected: filter == f,
                    showCheckmark: false,
                    selectedColor: CF.ink,
                    labelStyle: CF.body(15,
                        weight: FontWeight.w600, color: filter == f ? Colors.white : CF.text),
                    onSelected: (_) => setState(() => filter = f),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            _EmptyState(filter: filter, onShowAll: () => setState(() => filter = _Filter.all))
          else
            LayoutBuilder(builder: (context, box) {
              final columns = box.maxWidth >= 980 ? 2 : 1;
              const gap = 12.0;
              final w = (box.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(spacing: gap, runSpacing: gap, children: [
                for (final p in shown) SizedBox(width: w, child: StudentBillCard(plan: p)),
              ]);
            }),
          const SizedBox(height: 16),
          _RulesHint(store: store, onOpenRules: widget.onOpenRules),
          const SizedBox(height: 8),
        ]);
      },
    );
  }

  static int _order(BillStatus s) => switch (s) {
        BillStatus.overdue => 0,
        BillStatus.partial => 1,
        BillStatus.pending => 2,
        BillStatus.paid => 3,
        BillStatus.nothing => 4,
      };

  static String _filterLabel(_Filter f) => switch (f) {
        _Filter.all => 'Todos',
        _Filter.open => 'A receber',
        _Filter.overdue => 'Atrasados',
        _Filter.paid => 'Pagos',
      };
}

class _Header extends StatelessWidget {
  const _Header({required this.store});
  final BillingStore store;

  @override
  Widget build(BuildContext context) {
    final m = store.selectedMonth;
    final isCurrent = m.year == store.today.year && m.month == store.today.month;
    return Row(children: [
      Expanded(
        child: Text('Cobranças', style: CF.body(28, weight: FontWeight.w700)),
      ),
      IconButton(
        tooltip: 'Mês anterior',
        onPressed: () => store.shiftMonth(-1),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isCurrent
            ? null
            : () => store.goToMonth(DateTime(store.today.year, store.today.month)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(children: [
            Text('${capitalize(monthNames[m.month - 1])} ${m.year}',
                style: CF.body(16, weight: FontWeight.w700)),
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

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.store});
  final BillingStore store;

  @override
  Widget build(BuildContext context) {
    final total = store.monthTotal;
    final received = store.monthReceived;
    final remaining = store.monthRemaining;
    final progress = total <= 0 ? 0.0 : received / total;
    final overdue = store.countStatus(BillStatus.overdue);
    final month = monthNames[store.selectedMonth.month - 1];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(color: CF.ink, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Recebido', style: CF.body(15, color: Colors.white70)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(moneyCompact(received), style: CF.score(40, color: Colors.white)),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Falta receber', style: CF.body(15, color: Colors.white70)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(moneyCompact(remaining), style: CF.score(40, color: CF.lap)),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        LaneTrack(progress: progress),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Text(
              total <= 0
                  ? 'Nenhuma cobrança em $month.'
                  : '${(progress * 100).round()}% de ${money(total)} previstos em $month',
              style: CF.body(14, color: Colors.white70),
            ),
          ),
          if (overdue > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: CF.red.withValues(alpha: .22),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(overdue == 1 ? '1 atrasado' : '$overdue atrasados',
                  style: CF.body(13, color: const Color(0xFFFFB4B9), weight: FontWeight.w700)),
            ),
        ]),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter, required this.onShowAll});
  final _Filter filter;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: CF.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CF.line),
        ),
        child: Column(children: [
          Icon(filter == _Filter.overdue ? Icons.celebration_rounded : Icons.inbox_rounded,
              size: 36, color: CF.muted),
          const SizedBox(height: 10),
          Text(
            filter == _Filter.overdue ? 'Ninguém atrasado neste mês.' : 'Nenhum aluno nesta lista.',
            textAlign: TextAlign.center,
            style: CF.body(17, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextButton(onPressed: onShowAll, child: const Text('Ver todos os alunos')),
        ]),
      );
}

class _RulesHint extends StatelessWidget {
  const _RulesHint({required this.store, this.onOpenRules});
  final BillingStore store;
  final VoidCallback? onOpenRules;

  @override
  Widget build(BuildContext context) {
    final r = store.rules;
    final parts = [
      r.cancel == CancelRule.charge ? 'cancelamento é cobrado' : 'cancelamento não é cobrado',
      r.holiday == HolidayRule.noCharge ? 'feriado não é cobrado' : 'feriado é cobrado',
    ];
    return Row(children: [
      const Icon(Icons.rule_rounded, size: 18, color: CF.muted),
      const SizedBox(width: 8),
      Expanded(
        child: Text('Suas regras: ${parts.join(' e ')}.',
            style: CF.body(14, color: CF.muted)),
      ),
      if (onOpenRules != null) TextButton(onPressed: onOpenRules, child: const Text('Mudar regras')),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Cartão do aluno
// ---------------------------------------------------------------------------

class StudentBillCard extends StatelessWidget {
  const StudentBillCard({super.key, required this.plan});
  final StudentPlan plan;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final bill = store.bill(plan);
    final status = store.status(plan);
    final received = store.received(plan.id);
    final remaining = store.remaining(plan);
    final due = store.dueDate(plan);
    final (fg, bg) = CF.forStatus(status);
    final unpaid = status != BillStatus.paid && status != BillStatus.nothing;

    final detail = StringBuffer('${lessonsText(bill.billedLessons)} × ${money(bill.rate)}');
    if (bill.discountLessons > 0) {
      detail.write(bill.discountLessons == 1
          ? ' · 1 falta compensada'
          : ' · ${bill.discountLessons} faltas compensadas');
    }

    return Material(
      color: CF.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openBillDetail(context, plan),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: status == BillStatus.overdue ? CF.red.withValues(alpha: .45) : CF.line),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: bg,
                child: Text(initialsOf(plan.name), style: CF.body(15, color: fg, weight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(plan.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: CF.body(18, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${plan.service} · ${routineText(plan)}',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: CF.body(14, color: CF.muted)),
                ]),
              ),
              const SizedBox(width: 8),
              StatusPill(status),
            ]),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(money(bill.total), style: CF.score(34)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('no mês', style: CF.body(14, color: CF.muted)),
                  ]),
                  const SizedBox(height: 4),
                  Text(detail.toString(), style: CF.body(14, color: CF.muted)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(status == BillStatus.paid ? 'Pago' : 'Vence', style: CF.body(13, color: CF.muted)),
                Text(
                  status == BillStatus.paid && store.payments(plan.id).isNotEmpty
                      ? ddmm(store.payments(plan.id).last.date)
                      : ddmm(due),
                  style: CF.score(22, color: status == BillStatus.overdue ? CF.red : CF.text),
                ),
              ]),
            ]),
            if (received > 0 && unpaid) ...[
              const SizedBox(height: 10),
              _PartialBar(received: received, total: bill.total, remaining: remaining),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Text('Ver aulas e cálculo', style: CF.body(15, color: CF.blue, weight: FontWeight.w600)),
              const Icon(Icons.chevron_right_rounded, size: 20, color: CF.blue),
              const Spacer(),
              if (!unpaid) _MoreMenu(plan: plan),
            ]),
            if (unpaid) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openPaymentSheet(context, plan),
                    icon: const Icon(Icons.payments_rounded, size: 18),
                    label: const Text('Recebi'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => openWhatsAppBilling(context, plan),
                    style: FilledButton.styleFrom(backgroundColor: CF.whatsapp),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text('Cobrar'),
                  ),
                ),
                _MoreMenu(plan: plan),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

class _PartialBar extends StatelessWidget {
  const _PartialBar({required this.received, required this.total, required this.remaining});
  final double received, total, remaining;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: total <= 0 ? 0 : (received / total).clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            backgroundColor: CF.amberBg,
            color: CF.green,
          ),
        ),
        const SizedBox(height: 6),
        Text('Recebido ${money(received)} · falta ${money(remaining)}',
            style: CF.body(14, color: CF.amber, weight: FontWeight.w600)),
      ]);
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.plan});
  final StudentPlan plan;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final hasPayments = store.payments(plan.id).isNotEmpty;
    return PopupMenuButton<String>(
      tooltip: 'Mais ações',
      icon: const Icon(Icons.more_vert_rounded, color: CF.muted),
      onSelected: (v) {
        switch (v) {
          case 'pay':
            openPaymentSheet(context, plan);
          case 'vacation':
            openVacationSheet(context, plan);
          case 'due':
            openDueDayDialog(context, plan);
          case 'undo':
            confirmUndoPayment(context, plan);
          case 'whatsapp':
            openWhatsAppBilling(context, plan);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'pay', child: Text('Registrar pagamento')),
        const PopupMenuItem(value: 'whatsapp', child: Text('Enviar resumo no WhatsApp')),
        const PopupMenuItem(value: 'vacation', child: Text('Férias ou ausência')),
        const PopupMenuItem(value: 'due', child: Text('Mudar dia de vencimento')),
        if (hasPayments) const PopupMenuItem(value: 'undo', child: Text('Desfazer último pagamento')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Detalhe: como chegamos ao valor + aulas do mês
// ---------------------------------------------------------------------------

Future<void> openBillDetail(BuildContext context, StudentPlan plan) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .92,
        minChildSize: .5,
        maxChildSize: .97,
        builder: (context, scroll) => _BillDetail(planId: plan.id, scroll: scroll),
      ),
    );

class _BillDetail extends StatelessWidget {
  const _BillDetail({required this.planId, required this.scroll});
  final String planId;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final plan = store.plan(planId);
        final bill = store.bill(plan);
        final status = store.status(plan);
        final received = store.received(plan.id);
        final payments = store.payments(plan.id);
        final steps = explainBill(bill);
        final month = monthNames[bill.month - 1];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(plan.name, style: CF.body(24, weight: FontWeight.w700)),
                    Text('${capitalize(month)} de ${bill.year} · ${plan.service}',
                        style: CF.body(15, color: CF.muted)),
                  ]),
                ),
                StatusPill(status),
              ]),
              const SizedBox(height: 18),
              _Section(
                title: 'Como chegamos a esse valor',
                child: Column(children: [
                  for (final s in steps) _StepRow(step: s),
                  if (received > 0) ...[
                    const Divider(height: 22),
                    _StepRow(step: BillStep('Já recebido', '− ${money(received)}', kind: BillStepKind.minus)),
                    _StepRow(
                      step: BillStep('Falta receber', money(store.remaining(plan)), kind: BillStepKind.total),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Aulas de $month',
                subtitle: 'Toque em uma aula para marcar falta, remarcação ou crédito.',
                child: LayoutBuilder(builder: (context, box) {
                  final columns = box.maxWidth >= 560 ? 6 : 4;
                  const gap = 8.0;
                  final w = (box.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(spacing: gap, runSpacing: gap, children: [
                    for (final line in bill.lines)
                      SizedBox(
                        width: w,
                        child: _LessonTile(line: line, onTap: () => openLessonEditor(context, plan, line)),
                      ),
                  ]);
                }),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, box) {
                final vacation = OutlinedButton.icon(
                  onPressed: () => openVacationSheet(context, plan),
                  icon: const Icon(Icons.beach_access_rounded, size: 18),
                  label: const Text('Férias ou ausência'),
                );
                final pay = FilledButton.icon(
                  onPressed: status == BillStatus.paid ? null : () => openPaymentSheet(context, plan),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('Registrar pagamento'),
                );
                if (box.maxWidth < 440) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    pay,
                    const SizedBox(height: 8),
                    vacation,
                  ]);
                }
                return Row(children: [
                  Expanded(child: vacation),
                  const SizedBox(width: 10),
                  Expanded(child: pay),
                ]);
              }),
              if (payments.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Section(
                  title: 'Pagamentos deste mês',
                  child: Column(children: [
                    for (final p in payments)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          const Icon(Icons.check_circle_rounded, color: CF.green, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text('${ddmm(p.date)} · ${p.method}', style: CF.body(15))),
                          Text(money(p.amount), style: CF.score(20)),
                        ]),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => confirmUndoPayment(context, plan),
                        child: const Text('Desfazer último pagamento'),
                      ),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CF.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CF.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: CF.body(18, weight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: CF.body(14, color: CF.muted)),
          ],
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final BillStep step;

  @override
  Widget build(BuildContext context) {
    final isTotal = step.kind == BillStepKind.total;
    final isResult = step.kind == BillStepKind.result;
    final color = switch (step.kind) {
      BillStepKind.minus => CF.red,
      BillStepKind.plus => CF.green,
      _ => CF.text,
    };
    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: isTotal ? 10 : 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Text(step.label,
              style: CF.body(isTotal ? 16 : 15,
                  color: step.value.isEmpty ? CF.muted : CF.text,
                  weight: isTotal || isResult ? FontWeight.w700 : FontWeight.w400)),
        ),
        if (step.value.isNotEmpty) ...[
          const SizedBox(width: 12),
          Text(step.value,
              style: isTotal
                  ? CF.score(28)
                  : CF.body(15, color: color, weight: isResult ? FontWeight.w700 : FontWeight.w600)),
        ],
      ]),
    );
    if (!isTotal && !isResult) return row;
    return Column(children: [const Divider(height: 14), row]);
  }
}

String _tileLabel(LessonLine line) {
  final note = line.record?.note ?? '';
  if (line.outcome == LessonOutcome.cancelledWaived && (note == 'Férias' || note == 'Viagem')) return note;
  if (line.outcome == LessonOutcome.cancelledWaived) return 'Cancelada';
  return line.outcome.label;
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.line, required this.onTap});
  final LessonLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = CF.forOutcome(line.outcome);
    final struck = line.outcome == LessonOutcome.cancelledWaived ||
        line.outcome == LessonOutcome.movedOut ||
        line.outcome == LessonOutcome.holiday;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(weekdayShort[line.date.weekday - 1], style: CF.body(12, color: fg)),
            Text(
              line.date.day.toString().padLeft(2, '0'),
              style: CF.score(26, color: fg).copyWith(
                decoration: struck ? TextDecoration.lineThrough : null,
                decorationColor: fg,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(_tileLabel(line),
                  maxLines: 1, style: CF.body(12, color: fg, weight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editar uma aula
// ---------------------------------------------------------------------------

Future<void> openLessonEditor(BuildContext context, StudentPlan plan, LessonLine line) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _LessonEditor(plan: plan, line: line),
      ),
    );

class _LessonEditor extends StatefulWidget {
  const _LessonEditor({required this.plan, required this.line});
  final StudentPlan plan;
  final LessonLine line;

  @override
  State<_LessonEditor> createState() => _LessonEditorState();
}

class _LessonEditorState extends State<_LessonEditor> {
  final store = BillingStore.instance;
  late LessonStatus status = _initialStatus();
  late bool? charge = widget.line.record?.charge;
  late bool credit = widget.line.record?.credit ?? false;
  late DateTime? newDate = widget.line.record?.newDate;
  late final note = TextEditingController(text: widget.line.record?.note ?? '');
  String? error;

  LessonStatus _initialStatus() {
    final s = widget.line.record?.status ?? LessonStatus.scheduled;
    return s == LessonStatus.rescheduled ? LessonStatus.scheduled : s;
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  bool get _cancelChargeValue => charge ?? store.rules.cancel == CancelRule.charge;

  String get _nextMonthName {
    final d = widget.line.date;
    return monthNames[DateTime(d.year, d.month + 1).month - 1];
  }

  Future<void> _pickDate() async {
    final d = widget.line.date;
    final picked = await showDatePicker(
      context: context,
      initialDate: newDate ?? d.add(const Duration(days: 1)),
      firstDate: DateTime(d.year, d.month - 2),
      lastDate: DateTime(d.year, d.month + 3, 0),
      helpText: 'Nova data da aula',
    );
    if (picked != null) setState(() => newDate = picked);
  }

  void _save() {
    final record = LessonRecord(
      status: status,
      charge: status == LessonStatus.cancelled
          ? _cancelChargeValue
          : (status == LessonStatus.moved ? false : (credit ? false : null)),
      credit: status == LessonStatus.moved || status == LessonStatus.cancelled ? false : credit,
      newDate: status == LessonStatus.moved ? newDate : null,
      note: note.text.trim(),
    );
    final message = store.saveLesson(widget.plan.id, widget.line.date, record);
    if (message != null) {
      setState(() => error = message);
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Aula de ${ddmm(widget.line.date)} atualizada. A conta já foi refeita.')),
    );
  }

  void _clear() {
    store.clearLesson(widget.plan.id, widget.line.date);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Aula de ${ddmm(widget.line.date)} voltou ao normal.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final d = line.date;
    final time = line.time.isEmpty ? '' : ' · ${line.time}';
    final holiday = store.holidayOn(d);

    if (line.isMakeUp) return _makeUpView(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${weekdayLong[d.weekday - 1]}, ${ddmm(d)}$time', style: CF.body(22, weight: FontWeight.w700)),
            Text(widget.plan.name, style: CF.body(15, color: CF.muted)),
            if (holiday != null && holiday.noClass && store.rules.holiday == HolidayRule.noCharge) ...[
              const SizedBox(height: 12),
              _InfoBox(
                icon: Icons.event_busy_rounded,
                text: '${holiday.name}: pela sua regra, não há aula nem cobrança neste dia.',
              ),
            ],
            const SizedBox(height: 16),
            Text('O que aconteceu?', style: CF.body(16, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in const [
                LessonStatus.scheduled,
                LessonStatus.completed,
                LessonStatus.cancelled,
                LessonStatus.moved,
              ])
                ChoiceChip(
                  label: Text(s.label),
                  selected: status == s,
                  showCheckmark: false,
                  selectedColor: CF.ink,
                  labelStyle: CF.body(15, weight: FontWeight.w600, color: status == s ? Colors.white : CF.text),
                  onSelected: (_) => setState(() {
                    status = s;
                    error = null;
                  }),
                ),
            ]),
            const SizedBox(height: 12),
            if (status == LessonStatus.cancelled)
              _SwitchBox(
                title: 'Cobrar esta aula',
                subtitle: _cancelChargeValue
                    ? 'Entra na conta deste mês e vira 1 aula de desconto em $_nextMonthName.'
                    : 'Não entra na conta deste mês.',
                value: _cancelChargeValue,
                onChanged: (v) => setState(() => charge = v),
              ),
            if (status == LessonStatus.moved) ...[
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text(newDate == null ? 'Escolher a nova data' : 'Nova data: ${ddmm(newDate!)}'),
              ),
              const SizedBox(height: 6),
              Text(
                newDate != null && (newDate!.month != d.month || newDate!.year != d.year)
                    ? (store.rules.move == MoveRule.chargeNewMonth
                        ? 'A aula sai da conta deste mês e entra na conta de ${monthNames[newDate!.month - 1]}.'
                        : 'A aula continua na conta deste mês; a reposição não é cobrada de novo.')
                    : 'A aula sai desta data e é cobrada na nova data.',
                style: CF.body(14, color: CF.muted),
              ),
            ],
            if (status == LessonStatus.scheduled || status == LessonStatus.completed)
              _SwitchBox(
                title: 'Transformar em crédito',
                subtitle: credit
                    ? 'Esta aula não será cobrada e fica registrada como crédito do aluno.'
                    : 'Use quando o aluno já pagou esta aula antes.',
                value: credit,
                onChanged: (v) => setState(() => credit = v),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Observação (opcional)'),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: CF.body(15, color: CF.red, weight: FontWeight.w600)),
            ],
            const SizedBox(height: 18),
            Row(children: [
              if (line.record != null)
                TextButton(onPressed: _clear, child: const Text('Voltar ao normal')),
              const Spacer(),
              FilledButton(onPressed: _save, child: const Text('Salvar aula')),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _makeUpView(BuildContext context) {
    final line = widget.line;
    final origin = line.record?.originDate;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${weekdayLong[line.date.weekday - 1]}, ${ddmm(line.date)}', style: CF.body(22, weight: FontWeight.w700)),
        Text(widget.plan.name, style: CF.body(15, color: CF.muted)),
        const SizedBox(height: 14),
        _InfoBox(
          icon: Icons.swap_horiz_rounded,
          text: origin == null
              ? 'Esta é uma aula de reposição.'
              : 'Reposição da aula de ${ddmm(origin)}. ${line.outcome.isCharged ? 'É cobrada nesta data.' : 'Já foi cobrada no mês original.'}',
        ),
        const SizedBox(height: 18),
        Row(children: [
          TextButton(
            onPressed: () {
              store.clearLesson(widget.plan.id, line.date);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Remarcação desfeita. A aula voltou para a data original.')),
              );
            },
            child: const Text('Desfazer remarcação'),
          ),
          const Spacer(),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ]),
      ]),
    );
  }
}

class _SwitchBox extends StatelessWidget {
  const _SwitchBox({required this.title, required this.subtitle, required this.value, required this.onChanged});
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: CF.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CF.line),
        ),
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          activeTrackColor: CF.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: CF.body(16, weight: FontWeight.w700)),
          subtitle: Text(subtitle, style: CF.body(14, color: CF.muted)),
        ),
      );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: CF.greyBg, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: CF.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: CF.body(15, color: CF.text))),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Férias ou ausência
// ---------------------------------------------------------------------------

Future<void> openVacationSheet(BuildContext context, StudentPlan plan) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _VacationSheet(plan: plan, messengerContext: context),
    );

class _VacationSheet extends StatefulWidget {
  const _VacationSheet({required this.plan, required this.messengerContext});
  final StudentPlan plan;
  final BuildContext messengerContext;

  @override
  State<_VacationSheet> createState() => _VacationSheetState();
}

class _VacationSheetState extends State<_VacationSheet> {
  final store = BillingStore.instance;
  DateTimeRange? range;
  String reason = 'Férias';

  Future<void> _pick() async {
    final m = store.selectedMonth;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(m.year - 1, 1, 1),
      lastDate: DateTime(m.year + 1, 12, 31),
      initialDateRange: range,
      currentDate: store.today,
      helpText: 'Período de ausência',
    );
    if (picked != null) setState(() => range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final dates = range == null ? <DateTime>[] : store.vacationPreview(widget.plan.id, range!.start, range!.end);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Férias ou ausência', style: CF.body(22, weight: FontWeight.w700)),
            Text(
              'As aulas de ${widget.plan.name.split(' ').first} no período são canceladas sem cobrança, '
              'sem precisar mexer aula por aula.',
              style: CF.body(15, color: CF.muted),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.date_range_rounded, size: 18),
              label: Text(range == null
                  ? 'Escolher o período'
                  : 'De ${ddmm(range!.start)} até ${ddmm(range!.end)}'),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final r in const ['Férias', 'Viagem', 'Outro motivo'])
                ChoiceChip(
                  label: Text(r),
                  selected: reason == r,
                  showCheckmark: false,
                  selectedColor: CF.ink,
                  labelStyle: CF.body(15, weight: FontWeight.w600, color: reason == r ? Colors.white : CF.text),
                  onSelected: (_) => setState(() => reason = r),
                ),
            ]),
            const SizedBox(height: 14),
            if (range != null)
              _InfoBox(
                icon: dates.isEmpty ? Icons.info_outline_rounded : Icons.event_busy_rounded,
                text: dates.isEmpty
                    ? 'Nenhuma aula da rotina cai nesse período. Nada vai mudar.'
                    : '${lessonsText(dates.length)} sem cobrança: ${dates.map(ddmm).join(', ')}.',
              ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: dates.isEmpty
                  ? null
                  : () {
                      final before = store.applyVacation(widget.plan.id, range!.start, range!.end, reason);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(widget.messengerContext).showSnackBar(SnackBar(
                        duration: const Duration(seconds: 8),
                        content: Text('${lessonsText(dates.length)} marcadas como $reason.'),
                        action: SnackBarAction(
                          label: 'Desfazer',
                          onPressed: () => store.restore(widget.plan.id, before),
                        ),
                      ));
                    },
              child: Text(dates.isEmpty ? 'Aplicar' : 'Cancelar ${lessonsText(dates.length)} sem cobrança'),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Registrar pagamento
// ---------------------------------------------------------------------------

Future<void> openPaymentSheet(BuildContext context, StudentPlan plan) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: _PaymentSheet(plan: plan, messengerContext: context),
      ),
    );

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.plan, required this.messengerContext});
  final StudentPlan plan;
  final BuildContext messengerContext;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final store = BillingStore.instance;
  late final amount = TextEditingController(text: _format(store.remaining(widget.plan)));
  String method = 'Pix';
  late DateTime date = store.today;
  String? error;

  static String _format(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  double? _parse(String s) {
    final clean = s.replaceAll('R\$', '').replaceAll(' ', '').replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean);
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(date.year - 1),
      lastDate: DateTime(date.year + 1, 12, 31),
      helpText: 'Data do pagamento',
    );
    if (picked != null) setState(() => date = picked);
  }

  void _save() {
    final v = _parse(amount.text);
    if (v == null || v <= 0) {
      setState(() => error = 'Digite um valor maior que zero.');
      return;
    }
    store.addPayment(widget.plan.id, PaymentEntry(amount: v, date: date, method: method));
    Navigator.pop(context);
    final left = store.remaining(widget.plan);
    ScaffoldMessenger.of(widget.messengerContext).showSnackBar(SnackBar(
      content: Text(left <= 0
          ? 'Pagamento registrado. ${widget.plan.name.split(' ').first} está em dia.'
          : 'Pagamento registrado. Ainda falta ${money(left)}.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bill = store.bill(widget.plan);
    final remaining = store.remaining(widget.plan);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Registrar pagamento', style: CF.body(22, weight: FontWeight.w700)),
            Text(
              '${widget.plan.name} · conta de ${money(bill.total)}, falta ${money(remaining)}',
              style: CF.body(15, color: CF.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              style: CF.score(30),
              decoration: InputDecoration(
                labelText: 'Valor recebido',
                prefixText: 'R\$ ',
                prefixStyle: CF.score(30, color: CF.muted),
                helperText: 'Pode ser só uma parte. O restante continua em aberto.',
              ),
              onChanged: (_) => setState(() => error = null),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in const ['Pix', 'Dinheiro', 'Cartão', 'Transferência'])
                ChoiceChip(
                  label: Text(m),
                  selected: method == m,
                  showCheckmark: false,
                  selectedColor: CF.ink,
                  labelStyle: CF.body(15, weight: FontWeight.w600, color: method == m ? Colors.white : CF.text),
                  onSelected: (_) => setState(() => method = m),
                ),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text('Recebido em ${ddmm(date)}'),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: CF.body(15, color: CF.red, weight: FontWeight.w600)),
            ],
            const SizedBox(height: 18),
            FilledButton(onPressed: _save, child: const Text('Registrar pagamento')),
          ]),
        ),
      ),
    );
  }
}

Future<void> confirmUndoPayment(BuildContext context, StudentPlan plan) async {
  final store = BillingStore.instance;
  final list = store.payments(plan.id);
  if (list.isEmpty) return;
  final last = list.last;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Desfazer pagamento?'),
      content: Text('O pagamento de ${money(last.amount)} em ${ddmm(last.date)} será removido '
          'e o valor volta a ficar em aberto.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Manter')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: CF.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Desfazer pagamento'),
        ),
      ],
    ),
  );
  if (ok == true) store.removeLastPayment(plan.id);
}

Future<void> openDueDayDialog(BuildContext context, StudentPlan plan) async {
  final input = TextEditingController(text: '${plan.dueDay}');
  final day = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Vencimento de ${plan.name.split(' ').first}'),
      content: TextField(
        controller: input,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Dia do mês (1 a 31)',
          helperText: 'Em meses mais curtos, vale o último dia.',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final n = int.tryParse(input.text);
            if (n != null && n >= 1 && n <= 31) Navigator.pop(ctx, n);
          },
          child: const Text('Salvar vencimento'),
        ),
      ],
    ),
  );
  input.dispose();
  if (day != null) BillingStore.instance.setDueDay(plan.id, day);
}

// ---------------------------------------------------------------------------
// WhatsApp
// ---------------------------------------------------------------------------

String billingMessage(StudentPlan plan) {
  final store = BillingStore.instance;
  final bill = store.bill(plan);
  final received = store.received(plan.id);
  final remaining = store.remaining(plan);
  final due = store.dueDate(plan);
  final pix = DemoLedger.instance.professionalPixKey;
  final first = plan.name.split(' ').first;
  final b = StringBuffer()
    ..writeln('Olá, $first! Tudo bem?')
    ..writeln()
    ..writeln('Segue o resumo de ${monthNames[bill.month - 1]}:')
    ..writeln('• ${lessonsText(bill.chargedLessons)} × ${money(bill.rate)}');
  if (bill.discountLessons > 0) {
    final prev = previousMonth(bill.year, bill.month);
    b.writeln('• Desconto da falta de ${monthNames[prev.month - 1]}: −${money(bill.discountValue).replaceFirst('−', '')}');
  }
  b.writeln('Total: ${money(bill.total)}');
  if (received > 0) {
    b
      ..writeln('Já recebido: ${money(received)}')
      ..writeln('Falta: ${money(remaining)}');
  }
  b.writeln('Vencimento: ${ddmm(due)}');
  if (pix.isNotEmpty) b.writeln('Pix: $pix');
  b
    ..writeln()
    ..write('Qualquer dúvida, é só me chamar.');
  return b.toString();
}

Future<void> openWhatsAppBilling(BuildContext context, StudentPlan plan) async {
  final controller = TextEditingController(text: billingMessage(plan));
  final send = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.viewInsetsOf(sheet).bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Cobrar ${plan.name.split(' ').first}', style: CF.body(22, weight: FontWeight.w700)),
            Text('Confira a mensagem. Nada é enviado sem você tocar em enviar no WhatsApp.',
                style: CF.body(15, color: CF.muted)),
            const SizedBox(height: 14),
            TextField(controller: controller, minLines: 8, maxLines: 14, style: CF.body(16)),
            if (DemoLedger.instance.professionalPixKey.isEmpty) ...[
              const SizedBox(height: 8),
              Text('Dica: cadastre sua chave Pix em Mais › Configurações para ela aparecer aqui.',
                  style: CF.body(14, color: CF.muted)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: CF.whatsapp),
              onPressed: () => Navigator.pop(sheet, true),
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: const Text('Abrir no WhatsApp'),
            ),
          ]),
        ),
      ),
    ),
  );
  final text = controller.text;
  controller.dispose();
  if (send != true) return;
  var phone = plan.phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (phone.length == 10 || phone.length == 11) phone = '55$phone';
  final url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(text)}');
  final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o WhatsApp neste aparelho.')),
    );
  }
}
