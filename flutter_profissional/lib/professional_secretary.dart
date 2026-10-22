import 'package:flutter/material.dart';
import 'demo_ledger.dart';
import 'demo_mode.dart';

/// Secretária demonstrativa: regras locais, sem IA remota nem envio automático.
class ProfessionalSecretary extends StatelessWidget {
  const ProfessionalSecretary({super.key,required this.demo,required this.onAgenda,
    required this.onBilling,required this.onClients,required this.onFinance});
  final bool demo;
  final VoidCallback onAgenda,onBilling,onClients,onFinance;
  static const gold=Color(0xFFD8B56A);
  static const surface=Color(0xFF202329);
  Widget tile(IconData icon,String title,String subtitle,VoidCallback action)=>Card(
    color:surface,child:ListTile(leading:Icon(icon,color:gold),
      title:Text(title),subtitle:Text(subtitle),
      trailing:const Icon(Icons.chevron_right,color:gold),onTap:action));
  @override Widget build(BuildContext context)=>AnimatedBuilder(
    animation:DemoLedger.instance,builder:(context,_) {
      final ledger=DemoLedger.instance;
      final now=DateTime.now();
      final overdue=ledger.amounts.keys.where((name)=>ledger.overdue(name)).toList();
      final visits=demo?DemoData.appointments.length:0;
      final completed=demo?DemoData.appointments.where((a)=>
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
            TextButton.icon(onPressed:onAgenda,icon:const Icon(Icons.calendar_month),
              label:const Text('Abrir agenda')),
          ]))),
        Card(color:surface,child:Padding(padding:const EdgeInsets.all(16),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Resumo do mês • $month',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
            const SizedBox(height:8),
            Text('Receita prevista: ${demo?DemoData.currency(ledger.projected):'Não disponível'}'),
            Text('Recebido: ${demo?DemoData.currency(ledger.received):'Não disponível'}'),
            Text('A receber: ${demo?DemoData.currency(ledger.pending):'Não disponível'}'),
            Text('Cobranças vencidas em aberto: ${demo?overdue.length:0}'),
            const SizedBox(height:8),
            TextButton.icon(onPressed:onFinance,icon:const Icon(Icons.bar_chart),
              label:const Text('Abrir financeiro')),
          ]))),
        const SizedBox(height:12),
        const Text('Sugestões da secretária',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
        if(demo&&overdue.isNotEmpty)tile(Icons.priority_high,
          'Revisar ${overdue.length} cobrança(s) vencida(s)',
          'Conferir antes de entrar em contato com clientes.',onBilling),
        tile(Icons.fact_check_outlined,'Conferir atendimentos do dia',
          'Registrar realizados, faltas e remarcações.',onAgenda),
        tile(Icons.receipt_long_outlined,'Revisar pagamentos pendentes',
          'Não confundir valores a vencer com atrasados.',onBilling),
        tile(Icons.person_add_alt_outlined,'Organizar sua carteira de clientes',
          'Revisar cadastros e horários de atendimento.',onClients),
        const SizedBox(height:12),
        const Text('Os dados são fictícios e calculados localmente. A secretária não envia mensagens, não agenda sozinha e não utiliza IA generativa nesta versão.',
          style:TextStyle(color:Colors.white60,fontSize:12)),
      ]);
    });
}
