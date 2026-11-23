import 'package:coachflow_profissional/billing/billing_engine.dart';
import 'package:coachflow_profissional/billing/billing_store.dart';
import 'package:coachflow_profissional/data/cloud_sink.dart';
import 'package:coachflow_profissional/data/subscription.dart';
import 'package:coachflow_profissional/profile/profession_profile.dart';
import 'package:flutter_test/flutter_test.dart';

class _QuietSink implements CloudSink {
  int writes = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    writes++;
    return null;
  }
}

SubscriptionInfo _sub(String state, {String plan = 'profissional', int? limit}) =>
    SubscriptionInfo(plan: plan, status: state == 'read_only' ? 'trialing' : 'active', state: state, clientLimit: limit);

void main() {
  test('lê a assinatura vinda do banco', () {
    final s = SubscriptionInfo.fromJson({
      'plan': 'essencial',
      'status': 'trialing',
      'state': 'trialing',
      'trial_ends_at': DateTime.now().add(const Duration(days: 5, hours: 2)).toUtc().toIso8601String(),
      'founder': true,
      'client_limit': 15,
    });
    expect(s.planName, 'Essencial');
    expect(s.trialDaysLeft(DateTime.now()), 6);
    expect(s.clientLimit, 15);
    expect(s.canWrite, isTrue);
  });

  test('Agenda Grátis: agenda liberada, cobrança e financeiro travados', () {
    final store = BillingStore.instance;
    store.seed(professionById('personal'), BillingModel.perSession);
    final sink = _QuietSink();
    store.sink = sink;
    String? blocked;
    store.onLocked = (m) => blocked = m;
    store.setSubscription(_sub('read_only'));
    expect(store.isFree, isTrue);
    expect(store.canEdit, isTrue);
    final p = store.activePlans.first;
    // Agenda: presença, falta e aula avulsa funcionam.
    expect(store.saveLesson(p.id, store.today, const LessonRecord(status: LessonStatus.cancelled)), isNull);
    expect(blocked, isNull);
    // Financeiro: pagamento, despesa e entrada ficam travados.
    final before = store.received(p.id);
    store.addPayment(p.id, PaymentEntry(amount: 50, date: store.today, method: 'Pix'));
    expect(store.received(p.id), before);
    expect(blocked, BillingStore.freeMessage);
    blocked = null;
    final expenses = store.allExpenses.length;
    store.addExpense(Expense(id: 'x1', description: 'Aluguel', amount: 100, date: store.today));
    expect(store.allExpenses.length, expenses);
    expect(blocked, isNotNull);
    store.onLocked = null;
    store.setSubscription(null);
    store.seed(professionById('personal'), BillingModel.perSession);
  });

  test('Essencial não deixa passar do limite, mas edita quem já está', () {
    final store = BillingStore.instance;
    store.seed(professionById('personal'), BillingModel.perSession);
    store.sink = _QuietSink();
    String? blocked;
    store.onLocked = (m) => blocked = m;
    final n = store.activePlans.length;
    store.setSubscription(_sub('active', plan: 'essencial', limit: n));
    final first = store.activePlans.first;
    store.savePlan(first.copyWith(rate: first.rate + 10));
    expect(blocked, isNull);
    expect(store.plan(first.id).rate, first.rate + 10);
    store.savePlan(StudentPlan(id: 'novo', name: 'Novo cliente', rate: 100, weekdays: {1}));
    // Nos testes o app roda como Android (loja): o aviso não fala de plano.
    expect(blocked, contains('Sua conta vai até'));
    expect(store.plans.where((p) => p.id == 'novo'), isEmpty);
    store.onLocked = null;
    store.seed(professionById('personal'), BillingModel.perSession);
  });
}
