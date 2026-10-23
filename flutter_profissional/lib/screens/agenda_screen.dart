import 'package:flutter/material.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_screen.dart';
import '../billing/billing_store.dart';
import '../ui/cf_theme.dart';
import '../ui/widgets.dart';

/// Agenda da semana: escolha o dia e veja (e ajuste) cada atendimento.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final store = BillingStore.instance;
  late DateTime day = store.today;

  DateTime get weekStart => day.subtract(Duration(days: day.weekday - 1));

  void _shiftWeek(int delta) => setState(() => day = DateTime(day.year, day.month, day.day + 7 * delta));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final t = store.terms;
        final sessions = store.sessionsOn(day);
        final holiday = store.holidayOn(day);
        final isToday = dateOnly(day) == store.today;
        final happening = sessions.where((e) => store.happens(e.$2.outcome)).length;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageTitle(
            'Agenda',
            subtitle: '${capitalize(monthNames[weekStart.month - 1])} de ${weekStart.year}',
            trailing: FilledButton.icon(
              onPressed: () => _openNewSession(context, day),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Marcar'),
            ),
          ),
          const SizedBox(height: 14),
          _WeekStrip(
            start: weekStart,
            selected: day,
            today: store.today,
            onSelect: (d) => setState(() => day = d),
            onPrev: () => _shiftWeek(-1),
            onNext: () => _shiftWeek(1),
            countFor: store.busyCount,
          ),
          if (!isToday)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => setState(() => day = store.today), child: const Text('Voltar para hoje')),
            ),
          const SizedBox(height: 10),
          Panel(
            title: '${capitalize(fullDate(day))}${isToday ? ' (hoje)' : ''}',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (holiday != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: CF.greyBg, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.celebration_rounded, color: CF.muted, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        holiday.noClass ? '${holiday.name}: dia sem atendimento.' : '${holiday.name}: atendimento normal.',
                        style: CF.body(15),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
              if (sessions.isEmpty)
                EmptyNote(
                  icon: Icons.event_available_rounded,
                  text: 'Nenhum${t.g('a', '')} ${t.session} neste dia.',
                  action: TextButton(onPressed: () => _openNewSession(context, day), child: Text('Marcar ${t.session}')),
                )
              else ...[
                Text(t.count(happening), style: CF.body(14, color: CF.muted)),
                for (final (p, line) in sessions)
                  SessionRow(plan: p, line: line, onTap: () => openLessonEditor(context, p, line)),
              ],
            ]),
          ),
          const SizedBox(height: 8),
          Text('Toque em ${t.g('uma', 'um')} ${t.session} para marcar falta, remarcação ou crédito. '
              'A cobrança do mês é refeita na hora.', style: CF.body(14, color: CF.muted)),
        ]);
      },
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.start,
    required this.selected,
    required this.today,
    required this.onSelect,
    required this.onPrev,
    required this.onNext,
    required this.countFor,
  });
  final DateTime start, selected, today;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrev, onNext;
  final int Function(DateTime) countFor;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconButton(tooltip: 'Semana anterior', onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded)),
      Expanded(
        child: Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _DayPill(
                  date: DateTime(start.year, start.month, start.day + i),
                  selected: dateOnly(selected) == DateTime(start.year, start.month, start.day + i),
                  isToday: today == DateTime(start.year, start.month, start.day + i),
                  count: countFor(DateTime(start.year, start.month, start.day + i)),
                  onTap: () => onSelect(DateTime(start.year, start.month, start.day + i)),
                ),
              ),
            ),
        ]),
      ),
      IconButton(tooltip: 'Próxima semana', onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded)),
    ]);
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.count,
    required this.onTap,
  });
  final DateTime date;
  final bool selected, isToday;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : CF.text;
    return Semantics(
      selected: selected,
      button: true,
      label: '${weekdayLong[date.weekday - 1]} ${date.day}, $count',
      child: Material(
        color: selected ? CF.ink : CF.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? CF.ink : (isToday ? CF.blue : CF.line), width: isToday && !selected ? 2 : 1),
            ),
            child: Column(children: [
              Text(weekdayShort[date.weekday - 1], style: CF.body(12, color: selected ? Colors.white70 : CF.muted)),
              Text('${date.day}', style: CF.score(22, color: fg)),
              const SizedBox(height: 2),
              Container(
                width: 18, height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: count == 0 ? Colors.transparent : (selected ? CF.lap : CF.greyBg),
                  shape: BoxShape.circle,
                ),
                child: count == 0
                    ? null
                    : Text('$count', style: CF.body(11, weight: FontWeight.w700, color: CF.ink)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Marcar atendimento avulso
// ---------------------------------------------------------------------------

Future<void> _openNewSession(BuildContext context, DateTime initial) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _NewSession(initial: initial, messengerContext: context),
    );

class _NewSession extends StatefulWidget {
  const _NewSession({required this.initial, required this.messengerContext});
  final DateTime initial;
  final BuildContext messengerContext;

  @override
  State<_NewSession> createState() => _NewSessionState();
}

class _NewSessionState extends State<_NewSession> {
  final store = BillingStore.instance;
  late DateTime date = widget.initial;
  String? clientId;
  String? error;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(date.year - 1),
      lastDate: DateTime(date.year + 1, 12, 31),
    );
    if (picked != null) setState(() => date = picked);
  }

  void _save() {
    final t = store.terms;
    if (clientId == null) {
      setState(() => error = 'Escolha com quem será ${t.theSession}.');
      return;
    }
    final message = store.addExtra(clientId!, date);
    if (message != null) {
      setState(() => error = message);
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(widget.messengerContext).showSnackBar(SnackBar(
      content: Text('${t.sessionTitle} de ${store.plan(clientId!).name} marcad${t.g('a', 'o')} para ${ddmm(date)}.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = store.terms;
    final plans = store.activePlans..sort((a, b) => a.name.compareTo(b.name));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Marcar ${t.session}', style: CF.body(24, weight: FontWeight.w700)),
            Text('Para ${t.sessions} fora dos dias fixos, como reposição ou consulta avulsa.',
                style: CF.body(15, color: CF.muted)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text(capitalize(fullDate(date))),
            ),
            const SizedBox(height: 14),
            Text('Com quem?', style: CF.body(16, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in plans)
                ChoiceChip(
                  label: Text(p.name),
                  selected: clientId == p.id,
                  showCheckmark: false,
                  selectedColor: CF.ink,
                  labelStyle: CF.body(15, weight: FontWeight.w600, color: clientId == p.id ? Colors.white : CF.text),
                  onSelected: (_) => setState(() {
                    clientId = p.id;
                    error = null;
                  }),
                ),
            ]),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: CF.body(15, color: CF.red, weight: FontWeight.w600)),
            ],
            const SizedBox(height: 18),
            FilledButton(onPressed: _save, child: Text('Marcar ${t.session}')),
          ]),
        ),
      ),
    );
  }
}
