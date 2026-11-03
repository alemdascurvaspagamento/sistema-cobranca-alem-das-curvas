import 'package:coachflow_profissional/billing/billing_store.dart';
import 'package:coachflow_profissional/booking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('convite de agendamento sai pessoal e com link próprio de cada cliente', () {
    final store = BillingStore.instance;
    store.pixName = 'Daniel Barsottini';
    store.businessName = 'Além das Curvas';
    const link = 'https://app.leguno.com.br/?agendar=abc';
    final ana = Booking.inviteText(link, firstName: 'Ana', tag: 'a1b2c3');
    final bia = Booking.inviteText(link, firstName: 'Bia', tag: 'd4e5f6');
    expect(ana, startsWith('Oi, Ana! Aqui é Daniel, da Além das Curvas.'));
    expect(ana, contains('$link&c=a1b2c3'));
    expect(ana, isNot(equals(bia)));
    expect(Booking.inviteText(link), startsWith('Oi! Aqui é Daniel'));
  });
}
