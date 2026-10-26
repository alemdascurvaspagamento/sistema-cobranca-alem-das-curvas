import 'package:flutter/foundation.dart';

import '../data/cloud_sink.dart';
import '../data/ids.dart';
import '../demo_ledger.dart';
import '../profile/profession_profile.dart';
import 'billing_engine.dart';
import 'pix.dart';

/// Guarda clientes, atendimentos, feriados, regras, pagamentos e finanças.
///
/// Na demonstração, tudo fica só na memória. Com login, os dados são carregados
/// do banco ([replaceAll]) e cada mudança é enviada pelo [sink].
class BillingStore extends ChangeNotifier {
  BillingStore._() {
    seed(professionById('personal'), BillingModel.perSession);
  }

  static final BillingStore instance = BillingStore._();

  DateTime get today => dateOnly(DateTime.now());

  final List<StudentPlan> plans = [];
  final Map<String, Map<String, LessonRecord>> _events = {};
  final List<Holiday> holidays = [];
  final Map<String, List<PaymentEntry>> _payments = {};
  BillingRules rules = const BillingRules();
  Terms terms = Terms.generic;

  /// Canal de gravação no banco. `null` na demonstração.
  CloudSink? sink;
  bool get isCloud => sink != null;

  String pixKey = '';
  String businessName = '';

  /// Nome e cidade de quem recebe, que aparecem no app do banco ao pagar o Pix.
  String pixName = '';
  String pixCity = '';

  void setPixKey(String value) {
    pixKey = value.trim();
    DemoLedger.instance.setProfessionalPixKey(pixKey);
    sink?.saveProfile({'pix_key': pixKey});
    notifyListeners();
  }

  void setPixInfo({required String key, required String name, required String city}) {
    pixKey = key.trim();
    pixName = name.trim();
    pixCity = city.trim();
    DemoLedger.instance.setProfessionalPixKey(pixKey);
    sink?.saveProfile({'pix_key': pixKey, 'pix_name': pixName, 'pix_city': pixCity});
    notifyListeners();
  }

  /// Código Pix "copia e cola" com o valor que falta de um cliente no mês.
  String pixCodeFor(StudentPlan p, {DateTime? month}) {
    final m = month ?? selectedMonth;
    return pixPayload(
      key: pixKey,
      name: pixName.isNotEmpty ? pixName : businessName,
      city: pixCity,
      amount: remaining(p, month: m),
      message: '${terms.sessionsTitle} ${monthNames[m.month - 1]}',
    );
  }

  /// Primeiro mês com pagamento registrado: antes disso o app ainda não era usado.
  DateTime? get firstPaymentMonth {
    DateTime? first;
    _payments.forEach((key, list) {
      if (list.isEmpty) return;
      final ym = key.split('|').last.split('-');
      final m = DateTime(int.parse(ym[0]), int.parse(ym[1]));
      if (first == null || m.isBefore(first!)) first = m;
    });
    return first;
  }

  /// Cobranças atrasadas por mês, nos últimos 12 meses de uso (só clientes ativos).
  /// Meses anteriores ao primeiro pagamento registrado não contam.
  List<({DateTime month, double amount, int count})> overdueByMonth() {
    final out = <({DateTime month, double amount, int count})>[];
    final current = DateTime(today.year, today.month);
    final start = firstPaymentMonth ?? current;
    for (var k = 0; k < 12; k++) {
      final m = DateTime(today.year, today.month - k);
      if (m.isBefore(start)) break;
      var amount = 0.0;
      var count = 0;
      for (final p in activePlans) {
        if (status(p, month: m) == BillStatus.overdue) {
          amount += remaining(p, month: m);
          count++;
        }
      }
      if (count > 0) out.add((month: m, amount: amount, count: count));
    }
    return out;
  }


  // ---- envio de atendimentos alterados

  Map<String, LessonRecord> _snap(String id) => Map.of(_events[id] ?? const {});

  void _pushEvents(String id, Map<String, LessonRecord> before) {
    final s = sink;
    if (s == null) return;
    final after = _events[id] ?? const <String, LessonRecord>{};
    final up = <String, LessonRecord>{};
    after.forEach((k, v) {
      if (!identical(before[k], v)) up[k] = v;
    });
    final del = [for (final k in before.keys) if (!after.containsKey(k)) k];
    if (up.isNotEmpty || del.isNotEmpty) s.syncSessions(id, up, del);
  }

  late DateTime selectedMonth = DateTime(today.year, today.month);

  // ---------------------------------------------------------------- leitura

  Map<String, LessonRecord> eventsFor(String studentId) => _events[studentId] ?? const {};

  StudentPlan plan(String id) => plans.firstWhere((p) => p.id == id);

  MonthBill bill(StudentPlan p, {DateTime? month}) {
    final m = month ?? selectedMonth;
    return calculateMonth(
      plan: p,
      year: m.year,
      month: m.month,
      events: eventsFor(p.id),
      holidays: holidays,
      rules: rules,
    );
  }

  String _payKey(String id, DateTime month) => '$id|${month.year}-${month.month}';

  List<PaymentEntry> payments(String id, {DateTime? month}) =>
      List.unmodifiable(_payments[_payKey(id, month ?? selectedMonth)] ?? const []);

  double received(String id, {DateTime? month}) => sumPayments(payments(id, month: month));

  DateTime dueDate(StudentPlan p, {DateTime? month}) {
    final m = month ?? selectedMonth;
    return dueDateFor(p.dueDay, m.year, m.month);
  }

  BillStatus status(StudentPlan p, {DateTime? month}) => billStatus(
        total: bill(p, month: month).total,
        received: received(p.id, month: month),
        due: dueDate(p, month: month),
        today: today,
      );

