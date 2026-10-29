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

  /// Desliga o login (usado nos testes automáticos, que não têm internet).
  static const offline = bool.fromEnvironment('CF_OFFLINE');

  static bool get cloudEnabled => !offline && supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
