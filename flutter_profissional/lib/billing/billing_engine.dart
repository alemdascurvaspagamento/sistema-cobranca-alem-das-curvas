/// Motor de cobrança do Coach Flow Profissional.
///
/// Código puro (sem telas), para que o mesmo cálculo sirva à demonstração e,
/// depois, aos dados reais. Funciona para qualquer profissional liberal: o
/// vocabulário (aula, sessão, consulta...) vem de [Terms].
///
/// Formas de cobrança ([BillingModel]):
/// * Por atendimento: valor de cada atendimento × atendimentos cobrados no mês.
/// * Por hora: valor da hora × duração de cada atendimento.
/// * Mensalidade fixa: o mesmo valor todo mês, não importa quantos atendimentos.
/// * Pacote: o cliente paga um pacote de N atendimentos; um novo pacote é
///   cobrado no mês em que o anterior acaba.
///
/// Regras herdadas do Coach Flow Pessoal:
/// * Os atendimentos do mês vêm da rotina (dias fixos) e dos avulsos marcados.
/// * Feriado marcado como "sem atendimento" não é cobrado (se a regra mandar).
/// * Cancelamento: cobrar e descontar no mês seguinte (jeito do Pessoal),
///   cobrar sem desconto, ou não cobrar. Cada atendimento pode ser ajustado.
/// * Crédito não é cobrado. Remarcação sai da data original e entra na nova.
/// * Férias: um período de atendimentos cancelados sem cobrança.
library;

import 'terms.dart';

export 'terms.dart';

enum BillingModel { perSession, hourly, monthly, package }

enum LessonStatus { scheduled, completed, cancelled, moved, rescheduled }

extension LessonStatusLabel on LessonStatus {
  String label(Terms t) => switch (this) {
        LessonStatus.scheduled => t.g('Agendada', 'Agendado'),
        LessonStatus.completed => t.g('Realizada', 'Realizado'),
        LessonStatus.cancelled => t.g('Cancelada', 'Cancelado'),
        LessonStatus.moved => t.g('Remarcada', 'Remarcado'),
        LessonStatus.rescheduled => 'Reposição',
      };
}

/// Registro de uma alteração feita em um atendimento.
class LessonRecord {
  const LessonRecord({
    this.status = LessonStatus.scheduled,
    this.charge,
    this.credit = false,
    this.newDate,
    this.originDate,
    this.extra = false,
    this.note = '',
  });

  final LessonStatus status;

  /// `null` = seguir a regra padrão do profissional.
  final bool? charge;
  final bool credit;

  /// Para remarcações: a nova data.
  final DateTime? newDate;

  /// Para reposições: a data original de onde o atendimento veio.
  final DateTime? originDate;

  /// Atendimento avulso, marcado fora da rotina.
  final bool extra;
  final String note;
}

/// O que fazer quando o cliente cancela.
enum CancelRule {
  /// Cobra e desconta 1 atendimento no mês seguinte (jeito do Coach Flow Pessoal).
  compensate,

  /// Cobra normalmente, sem desconto depois.
  charge,

  /// Não cobra.
  waive,
}

enum HolidayRule { noCharge, charge }

enum MoveRule { chargeNewMonth, chargeOriginalMonth }

class BillingRules {
  const BillingRules({
    this.cancel = CancelRule.compensate,
    this.holiday = HolidayRule.noCharge,
    this.move = MoveRule.chargeNewMonth,
  });

  final CancelRule cancel;
  final HolidayRule holiday;
  final MoveRule move;

  BillingRules copyWith({CancelRule? cancel, HolidayRule? holiday, MoveRule? move}) => BillingRules(
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

  /// Verdadeiro quando não há atendimento neste dia.
  final bool noClass;

  Holiday copyWith({DateTime? date, String? name, bool? noClass}) => Holiday(
        id: id,
        date: date ?? this.date,
        name: name ?? this.name,
        noClass: noClass ?? this.noClass,
      );
}

/// Plano de um cliente: forma de cobrança, valor e dias fixos.
class StudentPlan {
  const StudentPlan({
    required this.id,
    required this.name,
    required this.rate,
    this.weekdays = const {},
    this.times = const {},
    this.service = '',
    this.phone = '',
    this.dueDay = 5,
    this.active = true,
    this.model = BillingModel.perSession,
    this.durationMinutes = 60,
    this.packageSize = 10,
    this.packageStart,
  });

  final String id;
  final String name;
  final String service;
  final String phone;
  final BillingModel model;

