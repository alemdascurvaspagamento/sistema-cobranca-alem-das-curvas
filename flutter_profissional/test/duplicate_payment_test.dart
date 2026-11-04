import 'package:coachflow_profissional/billing/billing_engine.dart';
import 'package:coachflow_profissional/billing/billing_store.dart';
import 'package:coachflow_profissional/profile/profession_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tocar "Recebi" duas vezes seguidas não lança o pagamento em dobro', () {
    final store = BillingStore.instance;
    store.seed(professionById('personal'), BillingModel.perSession);
    store.sink = null;
    var now = DateTime(2026, 11, 4, 10);
    store.clock = () => now;
    final p = store.activePlans.first;
    final before = store.received(p.id);
    final pay = PaymentEntry(amount: 777.77, date: store.today, method: 'Pix');

    store.addPayment(p.id, pay);
    now = now.add(const Duration(seconds: 50));
    store.addPayment(p.id, pay);
    expect(store.received(p.id), before + 777.77);

    // Depois de alguns minutos, um segundo pagamento igual é aceito.
    now = now.add(const Duration(minutes: 5));
    store.addPayment(p.id, pay);
    expect(store.received(p.id), closeTo(before + 2 * 777.77, 0.001));

    // Desfazer e lançar de novo funciona na hora.
    store.removeLastPayment(p.id);
    store.addPayment(p.id, pay);
    expect(store.received(p.id), closeTo(before + 2 * 777.77, 0.001));
    store.clock = DateTime.now;
  });
}
