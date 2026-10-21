import 'package:flutter/material.dart';

/// Dados exclusivamente fictícios, armazenados no código e nunca enviados à rede.
class DemoAppointment {
  const DemoAppointment(this.client, this.service, this.hour, this.amount);
  final String client, service, hour;
  final double amount;
}

class DemoData {
  static const appointments = <DemoAppointment>[
    DemoAppointment('Mariana Costa', 'Consultoria individual', '08:00', 180),
    DemoAppointment('Ricardo Almeida', 'Avaliação inicial', '10:30', 220),
    DemoAppointment('Fernanda Lima', 'Acompanhamento', '14:00', 150),
    DemoAppointment('Paulo Martins', 'Sessão de retorno', '16:30', 180),
  ];
  static const clients = <(String, String, String)>[
    ('Mariana Costa', 'Plano mensal', 'Em dia'),
    ('Ricardo Almeida', 'Avaliação', 'Pagamento pendente'),
    ('Fernanda Lima', 'Acompanhamento', 'Em dia'),
    ('Paulo Martins', 'Retorno', 'Em dia'),
  ];
  static String currency(num value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}

class DemoAgenda extends StatefulWidget {
  const DemoAgenda({super.key});
  @override
  State<DemoAgenda> createState() => _DemoAgendaState();
}

class _DemoAgendaState extends State<DemoAgenda> {
  static const gold = Color(0xFFD8B56A);
  static const surface = Color(0xFF1A1D22);
  int tab = 0;
  String statusFilter = 'Todos';
  DateTime? selectedWeek;

  final Map<String, String> appointmentStates = {};

  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? selectedDay;

  final Map<String, bool> chargeOverrides = {};
  final Map<String, String> appointmentNotes = {};
  String appointmentKey(DateTime date, String client) =>
      '${date.year}-${date.month}-${date.day}-$client';
  String appointmentState(DateTime date, String client) =>
      appointmentStates[appointmentKey(date, client)] ?? 'Agendada';
  Color appointmentColor(String state) {
    switch (state) {
      case 'Realizada': return const Color(0xFF42BA83);
      case 'Cancelada': return const Color(0xFFE96767);
      case 'Remarcada': return const Color(0xFFF4A15A);
      case 'Crédito': return const Color(0xFFA47DE1);
      default: return const Color(0xFF4B91F1);
    }
  }
  Future<void> editAppointment(DateTime date, DemoAppointment appointment) async {
    final key = appointmentKey(date, appointment.client);
    String state = appointmentState(date, appointment.client);
    bool charge = chargeOverrides[key] ?? state != 'Cancelada';
    final note = TextEditingController(text: appointmentNotes[key] ?? '');
    final confirmed = await showDialog<bool>(context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, refresh) =>
        AlertDialog(
          title: Text('${appointment.client} • ${appointment.hour}'),
          content: SizedBox(width: 400, child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${appointment.service} • ${DemoData.currency(appointment.amount)}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: state,
                decoration: const InputDecoration(labelText: 'Situação'),
                items: ['Agendada', 'Realizada', 'Cancelada', 'Remarcada', 'Crédito']
                  .map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                onChanged: (value) {
                  if (value != null) refresh(() {
                    state = value;
                    if (value == 'Cancelada' || value == 'Crédito') charge = false;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Cobrar atendimento'),
                subtitle: const Text('Conforme a política contratual'),
                value: charge,
                onChanged: (value) => refresh(() => charge = value),
              ),
              TextField(controller: note, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Motivo ou observações')),
            ]),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar')),
          ],
        )));
    if (confirmed == true && mounted) setState(() {
      appointmentStates[key] = state;
      chargeOverrides[key] = charge;
      appointmentNotes[key] = note.text.trim();
    });
    note.dispose();
  }

  String monthName(DateTime date) {
    const names = ['janeiro','fevereiro','março','abril','maio','junho',
      'julho','agosto','setembro','outubro','novembro','dezembro'];
    return '${names[date.month - 1]} de ${date.year}';
  }

