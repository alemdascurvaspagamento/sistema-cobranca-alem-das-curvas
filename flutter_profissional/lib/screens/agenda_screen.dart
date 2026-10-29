import 'package:flutter/material.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_screen.dart';
import '../billing/billing_store.dart';
import '../ui/cf_theme.dart';
import '../ui/widgets.dart';

enum _View { day, week, month }

/// Agenda em três visões: dia, semana e mês. Em todas, tocar em um atendimento
/// abre a edição (falta, remarcação, crédito, horário só daquela data).
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final store = BillingStore.instance;
  late DateTime day = store.today;
  late DateTime month = DateTime(store.today.year, store.today.month);
  _View view = _View.day;

  DateTime get weekStart => DateTime(day.year, day.month, day.day - (day.weekday - 1));

  void _shiftWeek(int delta) => setState(() => day = DateTime(day.year, day.month, day.day + 7 * delta));

  void _shiftMonth(int delta) => setState(() => month = DateTime(month.year, month.month + delta));

  void _openDay(DateTime d) => setState(() {
        day = d;
        view = _View.day;
      });

  /// Atendimentos dos meses que a semana atravessa.
  Map<DateTime, List<(StudentPlan, LessonLine)>> _weekData() {
    final start = weekStart;
    final end = DateTime(start.year, start.month, start.day + 6);
    final data = {...store.sessionsInMonth(start)};
    if (end.month != start.month) data.addAll(store.sessionsInMonth(end));
    return data;
  }

  String _subtitle() => switch (view) {
        _View.day => capitalize(fullDate(day)),
        _View.week => _weekLabel(weekStart),
        _View.month => '${capitalize(monthNames[month.month - 1])} de ${month.year}',
      };

  static String _weekLabel(DateTime start) {
    final end = DateTime(start.year, start.month, start.day + 6);
    return start.month == end.month
        ? '${start.day} a ${end.day} de ${monthNames[end.month - 1]}'
        : '${start.day} de ${monthNames[start.month - 1]} a ${end.day} de ${monthNames[end.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final t = store.terms;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageTitle(
            'Agenda',
            icon: Icons.calendar_month_rounded,
            color: CF.blue,
            subtitle: _subtitle(),
            trailing: FilledButton.icon(
              onPressed: () => _openNewSession(context, day),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Marcar'),
            ),
          ),
          const SizedBox(height: 14),
          _AgendaKpis(weekStart: weekStart),
          const SizedBox(height: 14),
          SegmentedButton<_View>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _View.day, icon: Icon(Icons.today_rounded), label: Text('Dia')),
              ButtonSegment(value: _View.week, icon: Icon(Icons.view_week_rounded), label: Text('Semana')),
              ButtonSegment(value: _View.month, icon: Icon(Icons.calendar_month_rounded), label: Text('Mês')),
            ],
            selected: {view},
            onSelectionChanged: (v) => setState(() {
              view = v.first;
              if (view == _View.month) month = DateTime(day.year, day.month);
            }),
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected) ? Colors.white : CF.ink),
              backgroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected) ? CF.ink : CF.surface),
              side: const WidgetStatePropertyAll(BorderSide(color: CF.line)),
              textStyle: WidgetStatePropertyAll(CF.body(15, weight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 14),
          switch (view) {
            _View.day => _dayView(context),
            _View.week => _WeekView(
                start: weekStart,
                today: store.today,
                data: _weekData(),
                onPrev: () => _shiftWeek(-1),
                onNext: () => _shiftWeek(1),
                onToday: () => setState(() => day = store.today),
                onOpenDay: _openDay,
              ),
            _View.month => _MonthView(
                month: month,
                today: store.today,
                data: store.sessionsInMonth(month),
                onPrev: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
                onToday: () => setState(() => month = DateTime(store.today.year, store.today.month)),
                onOpenDay: _openDay,
              ),
          },
          const SizedBox(height: 8),
          Text('Toque em ${t.g('uma', 'um')} ${t.session} para marcar falta, remarcação, crédito ou mudar o horário. '
              'A cobrança do mês é refeita na hora.', style: CF.body(14, color: CF.muted)),
        ]);
      },
    );
  }

  Widget _dayView(BuildContext context) {
    final t = store.terms;
    final sessions = store.sessionsOn(day);
    final holiday = store.holidayOn(day);
    final isToday = dateOnly(day) == store.today;
    final happening = sessions.where((e) => store.happens(e.$2.outcome)).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
        icon: Icons.calendar_today_rounded,
        color: CF.blue,
        title: '${capitalize(fullDate(day))}${isToday ? ' (hoje)' : ''}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (holiday != null) ...[
            _HolidayNote(holiday: holiday),
            const SizedBox(height: 8),
          ],
          if (sessions.isEmpty)
            EmptyNote(
              icon: Icons.event_available_rounded,
              text: 'Nenhum${t.g('a', '')} ${t.session} neste dia.',
              action: TextButton(onPressed: () => _openNewSession(context, day), child: Text('Marcar ${t.session}')),
            )
          else ...[
            Text('${t.count(happening)}. Toque num atendimento para anotar ou alterar.', style: CF.body(14, color: CF.muted)),
            for (final (p, line) in sessions)
              SessionRow(plan: p, line: line, onTap: () => openLessonEditor(context, p, line)),
          ],
        ]),
      ),
    ]);
  }
}

