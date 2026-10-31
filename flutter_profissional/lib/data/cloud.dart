import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../agenda_events.dart';
import '../booking.dart';
import '../billing/billing_engine.dart';
import '../billing/billing_store.dart';
import '../profile/profession_profile.dart';
import 'cloud_sink.dart';
import 'subscription.dart';

/// Situação da gravação: quantas mudanças estão sendo enviadas e o último erro.
class SyncStatus {
  const SyncStatus({this.pending = 0, this.error});
  final int pending;
  final String? error;
  bool get saving => pending > 0;
}

/// Lê e grava os dados do profissional no Supabase (tabelas cf_*).
///
/// As gravações entram numa fila e são feitas uma de cada vez, na ordem em
/// que aconteceram no app. Cada profissional só acessa as próprias linhas
/// (regras de segurança do banco).
class CloudService implements CloudSink {
  CloudService(this.db);

  final SupabaseClient db;
  final status = ValueNotifier(const SyncStatus());
  Future<void> _queue = Future.value();

  String get _uid => db.auth.currentUser!.id;

  static String _d(DateTime d) => dateKey(d);
  static String _m(DateTime d) => dateKey(DateTime(d.year, d.month, 1));
  static DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);
  static double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

  void _enqueue(Future<void> Function() op) {
    status.value = SyncStatus(pending: status.value.pending + 1, error: status.value.error);
    _queue = _queue.then((_) async {
      try {
        await op();
        status.value = SyncStatus(pending: status.value.pending - 1);
      } catch (e) {
        debugPrint('Coach Flow: falha ao salvar: $e');
        final text = '$e';
        status.value = SyncStatus(
          pending: status.value.pending - 1,
          error: text.contains('cf_limite_clientes')
              ? 'O plano Essencial vai até 15 clientes ativos. Esta alteração não foi salva.'
              : text.contains('row-level security') || text.contains('42501')
                  ? 'Sua conta está no modo somente leitura. Esta alteração não foi salva.'
                  : 'Não foi possível salvar a última alteração. Confira a internet e tente de novo.',
        );
      }
    });
  }

  /// Espera todas as gravações pendentes terminarem.
  Future<void> flush() => _queue;

  // ------------------------------------------------------------------ gravar

  Map<String, Object?> _client(StudentPlan p) => {
        'id': p.id,
        'name': p.name,
        'phone': p.phone,
        'service': p.service,
        'model': p.model.name,
        'rate': p.rate,
        'weekdays': (p.weekdays.toList()..sort()),
        'times': {for (final e in p.times.entries) '${e.key}': e.value},
        'duration_minutes': p.durationMinutes,
        'package_size': p.packageSize,
        'package_start': p.packageStart == null ? null : _d(p.packageStart!),
        'due_day': p.dueDay,
        'active': p.active,
        'pix_choice': p.pixChoice,
      };

  @override
  void saveClient(StudentPlan p) => _enqueue(() => db.from('cf_clients').upsert(_client(p)));

  @override
  void syncSessions(String clientId, Map<String, LessonRecord> upserts, List<String> deletes) {
    _enqueue(() async {
      if (upserts.isNotEmpty) {
        await db.from('cf_sessions').upsert([
          for (final e in upserts.entries)
            {
              'client_id': clientId,
              'date': e.key,
              'status': e.value.status.name,
              'charge': e.value.charge,
              'credit': e.value.credit,
              'new_date': e.value.newDate == null ? null : _d(e.value.newDate!),
              'origin_date': e.value.originDate == null ? null : _d(e.value.originDate!),
              'extra': e.value.extra,
              'note': e.value.note,
              'time': e.value.time,
            },
        ], onConflict: 'client_id,date');
      }
      if (deletes.isNotEmpty) {
        await db.from('cf_sessions').delete().eq('client_id', clientId).inFilter('date', deletes);
      }
    });
  }

  @override
  void addPayment(String clientId, DateTime month, PaymentEntry entry) => _enqueue(() => db.from('cf_payments').insert({
        'id': entry.id,
        'client_id': clientId,
        'month': _m(month),
        'amount': entry.amount,
        'paid_on': _d(entry.date),
        'method': entry.method,
      }));

  @override
  void deletePayment(String id) => _enqueue(() => db.from('cf_payments').delete().eq('id', id));

  @override
  void saveHoliday(Holiday h) => _enqueue(() => db.from('cf_holidays').upsert({
        'id': h.id,
        'date': _d(h.date),
        'name': h.name,
        'no_class': h.noClass,
      }));

  @override
  void deleteHoliday(String id) => _enqueue(() => db.from('cf_holidays').delete().eq('id', id));

  @override
  void saveExpense(Expense e) => _enqueue(() => db.from('cf_expenses').upsert({
        'id': e.id,
        'description': e.description,
        'amount': e.amount,
        'date': _d(e.date),
        'fixed': e.fixed,
        'end_month': e.endMonth == null ? null : _m(e.endMonth!),
      }));

  @override
  void deleteExpense(String id) => _enqueue(() => db.from('cf_expenses').delete().eq('id', id));

  @override
  void payExpense(String expenseId, DateTime month, DateTime paidOn) => _enqueue(() => db
      .from('cf_expense_payments')
      .upsert({'expense_id': expenseId, 'month': _m(month), 'paid_on': _d(paidOn)}, onConflict: 'expense_id,month'));

  @override
  void unpayExpense(String expenseId, DateTime month) => _enqueue(
      () => db.from('cf_expense_payments').delete().eq('expense_id', expenseId).eq('month', _m(month)));

  @override
  void addIncome(ExtraIncome e) => _enqueue(() => db.from('cf_incomes').upsert({
        'id': e.id,
        'description': e.description,
        'amount': e.amount,
        'date': _d(e.date),
      }));

  @override
  void deleteIncome(String id) => _enqueue(() => db.from('cf_incomes').delete().eq('id', id));

  @override
  void saveProfile(Map<String, Object?> fields) =>
      _enqueue(() => db.from('cf_profiles').upsert({'owner_id': _uid, ...fields}, onConflict: 'owner_id'));

  // ------------------------------------------------------------------ ler

  /// Lê uma tabela inteira em páginas de 1.000 linhas.
  Future<List<Map<String, dynamic>>> _all(String table, {String order = 'created_at'}) async {
    const page = 1000;
    final out = <Map<String, dynamic>>[];
    for (var from = 0;; from += page) {
      final rows = await db.from(table).select().order(order).range(from, from + page - 1);
      out.addAll(rows);
      if (rows.length < page) break;
    }
    return out;
  }

  /// Carrega tudo do profissional logado para dentro do app.
  /// Retorna `false` quando a conta ainda não tem perfil (primeiro acesso).
  Future<bool> load(BillingStore store) async {
    final profileRows = await db.from('cf_profiles').select().limit(1);
    if (profileRows.isEmpty) return false;
    final pr = profileRows.first;

    final results = await Future.wait([
      _all('cf_clients'),
      _all('cf_sessions', order: 'date'),
      _all('cf_holidays', order: 'date'),
      _all('cf_payments'),
      _all('cf_expenses'),
      _all('cf_expense_payments', order: 'month'),
      _all('cf_incomes'),
    ]);
    final [clients, sessions, holidays, payments, expenses, expensePayments, incomes] = results;

    var prof = professionById(pr['profession_id'] as String? ?? 'outra');
    final customName = pr['profession_name'] as String?;
    if (prof.id == 'outra' && customName != null && customName.isNotEmpty) prof = prof.withName(customName);
    final model = BillingModel.values.asNameMap()[pr['billing_model']] ?? prof.defaultModel;
    ProfessionalProfile.instance.choose(prof, model);

    final plans = [
      for (final c in clients)
        StudentPlan(
          id: c['id'] as String,
          name: c['name'] as String,
          phone: c['phone'] as String? ?? '',
          service: c['service'] as String? ?? '',
          model: BillingModel.values.asNameMap()[c['model']] ?? BillingModel.perSession,
          rate: _num(c['rate']),
          weekdays: {for (final d in (c['weekdays'] as List? ?? const [])) (d as num).toInt()},
          times: {
            for (final e in ((c['times'] as Map?) ?? const {}).entries)
              int.parse(e.key as String): e.value as String,
          },
          durationMinutes: (c['duration_minutes'] as num?)?.toInt() ?? 60,
          packageSize: (c['package_size'] as num?)?.toInt() ?? 10,
          packageStart: _date(c['package_start']),
          dueDay: (c['due_day'] as num?)?.toInt() ?? 5,
          active: c['active'] as bool? ?? true,
          pixChoice: (c['pix_choice'] as num?)?.toInt() ?? 1,
        ),
    ];

    final events = <String, Map<String, LessonRecord>>{};
    for (final s in sessions) {
      events.putIfAbsent(s['client_id'] as String, () => {})[s['date'] as String] = LessonRecord(
        status: LessonStatus.values.asNameMap()[s['status']] ?? LessonStatus.scheduled,
        charge: s['charge'] as bool?,
        credit: s['credit'] as bool? ?? false,
        newDate: _date(s['new_date']),
        originDate: _date(s['origin_date']),
        extra: s['extra'] as bool? ?? false,
        note: s['note'] as String? ?? '',
        time: s['time'] as String?,
      );
    }

    final paymentMap = <String, Map<DateTime, List<PaymentEntry>>>{};
    for (final p in payments) {
      final m = _date(p['month'])!;
      paymentMap.putIfAbsent(p['client_id'] as String, () => {}).putIfAbsent(DateTime(m.year, m.month), () => []).add(
            PaymentEntry(
              id: p['id'] as String,
              amount: _num(p['amount']),
              date: _date(p['paid_on'])!,
              method: p['method'] as String? ?? 'Pix',
            ),
          );
    }

    final paidOn = <String, Map<DateTime, DateTime>>{};
    for (final e in expensePayments) {
      final m = _date(e['month'])!;
      paidOn.putIfAbsent(e['expense_id'] as String, () => {})[DateTime(m.year, m.month)] = _date(e['paid_on'])!;
    }

    store.replaceAll(
      clients: plans,
      events: events,
      holidayList: [
        for (final h in holidays)
          Holiday(
            id: h['id'] as String,
            date: _date(h['date'])!,
            name: h['name'] as String,
            noClass: h['no_class'] as bool? ?? true,
          ),
      ],
      payments: paymentMap,
      expenses: [
        for (final e in expenses)
          Expense(
            id: e['id'] as String,
            description: e['description'] as String,
            amount: _num(e['amount']),
            date: _date(e['date'])!,
            fixed: e['fixed'] as bool? ?? false,
            endMonth: _date(e['end_month']),
          ),
      ],
      expensePaidOn: paidOn,
      incomes: [
        for (final i in incomes)
          ExtraIncome(
            id: i['id'] as String,
            description: i['description'] as String,
            amount: _num(i['amount']),
            date: _date(i['date'])!,
          ),
      ],
      billingRules: BillingRules(
        cancel: CancelRule.values.asNameMap()[pr['cancel_rule']] ?? prof.cancelRule,
        holiday: HolidayRule.values.asNameMap()[pr['holiday_rule']] ?? HolidayRule.noCharge,
        move: MoveRule.values.asNameMap()[pr['move_rule']] ?? MoveRule.chargeNewMonth,
      ),
      vocabulary: prof.terms,
      goal: _num(pr['annual_goal']) > 0 ? _num(pr['annual_goal']) : _num(pr['monthly_goal']) * 12,
      pix: pr['pix_key'] as String? ?? '',
      business: pr['business_name'] as String? ?? '',
      pixHolder: pr['pix_name'] as String? ?? '',
      pixTown: pr['pix_city'] as String? ?? '',
      pixLabel1: pr['pix_label'] as String? ?? '',
      pix2: pr['pix_key_2'] as String? ?? '',
      pixHolder2: pr['pix_name_2'] as String? ?? '',
      pixLabel2nd: pr['pix_label_2'] as String? ?? '',
    );
    store.sink = this;
    await refreshSubscription(store);
    await AgendaEvents.instance.load();
    await Booking.instance.load();
    return true;
  }

  /// Lê a situação da assinatura (teste, ativa, atraso, somente leitura).
  Future<void> refreshSubscription(BillingStore store) async {
    try {
      final data = await db.rpc('cf_my_subscription');
      store.setSubscription(SubscriptionInfo.fromJson(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      debugPrint('Coach Flow: falha ao ler a assinatura: $e');
    }
  }

  /// Primeiro acesso: cria o perfil e os feriados nacionais deste ano e do próximo.
  Future<void> createProfile(BillingStore store, ProfessionProfile prof, BillingModel model) async {
    final year = DateTime.now().year;
    final holidays = [...store.nationalHolidays(year), ...store.nationalHolidays(year + 1)];
    await db.from('cf_profiles').upsert({
      'owner_id': _uid,
      'profession_id': prof.id,
      'profession_name': prof.name,
      'billing_model': model.name,
      'cancel_rule': prof.cancelRule.name,
    }, onConflict: 'owner_id');
    await db.from('cf_holidays').insert([
      for (final h in holidays) {'id': h.id, 'date': _d(h.date), 'name': h.name, 'no_class': h.noClass},
    ]);
    await load(store);
  }
}
