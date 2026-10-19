import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'agenda_repository.dart';

/// Agenda responsiva com duas abas: Hoje e Mês.
/// Exibe estado vazio até a integração com os atendimentos reais.
class ProfessionalAgenda extends StatefulWidget {
  const ProfessionalAgenda({super.key});

  @override
  State<ProfessionalAgenda> createState() => _ProfessionalAgendaState();
}

class _ProfessionalAgendaState extends State<ProfessionalAgenda> {
  static const gold = Color(0xFFD8B56A);
  static const silver = Color(0xFFCBD0D8);
  static const surface = Color(0xFF1A1D22);
  static const border = Color(0xFF44474F);
  int view = 0;
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? selectedDay;

  late final AgendaRepository repository = AgendaRepository(Supabase.instance.client);
  Future<List<AgendaAppointment>>? appointments;
  @override
  void initState() { super.initState(); _load(); }
  void _load() {
    final now = DateTime.now();
    final start = view == 0 ? DateTime(now.year,now.month,now.day) : DateTime(month.year,month.month);
    final end = view == 0 ? DateTime(now.year,now.month,now.day + 1) : DateTime(month.year,month.month + 1);
    appointments = repository.forPeriod(start,end);
  }
  Widget _appointmentList(DateTime date) => FutureBuilder<List<AgendaAppointment>>(
    future: appointments,
    builder: (context,snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Column(children: [
          const Text('Não foi possível carregar a agenda.', style: TextStyle(color: Colors.redAccent)),
          TextButton(onPressed: () => setState(_load), child: const Text('Tentar novamente')),
        ]);
      }
      final items = (snapshot.data ?? []).where((a) => DateUtils.isSameDay(a.startsAt,date)).toList();
      if (items.isEmpty) return const _EmptyAgenda(label: 'Nenhum atendimento cadastrado para esta data.');
      return Column(children: [
        for (final a in items) ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event, color: gold),
          title: Text(a.clientName, style: const TextStyle(color: Colors.white)),
          subtitle: Text(a.status, style: const TextStyle(color: silver)),
          trailing: Text(TimeOfDay.fromDateTime(a.startsAt).format(context), style: const TextStyle(color: gold)),
        ),
      ]);
    },
  );


  String _monthName(DateTime date) {
    const months = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
    ];
    return '${months[date.month - 1]} de ${date.year}';
  }

  void _changeMonth(int offset) => setState(() {
        month = DateTime(month.year, month.month + offset);
        selectedDay = null;
        _load();
      });

  Future<void> _pickMonth() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: selectedDay ?? month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      locale: const Locale('pt', 'BR'),
      helpText: 'ESCOLHA O MÊS',
    );
    if (chosen != null) {
      setState(() {
        month = DateTime(chosen.year, chosen.month);
        selectedDay = chosen;
        _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, icon: Icon(Icons.today_outlined), label: Text('Hoje')),
            ButtonSegment(value: 1, icon: Icon(Icons.calendar_month_outlined), label: Text('Mês')),
          ],
          selected: {view},
          onSelectionChanged: (selection) => setState(() { view = selection.first; _load(); }),
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? const Color(0xFF101216) : silver,
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? gold : surface,
            ),
            side: const WidgetStatePropertyAll(BorderSide(color: border)),
          ),
        ),
        const SizedBox(height: 20),
        if (view == 0) ...[
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AGENDA DE HOJE',
                    style: TextStyle(color: gold, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
                const SizedBox(height: 10),
                Text(MaterialLocalizations.of(context).formatMediumDate(today),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 18),
                _appointmentList(today),
              ],
            ),
          ),
        ] else ...[
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Mês anterior',
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: _pickMonth,
                        child: Text(
                          _monthName(month),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: gold, fontSize: 17, fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Próximo mês',
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _calendar(today),
                const SizedBox(height: 20),
                Text(
                  selectedDay == null
                      ? 'Selecione um dia para consultar os atendimentos.'
                      : 'Atendimentos de ${MaterialLocalizations.of(context).formatMediumDate(selectedDay!)}',
                  style: const TextStyle(color: silver),
                ),
                if (selectedDay != null) ...[
                  const SizedBox(height: 14),
                  _appointmentList(selectedDay!),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _calendar(DateTime today) {
    final start = DateTime(month.year, month.month, 1);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final offset = (start.weekday + 6) % 7;
    final cells = ((offset + count + 6) ~/ 7) * 7;
    return Column(
      children: [
        const Row(
          children: [
            for (final day in ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'])
              Expanded(
                child: Center(child: Text(day, style: TextStyle(color: silver))),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            final day = index - offset + 1;
            if (day < 1 || day > count) return const SizedBox.shrink();
            final date = DateTime(month.year, month.month, day);
            final chosen = selectedDay != null && DateUtils.isSameDay(date, selectedDay);
            final isToday = DateUtils.isSameDay(date, today);
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => selectedDay = date),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: chosen ? gold : Colors.transparent,
                  border: isToday ? Border.all(color: gold) : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$day', style: TextStyle(
                  color: chosen ? const Color(0xFF101216) : Colors.white,
                  fontWeight: chosen || isToday ? FontWeight.bold : FontWeight.normal,
                )),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );
}

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(
          children: [
            const Icon(Icons.event_available_outlined, color: Color(0xFFD8B56A), size: 38),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFCBD0D8))),
          ],
        ),
      );
}
