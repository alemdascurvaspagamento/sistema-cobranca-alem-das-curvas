import 'package:flutter/material.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_screen.dart';
import '../billing/billing_store.dart';
import '../ui/cf_theme.dart';
import '../ui/widgets.dart';
import 'clients_screen.dart' show openClientForm;

/// Início: o dia de hoje, o que precisa de atenção e o mês em uma olhada.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onAgenda,
    required this.onBilling,
    required this.onClients,
    this.onFinance,
    this.onReports,
  });
  final VoidCallback onAgenda, onBilling, onClients;
  final VoidCallback? onFinance, onReports;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final now = DateTime.now();
        final today = store.sessionsOn(now);
        final summary = _DaySummary(today: today, onAgenda: onAgenda);
        final todo = _Secretary(onBilling: onBilling, onFinance: onFinance);
        final agenda = _TodayAgenda(today: today, onAgenda: onAgenda);
        final month = _MonthGlance(onBilling: onBilling, onReports: onReports);
        final late = store.overdueByMonth();
        final overdue = late.isEmpty ? null : _OverdueCard(items: late, onBilling: onBilling);
        return LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 980;
          final t = store.terms;
          final header = Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(greetingFor(now), style: CF.body(28, weight: FontWeight.w700)),
                Text(capitalize(fullDate(now)), style: CF.body(15, color: CF.muted)),
              ]),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => openClientForm(context),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: Text('Novo ${t.client}'),
            ),
          ]);
          final starter = _StartHere(onBilling: onBilling);
          if (wide) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              header,
              const SizedBox(height: 16),
              starter,
              if (overdue != null) ...[overdue, const SizedBox(height: 14)],
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
            starter,
            if (overdue != null) ...[overdue, const SizedBox(height: 14)],
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
              decoration: BoxDecoration(color: CF.lap.withValues(alpha: .16), borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.calendar_today_rounded, color: CF.lap),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Itens que pedem ação, com o botão certo em cada um.
class _Secretary extends StatelessWidget {
  const _Secretary({required this.onBilling, this.onFinance});
  final VoidCallback onBilling;
  final VoidCallback? onFinance;

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
          onAction: () => store.saveLesson(p.id, line.date, LessonRecord(status: LessonStatus.completed, extra: line.isExtra, time: line.record?.time)),
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

    // Contas do profissional atrasadas ou vencendo nos próximos dias.
    for (final e in store.billsDue()) {
      final overdue = dateOnly(e.date).isBefore(today);
      final isToday = dateOnly(e.date) == today;
      items.add(_TodoItem(
        icon: Icons.receipt_long_rounded,
        color: overdue ? CF.red : CF.amber,
        title: overdue
            ? 'Conta atrasada: ${e.description}'
            : (isToday ? 'Conta vence hoje: ${e.description}' : 'Conta vence em ${ddmm(e.date)}: ${e.description}'),
        detail: '${money(e.amount)}${e.fixed ? ' · despesa fixa' : ''}. Já pagou? Dê baixa.',
        actionLabel: 'Dar baixa',
        onAction: () => store.payExpense(e),
        onTap: onFinance ?? () {},
      ));
    }

    return Panel(
      icon: Icons.support_agent_rounded,
      color: CF.amber,
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
            IconBadge(icon, color: color, size: 38),
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
      icon: Icons.calendar_today_rounded,
      color: CF.blue,
      title: 'Agenda de hoje',
      action: TextButton(onPressed: onAgenda, child: const Text('Ver semana')),
      child: today.isEmpty
          ? EmptyNote(icon: Icons.event_available_rounded, text: 'Nenhum${t.g('a', '')} ${t.session} hoje.')
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Toque num atendimento para anotar ou alterar.', style: CF.body(13.5, color: CF.muted)),
              ),
              for (final (p, line) in today)
                SessionRow(plan: p, line: line, onTap: () => openLessonEditor(context, p, line)),
            ]),
    );
  }
}

class _MonthGlance extends StatelessWidget {
  const _MonthGlance({required this.onBilling, this.onReports});
  final VoidCallback onBilling;
  final VoidCallback? onReports;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final today = store.today;
    final current = DateTime(today.year, today.month);
    final f = store.forecast(current);
    final goal = store.monthlyGoal;
    final progress = goal <= 0 ? 0.0 : (f.incomeNow / goal).clamp(0.0, 1.0).toDouble();
    return Panel(
      icon: Icons.insights_rounded,
      color: CF.violet,
      title: 'Seu mês de ${monthNames[today.month - 1]}',
      action: TextButton(onPressed: onReports ?? onBilling, child: Text(onReports != null ? 'Relatórios' : 'Cobranças')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _GroupLabel(Icons.trending_up_rounded, 'Vai faturar', CF.green),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _Stat(label: 'Previsto', value: moneyCompact(f.incomePlanned), color: CF.blue)),
          const SizedBox(width: 8),
          Expanded(child: _Stat(label: 'Recebido', value: moneyCompact(f.incomeNow), color: CF.green)),
          const SizedBox(width: 8),
          Expanded(child: _Stat(label: 'A receber', value: moneyCompact(f.open), color: CF.amber)),
        ]),
        const SizedBox(height: 12),
        const _GroupLabel(Icons.trending_down_rounded, 'Vai gastar', CF.red),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _Stat(label: 'Previsto', value: moneyCompact(f.expensesPlanned), color: CF.violet)),
          const SizedBox(width: 8),
          Expanded(child: _Stat(label: 'Pago', value: moneyCompact(f.expensesPaid), color: CF.red)),
          const SizedBox(width: 8),
          Expanded(child: _Stat(label: 'A pagar', value: moneyCompact(f.expensesOpen), color: CF.amber)),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: f.resultPlanned < 0 ? CF.redBg : CF.greenBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Expanded(
              child: Text('Deve sobrar no mês',
                  style: CF.body(15, weight: FontWeight.w600, color: f.resultPlanned < 0 ? CF.red : CF.green)),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(moneyCompact(f.resultPlanned),
                    style: CF.score(24, color: f.resultPlanned < 0 ? CF.red : CF.green)),
              ),
            ),
          ]),
        ),
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

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.icon, this.text, this.color);
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(children: [
        IconBadge(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Text(text, style: CF.body(14, weight: FontWeight.w700)),
      ]);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
          border: Border(top: BorderSide(color: color, width: 3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: CF.body(11.5, weight: FontWeight.w700, color: CF.muted)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: CF.score(24, color: color)),
          ),
        ]),
      );
}

