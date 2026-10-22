import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fluxo demonstrativo local. Não é uma API pública de agendamentos.
/// Solicitações feitas em outro navegador não chegam ao profissional.
class BookingRequest {
  BookingRequest({required this.id,required this.name,required this.contact,
    required this.service,required this.day,required this.time});
  final String id,name,contact,service,time;
  final DateTime day;
  String status='Pendente';
}

class BookingDemoStore extends ChangeNotifier {
  BookingDemoStore._();
  static final instance=BookingDemoStore._();
  final List<BookingRequest> requests=[];
  final Set<String> blocked={};
  final Map<String,int> durations={'Conversa inicial':30,'Treino individual':60,'Reposição':60};
  final Set<int> weekdays={1,2,3,4,5};
  final List<String> slots=['08:00','09:00','10:00','11:00','14:00','15:00','16:00','17:00'];
  String key(DateTime day,String time)=>'${day.year}-${day.month}-${day.day}-$time';
  bool available(DateTime day,String time){
    final date=DateUtils.dateOnly(day);
    if(date.isBefore(DateUtils.dateOnly(DateTime.now()))||!weekdays.contains(date.weekday))return false;
    if(blocked.contains(key(date,time)))return false;
    if(requests.any((r)=>DateUtils.isSameDay(r.day,date)&&r.time==time&&r.status=='Aprovado'))return false;
    return true;
  }
  String? request(String name,String contact,String service,DateTime day,String time){
    if(name.trim().length<2||contact.trim().length<5)return 'Preencha nome e contato.';
    if(!durations.containsKey(service)||!slots.contains(time)||!available(day,time)){
      return 'Este horário não está mais disponível.';
    }
    if(requests.any((r)=>r.name.trim().toLowerCase()==name.trim().toLowerCase()&&
      DateUtils.isSameDay(r.day,day)&&r.time==time&&r.status=='Pendente')){
      return 'Já existe uma solicitação pendente para esse horário.';
    }
    requests.insert(0,BookingRequest(id:DateTime.now().microsecondsSinceEpoch.toString(),
      name:name.trim(),contact:contact.trim(),service:service,day:day,time:time));
    notifyListeners();
    return null;
  }
  bool decide(BookingRequest r,String status){
    if(status=='Aprovado'&&!available(r.day,r.time))return false;
    r.status=status;
    notifyListeners();
    return true;
  }
}

class BookingPublicDemo extends StatefulWidget {
  const BookingPublicDemo({super.key});
  @override State<BookingPublicDemo> createState()=>_BookingPublicDemoState();
}
class _BookingPublicDemoState extends State<BookingPublicDemo> {
  final name=TextEditingController(),contact=TextEditingController();
  String service='Conversa inicial';
  DateTime day=DateUtils.dateOnly(DateTime.now().add(const Duration(days:1)));
  String? time;
  @override void dispose(){name.dispose();contact.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final store=BookingDemoStore.instance;
    final available=store.slots.where((s)=>store.available(day,s)).toList();
    return Scaffold(backgroundColor:const Color(0xFFEAF4FC),
      appBar:AppBar(title:const Text('Solicitar horário • Demonstração'),
        backgroundColor:const Color(0xFF0C213A),foregroundColor:Colors.white),
      body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:580),
        child:ListView(padding:const EdgeInsets.all(16),children:[
          Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(
            crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            const Text('Agende um horário',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800)),
            const SizedBox(height:5),
            const Text('Escolha uma opção. O profissional precisa aprovar sua solicitação.'),
            const SizedBox(height:10),
            const Text('DEMONSTRAÇÃO LOCAL • Não envia solicitações reais.',
              style:TextStyle(color:Color(0xFF9D5420),fontSize:11)),
            const SizedBox(height:18),
            DropdownButtonFormField<String>(value:service,
              decoration:const InputDecoration(labelText:'Tipo de atendimento',border:OutlineInputBorder()),
              items:[for(final e in store.durations.entries)DropdownMenuItem(
                value:e.key,child:Text('${e.key} • ${e.value} min'))],
              onChanged:(v)=>setState(()=>service=v??service)),
            const SizedBox(height:12),
            OutlinedButton.icon(onPressed:()async{
              final picked=await showDatePicker(context:context,initialDate:day,
                firstDate:DateUtils.dateOnly(DateTime.now()),
                lastDate:DateTime.now().add(const Duration(days:90)));
              if(picked!=null)setState((){day=picked;time=null;});
            },icon:const Icon(Icons.calendar_month),
              label:Text('${day.day.toString().padLeft(2,'0')}/${day.month.toString().padLeft(2,'0')}/${day.year}')),
            const SizedBox(height:12),
            const Text('Horários disponíveis',style:TextStyle(fontWeight:FontWeight.w700)),
            const SizedBox(height:8),
            if(available.isEmpty)const Text('Nenhum horário disponível nesta data.')
            else Wrap(spacing:8,runSpacing:8,children:[
              for(final slot in available)ChoiceChip(label:Text(slot),
                selected:time==slot,onSelected:(_)=>setState(()=>time=slot)),
            ]),
            const SizedBox(height:16),
            TextField(controller:name,decoration:const InputDecoration(
              labelText:'Seu nome',border:OutlineInputBorder())),
            const SizedBox(height:10),
            TextField(controller:contact,keyboardType:TextInputType.emailAddress,
              decoration:const InputDecoration(labelText:'E-mail ou WhatsApp para retorno',
                border:OutlineInputBorder())),
            const SizedBox(height:16),
            FilledButton.icon(onPressed:time==null?null:(){
              final error=store.request(name.text,contact.text,service,day,time!);
              if(error!=null){
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(error)));
              }else{
                showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
                  title:const Text('Solicitação registrada na demonstração'),
                  content:const Text('Status: pendente de aprovação. '
                    'Este registro existe somente nesta sessão do navegador.'),
                  actions:[TextButton(onPressed:()=>Navigator.pop(ctx),
                    child:const Text('Entendi'))]));
              }
            },icon:const Icon(Icons.send_outlined),label:const Text('Solicitar horário')),
          ]))),
        ]))));
  }
}

