/// Vocabulário do cadastro profissional. Sem dados clínicos ou sensíveis.
class ProfessionTerms {
  static const professions=<String>[
    'Personal trainer','Coach / Mentor(a)','Consultor(a)','Dentista',
    'Enfermeiro(a)','Esteticista','Fisioterapeuta','Fonoaudiólogo(a)',
    'Instrutor(a) de Pilates','Instrutor(a) de Yoga','Massoterapeuta',
    'Médico(a)','Nutricionista','Podólogo(a)','Prestador(a) de serviços',
    'Professor(a) particular','Psicanalista','Psicólogo(a)',
    'Terapeuta integrativo(a)','Terapeuta ocupacional','Outros',
  ];
  static String appointment(String profession) {
    if(profession=='Personal trainer')return 'Treino / Aula';
    if(profession=='Professor(a) particular')return 'Aula';
    if(profession=='Médico(a)'||profession=='Dentista'||
       profession=='Nutricionista'||profession=='Enfermeiro(a)'||
       profession=='Fonoaudiólogo(a)')return 'Consulta';
    if(profession=='Consultor(a)'||profession=='Coach / Mentor(a)')
      return 'Consultoria / Reunião';
    if(profession=='Fisioterapeuta'||profession=='Psicólogo(a)'||
       profession=='Psicanalista'||profession=='Terapeuta ocupacional'||
       profession=='Terapeuta integrativo(a)'||
       profession=='Massoterapeuta'||profession=='Instrutor(a) de Pilates'||
       profession=='Instrutor(a) de Yoga')return 'Sessão';
    if(profession=='Dentista')return 'Consulta / Procedimento';
    return 'Atendimento';
  }
  static String client(String profession) =>
    profession=='Professor(a) particular'?'Aluno(a)':
    profession=='Personal trainer'?'Aluno(a) / Cliente':
    profession=='Médico(a)'||profession=='Psicólogo(a)'||
    profession=='Fisioterapeuta'||profession=='Dentista'||
    profession=='Nutricionista'?'Paciente':'Cliente';
}