class _HolidayNote extends StatelessWidget {
  const _HolidayNote({required this.holiday});
  final Holiday holiday;

  @override
  Widget build(BuildContext context) => Container(
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
      );
}

/// Barra de navegação de período: ‹ título › e "voltar para hoje".
class _PeriodBar extends StatelessWidget {
  const _PeriodBar({required this.label, required this.onPrev, required this.onNext, this.onToday});
  final String label;
  final VoidCallback onPrev, onNext;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) => Row(children: [
        IconButton(tooltip: 'Anterior', onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: Text(label, textAlign: TextAlign.center, style: CF.body(17, weight: FontWeight.w700)),
        ),
        IconButton(tooltip: 'Próximo', onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded)),
        if (onToday != null) TextButton(onPressed: onToday, child: const Text('Hoje')),
      ]);
}

/// Linha compacta de atendimento, usada na semana e no mês.
class _MiniSession extends StatelessWidget {
  const _MiniSession({required this.plan, required this.line, this.dense = false});
  final StudentPlan plan;
  final LessonLine line;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = CF.forOutcome(line.outcome);
    final struck = line.outcome == LessonOutcome.cancelledWaived ||
        line.outcome == LessonOutcome.movedOut ||
        line.outcome == LessonOutcome.holiday;
    final first = plan.name.split(' ').first;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openLessonEditor(context, plan, line),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: dense ? 2 : 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: fg, width: 3)),
          ),
          child: Text(
            '${line.time.isEmpty ? '' : '${line.time} '}${dense ? first : plan.name}',
            maxLines: dense ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: CF.body(dense ? 11 : 13, color: fg, weight: FontWeight.w600)
                .copyWith(decoration: struck ? TextDecoration.lineThrough : null, decorationColor: fg),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Semana
// ---------------------------------------------------------------------------

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.start,
    required this.today,
    required this.data,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onOpenDay,
  });
  final DateTime start, today;
  final Map<DateTime, List<(StudentPlan, LessonLine)>> data;
  final VoidCallback onPrev, onNext, onToday;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final t = store.terms;
    final days = [for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i)];
    final isThisWeek = days.contains(today);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _PeriodBar(
        label: _AgendaScreenState._weekLabel(start),
        onPrev: onPrev,
        onNext: onNext,
        onToday: isThisWeek ? null : onToday,
      ),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (context, box) {
        if (box.maxWidth >= 900) {
          // Computador: 7 colunas lado a lado.
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final d in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _WeekColumn(day: d, isToday: d == today, items: data[d] ?? const [], onOpenDay: onOpenDay),
                ),
              ),
          ]);
        }
        // Celular: um bloco por dia, todos os dias aparecem.
        return Column(children: [
          for (final d in days)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  InkWell(
                    onTap: () => onOpenDay(d),
                    child: Row(children: [
                      Text('${capitalize(weekdayLong[d.weekday - 1])}, ${ddmm(d)}',
                          style: CF.body(16, weight: FontWeight.w700, color: d == today ? CF.blue : CF.text)),
                      if (d == today) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: CF.lap, borderRadius: BorderRadius.circular(999)),
                          child: Text('Hoje', style: CF.body(12, weight: FontWeight.w700, color: CF.ink)),
                        ),
                      ],
                      const Spacer(),
                      Text(t.count((data[d] ?? const []).where((e) => store.happens(e.$2.outcome)).length),
                          style: CF.body(13, color: CF.muted)),
                    ]),
                  ),
                  if (store.holidayOn(d) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Feriado: ${store.holidayOn(d)!.name}', style: CF.body(13, color: CF.muted)),
                    ),
                  if ((data[d] ?? const []).isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text('Sem ${t.sessions} neste dia', style: CF.body(14, color: CF.muted)),
                    )
                  else
                    for (final (p, line) in data[d]!)
                      SessionRow(plan: p, line: line, onTap: () => openLessonEditor(context, p, line)),
                ]),
              ),
            ),
        ]);
      }),
    ]);
  }
}

