import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'demo_mode.dart';
import 'demo_ledger.dart';

/// Painel visual demonstrativo. Não confundir agenda prevista com receita recebida.
class ProfessionalDashboard extends StatefulWidget {
  const ProfessionalDashboard({super.key, required this.demo,
    required this.onClients, required this.onAgenda, required this.onBilling,
    required this.onFinance,required this.onSecretary});
  final bool demo;
  final VoidCallback onClients, onAgenda, onBilling, onFinance, onSecretary;

  @override State<ProfessionalDashboard> createState()=>_ProfessionalDashboardState();
}

class _ProfessionalDashboardState extends State<ProfessionalDashboard> {
  late int selectedMonth=DateTime.now().month;
  DateTime _localNow = DateTime.now();
  Timer? _greetingTimer;

  @override
  void initState() {
    super.initState();
    _greetingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && DateTime.now().hour != _localNow.hour) {
        setState(() => _localNow = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
    super.dispose();
  }

  String get _greeting {
    final hour = _localNow.hour;
    if (hour >= 5 && hour < 12) return 'Bom dia';
    if (hour >= 12 && hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String? get _firstName {
    if (widget.demo) return null;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final raw = metadata['full_name'] ?? metadata['name'] ?? metadata['display_name'];
    if (raw is! String || raw.trim().isEmpty) return null;
    return raw.trim().split(RegExp(r'\s+')).first;
  }

  String get _welcome {
    final name = _firstName;
    return name == null ? '$_greeting! 👋' : '$_greeting, $name! 👋';
  }

  late int selectedYear=DateTime.now().year;
  String _goalPeriod='Mensal';
  static const ink = Color(0xFF132238);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFF245A98);
  static const background = Color(0xFFEDF2F8);
  static const green = Color(0xFF29856F);
  static const amber = Color(0xFFE4A11B);
  static const red = Color(0xFFE36C4A);

  Future<void> _notDone(BuildContext context,DemoAppointment a,DateTime day) async {
    final reason=await showModalBottomSheet<String>(context:context,
      builder:(ctx)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const ListTile(title:Text('Atendimento não realizado'),
          subtitle:Text('Selecione o motivo e a regra de cobrança')),
        for(final choice in const [
          ('Cliente cancelou • sem cobrança','cliente-sem'),
          ('Cliente cancelou • com cobrança','cliente-com'),
          ('Profissional cancelou • sem cobrança','profissional'),
          ('Falta do cliente • com cobrança','falta'),
          ('Remarcar atendimento','remarcar'),
        ])ListTile(title:Text(choice.$1),
          onTap:()=>Navigator.pop(ctx,choice.$2)),
      ])));
    if(reason==null)return;
    final charge=reason=='cliente-com'||reason=='falta';
    DemoLedger.instance.updateVisit(a.client,day,
      reason=='remarcar'?'Remarcada':'Cancelada',charge,reason);
    if(reason=='remarcar')widget.onAgenda();
  }
  Future<void> _confirmAppointment(DemoAppointment a,DateTime day) async {
    final ledger=DemoLedger.instance;
    final phone=ledger.clientPhones[a.client]?.replaceAll(RegExp(r'[^0-9]'),'')??'';
    final validPhone=phone.length==12||phone.length==13;
    final date='${day.day.toString().padLeft(2,'0')}/'
      '${day.month.toString().padLeft(2,'0')}/${day.year}';
    final template=TextEditingController(text:ledger.confirmationTemplate);
    final result=await showModalBottomSheet<String>(
      context:context,isScrollControlled:true,useSafeArea:true,
      builder:(sheetContext)=>Padding(
        padding:EdgeInsets.only(
          bottom:MediaQuery.viewInsetsOf(sheetContext).bottom),
        child:SingleChildScrollView(child:Padding(
          padding:const EdgeInsets.all(20),
          child:Column(mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Row(children:[
              const Icon(Icons.chat_outlined,color:Color(0xFF128C4B)),
              const SizedBox(width:10),
              Expanded(child:Text('Confirmar • ${a.client}',
                style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800))),
              IconButton(onPressed:()=>Navigator.pop(sheetContext),
                icon:const Icon(Icons.close)),
            ]),
            const SizedBox(height:7),
            Text('$date • ${a.hour} • ${a.service}',
              style:const TextStyle(color:muted,fontSize:12)),
            const SizedBox(height:12),
            TextField(controller:template,minLines:5,maxLines:9,
              decoration:const InputDecoration(
                labelText:'Modelo de mensagem (editável)',
                helperText:'Campos: {nome}, {data}, {hora}, {servico}',
                helperMaxLines:2,border:OutlineInputBorder())),
            const SizedBox(height:12),
            if(!validPhone)const Text(
              'Telefone de WhatsApp não disponível. Confira o cadastro do cliente.',
              style:TextStyle(color:red,fontSize:12)),
            const Text('O WhatsApp será aberto com a mensagem preenchida. '
              'O envio e a confirmação do cliente não são automáticos.',
              style:TextStyle(color:muted,fontSize:12)),
            const SizedBox(height:14),
            FilledButton.icon(onPressed:validPhone?
              ()=>Navigator.pop(sheetContext,template.text):null,
              style:FilledButton.styleFrom(
                backgroundColor:const Color(0xFF128C4B),
                minimumSize:const Size.fromHeight(48)),
              icon:const Icon(Icons.open_in_new),
              label:const Text('Revisar e abrir WhatsApp')),
          ])),
        )));
    template.dispose();
    if(result==null||!mounted)return;
    ledger.setConfirmationTemplate(result);
    var message=result;
    final variables={
      '{nome}':a.client,'{data}':date,
      '{hora}':a.hour,'{servico}':a.service,
    };
    for(final item in variables.entries){
      message=message.replaceAll(item.key,item.value);
    }
    final approved=await showDialog<bool>(context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Revisar mensagem'),
        content:SizedBox(width:440,child:SingleChildScrollView(
          child:SelectableText(message))),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Voltar')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Abrir WhatsApp')),
        ]));
    if(approved!=true||!mounted)return;
    final url=Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    if(!await launchUrl(url,mode:LaunchMode.externalApplication)&&mounted){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Não foi possível abrir o WhatsApp.')));
    }
  }

  Future<void> _editConfirmationStatus(DemoAppointment a,DateTime day) async {
    final ledger=DemoLedger.instance;
    final selected=await showModalBottomSheet<String>(
      context:context,builder:(ctx)=>SafeArea(
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          ListTile(title:Text('Confirmação • ${a.client}'),
            subtitle:const Text('Marcação manual, independente da realização.')),
          for(final status in ['Aguardando','Confirmado','Solicitou remarcação'])
            ListTile(
              leading:Icon(status=='Confirmado'?Icons.check_circle_outline:
                status=='Solicitou remarcação'?Icons.edit_calendar_outlined:
                Icons.schedule_outlined),
              title:Text(status),
              onTap:()=>Navigator.pop(ctx,status)),
        ])));
    if(selected!=null)ledger.setConfirmationStatus(a.client,day,selected);
  }

  Widget panel(Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Color(0xFFFFFFFF),
      border: Border.all(color: border, width: 1.5),
      borderRadius: BorderRadius.circular(16)),
    child: child);

  Widget stat(String label, String value, String detail, IconData icon, Color accent) =>
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 19, color: accent)),
          const Spacer(),
        ]),
        Text(label.toUpperCase(), style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700, color: muted)),
        FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,
          child:Text(value, maxLines:1, style: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: ink))),
        Text(detail, maxLines: 2, overflow:TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: muted)),
      ]));

  Widget _miniMetric(String label,String value)=>Container(
    constraints:const BoxConstraints(minWidth:125),padding:const EdgeInsets.all(10),
    decoration:BoxDecoration(color:const Color(0xFFF3F7FC),borderRadius:BorderRadius.circular(10)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(label,style:const TextStyle(color:muted,fontSize:10,fontWeight:FontWeight.w700)),
      Text(value,style:const TextStyle(color:ink,fontSize:15,fontWeight:FontWeight.w800)),
    ]));

  Widget _goalChart(String title, double achieved, double goal, String subtitle) {
    final progress=goal>0?(achieved/goal).clamp(0.0,1.0).toDouble():0.0;
    final remaining=(goal-achieved).clamp(0.0,double.infinity).toDouble();
    return Container(
      padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(color:const Color(0xFFF3F7FC),
        borderRadius:BorderRadius.circular(12),
        border:Border.all(color:const Color(0xFFB9D0EA))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:const TextStyle(color:ink,fontWeight:FontWeight.w800,fontSize:14)),
        const SizedBox(height:4),
        Text(subtitle,style:const TextStyle(color:muted,fontSize:11)),
        const SizedBox(height:12),
        Row(children:[
          SizedBox(width:72,height:72,child:Stack(alignment:Alignment.center,children:[
            SizedBox.expand(child:CircularProgressIndicator(value:progress,
              strokeWidth:9,color:green,backgroundColor:const Color(0xFFD4E2F1))),
            Text('${(progress*100).toStringAsFixed(0)}%',
              style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:ink)),
          ])),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('${title.toLowerCase().contains('projeção') ? 'Projetado' : 'Recebido'}: ${DemoData.currency(achieved)}',
              style:const TextStyle(fontSize:12,color:ink,fontWeight:FontWeight.w700)),
            const SizedBox(height:5),
            Text('Faltam: ${DemoData.currency(remaining)}',
              style:const TextStyle(fontSize:12,color:muted)),
            const SizedBox(height:5),
            Text('Meta: ${DemoData.currency(goal)}',
              style:const TextStyle(fontSize:11,color:muted)),
          ])),
        ]),
        const SizedBox(height:12),
        ClipRRect(borderRadius:BorderRadius.circular(8),
          child:LinearProgressIndicator(value:progress,minHeight:8,
            backgroundColor:const Color(0xFFD4E2F1),color:green)),
      ]),
    );
  }

  Widget action(String label, String subtitle, IconData icon, VoidCallback onTap) =>
    Material(color: Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(14),
      child: InkWell(onTap:onTap, borderRadius:BorderRadius.circular(14),
        child:Container(
          padding:const EdgeInsets.symmetric(horizontal:12,vertical:13),
          decoration:BoxDecoration(border:Border.all(color:border,width:1.5),
            borderRadius:BorderRadius.circular(14)),
          child:Row(children:[
            Container(width:38,height:38,alignment:Alignment.center,
              decoration:BoxDecoration(color:amber.withValues(alpha:.12),
                borderRadius:BorderRadius.circular(10)),
              child:Icon(icon,color:amber,size:21)),
            const SizedBox(width:9),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
              mainAxisSize:MainAxisSize.min,children:[
                Text(label,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:ink)),
                Text(subtitle,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontSize:10,color:muted)),
              ])),
            const Icon(Icons.chevron_right,color:amber,size:15),
          ]),
        ),
      ),
    );

  @override Widget build(BuildContext context) {
    final today = DateTime.now();
    const months = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho',
      'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
    final appointments = widget.demo ? DemoData.appointments : <DemoAppointment>[];
    final planned = appointments.fold<double>(0, (sum, a) => sum + a.amount);
    return AnimatedBuilder(animation:DemoLedger.instance,
      builder:(context,_)=>_buildDashboard(context,today,months,appointments,planned));
  }

  Widget _dashboardCard(Widget child) => Container(
    padding:const EdgeInsets.all(20),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),
      border:Border.all(color:const Color(0xFFB5D5F4),width:1.2)),
    child:child);

  Widget _heading(IconData icon,String title,String subtitle,{Widget? trailing}) =>
    Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Container(padding:const EdgeInsets.all(9),
        decoration:BoxDecoration(color:const Color(0xFFE7F3FF),borderRadius:BorderRadius.circular(10)),
        child:Icon(icon,color:const Color(0xFF0065D7),size:23)),
      const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:ink)),
        Text(subtitle,style:const TextStyle(fontSize:12,color:muted)),
      ])),
      if(trailing!=null)trailing,
    ]);

  Widget _goalTile(String title,double amount,double goal,String note,Color accent) {
    final progress=goal>0?(amount/goal).clamp(0.0,1.0).toDouble():0.0;
    final missing=(goal-amount).clamp(0.0,double.infinity).toDouble();
    return Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(
        color:const Color(0xFFF5F9FD),borderRadius:BorderRadius.circular(12),
        border:Border.all(color:const Color(0xFFD0E4F9))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text(title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:14,color:ink)),
        Text(note,style:const TextStyle(fontSize:11,color:muted)),
        const SizedBox(height:14),
        Row(children:[
          SizedBox(height:82,width:82,child:Stack(alignment:Alignment.center,children:[
            SizedBox.expand(child:CircularProgressIndicator(value:progress,strokeWidth:10,
              strokeCap:StrokeCap.round,color:accent,
              backgroundColor:const Color(0xFFD4E5F4))),
            Text('${(progress*100).toStringAsFixed(0)}%',
              style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:ink)),
          ])),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,
              child:Text(widget.demo?DemoData.currency(amount):'—',
                style:const TextStyle(fontWeight:FontWeight.w800,fontSize:19,color:ink))),
            Text(widget.demo?'de ${DemoData.currency(goal)}':'Sem dados conectados',
              style:const TextStyle(fontSize:11,color:muted)),
            const SizedBox(height:9),
            Text(widget.demo?'Faltam ${DemoData.currency(missing)}':'',
              style:const TextStyle(fontSize:11,color:ink)),
          ])),
        ]),
        const SizedBox(height:14),
        ClipRRect(borderRadius:BorderRadius.circular(8),
          child:LinearProgressIndicator(value:widget.demo?progress:0,minHeight:9,
            color:accent,backgroundColor:const Color(0xFFD7E7F5))),
      ]),
    );
  }

  Widget _financeTile(String label,String value,IconData icon,Color accent) =>
    Container(padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(color:accent.withValues(alpha:.09),
        borderRadius:BorderRadius.circular(12)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Icon(icon,size:17,color:accent),const SizedBox(width:7),
          Expanded(child:Text(label,style:TextStyle(color:accent,fontSize:11,fontWeight:FontWeight.w700)))]),
        const SizedBox(height:12),
        FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,
          child:Text(value,style:TextStyle(color:accent,fontSize:20,fontWeight:FontWeight.w800))),
      ]));

  Widget _monthlyBars(double received,double pending) {
    final amounts=List<double>.generate(12,(i) => widget.demo?
      (i==DateTime.now().month-1?received:0):0);
    final maxAmount=amounts.fold<double>(1,(a,b)=>b>a?b:a);
    const labels=['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Wrap(spacing:14,runSpacing:5,children:[
        Text('● Recebido',style:TextStyle(fontSize:11,color:Color(0xFF079B79))),
        Text('● Demais meses sem histórico',style:TextStyle(fontSize:11,color:muted)),
      ]),
      const SizedBox(height:14),
      SizedBox(height:115,child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
        for(var i=0;i<12;i++)Expanded(child:Padding(
          padding:const EdgeInsets.symmetric(horizontal:3),
          child:Column(mainAxisAlignment:MainAxisAlignment.end,children:[
            Expanded(child:Align(alignment:Alignment.bottomCenter,child:Container(
              height:widget.demo&&amounts[i]>0?12+70*amounts[i]/maxAmount:4,
              decoration:BoxDecoration(color:amounts[i]>0?const Color(0xFF12A88A):const Color(0xFFDCE9F6),
                borderRadius:BorderRadius.circular(5))))),
            const SizedBox(height:7),
            FittedBox(child:Text(labels[i],style:const TextStyle(fontSize:10,color:muted))),
          ]),
        )),
      ])),
      const SizedBox(height:7),
      const Text('Histórico mensal não integrado: somente o mês demonstrativo contém valor.',
        style:TextStyle(fontSize:10,color:muted)),
    ]);
  }

  Widget _quickTile(String title,String value,IconData icon,Color accent,
      String action,VoidCallback onTap) => Material(color:Colors.white,
    borderRadius:BorderRadius.circular(14),child:InkWell(
      borderRadius:BorderRadius.circular(14),onTap:onTap,
      child:Container(padding:const EdgeInsets.all(15),
        decoration:BoxDecoration(border:Border.all(color:const Color(0xFFB5D5F4),width:1.2),
          borderRadius:BorderRadius.circular(14)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Container(padding:const EdgeInsets.all(8),
              decoration:BoxDecoration(color:accent.withValues(alpha:.09),
                borderRadius:BorderRadius.circular(9)),
              child:Icon(icon,size:21,color:accent)),
            const SizedBox(width:9),
            Expanded(child:Text(title,maxLines:2,overflow:TextOverflow.ellipsis,
              style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:ink))),
          ]),
          const SizedBox(height:12),
          Text(value,maxLines:1,overflow:TextOverflow.ellipsis,
            style:const TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),
          const SizedBox(height:6),
          Row(children:[Expanded(child:Text(action,style:const TextStyle(
            fontSize:11,color:Color(0xFF0065D7)))),
            const Icon(Icons.chevron_right,size:17,color:Color(0xFF0065D7))]),
        ])),
    ));

  Widget _buildDashboard(BuildContext context,DateTime today,List<String> months,
      List<DemoAppointment> appointments,double planned) {
    final ledger=DemoLedger.instance;
    final isDemo=widget.demo;
    final overdue=ledger.amounts.keys.where((n)=>ledger.overdue(n)).length;
    final monthlyGoal=ledger.annualGoal/12;
    final annualProjection=ledger.received*12;
    final pendingNames=ledger.amounts.keys.where((n)=>!ledger.isPaid(n)).toList()
      ..sort((a,b)=>ledger.dueDate(a).compareTo(ledger.dueDate(b)));
    return LayoutBuilder(builder:(context,viewport) {
      final desktop=viewport.maxWidth>=1080;
      final compact=viewport.maxWidth<650;
      final gap=compact?12.0:16.0;
      final goal=_dashboardCard(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        _heading(Icons.track_changes_outlined,'Metas de receita',
          'Acompanhe seu progresso mensal e a projeção anual.'),
        const SizedBox(height:16),
        LayoutBuilder(builder:(context,c){
          final monthly=_goalTile('Meta mensal',ledger.received,monthlyGoal,
            'Receita recebida no mês',const Color(0xFF079B79));
          final annual=_goalTile('Projeção anual',annualProjection,ledger.annualGoal,
            'Cenário: mês atual × 12',const Color(0xFF0068D8));
          return c.maxWidth>=530?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Expanded(child:monthly),const SizedBox(width:12),Expanded(child:annual),
          ]):Column(children:[monthly,const SizedBox(height:12),annual]);
        }),
        const SizedBox(height:16),
        const Divider(color:Color(0xFFDCE9F6)),
        const SizedBox(height:8),
        const Text('Balanço da meta',style:TextStyle(fontSize:14,
          fontWeight:FontWeight.w800,color:ink)),
        const SizedBox(height:8),
        Wrap(spacing:7,runSpacing:6,children:[
          for(final period in ['Mensal','Trimestral','Semestral','Anual'])
            ChoiceChip(label:Text(period),selected:_goalPeriod==period,
              onSelected:(_)=>setState(()=>_goalPeriod=period)),
        ]),
        const SizedBox(height:10),
        Builder(builder:(context){
          final divisor=_goalPeriod=='Mensal'?12:_goalPeriod=='Trimestral'?4:
            _goalPeriod=='Semestral'?2:1;
          final target=ledger.annualGoal/divisor;
          final balance=target-ledger.received;
          return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Wrap(spacing:14,runSpacing:6,children:[
              Text('Referência: ${DemoData.currency(target)}',
                style:const TextStyle(fontWeight:FontWeight.w700,color:ink)),
              Text('Recebido no mês: ${DemoData.currency(ledger.received)}',
                style:const TextStyle(color:ink)),
              Text('Diferença: ${DemoData.currency(balance>0?balance:0)}',
                style:const TextStyle(color:muted)),
            ]),
            const SizedBox(height:7),
            LinearProgressIndicator(value:target>0?
              (ledger.received/target).clamp(0.0,1.0).toDouble():0,
              minHeight:7,borderRadius:BorderRadius.circular(7)),
            const SizedBox(height:7),
            const Text('Comparação ilustrativa com o mês demonstrativo. '
              'Sem histórico trimestral, semestral ou anual integrado.',
              style:TextStyle(fontSize:10,color:muted)),
          ]);
        }),
        const SizedBox(height:12),
        Container(padding:const EdgeInsets.all(10),
          decoration:BoxDecoration(color:const Color(0xFFEAF5FF),borderRadius:BorderRadius.circular(9)),
          child:const Text('ⓘ A projeção anual é uma estimativa, não o total anual recebido.',
            style:TextStyle(fontSize:11,color:Color(0xFF245A98)))),
      ]));
      final finance=_dashboardCard(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        _heading(Icons.bar_chart_rounded,'Agenda financeira',
          'Entradas e saídas do mês em uma única leitura.',
          trailing:IconButton(tooltip:'Abrir financeiro',onPressed:widget.onFinance,
            icon:const Icon(Icons.chevron_right,color:Color(0xFF0065D7)))),
        const SizedBox(height:16),
        LayoutBuilder(builder:(context,c){
          final tiles=[
            _financeTile('Entradas',isDemo?DemoData.currency(ledger.received):'—',
              Icons.trending_up,const Color(0xFF008F69)),
            _financeTile('Saídas',isDemo?DemoData.currency(ledger.paidExpenses):'—',
              Icons.south_east,const Color(0xFFB63C27)),
            _financeTile('A receber',isDemo?DemoData.currency(ledger.pending):'—',
              Icons.schedule,const Color(0xFF0754A6)),
          ];
          if(c.maxWidth>=450)return Row(children:[
            for(var i=0;i<3;i++)...[
              if(i>0)const SizedBox(width:9),Expanded(child:tiles[i])]]);
          return Wrap(spacing:9,runSpacing:9,children:[
            for(final tile in tiles)SizedBox(width:(c.maxWidth-9)/2,child:tile)]);
        }),
        const SizedBox(height:15),
        _monthlyBars(ledger.received,ledger.pending),
        const SizedBox(height:10),
        Align(alignment:Alignment.centerRight,child:TextButton.icon(
          onPressed:widget.onFinance,icon:const Icon(Icons.arrow_forward,size:16),
          label:const Text('Abrir agenda financeira'))),
      ]));
      final secretary=_dashboardCard(LayoutBuilder(builder:(context,c){
        final info=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Container(width:52,height:52,
              decoration:BoxDecoration(color:const Color(0xFFEAF4FF),borderRadius:BorderRadius.circular(18)),
              child:const Icon(Icons.smart_toy_rounded,size:35,color:Color(0xFF0065D7))),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('Secretária Inteligente',style:TextStyle(
                fontSize:18,fontWeight:FontWeight.w800,color:Color(0xFF0754A6))),
              const Text('Suas prioridades do dia, resumidas por aqui.',
                style:TextStyle(fontSize:11,color:muted)),
            ])),
          ]),
        ]);
        final stats=Wrap(spacing:13,runSpacing:9,children:[
          _secretaryStat(Icons.calendar_today_outlined,isDemo?'${appointments.length}':'—','atendimentos',const Color(0xFF7C3AED)),
          _secretaryStat(Icons.receipt_long_outlined,isDemo?'${pendingNames.length}':'—','cobranças pendentes',red),
          _secretaryStat(Icons.people_outline,isDemo?'${ledger.amounts.length}':'—','clientes',const Color(0xFF0065D7)),
          _secretaryStat(Icons.schedule,isDemo?'${overdue}':'—','atrasadas',const Color(0xFF7C3AED)),
        ]);
        final open=FilledButton.icon(onPressed:widget.onSecretary,
          style:FilledButton.styleFrom(backgroundColor:const Color(0xFF06427C),
            padding:const EdgeInsets.symmetric(horizontal:20,vertical:14)),
          icon:const Icon(Icons.chat_bubble_outline,size:17),
          label:const Text('Abrir secretária'));
        return c.maxWidth>=950?Row(children:[
          Expanded(flex:4,child:info),const SizedBox(width:14),
          Expanded(flex:5,child:stats),const SizedBox(width:14),open,
        ]):Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          info,const SizedBox(height:14),stats,const SizedBox(height:14),
          Align(alignment:Alignment.centerLeft,child:open),
        ]);
      }));
      final agenda=_dashboardCard(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        _heading(Icons.calendar_month_outlined,'Agenda de hoje',
          '${today.day.toString().padLeft(2,'0')}/${today.month.toString().padLeft(2,'0')}/${today.year} • ${appointments.length} atendimentos demonstrativos',
          trailing:TextButton(onPressed:widget.onAgenda,child:const Text('Ver agenda'))),
        const SizedBox(height:10),
        for(final a in appointments)...[
          const Divider(color:Color(0xFFE2EBF5),height:13),
          LayoutBuilder(builder:(context,c){
            final state=ledger.visit(a.client,today)?.state??'Agendada';
            final statusColor=state=='Realizada'?green:
              state=='Cancelada'?red:const Color(0xFF0065D7);
            final info=Row(children:[
              SizedBox(width:48,child:Text(a.hour,style:const TextStyle(
                fontWeight:FontWeight.w800,fontSize:12,color:ink))),
              Container(width:8,height:8,decoration:BoxDecoration(
                color:statusColor,shape:BoxShape.circle)),
              const SizedBox(width:9),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(a.client,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:ink)),
                Text(a.service,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontSize:10,color:muted)),
              ])),
            ]);
            final status=Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
              decoration:BoxDecoration(color:statusColor.withValues(alpha:.10),
                borderRadius:BorderRadius.circular(18)),
              child:Text(state,style:TextStyle(fontSize:10,color:statusColor)));
            final confirmation=ledger.confirmationStatus(a.client,today);
            final actions=Wrap(spacing:4,runSpacing:5,
              crossAxisAlignment:WrapCrossAlignment.center,children:[
              Tooltip(message:'Confirmar por WhatsApp',child:IconButton.filledTonal(
                onPressed:()=>_confirmAppointment(a,today),
                style:IconButton.styleFrom(
                  backgroundColor:const Color(0xFFE1F7EA),
                  foregroundColor:const Color(0xFF128C4B),
                  minimumSize:const Size(44,44)),
                icon:const Icon(Icons.chat_outlined,size:21))),
              Tooltip(message:'Alterar confirmação',child:IconButton.outlined(
                onPressed:()=>_editConfirmationStatus(a,today),
                icon:Icon(confirmation=='Confirmado'?Icons.verified_outlined:
                  confirmation=='Solicitou remarcação'?Icons.event_busy_outlined:
                  Icons.schedule_outlined,size:20),
                style:IconButton.styleFrom(minimumSize:const Size(44,44)))),
              Tooltip(message:'Marcar realizada',child:IconButton.outlined(
                onPressed:()=>ledger.updateVisit(a.client,today,'Realizada',true,
                  'Marcado na tela inicial'),
                icon:const Icon(Icons.check_circle_outline,size:20,color:green),
                style:IconButton.styleFrom(minimumSize:const Size(44,44)))),
              Tooltip(message:'Não realizada ou remarcar',child:IconButton.outlined(
                onPressed:()=>_notDone(context,a,today),
                icon:const Icon(Icons.edit_calendar_outlined,size:20),
                style:IconButton.styleFrom(minimumSize:const Size(44,44)))),
            ]);
            final confirmationLabel=Text(
              confirmation=='Aguardando'?'Confirmação pendente':confirmation,
              style:TextStyle(fontSize:11,
                color:confirmation=='Confirmado'?green:muted));
            if(c.maxWidth>=650)return Row(children:[
              Expanded(child:info),const SizedBox(width:8),
              Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
                status,confirmationLabel,
              ]),
              const SizedBox(width:10),actions,
            ]);
            return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              info,const SizedBox(height:7),
              Row(children:[status,const SizedBox(width:8),
                Expanded(child:confirmationLabel)]),
              const SizedBox(height:7),
              actions,
            ]);
          }),
        ],
        const SizedBox(height:12),
        Align(alignment:Alignment.centerLeft,child:FilledButton.icon(
          onPressed:widget.onAgenda,
          style:FilledButton.styleFrom(backgroundColor:const Color(0xFF06427C)),
          icon:const Icon(Icons.add,size:18),label:const Text('Novo atendimento'))),
        const SizedBox(height:6),
        const Text('Marcar atendimento como realizado não confirma pagamento.',
          style:TextStyle(fontSize:10,color:muted)),
      ]));
      final upcoming=_dashboardCard(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        _heading(Icons.schedule_outlined,'Próximos recebimentos',
          'Cobranças pendentes por vencimento.',
          trailing:TextButton(onPressed:widget.onBilling,child:const Text('Ver todos'))),
        const SizedBox(height:10),
        if(!isDemo)const Text('Conecte os dados para consultar vencimentos.',
          style:TextStyle(color:muted))
        else if(pendingNames.isEmpty)const Text('Nenhuma cobrança pendente.',
          style:TextStyle(color:muted))
        else for(final name in pendingNames.take(5))...[
          const Divider(color:Color(0xFFE2EBF5),height:14),
          InkWell(onTap:widget.onBilling,child:Row(children:[
            SizedBox(width:44,child:Column(children:[
              Text('${ledger.dueDate(name).day}',style:const TextStyle(
                fontSize:19,fontWeight:FontWeight.w800,color:ink)),
              const Text('VENC.',style:TextStyle(fontSize:9,color:muted)),
            ])),
            const SizedBox(width:9),
            Expanded(child:Text(name,maxLines:1,overflow:TextOverflow.ellipsis,
              style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:ink))),
            const SizedBox(width:6),
            Text(DemoData.currency(ledger.amounts[name]??0),
              style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:ink)),
            const SizedBox(width:7),
            const Icon(Icons.chevron_right,color:Color(0xFF0065D7),size:18),
          ])),
        ],
      ]));
      return Container(
        decoration:BoxDecoration(color:const Color(0xFFEAF4FC),
          borderRadius:BorderRadius.circular(18)),
        padding:EdgeInsets.all(compact?10:16),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Padding(padding:const EdgeInsets.symmetric(horizontal:4,vertical:6),
            child:Row(children:[
              Icon(_localNow.hour>=18||_localNow.hour<5?Icons.nightlight_round:Icons.wb_sunny_rounded,
                size:30,color:const Color(0xFFF5AF24)),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(_welcome,style:TextStyle(fontSize:compact?23:29,
                  fontWeight:FontWeight.w800,color:const Color(0xFF06427C))),
                const Text('Seu negócio em uma única leitura.',
                  style:TextStyle(fontSize:12,color:Color(0xFF45648B))),
              ])),
              if(!compact)Container(
                padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
                decoration:BoxDecoration(color:Colors.white,
                  border:Border.all(color:const Color(0xFFBCD9F6)),
                  borderRadius:BorderRadius.circular(10)),
                child:Text('${today.day.toString().padLeft(2,'0')}/${today.month.toString().padLeft(2,'0')}/${today.year}',
                  style:const TextStyle(color:Color(0xFF06427C),fontSize:12))),
            ])),
          SizedBox(height:gap),
          secretary,
          SizedBox(height:gap),
          LayoutBuilder(builder:(context,c){
            if(c.maxWidth>=1050)return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Expanded(flex:11,child:ConstrainedBox(constraints:const BoxConstraints(minHeight:450),child:goal)),
              SizedBox(width:gap),
              Expanded(flex:10,child:ConstrainedBox(constraints:const BoxConstraints(minHeight:450),child:finance)),
            ]);
            return Column(children:[goal,SizedBox(height:gap),finance]);
          }),
          SizedBox(height:gap),
          LayoutBuilder(builder:(context,c){
            final count=c.maxWidth>=1000?4:c.maxWidth>=530?2:1;
            final w=(c.maxWidth-gap*(count-1))/count;
            final items=[
              _quickTile('Atendimentos hoje',isDemo?'${appointments.length}':'—',
                Icons.calendar_month_outlined,const Color(0xFF7C3AED),
                'Ver agenda do dia',widget.onAgenda),
              _quickTile('Clientes ativos',isDemo?'${ledger.amounts.length}':'—',
                Icons.groups_outlined,red,'Ver lista de clientes',widget.onClients),
              _quickTile('A receber',isDemo?DemoData.currency(ledger.pending):'—',
                Icons.payments_outlined,red,'Ver cobranças',widget.onBilling),
              _quickTile('Cobranças atrasadas',isDemo?'${overdue}':'—',
                Icons.access_time_outlined,red,'Ver pendências',widget.onBilling),
            ];
            return Wrap(spacing:gap,runSpacing:gap,children:[
              for(final item in items)SizedBox(width:w,child:item),
            ]);
          }),
          SizedBox(height:gap),
          LayoutBuilder(builder:(context,c){
            if(c.maxWidth>=920)return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Expanded(flex:11,child:ConstrainedBox(constraints:const BoxConstraints(minHeight:390),child:agenda)),
              SizedBox(width:gap),
              Expanded(flex:8,child:ConstrainedBox(constraints:const BoxConstraints(minHeight:390),child:upcoming)),
            ]);
            return Column(children:[agenda,SizedBox(height:gap),upcoming]);
          }),
          if(isDemo)const Padding(padding:EdgeInsets.only(top:14),
            child:Text('DEMONSTRAÇÃO • Dados fictícios; histórico financeiro anual não conectado.',
              style:TextStyle(fontSize:10,color:muted))),
        ]),
      );
    });
  }

  Widget _secretaryStat(IconData icon,String value,String label,Color accent) =>
    Row(mainAxisSize:MainAxisSize.min,children:[
      Container(padding:const EdgeInsets.all(7),
        decoration:BoxDecoration(color:accent.withValues(alpha:.09),
          borderRadius:BorderRadius.circular(8)),
        child:Icon(icon,size:18,color:accent)),
      const SizedBox(width:6),
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(value,style:const TextStyle(fontWeight:FontWeight.w800,color:ink,fontSize:15)),
        Text(label,style:const TextStyle(fontSize:10,color:muted)),
      ]),
    ]);
}