  double remaining(StudentPlan p, {DateTime? month}) {
    final r = bill(p, month: month).total - received(p.id, month: month);
    return r < 0 ? 0 : r;
  }

  List<StudentPlan> get activePlans => plans.where((p) => p.active).toList();

  double get monthTotal => activePlans.fold(0, (s, p) => s + bill(p).total);
  double get monthReceived => activePlans.fold(0, (s, p) => s + received(p.id));
  double get monthRemaining => activePlans.fold(0, (s, p) => s + remaining(p));
  int countStatus(BillStatus st) => activePlans.where((p) => status(p) == st).length;

  Holiday? holidayOn(DateTime d) {
    for (final h in holidays) {
      if (dateOnly(h.date) == dateOnly(d)) return h;
    }
    return null;
  }

  // ---------------------------------------------------------------- mês

  void goToMonth(DateTime month) {
    selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  void shiftMonth(int delta) => goToMonth(DateTime(selectedMonth.year, selectedMonth.month + delta));

  // ---------------------------------------------------------------- atendimentos

  /// Salva a situação de um atendimento. Em remarcações, cria a reposição na
  /// nova data. Retorna uma mensagem de erro, ou `null` quando deu certo.
  String? saveLesson(String studentId, DateTime date, LessonRecord record) {
    final map = _events.putIfAbsent(studentId, () => {});
    final key = dateKey(date);
    final previous = map[key];

    if (record.status == LessonStatus.moved) {
      final target = record.newDate;
      if (target == null) return 'Escolha a nova data.';
      if (dateOnly(target) == dateOnly(date)) return 'A nova data precisa ser diferente da original.';
      final existing = map[dateKey(target)];
      final isOwnMakeUp = existing?.originDate != null && dateOnly(existing!.originDate!) == dateOnly(date);
      final routineDay = plan(studentId).weekdays.contains(target.weekday);
      if ((existing != null && !isOwnMakeUp) || (routineDay && existing == null)) {
        return 'Já existe ${terms.theSession} nessa data. Escolha outro dia.';
      }
    }

    final before = _snap(studentId);
    _removeMakeUpOf(map, previous, date);
    map[key] = LessonRecord(
      status: record.status,
      charge: record.charge,
      credit: record.credit,
      newDate: record.newDate,
      originDate: record.originDate,
      extra: previous?.extra ?? record.extra,
      note: record.note,
      // Na remarcação, o horário escolhido vale para a nova data.
      time: record.status == LessonStatus.moved ? previous?.time : record.time,
    );
    if (record.status == LessonStatus.moved) {
      map[dateKey(record.newDate!)] = LessonRecord(
        status: LessonStatus.rescheduled,
        originDate: dateOnly(date),
        note: 'Reposição de ${_short(date)}',
        time: record.time,
      );
    }
    _pushEvents(studentId, before);
    _changed();
    return null;
  }

  /// Volta o atendimento ao normal. Se for avulso, ele é desmarcado.
  void clearLesson(String studentId, DateTime date) {
    final map = _events[studentId];
    if (map == null) return;
    final before = _snap(studentId);
    final key = dateKey(date);
    final previous = map.remove(key);
    _removeMakeUpOf(map, previous, date);
    final origin = previous?.originDate;
    if (previous?.status == LessonStatus.rescheduled && origin != null) {
      final original = map[dateKey(origin)];
      // Se a original era avulsa, ela volta como avulsa agendada.
      if (original != null && original.extra) {
        map[dateKey(origin)] = LessonRecord(extra: true, time: original.time);
      } else {
        map.remove(dateKey(origin));
      }
    }
    if (previous != null && previous.extra && previous.status != LessonStatus.scheduled) {
      // Avulso alterado: "voltar ao normal" mantém o atendimento marcado.
      map[key] = LessonRecord(extra: true, time: previous.time);
    }
    _pushEvents(studentId, before);
    _changed();
  }

  /// Marca um atendimento avulso. Retorna erro, ou `null`.
  String? addExtra(String studentId, DateTime date, {String note = '', String? time}) {
    final map = _events.putIfAbsent(studentId, () => {});
    final key = dateKey(date);
    if (map.containsKey(key) || plan(studentId).weekdays.contains(date.weekday)) {
      return 'Já existe ${terms.theSession} nessa data.';
    }
    final before = _snap(studentId);
    map[key] = LessonRecord(extra: true, note: note, time: time);
    _pushEvents(studentId, before);
    _changed();
    return null;
  }

  /// Desmarca um atendimento avulso.
  void removeExtra(String studentId, DateTime date) {
    final map = _events[studentId];
    if (map == null) return;
    final snap = _snap(studentId);
    final previous = map.remove(dateKey(date));
    _removeMakeUpOf(map, previous, date);
    _pushEvents(studentId, snap);
    _changed();
  }

  void _removeMakeUpOf(Map<String, LessonRecord> map, LessonRecord? previous, DateTime date) {
    if (previous?.status == LessonStatus.moved && previous?.newDate != null) {
      final makeUpKey = dateKey(previous!.newDate!);
      final makeUp = map[makeUpKey];
      if (makeUp?.originDate != null && dateOnly(makeUp!.originDate!) == dateOnly(date)) {
        map.remove(makeUpKey);
      }
    }
  }

  /// Datas que serão afetadas por férias no período (rotina e avulsos).
  List<DateTime> vacationPreview(String studentId, DateTime start, DateTime end) {
    final events = eventsFor(studentId);
    bool free(LessonRecord? r) =>
        r == null ||
        (r.status == LessonStatus.scheduled && !r.credit) ||
        (r.status == LessonStatus.cancelled && r.charge == false);
    final dates = routineDatesInRange(plan(studentId), start, end).where((d) => free(events[dateKey(d)])).toList();
    events.forEach((key, r) {
      final d = parseDateKey(key);
      if (d == null || !r.extra) return;
      if (d.isBefore(dateOnly(start)) || d.isAfter(dateOnly(end))) return;
      if (free(r) && !dates.contains(d)) dates.add(d);
    });
    dates.sort();
    return dates;
  }

  /// Marca férias: cancela os atendimentos do período sem cobrança.
  /// Retorna o estado anterior, para permitir desfazer.
  Map<String, LessonRecord?> applyVacation(String studentId, DateTime start, DateTime end, String reason) {
    final map = _events.putIfAbsent(studentId, () => {});
    final snap = _snap(studentId);
    final before = <String, LessonRecord?>{};
    for (final d in vacationPreview(studentId, start, end)) {
      final key = dateKey(d);
      before[key] = map[key];
      map[key] = LessonRecord(
        status: LessonStatus.cancelled,
        charge: false,
        extra: map[key]?.extra ?? false,
        note: reason,
        time: map[key]?.time,
      );
    }
    _pushEvents(studentId, snap);
    _changed();
    return before;
  }

  void restore(String studentId, Map<String, LessonRecord?> before) {
    final map = _events.putIfAbsent(studentId, () => {});
    final snap = _snap(studentId);
    before.forEach((key, record) {
      if (record == null) {
        map.remove(key);
      } else {
        map[key] = record;
      }
    });
    _pushEvents(studentId, snap);
    _changed();
  }

  // ---------------------------------------------------------------- pagamentos

  void addPayment(String studentId, PaymentEntry entry, {DateTime? month}) {
    final m = month ?? selectedMonth;
    final e = entry.id.isEmpty ? entry.withId(newUuid()) : entry;
    _payments.putIfAbsent(_payKey(studentId, m), () => []).add(e);
    sink?.addPayment(studentId, DateTime(m.year, m.month), e);
    _changed();
  }

  void removeLastPayment(String studentId, {DateTime? month}) {
    final list = _payments[_payKey(studentId, month ?? selectedMonth)];
    if (list == null || list.isEmpty) return;
    final removed = list.removeLast();
    if (removed.id.isNotEmpty) sink?.deletePayment(removed.id);
    _changed();
  }

  void setDueDay(String studentId, int day) {
    final i = plans.indexWhere((p) => p.id == studentId);
    if (i < 0) return;
    plans[i] = plans[i].copyWith(dueDay: day);
    sink?.saveClient(plans[i]);
    _changed();
  }

  // ---------------------------------------------------------------- regras e feriados

  void setRules(BillingRules value) {
    rules = value;
    sink?.saveProfile({
      'cancel_rule': value.cancel.name,
      'holiday_rule': value.holiday.name,
      'move_rule': value.move.name,
    });
    _changed();
  }

  void saveHoliday(Holiday h) {
    final i = holidays.indexWhere((x) => x.id == h.id);
    if (i >= 0) {
      holidays[i] = h;
    } else {
      holidays.add(h);
    }
    holidays.sort((a, b) => a.date.compareTo(b.date));
    sink?.saveHoliday(h);
    _changed();
  }

  void removeHoliday(String id) {
    holidays.removeWhere((h) => h.id == id);
    sink?.deleteHoliday(id);
    _changed();
  }

  // ---------------------------------------------------------------- cadastro de clientes

  String newClientId() => newUuid();

  /// Cria ou atualiza o cadastro de um cliente.
  void savePlan(StudentPlan p) {
    final i = plans.indexWhere((x) => x.id == p.id);
    if (i >= 0) {
      plans[i] = p;
    } else {
      plans.add(p);
    }
    plans.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    sink?.saveClient(p);
    _changed();
  }

  /// Arquiva (não apaga): o histórico continua guardado.
  void setActive(String id, bool active) {
    final i = plans.indexWhere((x) => x.id == id);
    if (i < 0) return;
    plans[i] = plans[i].copyWith(active: active);
    sink?.saveClient(plans[i]);
    _changed();
  }

  List<StudentPlan> get archivedPlans => plans.where((p) => !p.active).toList();

  // ---------------------------------------------------------------- agenda

  /// Atendimentos de todos os clientes ativos em um dia, por horário.
  List<(StudentPlan, LessonLine)> sessionsOn(DateTime day) {
    final d = dateOnly(day);
    final out = <(StudentPlan, LessonLine)>[];
    for (final p in activePlans) {
      for (final line in bill(p, month: DateTime(d.year, d.month)).lines) {
        if (dateOnly(line.date) == d) out.add((p, line));
      }
    }
    out.sort((a, b) {
      final ta = a.$2.time.isEmpty ? '99' : a.$2.time;
      final tb = b.$2.time.isEmpty ? '99' : b.$2.time;
      final c = ta.compareTo(tb);
      return c != 0 ? c : a.$1.name.compareTo(b.$1.name);
    });
    return out;
  }

  /// Atendimentos de um mês inteiro, agrupados por dia e ordenados por horário.
  /// Calcula cada cliente uma vez só (mais rápido que [sessionsOn] dia a dia).
  Map<DateTime, List<(StudentPlan, LessonLine)>> sessionsInMonth(DateTime month) {
    final m = DateTime(month.year, month.month);
    final out = <DateTime, List<(StudentPlan, LessonLine)>>{};
    for (final p in activePlans) {
      for (final line in bill(p, month: m).lines) {
        out.putIfAbsent(dateOnly(line.date), () => []).add((p, line));
      }
    }
    for (final list in out.values) {
      list.sort((a, b) {
        final ta = a.$2.time.isEmpty ? '99' : a.$2.time;
        final tb = b.$2.time.isEmpty ? '99' : b.$2.time;
        final c = ta.compareTo(tb);
        return c != 0 ? c : a.$1.name.compareTo(b.$1.name);
      });
    }
    return out;
  }

  /// Quantos atendimentos (que acontecem de fato) há em um dia.
  int busyCount(DateTime day) => sessionsOn(day).where((e) => _happens(e.$2.outcome)).length;

  static bool _happens(LessonOutcome o) =>
      o == LessonOutcome.charged || o == LessonOutcome.makeUpCharged ||
      o == LessonOutcome.makeUpNotCharged || o == LessonOutcome.credit ||
      o == LessonOutcome.movedChargedHere || o == LessonOutcome.waived;

  bool happens(LessonOutcome o) => _happens(o);

  // ---------------------------------------------------------------- financeiro

  final List<Expense> _expenses = [];
  final List<ExtraIncome> _incomes = [];

  /// Todas as despesas cadastradas (fixas aparecem uma vez, com o mês de início).
  List<Expense> get allExpenses => List.unmodifiable(_expenses);
  List<ExtraIncome> get allIncomes => List.unmodifiable(_incomes);

  /// Meta de recebimento do ano (como no Coach Flow Pessoal).
  double annualGoal = 0;

  /// Meta do mês: a anual dividida por 12.
  double get monthlyGoal => annualGoal / 12;

  void setAnnualGoal(double value) {
    annualGoal = value < 0 ? 0 : value;
    sink?.saveProfile({
      'annual_goal': annualGoal,
      'monthly_goal': (annualGoal / 12 * 100).roundToDouble() / 100,
    });
    _changed();
  }

  /// Compatibilidade: define a meta a partir do valor mensal.
  void setGoal(double monthly) => setAnnualGoal(monthly * 12);

  // ---- previsões e estatísticas

  /// Previsão de um mês: quanto vai faturar, gastar e sobrar.
  MonthForecast forecast(DateTime month) {
    final m = DateTime(month.year, month.month);
    final active = activePlans;
    return MonthForecast(
      billed: active.fold(0.0, (s, p) => s + bill(p, month: m).total),
      received: clientReceived(m),
      open: active.fold(0.0, (s, p) => s + remaining(p, month: m)),
      extras: extraReceived(m),
      expensesPlanned: expensesTotal(m),
      expensesPaid: expensesPaid(m),
    );
  }

  /// Tudo o que entrou no ano (cobranças + ganhos extras).
  double yearIn(int year) {
    var total = 0.0;
    for (var mo = 1; mo <= 12; mo++) {
      total += totalIn(DateTime(year, mo));
    }
    return total;
  }

  /// Atendimentos do mês somados de todos os clientes ativos.
  SessionStats sessionStats(DateTime month) {
    final m = DateTime(month.year, month.month);
    var charged = 0, cancelCharged = 0, cancelWaived = 0, moved = 0, credits = 0, holidays = 0, makeUps = 0;
    for (final p in activePlans) {
      final b = bill(p, month: m);
      charged += b.chargedLessons;
      cancelCharged += b.cancelledCharged;
      cancelWaived += b.cancelledWaived;
      moved += b.movedOut;
      credits += b.credits;
      holidays += b.holidays;
      makeUps += b.makeUps;
    }
    return SessionStats(
      charged: charged,
      cancelledCharged: cancelCharged,
      cancelledWaived: cancelWaived,
      moved: moved,
      credits: credits,
      holidays: holidays,
      makeUps: makeUps,
    );
  }

  List<Expense> expensesFor(DateTime month) {
    final m = DateTime(month.year, month.month);
    final out = <Expense>[];
    for (final e in _expenses) {
      final start = DateTime(e.date.year, e.date.month);
      if (e.fixed) {
        final ended = e.endMonth != null && !m.isBefore(e.endMonth!);
        if (!m.isBefore(start) && !ended) {
          out.add(e.atMonth(m));
        }
      } else if (start == m) {
        out.add(e);
      }
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  List<Expense> get fixedExpenses => _expenses.where((e) => e.fixed && e.endMonth == null).toList();

  List<ExtraIncome> incomesFor(DateTime month) =>
      _incomes.where((e) => e.date.year == month.year && e.date.month == month.month).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  void addExpense(Expense e) {
    _expenses.add(e);
    sink?.saveExpense(e);
    _changed();
  }

  /// Avulsa: apaga. Fixa: deixa de repetir a partir do mês informado.
  void removeExpense(String id, {DateTime? fromMonth}) {
    final i = _expenses.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final e = _expenses[i];
    if (e.fixed && fromMonth != null) {
      final from = DateTime(fromMonth.year, fromMonth.month);
      final start = DateTime(e.date.year, e.date.month);
      if (!from.isAfter(start)) {
        _expenses.removeAt(i);
        sink?.deleteExpense(id);
      } else {
        _expenses[i] = e.endingAt(from);
        sink?.saveExpense(_expenses[i]);
      }
    } else {
      _expenses.removeAt(i);
      sink?.deleteExpense(id);
    }
    _changed();
  }

  Expense? expenseById(String id) {
    for (final e in _expenses) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _moveExpensePaid(String fromId, DateTime fromMonth, String toId, DateTime toMonth) {
    final old = _expKey(fromId, fromMonth);
    final paidOn = _expensePaid.remove(old);
    if (paidOn == null) return;
    _expensePaid[_expKey(toId, toMonth)] = paidOn;
    sink?.unpayExpense(fromId, DateTime(fromMonth.year, fromMonth.month));
    sink?.payExpense(toId, DateTime(toMonth.year, toMonth.month), paidOn);
  }

  /// Corrige uma despesa.
  ///
  /// Avulsa (ou fixa com [fromMonth] nulo): muda a despesa inteira, em todos os meses.
  /// Fixa com [fromMonth]: os meses anteriores ficam como estavam e a nova versão
  /// vale daquele mês em diante (as baixas desses meses vão junto).
  void updateExpense(String id, {
    required String description,
    required double amount,
    required DateTime date,
    required bool fixed,
    DateTime? fromMonth,
  }) {
    final i = _expenses.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final old = _expenses[i];
    final oldStart = DateTime(old.date.year, old.date.month);
    final from = fromMonth == null ? null : DateTime(fromMonth.year, fromMonth.month);
    if (old.fixed && from != null && from.isAfter(oldStart)) {
      _expenses[i] = old.endingAt(from);
      sink?.saveExpense(_expenses[i]);
      final next = Expense(
        id: newUuid(),
        description: description,
        amount: amount,
        date: DateTime(from.year, from.month, date.day),
        fixed: true,
        endMonth: old.endMonth,
      );
      _expenses.add(next);
      sink?.saveExpense(next);
      final moving = [
        for (final k in _expensePaid.keys)
          if (k.startsWith('$id|')) k,
      ];
      for (final k in moving) {
        final ym = k.split('|').last.split('-');
        final m = DateTime(int.parse(ym[0]), int.parse(ym[1]));
        if (!m.isBefore(from)) _moveExpensePaid(id, m, next.id, m);
      }
    } else {
      final start = old.fixed ? DateTime(old.date.year, old.date.month, date.day) : date;
      final updated = Expense(
        id: id,
        description: description,
        amount: amount,
        date: old.fixed && fixed ? start : date,
        fixed: fixed,
        endMonth: fixed ? old.endMonth : null,
      );
      if (!old.fixed && (old.date.year != date.year || old.date.month != date.month)) {
        _moveExpensePaid(id, old.date, id, date);
      }
      _expenses[i] = updated;
      sink?.saveExpense(updated);
    }
    _changed();
  }

  void updateIncome(ExtraIncome e) {
    final i = _incomes.indexWhere((x) => x.id == e.id);
    if (i < 0) return;
    _incomes[i] = e;
    sink?.addIncome(e);
    _changed();
  }

  void addIncome(ExtraIncome e) {
    _incomes.add(e);
    sink?.addIncome(e);
    _changed();
  }

  void removeIncome(String id) {
    _incomes.removeWhere((e) => e.id == id);
    sink?.deleteIncome(id);
    _changed();
  }

  /// Recebido de clientes no mês (pela data de competência da cobrança).
  double clientReceived(DateTime month) =>
      plans.fold(0.0, (s, p) => s + received(p.id, month: DateTime(month.year, month.month)));

  double extraReceived(DateTime month) => incomesFor(month).fold(0.0, (s, e) => s + e.amount);
  double expensesTotal(DateTime month) => expensesFor(month).fold(0.0, (s, e) => s + e.amount);
  double totalIn(DateTime month) => clientReceived(month) + extraReceived(month);

  // ---- baixa de despesas (cada mês de uma despesa fixa tem a sua baixa)

  final Map<String, DateTime> _expensePaid = {};

  String _expKey(String id, DateTime d) => '$id|${d.year}-${d.month}';

  /// Data em que a despesa daquele mês foi paga, ou `null` se ainda não foi.
  DateTime? paidAt(Expense e) => _expensePaid[_expKey(e.id, e.date)];

  ExpenseStatus expenseStatus(Expense e) {
    if (paidAt(e) != null) return ExpenseStatus.paid;
    return dateOnly(e.date).isBefore(today) ? ExpenseStatus.overdue : ExpenseStatus.open;
  }

  void payExpense(Expense e, {DateTime? on}) {
    final paidOn = dateOnly(on ?? today);
    _expensePaid[_expKey(e.id, e.date)] = paidOn;
    sink?.payExpense(e.id, DateTime(e.date.year, e.date.month), paidOn);
    _changed();
  }

  void unpayExpense(Expense e) {
    _expensePaid.remove(_expKey(e.id, e.date));
    sink?.unpayExpense(e.id, DateTime(e.date.year, e.date.month));
    _changed();
  }

  double expensesPaid(DateTime month) =>
      expensesFor(month).where((e) => paidAt(e) != null).fold(0.0, (s, e) => s + e.amount);

  double expensesOpen(DateTime month) =>
      expensesFor(month).where((e) => paidAt(e) == null).fold(0.0, (s, e) => s + e.amount);

  /// Sobrou no mês: tudo o que entrou menos as despesas já pagas.
  double result(DateTime month) => totalIn(month) - expensesPaid(month);

  /// Contas não pagas que venceram ou vencem nos próximos [days] dias (para a Secretária).
  List<Expense> billsDue({int days = 3}) {
    final limit = today.add(Duration(days: days));
    final out = <Expense>[];
    for (var k = 2; k >= 0; k--) {
      for (final e in expensesFor(DateTime(today.year, today.month - k))) {
        if (paidAt(e) == null && !dateOnly(e.date).isAfter(limit)) out.add(e);
      }
    }
    return out;
  }

  /// Todos os pagamentos de clientes registrados no mês, com o nome do cliente.
  List<(StudentPlan, PaymentEntry)> paymentsIn(DateTime month) {
    final out = <(StudentPlan, PaymentEntry)>[];
    for (final p in plans) {
      for (final e in payments(p.id, month: DateTime(month.year, month.month))) {
        out.add((p, e));
      }
    }
    out.sort((a, b) => b.$2.date.compareTo(a.$2.date));
    return out;
  }

  void _seedFinance(int y, int m) {
    _expenses.clear();
    _incomes.clear();
    final start = DateTime(y, m - 5, 5);
    _expenses.addAll([
      Expense(id: 'e-aluguel', description: 'Aluguel da sala', amount: 900, date: start, fixed: true),
      Expense(id: 'e-internet', description: 'Internet e telefone', amount: 150, date: DateTime(y, m - 5, 10), fixed: true),
      Expense(id: 'e-contador', description: 'Contador', amount: 250, date: DateTime(y, m - 5, 20), fixed: true),
      Expense(id: 'e-material', description: 'Material de trabalho', amount: 180, date: DateTime(y, m, 8)),
    ]);
    _incomes.addAll([
      ExtraIncome(id: 'i-1', description: 'Avaliação avulsa', amount: 200, date: DateTime(y, m, 3)),
      ExtraIncome(id: 'i-2', description: 'Palestra em empresa', amount: 600, date: DateTime(y, m - 1, 18)),
    ]);
    // Baixas: meses anteriores pagos; neste mês, só o que já passou, menos o contador.
    _expensePaid.clear();
    for (var k = 5; k >= 0; k--) {
      for (final e in expensesFor(DateTime(y, m - k))) {
        final pastMonth = k > 0;
        if (pastMonth || (e.date.isBefore(today) && e.id != 'e-contador')) {
          _expensePaid[_expKey(e.id, e.date)] = e.date;
        }
      }
    }
    // Meta: 10% acima do previsto do mês, arredondada.
    final expected = activePlans.fold(0.0, (s, p) => s + bill(p, month: DateTime(y, m)).total);
    annualGoal = ((expected * 1.1 * 12) / 1000).round() * 1000.0;
  }

  // ---------------------------------------------------------------- carregar do banco

  /// Troca todos os dados pelos que vieram do banco (conta real).
  void replaceAll({
    required List<StudentPlan> clients,
    required Map<String, Map<String, LessonRecord>> events,
    required List<Holiday> holidayList,
    required Map<String, Map<DateTime, List<PaymentEntry>>> payments,
    required List<Expense> expenses,
    required Map<String, Map<DateTime, DateTime>> expensePaidOn,
    required List<ExtraIncome> incomes,
    required BillingRules billingRules,
    required Terms vocabulary,
    required double goal,
    String pixHolder = '',
    String pixTown = '',
    required String pix,
    required String business,
  }) {
    plans
      ..clear()
      ..addAll(clients)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _events
      ..clear()
      ..addAll(events);
    holidays
      ..clear()
      ..addAll(holidayList)
      ..sort((a, b) => a.date.compareTo(b.date));
    _payments.clear();
    payments.forEach((id, byMonth) {
      byMonth.forEach((m, list) => _payments[_payKey(id, m)] = [...list]);
    });
    _expenses
      ..clear()
      ..addAll(expenses);
    _expensePaid.clear();
    expensePaidOn.forEach((id, byMonth) {
      byMonth.forEach((m, paidOn) => _expensePaid['$id|${m.year}-${m.month}'] = paidOn);
    });
    _incomes
      ..clear()
      ..addAll(incomes);
    rules = billingRules;
    terms = vocabulary;
    annualGoal = goal;
    pixKey = pix;
    businessName = business;
    pixName = pixHolder;
    pixCity = pixTown;
    DemoLedger.instance.setProfessionalPixKey(pix);
    selectedMonth = DateTime(today.year, today.month);
    _syncDashboard();
    notifyListeners();
  }

  /// Vocabulário e regras novos ao trocar de profissão (conta real: sem dados de exemplo).
  void applyProfession(ProfessionProfile prof, BillingModel model) {
    terms = prof.terms;
    sink?.saveProfile({
      'profession_id': prof.id,
      'profession_name': prof.name,
      'billing_model': model.name,
    });
    notifyListeners();
  }

  /// Feriados nacionais do ano (para contas novas).
  List<Holiday> nationalHolidays(int year) => [
        for (final h in _nationalHolidays(year))
          Holiday(id: newUuid(), date: h.date, name: h.name, noClass: h.noClass),
      ];

  // ---------------------------------------------------------------- integração

  void _changed() {
    _syncDashboard();
    notifyListeners();
  }

  /// Mantém o painel inicial e a secretária com os mesmos números desta tela.
  void _syncDashboard() {
    final ledger = DemoLedger.instance;
    final current = DateTime(today.year, today.month);
    final amounts = <String, double>{};
    final receivedMap = <String, double>{};
    final paid = <String, bool>{};
    final dueDays = <String, int>{};
    for (final p in activePlans) {
      amounts[p.name] = bill(p, month: current).total;
      receivedMap[p.name] = received(p.id, month: current);
      paid[p.name] = status(p, month: current) == BillStatus.paid;
      dueDays[p.name] = p.dueDay;
    }
    ledger.syncFromBilling(amounts: amounts, received: receivedMap, paid: paid, dueDays: dueDays);
  }

  /// Usado pelo app ao abrir a demonstração.
  void attach() => _syncDashboard();

  static String _short(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------- dados de exemplo

  static double _round10(double v) => (v / 10).round() * 10.0;

  /// Recria os dados de exemplo para a profissão e a forma de cobrança escolhidas.
  void seed(ProfessionProfile prof, BillingModel model) {
    sink = null;
    pixKey = '';
    businessName = '';
    pixName = '';
    pixCity = '';
    plans.clear();
    _events.clear();
    holidays.clear();
    _payments.clear();
    terms = prof.terms;
    rules = BillingRules(cancel: prof.cancelRule);
    selectedMonth = DateTime(today.year, today.month);

    final now = today;
    final y = now.year, m = now.month;
    final prev = previousMonth(y, m);
    final start = DateTime(y, m - 2);

    final base = prof.sampleRate;
    double rateFor(double factor) => switch (model) {
          BillingModel.perSession => _round10(base * factor),
          BillingModel.hourly => _round10(base * factor * 60 / prof.duration),
          BillingModel.monthly => _round10(base * factor * prof.perWeek * 4.3),
          BillingModel.package => _round10(base * factor * 10 * .9),
        };

    // Dias fixos: 2x por semana (seg/qua, ter/qui...) ou 1x por semana.
    final routines = prof.perWeek >= 2
        ? const [<int>{1, 3}, <int>{2, 4}, <int>{1, 3, 5}, <int>{5}]
        : const [<int>{1}, <int>{2}, <int>{3}, <int>{4}];
    const times = ['07:00', '18:30', '09:00', '14:00'];
    const people = [
      ('mariana', 'Mariana Costa', '11999990001', 1.0, 5),
      ('ricardo', 'Ricardo Almeida', '11999990002', .9, 10),
      ('fernanda', 'Fernanda Lima', '11999990003', .85, 15),
      ('paulo', 'Paulo Martins', '11999990004', 1.2, 28),
    ];
    for (var i = 0; i < people.length; i++) {
      final (id, name, phone, factor, due) = people[i];
      final days = prof.fixedRoutine ? routines[i] : <int>{};
      plans.add(StudentPlan(
        id: id,
        name: name,
        phone: phone,
        service: prof.services[i % prof.services.length],
        rate: rateFor(factor),
        weekdays: days,
        times: {for (final d in days) d: times[i]},
        dueDay: due,
        model: model,
        durationMinutes: prof.duration,
        packageSize: 10,
        packageStart: start,
      ));
    }

    holidays.addAll(_nationalHolidays(y));
    if (prev.year != y) holidays.insertAll(0, _nationalHolidays(prev.year));

    if (prof.fixedRoutine) {
      _seedRoutineScenarios(y, m, prev);
    } else {
      _seedAppointments(y, m, start);
    }

    // Pagamentos: meses anteriores quitados; no mês atual, um em dia e um parcial.
    for (final p in plans) {
      for (var k = 2; k >= 1; k--) {
        final mm = DateTime(y, m - k);
        final b = bill(p, month: mm);
        if (b.total > 0) {
          _payments[_payKey(p.id, mm)] = [PaymentEntry(amount: b.total, date: dueDateFor(p.dueDay, mm.year, mm.month))];
        }
      }
    }
    final current = DateTime(y, m);
    final marTotal = bill(plan('mariana'), month: current).total;
    if (marTotal > 0) {
      _payments[_payKey('mariana', current)] = [PaymentEntry(amount: marTotal, date: dueDateFor(5, y, m))];
    }
    final ricTotal = bill(plan('ricardo'), month: current).total;
    if (ricTotal > 0) {
      _payments[_payKey('ricardo', current)] = [
        PaymentEntry(amount: _round10(ricTotal * .4), date: dueDateFor(8, y, m), method: 'Dinheiro'),
      ];
    }
    _seedFinance(y, m);
    _syncDashboard();
    notifyListeners();
  }

  void _seedRoutineScenarios(int y, int m, DateTime prev) {
    List<DateTime> routine(String id) => routineDates(plan(id), y, m);
    final t = terms;

    // Mariana: remarcada para o dia seguinte.
    final mar = routine('mariana');
    if (mar.length > 2) {
      final original = mar[1];
      final target = original.add(const Duration(days: 1));
      _events.putIfAbsent('mariana', () => {})
        ..[dateKey(original)] = LessonRecord(status: LessonStatus.moved, newDate: target)
        ..[dateKey(target)] = LessonRecord(
            status: LessonStatus.rescheduled, originDate: original, note: 'Reposição de ${_short(original)}');
    }

    // Ricardo: crédito.
    final ric = routine('ricardo');
    if (ric.length > 2) {
      _events.putIfAbsent('ricardo', () => {})[dateKey(ric[2])] =
          LessonRecord(credit: true, note: '${t.sessionTitle} extra no mês passado');
    }

    // Fernanda: falta cobrada no mês passado e um cancelamento sem cobrança agora.
    final ferPrev = routineDates(plan('fernanda'), prev.year, prev.month);
    if (ferPrev.length > 2) {
      _events.putIfAbsent('fernanda', () => {})[dateKey(ferPrev[2])] =
          const LessonRecord(status: LessonStatus.cancelled, charge: true, note: 'Faltou sem avisar');
    }
    final fer = routine('fernanda');
    if (fer.length > 2) {
      _events.putIfAbsent('fernanda', () => {})[dateKey(fer[1])] =
          const LessonRecord(status: LessonStatus.cancelled, charge: false, note: 'Avisou com antecedência');
    }

    // Paulo: férias nos dois últimos atendimentos do mês.
    final pau = routine('paulo');
    if (pau.length >= 3) {
      for (final d in pau.sublist(pau.length - 2)) {
        _events.putIfAbsent('paulo', () => {})[dateKey(d)] =
            const LessonRecord(status: LessonStatus.cancelled, charge: false, note: 'Férias');
      }
    }
  }

  /// Sem rotina fixa: consultas avulsas espalhadas pelos últimos meses.
  void _seedAppointments(int y, int m, DateTime start) {
    const pattern = <String, List<int>>{
      'mariana': [6, 20],
      'ricardo': [9],
      'fernanda': [3, 14, 27],
      'paulo': [12, 26],
    };
    var cursor = start;
    while (!cursor.isAfter(DateTime(y, m))) {
      pattern.forEach((id, days) {
        for (final day in days) {
          final last = daysInMonth(cursor.year, cursor.month);
          var d = DateTime(cursor.year, cursor.month, day > last ? last : day);
          // Evita fins de semana.
          while (d.weekday > 5) {
            d = d.subtract(const Duration(days: 1));
          }
          _events.putIfAbsent(id, () => {})[dateKey(d)] = const LessonRecord(extra: true);
        }
      });
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    // Fernanda faltou a uma consulta do mês atual.
    final fer = _events['fernanda'];
    if (fer != null) {
      final key = dateKey(DateTime(y, m, 14));
      final match = fer.keys.where((k) => k.startsWith(dateKey(DateTime(y, m, 1)).substring(0, 8))).toList()..sort();
      final target = fer.containsKey(key) ? key : (match.isNotEmpty ? match.first : null);
      if (target != null) {
        fer[target] = const LessonRecord(
            status: LessonStatus.cancelled, charge: false, extra: true, note: 'Desmarcou no dia');
      }
    }
  }

  static List<Holiday> _nationalHolidays(int y) {
    final easter = _easter(y);
    final fixed = <(int, int, String)>[
      (1, 1, 'Confraternização Universal'),
      (4, 21, 'Tiradentes'),
      (5, 1, 'Dia do Trabalho'),
      (9, 7, 'Independência do Brasil'),
      (10, 12, 'Nossa Senhora Aparecida'),
      (11, 2, 'Finados'),
      (11, 15, 'Proclamação da República'),
      (11, 20, 'Consciência Negra'),
      (12, 25, 'Natal'),
    ];
    final list = [
      for (final (mo, d, name) in fixed) Holiday(id: 'h$y-$mo-$d', date: DateTime(y, mo, d), name: name),
      Holiday(id: 'h$y-sexta-santa', date: easter.subtract(const Duration(days: 2)), name: 'Sexta-feira Santa'),
      Holiday(id: 'h$y-carnaval', date: easter.subtract(const Duration(days: 47)), name: 'Carnaval', noClass: false),
    ];
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  /// Domingo de Páscoa (algoritmo de Meeus/Jones/Butcher).
  static DateTime _easter(int y) {
    final a = y % 19, b = y ~/ 100, c = y % 100, d = b ~/ 4, e = b % 4;
    final f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4, k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(y, month, day);
  }
}

/// Despesa do profissional. Fixas se repetem todo mês até serem encerradas.
class Expense {
  const Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    this.fixed = false,
    this.endMonth,
  });

  final String id;
  final String description;
  final double amount;

  /// Avulsa: data da despesa. Fixa: primeiro mês e dia de pagamento.
  final DateTime date;
  final bool fixed;

  /// Fixa: primeiro mês em que ela deixa de valer.
  final DateTime? endMonth;

  /// A mesma despesa fixa, posicionada em outro mês.
  Expense atMonth(DateTime month) {
    final last = DateTime(month.year, month.month + 1, 0).day;
    return Expense(
      id: id,
      description: description,
      amount: amount,
      date: DateTime(month.year, month.month, date.day > last ? last : date.day),
      fixed: fixed,
      endMonth: endMonth,
    );
  }

  Expense endingAt(DateTime month) => Expense(
        id: id, description: description, amount: amount, date: date, fixed: fixed, endMonth: month);
}

/// Ganho que não vem da cobrança mensal (avaliação avulsa, palestra...).
class ExtraIncome {
  const ExtraIncome({required this.id, required this.description, required this.amount, required this.date});
  final String id;
  final String description;
  final double amount;
  final DateTime date;
}

enum ExpenseStatus { paid, open, overdue }

/// Previsão de um mês.
class MonthForecast {
  const MonthForecast({
    required this.billed,
    required this.received,
    required this.open,
    required this.extras,
    required this.expensesPlanned,
    required this.expensesPaid,
  });

  /// Cobranças do mês (o que os clientes devem pagar).
  final double billed;
  final double received;
  final double open;

  /// Ganhos extras do mês (já recebidos).
  final double extras;
  final double expensesPlanned;
  final double expensesPaid;

  double get expensesOpen => (expensesPlanned - expensesPaid).clamp(0, double.infinity).toDouble();

  /// Quanto vai entrar no mês: cobranças + ganhos extras.
  double get incomePlanned => billed + extras;

  /// Quanto já entrou.
  double get incomeNow => received + extras;

  /// Sobra prevista: tudo o que vai entrar menos tudo o que vai sair.
  double get resultPlanned => incomePlanned - expensesPlanned;

  /// Sobra até agora: o que entrou menos o que foi pago.
  double get resultNow => incomeNow - expensesPaid;

  /// Parte das cobranças que ainda não foi paga, em %.
  int get openRate => billed <= 0 ? 0 : (open / billed * 100).round();
}

/// Atendimentos de um mês somados.
class SessionStats {
  const SessionStats({
    required this.charged,
    required this.cancelledCharged,
    required this.cancelledWaived,
    required this.moved,
    required this.credits,
    required this.holidays,
    required this.makeUps,
  });
  final int charged, cancelledCharged, cancelledWaived, moved, credits, holidays, makeUps;
  int get cancelled => cancelledCharged + cancelledWaived;
}
