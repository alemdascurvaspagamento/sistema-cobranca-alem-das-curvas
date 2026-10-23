import 'package:flutter/material.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_screen.dart';
import '../billing/billing_store.dart';
import '../ui/cf_theme.dart';
import '../ui/widgets.dart';

/// Início: o dia de hoje, o que precisa de atenção e o mês em uma olhada.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onAgenda, required this.onBilling, required this.onClients});
  final VoidCallback onAgenda, onBilling, onClients;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final now = DateTime.now();
        final today = store.sessionsOn(now);
        final summary = _DaySummary(today: today, onAgenda: onAgenda);
        final todo = _Secretary(onBilling: onBilling);
        final agenda = _TodayAgenda(today: today, onAgenda: onAgenda);
        final month = _MonthGlance(onBilling: onBilling);
        return LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 980;
          final header = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greetingFor(now), style: CF.body(28, weight: FontWeight.w700)),
            Text(capitalize(fullDate(now)), style: CF.body(15, color: CF.muted)),
          ]);
          if (wide) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              header,
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 6,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    summary,
                    const SizedBox(height: 14),
                    agenda,
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    todo,
                    const SizedBox(height: 14),
                    month,
                  ]),
                ),
              ]),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            header,
            const SizedBox(height: 16),
            summary,
            const SizedBox(height: 14),
            todo,
            const SizedBox(height: 14),
            agenda,
            const SizedBox(height: 14),
            month,
            const SizedBox(height: 8),
          ]);
        });
      },
    );
  }
}

int _minutes(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return 24 * 60;
  return (int.tryParse(parts[0]) ?? 24) * 60 + (int.tryParse(parts[1]) ?? 0);
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.today, required this.onAgenda});
  final List<(StudentPlan, LessonLine)> today;
  final VoidCallback onAgenda;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final t = store.terms;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final active = today.where((e) => store.happens(e.$2.outcome)).toList();
    final next = active.where((e) => e.$2.time.isNotEmpty && _minutes(e.$2.time) >= nowMin).toList();
    final nextText = next.isEmpty
        ? (active.isEmpty ? 'Dia livre na agenda.' : 'Nenhum${t.g('a', '')} ${t.session} pela frente hoje.')
        : 'Próxim${t.g('a', 'o')}: ${next.first.$2.time} · ${next.first.$1.name}';
    return Material(
      color: CF.ink,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onAgenda,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hoje', style: CF.body(15, color: Colors.white70)),
                const SizedBox(height: 4),
                Text(t.count(active.length), style: CF.score(44, color: Colors.white)),
                const SizedBox(height: 8),
                Text(nextText, style: CF.body(15, color: CF.lap, weight: FontWeight.w600)),
              ]),
            ),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: CF.inkSoft, borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.calendar_today_rounded, color: Colors.white),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Itens que pedem ação, com o botão certo em cada um.
class _Secretary extends StatelessWidget {
  const _Secretary({required this.onBilling});
  final VoidCallback onBilling;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final t = store.terms;
    final today = store.today;
    final current = DateTime(today.year, today.month);
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    final items = <Widget>[];

    // Atendimentos de hoje que já passaram e não foram confirmados.
    for (final (p, line) in store.sessionsOn(today)) {
      final pending = line.record == null || (line.isExtra && line.record?.status == LessonStatus.scheduled);
      if (line.outcome == LessonOutcome.charged && pending && line.time.isNotEmpty && _minutes(line.time) < nowMin) {
        items.add(_TodoItem(
          icon: Icons.fact_check_rounded,
          color: CF.blue,
          title: 'Confirme ${t.theSession} das ${line.time}',
          detail: '${p.name} veio? Marque como ${t.g('realizada', 'realizado')} ou registre a falta.',
          actionLabel: t.g('Realizada', 'Realizado'),
          onAction: () => store.saveLesson(p.id, line.date, LessonRecord(status: LessonStatus.completed, extra: line.isExtra)),
          onTap: () => openLessonEditor(context, p, line),
        ));
      }
    }

