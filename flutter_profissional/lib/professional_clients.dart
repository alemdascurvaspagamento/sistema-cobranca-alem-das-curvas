import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'professional_repository.dart';

class ProfessionalClients extends StatefulWidget {
  const ProfessionalClients({super.key});
  @override State<ProfessionalClients> createState()=>_ProfessionalClientsState();
}
class _ProfessionalClientsState extends State<ProfessionalClients> {
  static const gold=Color(0xFF0C213A);
  late final repository=ProfessionalRepository(Supabase.instance.client);
  late Future<List<Map<String,dynamic>>> future=_load();
  Future<List<Map<String,dynamic>>> _load()=>repository.clients();
  void refresh()=>setState(()=>future=_load());

  Future<void> edit([Map<String,dynamic>? current]) async {
    final name=TextEditingController(text:current?['name']?.toString()??'');
    final service=TextEditingController(text:current?['service']?.toString()??'');
    final phone=TextEditingController(text:current?['phone']?.toString()??'');
    var status=current?['status']?.toString()??'Em dia';
    try {
      final accepted=await showDialog<bool>(context:context,builder:(context)=>
        StatefulBuilder(builder:(context,setDialog)=>AlertDialog(
          title:Text(current==null?'Novo cliente':'Editar cliente'),
          content:SizedBox(width:380,child:SingleChildScrollView(
            child:Column(mainAxisSize:MainAxisSize.min,children:[
              TextField(controller:name,decoration:const InputDecoration(labelText:'Nome')),
              TextField(controller:service,decoration:const InputDecoration(labelText:'Serviço')),
              TextField(controller:phone,keyboardType:TextInputType.phone,
                decoration:const InputDecoration(labelText:'Telefone')),
              DropdownButtonFormField<String>(value:status,
                items:['Em dia','Pendente'].map((x)=>DropdownMenuItem(
                  value:x,child:Text(x))).toList(),
                onChanged:(x)=>setDialog(()=>status=x??status)),
            ]))),
          actions:[TextButton(onPressed:()=>Navigator.pop(context,false),
            child:const Text('Cancelar')),
            FilledButton(onPressed:()=>Navigator.pop(context,true),
              child:const Text('Salvar'))],
        )));
      if(accepted==true){
        await repository.saveClient(id:current?['id']?.toString(),
          name:name.text,service:service.text,phone:phone.text,status:status);
        refresh();
      }
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Não foi possível salvar. Confira os campos e a conexão.')));
    } finally {name.dispose();service.dispose();phone.dispose();}
  }
  Future<void> remove(Map<String,dynamic> item) async {
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Excluir cliente?'),
      content:Text('Excluir ${item['name']} e os atendimentos vinculados?'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Excluir'))]));
    if(ok!=true)return;
    try{await repository.deleteClient(item['id'].toString());refresh();}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content:Text('Não foi possível excluir o cliente.')));}
  }

  @override Widget build(BuildContext context)=>Column(
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[
        const Expanded(child:Text('Clientes',style:TextStyle(
          fontSize:23,fontWeight:FontWeight.w800))),
        FilledButton.icon(onPressed:()=>edit(),icon:const Icon(Icons.add),
          label:const Text('Novo')),
      ]),
      const SizedBox(height:12),
      FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(context,snapshot){
        if(snapshot.connectionState!=ConnectionState.done)
          return const Center(child:CircularProgressIndicator());
        if(snapshot.hasError)return Column(children:[
          const Text('Não foi possível carregar os clientes. Verifique a configuração do banco exclusivo.'),
          TextButton(onPressed:refresh,child:const Text('Tentar novamente')),
        ]);
        final clients=snapshot.data??[];
        if(clients.isEmpty)return const Padding(padding:EdgeInsets.all(24),
          child:Text('Nenhum cliente cadastrado. Use Novo para começar.'));
        return Column(children:[
          for(final item in clients) Card(
            color:const Color(0xFFFFFFFF),
            margin:const EdgeInsets.only(bottom:10),
            child:Padding(padding:const EdgeInsets.all(14),child:Column(
              crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  const CircleAvatar(backgroundColor:Color(0xFFFFF4DE),
                    child:Icon(Icons.person,color:gold)),
                  const SizedBox(width:10),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      Text(item['name']?.toString()??'',maxLines:2,
                        overflow:TextOverflow.ellipsis,
                        style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
                      Text(item['service']?.toString()??'',
                        maxLines:2,overflow:TextOverflow.ellipsis),
                      Text(item['phone']?.toString()??'',
                        maxLines:1,overflow:TextOverflow.ellipsis),
                    ])),
                  const SizedBox(width:8),
                  Text(item['status']?.toString()??'',style:const TextStyle(
                    color:gold,fontSize:11)),
                ]),
                const Divider(height:22),
                Row(children:[
                  Expanded(child:OutlinedButton.icon(onPressed:()=>edit(item),
                    icon:const Icon(Icons.edit_outlined,size:17),
                    label:const Text('Editar'))),
                  const SizedBox(width:10),
                  Expanded(child:OutlinedButton.icon(onPressed:()=>remove(item),
                    icon:const Icon(Icons.delete_outline,size:17),
                    label:const Text('Excluir'))),
                ]),
              ]))),
        ]);
      }),
    ]);
}