class BookingManagementDemo extends StatefulWidget {
  const BookingManagementDemo({super.key});
  @override State<BookingManagementDemo> createState()=>_BookingManagementDemoState();
}
class _BookingManagementDemoState extends State<BookingManagementDemo>{
  final store=BookingDemoStore.instance;
  @override void initState(){super.initState();store.addListener(_refresh);}
  void _refresh(){if(mounted)setState((){});}
  @override void dispose(){store.removeListener(_refresh);super.dispose();}
  @override Widget build(BuildContext context)=>Column(
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Link de agendamento',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
      const SizedBox(height:6),
      const Text('Conversa inicial, treino e reposição. Aprovação manual antes da confirmação.'),
      const SizedBox(height:8),
      const Text('Esta versão é uma simulação local: compartilhar o endereço não '
        'entrega pedidos entre dispositivos. A publicação do link real exige '
        'o serviço de agendamentos e autenticação do profissional.',
        style:TextStyle(fontSize:11,color:Color(0xFF9D5420))),
      const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:[
        OutlinedButton.icon(onPressed:()=>Navigator.of(context).push(
          MaterialPageRoute(builder:(_)=>const BookingPublicDemo())),
          icon:const Icon(Icons.open_in_new),label:const Text('Testar página do cliente')),
        OutlinedButton.icon(onPressed:(){
          final link=Uri.base.replace(queryParameters:{'agendar':'demo'}).toString();
          Clipboard.setData(ClipboardData(text:link));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:Text('Link de teste copiado. Não recebe pedidos reais.')));
        },icon:const Icon(Icons.copy),label:const Text('Copiar link de teste')),
      ]),
    ]))),
    const SizedBox(height:12),
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('Solicitações recebidas nesta sessão',
        style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
      const SizedBox(height:10),
      if(store.requests.isEmpty)const Padding(padding:EdgeInsets.all(12),
        child:Text('Nenhuma solicitação nesta demonstração. '
          'Use “Testar página do cliente” para simular uma.')),
      for(final r in store.requests)...[
        const Divider(),
        Text(r.name,style:const TextStyle(fontWeight:FontWeight.w700)),
        Text('${r.service} • ${r.day.day}/${r.day.month} às ${r.time}'),
        Text('Contato: ${r.contact} • ${r.status}'),
        if(r.status=='Pendente')Wrap(spacing:8,children:[
          TextButton.icon(onPressed:(){
            if(!store.decide(r,'Aprovado'))ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content:Text('Horário indisponível.')));
          },icon:const Icon(Icons.check),label:const Text('Aprovar')),
          TextButton.icon(onPressed:()=>store.decide(r,'Recusado'),
            icon:const Icon(Icons.close),label:const Text('Recusar')),
        ]),
      ],
    ]))),
  ]);
}
