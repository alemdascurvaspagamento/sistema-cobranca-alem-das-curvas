import 'package:flutter/material.dart';
import 'demo_mode.dart';
import 'demo_ledger.dart';

/// Painel visual demonstrativo. Não confundir agenda prevista com receita recebida.
class ProfessionalDashboard extends StatefulWidget {
  const ProfessionalDashboard({super.key, required this.demo,
    required this.onClients, required this.onAgenda, required this.onBilling,
    required this.onFinance,required this.onSecretary});
  final bool demo;
  final VoidCallback onClients, onAgenda, onBilling, onFinance, onSecretary;

  @override State<ProfessionalDashboard> createState()=>_ProfessionalDashboardState();
}

class _ProfessionalDashboardState extends State<ProfessionalDashboard> {
  late int selectedMonth=DateTime.now().month;
  late int selectedYear=DateTime.now().year;
  static const ink = Color(0xFF17243A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const background = Color(0xFFEDF2F8);
  static const green = Color(0xFF20835D);
  static const amber = Color(0xFFB98522);
  static const red = Color(0xFFC34B50);

  Future<void> _notDone(BuildContext context,DemoAppointment a,DateTime day) async {
    final reason=await showModalBottomSheet<String>(context:context,
      builder:(ctx)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const ListTile(title:Text('Atendimento não realizado'),
          subtitle:Text('Selecione o motivo e a regra de cobrança')),
        for(final choice in const [
          ('Cliente cancelou • sem cobrança','cliente-sem'),
          ('Cliente cancelou • com cobrança','cliente-com'),
          ('Profissional cancelou • sem cobrança','profissional'),
          ('Falta do cliente • com cobrança','falta'),
          ('Remarcar atendimento','remarcar'),
        ])ListTile(title:Text(choice.$1),
          onTap:()=>Navigator.pop(ctx,choice.$2)),
      ])));
    if(reason==null)return;
    final charge=reason=='cliente-com'||reason=='falta';
    DemoLedger.instance.updateVisit(a.client,day,
      reason=='remarcar'?'Remarcada':'Cancelada',charge,reason);
    if(reason=='remarcar')widget.onAgenda();
  }
  Widget panel(Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Color(0xFFFFFFFF),
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
        FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,
          child:Text(value, maxLines:1, style: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: ink))),
        Text(detail, maxLines: 2, overflow:TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: muted)),
      ]));

  Widget action(String label, String subtitle, IconData icon, VoidCallback onTap) =>
    Material(color: Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(14),
      child: InkWell(onTap:onTap, borderRadius:BorderRadius.circular(14),
        child:Container(
          padding:const EdgeInsets.symmetric(horizontal:12,vertical:13),
          decoration:BoxDecoration(border:Border.all(color:border),
            borderRadius:BorderRadius.circular(14)),
          child:Row(children:[
            Container(width:38,height:38,alignment:Alignment.center,
              decoration:BoxDecoration(color:amber.withValues(alpha:.12),
                borderRadius:BorderRadius.circular(10)),
              child:Icon(icon,color:amber,size:21)),
            const SizedBox(width:9),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
              mainAxisSize:MainAxisSize.min,children:[
                Text(label,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:ink)),
                Text(subtitle,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontSize:10,color:muted)),
              ])),
            const Icon(Icons.chevron_right,color:amber,size:15),
          ]),
        ),
      ),
    );

  @override Widget build(BuildContext context) {
    final today = DateTime.now();
    const months = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho',
      'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
    final appointments = widget.demo ? DemoData.appointments : <DemoAppointment>[];
    final planned = appointments.fold<double>(0, (sum, a) => sum + a.amount);
    return AnimatedBuilder(animation:DemoLedger.instance,
      builder:(context,_)=>_buildDashboard(context,today,months,appointments,planned));
  }
  Widget _buildDashboard(BuildContext context, DateTime today,
    List<String> months, List<DemoAppointment> appointments, double planned) {
    final ledger=DemoLedger.instance;
    return Theme(data: ThemeData(useMaterial3: true, brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF245A98), brightness: Brightness.light),
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
              Text('${months[selectedMonth-1]} / $selectedYear • Seu negócio em uma única leitura',
                style: const TextStyle(fontSize: 12, color: muted)),
            ]),
          ]),
          const SizedBox(height: 14),
          Container(
            padding:const EdgeInsets.all(18),
            decoration:BoxDecoration(
              gradient:const LinearGradient(
                colors:[Color(0xFF0C213A),Color(0xFF173B64)],
                begin:Alignment.topLeft,end:Alignment.bottomRight),
              borderRadius:BorderRadius.circular(18)),
            child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Row(children:[
                const CircleAvatar(backgroundColor:Color(0xFF345B88),
                  child:Icon(Icons.support_agent,color:Colors.white)),
                const SizedBox(width:10),
                const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text('Sua secretária',style:TextStyle(fontSize:19,
                      fontWeight:FontWeight.w800,color:Colors.white)),
                    Text('Resumo e prioridades do dia',
                      style:TextStyle(fontSize:12,color:Color(0xFFD2E3F7))),
                  ])),
                TextButton(onPressed:widget.onSecretary,
                  style:TextButton.styleFrom(foregroundColor:Colors.white),
                  child:const Text('Ver tudo')),
              ]),
              const SizedBox(height:14),
              if(widget.demo) ...[
                Text('${appointments.length} atendimentos previstos hoje',
                  style:const TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w700)),
                const SizedBox(height:6),
                Text('${ledger.amounts.keys.where((n)=>ledger.overdue(n)).length} cobranças vencidas • ${DemoData.currency(ledger.pending)} a receber',
                  style:const TextStyle(color:Color(0xFFD2E3F7),fontSize:12)),
              ] else const Text('Conecte seus dados para receber recomendações.',
                style:TextStyle(color:Color(0xFFD2E3F7),fontSize:12)),
              const SizedBox(height:14),
              FilledButton.icon(onPressed:widget.onSecretary,
                style:FilledButton.styleFrom(backgroundColor:Colors.white,
                  foregroundColor:const Color(0xFF17375D),
                  padding:const EdgeInsets.symmetric(vertical:13,horizontal:12)),
                icon:const Icon(Icons.auto_awesome_outlined),
                label:const Text('Ver prioridades e próximas ações',
                  style:TextStyle(fontWeight:FontWeight.w700))),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children:[
            Expanded(child:DropdownButtonFormField<int>(
              value:selectedMonth,decoration:const InputDecoration(labelText:'Mês',
                border:OutlineInputBorder(),isDense:true),
              items:[for(var i=1;i<=12;i++)DropdownMenuItem(value:i,child:Text(months[i-1]))],
              onChanged:(value){if(value!=null)setState(()=>selectedMonth=value);})),
            const SizedBox(width:10),
            SizedBox(width:115,child:DropdownButtonFormField<int>(
              value:selectedYear,decoration:const InputDecoration(labelText:'Ano',
                border:OutlineInputBorder(),isDense:true),
              items:[for(var i=DateTime.now().year-3;i<=DateTime.now().year+3;i++)
                DropdownMenuItem(value:i,child:Text('$i'))],
              onChanged:(value){if(value!=null)setState(()=>selectedYear=value);})),
          ]),
          if(selectedMonth!=today.month||selectedYear!=today.year)
            const Padding(padding:EdgeInsets.only(top:8),
              child:Text('Indicadores demonstrativos exibem o mês atual; histórico mensal ainda não integrado.',
                style:TextStyle(color:amber,fontSize:11))),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, size) {
            final columns = size.maxWidth >= 1020 ? 5 : size.maxWidth >= 600 ? 3 : 2;
            final cardWidth = (size.maxWidth - (columns - 1) * 10) / columns;
            final metrics = <Widget>[
              stat('Receita prevista',widget.demo?DemoData.currency(ledger.projected):'—','Total de cobranças demonstrativas',
                Icons.insights_outlined, amber),
              stat('Recebido no mês',widget.demo?DemoData.currency(ledger.received):'—','Pagamentos marcados como recebidos',
                Icons.check_circle_outline, green),
              stat('A receber',widget.demo?DemoData.currency(ledger.pending):'—','Cobranças pendentes',Icons.schedule, amber),
              stat('Despesas do mês',widget.demo?DemoData.currency(ledger.paidExpenses):'—','Despesa fictícia paga, para demonstração',
                Icons.trending_down, red),
              stat('Resultado de caixa',widget.demo?DemoData.currency(ledger.cash):'—','Recebido menos despesas pagas',
                Icons.account_balance_outlined, ledger.cash < 0 ? red : green),
            ];
            return Wrap(spacing: 10, runSpacing: 10, children: [
              for (final metric in metrics)
                SizedBox(width: cardWidth, height: 176, child: metric),
            ]);
          }),
          const SizedBox(height:14),
          panel(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Row(children:[
              const Expanded(child:Text('Agenda de hoje',style:TextStyle(
                color:ink,fontSize:18,fontWeight:FontWeight.w800))),
              TextButton(onPressed:widget.onAgenda,child:const Text('Ver agenda')),
            ]),
            Text('${today.day}/${today.month}/${today.year} • ${appointments.length} atendimentos fictícios',
              style:const TextStyle(color:muted,fontSize:12)),
            for(final a in appointments)...[
              const Divider(color:border),
              Row(children:[
                SizedBox(width:55,child:Text(a.hour,style:const TextStyle(color:amber))),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(a.client,style:const TextStyle(color:ink,fontWeight:FontWeight.w700)),
                  Text(a.service,style:const TextStyle(color:muted,fontSize:11)),
                ])),
                Text(ledger.visit(a.client,today)?.state??'Agendada',
                  style:const TextStyle(color:amber,fontSize:11)),
              ]),
              Wrap(spacing:8,children:[
                TextButton.icon(onPressed:()=>ledger.updateVisit(a.client,today,
                  'Realizada',true,'Confirmado na tela inicial'),
                  icon:const Icon(Icons.check,color:green),label:const Text('Realizada')),
                TextButton.icon(onPressed:()=>_notDone(context,a,today),
                  icon:const Icon(Icons.close,color:red),label:const Text('Não realizada')),
              ]),
            ],
            const SizedBox(height:8),
            Align(alignment:Alignment.centerLeft,child:OutlinedButton.icon(
              onPressed:widget.onClients,
              icon:const Icon(Icons.person_add_alt_1_outlined,size:18),
              label:const Text('Novo cliente'),
              style:FilledButton.styleFrom(backgroundColor:const Color(0xFF0C213A),foregroundColor:Colors.white))),
            const Text('Atendimento realizado não confirma pagamento.',
              style:TextStyle(color:muted,fontSize:11)),
          ])),
          const SizedBox(height: 14),
          panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Panorama financeiro',style:TextStyle(
              fontSize:17,fontWeight:FontWeight.w800,color:ink)),
            const SizedBox(height:5),
            const Text('Recebido e pendente • dados fictícios da Central de Cobranças',
              style:TextStyle(fontSize:12,color:muted)),
            const SizedBox(height:14),
            if(widget.demo && ledger.projected>0) ...[
              ClipRRect(borderRadius:BorderRadius.circular(9),
                child:Row(children:[
                  Expanded(flex:(ledger.received/ledger.projected*1000).round().clamp(1,1000).toInt(),
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
                          color: green.withValues(alpha: widget.demo ? .85 : .18),
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
            Text(widget.demo
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
                Text(widget.demo ? '${DemoData.currency(ledger.received)} de ${DemoData.currency(ledger.annualGoal)}' : 'Aguardando dados financeiros',
                  style: const TextStyle(color: muted)),
                const SizedBox(height: 12),
                ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value:widget.demo && ledger.annualGoal>0 ? (ledger.received/ledger.annualGoal).clamp(0.0,1.0):0, minHeight: 9,
                    color: green, backgroundColor: background)),
                const SizedBox(height: 15),
                Text(widget.demo && ledger.annualGoal>0 ? '${(ledger.received/ledger.annualGoal*100).toStringAsFixed(1)}% da meta anual • referência mensal ${DemoData.currency(ledger.annualGoal/12)}' : 'Nenhum progresso calculado sem receitas e meta válidas.',
                  style: const TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft,
                  child: TextButton.icon(onPressed: widget.demo ? () async {
                    final controller=TextEditingController(text:ledger.annualGoal.toStringAsFixed(0));
                    final result=await showDialog<double>(context:context,builder:(ctx)=>AlertDialog(
                      title:const Text('Meta anual demonstrativa'),
                      content:TextField(controller:controller,
                        keyboardType:const TextInputType.numberWithOptions(decimal:true),
                        decoration:const InputDecoration(labelText:'Meta em reais')),
                      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),
                        FilledButton(onPressed:()=>Navigator.pop(ctx,double.tryParse(controller.text.replaceAll(',','.'))),child:const Text('Salvar'))]));
                    controller.dispose();
                    if(result!=null&&result>0)ledger.setGoal(result);
                  } : widget.onFinance,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Definir meta'))),
              ]));
            const agenda = SizedBox.shrink();
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