  /// Depende da forma de cobrança: valor do atendimento, da hora,
  /// da mensalidade ou do pacote.
  final double rate;

  /// Dias fixos no padrão do Dart: 1 = segunda ... 7 = domingo.
  /// Vazio = sem rotina fixa (só atendimentos avulsos).
  final Set<int> weekdays;

  /// Horário por dia da semana, ex.: {1: '07:00'}.
  final Map<int, String> times;
  final int dueDay;
  final bool active;

  /// Duração de cada atendimento (usada na cobrança por hora).
  final int durationMinutes;

  /// Quantidade de atendimentos do pacote.
  final int packageSize;

  /// Mês em que o primeiro pacote foi comprado.
  final DateTime? packageStart;

  bool get hasRoutine => weekdays.isNotEmpty;

  /// Valor de cada atendimento (por atendimento ou por hora).
  double get unitPrice => model == BillingModel.hourly ? rate * durationMinutes / 60 : rate;

  StudentPlan copyWith({int? dueDay, double? rate, BillingModel? model, bool? active}) => StudentPlan(
        id: id,
        name: name,
        rate: rate ?? this.rate,
        weekdays: weekdays,
        times: times,
        service: service,
        phone: phone,
        dueDay: dueDay ?? this.dueDay,
        active: active ?? this.active,
        model: model ?? this.model,
        durationMinutes: durationMinutes,
        packageSize: packageSize,
        packageStart: packageStart,
      );
}

/// O que aconteceu com cada atendimento na conta do mês.
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

  String label(Terms t) => switch (this) {
        LessonOutcome.charged => t.sessionTitle,
        LessonOutcome.waived => t.g('Não cobrada', 'Não cobrado'),
        LessonOutcome.holiday => 'Feriado',
        LessonOutcome.cancelledCharged => 'Falta cobrada',
        LessonOutcome.cancelledWaived => t.g('Cancelada', 'Cancelado'),
        LessonOutcome.movedOut => t.g('Remarcada', 'Remarcado'),
        LessonOutcome.movedChargedHere => t.g('Remarcada', 'Remarcado'),
        LessonOutcome.credit => 'Crédito',
        LessonOutcome.makeUpCharged => 'Reposição',
        LessonOutcome.makeUpNotCharged => 'Reposição',
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
    this.isExtra = false,
  });

  final DateTime date;
  final String time;
  final LessonOutcome outcome;
  final LessonRecord? record;
  final String? holidayName;
  final bool isMakeUp;
  final bool isExtra;
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
    required this.extras,
    required this.holidays,
    required this.cancelledCharged,
    required this.cancelledWaived,
    required this.waived,
    required this.movedOut,
    required this.makeUps,
    required this.credits,
    required this.chargedLessons,
    required this.discountLessons,
    this.packagesCharged = 0,
    this.packageUsedBefore = 0,
    this.packageRemaining = 0,
  });

  final StudentPlan plan;
  final int year;
  final int month;
  final List<LessonLine> lines;

  /// Atendimentos que a rotina prevê no mês.
  final int routineCount;

  /// Atendimentos avulsos marcados no mês.
  final int extras;
  final int holidays;
  final int cancelledCharged;
  final int cancelledWaived;
  final int waived;
  final int movedOut;

  /// Reposições cobradas neste mês vindas de remarcações.
  final int makeUps;
  final int credits;

  /// Atendimentos cobrados (ou usados, no pacote) antes do desconto.
  final int chargedLessons;

  /// Faltas cobradas no mês anterior que viram desconto agora.
  final int discountLessons;

  /// Pacote: quantos pacotes novos são cobrados neste mês.
  final int packagesCharged;

  /// Pacote: atendimentos usados antes deste mês.
  final int packageUsedBefore;

  /// Pacote: atendimentos que sobram no pacote atual ao fim do mês.
  final int packageRemaining;

  BillingModel get model => plan.model;
  double get unitPrice => plan.unitPrice;
  int get billedLessons => chargedLessons - discountLessons;
  double get discountValue => discountLessons * unitPrice;

  double get total => switch (model) {
        BillingModel.perSession || BillingModel.hourly => billedLessons * unitPrice,
        BillingModel.monthly => plan.rate,
        BillingModel.package => packagesCharged * plan.rate,
      };
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDateKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]), m = int.tryParse(parts[1]), d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

