/// Motor de cobrança do Coach Flow Profissional.
///
/// Reproduz as regras do Coach Flow Pessoal em código puro (sem telas), para
/// que o mesmo cálculo sirva à demonstração e, depois, aos dados reais.
///
/// Regras herdadas do Pessoal:
/// * As aulas do mês vêm da rotina do aluno (dias fixos da semana).
/// * Feriado marcado como "sem aula" não é cobrado (se a regra de feriado mandar).
/// * Aula cancelada é cobrada ou não conforme a escolha feita na própria aula;
///   quando nada foi escolhido, vale a regra padrão de cancelamento.
/// * Aula cancelada E cobrada vira 1 aula de desconto no mês seguinte.
/// * Aula com crédito não é cobrada.
/// * Aula remarcada não é cobrada na data original; a nova data é cobrada.
///   Se a nova data cair em outro mês e a regra for "cobrar no mês original",
///   a aula é cobrada na data original e a nova data não é cobrada.
/// * Férias: um período de aulas canceladas sem cobrança (não gera desconto).
library;

enum LessonStatus { scheduled, completed, cancelled, moved, rescheduled }

extension LessonStatusLabel on LessonStatus {
  String get label => switch (this) {
        LessonStatus.scheduled => 'Agendada',
        LessonStatus.completed => 'Realizada',
        LessonStatus.cancelled => 'Cancelada',
        LessonStatus.moved => 'Remarcada',
        LessonStatus.rescheduled => 'Reposição',
      };
}

/// Registro de uma alteração feita em uma aula.
class LessonRecord {
  const LessonRecord({
    this.status = LessonStatus.scheduled,
    this.charge,
    this.credit = false,
    this.newDate,
    this.originDate,
    this.note = '',
  });

  final LessonStatus status;

  /// `null` = seguir a regra padrão do profissional.
  final bool? charge;
  final bool credit;

  /// Para aulas remarcadas: a nova data.
  final DateTime? newDate;

  /// Para reposições: a data original de onde a aula veio.
  final DateTime? originDate;
  final String note;

  LessonRecord copyWith({
    LessonStatus? status,
    bool? charge,
    bool clearCharge = false,
    bool? credit,
    DateTime? newDate,
    bool clearNewDate = false,
    DateTime? originDate,
    String? note,
  }) =>
      LessonRecord(
        status: status ?? this.status,
        charge: clearCharge ? null : (charge ?? this.charge),
        credit: credit ?? this.credit,
        newDate: clearNewDate ? null : (newDate ?? this.newDate),
        originDate: originDate ?? this.originDate,
        note: note ?? this.note,
      );
}

enum CancelRule { charge, waive }

enum HolidayRule { noCharge, charge }

enum MoveRule { chargeNewMonth, chargeOriginalMonth }

class BillingRules {
  const BillingRules({
    this.cancel = CancelRule.charge,
    this.holiday = HolidayRule.noCharge,
    this.move = MoveRule.chargeNewMonth,
  });

  final CancelRule cancel;
  final HolidayRule holiday;
  final MoveRule move;

  BillingRules copyWith({CancelRule? cancel, HolidayRule? holiday, MoveRule? move}) =>
      BillingRules(
        cancel: cancel ?? this.cancel,
        holiday: holiday ?? this.holiday,
        move: move ?? this.move,
      );
}

class Holiday {
  const Holiday({required this.id, required this.date, required this.name, this.noClass = true});
  final String id;
  final DateTime date;
  final String name;

  /// Verdadeiro quando não há aula neste dia.
  final bool noClass;

  Holiday copyWith({DateTime? date, String? name, bool? noClass}) => Holiday(
        id: id,
        date: date ?? this.date,
        name: name ?? this.name,
        noClass: noClass ?? this.noClass,
      );
}

/// Plano de um aluno: valor por aula e dias fixos da semana.
class StudentPlan {
  const StudentPlan({
    required this.id,
    required this.name,
    required this.rate,
    required this.weekdays,
    this.times = const {},
    this.service = '',
    this.phone = '',
    this.dueDay = 5,
    this.active = true,
  });

  final String id;
  final String name;
  final String service;
  final String phone;

  /// Valor de cada aula.
  final double rate;

  /// Dias da semana no padrão do Dart: 1 = segunda ... 7 = domingo.
  final Set<int> weekdays;

  /// Horário por dia da semana, ex.: {1: '07:00'}.
  final Map<int, String> times;
  final int dueDay;
  final bool active;

