import 'package:coachflow_profissional/billing/billing_engine.dart';
import 'package:coachflow_profissional/billing/billing_store.dart';
import 'package:coachflow_profissional/profile/profession_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final store = BillingStore.instance;

  test('dados de exemplo funcionam em todas as profissões e formas de cobrança', () {
    for (final prof in professionProfiles) {
      for (final model in BillingModel.values) {
        store.seed(prof, model);
        final label = '${prof.name} / ${model.title}';
        expect(store.activePlans, hasLength(4), reason: label);
        expect(store.monthTotal, greaterThanOrEqualTo(0), reason: label);
        expect(store.monthRemaining, lessThanOrEqualTo(store.monthTotal + 0.01), reason: label);
        for (final p in store.activePlans) {
          expect(p.model, model, reason: label);
          final steps = explainBill(store.bill(p), store.terms);
          expect(steps.last.kind, BillStepKind.total, reason: label);
        }
      }
    }
  });

  test('marcar atendimento avulso entra na conta e na agenda', () {
    store.seed(professionById('medico'), BillingModel.perSession);
    final p = store.activePlans.first;
    final before = store.bill(p).total;
    final day = DateTime(store.today.year, store.today.month, 1);
    var free = day;
    while (store.eventsFor(p.id).containsKey(dateKey(free))) {
      free = free.add(const Duration(days: 1));
    }
    expect(store.addExtra(p.id, free), isNull);
    expect(store.bill(p).total, before + p.rate);
    expect(store.sessionsOn(free).any((e) => e.$1.id == p.id), isTrue);
    store.removeExtra(p.id, free);
    expect(store.bill(p).total, before);
  });

  test('despesa fixa se repete e pode parar de repetir', () {
    store.seed(professionById('psico'), BillingModel.perSession);
    final m = store.selectedMonth;
    final next = DateTime(m.year, m.month + 1);
    store.addExpense(Expense(id: 'x', description: 'Teste', amount: 100, date: DateTime(m.year, m.month, 3), fixed: true));
    expect(store.expensesFor(next).any((e) => e.id == 'x'), isTrue);
    store.removeExpense('x', fromMonth: next);
    expect(store.expensesFor(next).any((e) => e.id == 'x'), isFalse);
    expect(store.expensesFor(m).any((e) => e.id == 'x'), isTrue);
  });

  test('arquivar tira da cobrança sem apagar', () {
    store.seed(professionById('personal'), BillingModel.perSession);
    final id = store.activePlans.first.id;
    store.setActive(id, false);
    expect(store.activePlans.any((p) => p.id == id), isFalse);
    expect(store.archivedPlans.any((p) => p.id == id), isTrue);
    store.setActive(id, true);
    expect(store.activePlans.any((p) => p.id == id), isTrue);
  });

  test('dar baixa em despesa: cada mês da fixa tem a sua baixa', () {
    store.seed(professionById('psico'), BillingModel.perSession);
    final m = store.selectedMonth;
    final next = DateTime(m.year, m.month + 1);
    store.addExpense(Expense(id: 'b', description: 'Sala', amount: 500, date: DateTime(m.year, m.month, 2), fixed: true));
    final thisMonth = store.expensesFor(m).firstWhere((e) => e.id == 'b');
    final nextMonth = store.expensesFor(next).firstWhere((e) => e.id == 'b');
    final paidBefore = store.expensesPaid(m);
    store.payExpense(thisMonth);
    expect(store.paidAt(thisMonth), isNotNull);
    expect(store.expenseStatus(thisMonth), ExpenseStatus.paid);
    expect(store.paidAt(nextMonth), isNull);
    expect(store.expensesPaid(m), paidBefore + 500);
    store.unpayExpense(thisMonth);
    expect(store.paidAt(thisMonth), isNull);
  });

  test('sobra do mês só desconta despesas pagas', () {
    store.seed(professionById('psico'), BillingModel.perSession);
    final m = store.selectedMonth;
    expect(store.result(m), closeTo(store.totalIn(m) - store.expensesPaid(m), .001));
    expect(store.expensesPaid(m) + store.expensesOpen(m), closeTo(store.expensesTotal(m), .001));
  });

  test('horário diferente em cada dia e só numa data', () {
    store.seed(professionById('personal'), BillingModel.perSession);
    final base = store.activePlans.firstWhere((p) => p.weekdays.length >= 2);
    final days = base.weekdays.toList()..sort();
    final plan = StudentPlan(
      id: base.id, name: base.name, rate: base.rate, weekdays: base.weekdays,
      times: {days[0]: '07:00', days[1]: '18:30'},
    );
    store.savePlan(plan);
    final lines = store.bill(plan).lines.where((l) => !l.isMakeUp && !l.isExtra).toList();
    final first = lines.firstWhere((l) => l.date.weekday == days[0]);
    final second = lines.firstWhere((l) => l.date.weekday == days[1]);
    expect(first.time, '07:00');
    expect(second.time, '18:30');
    store.saveLesson(plan.id, first.date, const LessonRecord(time: '10:15'));
    final changed = store.bill(plan).lines.firstWhere((l) => l.date == first.date);
    expect(changed.time, '10:15');
    final other = store.bill(plan).lines.where((l) => l.date.weekday == days[0] && l.date != first.date);
    expect(other.every((l) => l.time == '07:00' || l.outcome != LessonOutcome.charged), isTrue);
  });

  test('calendário do mês bate com a lista de cada dia', () {
    for (final id in ['personal', 'medico', 'fisio']) {
      store.seed(professionById(id), professionById(id).defaultModel);
      final m = store.selectedMonth;
      final month = store.sessionsInMonth(m);
      for (var d = 1; d <= daysInMonth(m.year, m.month); d++) {
        final day = DateTime(m.year, m.month, d);
        final fromMonth = (month[day] ?? const []).map((e) => '${e.$1.id}|${e.$2.time}|${e.$2.outcome}').toList();
        final fromDay = store.sessionsOn(day).map((e) => '${e.$1.id}|${e.$2.time}|${e.$2.outcome}').toList();
        expect(fromMonth, fromDay, reason: '$id em ${dateKey(day)}');
      }
    }
  });

  test('previsão do mês bate com cobranças, ganhos e despesas', () {
    final store = BillingStore.instance;
    store.seed(professionById('personal'), BillingModel.perSession);
    final m = store.selectedMonth;
    final f = store.forecast(m);
    final billed = store.activePlans.fold(0.0, (s, p) => s + store.bill(p, month: m).total);
    expect(f.billed, closeTo(billed, .001));
    expect(f.expensesPlanned, closeTo(store.expensesTotal(m), .001));
    expect(f.expensesPaid + f.expensesOpen, closeTo(f.expensesPlanned, .001));
    expect(f.resultPlanned, closeTo(f.billed + f.extras - f.expensesPlanned, .001));
    expect(f.resultNow, closeTo(store.totalIn(m) - store.expensesPaid(m), .001));
    store.setAnnualGoal(120000);
    expect(store.monthlyGoal, 10000);
    expect(store.yearIn(m.year), greaterThanOrEqualTo(store.totalIn(m)));
  });
}
