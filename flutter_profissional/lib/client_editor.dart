import 'package:flutter/material.dart';
import 'profession_terms.dart';

/// Cadastro demonstrativo, sem persistência ou acesso a dados reais.
class ClientProfile {
  ClientProfile({
    required this.name, required this.service, required this.phone,
    required this.status, this.email='', this.profession='Personal trainer',
    this.plan='', this.goal='', this.notes='', this.pixKey='',
    this.startDate='', this.birthDate='', this.weekdays='',
    this.schedule='', this.duration='60', this.rate='', this.dueDay='5',
    this.billingCycle='Mensal', this.paymentMethod='Pix',
  });
  String name, service, phone, status, email, profession, plan, goal, notes,
    pixKey, startDate, birthDate, weekdays, schedule, duration, rate,
    dueDay, billingCycle, paymentMethod;
}

class ClientEditor extends StatefulWidget {
  const ClientEditor({super.key, this.initial});
  final ClientProfile? initial;
  @override
  State<ClientEditor> createState()=>_ClientEditorState();
}

class _ClientEditorState extends State<ClientEditor> with SingleTickerProviderStateMixin {
  late final TabController tabs;
  late final Map<String,TextEditingController> fields;
  late String profession, status, cycle, method;
  String? error;
  static const days=['SEG','TER','QUA','QUI','SEX','SÁB','DOM'];
  final selectedDays=<String>{};
  final dayTimes=<String,String>{};
  static const professions=ProfessionTerms.professions;
  static const keys=['name','service','phone','email','plan','goal','notes','pixKey',
    'startDate','birthDate','weekdays','schedule','duration','rate','dueDay'];
  @override void initState(){
    super.initState();
    tabs=TabController(length:4,vsync:this);
    final p=widget.initial;
    final values=<String,String>{
      'name':p?.name??'', 'service':p?.service??'', 'phone':p?.phone??'',
      'email':p?.email??'', 'plan':p?.plan??'', 'goal':p?.goal??'',
      'notes':p?.notes??'', 'pixKey':p?.pixKey??'', 'startDate':p?.startDate??'',
      'birthDate':p?.birthDate??'', 'weekdays':p?.weekdays??'',
      'schedule':p?.schedule??'', 'duration':p?.duration??'60',
      'rate':p?.rate??'', 'dueDay':p?.dueDay??'5',
    };
    fields={for(final key in keys)key:TextEditingController(text:values[key])};
    selectedDays.addAll((p?.weekdays??'').split(',').map((e)=>e.trim()).where(days.contains));
    for(final part in (p?.schedule??'').split(';')){
      final entry=part.trim().split(' ');
      if(entry.length>=2&&days.contains(entry.first))dayTimes[entry.first]=entry.last;
    }
    profession=professions.contains(p?.profession)?p!.profession:professions.first;
    status=p?.status??'Em dia';
    cycle=p?.billingCycle??'Mensal';
    method=p?.paymentMethod??'Pix';
  }
  @override void dispose(){
    tabs.dispose();
    for(final controller in fields.values){controller.dispose();}
    super.dispose();
  }
  Widget field(String key,String label,{String? hint,int lines=1,TextInputType? type}){
    return TextField(controller:fields[key],maxLines:lines,keyboardType:type,
      decoration:InputDecoration(labelText:label,hintText:hint,
        border:const OutlineInputBorder(),isDense:true));
  }
  Widget dropdown(String label,String value,List<String> options,ValueChanged<String> onChange){
    return DropdownButtonFormField<String>(
      value:options.contains(value)?value:options.first,
      isExpanded:true,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),
      items:[for(final option in options)DropdownMenuItem(value:option,child:Text(option))],
      onChanged:(next){if(next!=null)setState(()=>onChange(next));});
  }
  Future<void> chooseTime(String day) async {
    final parts=(dayTimes[day]??'09:00').split(':');
    final initial=TimeOfDay(hour:int.tryParse(parts.first)??9,
      minute:parts.length>1?(int.tryParse(parts[1])??0):0);
    final chosen=await showTimePicker(context:context,initialTime:initial,
      builder:(ctx,child)=>MediaQuery(data:MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat:true),child:child!));
    if(chosen!=null)setState(()=>dayTimes[day]='${chosen.hour.toString().padLeft(2,'0')}:${chosen.minute.toString().padLeft(2,'0')}');
  }
  Widget section(List<Widget> children)=>SingleChildScrollView(
    padding:const EdgeInsets.symmetric(vertical:18,horizontal:4),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      for(final child in children)...[child,const SizedBox(height:14)],
    ]));
  @override Widget build(BuildContext context){
    final sessionLabel=ProfessionTerms.appointment(profession);
    final clientLabel=ProfessionTerms.client(profession);
    return Dialog(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:740,maxHeight:740),
      child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text(widget.initial==null?'Novo cliente':'Editar cliente',
            style:Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height:5),
          const Text('Cadastro adaptável por profissão • demonstração sem dados persistentes',
            style:TextStyle(color:Color(0xFF64748B),fontSize:12)),
          const SizedBox(height:14),
          TabBar(controller:tabs,isScrollable:true,tabs:const [
            Tab(icon:Icon(Icons.person_outline),text:'Dados'),
            Tab(icon:Icon(Icons.calendar_month_outlined),text:'Agenda'),
            Tab(icon:Icon(Icons.account_balance_wallet_outlined),text:'Financeiro'),
            Tab(icon:Icon(Icons.history),text:'Histórico'),
          ]),
          Expanded(child:TabBarView(controller:tabs,children:[
            section([
              field('name','Nome completo *'),
              Text('Neste perfil: $clientLabel • $sessionLabel',
                style:const TextStyle(color:Color(0xFF0C213A),fontSize:12)),
              field('service','Serviço / $sessionLabel',hint:'Descreva o serviço oferecido'),
              field('phone','Telefone / WhatsApp',hint:'(11) 99999-9999',
                type:TextInputType.phone),
              field('email','E-mail',type:TextInputType.emailAddress),
              field('birthDate','Data de nascimento',hint:'dd/mm/aaaa'),
              field('startDate','Início do acompanhamento',hint:'dd/mm/aaaa'),
              field('goal','Objetivo',hint:'Objetivo do cliente'),
              field('notes','Observações',lines:3),
              dropdown('Situação',status,['Em dia','Pendente'],(v)=>status=v),
            ]),
            section([
              Text('Agenda • $sessionLabel',style:Theme.of(context).textTheme.titleMedium),
              const Text('Dias fixos • selecione um ou mais dias'),
              Wrap(spacing:7,runSpacing:7,children:[
                for(final day in days)FilterChip(
                  label:Text(day),selected:selectedDays.contains(day),
                  selectedColor:const Color(0xFF0C213A),
                  checkmarkColor:Colors.black,
                  onSelected:(active)=>setState((){
                    if(active){selectedDays.add(day);}else{selectedDays.remove(day);dayTimes.remove(day);}
                  })),
              ]),
              if(selectedDays.isNotEmpty)...[
                const Text('Horários por dia • toque para escolher'),
                for(final day in days.where(selectedDays.contains))
                  OutlinedButton.icon(
                    onPressed:()=>chooseTime(day),
                    icon:const Icon(Icons.access_time),
                    label:Text('$day  •  ${dayTimes[day]??'Selecionar horário'}')),
              ],

              field('duration','Duração em minutos',type:TextInputType.number),
              const Text('Datas, recorrências e remarcações serão integradas à agenda real em etapa posterior.',
                style:TextStyle(color:Color(0xFF64748B))),
            ]),
            section([
              field('plan','Plano',hint:'Ex.: 2x por semana'),
              field('rate','Valor por $sessionLabel (R\$)',type:const TextInputType.numberWithOptions(decimal:true)),
              dropdown('Periodicidade',cycle,['Por atendimento','Semanal','Mensal','Trimestral','Anual'],(v)=>cycle=v),
              field('dueDay','Dia de vencimento',type:TextInputType.number),
              dropdown('Forma de pagamento',method,['Pix','Transferência','Dinheiro','Cartão','Boleto','Outro'],(v)=>method=v),
              field('pixKey','Chave Pix'),
              const Text('Valores informativos. Nenhuma cobrança ou pagamento é executado.',
                style:TextStyle(color:Color(0xFF64748B))),
            ]),
            section([
              const ListTile(leading:Icon(Icons.history),
                title:Text('Histórico de atendimentos'),
                subtitle:Text('Disponível após integração da agenda e do banco de dados.')),
              const ListTile(leading:Icon(Icons.receipt_long_outlined),
                title:Text('Histórico financeiro'),
                subtitle:Text('Pagamentos, cobranças e alterações serão registrados por profissional.')),
              const ListTile(leading:Icon(Icons.lock_outline),
                title:Text('Privacidade'),
                subtitle:Text('O protótipo não consulta dados do Coach Flow Pessoal.')),
            ]),
          ])),
          if(error!=null) Padding(padding:const EdgeInsets.only(bottom:8),
            child:Text(error!,style:const TextStyle(color:Colors.redAccent))),
          Row(mainAxisAlignment:MainAxisAlignment.end,children:[
            TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancelar')),
            const SizedBox(width:8),
            FilledButton.icon(icon:const Icon(Icons.save_outlined),label:const Text('Salvar cadastro'),
              onPressed:(){
                if(fields['name']!.text.trim().isEmpty){
                  setState(()=>error='Informe o nome completo.');
                  tabs.animateTo(0);
                  return;
                }
                final phone=fields['phone']!.text.replaceAll(RegExp(r'[^0-9]'),'');
                if(phone.isNotEmpty && phone.length!=10 && phone.length!=11 &&
                    phone.length!=12 && phone.length!=13){
                  setState(()=>error='Informe um WhatsApp válido com DDD.');
                  tabs.animateTo(0);
                  return;
                }
                String v(String key)=>fields[key]!.text.trim();
                Navigator.pop(context,ClientProfile(
                  name:v('name'),service:v('service'),phone:v('phone'),status:status,
                  profession:profession,email:v('email'),plan:v('plan'),goal:v('goal'),
                  notes:v('notes'),pixKey:v('pixKey'),startDate:v('startDate'),
                  birthDate:v('birthDate'),weekdays:days.where(selectedDays.contains).join(', '),
                  schedule:days.where(selectedDays.contains).map((d)=>'$d ${dayTimes[d]??'09:00'}').join('; '),
                  duration:v('duration'),rate:v('rate'),dueDay:v('dueDay'),
                  billingCycle:cycle,paymentMethod:method,
                ));
              }),
          ]),
        ]))));
  }
}