  StudentPlan copyWith({int? dueDay, double? rate}) => StudentPlan(
        id: id,
        name: name,
        rate: rate ?? this.rate,
        weekdays: weekdays,
        times: times,
        service: service,
        phone: phone,
        dueDay: dueDay ?? this.dueDay,
        active: active,
      );
}

/// O que aconteceu com cada aula na conta do mês.
enum LessonOutcome {
  charged,
  waived,
  holiday,
  cancelledCharged,
  cancelledWaived,
  movedOut,
  movedChargedHere,
  credit,
  makeUpCharged,
  makeUpNotCharged,
}

extension LessonOutcomeInfo on LessonOutcome {
  bool get isCharged =>
      this == LessonOutcome.charged ||
      this == LessonOutcome.cancelledCharged ||
      this == LessonOutcome.movedChargedHere ||
      this == LessonOutcome.makeUpCharged;

  String get label => switch (this) {
        LessonOutcome.charged => 'Aula',
        LessonOutcome.waived => 'Não cobrada',
        LessonOutcome.holiday => 'Feriado',
        LessonOutcome.cancelledCharged => 'Falta cobrada',
        LessonOutcome.cancelledWaived => 'Cancelada',
        LessonOutcome.movedOut => 'Remarcada',
        LessonOutcome.movedChargedHere => 'Remarcada (cobrada aqui)',
        LessonOutcome.credit => 'Crédito',
        LessonOutcome.makeUpCharged => 'Reposição',
        LessonOutcome.makeUpNotCharged => 'Reposição sem cobrança',
      };
}

class LessonLine {
  const LessonLine({
    required this.date,
    required this.time,
    required this.outcome,
    required this.record,
    this.holidayName,
    this.isMakeUp = false,
  });

  final DateTime date;
  final String time;
  final LessonOutcome outcome;
  final LessonRecord? record;
  final String? holidayName;
  final bool isMakeUp;
}

/// Uma linha do "como chegamos a esse valor".
class BillStep {
  const BillStep(this.label, this.value, {this.kind = BillStepKind.neutral});
  final String label;
  final String value;
  final BillStepKind kind;
}

enum BillStepKind { neutral, minus, plus, result, total }

class MonthBill {
  const MonthBill({
    required this.plan,
    required this.year,
    required this.month,
    required this.lines,
    required this.routineCount,
    required this.holidays,
    required this.cancelledCharged,
    required this.cancelledWaived,
    required this.waived,
    required this.movedOut,
    required this.makeUps,
    required this.credits,
    required this.chargedLessons,
    required this.discountLessons,
  });

  final StudentPlan plan;
  final int year;
  final int month;
  final List<LessonLine> lines;

  /// Aulas que a rotina do aluno prevê no mês.
  final int routineCount;
  final int holidays;
  final int cancelledCharged;
  final int cancelledWaived;
  final int waived;
  final int movedOut;

  /// Reposições cobradas neste mês vindas de remarcações.
  final int makeUps;
  final int credits;

  /// Aulas cobradas antes do desconto.
  final int chargedLessons;

  /// Faltas cobradas no mês anterior que viram desconto agora.
  final int discountLessons;

