import 'package:coachflow_profissional/billing/billing_engine.dart';
import 'package:coachflow_profissional/billing/billing_store.dart';
import 'package:coachflow_profissional/data/cloud_sink.dart';
import 'package:coachflow_profissional/data/ids.dart';
import 'package:coachflow_profissional/profile/profession_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Banco de mentira: só anota o que o app pediu para gravar.
class FakeSink implements CloudSink {
  final calls = <String>[];
  final sessions = <String, LessonRecord>{};
  final deleted = <String>[];

  @override
  void saveClient(StudentPlan p) => calls.add('client:${p.id}:${p.active}');
  @override
  void syncSessions(String clientId, Map<String, LessonRecord> upserts, List<String> deletes) {
    calls.add('sessions:$clientId:+${upserts.length}-${deletes.length}');
    sessions.addAll(upserts);
    deleted.addAll(deletes);
  }

  @override
  void addPayment(String clientId, DateTime month, PaymentEntry entry) =>
      calls.add('pay:$clientId:${month.month}:${entry.amount}:${entry.id.isNotEmpty}');
  @override
  void deletePayment(String id) => calls.add('unpay:$id');
  @override
  void saveHoliday(Holiday h) => calls.add('holiday:${h.name}');
  @override
  void deleteHoliday(String id) => calls.add('holiday-del');
  @override
  void saveExpense(Expense e) => calls.add('expense:${e.description}:${e.endMonth != null}');
  @override
  void deleteExpense(String id) => calls.add('expense-del');
  @override
  void payExpense(String expenseId, DateTime month, DateTime paidOn) => calls.add('expense-paid:${month.month}');
  @override
  void unpayExpense(String expenseId, DateTime month) => calls.add('expense-unpaid');
  @override
  void addIncome(ExtraIncome e) => calls.add('income');
  @override
  void deleteIncome(String id) => calls.add('income-del');
  @override
  void saveProfile(Map<String, Object?> fields) => calls.add('profile:${fields.keys.join(',')}');
}

void main() {
  late BillingStore store;
  late FakeSink sink;

  setUp(() {
    store = BillingStore.instance;
    store.seed(professionById('personal'), BillingModel.perSession);
    sink = FakeSink();
    store.sink = sink;
  });

  tearDown(() => store.sink = null);

  test('identificador no formato do banco', () {
    final id = newUuid();
    expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id), isTrue);
    expect(newUuid(), isNot(id));
  });

  test('falta grava só o atendimento alterado', () {
    final p = store.activePlans.firstWhere((p) => p.hasRoutine);
    final day = store.bill(p).lines.firstWhere((l) => l.record == null).date;
    store.saveLesson(p.id, day, const LessonRecord(status: LessonStatus.cancelled, charge: false));
    expect(sink.calls, ['sessions:${p.id}:+1-0']);
    expect(sink.sessions[dateKey(day)]?.status, LessonStatus.cancelled);
    store.clearLesson(p.id, day);
    expect(sink.calls.last, 'sessions:${p.id}:+0-1');
    expect(sink.deleted, [dateKey(day)]);
  });

  test('remarcação grava a original e a reposição', () {
    final p = store.activePlans.firstWhere((p) => p.hasRoutine);
    final day = store.bill(p).lines.firstWhere((l) => l.record == null).date;
    var target = day.add(const Duration(days: 1));
    while (p.weekdays.contains(target.weekday) || store.eventsFor(p.id).containsKey(dateKey(target))) {
      target = target.add(const Duration(days: 1));
    }
    store.saveLesson(p.id, day, LessonRecord(status: LessonStatus.moved, newDate: target));
    expect(sink.calls.last, 'sessions:${p.id}:+2-0');
  });

  test('pagamento, cadastro, regras e finanças vão para o banco', () {
    final p = store.activePlans.first;
    store.addPayment(p.id, PaymentEntry(amount: 100, date: store.today));
    expect(sink.calls.last, startsWith('pay:${p.id}:'));
    expect(sink.calls.last, endsWith(':true'));
    store.removeLastPayment(p.id);
    expect(sink.calls.last, startsWith('unpay:'));

    store.setActive(p.id, false);
    expect(sink.calls.last, 'client:${p.id}:false');

    store.setRules(store.rules.copyWith(cancel: CancelRule.waive));
    expect(sink.calls.last, 'profile:cancel_rule,holiday_rule,move_rule');
    store.setAnnualGoal(60000);
    expect(sink.calls.last, 'profile:annual_goal,monthly_goal');
    expect(store.monthlyGoal, 5000);
    store.setPixKey('pix@exemplo.com');
    expect(sink.calls.last, 'profile:pix_key');

    final e = Expense(id: newUuid(), description: 'Sala', amount: 300, date: store.today, fixed: true);
    store.addExpense(e);
    expect(sink.calls.last, 'expense:Sala:false');
    store.payExpense(store.expensesFor(store.selectedMonth).firstWhere((x) => x.id == e.id));
    expect(sink.calls.last, 'expense-paid:${store.today.month}');
    store.removeExpense(e.id, fromMonth: DateTime(store.today.year, store.today.month + 1));
    expect(sink.calls.last, 'expense:Sala:true');
  });

  test('férias e desfazer gravam e apagam os mesmos dias', () {
    final p = store.activePlans.firstWhere((p) => p.hasRoutine);
    final m = store.selectedMonth;
    final before = store.applyVacation(p.id, DateTime(m.year, m.month, 1), DateTime(m.year, m.month, 10), 'Férias');
    final changed = before.length;
    expect(sink.calls.last, 'sessions:${p.id}:+$changed-0');
    store.restore(p.id, before);
    final added = before.values.where((v) => v == null).length;
    expect(sink.calls.last, 'sessions:${p.id}:+${changed - added}-$added');
  });

  test('demonstração não grava nada', () {
    store.seed(professionById('psico'), BillingModel.perSession);
    expect(store.sink, isNull);
  });
}