    for (final p in store.activePlans) {
      final st = store.status(p, month: current);
      final left = store.remaining(p, month: current);
      if (st == BillStatus.overdue) {
        items.add(_TodoItem(
          icon: Icons.error_rounded,
          color: CF.red,
          title: '${p.name} está com pagamento atrasado',
          detail: 'Falta ${money(left)}. Venceu em ${ddmm(store.dueDate(p, month: current))}.',
          actionLabel: 'Cobrar',
          onAction: () => openWhatsAppBilling(context, p),
          onTap: () => openBillDetail(context, p),
        ));
      } else if ((st == BillStatus.pending || st == BillStatus.partial)) {
        final days = store.dueDate(p, month: current).difference(today).inDays;
        if (days >= 0 && days <= 3) {
          items.add(_TodoItem(
            icon: Icons.schedule_rounded,
            color: CF.amber,
            title: days == 0 ? 'Vence hoje: ${p.name}' : '${p.name} vence em $days dia${days == 1 ? '' : 's'}',
            detail: '${money(left)} a receber. Um lembrete gentil ajuda.',
            actionLabel: 'Lembrar',
            onAction: () => openWhatsAppBilling(context, p),
            onTap: () => openBillDetail(context, p),
          ));
        }
      }
      if (p.model == BillingModel.package) {
        final b = store.bill(p, month: current);
        if (b.packageRemaining <= 2) {
          items.add(_TodoItem(
            icon: Icons.inventory_2_rounded,
            color: CF.violet,
            title: 'Pacote de ${p.name} está acabando',
            detail: b.packageRemaining == 0
                ? 'Não sobrou nenhum${t.g('a', '')} ${t.session}. O próximo pacote entra na conta.'
                : 'Restam ${t.count(b.packageRemaining)}. Combine a renovação.',
            onTap: () => openBillDetail(context, p),
          ));
        }
      }
    }

    return Panel(
      title: 'Secretária: o que precisa de você',
      child: items.isEmpty
          ? const EmptyNote(icon: Icons.task_alt_rounded, text: 'Tudo em dia por aqui.')
          : Column(children: [
              for (var i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1) const Divider(height: 1),
              ],
            ]),
    );
  }
}

class _TodoItem extends StatelessWidget {
  const _TodoItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.onTap,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final Color color;
  final String title, detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: CF.body(16, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(detail, style: CF.body(14, color: CF.muted)),
              ]),
            ),
            if (actionLabel != null) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                child: Text(actionLabel!),
              ),
            ],
          ]),
        ),
      );
}

class _TodayAgenda extends StatelessWidget {
  const _TodayAgenda({required this.today, required this.onAgenda});
  final List<(StudentPlan, LessonLine)> today;
  final VoidCallback onAgenda;

  @override
  Widget build(BuildContext context) {
    final t = BillingStore.instance.terms;
    return Panel(
      title: 'Agenda de hoje',
      action: TextButton(onPressed: onAgenda, child: const Text('Ver semana')),
      child: today.isEmpty
          ? EmptyNote(icon: Icons.event_available_rounded, text: 'Nenhum${t.g('a', '')} ${t.session} hoje.')
          : Column(children: [
              for (final (p, line) in today)
                SessionRow(plan: p, line: line, onTap: () => openLessonEditor(context, p, line)),
            ]),
    );
  }
}

class _MonthGlance extends StatelessWidget {
  const _MonthGlance({required this.onBilling});
  final VoidCallback onBilling;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final today = store.today;
    final current = DateTime(today.year, today.month);
    final total = store.activePlans.fold(0.0, (s, p) => s + store.bill(p, month: current).total);
    final received = store.clientReceived(current);
    final goal = store.monthlyGoal;
    final progress = goal <= 0 ? 0.0 : (store.totalIn(current) / goal).clamp(0.0, 1.0).toDouble();
    return Panel(
      title: 'Seu mês de ${monthNames[today.month - 1]}',
      action: TextButton(onPressed: onBilling, child: const Text('Cobranças')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: _Stat(label: 'Recebido', value: moneyCompact(received), color: CF.green)),
          Expanded(child: _Stat(label: 'Previsto', value: moneyCompact(total), color: CF.text)),
          Expanded(child: _Stat(label: 'Falta', value: moneyCompact((total - received) < 0 ? 0 : total - received), color: CF.amber)),
        ]),
        if (goal > 0) ...[
          const SizedBox(height: 14),
          Text('Meta do mês: ${moneyCompact(goal)} · ${(progress * 100).round()}% alcançada',
              style: CF.body(14, color: CF.muted)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: CF.greyBg, color: CF.green),
          ),
        ],
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: CF.body(14, color: CF.muted)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: CF.score(26, color: color)),
        ),
      ]);
}
