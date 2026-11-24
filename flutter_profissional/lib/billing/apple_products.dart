/// Assinaturas vendidas dentro do iPhone/iPad (compra pela Apple — Plano C).
/// Os códigos precisam ser idênticos aos produtos criados no App Store Connect.
class AppleProducts {
  static const _base = 'br.com.alemdascurvas.coachflow';
  static const essencialMensal = '$_base.essencial.mensal';
  static const essencialAnual = '$_base.essencial.anual';
  static const profissionalMensal = '$_base.profissional.mensal';
  static const profissionalAnual = '$_base.profissional.anual';

  static const ids = {essencialMensal, essencialAnual, profissionalMensal, profissionalAnual};

  static String idFor(String plan, {required bool annual}) => '$_base.$plan.${annual ? 'anual' : 'mensal'}';
  static String planOf(String id) => id.contains('.essencial.') ? 'essencial' : 'profissional';
  static bool isAnnual(String id) => id.endsWith('.anual');

  /// Preços combinados (o valor mostrado de verdade vem da App Store, já no formato do país).
  static const referencePrice = {
    essencialMensal: 'R\$ 39,90',
    essencialAnual: 'R\$ 349,00',
    profissionalMensal: 'R\$ 69,90',
    profissionalAnual: 'R\$ 599,00',
  };

  static const features = {
    'essencial': [
      'Tudo da agenda',
      'Cobrança pelo WhatsApp com Pix',
      'Valor do mês calculado sozinho',
      'Financeiro: entradas, despesas e previsão',
      'Alunos e clientes ilimitados',
    ],
    'profissional': [
      'Tudo do Essencial',
      'Agendamento online',
      'Confirmação pelo WhatsApp',
      'Agenda no Google e no Outlook',
      'Relatórios e meta do ano',
    ],
  };

  /// Onde a pessoa gerencia ou cancela a assinatura feita pela Apple.
  static const manageUrl = 'https://apps.apple.com/account/subscriptions';
}
