import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'billing/billing_engine.dart';
import 'billing/billing_store.dart';
import 'data/ids.dart';
import 'ui/cf_theme.dart';

/// Compromisso pessoal na agenda (reunião, médico, folga...).
/// Ocupa o horário, mas não entra em cobrança nem em relatório.
class PersonalEvent {
  const PersonalEvent({
    required this.id,
    required this.title,
    required this.date,
    this.time = '',
    this.duration = 60,
    this.weekly = false,
    this.until,
  });

  final String id;
  final String title;
  final DateTime date;

  /// "HH:MM"; vazio = dia inteiro.
  final String time;
  final int duration;

  /// Repete toda semana, no mesmo dia da semana, a partir de [date].
  final bool weekly;
  final DateTime? until;

  bool get allDay => time.isEmpty;

  bool occursOn(DateTime day) {
    final d = dateOnly(day), start = dateOnly(date);
    if (d.isBefore(start)) return false;
    if (until != null && d.isAfter(dateOnly(until!))) return false;
    return weekly ? d.weekday == start.weekday : d == start;
  }

  int get startMinute => allDay ? 0 : minutesOf(time);
  int get endMinute => allDay ? 24 * 60 : startMinute + duration;

  String get timeLabel {
    if (allDay) return 'Dia todo';
    final end = endMinute;
    return '$time–${(end ~/ 60 % 24).toString().padLeft(2, '0')}:${(end % 60).toString().padLeft(2, '0')}';
  }
}

int minutesOf(String hhmm) {
  final p = hhmm.split(':');
  if (p.length != 2) return 0;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class AgendaEvents extends ChangeNotifier {
  AgendaEvents._();
  static final instance = AgendaEvents._();

  final List<PersonalEvent> _all = [];
  bool _cloud = false;

  /// Mensagem do último erro ao salvar (mostrada pela tela).
  void Function(String message)? onError;

  List<PersonalEvent> get all => List.unmodifiable(_all);

  List<PersonalEvent> on(DateTime day) => _all.where((e) => e.occursOn(day)).toList()
    ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

  /// Compromissos do dia que batem com o horário informado.
  List<PersonalEvent> clashes(DateTime day, String time, int duration, {String? ignoreId}) {
    if (time.isEmpty) return const [];
    final s = minutesOf(time), e = s + duration;
    return on(day).where((x) => x.id != ignoreId && x.startMinute < e && s < x.endMinute).toList();
  }

  /// Atendimentos do dia que batem com o horário de um compromisso.
  List<(StudentPlan, LessonLine)> sessionClashes(PersonalEvent ev, DateTime day) {
    final store = BillingStore.instance;
    return [
      for (final (p, line) in store.sessionsOn(day))
        if (store.happens(line.outcome) && line.time.isNotEmpty)
          if (ev.allDay ||
              (minutesOf(line.time) < ev.endMinute && ev.startMinute < minutesOf(line.time) + p.durationMinutes))
            (p, line),
    ];
  }

  void clear() {
    _all.clear();
    _cloud = false;
    notifyListeners();
  }

  /// Lê os compromissos da conta conectada.
  Future<void> load() async {
    _all.clear();
    try {
      final rows = await Supabase.instance.client.from('cf_events').select().order('date');
      _cloud = true;
      for (final r in rows) {
        _all.add(PersonalEvent(
          id: r['id'] as String,
          title: r['title'] as String? ?? '',
          date: DateTime.parse(r['date'] as String),
          time: r['time'] as String? ?? '',
          duration: (r['duration_minutes'] as num?)?.toInt() ?? 60,
          weekly: r['weekly'] as bool? ?? false,
          until: r['until'] == null ? null : DateTime.parse(r['until'] as String),
        ));
      }
    } catch (e) {
      debugPrint('Okday: compromissos indisponíveis ($e)');
    }
    notifyListeners();
  }

  Future<void> save(PersonalEvent e) async {
    final i = _all.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      _all[i] = e;
    } else {
      _all.add(e);
    }
    notifyListeners();
    if (!_cloud) return;
    try {
      await Supabase.instance.client.from('cf_events').upsert({
        'id': e.id,
        'title': e.title,
        'date': _d(e.date),
        'time': e.time,
        'duration_minutes': e.duration,
        'weekly': e.weekly,
        'until': e.until == null ? null : _d(e.until!),
      });
    } catch (err) {
      onError?.call('Não foi possível salvar o compromisso. Confira a internet e tente de novo.');
    }
  }

  Future<void> delete(String id) async {
    _all.removeWhere((x) => x.id == id);
    notifyListeners();
    if (!_cloud) return;
    try {
      await Supabase.instance.client.from('cf_events').delete().eq('id', id);
    } catch (_) {
      onError?.call('Não foi possível apagar o compromisso. Confira a internet e tente de novo.');
    }
  }
}

// ---------------------------------------------------------------------------
// Telas
// ---------------------------------------------------------------------------