  Widget appointmentList(DateTime day) {
    final today = DateUtils.dateOnly(DateTime.now());
    if (!DateUtils.isSameDay(day, today) && day.month != today.month) {
      return const Padding(padding: EdgeInsets.all(12),
        child: Text('Nenhum atendimento fictício neste período.'));
    }
    final appointments = DemoData.appointments.where((appointment) =>
      statusFilter == 'Todos' ||
      appointmentState(day, appointment.client) == statusFilter).toList();
    if (appointments.isEmpty) {
      return const Padding(padding: EdgeInsets.all(12),
        child: Text('Nenhum atendimento neste filtro.'));
    }
    return Column(children: [
      for (final appointment in appointments)
        Card(color: const Color(0xFF24282F), child: ListTile(
          onTap: () => editAppointment(day, appointment),
          leading: Icon(Icons.circle,
            color: appointmentColor(appointmentState(day, appointment.client))),
          title: Text(appointment.client),
          subtitle: Text('${appointment.service} • ${appointmentState(day, appointment.client)}'),
          trailing: Text(appointment.hour,
            style: const TextStyle(color: gold)),
        )),
    ]);
  }

  Future<void> chooseMonth() async {
    final result = await showDatePicker(
      context: context,
      initialDate: selectedDay ?? month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      locale: const Locale('pt', 'BR'),
    );
    if (result != null) setState(() {
      month = DateTime(result.year, result.month);
      selectedDay = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 0, icon: Icon(Icons.today), label: Text('Hoje')),
          ButtonSegment(value: 1, icon: Icon(Icons.calendar_month), label: Text('Mês')),
        ],
        selected: {tab},
        onSelectionChanged: (value) => setState(() => tab = value.first),
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.black : Colors.white),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? gold : surface),
        ),
      ),
      const SizedBox(height: 18),
      if (tab == 0) ...[
        Text('Atendimentos de hoje', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        appointmentList(today),
      ] else ...[
        Card(color: surface, child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              IconButton(onPressed: () => setState(() {
                month = DateTime(month.year, month.month - 1);
                selectedDay = null;
              }), icon: const Icon(Icons.chevron_left)),
              Expanded(child: TextButton(
                onPressed: chooseMonth,
                child: Text(monthName(month), style: const TextStyle(color: gold, fontSize: 17)),
              )),
              IconButton(onPressed: () => setState(() {
                month = DateTime(month.year, month.month + 1);
                selectedDay = null;
              }), icon: const Icon(Icons.chevron_right)),
            ]),
            Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(children: [
            Row(children: [
              for (final label in const ['S','T','Q','Q','S','S','D'])
                Expanded(child: Center(child: Text(label,
                  style: const TextStyle(color: Color(0xFFCBD0D8))))),
            ]),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, size) {
              final offset = DateTime(month.year, month.month).weekday - 1;
              final days = DateTime(month.year, month.month + 1, 0).day;
              final count = ((offset + days + 6) ~/ 7) * 7;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: count,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7, mainAxisSpacing: 5, crossAxisSpacing: 5,
                  mainAxisExtent: 42),
                itemBuilder: (context, index) {
                  final number = index - offset + 1;
                  if (number < 1 || number > days) return const SizedBox.shrink();
                  final date = DateTime(month.year, month.month, number);
                  final chosen = DateUtils.isSameDay(selectedDay, date);
                  final current = DateUtils.isSameDay(today, date);
                  return InkWell(
                    onTap: () => setState(() => selectedDay = date),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: chosen ? gold : Colors.transparent,
                        border: current ? Border.all(color: gold) : null,
                        borderRadius: BorderRadius.circular(9)),
                      child: Text('$number', style: TextStyle(
                        color: chosen ? Colors.black : Colors.white,
                        fontWeight: current || chosen ? FontWeight.bold : FontWeight.normal)),
                    ),
                  );
                },
              );
            }),
              ]),
            )),
            const SizedBox(height: 12),
            if (selectedDay != null) appointmentList(selectedDay!)
            else const Text('Selecione um dia para ver os atendimentos.',
              style: TextStyle(color: Color(0xFFCBD0D8))),
          ]),
        )),
      ],
    ]);
  }
}
