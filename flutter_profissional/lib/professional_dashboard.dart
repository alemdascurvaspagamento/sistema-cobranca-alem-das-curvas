import 'package:flutter/material.dart';
import 'demo_mode.dart';
import 'demo_ledger.dart';

/// Painel visual demonstrativo. Não confundir agenda prevista com receita recebida.
class ProfessionalDashboard extends StatelessWidget {
  const ProfessionalDashboard({super.key, required this.demo,
    required this.onClients, required this.onAgenda, required this.onBilling,
    required this.onFinance});
  final bool demo;
  final VoidCallback onClients, onAgenda, onBilling, onFinance;

  static const ink = Color(0xFFF5F2EA);
  static const muted = Color(0xFFADB0B8);
  static const border = Color(0xFF383A40);
  static const background = Color(0xFF111317);
  static const green = Color(0xFFD6B46B);
  static const amber = Color(0xFFE0BA62);
  static const red = Color(0xFFBD8E62);

  Widget panel(Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: const Color(0xFF1E2127),
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(17)),
    child: child);

  Widget stat(String label, String value, String detail, IconData icon, Color accent) =>
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 19, color: accent)),
          const Spacer(),
        ]),
        Text(label.toUpperCase(), style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700, color: muted)),
        Text(value, style: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
        Text(detail, maxLines: 2, style: const TextStyle(fontSize: 11, color: muted)),
      ]));

  Widget action(String label, IconData icon, VoidCallback onTap) =>
    OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 18),
      label: Text(label), style: OutlinedButton.styleFrom(
        foregroundColor: ink, side: const BorderSide(color: border),
        backgroundColor: const Color(0xFF1E2127),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14)));

  @override Widget build(BuildContext context) {
    final today = DateTime.now();
    const months = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho',
      'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
    final appointments = demo ? DemoData.appointments : <DemoAppointment>[];
    final planned = appointments.fold<double>(0, (sum, a) => sum + a.amount);
    return AnimatedBuilder(animation:DemoLedger.instance,
      builder:(context,_)=>_buildDashboard(context,today,months,appointments,planned));
  }
  Widget _buildDashboard(BuildContext context, DateTime today,
    List<String> months, List<DemoAppointment> appointments, double planned) {
    final ledger=DemoLedger.instance;
    return Theme(data: ThemeData(useMaterial3: true, brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: green, brightness: Brightness.dark),
      scaffoldBackgroundColor: background), child: Container(
      decoration: BoxDecoration(color: background,
        borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(18),
      child: DefaultTextStyle.merge(style: const TextStyle(color: ink),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Visão geral', style: TextStyle(
                fontSize: 25, fontWeight: FontWeight.w800, color: ink)),
              Text('${months[today.month-1]} / ${today.year} • Seu negócio em uma única leitura',
                style: const TextStyle(fontSize: 12, color: muted)),
            ]),
            FilledButton.icon(onPressed: onClients, icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Novo cliente'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD6B46B),
                foregroundColor: const Color(0xFF111317))),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            action('Agenda', Icons.calendar_month_outlined, onAgenda),
            action('Cobranças', Icons.receipt_long_outlined, onBilling),
            action('Financeiro', Icons.account_balance_wallet_outlined, onFinance),
            action('Clientes', Icons.groups_outlined, onClients),
          ]),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, size) {
            final columns = size.maxWidth >= 1020 ? 5 : size.maxWidth >= 600 ? 3 : 2;
            final cardWidth = (size.maxWidth - (columns - 1) * 10) / columns;
            final metrics = <Widget>[
              stat('Receita prevista',demo?DemoData.currency(ledger.projected):'—','Total de cobranças demonstrativas',
                Icons.insights_outlined, green),
              stat('Recebido no mês',demo?DemoData.currency(ledger.received):'—','Pagamentos marcados como recebidos',
                Icons.check_circle_outline, green),
              stat('A receber',demo?DemoData.currency(ledger.pending):'—','Cobranças pendentes',Icons.schedule, amber),
              stat('Despesas do mês',demo?DemoData.currency(ledger.paidExpenses):'—','Despesa fictícia paga, para demonstração',
                Icons.trending_down, red),
              stat('Resultado de caixa',demo?DemoData.currency(ledger.cash):'—','Recebido menos despesas pagas',
                Icons.account_balance_outlined, green),
            ];
            return Wrap(spacing: 10, runSpacing: 10, children: [
              for (final metric in metrics)
                SizedBox(width: cardWidth, height: 158, child: metric),
            ]);
          }),
          const SizedBox(height: 14),
          panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Panorama financeiro',style:TextStyle(
              fontSize:17,fontWeight:FontWeight.w800,color:ink)),
            const SizedBox(height:5),
            const Text('Recebido e pendente • dados fictícios da Central de Cobranças',
              style:TextStyle(fontSize:12,color:muted)),
            const SizedBox(height:14),
            if(demo && ledger.projected>0) ...[
              ClipRRect(borderRadius:BorderRadius.circular(9),
                child:Row(children:[
                  Expanded(flex:(ledger.received/ledger.projected*1000).round().clamp(0,1000),
                    child:Container(height:16,color:green)),
                  Expanded(flex:(ledger.pending/ledger.projected*1000).round().clamp(0,1000),
                    child:Container(height:16,color:amber)),
                ])),
              const SizedBox(height:12),
              Text('Recebido ${(ledger.received/ledger.projected*100).toStringAsFixed(1)}%   •   Pendente ${(ledger.pending/ledger.projected*100).toStringAsFixed(1)}%',
                style:const TextStyle(color:muted,fontSize:12)),
            ] else const Text('Sem dados financeiros para o gráfico.',
              style:TextStyle(color:muted)),
          ])),
          const SizedBox(height: 14),
          panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.auto_graph_rounded, color: green, size: 22),
              SizedBox(width: 8),
              Expanded(child: Text('Ritmo dos atendimentos',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink))),
            ]),
            const SizedBox(height: 4),
            const Text('Distribuição por horário da agenda demonstrativa — não é faturamento',
              style: TextStyle(fontSize: 12, color: muted)),
            const SizedBox(height: 18),
            SizedBox(height: 124, child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final slot in <(String, int, int)>[
                  ('06–09', 6, 9), ('09–12', 9, 12),
                  ('12–15', 12, 15), ('15–18', 15, 18),
                  ('18–21', 18, 21),
                ])
                  Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('${appointments.where((a) {
                        final hour = int.tryParse(a.hour.split(':').first) ?? -1;
                        return hour >= slot.$2 && hour < slot.$3;
                      }).length}', style: const TextStyle(
                        fontSize: 12, color: ink, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      Container(
                        height: 12 + 16.0 * appointments.where((a) {
                          final hour = int.tryParse(a.hour.split(':').first) ?? -1;
                          return hour >= slot.$2 && hour < slot.$3;
                        }).length,
                        decoration: BoxDecoration(
                          color: green.withValues(alpha: demo ? .85 : .18),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(7)))),
                      const SizedBox(height: 7),
                      FittedBox(child: Text(slot.$1, style: const TextStyle(
                        fontSize: 11, color: muted))),
                    ]),
                  )),
              ],
            )),
            const SizedBox(height: 10),
            Text(demo
              ? '${appointments.length} atendimentos previstos no exemplo. Acompanhe seu ritmo ao longo do dia.'
              : 'O gráfico será preenchido após a integração com a agenda.',
              style: const TextStyle(fontSize: 12, color: muted)),
          ])),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, size) {
            final wide = size.maxWidth >= 780;
            final target = panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Meta de receita', style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
                const SizedBox(height: 4),
                const Text('Acompanhamento mensal e anual',
                  style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 22),
                Text(demo ? '${DemoData.currency(ledger.received)} de ${DemoData.currency(ledger.annualGoal)}' : 'Aguardando dados financeiros',
                  style: const TextStyle(color: muted)),
                const SizedBox(height: 12),
                ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value:demo && ledger.annualGoal>0 ? (ledger.received/ledger.annualGoal).clamp(0.0,1.0):0, minHeight: 9,
                    color: green, backgroundColor: background)),
                const SizedBox(height: 15),
                Text(demo && ledger.annualGoal>0 ? '${(ledger.received/ledger.annualGoal*100).toStringAsFixed(1)}% da meta anual • referência mensal ${DemoData.currency(ledger.annualGoal/12)}' : 'Nenhum progresso calculado sem receitas e meta válidas.',
                  style: const TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft,
                  child: TextButton.icon(onPressed: onFinance,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Abrir financeiro'))),
              ]));
            final agenda = panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Agenda de hoje', style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
                const SizedBox(height: 4),
                const Text('Atendimentos previstos — não representam receita recebida',
                  style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 13),
                if (appointments.isEmpty)
                  const Text('Nenhum atendimento disponível.',
                    style: TextStyle(color: muted)),
                for (final a in appointments)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Container(width: 52, alignment: Alignment.centerLeft,
                        child: Text(a.hour, style: const TextStyle(
                          fontWeight: FontWeight.bold, color: green))),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.client, style: const TextStyle(
                            fontWeight: FontWeight.w600, color: ink)),
                          Text(a.service, style: const TextStyle(
                            fontSize: 11, color: muted)),
                        ])),
                      Text(DemoData.currency(a.amount),
                        style: const TextStyle(fontSize: 12, color: ink)),
                    ])),
                if (demo) Padding(padding: const EdgeInsets.only(top: 10),
                  child: Text('Total previsto nesta agenda fictícia: ${DemoData.currency(planned)}',
                    style: const TextStyle(fontSize: 12, color: muted))),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft,
                  child: TextButton.icon(onPressed: onAgenda,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Abrir calendário'))),
              ]));
            if (!wide) return Column(children: [
              target, const SizedBox(height: 12), agenda,
            ]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: target), const SizedBox(width: 12),
              Expanded(child: agenda),
            ]);
          }),
          const SizedBox(height: 12),
          const Text('PAINEL DEMONSTRATIVO • Dados fictícios da agenda. '
            'Indicadores financeiros indisponíveis até integração e validação.',
            style: TextStyle(fontSize: 11, color: muted)),
        ]))));
  }
}
