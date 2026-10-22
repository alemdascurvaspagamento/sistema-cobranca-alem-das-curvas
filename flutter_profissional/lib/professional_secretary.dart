import 'package:flutter/material.dart';
import 'demo_ledger.dart';
import 'demo_mode.dart';

/// Secretária demonstrativa: regras locais, sem IA remota nem envio automático.
class ProfessionalSecretary extends StatefulWidget {
  const ProfessionalSecretary({super.key,required this.demo,required this.onAgenda,
    required this.onBilling,required this.onClients,required this.onFinance});
  final bool demo;
  final VoidCallback onAgenda,onBilling,onClients,onFinance;
  @override State<ProfessionalSecretary> createState()=>_ProfessionalSecretaryState();
}

class _ProfessionalSecretaryState extends State<ProfessionalSecretary> {
  final hidden=<String>{};
  static const gold=Color(0xFFD8B56A);
  static const surface=Color(0xFF202329);
  Widget suggestion(String id,IconData icon,String title,String detail,
      String priority,Color color,VoidCallback action){
    if(hidden.contains(id))return const SizedBox.shrink();
    return Card(color:surface,child:Padding(
      padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Row(children:[
          Icon(icon,color:color),const SizedBox(width:10),
          Expanded(child:Text(title,style:const TextStyle(fontWeight:FontWeight.bold))),
          IconButton(tooltip:'Dispensar sugestão',icon:const Icon(Icons.close,size:18),
            onPressed:()=>setState(()=>hidden.add(id))),
        ]),
        Padding(padding:const EdgeInsets.only(left:34,right:8),
          child:Text(detail,style:const TextStyle(color:Colors.white70,fontSize:12))),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
          Padding(padding:const EdgeInsets.only(left:34),
            child:Text(priority,style:TextStyle(color:color,fontSize:11))),
          TextButton.icon(onPressed:action,icon:const Icon(Icons.arrow_forward,size:16),
            label:const Text('Resolver')),
        ]),
      ])));
  }
  @override Widget build(BuildContext context)=>AnimatedBuilder(
    animation:DemoLedger.instance,builder:(context,_) {
      final ledger=DemoLedger.instance;
      final now=DateTime.now();
      final overdue=ledger.amounts.keys.where((name)=>ledger.overdue(name)).toList();
      final visits=widget.demo?DemoData.appointments.length:0;
      final completed=widget.demo?DemoData.appointments.where((a)=>
        ledger.visit(a.client,now)?.state=='Realizada').length:0;
      final month='${now.month.toString().padLeft(2,'0')}/${now.year}';
      return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const ListTile(contentPadding:EdgeInsets.zero,
          leading:CircleAvatar(backgroundColor:Color(0xFF403620),
            child:Icon(Icons.support_agent,color:gold)),
          title:Text('Secretária Coach Flow',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
          subtitle:Text('Resumos e próximos passos • assistente demonstrativa')),
        const SizedBox(height:8),
        Card(color:surface,child:Padding(padding:const EdgeInsets.all(16),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Resumo do dia',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
            const SizedBox(height:8),
            Text('${now.day}/$month • $visits atendimentos previstos'),
            Text('$completed realizados • ${visits-completed} ainda não confirmados'),
            const SizedBox(height:8),
            TextButton.icon(onPressed:widget.onAgenda,icon:const Icon(Icons.calendar_month),
              label:const Text('Abrir agenda')),
          ]))),
        Card(color:surface,child:Padding(padding:const EdgeInsets.all(16),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Resumo do mês • $month',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
            const SizedBox(height:8),
            Text('Receita prevista: ${widget.demo?DemoData.currency(ledger.projected):'Não disponível'}'),
            Text('Recebido: ${widget.demo?DemoData.currency(ledger.received):'Não disponível'}'),
            Text('A receber: ${widget.demo?DemoData.currency(ledger.pending):'Não disponível'}'),
            Text('Cobranças vencidas em aberto: ${widget.demo?overdue.length:0}'),
            const SizedBox(height:8),
            TextButton.icon(onPressed:widget.onFinance,icon:const Icon(Icons.bar_chart),
              label:const Text('Abrir financeiro')),
          ]))),
        const SizedBox(height:12),
        const Text('Sugestões da secretária',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
        if(widget.demo&&overdue.isNotEmpty)suggestion('overdue',
          Icons.warning_amber_rounded,'${overdue.length} cobrança(s) vencida(s)',
          'Verifique os vencimentos e os valores antes de cobrar.',
          'URGENTE',const Color(0xFFF1767B),widget.onBilling),
        if(widget.demo&&visits>completed)suggestion('attendance',
          Icons.fact_check_outlined,'${visits-completed} atendimento(s) para conferir',
          'Registre presença, falta ou remarcação na agenda.',
          'ATENÇÃO',const Color(0xFFE0BA62),widget.onAgenda),
        if(widget.demo&&ledger.pending>0)suggestion('payments',
          Icons.receipt_long_outlined,'Pagamentos pendentes',
          'Há ${DemoData.currency(ledger.pending)} a receber. Nem tudo está vencido.',
          'ATENÇÃO',const Color(0xFFE0BA62),widget.onBilling),
        suggestion('clients',Icons.people_outline,'Revisar carteira de clientes',
          'Confira horários, recorrências e cadastros.',
          'OPORTUNIDADE',const Color(0xFF52D69A),widget.onClients),
        if(hidden.isNotEmpty)TextButton.icon(
          onPressed:()=>setState(hidden.clear),
          icon:const Icon(Icons.refresh),label:const Text('Restaurar sugestões')),
        const SizedBox(height:12),
        const Text('Os dados são fictícios e calculados localmente. A secretária não envia mensagens, não agenda sozinha e não utiliza IA generativa nesta versão.',
          style:TextStyle(color:Colors.white60,fontSize:12)),
      ]);
    });
}
