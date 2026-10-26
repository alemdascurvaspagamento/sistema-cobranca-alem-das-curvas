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

  /// Desliga o login (usado nos testes automáticos, que não têm internet).
  static const offline = bool.fromEnvironment('CF_OFFLINE');

  static bool get cloudEnabled => !offline && supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
