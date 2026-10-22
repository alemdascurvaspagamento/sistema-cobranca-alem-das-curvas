import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'demo_mode.dart';
import 'client_editor.dart';
import 'demo_ledger.dart';

const demoGold = Color(0xFF0C213A);
const demoSurface = Color(0xFFFFFFFF);

class DemoClient {
  DemoClient(this.name, this.service, this.status, this.phone);
  String name, service, status, phone;
  ClientProfile? profile;
}

class DemoClients extends StatefulWidget {
  const DemoClients({super.key});
  @override State<DemoClients> createState() => _DemoClientsState();
}

class _DemoClientsState extends State<DemoClients> {
  final clients = <DemoClient>[
    DemoClient('Mariana Costa','Plano mensal','Em dia','(11) 99999-0001'),
    DemoClient('Ricardo Almeida','Avaliação','Pendente','(11) 99999-0002'),
    DemoClient('Fernanda Lima','Acompanhamento','Em dia','(11) 99999-0003'),
    DemoClient('Paulo Martins','Retorno','Em dia','(11) 99999-0004'),
  ];
  final ledger=DemoLedger.instance;
  @override void initState(){super.initState();ledger.addListener(_refresh);}
  void _refresh(){if(mounted)setState((){});}
  @override void dispose(){ledger.removeListener(_refresh);super.dispose();}
  String financialStatus(DemoClient c)=>ledger.amounts.containsKey(c.name)?
    (ledger.isPaid(c.name)?'Em dia':ledger.paymentStatus(c.name)):c.status;
  String search = '';
  String clientFilter = 'Todos';
  Future<void> openBillingWhatsApp(DemoClient client) async {
    var digits=client.phone.replaceAll(RegExp(r'[^0-9]'),'');
    if(digits.length==10 || digits.length==11) digits='55$digits';
    if(digits.length<12 || digits.length>13){
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Cadastre um WhatsApp válido com DDD.')));
      return;
    }
    final message='Olá, ${client.name}! Tudo bem? Aqui é da equipe Coach Flow. '
      'Estamos entrando em contato sobre ${client.service}. '
      'Podemos confirmar a situação do seu pagamento? '
      'Caso já tenha efetuado, desconsidere esta mensagem. Obrigado!';
    final uri=Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
    if(!await launchUrl(uri,mode:LaunchMode.externalApplication) && mounted){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Não foi possível abrir o WhatsApp.')));
    }
  }
  Future<void> openWhatsApp(DemoClient client) async {
    var digits=client.phone.replaceAll(RegExp(r'[^0-9]'),'');
    if(digits.length==10 || digits.length==11) digits='55$digits';
    if(digits.length<12 || digits.length>13){
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Informe um WhatsApp válido com DDD.')));
      return;
    }
    final message=Uri.encodeComponent('Olá, ${client.name}! Aqui é da equipe Coach Flow. Podemos conversar sobre ${client.service}?');
    final uri=Uri.parse('https://wa.me/$digits?text=$message');
    if(!await launchUrl(uri,mode:LaunchMode.externalApplication) && mounted){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Não foi possível abrir o WhatsApp.')));
    }
  }
  Future<void> deleteClient(DemoClient client) async {
    final confirmed = await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Excluir cliente fictício?'),
      content:Text('Remover ${client.name} desta demonstração?'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Excluir'))],
    ));
    if(confirmed==true && mounted) setState(()=>clients.remove(client));
  }
  Future<void> edit([DemoClient? current]) async {
    final initial=current?.profile ?? (current==null?null:ClientProfile(
      name:current.name,service:current.service,phone:current.phone,status:current.status));
    final result=await showDialog<ClientProfile>(context:context,
      builder:(ctx)=>ClientEditor(initial:initial));
    if(result==null || !mounted)return;
    setState((){
      if(current==null){
        final client=DemoClient(result.name,result.service,result.status,result.phone);
        client.profile=result;
        clients.add(client);
      }else{
        current.name=result.name;
        current.service=result.service;
        current.status=result.status;
        current.phone=result.phone;
        current.profile=result;
      }
      final day=int.tryParse(result.dueDay);
      if(day!=null&&day>=1&&day<=31)ledger.setDueDay(result.name,day);
    });
  }
  @override Widget build(BuildContext context) {
    final term=search.trim().toLowerCase();
    final shown=clients.where((c) =>
      (clientFilter=='Todos' || financialStatus(c)==clientFilter) &&
      (c.name.toLowerCase().contains(term) || c.service.toLowerCase().contains(term) ||
        c.phone.toLowerCase().contains(term))).toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Wrap(alignment:WrapAlignment.spaceBetween,runSpacing:12,children:[
        Text('${clients.length} clientes fictícios',style:const TextStyle(color:demoGold,fontSize:16)),
        FilledButton.icon(onPressed:()=>edit(),icon:const Icon(Icons.person_add_alt_1),label:const Text('Novo cliente')),
      ]),
      const SizedBox(height:14),
      TextField(onChanged:(v)=>setState(()=>search=v),decoration:const InputDecoration(
        prefixIcon:Icon(Icons.search),labelText:'Pesquisar nome, serviço ou telefone',border:OutlineInputBorder())),
      const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:[
        for(final option in ['Todos','Em dia','Pendente','Em atraso'])
          ChoiceChip(label:Text(option),selected:clientFilter==option,
            onSelected:(_)=>setState(()=>clientFilter=option)),
      ]),
      const SizedBox(height:14),
      if(shown.isEmpty) const Padding(padding:EdgeInsets.all(24),child:Text('Nenhum cliente encontrado.')),
      for(final c in shown) Card(
        color:demoSurface,
        margin:const EdgeInsets.only(bottom:12),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),
          side:const BorderSide(color:Color(0xFF245A98),width:1.5)),
        child:Padding(padding:const EdgeInsets.all(15),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const CircleAvatar(radius:22,backgroundColor:Color(0xFFFFF4DE),
                child:Icon(Icons.person,color:demoGold)),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(c.name,maxLines:2,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
                const SizedBox(height:4),
                Text(c.service,maxLines:2,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontSize:13,color:Color(0xFF64748B))),
                const SizedBox(height:3),
                Text(c.phone,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontSize:12,color:Color(0xFF64748B))),
              ])),
              const SizedBox(width:8),
              Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:7),
                decoration:BoxDecoration(
                  color:financialStatus(c)=='Em dia'?const Color(0xFFE7F6EF):financialStatus(c)=='Em atraso'?const Color(0xFFFCECED):const Color(0xFFFFF4DE),
                  borderRadius:BorderRadius.circular(9)),
                child:Text(financialStatus(c),maxLines:1,style:TextStyle(
                  color:c.status=='Em dia'?const Color(0xFF20835D):c.status=='Em atraso'?const Color(0xFFC34B50):demoGold,
                  fontSize:11,fontWeight:FontWeight.w700))),
            ]),
            const SizedBox(height:12),
            const Divider(height:1,color:Color(0xFFE2E8F0)),
            const SizedBox(height:10),
            LayoutBuilder(builder:(context,box){
              final compact=box.maxWidth<470;
              return Row(children:[
                Expanded(child:OutlinedButton.icon(onPressed:()=>edit(c),
                    icon:const Icon(Icons.edit_outlined,size:17),
                    label:Text(compact?'':'Editar',maxLines:1,overflow:TextOverflow.ellipsis),
                    style:OutlinedButton.styleFrom(
                      padding:const EdgeInsets.symmetric(horizontal:6,vertical:12)))),
                const SizedBox(width:6),
                Expanded(child:OutlinedButton.icon(onPressed:()=>openWhatsApp(c),
                    icon:const Icon(Icons.chat_outlined,size:17),
                    label:Text(compact?'':'WhatsApp',maxLines:1,overflow:TextOverflow.ellipsis),
                    style:OutlinedButton.styleFrom(
                      padding:const EdgeInsets.symmetric(horizontal:6,vertical:12),
                      foregroundColor:Colors.white,
                      backgroundColor:const Color(0xFF25D366),
                      side:const BorderSide(color:Color(0xFF25D366))))),
                const SizedBox(width:6),
                Expanded(child:OutlinedButton.icon(onPressed:()=>openBillingWhatsApp(c),
                      icon:const Icon(Icons.receipt_long_outlined,size:17),
                      label:Text(compact?'':'Cobrar',maxLines:1,overflow:TextOverflow.ellipsis),
                      style:OutlinedButton.styleFrom(
                        padding:const EdgeInsets.symmetric(horizontal:6,vertical:12),
                        foregroundColor:Colors.white,
                        backgroundColor:const Color(0xFF0C213A),
                        side:const BorderSide(color:Color(0xFF0C213A))))),
                const SizedBox(width:6),
                Expanded(child:OutlinedButton.icon(onPressed:()=>deleteClient(c),
                    icon:const Icon(Icons.delete_outline,size:17),
                    label:Text(compact?'':'Excluir',maxLines:1,overflow:TextOverflow.ellipsis),
                    style:OutlinedButton.styleFrom(
                      padding:const EdgeInsets.symmetric(horizontal:6,vertical:12),
                      foregroundColor:const Color(0xFF64748B)))),
              ]);
            }),
          ]))),
      const SizedBox(height:12),
      const Text('Os cadastros são temporários: serão descartados ao atualizar a página.',style:TextStyle(color:Color(0xFF64748B),fontSize:12)),
    ]);
  }
}

