import 'package:flutter/foundation.dart';

import '../demo_ledger.dart';
import 'billing_engine.dart';

/// Guarda alunos, aulas, feriados, regras e pagamentos da demonstração.
///
/// Tudo fica só na memória desta sessão. Na Etapa 3, esta classe passa a ler e
/// gravar no banco, mantendo o mesmo motor de cálculo.
class BillingStore extends ChangeNotifier {
  BillingStore._() {
    _seed();
  }

  @visibleForTesting
  BillingStore.empty({DateTime? today}) : _today = today;

  static final BillingStore instance = BillingStore._();

  DateTime? _today;
  DateTime get today => dateOnly(_today ?? DateTime.now());

  final List<StudentPlan> plans = [];
  final Map<String, Map<String, LessonRecord>> _events = {};
  final List<Holiday> holidays = [];
  final Map<String, List<PaymentEntry>> _payments = {};
  BillingRules rules = const BillingRules();

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

  void shiftMonth(int delta) =>
      goToMonth(DateTime(selectedMonth.year, selectedMonth.month + delta));

  // ---------------------------------------------------------------- aulas

  /// Salva a situação de uma aula. Em remarcações, cria a reposição na nova data.
  /// Retorna uma mensagem de erro, ou `null` quando deu certo.
  String? saveLesson(String studentId, DateTime date, LessonRecord record) {
    final map = _events.putIfAbsent(studentId, () => {});
    final key = dateKey(date);
    final previous = map[key];

    if (record.status == LessonStatus.moved) {
      final target = record.newDate;
      if (target == null) return 'Escolha a nova data da aula.';
      if (dateOnly(target) == dateOnly(date)) return 'A nova data precisa ser diferente da original.';
      final existing = map[dateKey(target)];
      final isOwnMakeUp = existing?.originDate != null && dateOnly(existing!.originDate!) == dateOnly(date);
      if (existing != null && existing.status != LessonStatus.scheduled && !isOwnMakeUp) {
        return 'Já existe uma alteração nessa data. Escolha outro dia.';
      }
    }

    _removeMakeUpOf(map, previous, date);
    map[key] = record;
    if (record.status == LessonStatus.moved) {
      map[dateKey(record.newDate!)] = LessonRecord(
        status: LessonStatus.rescheduled,
        originDate: dateOnly(date),
        note: 'Reposição da aula de ${_short(date)}',
      );
    }
    _changed();
    return null;
  }

