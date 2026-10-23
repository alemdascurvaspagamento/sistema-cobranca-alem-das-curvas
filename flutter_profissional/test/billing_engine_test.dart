import 'package:coachflow_profissional/billing/billing_engine.dart';
import 'package:flutter_test/flutter_test.dart';

// Outubro de 2026: segundas = 5, 12, 19, 26 · quartas = 7, 14, 21, 28.
const plan = StudentPlan(id: 'a1', name: 'Teste', rate: 100, weekdays: {1, 3});
const rules = BillingRules();

MonthBill calc(
  Map<String, LessonRecord> events, {
  List<Holiday> holidays = const [],
  BillingRules r = rules,
  int month = 10,
  StudentPlan p = plan,
}) =>
    calculateMonth(plan: p, year: 2026, month: month, events: events, holidays: holidays, rules: r);

void main() {
  group('por atendimento', () {
    test('sem alterações, cobra toda a rotina', () {
      final b = calc({});
      expect(b.routineCount, 8);
      expect(b.chargedLessons, 8);
      expect(b.total, 800);
    });

    test('feriado sem atendimento não é cobrado', () {
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

    test('cancelado sem cobrança sai da conta', () {
      final b = calc({'2026-10-05': const LessonRecord(status: LessonStatus.cancelled, charge: false)});
      expect(b.cancelledWaived, 1);
      expect(b.total, 700);
    });

    test('cancelado sem escolha segue a regra padrão', () {
      const cancelled = {'2026-10-05': LessonRecord(status: LessonStatus.cancelled)};
      expect(calc(cancelled).total, 800);
      expect(calc(cancelled, r: const BillingRules(cancel: CancelRule.charge)).total, 800);
      expect(calc(cancelled, r: const BillingRules(cancel: CancelRule.waive)).total, 700);
    });

    test('falta cobrada vira desconto no mês seguinte só na regra de compensar', () {
      final events = {'2026-10-05': const LessonRecord(status: LessonStatus.cancelled, charge: true)};
      final nov = calc(events, month: 11);
      expect(nov.discountLessons, 1);
      expect(nov.total, nov.chargedLessons * 100 - 100);
      final novCharge = calc(events, month: 11, r: const BillingRules(cancel: CancelRule.charge));
      expect(novCharge.discountLessons, 0);
    });

    test('crédito não é cobrado', () {
      final b = calc({'2026-10-07': const LessonRecord(credit: true)});
      expect(b.credits, 1);
      expect(b.total, 700);
    });

    test('remarcado no mesmo mês: sai o original e entra a reposição', () {
      final b = calc({
        '2026-10-07': LessonRecord(status: LessonStatus.moved, newDate: DateTime(2026, 10, 8)),
        '2026-10-08': LessonRecord(status: LessonStatus.rescheduled, originDate: DateTime(2026, 10, 7)),
      });
      expect(b.movedOut, 1);
      expect(b.makeUps, 1);
      expect(b.total, 800);
    });

    test('remarcado para outro mês nas duas regras', () {
      final events = {
        '2026-10-28': LessonRecord(status: LessonStatus.moved, newDate: DateTime(2026, 11, 3)),
        '2026-11-03': LessonRecord(status: LessonStatus.rescheduled, originDate: DateTime(2026, 10, 28)),
      };
      const original = BillingRules(move: MoveRule.chargeOriginalMonth);
      expect(calc(events, r: original).total, 800);
      expect(calc(events, r: original, month: 11).makeUps, 0);
      expect(calc(events).total, 700);
      expect(calc(events, month: 11).makeUps, 1);
    });
  });

  test('avulsos sem rotina fixa', () {
    const noRoutine = StudentPlan(id: 'b', name: 'Avulso', rate: 100);
    final b = calc({
      '2026-10-06': const LessonRecord(extra: true),
      '2026-10-20': const LessonRecord(extra: true, status: LessonStatus.cancelled, charge: false),
      '2026-11-03': const LessonRecord(extra: true),
    }, p: noRoutine);
    expect(b.routineCount, 0);
    expect(b.extras, 2);
    expect(b.total, 100);
  });

  test('por hora usa a duração', () {
    const hourly = StudentPlan(
        id: 'h', name: 'Hora', rate: 120, weekdays: {1, 3}, model: BillingModel.hourly, durationMinutes: 90);
    final b = calc({}, p: hourly);
    expect(b.unitPrice, 180);
    expect(b.total, 1440);
  });

  test('mensalidade não muda com faltas', () {
    const monthly = StudentPlan(id: 'm', name: 'Mensal', rate: 600, weekdays: {1, 3}, model: BillingModel.monthly);
    final b = calc({'2026-10-05': const LessonRecord(status: LessonStatus.cancelled, charge: false)}, p: monthly);
    expect(b.total, 600);
  });

  test('pacote cobra um novo quando o anterior acaba', () {
    final pack = StudentPlan(
      id: 'p', name: 'Pacote', rate: 900, weekdays: const {1, 3},
      model: BillingModel.package, packageSize: 10, packageStart: DateTime(2026, 10),
    );
    final oct = calc({}, p: pack);
    expect(oct.packagesCharged, 1);
    expect(oct.packageRemaining, 2);
    expect(oct.total, 900);
    final nov = calc({}, p: pack, month: 11);
    expect(nov.packageUsedBefore, 8);
    expect(nov.packagesCharged, 1);
    expect(nov.packageRemaining, 3);
    expect(calc({}, p: pack, month: 9).total, 0);
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

  test('textos', () {
    expect(money(1234.5), 'R\$ 1.234,50');
    expect(moneyCompact(80), 'R\$ 80');
    expect(durationText(90), '1h30');
    const psico = Terms(client: 'paciente', clients: 'pacientes', session: 'sessão', sessions: 'sessões');
    expect(psico.count(1), '1 sessão');
    expect(Terms.generic.g('cancelada', 'cancelado'), 'cancelado');
    final steps = explainBill(calc({}), psico);
    expect(steps.last.value, 'R\$ 800,00');
    expect(steps.last.kind, BillStepKind.total);
  });
}