class _WeekColumn extends StatelessWidget {
  const _WeekColumn({required this.day, required this.isToday, required this.items, required this.onOpenDay});
  final DateTime day;
  final bool isToday;
  final List<(StudentPlan, LessonLine)> items;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final holiday = BillingStore.instance.holidayOn(day);
    return Container(
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: CF.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isToday ? CF.blue : CF.line, width: isToday ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => onOpenDay(day),
          child: Column(children: [
            Text(weekdayShort[day.weekday - 1], style: CF.body(13, color: CF.muted)),
            Text('${day.day}', style: CF.score(26, color: isToday ? CF.blue : CF.text)),
          ]),
        ),
        if (holiday != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(holiday.name, maxLines: 2, textAlign: TextAlign.center, style: CF.body(11, color: CF.muted)),
          ),
        const SizedBox(height: 4),
        for (final (p, line) in items)
          Padding(padding: const EdgeInsets.only(bottom: 4), child: _MiniSession(plan: p, line: line)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Mês
// ---------------------------------------------------------------------------

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.month,
    required this.today,
    required this.data,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onOpenDay,
  });
  final DateTime month, today;
  final Map<DateTime, List<(StudentPlan, LessonLine)>> data;
  final VoidCallback onPrev, onNext, onToday;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final t = store.terms;
    final isThisMonth = month.year == today.year && month.month == today.month;
    final offset = DateTime(month.year, month.month, 1).weekday - 1; // começa na segunda
    final days = daysInMonth(month.year, month.month);
    final cells = ((offset + days + 6) ~/ 7) * 7;
    final total = data.values.fold<int>(0, (s, l) => s + l.where((e) => store.happens(e.$2.outcome)).length);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _PeriodBar(
        label: '${capitalize(monthNames[month.month - 1])} de ${month.year}',
        onPrev: onPrev,
        onNext: onNext,
        onToday: isThisMonth ? null : onToday,
      ),
      Text('${t.count(total)} no mês', textAlign: TextAlign.center, style: CF.body(14, color: CF.muted)),
      const SizedBox(height: 10),
      Panel(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 760;
          return Column(children: [
            Row(children: [
              for (final w in weekdayShort)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(w, textAlign: TextAlign.center, style: CF.body(12, color: CF.muted, weight: FontWeight.w700)),
                  ),
                ),
            ]),
            for (var row = 0; row < cells ~/ 7; row++)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(builder: (context) {
                      final n = row * 7 + col - offset + 1;
                      if (n < 1 || n > days) return SizedBox(height: wide ? 112 : 64);
                      final d = DateTime(month.year, month.month, n);
                      return _MonthCell(
                        day: d,
                        isToday: d == today,
                        wide: wide,
                        items: data[d] ?? const [],
                        holiday: store.holidayOn(d),
                        onTap: () => onOpenDay(d),
                      );
                    }),
                  ),
              ]),
          ]);
        }),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 14, runSpacing: 6, children: [
        _Legend(color: CF.blue, text: t.g('Agendada', 'Agendado')),
        _Legend(color: CF.amber, text: 'Falta cobrada ou remarcação'),
        _Legend(color: CF.red, text: t.g('Cancelada', 'Cancelado')),
        _Legend(color: CF.violet, text: 'Crédito'),
        _Legend(color: CF.grey, text: 'Feriado'),
      ]),
    ]);
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.day,
    required this.isToday,
    required this.wide,
    required this.items,
    required this.holiday,
    required this.onTap,
  });
  final DateTime day;
  final bool isToday, wide;
  final List<(StudentPlan, LessonLine)> items;
  final Holiday? holiday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shown = wide ? items.take(3).toList() : const <(StudentPlan, LessonLine)>[];
    final extra = items.length - shown.length;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: isToday ? const Color(0xFFE9EFFA) : CF.bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: wide ? 112 : 64,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isToday ? CF.blue : Colors.transparent, width: 1.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${day.day}', style: CF.score(18, color: isToday ? CF.blue : CF.text)),
                if (holiday != null) ...[
                  const SizedBox(width: 3),
                  const Icon(Icons.celebration_rounded, size: 12, color: CF.muted),
                ],
              ]),
              const SizedBox(height: 2),
              if (wide) ...[
                for (final (p, line) in shown)
                  Padding(padding: const EdgeInsets.only(bottom: 2), child: _MiniSession(plan: p, line: line, dense: true)),
                if (extra > 0) Text('+$extra', style: CF.body(11, color: CF.muted, weight: FontWeight.w700)),
              ] else if (items.isNotEmpty) ...[
                // Celular: bolinhas coloridas (até 4) e o total.
                Wrap(spacing: 2, runSpacing: 2, children: [
                  for (final (_, line) in items.take(4))
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(color: CF.forOutcome(line.outcome).$1, shape: BoxShape.circle),
                    ),
                ]),
                const Spacer(),
                Text('${items.length}', style: CF.body(11, color: CF.muted, weight: FontWeight.w700)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(text, style: CF.body(13, color: CF.muted)),
      ]);
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
  String? time;
  String? clientId;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
    if (picked != null) {
      setState(() => time = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }
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
    final message = store.addExtra(clientId!, date, time: time);
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
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(time == null ? 'Escolher horário (opcional)' : 'Às $time'),
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

/// Números da agenda: hoje, semana e faltas do mês.
class _AgendaKpis extends StatelessWidget {
  const _AgendaKpis({required this.weekStart});
  final DateTime weekStart;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final t = store.terms;
    final today = store.today;
    int count(DateTime d) => store.sessionsOn(d).where((e) => store.happens(e.$2.outcome)).length;
    var week = 0;
    for (var i = 0; i < 7; i++) {
      week += count(weekStart.add(Duration(days: i)));
    }
    final st = store.sessionStats(DateTime(today.year, today.month));
    return KpiRow([
      KpiCard(icon: Icons.today_rounded, label: 'Hoje', value: '${count(today)}', hint: t.sessionsTitle, color: CF.blue, accent: true),
      KpiCard(icon: Icons.view_week_rounded, label: 'Na semana', value: '$week', hint: 'Da semana mostrada', color: CF.green, accent: true),
      KpiCard(icon: Icons.event_busy_rounded, label: 'Faltas no mês', value: '${st.cancelled}', hint: '${st.cancelledCharged} cobradas', color: CF.amber, accent: true),
      KpiCard(icon: Icons.event_repeat_rounded, label: 'Reposições', value: '${st.makeUps}', hint: 'No mês', color: CF.violet, accent: true),
    ]);
  }
}