  /// Volta a aula ao normal (agendada e cobrada).
  void clearLesson(String studentId, DateTime date) {
    final map = _events[studentId];
    if (map == null) return;
    final key = dateKey(date);
    final previous = map.remove(key);
    _removeMakeUpOf(map, previous, date);
    // Se era uma reposição, a aula original volta a ser cobrada normalmente.
    final origin = previous?.originDate;
    if (previous?.status == LessonStatus.rescheduled && origin != null) {
      map.remove(dateKey(origin));
    }
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

  /// Datas que serão afetadas por férias no período.
  List<DateTime> vacationPreview(String studentId, DateTime start, DateTime end) =>
      routineDatesInRange(plan(studentId), start, end).where((d) {
        final r = eventsFor(studentId)[dateKey(d)];
        return r == null ||
            r.status == LessonStatus.scheduled ||
            (r.status == LessonStatus.cancelled && r.charge == false);
      }).toList();

  /// Marca férias: cancela as aulas do período sem cobrança.
  /// Retorna o estado anterior, para permitir desfazer.
  Map<String, LessonRecord?> applyVacation(String studentId, DateTime start, DateTime end, String reason) {
    final map = _events.putIfAbsent(studentId, () => {});
    final before = <String, LessonRecord?>{};
    for (final d in vacationPreview(studentId, start, end)) {
      final key = dateKey(d);
      before[key] = map[key];
      map[key] = LessonRecord(status: LessonStatus.cancelled, charge: false, note: reason);
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

  // ---------------------------------------------------------------- dados fictícios

  void _seed() {
    final now = today;
    final y = now.year, m = now.month;
    final prev = previousMonth(y, m);

    plans.addAll(const [
      StudentPlan(
        id: 'mariana', name: 'Mariana Costa', service: 'Treino funcional',
        phone: '11999990001', rate: 180, weekdays: {1, 3},
        times: {1: '07:00', 3: '07:00'}, dueDay: 5,
      ),
      StudentPlan(
        id: 'ricardo', name: 'Ricardo Almeida', service: 'Personal na academia',
        phone: '11999990002', rate: 150, weekdays: {2, 4},
        times: {2: '18:30', 4: '18:30'}, dueDay: 10,
      ),
      StudentPlan(
        id: 'fernanda', name: 'Fernanda Lima', service: 'Assessoria de corrida',
        phone: '11999990003', rate: 120, weekdays: {1, 3, 5},
        times: {1: '06:00', 3: '06:00', 5: '06:00'}, dueDay: 15,
      ),
      StudentPlan(
        id: 'paulo', name: 'Paulo Martins', service: 'Treino em casa',
        phone: '11999990004', rate: 200, weekdays: {5},
        times: {5: '09:00'}, dueDay: 28,
      ),
    ]);

    holidays.addAll(_nationalHolidays(y));
    if (prev.year != y) holidays.insertAll(0, _nationalHolidays(prev.year));

    List<DateTime> routine(String id) => routineDates(plan(id), y, m);
    List<DateTime> routinePrev(String id) => routineDates(plan(id), prev.year, prev.month);

    // Mariana: uma aula remarcada para o dia seguinte, no mesmo mês.
    final mar = routine('mariana');
    if (mar.length > 2) {
      final original = mar[1];
      saveLessonSilently('mariana', original,
          LessonRecord(status: LessonStatus.moved, newDate: original.add(const Duration(days: 1))));
    }

    // Ricardo: uma aula vira crédito.
    final ric = routine('ricardo');
    if (ric.length > 3) {
      _events.putIfAbsent('ricardo', () => {})[dateKey(ric[3])] =
          const LessonRecord(credit: true, note: 'Aula extra no mês passado');
    }

    // Fernanda: falta cobrada no mês passado (vira desconto agora) e
    // um cancelamento sem cobrança neste mês.
    final ferPrev = routinePrev('fernanda');
    if (ferPrev.length > 4) {
      _events.putIfAbsent('fernanda', () => {})[dateKey(ferPrev[4])] =
          const LessonRecord(status: LessonStatus.cancelled, charge: true, note: 'Faltou sem avisar');
    }
    final fer = routine('fernanda');
    if (fer.length > 2) {
      _events.putIfAbsent('fernanda', () => {})[dateKey(fer[2])] =
          const LessonRecord(status: LessonStatus.cancelled, charge: false, note: 'Avisou com antecedência');
    }

    // Paulo: férias nas duas últimas sextas do mês.
    final pau = routine('paulo');
    if (pau.length >= 2) {
      for (final d in pau.sublist(pau.length - 2)) {
        _events.putIfAbsent('paulo', () => {})[dateKey(d)] =
            const LessonRecord(status: LessonStatus.cancelled, charge: false, note: 'Férias');
      }
    }

    // Pagamentos do mês anterior: todos quitados.
    for (final p in plans) {
      final b = bill(p, month: prev);
      if (b.total > 0) {
        _payments[_payKey(p.id, prev)] = [
          PaymentEntry(amount: b.total, date: dueDateFor(p.dueDay, prev.year, prev.month)),
        ];
      }
    }
    // Mês atual: Mariana pagou tudo; Ricardo pagou uma parte.
    final current = DateTime(y, m);
    final marTotal = bill(plan('mariana'), month: current).total;
    _payments[_payKey('mariana', current)] = [
      PaymentEntry(amount: marTotal, date: dueDateFor(5, y, m)),
    ];
    _payments[_payKey('ricardo', current)] = [
      PaymentEntry(amount: 300, date: dueDateFor(8, y, m), method: 'Dinheiro'),
    ];
  }

  @visibleForTesting
  void saveLessonSilently(String id, DateTime date, LessonRecord record) {
    final map = _events.putIfAbsent(id, () => {});
    map[dateKey(date)] = record;
    if (record.status == LessonStatus.moved && record.newDate != null) {
      map[dateKey(record.newDate!)] = LessonRecord(
        status: LessonStatus.rescheduled,
        originDate: dateOnly(date),
        note: 'Reposição da aula de ${_short(date)}',
      );
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
      for (final (mo, d, name) in fixed)
        Holiday(id: 'h$y-$mo-$d', date: DateTime(y, mo, d), name: name),
      Holiday(
        id: 'h$y-sexta-santa',
        date: easter.subtract(const Duration(days: 2)),
        name: 'Sexta-feira Santa',
      ),
      Holiday(
        id: 'h$y-carnaval',
        date: easter.subtract(const Duration(days: 47)),
        name: 'Carnaval',
        noClass: false,
      ),
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