DateTime previousMonth(int year, int month) =>
    month == 1 ? DateTime(year - 1, 12) : DateTime(year, month - 1);

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Datas da rotina dentro do mês.
List<DateTime> routineDates(StudentPlan plan, int year, int month) => [
      for (var d = 1; d <= daysInMonth(year, month); d++)
        if (plan.weekdays.contains(DateTime(year, month, d).weekday)) DateTime(year, month, d),
    ];

/// Datas da rotina dentro de um período (usado em férias).
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

bool _cancelCharged(LessonRecord r, BillingRules rules) => r.charge ?? (rules.cancel != CancelRule.waive);

/// Conta faltas cobradas em um mês (viram desconto no mês seguinte).
int countChargedCancels(Map<String, LessonRecord> events, int year, int month, BillingRules rules) {
  var n = 0;
  events.forEach((key, record) {
    if (record.status != LessonStatus.cancelled || record.credit) return;
    final d = parseDateKey(key);
    if (d == null || !_sameMonth(d, year, month)) return;
    if (_cancelCharged(record, rules)) n++;
  });
  return n;
}

/// Calcula a cobrança de um cliente em um mês (mês de 1 a 12).
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
      credits = 0,
      extras = 0;

  final routine = routineDates(plan, year, month);
  final routineKeys = routine.map(dateKey).toSet();

  LessonOutcome classify(LessonRecord? record, DateTime d, {required bool allowHoliday}) {
    final holiday = allowHoliday && rules.holiday == HolidayRule.noCharge ? _holidayOn(holidays, d) : null;
    if (holiday != null) {
      holidaysCount++;
      return LessonOutcome.holiday;
    }
    if (record == null) return LessonOutcome.charged;
    if (record.credit) {
      credits++;
      return LessonOutcome.credit;
    }
    switch (record.status) {
      case LessonStatus.cancelled:
        if (_cancelCharged(record, rules)) {
          cancelledCharged++;
          return LessonOutcome.cancelledCharged;
        }
        cancelledWaived++;
        return LessonOutcome.cancelledWaived;
      case LessonStatus.moved:
        final target = record.newDate;
        final otherMonth = target != null && !_sameMonth(target, year, month);
        if (otherMonth && rules.move == MoveRule.chargeOriginalMonth) return LessonOutcome.movedChargedHere;
        movedOut++;
        return LessonOutcome.movedOut;
      case LessonStatus.scheduled:
      case LessonStatus.completed:
      case LessonStatus.rescheduled:
        if (record.charge == false) {
          waived++;
          return LessonOutcome.waived;
        }
        return LessonOutcome.charged;
    }
  }

  for (final d in routine) {
    final record = events[dateKey(d)];
    final outcome = classify(record, d, allowHoliday: true);
    lines.add(LessonLine(
      date: d,
      time: plan.times[d.weekday] ?? '',
      outcome: outcome,
      record: record,
      holidayName: outcome == LessonOutcome.holiday ? _holidayOn(holidays, d)?.name : null,
    ));
  }

  // Fora da rotina: avulsos e reposições de remarcações.
  events.forEach((key, record) {
    if (routineKeys.contains(key)) return;
    final d = parseDateKey(key);
    if (d == null || !_sameMonth(d, year, month)) return;
    if (record.status == LessonStatus.rescheduled) {
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
    } else if (record.extra) {
      extras++;
      lines.add(LessonLine(
        date: d,
        time: '',
        outcome: classify(record, d, allowHoliday: false),
        record: record,
        isExtra: true,
      ));
    }
  });

  lines.sort((a, b) => a.date.compareTo(b.date));
  final chargedLessons = lines.where((l) => l.outcome.isCharged).length;

  var discount = 0;
  final compensates = rules.cancel == CancelRule.compensate &&
      (plan.model == BillingModel.perSession || plan.model == BillingModel.hourly);
  if (compensates) {
    final prev = previousMonth(year, month);
    final prevChargedCancels = countChargedCancels(events, prev.year, prev.month, rules);
    discount = prevChargedCancels < chargedLessons ? prevChargedCancels : chargedLessons;
  }

  var packages = 0, usedBefore = 0, remaining = 0;
  if (plan.model == BillingModel.package) {
    final size = plan.packageSize < 1 ? 1 : plan.packageSize;
    final start = plan.packageStart == null
        ? DateTime(year, month)
        : DateTime(plan.packageStart!.year, plan.packageStart!.month);
    final target = DateTime(year, month);
    if (!target.isBefore(start)) {
      var cursor = start;
      var guard = 0;
      while (cursor.isBefore(target) && guard < 120) {
        usedBefore += calculateMonth(
          plan: plan.copyWith(model: BillingModel.perSession),
          year: cursor.year,
          month: cursor.month,
          events: events,
          holidays: holidays,
          rules: rules,
        ).chargedLessons;
        cursor = DateTime(cursor.year, cursor.month + 1);
        guard++;
      }
      int needed(int used) => used <= 0 ? 1 : (used + size - 1) ~/ size;
      final isStart = target == start;
      final total = usedBefore + chargedLessons;
      packages = needed(total) - (isStart ? 0 : needed(usedBefore));
      remaining = needed(total) * size - total;
    }
  }

  return MonthBill(
    plan: plan,
    year: year,
    month: month,
    lines: lines,
    routineCount: routine.length,
    extras: extras,
    holidays: holidaysCount,
    cancelledCharged: cancelledCharged,
    cancelledWaived: cancelledWaived,
    waived: waived,
    movedOut: movedOut,
    makeUps: makeUps,
    credits: credits,
    chargedLessons: chargedLessons,
    discountLessons: discount,
    packagesCharged: packages,
    packageUsedBefore: usedBefore,
    packageRemaining: remaining,
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
        BillStatus.nothing => 'Nada a cobrar',
      };
}

