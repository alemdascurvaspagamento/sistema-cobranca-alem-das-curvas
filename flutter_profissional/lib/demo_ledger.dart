import 'package:flutter/foundation.dart';

/// Dados simulados compartilhados entre telas durante a sessão.
class DemoLedger extends ChangeNotifier {
  DemoLedger._();
  static final DemoLedger instance = DemoLedger._();
  final Map<String, bool> payments = {'Mariana Costa': true};
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
  bool isPaid(String name) => payments[name] ?? false;
  void setPaid(String name, bool paid) { payments[name] = paid; notifyListeners(); }
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
