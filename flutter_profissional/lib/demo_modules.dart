import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'demo_mode.dart';

const demoGold = Color(0xFFD8B56A);
const demoSurface = Color(0xFF1A1D22);

class DemoClient {
  DemoClient(this.name, this.service, this.status, this.phone);
  String name, service, status, phone;
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
    final name = TextEditingController(text: current?.name ?? '');
    final service = TextEditingController(text: current?.service ?? '');
    final phone = TextEditingController(text: current?.phone ?? '');
    String status = current?.status ?? 'Em dia';
    final result = await showDialog<bool>(context: context, builder: (context) =>
      StatefulBuilder(builder: (context, refresh) => AlertDialog(
        title: Text(current == null ? 'Novo cliente fictício' : 'Editar cliente'),
        content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome *')),
            TextField(controller: service, decoration: const InputDecoration(labelText: 'Serviço')),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telefone')),
            DropdownButtonFormField<String>(value: status,
              decoration: const InputDecoration(labelText: 'Situação'),
              items: ['Em dia','Pendente'].map((s) => DropdownMenuItem(value:s,child:Text(s))).toList(),
              onChanged: (v) => refresh(() => status = v ?? status)),
          ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(context, true);
          }, child: const Text('Salvar')),
        ],
      )));
    if (result == true && mounted) setState(() {
      if (current == null) {
        clients.add(DemoClient(name.text.trim(),service.text.trim(),status,phone.text.trim()));
      } else {
        current.name=name.text.trim();current.service=service.text.trim();
        current.status=status;current.phone=phone.text.trim();
      }
    });
    name.dispose();service.dispose();phone.dispose();
  }
  @override Widget build(BuildContext context) {
    final term=search.trim().toLowerCase();
    final shown=clients.where((c) =>
      (clientFilter=='Todos' || c.status==clientFilter) &&
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
        for(final option in ['Todos','Em dia','Pendente'])
          ChoiceChip(label:Text(option),selected:clientFilter==option,
            onSelected:(_)=>setState(()=>clientFilter=option)),
      ]),
      const SizedBox(height:14),
      if(shown.isEmpty) const Padding(padding:EdgeInsets.all(24),child:Text('Nenhum cliente encontrado.')),
      for(final c in shown) Card(color:demoSurface,child:ListTile(
        leading:const CircleAvatar(backgroundColor:Color(0xFF383124),child:Icon(Icons.person,color:demoGold)),
        title:Text(c.name),subtitle:Text('${c.service} • ${c.phone}'),
        trailing:Wrap(crossAxisAlignment:WrapCrossAlignment.center,spacing:4,children:[
          Text(c.status,style:const TextStyle(color:demoGold,fontSize:12)),
          IconButton(tooltip:'Abrir WhatsApp',onPressed:()=>openWhatsApp(c),icon:const Icon(Icons.chat_outlined,color:Color(0xFF25D366))),
          if(c.status=='Pendente') IconButton(tooltip:'Preparar cobrança pelo WhatsApp',onPressed:()=>openBillingWhatsApp(c),icon:const Icon(Icons.request_quote_outlined,color:demoGold)),
          IconButton(tooltip:'Editar cliente',onPressed:()=>edit(c),icon:const Icon(Icons.edit_outlined)),
          IconButton(tooltip:'Excluir cliente fictício',onPressed:()=>deleteClient(c),icon:const Icon(Icons.delete_outline)),
        ]),
      )),
      const SizedBox(height:12),
      const Text('Os cadastros são temporários: serão descartados ao atualizar a página.',style:TextStyle(color:Colors.white60,fontSize:12)),
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
      Wrap(spacing:12,runSpacing:12,children:[
        _metric('Recebido',received,Icons.check_circle_outline),
        _metric('A receber',pending,Icons.trending_up),
        _metric('A pagar',expenses,Icons.south_east),
        _metric('Saldo realizado',received-paidExpenses,Icons.account_balance_wallet_outlined),
      ]),
      const SizedBox(height:16),
      Card(color:demoSurface,child:Padding(padding:const EdgeInsets.all(18),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Expanded(child:Text('Meta anual de recebimentos',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),
          TextButton.icon(onPressed:editAnnualGoal,icon:const Icon(Icons.edit_outlined),label:const Text('Definir meta'))]),
        if(annualGoal>0) ...[
          Text('${DemoData.currency(received)} de ${DemoData.currency(annualGoal)}',style:const TextStyle(color:demoGold)),
          const SizedBox(height:10),
          LinearProgressIndicator(value:(received/annualGoal).clamp(0.0,1.0),minHeight:9),
          const SizedBox(height:10),
          Wrap(spacing:16,runSpacing:8,children:[
            Text('Realizado: ${(received/annualGoal*100).toStringAsFixed(1)}%'),
            Text('Faltam: ${DemoData.currency((annualGoal-received).clamp(0.0,double.infinity))}'),
            Text('Referência mensal: ${DemoData.currency(annualGoal/12)}'),
            Text('Referência trimestral: ${DemoData.currency(annualGoal/4)}'),
          ]),
        ] else const Text('Defina uma meta anual para acompanhar o progresso da demonstração.'),
      ]))),
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
            onPressed:()=>setState(()=>items.removeAt(i))),
        ]),
      );
      })),
      const SizedBox(height:10),
      const Text('Demonstração: lançamentos não são cobrados nem salvos em banco.',style:TextStyle(color:Colors.white60,fontSize:12)),
    ]);
  }
  Widget _metric(String label,double value,IconData icon)=>Container(
    width:210,padding:const EdgeInsets.all(18),
    decoration:BoxDecoration(color:demoSurface,borderRadius:BorderRadius.circular(18),border:Border.all(color:Colors.white24)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:demoGold),const SizedBox(height:12),Text(label),
      Text(DemoData.currency(value),style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
    ]));
}

class DemoMore extends StatelessWidget {
  const DemoMore({super.key});
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Card(color:demoSurface,child:ListTile(leading:Icon(Icons.shield_outlined,color:demoGold),
      title:Text('Ambiente de demonstração'),subtitle:Text('Dados temporários e fictícios. Nenhuma cobrança real.'))),
    const Card(color:demoSurface,child:ListTile(leading:Icon(Icons.settings_outlined,color:demoGold),
      title:Text('Configurações'),subtitle:Text('A personalização por profissional será conectada ao backend isolado.'))),
    const Card(color:demoSurface,child:ListTile(leading:Icon(Icons.summarize_outlined,color:demoGold),
      title:Text('Relatórios'),subtitle:Text('Indicadores demonstrativos disponíveis em Financeiro.'))),
    const SizedBox(height:12),
    const Text('Coach Flow Profissional • Protótipo Flutter para validação visual e funcional.',style:TextStyle(color:Colors.white60)),
  ]);
}