/// Linha cinza de compromisso, no mesmo formato dos atendimentos.
class EventRow extends StatelessWidget {
  const EventRow({super.key, required this.event, required this.day, this.compact = false});
  final PersonalEvent event;
  final DateTime day;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: CF.greyBg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => openEventForm(context, event: event),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: const Border(left: BorderSide(color: CF.muted, width: 3)),
              ),
              child: Text('${event.allDay ? '' : '${event.time} '}${event.title}',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: CF.body(13, color: CF.muted, weight: FontWeight.w600)),
            ),
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: CF.greyBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CF.line),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: const Border(left: BorderSide(color: CF.muted, width: 5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openEventForm(context, event: event),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(children: [
            SizedBox(
              width: 58,
              child: Text(event.allDay ? 'Dia' : event.time, style: CF.score(22, color: CF.muted)),
            ),
            Container(width: 1, height: 36, color: CF.line),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: CF.body(16, weight: FontWeight.w700, color: CF.text)),
                Text('${event.timeLabel}${event.weekly ? ' · toda semana' : ''}',
                    style: CF.body(14, color: CF.muted)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: CF.surface, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(event.weekly ? Icons.repeat_rounded : Icons.event_note_rounded, size: 14, color: CF.muted),
                const SizedBox(width: 4),
                Text('Compromisso', style: CF.body(12.5, color: CF.muted, weight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Cadastro e edição de compromisso.
Future<void> openEventForm(BuildContext context, {PersonalEvent? event, DateTime? day}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: _EventForm(event: event, day: day ?? BillingStore.instance.today, messenger: context),
      ),
    );

class _EventForm extends StatefulWidget {
  const _EventForm({required this.event, required this.day, required this.messenger});
  final PersonalEvent? event;
  final DateTime day;
  final BuildContext messenger;

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  late final title = TextEditingController(text: widget.event?.title ?? '');
  late DateTime date = widget.event?.date ?? widget.day;
  late String time = widget.event?.time ?? '12:00';
  late bool allDay = widget.event?.allDay ?? false;
  late int duration = widget.event?.duration ?? 60;
  late bool weekly = widget.event?.weekly ?? false;
  String? error;

  static const suggestions = ['Reunião', 'Consulta médica', 'Almoço', 'Folga', 'Curso', 'Buscar filhos'];

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  PersonalEvent _draft() => PersonalEvent(
        id: widget.event?.id ?? newUuid(),
        title: title.text.trim(),
        date: dateOnly(date),
        time: allDay ? '' : time,
        duration: duration,
        weekly: weekly,
        until: widget.event?.until,
      );

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => date = d);
  }

  Future<void> _pickTime() async {
    final m = minutesOf(time);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) {
      setState(() => time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    }
  }

  void _save() {
    if (title.text.trim().isEmpty) {
      setState(() => error = 'Dê um nome ao compromisso.');
      return;
    }
    final e = _draft();
    AgendaEvents.instance.save(e);
    Navigator.pop(context);
    ScaffoldMessenger.of(widget.messenger).showSnackBar(SnackBar(
      content: Text(widget.event == null ? 'Compromisso marcado. Tá ok!' : 'Compromisso atualizado.'),
    ));
  }

  void _delete() {
    AgendaEvents.instance.delete(widget.event!.id);
    Navigator.pop(context);
    ScaffoldMessenger.of(widget.messenger).showSnackBar(const SnackBar(content: Text('Compromisso apagado.')));
  }

  @override
  Widget build(BuildContext context) {
    final t = BillingStore.instance.terms;
    final draft = _draft();
    final clashes = AgendaEvents.instance.sessionClashes(draft, date);
    Widget chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          selectedColor: CF.ink,
          labelStyle: CF.body(15, weight: FontWeight.w600, color: selected ? Colors.white : CF.text),
          onSelected: (_) => onTap(),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.event == null ? 'Novo compromisso' : 'Editar compromisso',
                style: CF.body(22, weight: FontWeight.w700)),
            Text('Ocupa o horário na agenda. Não entra na cobrança.', style: CF.body(14, color: CF.muted)),
            const SizedBox(height: 14),
            TextField(
              controller: title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'O que é?', hintText: 'Ex.: Reunião, médico, folga'),
              onChanged: (_) => setState(() => error = null),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in suggestions)
                ActionChip(label: Text(s), onPressed: () => setState(() => title.text = s)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text('${capitalize(weekdayLong[date.weekday - 1])}, ${ddmm(date)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: allDay ? null : _pickTime,
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(allDay ? 'Dia todo' : time),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: allDay,
              onChanged: (v) => setState(() => allDay = v),
              title: Text('Dia todo', style: CF.body(16, weight: FontWeight.w600)),
            ),
            if (!allDay) ...[
              Text('Duração', style: CF.body(16, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in const [30, 60, 90, 120, 180, 240]) chip(durationText(m), duration == m, () => setState(() => duration = m)),
              ]),
              const SizedBox(height: 6),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: weekly,
              onChanged: (v) => setState(() => weekly = v),
              title: Text('Repetir toda semana', style: CF.body(16, weight: FontWeight.w600)),
              subtitle: Text('Toda ${weekdayLong[date.weekday - 1].toLowerCase()}', style: CF.body(14, color: CF.muted)),
            ),
            if (clashes.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: CF.amberBg, borderRadius: BorderRadius.circular(12)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.warning_amber_rounded, color: CF.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Conflito com ${clashes.length == 1 ? '${t.g('a', 'o')} ${t.session}' : '${clashes.length} ${t.sessions}'}: '
                      '${clashes.map((e) => '${e.$2.time} ${e.$1.name.split(' ').first}').join(', ')}. '
                      'Dá para salvar mesmo assim.',
                      style: CF.body(14, color: CF.text),
                    ),
                  ),
                ]),
              ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: CF.body(15, color: CF.red, weight: FontWeight.w600)),
            ],
            const SizedBox(height: 18),
            FilledButton(onPressed: _save, child: Text(widget.event == null ? 'Marcar compromisso' : 'Salvar')),
            if (widget.event != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _delete,
                style: TextButton.styleFrom(foregroundColor: CF.red),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(widget.event!.weekly ? 'Apagar (todas as semanas)' : 'Apagar'),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
