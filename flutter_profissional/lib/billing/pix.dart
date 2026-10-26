/// Monta o "Pix copia e cola" (padrão BR Code do Banco Central) com valor.
///
/// É um código estático: qualquer app de banco lê, mostra o valor e o nome
/// de quem recebe. Nada passa por servidor nosso.
library;

String _field(String id, String value) => '$id${value.length.toString().padLeft(2, '0')}$value';

/// Tira acentos e caracteres que alguns bancos não aceitam.
String pixText(String s, int max) {
  const from = 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑáàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'AAAAAEEEEIIIIOOOOOUUUUCNaaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final ch in s.trim().split('')) {
    final i = from.indexOf(ch);
    final c = i >= 0 ? to[i] : ch;
    if (RegExp(r'[A-Za-z0-9 ]').hasMatch(c)) b.write(c);
  }
  final out = b.toString().replaceAll(RegExp(r' +'), ' ').toUpperCase();
  return out.length > max ? out.substring(0, max).trim() : out;
}

/// Deixa a chave no formato que o Pix espera.
/// Telefone vira +55DDDNUMERO; CPF/CNPJ só números; e-mail em minúsculas.
String normalizePixKey(String raw) {
  final k = raw.trim();
  if (k.isEmpty) return k;
  if (k.contains('@')) return k.toLowerCase();
  final digits = k.replaceAll(RegExp(r'[^0-9]'), '');
  final looksPhone = k.startsWith('+') || k.contains('(');
  if (looksPhone) return digits.startsWith('55') && digits.length >= 12 ? '+$digits' : '+55$digits';
  final looksDocument = RegExp(r'^[0-9.\-/ ]+$').hasMatch(k);
  if (looksDocument) return digits;
  return k; // chave aleatória
}

/// Dígitos de conferência (CRC16) do código Pix.
int pixCrc(String s) {
  var crc = 0xFFFF;
  for (final byte in s.codeUnits) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xFFFF;
    }
  }
  return crc;
}

/// Código "copia e cola". [amount] em reais; use 0 para o pagador digitar o valor.
String pixPayload({
  required String key,
  required String name,
  required String city,
  double amount = 0,
  String txid = '***',
  String message = '',
}) {
  final account = _field('00', 'br.gov.bcb.pix') +
      _field('01', normalizePixKey(key)) +
      (message.isEmpty ? '' : _field('02', pixText(message, 40)));
  final cleanTx = txid == '***' ? txid : txid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  final body = _field('00', '01') +
      _field('26', account) +
      _field('52', '0000') +
      _field('53', '986') +
      (amount > 0 ? _field('54', amount.toStringAsFixed(2)) : '') +
      _field('58', 'BR') +
      _field('59', pixText(name.isEmpty ? 'RECEBEDOR' : name, 25)) +
      _field('60', pixText(city.isEmpty ? 'BRASIL' : city, 15)) +
      _field('62', _field('05', cleanTx.isEmpty ? '***' : (cleanTx.length > 25 ? cleanTx.substring(0, 25) : cleanTx))) +
      '6304';
  return body + pixCrc(body).toRadixString(16).toUpperCase().padLeft(4, '0');
}
