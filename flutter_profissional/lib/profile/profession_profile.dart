import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../billing/billing_engine.dart';

/// Uma profissão: vocabulário, jeito de cobrar mais comum e exemplos.
class ProfessionProfile {
  const ProfessionProfile({
    required this.id,
    required this.name,
    required this.icon,
    required this.terms,
    required this.defaultModel,
    required this.cancelRule,
    required this.services,
    required this.sampleRate,
    this.fixedRoutine = true,
    this.perWeek = 2,
    this.duration = 60,
  });

  final String id;

  /// Nome mostrado na escolha (ex.: "Psicólogo(a)").
  final String name;
  final IconData icon;
  final Terms terms;
  final BillingModel defaultModel;
  final CancelRule cancelRule;

  /// Nomes de serviços usados nos dados de exemplo.
  final List<String> services;

  /// Valor típico de um atendimento, usado nos exemplos.
  final double sampleRate;

  /// Verdadeiro quando costuma atender em dias fixos da semana.
  final bool fixedRoutine;

  /// Atendimentos por semana de cada cliente nos exemplos.
  final int perWeek;
  final int duration;

  ProfessionProfile withName(String custom) => ProfessionProfile(
        id: id,
        name: custom,
        icon: icon,
        terms: terms,
        defaultModel: defaultModel,
        cancelRule: cancelRule,
        services: services,
        sampleRate: sampleRate,
        fixedRoutine: fixedRoutine,
        perWeek: perWeek,
        duration: duration,
      );
}

const _alunoAula = Terms(client: 'aluno', clients: 'alunos', session: 'aula', sessions: 'aulas');
const _pacienteSessao = Terms(client: 'paciente', clients: 'pacientes', session: 'sessão', sessions: 'sessões');
const _pacienteConsulta = Terms(client: 'paciente', clients: 'pacientes', session: 'consulta', sessions: 'consultas');
const _clienteSessao = Terms(client: 'cliente', clients: 'clientes', session: 'sessão', sessions: 'sessões');
const _clienteAtendimento = Terms.generic;