/// Valor em atraso, em vermelho, com um toque para ir cobrar.
class _OverdueCard extends StatelessWidget {
  const _OverdueCard({required this.items, required this.onBilling});
  final List<({DateTime month, double amount, int count})> items;
  final VoidCallback onBilling;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final t = store.terms;
    final total = items.fold(0.0, (s, e) => s + e.amount);
    void open(DateTime m) {
      store.goToMonth(m);
      onBilling();
    }

    return Material(
      color: CF.redBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => open(items.last.month),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CF.red.withValues(alpha: .35)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const IconBadge(Icons.warning_amber_rounded, color: CF.red, size: 34),
              const SizedBox(width: 10),
              Expanded(child: Text('Em atraso', style: CF.body(16, weight: FontWeight.w700, color: CF.red))),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(money(total), style: CF.score(30, color: CF.red)),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            for (final e in items)
              InkWell(
                onTap: () => open(e.month),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        '${capitalize(monthNames[e.month.month - 1])}: '
                        '${e.count} ${e.count == 1 ? t.client : t.clients}',
                        style: CF.body(15, color: CF.text),
                      ),
                    ),
                    Text(money(e.amount), style: CF.body(15, weight: FontWeight.w700, color: CF.red)),
                    const Icon(Icons.chevron_right_rounded, color: CF.red, size: 20),
                  ]),
                ),
              ),
            const SizedBox(height: 4),
            Text('Toque para ver e cobrar.', style: CF.body(13.5, color: CF.muted)),
          ]),
        ),
      ),
    );
  }
}


/// "Comece por aqui": guia a conta nova pelos primeiros passos e some quando termina.
class _StartHere extends StatefulWidget {
  const _StartHere({required this.onBilling});
  final VoidCallback onBilling;

  /// Vale só enquanto o app está aberto: quem dispensa não vê de novo na sessão.
  static bool dismissed = false;
  static bool seenBilling = false;

  @override
  State<_StartHere> createState() => _StartHereState();
}

class _StartHereState extends State<_StartHere> {
  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final t = store.terms;
    final hasClient = store.plans.isNotEmpty;
    final hasPix = store.pixKey.isNotEmpty;
    final seen = _StartHere.seenBilling;
    if (_StartHere.dismissed || (hasClient && hasPix && seen)) return const SizedBox.shrink();
    final done = [hasClient, hasPix, seen].where((e) => e).length;
    Widget step({
      required int n,
      required bool ok,
      required bool enabled,
      required String title,
      required String detail,
      required String action,
      required VoidCallback onTap,
    }) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            ok
                ? const IconBadge(Icons.check_rounded, color: CF.green, size: 38)
                : Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: CF.blue.withValues(alpha: .13), borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Text('$n', style: CF.score(20, color: CF.blue)),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$n. $title',
                    style: CF.body(16, weight: FontWeight.w700, color: ok ? CF.muted : CF.text)
                        .copyWith(decoration: ok ? TextDecoration.lineThrough : null)),
                Text(detail, style: CF.body(14, color: CF.muted, height: 1.3)),
              ]),
            ),
            if (!ok) ...[
              const SizedBox(width: 8),
              enabled
                  ? FilledButton(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                      child: Text(action),
                    )
                  : OutlinedButton(onPressed: null, child: Text(action)),
            ],
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Panel(
        icon: Icons.rocket_launch_rounded,
        color: CF.amber,
        title: 'Comece por aqui ($done de 3)',
        action: IconButton(
          tooltip: 'Dispensar',
          onPressed: () => setState(() => _StartHere.dismissed = true),
          icon: const Icon(Icons.close_rounded, size: 20),
        ),
        child: Column(children: [
          step(
            n: 1,
            ok: hasClient,
            enabled: true,
            title: 'Cadastre seu primeiro ${t.client}',
            detail: 'Nome, telefone, dias, horários e valor combinado.',
            action: 'Cadastrar',
            onTap: () => openClientForm(context),
          ),
          const Divider(height: 1),
          step(
            n: 2,
            ok: hasPix,
            enabled: true,
            title: 'Cadastre sua chave Pix',
            detail: 'A cobrança já vai com QR Code e copia e cola.',
            action: 'Cadastrar Pix',
            onTap: () async {
              await openPixSettings(context);
              if (mounted) setState(() {});
            },
          ),
          const Divider(height: 1),
          step(
            n: 3,
            ok: seen,
            enabled: hasClient,
            title: 'Veja a cobrança do mês',
            detail: hasClient ? 'O valor de cada ${t.client}, com a conta explicada.' : 'Libera depois do primeiro cadastro.',
            action: 'Ver cobranças',
            onTap: () {
              _StartHere.seenBilling = true;
              widget.onBilling();
            },
          ),
        ]),
      ),
    );
  }
}
