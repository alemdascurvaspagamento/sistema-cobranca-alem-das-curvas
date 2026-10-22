import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'demo_mode.dart';
import 'demo_ledger.dart';

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
  double get total => (gross - creditValue - discount).clamp(0.0,double.infinity).toDouble();
  String get status => paid?'Recebido':'Pendente';
}

class _BillingVisit {
  _BillingVisit(this.date, this.hour, this.state);
  final DateTime date;
  final String hour;
  String state;
  String note = '';
  bool charge = true;
}

class DemoBilling extends StatefulWidget {
  const DemoBilling({super.key});
  @override State<DemoBilling> createState()=>_DemoBillingState();
}

class _DemoBillingState extends State<DemoBilling> {
  String search='',filter='Todos';
  final ledger=DemoLedger.instance;
  @override void initState(){super.initState(); ledger.addListener(_refresh);}
  void _refresh(){if(mounted)setState((){});}
  @override void dispose(){ledger.removeListener(_refresh);super.dispose();}
  double totalFor(BillingAccount a)=>ledger.amounts[a.name] ?? a.total;
  bool paidFor(BillingAccount a)=>ledger.isPaid(a.name);
  String statusFor(BillingAccount a)=>paidFor(a)?'Recebido':'Pendente';
  void recalculate(BillingAccount a){
    final current=ledger.visits[a.name]?.values.toList()??[];
    final completed=current.where((v)=>v.state=='Realizada'&&v.charge).length;
    ledger.updateBilling(a.name,(completed*a.unitPrice-a.creditValue-a.discount)
      .clamp(0.0,double.infinity).toDouble());
  }
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
    (filter=='Todos'||statusFor(a)==filter) &&
    (a.name.toLowerCase().contains(search.toLowerCase())||
     a.service.toLowerCase().contains(search.toLowerCase()))).toList();
  // Registros sintéticos apenas para demonstrar a consulta detalhada.
  // Não representam a agenda real nem alteram o cálculo da cobrança.
  final Map<String, List<_BillingVisit>> _visits = {};
  List<_BillingVisit> visitsFor(BillingAccount a) => _visits.putIfAbsent(a.name, () {
    final now = DateTime.now();
    final days = <DateTime>[];
    for (var d = 1; d <= DateUtils.getDaysInMonth(now.year, now.month); d++) {
      final date = DateTime(now.year, now.month, d);
      if (date.weekday <= 5) days.add(date);
    }
    final result = <_BillingVisit>[];
    for (var i = 0; i < a.scheduled && i < days.length; i++) {
      final state = i < a.completed ? 'Realizada'
        : i < a.completed + a.cancelled ? 'Cancelada'
        : i < a.completed + a.cancelled + a.rescheduled ? 'Remarcada'
        : 'Agendada';
      result.add(_BillingVisit(days[i], '09:00', state));
    }
    for(final visit in result){
      final saved=ledger.visit(a.name,visit.date);
      if(saved!=null){visit.state=saved.state;visit.charge=saved.charge;visit.note=saved.note;}
    }
    return result;
  });
  Color visitColor(String state) => switch(state) {
    'Realizada' => const Color(0xFF42BA83),
    'Cancelada' => const Color(0xFFE96767),
    'Remarcada' => const Color(0xFFF4A15A),
    'Crédito' => const Color(0xFFA47DE1),
    _ => const Color(0xFF4B91F1),
  };
  Future<void> editVisit(_BillingVisit visit, StateSetter refresh) async {
    var state = visit.state;
    var charge = visit.charge;
    final notes = TextEditingController(text: visit.note);
    final ok = await showDialog<bool>(context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Detalhes do atendimento'),
          content: SizedBox(width: MediaQuery.sizeOf(dialogContext).width < 450 ? MediaQuery.sizeOf(dialogContext).width * .72 : 360, child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${visit.date.day.toString().padLeft(2, '0')}/'
                '${visit.date.month.toString().padLeft(2, '0')} • ${visit.hour}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: state,
                decoration: const InputDecoration(labelText: 'Situação'),
                items: ['Agendada', 'Realizada', 'Cancelada', 'Remarcada', 'Crédito', 'Feriado']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) { if (v != null) update(() => state = v); },
              ),
              SwitchListTile(
                title: const Text('Cobrar atendimento'),
                subtitle: const Text('Apenas anotação demonstrativa'),
                value: charge, onChanged: (v) => update(() => charge = v)),
              TextField(controller: notes, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Motivo / observações')),
            ],
          ))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar')),
          ],
        )));
    if (ok == true && mounted) {
      refresh(() { visit.state = state; visit.charge = charge; visit.note = notes.text.trim(); });
      for(final account in accounts){if(visitsFor(account).contains(visit)){
        ledger.updateVisit(account.name,visit.date,state,charge,visit.note);break;
      }}
    }
    notes.dispose();
  }
  Future<void> details(BillingAccount a) async {
    final visits = visitsFor(a);
    final today = DateTime.now();
    const months = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    await showDialog<void>(context: context, builder: (ctx) =>
      StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        title: Text('Atendimentos de ${a.name} — ${months[today.month - 1]}/${today.year}'),
        content: SizedBox(width: MediaQuery.sizeOf(ctx).width < 680 ? MediaQuery.sizeOf(ctx).width * .75 : 620, child: SingleChildScrollView(child:
          Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Datas demonstrativas: toque em um atendimento para '
                'consultar ou alterar situação, cobrança e observações.',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 12),
              Wrap(spacing: 7, runSpacing: 8, children: [
                for (final visit in visits)
                  ActionChip(
                    avatar: Icon(Icons.circle, size: 9, color: visitColor(visit.state)),
                    label: Text('${visit.date.day.toString().padLeft(2, '0')}/'
                      '${visit.date.month.toString().padLeft(2, '0')} '
                      '· ${visit.hour} · ${visit.state}'),
                    onPressed: () => editVisit(visit, refresh)),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 7, children: [
                for (final state in ['Agendada','Realizada','Cancelada','Remarcada','Crédito','Feriado'])
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.circle, size: 10, color: visitColor(state)),
                    const SizedBox(width: 4),
                    Text(state, style: const TextStyle(fontSize: 11)),
                  ]),
              ]),
              const Divider(height: 30),
              const Text('Memória de cálculo da cobrança',
                style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _line('Atendimentos previstos', '${a.scheduled}'),
              _line('Realizados considerados na cobrança', '${ledger.visits[a.name]?.values.where((v)=>v.state=='Realizada'&&v.charge).length??0}'),
              _line('Cancelamentos', '${a.cancelled} (não faturados)'),
              _line('Remarcações', '${a.rescheduled} (não duplicadas)'),
              _line('Valor por atendimento', DemoData.currency(a.unitPrice)),
              _line('Subtotal', DemoData.currency((ledger.visits[a.name]?.values.where((v)=>v.state=='Realizada'&&v.charge).length??0)*a.unitPrice)),
              _line('Créditos (${a.credits})', '− ${DemoData.currency(a.creditValue)}'),
              _line('Descontos', '− ${DemoData.currency(a.discount)}'),
              const Divider(),
              _line('Total a cobrar', DemoData.currency(totalFor(a))),
              const SizedBox(height: 12),
              const Text('Alterações recalculam esta cobrança e os indicadores da dashboard nesta sessão. Não são persistidas em banco nem alteram a agenda independente.',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
            ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Fechar'))],
      )));
  }
  Widget _line(String label,String value)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:4),
    child:Row(children:[Expanded(child:Text(label)),Text(value,
      style:const TextStyle(fontWeight:FontWeight.w600))]));
  Future<void> whatsapp(BillingAccount a) async {
    if(paidFor(a)||totalFor(a)<=0)return;
    var phone=a.phone.replaceAll(RegExp(r'[^0-9]'),'');
    if(phone.length==10||phone.length==11)phone='55$phone';
    if(phone.length<12||phone.length>13){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('WhatsApp inválido: verifique o DDD.')));
      return;
    }
    final message='Olá, ${a.name}! Segue o resumo demonstrativo dos atendimentos '
      'de ${a.service}: ${a.completed} realizados, '
      '${a.credits} crédito(s), total de ${DemoData.currency(totalFor(a))}. '
      'Por favor, confira os valores antes do pagamento. Obrigado!';
    final url=Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    if(!await launchUrl(url,mode:LaunchMode.externalApplication)&&mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Não foi possível abrir o WhatsApp.')));
    }
  }
  Future<void> changePaid(BillingAccount a) async {
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(paidFor(a)?'Reabrir cobrança?':'Marcar como recebida?'),
      content:Text('Alterar apenas o estado fictício da cobrança de ${a.name}?'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Confirmar'))],
    ));
    if(confirmed==true&&mounted)ledger.setPaid(a.name,!paidFor(a));
  }
  Future<void> absencePeriod(BillingAccount account) async {
    DateTimeRange? range;
    String reason='Férias';
    final approved=await showDialog<bool>(context:context,
      builder:(dialogContext)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
        title:Text('Ausência • ${account.name}'),
        content:SizedBox(width:MediaQuery.sizeOf(ctx).width<500?MediaQuery.sizeOf(ctx).width*.72:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('Selecione o período e confira quantos atendimentos serão alterados. '
            'Na demonstração, apenas as sessões deste cliente serão afetadas.'),
          const SizedBox(height:14),
          OutlinedButton.icon(
            icon:const Icon(Icons.date_range_outlined),
            label:Text(range==null?'Escolher período':
              '${range!.start.day}/${range!.start.month} até ${range!.end.day}/${range!.end.month}'),
            onPressed:() async {
              final selected=await showDateRangePicker(context:ctx,
                firstDate:DateTime(2020),lastDate:DateTime(2035),
                initialDateRange:range);
              if(selected!=null)refresh(()=>range=selected);
            }),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(value:reason,
            decoration:const InputDecoration(labelText:'Motivo'),
            items:['Férias','Viagem','Ausência justificada','Outro']
              .map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
            onChanged:(v)=>refresh(()=>reason=v??reason)),
          if(range!=null)Padding(padding:const EdgeInsets.only(top:14),
            child:Text('Serão afetados ${visitsFor(account).where((v)=>
              !v.date.isBefore(range!.start)&&!v.date.isAfter(range!.end)).length} '
              'atendimentos. Sessões realizadas também serão modificadas; '
              'revise antes de confirmar.',
              style:const TextStyle(color:_gold))),
        ]))),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
          FilledButton(onPressed:range==null?null:()=>Navigator.pop(ctx,true),
            child:const Text('Aplicar ausência')),
        ],
      )));
    if(approved!=true||range==null||!mounted)return;
    final affected=visitsFor(account).where((v)=>
      !v.date.isBefore(range!.start)&&!v.date.isAfter(range!.end)).toList();
    final before={for(final v in affected)v:(v.state,v.charge,v.note)};
    for(final visit in affected){
      visit.state='Cancelada';visit.charge=false;visit.note=reason;
      ledger.setAbsence(account.name,visit.date,reason);
      ledger.updateVisit(account.name,visit.date,'Cancelada',false,reason);
    }
    recalculate(account);
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Text('${affected.length} atendimentos ajustados na demonstração.'),
      duration:const Duration(seconds:8),
      action:SnackBarAction(label:'DESFAZER',onPressed:(){
        for(final visit in affected){
          final old=before[visit]!;
          visit.state=old.$1;visit.charge=old.$2;visit.note=old.$3;
          ledger.setAbsence(account.name,visit.date,null);
          ledger.updateVisit(account.name,visit.date,old.$1,old.$2,old.$3);
        }
        recalculate(account);
      })));
  }
  Widget actions(BillingAccount a)=>Wrap(spacing:4,runSpacing:6,children:[
    OutlinedButton.icon(onPressed:()=>details(a),
      icon:const Icon(Icons.event_note_outlined,size:17),
      label:const Text('Ver atendimentos')),
    if(!paidFor(a)) OutlinedButton.icon(onPressed:()=>whatsapp(a),
      icon:const Icon(Icons.chat_outlined,size:17,color:Color(0xFF42BA83)),
      label:const Text('WhatsApp')),
    PopupMenuButton<String>(
      tooltip:'Outras ações',
      onSelected:(choice){
        if(choice=='payment')changePaid(a);
        if(choice=='absence')absencePeriod(a);
      },
      itemBuilder:(_)=>[
        PopupMenuItem(value:'payment',child:Text(paidFor(a)?
          'Reabrir cobrança':'Registrar pagamento')),
        const PopupMenuItem(value:'absence',child:Text('Férias / ausência')),
      ],
      icon:const Icon(Icons.more_horiz,color:_gold)),
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
        DataCell(Text(statusFor(a))),
        DataCell(actions(a)),
      ])]));
  Widget mobileCard(BillingAccount a)=>Card(color:_surface,child:Padding(
    padding:const EdgeInsets.all(14),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Row(children:[Expanded(child:Text(a.name,
          style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold))),
          Chip(label:Text(statusFor(a)))]),
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
    final total=accounts.fold<double>(0,(sum,a)=>sum+totalFor(a));
    final received=accounts.where((a)=>paidFor(a)).fold<double>(0,(sum,a)=>sum+totalFor(a));
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
