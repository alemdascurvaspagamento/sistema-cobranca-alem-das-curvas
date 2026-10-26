import 'package:coachflow_profissional/billing/pix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CRC igual ao exemplo do manual do Banco Central', () {
    const body = '00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-426655440000'
        '5204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***6304';
    expect(pixCrc(body).toRadixString(16).toUpperCase().padLeft(4, '0'), '1D3D');
  });

  test('código com valor, nome e cidade sem acento', () {
    final code = pixPayload(key: 'daniel@exemplo.com', name: 'Daniel Barsottini', city: 'São Paulo', amount: 420);
    expect(code, startsWith('000201'));
    expect(code, contains('0014br.gov.bcb.pix'));
    expect(code, contains('5406420.00'));
    expect(code, contains('5917DANIEL BARSOTTINI'));
    expect(code, contains('6009SAO PAULO'));
    final body = code.substring(0, code.length - 4);
    expect(code.substring(code.length - 4), pixCrc(body).toRadixString(16).toUpperCase().padLeft(4, '0'));
  });

  test('chaves no formato do Pix', () {
    expect(normalizePixKey('(11) 98765-4321'), '+5511987654321');
    expect(normalizePixKey('123.456.789-09'), '12345678909');
    expect(normalizePixKey('Daniel@Exemplo.com'), 'daniel@exemplo.com');
  });
}
