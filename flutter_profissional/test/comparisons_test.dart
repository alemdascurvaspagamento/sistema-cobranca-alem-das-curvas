import 'package:coachflow_profissional/billing/billing_engine.dart';
import 'package:coachflow_profissional/billing/billing_store.dart';
import 'package:coachflow_profissional/profile/profession_profile.dart';
import 'package:coachflow_profissional/reports/comparisons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final store = BillingStore.instance;

  test('períodos: anterior, próximo e mesmo período do ano passado', () {
    const q = Period(PeriodKind.quarter, 2026, 0);
    expect(q.previous.year, 2025);
    expect(q.previous.index, 3);
    expect(q.next.index, 1);
    expect(q.months.first.month, 1);
    expect(q.months.last.month, 3);
    const s = Period(PeriodKind.semester, 2026, 1);
    expect(s.months.first.month, 7);
    expect(s.sameLastYear.year, 2025);
    expect(Period.containing(PeriodKind.month, DateTime(2026, 11, 3)).index, 10);
  });

  test('o "por que mudou" soma exatamente a diferença dos ganhos', () {
    store.seed(professionById('personal'), BillingModel.perSession);
    final now = Period.containing(PeriodKind.month, store.today);
    for (final p in [now, now.previous, Period.containing(PeriodKind.quarter, store.today)]) {
      final cur = PeriodNumbers.of(p);
      final base = PeriodNumbers.of(p.previous);
      final cmp = Comparison(cur, base);
      final sum = cmp.incomeDrivers().fold(0.0, (s, d) => s + d.amount);
      expect(sum, closeTo(cur.income - base.income, 5), reason: p.label);
      final exp = cmp.expenseDrivers().fold(0.0, (s, d) => s + d.amount);
      expect(exp, closeTo(cur.expenses - base.expenses, 2), reason: p.label);
    }
  });
}
