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
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? selectedDay;

  String monthName(DateTime date) {
    const names = ['janeiro','fevereiro','março','abril','maio','junho',
      'julho','agosto','setembro','outubro','novembro','dezembro'];
    return '${names[date.month - 1]} de ${date.year}';
  }

  Widget appointmentList(DateTime day) {
    final today = DateUtils.dateOnly(DateTime.now());
    if (!DateUtils.isSameDay(day, today)) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Nenhum atendimento fictício para este dia.',
          style: TextStyle(color: Color(0xFFCBD0D8))),
      );
    }
    return Column(children: [
      for (final a in DemoData.appointments)
        Card(
          color: const Color(0xFF24282F),
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: gold.withValues(alpha: .15),
              child: const Icon(Icons.event_available, color: gold),
            ),
            title: Text(a.client, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(a.service),
            trailing: Text(a.hour, style: const TextStyle(color: gold, fontWeight: FontWeight.bold)),
          ),
        ),
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
                  crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
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
