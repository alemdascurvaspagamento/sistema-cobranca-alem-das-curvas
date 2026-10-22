import 'package:flutter_test/flutter_test.dart';
import 'package:coachflow_profissional/booking_requests.dart';

void main() {
  test('request requires valid name and contact', () {
    final store=BookingDemoStore.instance;
    final day=DateTime(2030,1,7);
    expect(store.request('A','1','Conversa inicial',day,'09:00'),isNotNull);
  });

  test('approved slot cannot be booked again', () {
    final store=BookingDemoStore.instance;
    final day=DateTime(2030,1,7);
    final before=store.requests.length;
    expect(store.request('Pessoa Teste','contato@exemplo.com',
      'Conversa inicial',day,'09:00'),isNull);
    final r=store.requests.first;
    expect(store.decide(r,'Aprovado'),isTrue);
    expect(store.available(day,'09:00'),isFalse);
    expect(store.request('Outra Pessoa','contato2@exemplo.com',
      'Conversa inicial',day,'09:00'),isNotNull);
    expect(store.requests.length,before+1);
  });
}
