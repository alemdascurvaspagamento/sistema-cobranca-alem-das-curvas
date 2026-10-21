import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'demo_mode.dart';

const _gold = Color(0xFFD8B56A);
const _surface = Color(0xFF1A1D22);

class BillingAccount {
  BillingAccount(this.name,this.service,this.phone,this.unitPrice,this.scheduled,
    this.completed,this.cancelled,this.rescheduled,this.credits,this.discount,
    {this.paid=false});
  final String name,service,phone;
  final double unitPrice,discount;
  final int scheduled,completed,cancelled,rescheduled,credits;
  bool paid;
  // A cobrança usa apenas atendimentos efetivamente realizados, sem contar
  // remarcações como novas sessões. Desconto e créditos são abatidos uma vez.
  double get gross => completed * unitPrice;
  double get creditValue => credits * unitPrice;
  double get total => (gross - creditValue - discount).clamp(0.0,double.infinity);
  String get status => paid?'Recebido':'Pendente';
}

class DemoBilling extends StatefulWidget {
  const DemoBilling({super.key});
  @override State<DemoBilling> createState()=>_DemoBillingState();
}

class _DemoBillingState extends State<DemoBilling> {
  String search='',filter='Todos';
  final accounts=<BillingAccount>[
    BillingAccount('Mariana Costa','Consultoria individual','(11) 99999-0001',
      180,8,7,1,0,0,0,paid:true),
    BillingAccount('Ricardo Almeida','Avaliação inicial','(11) 99999-0002',
      220,4,3,1,1,0,0),
    BillingAccount('Fernanda Lima','Acompanhamento','(11) 99999-0003',
      150,6,5,0,1,1,0),
    BillingAccount('Paulo Martins','Sessão de retorno','(11) 99999-0004',
      180,5,4,1,0,0,90),
  ];
  List<BillingAccount> get shown => accounts.where((a)=>
    (filter=='Todos'||a.status==filter) &&
    (a.name.toLowerCase().contains(search.toLowerCase())||
     a.service.toLowerCase().contains(search.toLowerCase()))).toList();
  Future<void> details(BillingAccount a) async {
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:Text('Memória de cálculo — ${a.name}'),
      content:SizedBox(width:430,child:Column(mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text(a.service),
        const SizedBox(height:12),
        _line('Atendimentos previstos','${a.scheduled}'),
        _line('Atendimentos realizados','${a.completed}'),
        _line('Cancelamentos','${a.cancelled} (não faturados)'),
        _line('Remarcações','${a.rescheduled} (não duplicadas)'),
        _line('Valor por atendimento',DemoData.currency(a.unitPrice)),
        _line('Subtotal realizado',DemoData.currency(a.gross)),
        _line('Créditos (${a.credits})','− ${DemoData.currency(a.creditValue)}'),
        _line('Descontos','− ${DemoData.currency(a.discount)}'),
        const Divider(),
        _line('Total a cobrar',DemoData.currency(a.total)),
        const SizedBox(height:12),
        const Text('Regra ilustrativa: somente sessões realizadas entram no subtotal. '
          'Contratos por mensalidade, pacote ou projeto exigirão regras próprias.',
          style:TextStyle(fontSize:12,color:Colors.white70)),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Fechar'))],
    ));
  }
  Widget _line(String label,String value)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:4),
    child:Row(children:[Expanded(child:Text(label)),Text(value,
      style:const TextStyle(fontWeight:FontWeight.w600))]));
  Future<void> whatsapp(BillingAccount a) async {
    if(a.paid||a.total<=0)return;
    var phone=a.phone.replaceAll(RegExp(r'[^0-9]'),'');
    if(phone.length==10||phone.length==11)phone='55$phone';
    if(phone.length<12||phone.length>13){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('WhatsApp inválido: verifique o DDD.')));
      return;
    }
    final message='Olá, ${a.name}! Segue o resumo demonstrativo dos atendimentos '
      'de ${a.service}: ${a.completed} realizados, '
      '${a.credits} crédito(s), total de ${DemoData.currency(a.total)}. '
      'Por favor, confira os valores antes do pagamento. Obrigado!';
    final url=Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    if(!await launchUrl(url,mode:LaunchMode.externalApplication)&&mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Não foi possível abrir o WhatsApp.')));
    }
  }
  Future<void> changePaid(BillingAccount a) async {
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(a.paid?'Reabrir cobrança?':'Marcar como recebida?'),
      content:Text('Alterar apenas o estado fictício da cobrança de ${a.name}?'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Confirmar'))],
    ));
    if(confirmed==true&&mounted)setState(()=>a.paid=!a.paid);
  }
  Widget actions(BillingAccount a)=>Wrap(spacing:2,children:[
    IconButton(tooltip:'Memória de cálculo',icon:const Icon(Icons.receipt_long_outlined),
      onPressed:()=>details(a)),
    IconButton(tooltip:'Preparar WhatsApp',icon:const Icon(Icons.chat_outlined,
      color:Color(0xFF25D366)),onPressed:()=>whatsapp(a)),
    IconButton(tooltip:a.paid?'Reabrir cobrança':'Marcar recebida',
      icon:Icon(a.paid?Icons.undo:Icons.check_circle_outline,color:_gold),
      onPressed:()=>changePaid(a)),
  ]);
  Widget desktopTable(List<BillingAccount> data)=>SingleChildScrollView(
    scrollDirection:Axis.horizontal,child:DataTable(
      columnSpacing:20,headingRowColor:WidgetStateProperty.all(_surface),
      columns:const [
        DataColumn(label:Text('Cliente / serviço')),
        DataColumn(label:Text('Valor / sessão')),
        DataColumn(label:Text('Previstas')),
        DataColumn(label:Text('Realizadas')),
        DataColumn(label:Text('Canceladas')),
        DataColumn(label:Text('Remarcadas')),
        DataColumn(label:Text('Créditos')),
        DataColumn(label:Text('Descontos')),
        DataColumn(label:Text('Total')),
        DataColumn(label:Text('Situação')),
        DataColumn(label:Text('Ações')),
      ],
      rows:[for(final a in data)DataRow(cells:[
        DataCell(Column(mainAxisAlignment:MainAxisAlignment.center,
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(a.name,style:const TextStyle(fontWeight:FontWeight.bold)),
          Text(a.service,style:const TextStyle(fontSize:11,color:Colors.white60))])),
        DataCell(Text(DemoData.currency(a.unitPrice))),
        DataCell(Text('${a.scheduled}')),
        DataCell(Text('${a.completed}')),
        DataCell(Text('${a.cancelled}')),
        DataCell(Text('${a.rescheduled}')),
        DataCell(Text('${a.credits}')),
        DataCell(Text(DemoData.currency(a.discount))),
        DataCell(Text(DemoData.currency(a.total),
          style:const TextStyle(color:_gold,fontWeight:FontWeight.bold))),
        DataCell(Text(a.status)),
        DataCell(actions(a)),
      ])]));
  Widget mobileCard(BillingAccount a)=>Card(color:_surface,child:Padding(
    padding:const EdgeInsets.all(14),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Row(children:[Expanded(child:Text(a.name,
          style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold))),
          Chip(label:Text(a.status))]),
        Text(a.service,style:const TextStyle(color:Colors.white70)),
        const SizedBox(height:8),
        Text('${a.completed} realizados · ${a.cancelled} cancelados · '
          '${a.credits} créditos',style:const TextStyle(fontSize:12)),
        const SizedBox(height:8),
        Row(children:[Expanded(child:Text(DemoData.currency(a.total),
          style:const TextStyle(color:_gold,fontSize:20,fontWeight:FontWeight.bold))),
          actions(a)]),
      ])));
  Widget metric(String label,double value,IconData icon)=>Card(
    color:_surface,child:Padding(padding:const EdgeInsets.all(14),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(icon,color:_gold,size:20),const SizedBox(height:8),
        Text(label,style:const TextStyle(fontSize:12,color:Colors.white70)),
        Text(DemoData.currency(value),
          style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
      ])));
  @override Widget build(BuildContext context){
    final total=accounts.fold<double>(0,(sum,a)=>sum+a.total);
    final received=accounts.where((a)=>a.paid).fold<double>(0,(sum,a)=>sum+a.total);
    final data=shown;
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text('Central de cobranças',style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:6),
      const Text('Demonstrativo por atendimento, com cálculo auditável e revisão humana.',
        style:TextStyle(color:Colors.white70)),
      const SizedBox(height:14),
      LayoutBuilder(builder:(context,box)=>GridView.count(
        crossAxisCount:box.maxWidth<580?1:3,childAspectRatio:box.maxWidth<580?5:2.1,
        shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
        children:[
          metric('Total calculado',total,Icons.receipt_long_outlined),
          metric('Recebido',received,Icons.check_circle_outline),
          metric('A receber',total-received,Icons.schedule_outlined),
        ])),
      const SizedBox(height:12),
      Wrap(spacing:12,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,
        children:[
          SizedBox(width:280,child:TextField(
            onChanged:(value)=>setState(()=>search=value),
            decoration:const InputDecoration(prefixIcon:Icon(Icons.search),
              hintText:'Buscar cliente ou serviço',border:OutlineInputBorder()))),
          DropdownButton<String>(value:filter,items:[
            for(final option in ['Todos','Pendente','Recebido'])
              DropdownMenuItem(value:option,child:Text(option))],
            onChanged:(value)=>setState(()=>filter=value??'Todos')),
        ]),
      const SizedBox(height:12),
      if(data.isEmpty)const Padding(padding:EdgeInsets.all(24),
        child:Text('Nenhuma cobrança encontrada.')),
      LayoutBuilder(builder:(context,box)=>box.maxWidth<750?
        Column(children:[for(final a in data)mobileCard(a)]):
        Card(color:_surface,child:desktopTable(data))),
      const SizedBox(height:12),
      const Text('DADOS FICTÍCIOS • Valores e status não são persistidos. '
        'O WhatsApp abre uma mensagem para revisão, sem envio automático. '
        'Este demonstrativo não está sincronizado com a agenda nem com o financeiro.',
        style:TextStyle(color:Colors.white60,fontSize:12)),
    ]);
  }
}
