import 'package:flutter/material.dart';

/// Preparação visual da integração. Nenhuma conta é conectada nesta versão.
class CalendarConnections extends StatefulWidget {
  const CalendarConnections({super.key});
  @override
  State<CalendarConnections> createState() => _CalendarConnectionsState();
}

class _CalendarConnectionsState extends State<CalendarConnections> {
  bool hidePrivateDetails = true;
  bool blockConflicts = true;
  bool exportClientNames = false;
  static const navy = Color(0xFF0C213A);
  static const blue = Color(0xFF245A98);
  static const muted = Color(0xFF64748B);

  Widget provider(String name, String description, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, color: blue, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
            Text(description, style: const TextStyle(fontSize: 12, color: muted)),
          ])),
          const Chip(label: Text('Não conectado')),
        ]),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.link),
          label: const Text('Conectar em breve'),
        ),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Calendários conectados',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: navy)),
      const SizedBox(height: 6),
      const Text('Prepare sua agenda para sincronizar compromissos sem expor informações pessoais.',
        style: TextStyle(color: muted)),
      const SizedBox(height: 14),
      provider('Google Agenda', 'Google Calendar • Web, Android e iOS', Icons.calendar_month_outlined),
      provider('Calendário Apple', 'EventKit • aplicativo nativo para iPhone e iPad', Icons.event_outlined),
      const SizedBox(height: 14),
      const Text('Privacidade e conflitos',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: navy)),
      const SizedBox(height: 8),
      Card(child: Column(children: [
        SwitchListTile(
          activeThumbColor: navy,
          title: const Text('Ocultar detalhes pessoais'),
          subtitle: const Text('Eventos importados serão exibidos apenas como “Ocupado”.'),
          value: hidePrivateDetails,
          onChanged: (v) => setState(() => hidePrivateDetails = v),
        ),
        const Divider(height: 1),
        SwitchListTile(
          activeThumbColor: navy,
          title: const Text('Evitar conflitos de horários'),
          subtitle: const Text('Identificar sobreposições antes de confirmar um atendimento.'),
          value: blockConflicts,
          onChanged: (v) => setState(() => blockConflicts = v),
        ),
        const Divider(height: 1),
        SwitchListTile(
          activeThumbColor: navy,
          title: const Text('Incluir nome do cliente em eventos externos'),
          subtitle: const Text('Desativado por padrão para preservar a confidencialidade.'),
          value: exportClientNames,
          onChanged: (v) => setState(() => exportClientNames = v),
        ),
      ])),
      const SizedBox(height: 10),
      const Text('Prévia de configuração: as preferências são locais a esta tela, não são salvas e ainda não alteram agendas externas. A conexão real exigirá autorização e um serviço seguro de sincronização.',
        style: TextStyle(fontSize: 12, color: muted)),
    ],
  );
}
