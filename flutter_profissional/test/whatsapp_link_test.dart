import 'package:coachflow_profissional/billing/billing_store.dart';
import 'package:coachflow_profissional/ui/whatsapp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('na demonstração o WhatsApp abre sem número (telefones de exemplo podem ser reais)', () {
    BillingStore.instance.sink = null;
    final link = whatsAppLink('(11) 99999-0002', text: 'Oi!');
    expect(link.toString(), 'https://wa.me/?text=Oi!');
    expect(link.toString(), isNot(contains('99999')));
  });
}