DateTime dueDateFor(int dueDay, int year, int month) {
  final last = daysInMonth(year, month);
  return DateTime(year, month, dueDay < 1 ? 1 : (dueDay > last ? last : dueDay));
}

double sumPayments(List<PaymentEntry> entries) => entries.fold<double>(0, (sum, e) => sum + e.amount);

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
// Textos
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

/// Valor sem os centavos quando forem zero (R$ 1.560 em vez de R$ 1.560,00).
String moneyCompact(num value) {
  final full = money(value);
  return full.endsWith(',00') ? full.substring(0, full.length - 3) : full;
}

/// "60 min", "1h", "1h30".
String durationText(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
}

extension BillingModelText on BillingModel {
  String get title => switch (this) {
        BillingModel.perSession => 'Por atendimento',
        BillingModel.hourly => 'Por hora',
        BillingModel.monthly => 'Mensalidade fixa',
        BillingModel.package => 'Pacote',
      };

  /// Explicação curta, com o vocabulário da profissão.
  String describe(Terms t) => switch (this) {
        BillingModel.perSession =>
          'Um valor por ${t.session}. No fim do mês, soma ${t.g('as', 'os')} ${t.sessions} que aconteceram.',
        BillingModel.hourly => 'Um valor por hora. Cada ${t.session} é cobrad${t.g('a', 'o')} pela duração.',
        BillingModel.monthly => 'O mesmo valor todo mês, não importa quant${t.g('as', 'os')} ${t.sessions}.',
        BillingModel.package =>
          '${t.clientTitle} paga um pacote de ${t.sessions}. Quando acaba, um novo pacote é cobrado.',
      };

  /// Nome do campo de valor no cadastro.
  String rateLabel(Terms t) => switch (this) {
        BillingModel.perSession => 'Valor de cada ${t.session}',
        BillingModel.hourly => 'Valor da hora',
        BillingModel.monthly => 'Valor da mensalidade',
        BillingModel.package => 'Valor do pacote',
      };
}

/// Resumo de uma linha para o cartão do cliente.
String billSummary(MonthBill bill, Terms t) {
  switch (bill.model) {
    case BillingModel.perSession:
    case BillingModel.hourly:
      final b = StringBuffer(bill.model == BillingModel.hourly
          ? '${t.count(bill.billedLessons)} de ${durationText(bill.plan.durationMinutes)} × ${moneyCompact(bill.plan.rate)}/h'
          : '${t.count(bill.billedLessons)} × ${moneyCompact(bill.unitPrice)}');
      if (bill.discountLessons > 0) {
        b.write(bill.discountLessons == 1 ? ' · 1 falta compensada' : ' · ${bill.discountLessons} faltas compensadas');
      }
      return b.toString();
    case BillingModel.monthly:
      return 'Mensalidade · ${t.count(bill.chargedLessons)} no mês';
    case BillingModel.package:
      final size = bill.plan.packageSize;
      if (bill.packagesCharged > 0) {
        return 'Novo pacote de $size · restam ${bill.packageRemaining}';
      }
      return 'Pacote de $size em uso · restam ${bill.packageRemaining}';
  }
}

