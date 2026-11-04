import 'package:coachflow_profissional/profile/profession_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('escolha da profissão começa pelas mais usadas e termina em "Outra profissão"', () {
    final ids = [for (final p in professionsForChoice) p.id];
    expect(ids.take(7), ['personal', 'fisio', 'nutri', 'professor', 'dentista', 'fono', 'massoterapeuta']);
    expect(ids.last, 'outra');
    expect(ids.length, professionProfiles.length);
    expect(ids.toSet().length, ids.length);
  });
}