  double get rate => plan.rate;
  int get billedLessons => chargedLessons - discountLessons;
  double get gross => chargedLessons * rate;
  double get discountValue => discountLessons * rate;
  double get total => billedLessons * rate;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime previousMonth(int year, int month) =>
    month == 1 ? DateTime(year - 1, 12) : DateTime(year, month - 1);

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Datas da rotina do aluno dentro do mês.
List<DateTime> routineDates(StudentPlan plan, int year, int month) => [
      for (var d = 1; d <= daysInMonth(year, month); d++)
        if (plan.weekdays.contains(DateTime(year, month, d).weekday)) DateTime(year, month, d),
    ];

/// Datas da rotina do aluno dentro de um período (usado em férias).
List<DateTime> routineDatesInRange(StudentPlan plan, DateTime start, DateTime end) {
  final out = <DateTime>[];
  var d = dateOnly(start);
  final last = dateOnly(end);
  while (!d.isAfter(last)) {
    if (plan.weekdays.contains(d.weekday)) out.add(d);
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return out;
}

bool _sameMonth(DateTime d, int year, int month) => d.year == year && d.month == month;

Holiday? _holidayOn(List<Holiday> holidays, DateTime d) {
  for (final h in holidays) {
    if (h.noClass && dateOnly(h.date) == dateOnly(d)) return h;
  }
  return null;
}

bool _cancelCharged(LessonRecord r, BillingRules rules) =>
    r.charge ?? (rules.cancel == CancelRule.charge);

/// Conta faltas cobradas em um mês (viram desconto no mês seguinte).
int countChargedCancels(
  StudentPlan plan,
  Map<String, LessonRecord> events,
  int year,
  int month,
  BillingRules rules,
) {
  var n = 0;
  events.forEach((key, record) {
    if (record.status != LessonStatus.cancelled || record.credit) return;
    final parts = key.split('-');
    if (parts.length != 3) return;
    final y = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    if (y != year || m != month) return;
    if (_cancelCharged(record, rules)) n++;
  });
  return n;
}

/// Calcula a cobrança de um aluno em um mês (mês de 1 a 12).
MonthBill calculateMonth({
  required StudentPlan plan,
  required int year,
  required int month,
  required Map<String, LessonRecord> events,
  required List<Holiday> holidays,
  required BillingRules rules,
}) {
  final lines = <LessonLine>[];
  var holidaysCount = 0,
      cancelledCharged = 0,
      cancelledWaived = 0,
      waived = 0,
      movedOut = 0,
      makeUps = 0,
      credits = 0;

  final routine = routineDates(plan, year, month);
  final routineKeys = routine.map(dateKey).toSet();

  for (final d in routine) {
    final record = events[dateKey(d)];
    final time = plan.times[d.weekday] ?? '';
    final holiday = rules.holiday == HolidayRule.noCharge ? _holidayOn(holidays, d) : null;
    LessonOutcome outcome;

    if (holiday != null) {
      outcome = LessonOutcome.holiday;
      holidaysCount++;
    } else if (record == null) {
      outcome = LessonOutcome.charged;
    } else if (record.credit) {
      outcome = LessonOutcome.credit;
      credits++;
    } else {
      switch (record.status) {
        case LessonStatus.cancelled:
          if (_cancelCharged(record, rules)) {
            outcome = LessonOutcome.cancelledCharged;
            cancelledCharged++;
          } else {
            outcome = LessonOutcome.cancelledWaived;
            cancelledWaived++;
          }
        case LessonStatus.moved:
          final target = record.newDate;
          final otherMonth = target != null && !_sameMonth(target, year, month);
          if (otherMonth && rules.move == MoveRule.chargeOriginalMonth) {
            outcome = LessonOutcome.movedChargedHere;
          } else {
            outcome = LessonOutcome.movedOut;
            movedOut++;
          }
        case LessonStatus.scheduled:
        case LessonStatus.completed:
        case LessonStatus.rescheduled:
          if (record.charge == false) {
            outcome = LessonOutcome.waived;
            waived++;
          } else {
            outcome = LessonOutcome.charged;
          }
      }
    }
    lines.add(LessonLine(
      date: d,
      time: time,
      outcome: outcome,
      record: record,
      holidayName: holiday?.name,
    ));
  }

  // Reposições: aulas remarcadas que caem neste mês fora da rotina.
  events.forEach((key, record) {
    if (record.status != LessonStatus.rescheduled || routineKeys.contains(key)) return;
    final parts = key.split('-');
    if (parts.length != 3) return;
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    if (!_sameMonth(d, year, month)) return;
    final origin = record.originDate;
    final fromOtherMonth = origin != null && !_sameMonth(origin, year, month);
    final chargedElsewhere = fromOtherMonth && rules.move == MoveRule.chargeOriginalMonth;
    final charged = !chargedElsewhere && record.charge != false && !record.credit;
    if (charged) makeUps++;
    lines.add(LessonLine(
      date: d,
      time: '',
      outcome: charged ? LessonOutcome.makeUpCharged : LessonOutcome.makeUpNotCharged,
      record: record,
      isMakeUp: true,
    ));
  });

  lines.sort((a, b) => a.date.compareTo(b.date));
  final chargedLessons = lines.where((l) => l.outcome.isCharged).length;
  final prev = previousMonth(year, month);
  final prevChargedCancels = countChargedCancels(plan, events, prev.year, prev.month, rules);
  final discount = prevChargedCancels < chargedLessons ? prevChargedCancels : chargedLessons;

  return MonthBill(
    plan: plan,
    year: year,
    month: month,
    lines: lines,
    routineCount: routine.length,
    holidays: holidaysCount,
    cancelledCharged: cancelledCharged,
    cancelledWaived: cancelledWaived,
    waived: waived,
    movedOut: movedOut,
    makeUps: makeUps,
    credits: credits,
    chargedLessons: chargedLessons,
    discountLessons: discount,
  );
}

// ---------------------------------------------------------------------------
// Pagamentos
// ---------------------------------------------------------------------------

class PaymentEntry {
  const PaymentEntry({required this.amount, required this.date, this.method = 'Pix'});
  final double amount;
  final DateTime date;
  final String method;
}

enum BillStatus { paid, partial, pending, overdue, nothing }

extension BillStatusLabel on BillStatus {
  String get label => switch (this) {
        BillStatus.paid => 'Pago',
        BillStatus.partial => 'Pago em parte',
        BillStatus.pending => 'A receber',
        BillStatus.overdue => 'Atrasado',
        BillStatus.nothing => 'Sem cobrança',
      };
}

DateTime dueDateFor(int dueDay, int year, int month) {
  final last = daysInMonth(year, month);
  return DateTime(year, month, dueDay < 1 ? 1 : (dueDay > last ? last : dueDay));
}

double sumPayments(List<PaymentEntry> entries) =>
    entries.fold<double>(0, (sum, e) => sum + e.amount);

BillStatus billStatus({
  required double total,
  required double received,
  required DateTime due,
  required DateTime today,
}) {
  if (total <= 0) return received > 0 ? BillStatus.paid : BillStatus.nothing;
  if (received >= total - 0.004) return BillStatus.paid;
  if (dateOnly(today).isAfter(dateOnly(due))) return BillStatus.overdue;
  if (received > 0) return BillStatus.partial;
  return BillStatus.pending;
}

// ---------------------------------------------------------------------------
// Explicação do valor
// ---------------------------------------------------------------------------

const monthNames = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

String money(num value) {
  final negative = value < 0;
  final cents = (value.abs() * 100).round();
  final reais = cents ~/ 100;
  final rest = (cents % 100).toString().padLeft(2, '0');
  final digits = reais.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${negative ? '−' : ''}R\$ $buffer,$rest';
}

String lessonsText(int n) => n == 1 ? '1 aula' : '$n aulas';

/// Passo a passo do valor, em linguagem simples.
List<BillStep> explainBill(MonthBill bill) {
  final steps = <BillStep>[
    BillStep('Aulas da rotina em ${monthNames[bill.month - 1]}', lessonsText(bill.routineCount)),
  ];
  if (bill.holidays > 0) {
    final names = bill.lines
        .where((l) => l.outcome == LessonOutcome.holiday)
        .map((l) => '${l.date.day.toString().padLeft(2, '0')}/${l.date.month.toString().padLeft(2, '0')}')
        .join(', ');
    steps.add(BillStep('Feriado sem aula ($names)', '− ${lessonsText(bill.holidays)}',
        kind: BillStepKind.minus));
  }
  if (bill.cancelledWaived > 0) {
    steps.add(BillStep('Canceladas sem cobrança', '− ${lessonsText(bill.cancelledWaived)}',
        kind: BillStepKind.minus));
  }
  if (bill.waived > 0) {
    steps.add(BillStep('Aulas marcadas para não cobrar', '− ${lessonsText(bill.waived)}',
        kind: BillStepKind.minus));
  }
  if (bill.movedOut > 0) {
    steps.add(BillStep('Remarcadas para outra data', '− ${lessonsText(bill.movedOut)}',
        kind: BillStepKind.minus));
  }
  if (bill.credits > 0) {
    steps.add(BillStep('Viraram crédito', '− ${lessonsText(bill.credits)}', kind: BillStepKind.minus));
  }
  if (bill.makeUps > 0) {
    steps.add(BillStep('Reposições neste mês', '+ ${lessonsText(bill.makeUps)}', kind: BillStepKind.plus));
  }
  steps.add(BillStep('Aulas cobradas', lessonsText(bill.chargedLessons), kind: BillStepKind.result));
  if (bill.cancelledCharged > 0) {
    steps.add(BillStep(
      'Inclui ${lessonsText(bill.cancelledCharged)} com falta cobrada (vira desconto no mês seguinte)',
      '',
    ));
  }
  if (bill.discountLessons > 0) {
    final prev = previousMonth(bill.year, bill.month);
    steps.add(BillStep(
      'Desconto da falta cobrada em ${monthNames[prev.month - 1]}',
      '− ${lessonsText(bill.discountLessons)}',
      kind: BillStepKind.minus,
    ));
  }
  steps.add(BillStep(
    '${lessonsText(bill.billedLessons)} × ${money(bill.rate)} por aula',
    money(bill.total),
    kind: BillStepKind.total,
  ));
  return steps;
}
