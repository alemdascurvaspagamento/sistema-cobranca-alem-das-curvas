import 'package:flutter_test/flutter_test.dart';
import 'package:coachflow_profissional/ui/client_import.dart';

void main() {
  test('lê nome, telefone e valor de linhas coladas', () {
    final rows = parseClientList('Nome;Telefone;Valor\nAna Souza; 11 99999-1111; 150\nBruno Lima\t(11) 98888-2222\tR\$ 1.200,50\nCarla Dias\n\n');
    expect(rows.map((r) => r.name), ['Ana Souza', 'Bruno Lima', 'Carla Dias']);
    expect(rows[0].phone, '11999991111');
    expect(rows[0].rate, 150);
    expect(rows[1].phone, '11988882222');
    expect(rows[1].rate, 1200.5);
    expect(rows[2].phone, '');
    expect(rows[2].rate, 0);
  });

  test('lista vazia não gera linhas', () {
    expect(parseClientList('  \n \n'), isEmpty);
  });
}
