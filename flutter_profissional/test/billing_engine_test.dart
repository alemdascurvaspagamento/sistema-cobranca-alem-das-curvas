import 'package:coachflow_profissional/billing/billing_engine.dart';
import 'package:flutter_test/flutter_test.dart';

// Outubro de 2026: segundas = 5, 12, 19, 26 · quartas = 7, 14, 21, 28.
const plan = StudentPlan(id: 'a1', name: 'Teste', rate: 100, weekdays: {1, 3});
const rules = BillingRules();

MonthBill calc(Map<String, LessonRecord> events,
        {List<Holiday> holidays = const [], BillingRules r = rules, int month = 10}) =>
    calculateMonth(plan: plan, year: 2026, month: month, events: events, holidays: holidays, rules: r);

void main() {
  test('sem alterações, cobra todas as aulas da rotina', () {
    final b = calc({});
    expect(b.routineCount, 8);
    expect(b.chargedLessons, 8);
    expect(b.total, 800);
  });

  test('feriado sem aula não é cobrado', () {
    final b = calc({}, holidays: [Holiday(id: 'h', date: DateTime(2026, 10, 12), name: 'Aparecida')]);
    expect(b.holidays, 1);
    expect(b.total, 700);
  });

  test('feriado é cobrado quando a regra manda cobrar', () {
    final b = calc({},
        holidays: [Holiday(id: 'h', date: DateTime(2026, 10, 12), name: 'Aparecida')],
        r: const BillingRules(holiday: HolidayRule.charge));
    expect(b.total, 800);
  });

  test('cancelada sem cobrança sai da conta', () {
    final b = calc({'2026-10-05': const LessonRecord(status: LessonStatus.cancelled, charge: false)});
    expect(b.cancelledWaived, 1);
    expect(b.total, 700);
  });

  test('cancelada sem escolha segue a regra padrão', () {
    const cancelled = {'2026-10-05': LessonRecord(status: LessonStatus.cancelled)};
    expect(calc(cancelled).total, 800);
    expect(calc(cancelled, r: const BillingRules(cancel: CancelRule.waive)).total, 700);
  });

  test('falta cobrada vira desconto no mês seguinte', () {
    final events = {'2026-10-05': const LessonRecord(status: LessonStatus.cancelled, charge: true)};
    expect(calc(events).total, 800);
    final nov = calc(events, month: 11);
    expect(nov.discountLessons, 1);
    expect(nov.total, nov.chargedLessons * 100 - 100);
  });

  test('crédito não é cobrado', () {
    final b = calc({'2026-10-07': const LessonRecord(credit: true)});
    expect(b.credits, 1);
    expect(b.total, 700);
  });

  test('remarcada no mesmo mês: sai a original e entra a reposição', () {
    final b = calc({
      '2026-10-07': LessonRecord(status: LessonStatus.moved, newDate: DateTime(2026, 10, 8)),
      '2026-10-08': LessonRecord(status: LessonStatus.rescheduled, originDate: DateTime(2026, 10, 7)),
    });
    expect(b.movedOut, 1);
    expect(b.makeUps, 1);
    expect(b.total, 800);
  });

  test('remarcada para outro mês com regra de cobrar no mês original', () {
    final events = {
      '2026-10-28': LessonRecord(status: LessonStatus.moved, newDate: DateTime(2026, 11, 3)),
      '2026-11-03': LessonRecord(status: LessonStatus.rescheduled, originDate: DateTime(2026, 10, 28)),
    };
    const original = BillingRules(move: MoveRule.chargeOriginalMonth);
    expect(calc(events, r: original).total, 800);
    final nov = calc(events, r: original, month: 11);
    expect(nov.makeUps, 0);
    // Com a regra padrão, a aula sai de outubro e entra em novembro.
    expect(calc(events).total, 700);
    expect(calc(events, month: 11).makeUps, 1);
  });

  test('férias pegam só os dias da rotina', () {
    final dates = routineDatesInRange(plan, DateTime(2026, 10, 10), DateTime(2026, 10, 20));
    expect(dates.map(dateKey), ['2026-10-12', '2026-10-14', '2026-10-19']);
  });

  test('situação do pagamento', () {
    final due = dueDateFor(15, 2026, 10);
    expect(billStatus(total: 500, received: 500, due: due, today: DateTime(2026, 10, 20)), BillStatus.paid);
    expect(billStatus(total: 500, received: 200, due: due, today: DateTime(2026, 10, 10)), BillStatus.partial);
    expect(billStatus(total: 500, received: 200, due: due, today: DateTime(2026, 10, 20)), BillStatus.overdue);
    expect(billStatus(total: 500, received: 0, due: due, today: DateTime(2026, 10, 15)), BillStatus.pending);
  });

  test('vencimento no dia 31 usa o último dia de meses curtos', () {
    expect(dueDateFor(31, 2026, 2), DateTime(2026, 2, 28));
  });

  test('valor em reais', () {
    expect(money(1234.5), 'R\$ 1.234,50');
    expect(money(80), 'R\$ 80,00');
  });

  test('explicação termina no total', () {
    final steps = explainBill(calc({}));
    expect(steps.last.value, 'R\$ 800,00');
    expect(steps.last.kind, BillStepKind.total);
  });
}
