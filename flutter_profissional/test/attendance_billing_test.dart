import 'package:flutter_test/flutter_test.dart';
import 'package:coachflow_profissional/demo_ledger.dart';

void main(){
  test('realizada atualiza valor sem marcar pagamento',(){
    final ledger=DemoLedger.testing();
    ledger.prices['Teste']=100;
    ledger.updateVisit('Teste',DateTime(2026,10,22),'Realizada',true,'');
    expect(ledger.amounts['Teste'],100);
    expect(ledger.isPaid('Teste'),false);
  });
  test('cancelada com cobrança entra no valor mas não como realizada',(){
    final ledger=DemoLedger.testing();
    ledger.prices['Teste']=100;
    ledger.updateVisit('Teste',DateTime(2026,10,22),'Cancelada',true,'falta');
    expect(ledger.amounts['Teste'],100);
    expect(ledger.visit('Teste',DateTime(2026,10,22))?.state,'Cancelada');
  });
  test('cancelada sem cobrança não gera receita',(){
    final ledger=DemoLedger.testing();
    ledger.prices['Teste']=100;
    ledger.updateVisit('Teste',DateTime(2026,10,22),'Cancelada',false,'');
    expect(ledger.amounts['Teste'],0);
  });
}
