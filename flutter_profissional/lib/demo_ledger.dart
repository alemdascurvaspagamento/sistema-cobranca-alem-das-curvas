import 'package:flutter/foundation.dart';

/// Dados simulados compartilhados entre telas durante a sessão.
class DemoLedger extends ChangeNotifier {
  DemoLedger._(){seedVisits();}
  static final DemoLedger instance = DemoLedger._();
  final Map<String, bool> payments = {'Mariana Costa': true};
  final Map<String,int> dueDays={'Mariana Costa':5,'Ricardo Almeida':28,'Fernanda Lima':15,'Paulo Martins':28};
  final Map<String,DateTime> paymentDates={};
  DateTime dueDate(String name,{DateTime? at}){
    final now=at??DateTime.now();
    final last=DateTime(now.year,now.month+1,0).day;
    return DateTime(now.year,now.month,(dueDays[name]??last).clamp(1,last));
  }
  bool overdue(String name,{DateTime? at}){
    if(isPaid(name)||(amounts[name]??0)<=0||!dueDays.containsKey(name))return false;
    final now=at??DateTime.now();
    return DateTime(now.year,now.month,now.day).isAfter(dueDate(name,at:now));
  }
  String paymentStatus(String name,{DateTime? at})=>isPaid(name)?'Recebido':overdue(name,at:at)?'Em atraso':'Pendente';
  void setDueDay(String name,int day){
    if(day<1||day>31)throw ArgumentError('Dia inválido');
    dueDays[name]=day;notifyListeners();
  }
  final Map<String, Map<int, String>> absences = {};
  final Map<String, Map<int, ({String state, bool charge, String note})>> visits = {};
  int dateKey(DateTime date)=>DateTime(date.year,date.month,date.day).millisecondsSinceEpoch;
  ({String state, bool charge, String note})? visit(String name,DateTime date)=>visits[name]?[dateKey(date)];
  void setVisit(String name,DateTime date,String state,bool charge,String note){
    visits.putIfAbsent(name,()=>{})[dateKey(date)]=(state:state,charge:charge,note:note);
    notifyListeners();
  }
  void removeVisit(String name,DateTime date){visits[name]?.remove(dateKey(date));notifyListeners();}
  void updateBilling(String name,double amount){amounts[name]=amount;notifyListeners();}
  double annualGoal = 12000;
  final Map<String, double> amounts = {
    'Mariana Costa': 1260, 'Ricardo Almeida': 660,
    'Fernanda Lima': 600, 'Paulo Martins': 630,
  };
  final Map<String, double> prices = {
    'Mariana Costa': 180, 'Ricardo Almeida': 220,
    'Fernanda Lima': 150, 'Paulo Martins': 180,
  };
  final Map<String, int> credits={'Fernanda Lima':1};
  final Map<String, double> discounts={'Paulo Martins':90};
  final Map<String, int> sessionCounts={
    'Mariana Costa':8,'Ricardo Almeida':4,
    'Fernanda Lima':6,'Paulo Martins':5,
  };
  final Map<String, int> completedCounts={
    'Mariana Costa':7,'Ricardo Almeida':3,
    'Fernanda Lima':5,'Paulo Martins':4,
  };
  void seedVisits(){
    final now=DateTime.now();
    final weekdays=<DateTime>[];
    for(var day=1;day<=DateTime(now.year,now.month+1,0).day;day++){
      final date=DateTime(now.year,now.month,day);
      if(date.weekday<=5)weekdays.add(date);
    }
    for(final name in sessionCounts.keys){
      final count=sessionCounts[name]!;
      final completed=completedCounts[name]!;
      final map=visits.putIfAbsent(name,()=>{});
      for(var i=0;i<count && i<weekdays.length;i++){
        map[dateKey(weekdays[i])]=(
          state:i<completed?'Realizada':'Cancelada',
          charge:i<completed,note:'');
      }
    }
    for(final name in sessionCounts.keys){_recalculate(name);}
  }
  void _recalculate(String name){
    final completed=visits[name]?.values.where((v)=>v.state=='Realizada'&&v.charge).length??0;
    final gross=completed*(prices[name]??0);
    amounts[name]=(gross-(credits[name]??0)*(prices[name]??0)-
      (discounts[name]??0)).clamp(0.0,double.infinity).toDouble();
  }
  void updateVisit(String name,DateTime date,String state,bool charge,String note){
    visits.putIfAbsent(name,()=>{})[dateKey(date)]=(state:state,charge:charge,note:note);
    _recalculate(name);
    notifyListeners();
  }
  bool isPaid(String name) => payments[name] ?? false;
  void setPaid(String name, bool paid) { payments[name] = paid; if(paid){paymentDates[name]=DateTime.now();}else{paymentDates.remove(name);} notifyListeners(); }
  void setAmount(String name, double amount) { amounts[name] = amount; notifyListeners(); }
  String? absence(String name, DateTime date) =>
    absences[name]?[DateTime(date.year,date.month,date.day).millisecondsSinceEpoch];
  void setAbsence(String name, DateTime date, String? reason) {
    final key=DateTime(date.year,date.month,date.day).millisecondsSinceEpoch;
    final map=absences.putIfAbsent(name, () => {});
    if(reason==null) {map.remove(key);} else {map[key]=reason;}
    notifyListeners();
  }
  void setGoal(double value) { annualGoal=value; notifyListeners(); }
  double get projected => amounts.values.fold(0,(a,b)=>a+b);
  double get received => amounts.entries.where((e)=>isPaid(e.key))
    .fold(0,(sum,e)=>sum+e.value);
  double get pending => projected-received;
  // Despesa fictícia separada, não misturada com o recebimento.
  double get paidExpenses => 120;
  double get cash => received-paidExpenses;
}