/// Profissões oferecidas na escolha inicial, em ordem alfabética
/// (exceto "Outra profissão", sempre por último).
const professionProfiles = <ProfessionProfile>[
  ProfessionProfile(
    id: 'coach', name: 'Coach ou mentor(a)', icon: Icons.record_voice_over_rounded,
    terms: _clienteSessao, defaultModel: BillingModel.package, cancelRule: CancelRule.charge,
    services: ['Mentoria individual', 'Sessão de coaching', 'Mentoria de carreira', 'Plano de desenvolvimento'],
    sampleRate: 300, perWeek: 1,
  ),
  ProfessionProfile(
    id: 'consultor', name: 'Consultor(a)', icon: Icons.business_center_rounded,
    terms: _clienteAtendimento, defaultModel: BillingModel.hourly, cancelRule: CancelRule.charge,
    services: ['Consultoria mensal', 'Diagnóstico', 'Acompanhamento', 'Reunião de estratégia'],
    sampleRate: 250, perWeek: 1, duration: 90,
  ),
  ProfessionProfile(
    id: 'dentista', name: 'Dentista', icon: Icons.medical_services_rounded,
    terms: _pacienteConsulta, defaultModel: BillingModel.perSession, cancelRule: CancelRule.waive,
    services: ['Avaliação', 'Limpeza', 'Manutenção de aparelho', 'Restauração'],
    sampleRate: 250, fixedRoutine: false,
  ),
  ProfessionProfile(
    id: 'esteticista', name: 'Esteticista', icon: Icons.spa_rounded,
    terms: _clienteSessao, defaultModel: BillingModel.package, cancelRule: CancelRule.charge,
    services: ['Drenagem linfática', 'Limpeza de pele', 'Massagem modeladora', 'Radiofrequência'],
    sampleRate: 150, perWeek: 1,
  ),
  ProfessionProfile(
    id: 'fisio', name: 'Fisioterapeuta', icon: Icons.accessibility_new_rounded,
    terms: _pacienteSessao, defaultModel: BillingModel.package, cancelRule: CancelRule.charge,
    services: ['Fisioterapia ortopédica', 'Reabilitação de joelho', 'RPG', 'Pilates clínico'],
    sampleRate: 140,
  ),
  ProfessionProfile(
    id: 'fono', name: 'Fonoaudiólogo(a)', icon: Icons.hearing_rounded,
    terms: _pacienteSessao, defaultModel: BillingModel.perSession, cancelRule: CancelRule.charge,
    services: ['Terapia de fala', 'Terapia de voz', 'Linguagem infantil', 'Motricidade orofacial'],
    sampleRate: 180, perWeek: 1,
  ),
  ProfessionProfile(
    id: 'massoterapeuta', name: 'Massoterapeuta', icon: Icons.self_improvement_rounded,
    terms: _clienteSessao, defaultModel: BillingModel.package, cancelRule: CancelRule.charge,
    services: ['Massagem relaxante', 'Quick massage', 'Liberação miofascial', 'Massagem desportiva'],
    sampleRate: 160, perWeek: 1,
  ),
  ProfessionProfile(
    id: 'medico', name: 'Médico(a)', icon: Icons.local_hospital_rounded,
    terms: _pacienteConsulta, defaultModel: BillingModel.perSession, cancelRule: CancelRule.waive,
    services: ['Consulta', 'Retorno', 'Consulta de acompanhamento', 'Avaliação'],
    sampleRate: 400, fixedRoutine: false, duration: 30,
  ),
  ProfessionProfile(
    id: 'nutri', name: 'Nutricionista', icon: Icons.restaurant_rounded,
    terms: _pacienteConsulta, defaultModel: BillingModel.perSession, cancelRule: CancelRule.waive,
    services: ['Consulta inicial', 'Retorno', 'Acompanhamento esportivo', 'Plano alimentar'],
    sampleRate: 250, fixedRoutine: false,
  ),
  ProfessionProfile(
    id: 'personal', name: 'Personal trainer', icon: Icons.fitness_center_rounded,
    terms: _alunoAula, defaultModel: BillingModel.perSession, cancelRule: CancelRule.compensate,
    services: ['Treino funcional', 'Personal na academia', 'Assessoria de corrida', 'Treino em casa'],
    sampleRate: 150,
  ),
  ProfessionProfile(
    id: 'pilates', name: 'Instrutor(a) de Pilates ou Yoga', icon: Icons.sports_gymnastics_rounded,
    terms: _alunoAula, defaultModel: BillingModel.monthly, cancelRule: CancelRule.charge,
    services: ['Pilates 2x por semana', 'Yoga individual', 'Pilates em dupla', 'Alongamento'],
    sampleRate: 90,
  ),
  ProfessionProfile(
    id: 'professor', name: 'Professor(a) particular', icon: Icons.menu_book_rounded,
    terms: _alunoAula, defaultModel: BillingModel.hourly, cancelRule: CancelRule.charge,
    services: ['Matemática', 'Inglês', 'Redação', 'Reforço escolar'],
    sampleRate: 90, duration: 90,
  ),
  ProfessionProfile(
    id: 'psico', name: 'Psicólogo(a) ou psicanalista', icon: Icons.psychology_rounded,
    terms: _pacienteSessao, defaultModel: BillingModel.perSession, cancelRule: CancelRule.charge,
    services: ['Psicoterapia individual', 'Terapia de casal', 'Psicoterapia on-line', 'Acompanhamento'],
    sampleRate: 200, perWeek: 1, duration: 50,
  ),
  ProfessionProfile(
    id: 'terapeuta', name: 'Terapeuta (ocupacional ou integrativo)', icon: Icons.healing_rounded,
    terms: _clienteSessao, defaultModel: BillingModel.perSession, cancelRule: CancelRule.charge,
    services: ['Terapia ocupacional', 'Acupuntura', 'Reiki', 'Terapia integrativa'],
    sampleRate: 180, perWeek: 1,
  ),
  ProfessionProfile(
    id: 'outra', name: 'Outra profissão', icon: Icons.work_outline_rounded,
    terms: _clienteAtendimento, defaultModel: BillingModel.perSession, cancelRule: CancelRule.charge,
    services: ['Atendimento', 'Atendimento mensal', 'Avaliação', 'Acompanhamento'],
    sampleRate: 150, perWeek: 1,
  ),
];

ProfessionProfile professionById(String id) =>
    professionProfiles.firstWhere((p) => p.id == id, orElse: () => professionProfiles.last);

/// Profissão e forma de cobrança escolhidas por quem está usando o app.
class ProfessionalProfile extends ChangeNotifier {
  ProfessionalProfile._();
  static final ProfessionalProfile instance = ProfessionalProfile._();

  ProfessionProfile profession = professionById('personal');
  BillingModel model = BillingModel.perSession;
  bool chosen = false;

  Terms get terms => profession.terms;

  void choose(ProfessionProfile p, BillingModel m) {
    profession = p;
    model = m;
    chosen = true;
    notifyListeners();
  }
}