class DemoFinance extends StatefulWidget {
  const DemoFinance({super.key});
  @override State<DemoFinance> createState()=>_DemoFinanceState();
}
class _DemoFinanceState extends State<DemoFinance> {
  String filter = 'Todos';
  double annualGoal = 0;
  bool trackAnnualGoal = false;
  String balancePeriod = 'Mensal';
  Future<void> editAnnualGoal() async {
    final controller=TextEditingController(text:annualGoal>0?annualGoal.toStringAsFixed(0):'');
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text('Meta de receita — ${DateTime.now().year}'),
      content:SizedBox(width:380,child:TextField(controller:controller,keyboardType:const TextInputType.numberWithOptions(decimal:true),
        decoration:const InputDecoration(labelText:'Meta anual em reais',helperText:'Valor demonstrativo; não será salvo.'))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Salvar'))],
    ));
    if(confirmed==true && mounted){
      final value=double.tryParse(controller.text.replaceAll(',','.'));
      if(value!=null && value>=0) setState(()=>annualGoal=value);
    }
    controller.dispose();
  }
  Future<void> deleteEntry(int index) async {
    if(index<0 || index>=items.length) return;
    final entry=items[index];
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Excluir lançamento fictício?'),
      content:Text('Remover ${entry.name} (${DemoData.currency(entry.value)})?'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Excluir')),
      ],
    ));
    if(confirmed==true && mounted && items.contains(entry)) {
      setState(()=>items.remove(entry));
    }
  }
  final items=<({String name,String type,double value,bool paid})>[
    (name:'Mariana Costa',type:'Receita',value:180,paid:true),
    (name:'Ricardo Almeida',type:'Receita',value:220,paid:false),
    (name:'Fernanda Lima',type:'Receita',value:150,paid:true),
    (name:'Paulo Martins',type:'Receita',value:150,paid:false),
    (name:'Material de escritório',type:'Despesa',value:120,paid:false),
  ];
  Future<void> add() async {
    final name=TextEditingController();
    final amount=TextEditingController();
    String type='Receita';
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(
      builder:(ctx,refresh)=>AlertDialog(title:const Text('Novo lançamento fictício'),
      content:SizedBox(width:400,child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Descrição')),
        TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
          decoration:const InputDecoration(labelText:'Valor em reais')),
        DropdownButtonFormField<String>(value:type,items:['Receita','Despesa']
          .map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
          onChanged:(v)=>refresh(()=>type=v??type)),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
      FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Adicionar'))])));
    final value=double.tryParse(amount.text.replaceAll(',','.'));
    if(ok==true&&value!=null&&value>0&&name.text.trim().isNotEmpty&&mounted){
      setState(()=>items.add((name:name.text.trim(),type:type,value:value,paid:false)));
    }
    name.dispose();amount.dispose();
  }
  @override Widget build(BuildContext context) {
    final received=items.where((e)=>e.type=='Receita'&&e.paid).fold<double>(0,(s,e)=>s+e.value);
    final pending=items.where((e)=>e.type=='Receita'&&!e.paid).fold<double>(0,(s,e)=>s+e.value);
    final expenses=items.where((e)=>e.type=='Despesa'&&!e.paid).fold<double>(0,(s,e)=>s+e.value);
    final paidExpenses=items.where((e)=>e.type=='Despesa'&&e.paid).fold<double>(0,(s,e)=>s+e.value);
    final visible=items.asMap().entries.where((entry) {
      final e=entry.value;
      return filter=='Todos' || (filter=='Receitas' && e.type=='Receita') ||
        (filter=='Despesas' && e.type=='Despesa') ||
        (filter=='Pendentes' && !e.paid);
    }).toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Card(color:demoSurface,shape:RoundedRectangleBorder(
        borderRadius:BorderRadius.circular(16),
        side:const BorderSide(color:Color(0xFF245A98),width:1.3)),
        child:Padding(padding:const EdgeInsets.all(18),child:Column(
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Wrap(alignment:WrapAlignment.spaceBetween,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
            const Text('Meta anual de recebimentos',
              style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
            TextButton.icon(onPressed:editAnnualGoal,
              icon:const Icon(Icons.edit_outlined),label:const Text('Definir meta')),
          ]),
          const SizedBox(height:8),
          SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,
            title:const Text('Acompanhar meta anual'),
            subtitle:const Text('Ative para consultar o balanço por período.'),
            value:trackAnnualGoal,
            onChanged:(v)=>setState(()=>trackAnnualGoal=v)),
          if(trackAnnualGoal)...[
            const SizedBox(height:10),
            Wrap(spacing:8,runSpacing:8,children:[
              for(final period in ['Mensal','Trimestral','Semestral','Anual'])
                ChoiceChip(label:Text(period),selected:balancePeriod==period,
                  onSelected:(_)=>setState(()=>balancePeriod=period)),
            ]),
            const SizedBox(height:14),
            Builder(builder:(context){
              final divisor=balancePeriod=='Mensal'?12:balancePeriod=='Trimestral'?4:
                balancePeriod=='Semestral'?2:1;
              final periodTarget=annualGoal/divisor;
              final progress=periodTarget>0?(received/periodTarget).clamp(0.0,1.0).toDouble():0.0;
              return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                Text('Referência ${balancePeriod.toLowerCase()}: ${DemoData.currency(periodTarget)}',
                  style:const TextStyle(fontWeight:FontWeight.w700)),
                const SizedBox(height:8),
                LinearProgressIndicator(value:progress,minHeight:10,
                  borderRadius:BorderRadius.circular(8)),
                const SizedBox(height:9),
                Wrap(spacing:16,runSpacing:8,children:[
                  Text('Recebido nos lançamentos: ${DemoData.currency(received)}'),
                  Text('Diferença: ${DemoData.currency((periodTarget-received).clamp(0.0,double.infinity).toDouble())}'),
                  Text('Referência anual: ${DemoData.currency(annualGoal)}'),
                ]),
                const SizedBox(height:8),
                const Text('Comparação ilustrativa: os lançamentos não possuem histórico por mês. '
                  'O recebido da sessão não representa necessariamente o período selecionado.',
                  style:TextStyle(fontSize:11,color:Color(0xFF64748B))),
              ]);
            }),
          ] else const Text('Acompanhamento desativado. Ative quando quiser visualizar sua meta.',
            style:TextStyle(fontSize:12,color:Color(0xFF64748B))),
        ]))),
      const SizedBox(height:16),
      LayoutBuilder(builder:(context,constraints){
        final width=constraints.maxWidth;
        final columns=width>=760?4:2;
        const gap=12.0;
        final cardWidth=(width-gap*(columns-1))/columns;
        return Wrap(spacing:gap,runSpacing:gap,children:[
          SizedBox(width:cardWidth,child:_metric('Recebido',received,Icons.check_circle_outline)),
          SizedBox(width:cardWidth,child:_metric('A receber',pending,Icons.trending_up)),
          SizedBox(width:cardWidth,child:_metric('A pagar',expenses,Icons.south_east)),
          SizedBox(width:cardWidth,child:_metric('Saldo realizado',received-paidExpenses,Icons.account_balance_wallet_outlined)),
        ]);
      }),
      const SizedBox(height:20),
      Row(children:[const Expanded(child:Text('Lançamentos e cobranças',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),
        FilledButton.icon(onPressed:add,icon:const Icon(Icons.add),label:const Text('Adicionar'))]),
      const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:[
        for(final option in ['Todos','Receitas','Despesas','Pendentes'])
          ChoiceChip(label:Text(option),selected:filter==option,
            onSelected:(_)=>setState(()=>filter=option)),
      ]),
      const SizedBox(height:12),
      if(visible.isEmpty) const Padding(padding:EdgeInsets.all(20),child:Text('Nenhum lançamento neste filtro.')),
      for(final entry in visible) Card(color:demoSurface,child:Builder(builder:(context) {
        final i=entry.key;
        return ListTile(
        leading:Icon(items[i].type=='Receita'?Icons.arrow_downward:Icons.arrow_upward,color:demoGold),
        title:Text(items[i].name),subtitle:Text('${items[i].type} • ${items[i].paid ? "Pago" : "Pendente"}'),
        trailing:Wrap(crossAxisAlignment:WrapCrossAlignment.center,children:[
          Text(DemoData.currency(items[i].value),style:const TextStyle(color:demoGold)),
          IconButton(tooltip:'Alternar situação de pagamento',icon:Icon(items[i].paid?Icons.check_circle:Icons.radio_button_unchecked),
            onPressed:(){setState((){
              final e=items[i];items[i]=(name:e.name,type:e.type,value:e.value,paid:!e.paid);
            });}),
          IconButton(tooltip:'Excluir lançamento fictício',icon:const Icon(Icons.delete_outline),
            onPressed:()=>deleteEntry(i)),
        ]),
      );
      })),
      const SizedBox(height:10),
      const Text('Demonstração: lançamentos não são cobrados nem salvos em banco.',style:TextStyle(color:Color(0xFF64748B),fontSize:12)),
    ]);
  }
  Widget _metric(String label,double value,IconData icon)=>Container(
    padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(color:demoSurface,borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFF245A98),width:1.5)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:demoGold,size:23),const SizedBox(height:10),
      Text(label,maxLines:2,overflow:TextOverflow.ellipsis,
        style:const TextStyle(fontSize:13,color:Color(0xFF64748B))),
      const SizedBox(height:5),
      FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,
        child:Text(DemoData.currency(value),
          maxLines:1,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold))),
    ]));
}

