import 'package:flutter_test/flutter_test.dart';
import 'package:coachflow_profissional/demo_ledger.dart';

void main() {
  test('antes do vencimento continua pendente', () {
    final ledger=DemoLedger.testing();
    ledger.setAmount('Ricardo Almeida',660);
    ledger.setDueDay('Ricardo Almeida',20);
    expect(ledger.paymentStatus('Ricardo Almeida',at:DateTime(2026,10,19)),'Pendente');
  });
  test('no dia do vencimento ainda nao esta atrasado', () {
    final ledger=DemoLedger.testing();
    ledger.setAmount('Ricardo Almeida',660);
    ledger.setDueDay('Ricardo Almeida',20);
    expect(ledger.paymentStatus('Ricardo Almeida',at:DateTime(2026,10,20,23,59)),'Pendente');
  });
  test('depois do vencimento sem pagamento fica em atraso', () {
    final ledger=DemoLedger.testing();
    ledger.setAmount('Ricardo Almeida',660);
    ledger.setDueDay('Ricardo Almeida',20);
    expect(ledger.paymentStatus('Ricardo Almeida',at:DateTime(2026,10,21)),'Em atraso');
  });
  test('pagamento quita atraso imediatamente', () {
    final ledger=DemoLedger.testing();
    ledger.setAmount('Ricardo Almeida',660);
    ledger.setDueDay('Ricardo Almeida',20);
    expect(ledger.paymentStatus('Ricardo Almeida',at:DateTime(2026,10,21)),'Em atraso');
    ledger.setPaid('Ricardo Almeida',true);
    expect(ledger.paymentStatus('Ricardo Almeida',at:DateTime(2026,10,21)),'Recebido');
    expect(ledger.paymentDates['Ricardo Almeida'],isNotNull);
  });
  test('reabertura de pagamento restaura atraso e limpa data', () {
    final ledger=DemoLedger.testing();
    ledger.setAmount('Ricardo Almeida',660);
    ledger.setDueDay('Ricardo Almeida',20);
    ledger.setPaid('Ricardo Almeida',true);
    ledger.setPaid('Ricardo Almeida',false);
    expect(ledger.paymentStatus('Ricardo Almeida',at:DateTime(2026,10,21)),'Em atraso');
    expect(ledger.paymentDates['Ricardo Almeida'],isNull);
  });
  test('vencimento 31 em fevereiro usa ultimo dia', () {
    final ledger=DemoLedger.testing();
    ledger.setDueDay('Ricardo Almeida',31);
    expect(ledger.dueDate('Ricardo Almeida',at:DateTime(2027,2,1)),DateTime(2027,2,28));
  });
  test('saldo zerado nunca gera atraso', () {
    final ledger=DemoLedger.testing();
    ledger.setAmount('Ricardo Almeida',0);
    ledger.setDueDay('Ricardo Almeida',1);
    expect(ledger.paymentStatus('Ricardo Almeida',at:DateTime(2026,10,22)),'Pendente');
  });
}
