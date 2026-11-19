import 'package:coachflow_profissional/billing/checkout.dart';
import 'package:coachflow_profissional/billing/pro_gate.dart';
import 'package:coachflow_profissional/data/subscription.dart';
import 'package:coachflow_profissional/ui/cf_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => CF.useGoogleFonts = false);

  test('CPF e CNPJ: aceita válidos e recusa inválidos', () {
    expect(validCpfCnpj('529.982.247-25'), isTrue);
    expect(validCpfCnpj('11.222.333/0001-81'), isTrue);
    expect(validCpfCnpj('529.982.247-24'), isFalse);
    expect(validCpfCnpj('11111111111'), isFalse);
    expect(validCpfCnpj('123'), isFalse);
  });

  test('assinatura lê se a conta é Profissional', () {
    final ess = SubscriptionInfo.fromJson({'plan': 'essencial', 'status': 'active', 'state': 'active', 'pro': false});
    expect(ess.pro, isFalse);
    final old = SubscriptionInfo.fromJson({'plan': 'profissional', 'status': 'trialing', 'state': 'trialing'});
    expect(old.pro, isTrue);
    expect(old.cycle, 'monthly');
    expect(old.hasSubscription, isFalse);
  });

  testWidgets('tela de relatórios bloqueada mostra o aviso', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ProLockedView(title: 'Relatórios', what: 'Gráficos e comparativos.'))));
    expect(find.text('Relatórios'), findsOneWidget);
    // Nos testes o app roda como Android (loja): o aviso não fala de plano.
    expect(find.textContaining('Não está disponível na sua conta'), findsOneWidget);
  });
}
