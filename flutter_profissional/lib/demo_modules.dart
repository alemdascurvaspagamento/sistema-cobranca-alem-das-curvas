import 'package:flutter/material.dart';
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
    final shown=clients.where((c)=>c.name.toLowerCase().contains(search.toLowerCase())).toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Wrap(alignment:WrapAlignment.spaceBetween,runSpacing:12,children:[
        Text('${clients.length} clientes fictícios',style:const TextStyle(color:demoGold,fontSize:16)),
        FilledButton.icon(onPressed:()=>edit(),icon:const Icon(Icons.person_add_alt_1),label:const Text('Novo cliente')),
      ]),
      const SizedBox(height:14),
      TextField(onChanged:(v)=>setState(()=>search=v),decoration:const InputDecoration(
        prefixIcon:Icon(Icons.search),labelText:'Pesquisar clientes',border:OutlineInputBorder())),
      const SizedBox(height:14),
      if(shown.isEmpty) const Padding(padding:EdgeInsets.all(24),child:Text('Nenhum cliente encontrado.')),
      for(final c in shown) Card(color:demoSurface,child:ListTile(
        leading:const CircleAvatar(backgroundColor:Color(0xFF383124),child:Icon(Icons.person,color:demoGold)),
        title:Text(c.name),subtitle:Text('${c.service} • ${c.phone}'),
        trailing:Wrap(crossAxisAlignment:WrapCrossAlignment.center,spacing:4,children:[
          Text(c.status,style:const TextStyle(color:demoGold,fontSize:12)),
          IconButton(tooltip:'Editar cliente',onPressed:()=>edit(c),icon:const Icon(Icons.edit_outlined)),
          IconButton(tooltip:'Excluir cliente fictício',onPressed:()=>setState(()=>clients.remove(c)),icon:const Icon(Icons.delete_outline)),
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
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Wrap(spacing:12,runSpacing:12,children:[
        _metric('Recebido',received,Icons.check_circle_outline),
        _metric('A receber',pending,Icons.trending_up),
        _metric('A pagar',expenses,Icons.south_east),
      ]),
      const SizedBox(height:20),
      Row(children:[const Expanded(child:Text('Lançamentos e cobranças',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),
        FilledButton.icon(onPressed:add,icon:const Icon(Icons.add),label:const Text('Adicionar'))]),
      const SizedBox(height:12),
      for(var i=0;i<items.length;i++) Card(color:demoSurface,child:ListTile(
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
      )),
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
