import 'package:flutter/foundation.dart';

import '../demo_ledger.dart';
import '../profile/profession_profile.dart';
import 'billing_engine.dart';

/// Guarda clientes, atendimentos, feriados, regras e pagamentos da demonstração.
///
/// Tudo fica só na memória desta sessão. Na Etapa 3, esta classe passa a ler e
/// gravar no banco, mantendo o mesmo motor de cálculo.
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

    _removeMakeUpOf(map, previous, date);
    map[key] = LessonRecord(
      status: record.status,
      charge: record.charge,
      credit: record.credit,
      newDate: record.newDate,
      originDate: record.originDate,
      extra: previous?.extra ?? record.extra,
      note: record.note,
    );
    if (record.status == LessonStatus.moved) {
      map[dateKey(record.newDate!)] = LessonRecord(
        status: LessonStatus.rescheduled,
        originDate: dateOnly(date),
        note: 'Reposição de ${_short(date)}',
      );
    }
    _changed();
    return null;
  }

  /// Volta o atendimento ao normal. Se for avulso, ele é desmarcado.
  void clearLesson(String studentId, DateTime date) {
    final map = _events[studentId];
    if (map == null) return;
    final key = dateKey(date);
    final previous = map.remove(key);
    _removeMakeUpOf(map, previous, date);
    final origin = previous?.originDate;
    if (previous?.status == LessonStatus.rescheduled && origin != null) {
      final original = map[dateKey(origin)];
      // Se a original era avulsa, ela volta como avulsa agendada.
      if (original != null && original.extra) {
        map[dateKey(origin)] = const LessonRecord(extra: true);
      } else {
        map.remove(dateKey(origin));
      }
    }
    if (previous != null && previous.extra && previous.status != LessonStatus.scheduled) {
      // Avulso alterado: "voltar ao normal" mantém o atendimento marcado.
      map[key] = const LessonRecord(extra: true);
    }
    _changed();
  }

  /// Marca um atendimento avulso. Retorna erro, ou `null`.
  String? addExtra(String studentId, DateTime date, {String note = ''}) {
    final map = _events.putIfAbsent(studentId, () => {});
    final key = dateKey(date);
    if (map.containsKey(key) || plan(studentId).weekdays.contains(date.weekday)) {
      return 'Já existe ${terms.theSession} nessa data.';
    }
    map[key] = LessonRecord(extra: true, note: note);
    _changed();
    return null;
  }

  /// Desmarca um atendimento avulso.
  void removeExtra(String studentId, DateTime date) {
    final map = _events[studentId];
    if (map == null) return;
    final previous = map.remove(dateKey(date));
    _removeMakeUpOf(map, previous, date);
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
    final before = <String, LessonRecord?>{};
    for (final d in vacationPreview(studentId, start, end)) {
      final key = dateKey(d);
      before[key] = map[key];
      map[key] = LessonRecord(
        status: LessonStatus.cancelled,
        charge: false,
        extra: map[key]?.extra ?? false,
        note: reason,
      );
    }
    _changed();
    return before;
  }

  void restore(String studentId, Map<String, LessonRecord?> before) {
    final map = _events.putIfAbsent(studentId, () => {});
    before.forEach((key, record) {
      if (record == null) {
        map.remove(key);
      } else {
        map[key] = record;
      }
    });
    _changed();
  }

  // ---------------------------------------------------------------- pagamentos

  void addPayment(String studentId, PaymentEntry entry, {DateTime? month}) {
    _payments.putIfAbsent(_payKey(studentId, month ?? selectedMonth), () => []).add(entry);
    _changed();
  }

  void removeLastPayment(String studentId, {DateTime? month}) {
    final list = _payments[_payKey(studentId, month ?? selectedMonth)];
    if (list == null || list.isEmpty) return;
    list.removeLast();
    _changed();
  }

  void setDueDay(String studentId, int day) {
    final i = plans.indexWhere((p) => p.id == studentId);
    if (i < 0) return;
    plans[i] = plans[i].copyWith(dueDay: day);
    _changed();
  }

  // ---------------------------------------------------------------- regras e feriados

  void setRules(BillingRules value) {
    rules = value;
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
    _changed();
  }

  void removeHoliday(String id) {
    holidays.removeWhere((h) => h.id == id);
    _changed();
  }

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