class DemoMore extends StatefulWidget {
  const DemoMore({super.key});
  @override State<DemoMore> createState()=>_DemoMoreState();
}
class _DemoMoreState extends State<DemoMore> {
  late final pix=TextEditingController(text:DemoLedger.instance.professionalPixKey);
  @override void dispose(){pix.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Card(color:demoSurface,child:ListTile(leading:Icon(Icons.shield_outlined,color:demoGold),
      title:Text('Ambiente de demonstração'),subtitle:Text('Dados temporários e fictícios. Nenhuma cobrança real.'))),
    Card(color:demoSurface,child:Padding(padding:const EdgeInsets.all(14),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Text('Dados para recebimento',style:TextStyle(fontWeight:FontWeight.bold)),
        const SizedBox(height:10),
        TextField(controller:pix,decoration:const InputDecoration(
          labelText:'Sua chave Pix (opcional)',border:OutlineInputBorder())),
        const SizedBox(height:8),
        FilledButton(onPressed:(){
          DemoLedger.instance.setProfessionalPixKey(pix.text);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content:Text('Chave Pix salva na demonstração.')));
        },child:const Text('Salvar chave Pix')),
        const Text('A chave só aparece na cobrança quando preenchida. Dados temporários.',
          style:TextStyle(color:Color(0xFF64748B),fontSize:12)),
      ]))),
    const Card(color:demoSurface,child:ListTile(leading:Icon(Icons.settings_outlined,color:demoGold),
      title:Text('Configurações'),subtitle:Text('A personalização por profissional será conectada ao backend isolado.'))),
    const Card(color:demoSurface,child:ListTile(leading:Icon(Icons.summarize_outlined,color:demoGold),
      title:Text('Relatórios'),subtitle:Text('Indicadores demonstrativos disponíveis em Financeiro.'))),
    const SizedBox(height:12),
    const Text('Coach Flow Profissional • Protótipo Flutter para validação visual e funcional.',style:TextStyle(color:Color(0xFF64748B))),
  ]);
}
