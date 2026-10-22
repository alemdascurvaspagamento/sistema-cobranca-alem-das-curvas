import 'package:flutter_test/flutter_test.dart';
import 'package:coachflow_profissional/profession_terms.dart';

void main(){
  test('personal trainer is not duplicated by physical educator',(){
    expect(ProfessionTerms.professions.where((p)=>p=='Personal trainer').length,1);
    expect(ProfessionTerms.professions.contains('Educador(a) físico(a)'),false);
    expect(ProfessionTerms.professions.last,'Outros');
  });
  test('profession vocabulary changes by field',(){
    expect(ProfessionTerms.appointment('Personal trainer'),'Treino / Aula');
    expect(ProfessionTerms.appointment('Médico(a)'),'Consulta');
    expect(ProfessionTerms.appointment('Psicólogo(a)'),'Sessão');
    expect(ProfessionTerms.appointment('Dentista'),'Consulta / Procedimento');
    expect(ProfessionTerms.appointment('Professor(a) particular'),'Aula');
    expect(ProfessionTerms.appointment('Consultor(a)'),'Consultoria / Reunião');
    expect(ProfessionTerms.client('Psicólogo(a)'),'Paciente');
    expect(ProfessionTerms.client('Professor(a) particular'),'Aluno(a)');
  });
}
