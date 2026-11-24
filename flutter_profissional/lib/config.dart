import 'package:flutter/foundation.dart';

/// Endereço do banco e chave pública do Coach Flow Profissional.
///
/// A chave "publishable" é feita para ficar dentro do app (navegador e celular).
/// Ela só permite o que as regras de segurança do banco deixam: cada
/// profissional logado acessa apenas as próprias linhas das tabelas cf_*.
/// Nunca coloque aqui a chave secreta (service_role).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yjpxjzgvshaabjpdpbsc.supabase.co',
  );
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_cfk3k9kcgmbvUp-oUmoNfw_rYLUzIge',
  );

  /// Contato para os testadores falarem com a gente (WhatsApp com DDI+DDD, ex.: 5511999999999,
  /// ou e-mail). Vazio: a faixa de teste aparece sem o botão de contato.
  static const supportContact = String.fromEnvironment('SUPPORT_CONTACT', defaultValue: '5511991827006');

  /// E-mail de suporte (caixa do Zoho).
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL', defaultValue: 'daniel@leguno.com.br');

  /// Endereço público do app (links enviados a clientes).
  static const publicUrl = String.fromEnvironment('PUBLIC_URL', defaultValue: 'https://app.leguno.com.br');

  /// Desliga o login (usado nos testes automáticos, que não têm internet).
  static const offline = bool.fromEnvironment('CF_OFFLINE');

  /// Nos apps das lojas (iPhone e Android) não aparecem preços, planos nem botão de assinatura:
  /// as lojas só aceitam venda de assinatura pelos meios delas. No navegador tudo continua igual.
  static bool get hidePricing =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  /// iPhone e iPad: o app tem só a agenda (Agenda Grátis) para todos, mesmo para quem assina pela web.
  /// Exigência da Apple (regras 3.1.1 e 3.1.3(b)): nada pago pode ser liberado no app sem a compra pela Apple.
  static bool get agendaOnly => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Texto curto para recurso que não existe no app do iPhone/iPad ou na conta.
  static String get unavailableHere => agendaOnly ? 'não está disponível neste app' : 'não está disponível na sua conta';

  static bool get cloudEnabled => !offline && supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
