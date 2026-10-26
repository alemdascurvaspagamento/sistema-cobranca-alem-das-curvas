import 'package:coachflow_profissional/billing/billing_engine.dart';
import 'package:coachflow_profissional/billing/billing_store.dart';
import 'package:coachflow_profissional/data/export.dart';
import 'package:coachflow_profissional/profile/profession_profile.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('planilha com todas as abas e os clientes', () {
    final store = BillingStore.instance;
    store.seed(professionById('psico'), BillingModel.perSession);
    final bytes = buildDataWorkbook(store);
    final book = Excel.decodeBytes(bytes);
    expect(book.tables.keys, containsAll(['Resumo por mês', 'Cobranças', 'Pagamentos', 'Despesas', 'Ganhos extras', 'Feriados']));
    expect(book.tables.keys, isNot(contains('Sheet1')));
    final clients = book.tables[store.terms.clientsTitle]!;
    expect(clients.maxRows, store.plans.length + 1);
  });
}
