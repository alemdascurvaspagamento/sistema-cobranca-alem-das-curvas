import '../billing/billing_store.dart';

/// Link do WhatsApp para uma conversa.
///
/// Na demonstração os telefones são de exemplo e podem pertencer a alguém de
/// verdade. Por isso, fora da conta real, o WhatsApp abre sem número: a
/// mensagem vai pronta e a própria pessoa escolhe para quem mandar.
Uri whatsAppLink(String phone, {String? text}) {
  final demo = !BillingStore.instance.isCloud;
  final query = text == null ? '' : '?text=${Uri.encodeComponent(text)}';
  if (demo) return Uri.parse('https://wa.me/${query.isEmpty ? '?text=' : query}');
  var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 10 || digits.length == 11) digits = '55$digits';
  return Uri.parse('https://wa.me/$digits$query');
}