/// Passo a passo do valor, em linguagem simples.
List<BillStep> explainBill(MonthBill bill, Terms t) {
  final month = monthNames[bill.month - 1];
  final steps = <BillStep>[];
  final hasRoutine = bill.plan.hasRoutine;

  if (hasRoutine) {
    steps.add(BillStep('${t.sessionsTitle} da rotina em $month', t.count(bill.routineCount)));
  }
  if (bill.extras > 0) {
    steps.add(BillStep(
      hasRoutine ? '${t.sessionsTitle} avuls${t.g('as', 'os')} marcad${t.g('as', 'os')}' : '${t.sessionsTitle} marcad${t.g('as', 'os')} em $month',
      hasRoutine ? '+ ${t.count(bill.extras)}' : t.count(bill.extras),
      kind: hasRoutine ? BillStepKind.plus : BillStepKind.neutral,
    ));
  }
  if (bill.holidays > 0) {
    final dates = bill.lines
        .where((l) => l.outcome == LessonOutcome.holiday)
        .map((l) => '${l.date.day.toString().padLeft(2, '0')}/${l.date.month.toString().padLeft(2, '0')}')
        .join(', ');
    steps.add(BillStep('Feriado ($dates)', '− ${t.count(bill.holidays)}', kind: BillStepKind.minus));
  }
  if (bill.cancelledWaived > 0) {
    steps.add(BillStep('${t.g('Canceladas', 'Cancelados')} sem cobrança', '− ${t.count(bill.cancelledWaived)}',
        kind: BillStepKind.minus));
  }
  if (bill.waived > 0) {
    steps.add(BillStep('Marcad${t.g('as', 'os')} para não cobrar', '− ${t.count(bill.waived)}', kind: BillStepKind.minus));
  }
  if (bill.movedOut > 0) {
    steps.add(BillStep('Remarcad${t.g('as', 'os')} para outra data', '− ${t.count(bill.movedOut)}',
        kind: BillStepKind.minus));
  }
  if (bill.credits > 0) {
    steps.add(BillStep('Viraram crédito', '− ${t.count(bill.credits)}', kind: BillStepKind.minus));
  }
  if (bill.makeUps > 0) {
    steps.add(BillStep('Reposições neste mês', '+ ${t.count(bill.makeUps)}', kind: BillStepKind.plus));
  }

  switch (bill.model) {
    case BillingModel.perSession:
    case BillingModel.hourly:
      steps.add(BillStep('${t.sessionsTitle} ${t.g('cobradas', 'cobrados')}', t.count(bill.chargedLessons),
          kind: BillStepKind.result));
      if (bill.cancelledCharged > 0) {
        steps.add(BillStep('Inclui ${t.count(bill.cancelledCharged)} com falta cobrada', ''));
      }
      if (bill.discountLessons > 0) {
        final prev = previousMonth(bill.year, bill.month);
        steps.add(BillStep('Desconto da falta cobrada em ${monthNames[prev.month - 1]}',
            '− ${t.count(bill.discountLessons)}',
            kind: BillStepKind.minus));
      }
      if (bill.model == BillingModel.hourly) {
        steps.add(BillStep(
          'Cada ${t.session}: ${durationText(bill.plan.durationMinutes)} × ${money(bill.plan.rate)} por hora',
          money(bill.unitPrice),
        ));
      }
      steps.add(BillStep(
        '${t.count(bill.billedLessons)} × ${money(bill.unitPrice)}',
        money(bill.total),
        kind: BillStepKind.total,
      ));
    case BillingModel.monthly:
      steps.add(BillStep('${t.sessionsTitle} no mês', t.count(bill.chargedLessons), kind: BillStepKind.result));
      steps.add(BillStep(
        'Faltas e feriados não mudam o valor da mensalidade.',
        '',
      ));
      steps.add(BillStep('Mensalidade de $month', money(bill.total), kind: BillStepKind.total));
    case BillingModel.package:
      final size = bill.plan.packageSize;
      steps.add(BillStep('${t.sessionsTitle} usad${t.g('as', 'os')} em $month', t.count(bill.chargedLessons),
          kind: BillStepKind.result));
      steps.add(BillStep('Usad${t.g('as', 'os')} antes de $month', t.count(bill.packageUsedBefore)));
      steps.add(BillStep('Restam no pacote atual', t.count(bill.packageRemaining)));
      steps.add(BillStep(
        bill.packagesCharged == 0
            ? 'Nenhum pacote novo em $month'
            : '${bill.packagesCharged == 1 ? '1 pacote novo' : '${bill.packagesCharged} pacotes novos'} '
                'de ${t.count(size)} × ${money(bill.plan.rate)}',
        money(bill.total),
        kind: BillStepKind.total,
      ));
  }
  return steps;
}
