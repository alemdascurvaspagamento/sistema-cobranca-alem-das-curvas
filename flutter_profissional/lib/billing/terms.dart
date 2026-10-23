/// Vocabulário de cada profissão: como chamar quem é atendido e o atendimento.
///
/// Ex.: personal trainer → aluno / aula; psicólogo → paciente / sessão;
/// médico → paciente / consulta; consultor → cliente / atendimento.
class Terms {
  const Terms({
    required this.client,
    required this.clients,
    required this.session,
    required this.sessions,
    this.feminine = true,
  });

  /// Singular e plural de quem é atendido, em minúsculas (aluno, alunos).
  final String client, clients;

  /// Singular e plural do atendimento, em minúsculas (aula, aulas).
  final String session, sessions;

  /// Gênero gramatical do atendimento: "aula cancelada" × "atendimento cancelado".
  final bool feminine;

  static const generic = Terms(
    client: 'cliente',
    clients: 'clientes',
    session: 'atendimento',
    sessions: 'atendimentos',
    feminine: false,
  );

  /// "1 aula", "3 aulas".
  String count(int n) => n == 1 ? '1 $session' : '$n $sessions';

  /// Escolhe a forma feminina ou masculina: g('cancelada', 'cancelado').
  String g(String f, String m) => feminine ? f : m;

  String get sessionTitle => _cap(session);
  String get sessionsTitle => _cap(sessions);
  String get clientTitle => _cap(client);
  String get clientsTitle => _cap(clients);

  /// "da aula" / "do atendimento".
  String get ofSession => '${g('da', 'do')} $session';

  /// "a aula" / "o atendimento".
  String get theSession => '${g('a', 'o')} $session';

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
