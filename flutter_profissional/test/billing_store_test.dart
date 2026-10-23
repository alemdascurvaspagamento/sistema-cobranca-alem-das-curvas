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
}
