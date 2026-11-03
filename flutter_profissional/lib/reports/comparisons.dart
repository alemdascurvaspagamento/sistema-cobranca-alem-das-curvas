import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_store.dart';

String _ym(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}-01';

/// O que um cliente gerou de cobrança num mês (a parte que depende do preço e da agenda).
class ClientMonth {
  const ClientMonth({
    required this.name,
    required this.billed,
    required this.lessons,
    required this.unit,
    required this.waived,
    required this.holidays,
    required this.makeUps,
    required this.perLesson,
  });

  final String name;

  /// Valor cobrado no mês.
  final double billed;

  /// Aulas cobradas (já sem as faltas não cobradas e os feriados).
  final int lessons;

  /// Valor de cada aula.
  final double unit;

  /// Faltas que não foram cobradas.
  final int waived;

  /// Aulas que caíram em feriado.
  final int holidays;
  final int makeUps;

  /// Cobra por aula (ou por hora)? Mensalidade e pacote não dependem do número de aulas.
  final bool perLesson;

  Map<String, Object> toJson() => {
        'n': name,
        'b': billed,
        'l': lessons,
        'u': unit,
        'w': waived,
        'h': holidays,
        'mk': makeUps,
        'pl': perLesson,
      };

  factory ClientMonth.fromJson(Map m) => ClientMonth(
        name: '${m['n'] ?? ''}',
        billed: (m['b'] as num?)?.toDouble() ?? 0,
        lessons: (m['l'] as num?)?.toInt() ?? 0,
        unit: (m['u'] as num?)?.toDouble() ?? 0,
        waived: (m['w'] as num?)?.toInt() ?? 0,
        holidays: (m['h'] as num?)?.toInt() ?? 0,
        makeUps: (m['mk'] as num?)?.toInt() ?? 0,
        perLesson: m['pl'] as bool? ?? true,
      );

  ClientMonth plus(ClientMonth o) => ClientMonth(
        name: name.isEmpty ? o.name : name,
        billed: billed + o.billed,
        lessons: lessons + o.lessons,
        // Média ponderada pelo número de aulas.
        unit: (lessons + o.lessons) == 0 ? (unit == 0 ? o.unit : unit) : (unit * lessons + o.unit * o.lessons) / (lessons + o.lessons),
        waived: waived + o.waived,
        holidays: holidays + o.holidays,
        makeUps: makeUps + o.makeUps,
        perLesson: perLesson && o.perLesson,
      );

  static const zero = ClientMonth(name: '', billed: 0, lessons: 0, unit: 0, waived: 0, holidays: 0, makeUps: 0, perLesson: true);
}

/// Fotografia dos meses: o mês atual e o anterior são calculados na hora;
/// os mais antigos ficam congelados, para que mudar o preço de alguém hoje
/// não altere o passado.
class Snapshots {
  Snapshots._();
  static final instance = Snapshots._();

  final Map<String, Map<String, ClientMonth>> _frozen = {};
  bool _cloud = false;

  SupabaseClient get _db => Supabase.instance.client;

  void clear() {
    _frozen.clear();
    _cloud = false;
  }

  /// Carrega as fotografias e grava as que faltam (ou as do mês atual e anterior).
  Future<void> load() async {
    try {
      final rows = await _db.from('cf_month_snapshots').select('month, data');
      _frozen.clear();
      for (final r in rows) {
        final data = (r['data'] as Map?) ?? const {};
        final clients = (data['clients'] as Map?) ?? const {};
        _frozen['${r['month']}'.substring(0, 10)] = {
          for (final e in clients.entries) '${e.key}': ClientMonth.fromJson(e.value as Map),
        };
      }
      _cloud = true;
      unawaited(_saveMissing());
    } catch (e) {
      debugPrint('Avora: fotografias mensais indisponíveis ($e)');
    }
  }

  DateTime get _today => BillingStore.instance.today;

  /// Meses antes do anterior ao atual já estão fechados.
  bool _isClosed(DateTime m) {
    final prev = DateTime(_today.year, _today.month - 1);
    return m.isBefore(prev);
  }

  /// Primeiro mês com algum dado (até 3 anos para trás).
  DateTime firstMonth() {
    final store = BillingStore.instance;
    var first = DateTime(_today.year, _today.month);
    for (final p in store.plans) {
      final s = store.clientStart(p);
      if (s.isBefore(first)) first = s;
    }
    for (final e in store.allExpenses) {
      final s = DateTime(e.date.year, e.date.month);
      if (s.isBefore(first)) first = s;
    }
    for (final i in store.allIncomes) {
      final s = DateTime(i.date.year, i.date.month);
      if (s.isBefore(first)) first = s;
    }
    final limit = DateTime(_today.year - 3, _today.month);
    return first.isBefore(limit) ? limit : first;
  }

  Future<void> _saveMissing() async {
    if (!_cloud) return;
    final rows = <Map<String, Object>>[];
    final last = DateTime(_today.year, _today.month);
    for (var m = firstMonth(); !m.isAfter(last); m = DateTime(m.year, m.month + 1)) {
      final key = _ym(m);
      if (_isClosed(m) && _frozen.containsKey(key)) continue;
      final live = computeClients(m);
      if (_isClosed(m)) _frozen[key] = live;
      rows.add({
        'month': key,
        'data': {'clients': {for (final e in live.entries) e.key: e.value.toJson()}},
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    if (rows.isEmpty) return;
    try {
      await _db.from('cf_month_snapshots').upsert(rows, onConflict: 'owner_id,month');
    } catch (e) {
      debugPrint('Avora: não gravou fotografias mensais ($e)');
    }
  }

  /// Cobrança de cada cliente no mês, calculada agora.
  static Map<String, ClientMonth> computeClients(DateTime month) {
    final store = BillingStore.instance;
    final m = DateTime(month.year, month.month);
    final out = <String, ClientMonth>{};
    for (final p in store.plans) {
      if (!store.clientInMonth(p, m)) continue;
      final b = store.bill(p, month: m);
      out[p.id] = ClientMonth(
        name: p.name,
        billed: b.total,
        lessons: b.billedLessons,
        unit: p.unitPrice,
        waived: b.cancelledWaived + b.waived,
        holidays: b.holidays,
        makeUps: b.makeUps,
        perLesson: p.model == BillingModel.perSession || p.model == BillingModel.hourly,
      );
    }
    return out;
  }

  /// Cobrança por cliente do mês: congelada se o mês já fechou, senão calculada agora.
  Map<String, ClientMonth> clientsOf(DateTime month) {
    final m = DateTime(month.year, month.month);
    if (_isClosed(m)) {
      final f = _frozen[_ym(m)];
      if (f != null) return f;
    }
    return computeClients(m);
  }
}

// ---------------------------------------------------------------------------
// Períodos
// ---------------------------------------------------------------------------

enum PeriodKind { month, quarter, semester, year }

extension PeriodKindLabel on PeriodKind {
  String get label => switch (this) {
        PeriodKind.month => 'Mês',
        PeriodKind.quarter => 'Trimestre',
        PeriodKind.semester => 'Semestre',
        PeriodKind.year => 'Ano',
      };

  int get size => switch (this) {
        PeriodKind.month => 1,
        PeriodKind.quarter => 3,
        PeriodKind.semester => 6,
        PeriodKind.year => 12,
      };
}

/// Um período do calendário: novembro/2026, 4º trimestre/2026, 2º semestre/2026, 2026...
class Period {
  const Period(this.kind, this.year, this.index);

  /// [index] começa em 0: mês 0..11, trimestre 0..3, semestre 0..1, ano 0.
  final PeriodKind kind;
  final int year;
  final int index;

  factory Period.containing(PeriodKind kind, DateTime d) => Period(kind, d.year, (d.month - 1) ~/ kind.size);

  DateTime get start => DateTime(year, index * kind.size + 1);

  List<DateTime> get months => [for (var i = 0; i < kind.size; i++) DateTime(start.year, start.month + i)];

  Period get previous {
    final count = 12 ~/ kind.size;
    return index == 0 ? Period(kind, year - 1, count - 1) : Period(kind, year, index - 1);
  }

  Period get next {
    final count = 12 ~/ kind.size;
    return index == count - 1 ? Period(kind, year + 1, 0) : Period(kind, year, index + 1);
  }

  Period get sameLastYear => Period(kind, year - 1, index);

  String get label => switch (kind) {
        PeriodKind.month => '${_cap(monthNames[index])} de $year',
        PeriodKind.quarter => '${index + 1}º trimestre de $year',
        PeriodKind.semester => '${index + 1}º semestre de $year',
        PeriodKind.year => '$year',
      };

  String get short => switch (kind) {
        PeriodKind.month => '${monthNames[index].substring(0, 3)}/${year % 100}',
        PeriodKind.quarter => '${index + 1}º tri/${year % 100}',
        PeriodKind.semester => '${index + 1}º sem/${year % 100}',
        PeriodKind.year => '$year',
      };

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ---------------------------------------------------------------------------
// Números de um período
// ---------------------------------------------------------------------------

class PeriodNumbers {
  PeriodNumbers({required this.period, required this.months, required this.until});

  final Period period;

  /// Meses que entram na conta (os futuros ficam de fora).
  final List<DateTime> months;

  /// Último mês considerado (período em andamento termina "até agora").
  final DateTime until;

  double received = 0;
  double extras = 0;
  double billed = 0;
  double expenses = 0;
  double expFixed = 0;
  double expInstallment = 0;
  double expExtra = 0;
  final Map<String, double> expenseItems = {};
  final Map<String, ClientMonth> clients = {};
  final Map<String, double> clientReceived = {};

  /// Por mês: ganhos e gastos (para o mês a mês).
  final List<({DateTime month, double income, double expenses})> perMonth = [];

  double get income => received + extras;
  double get result => income - expenses;
  double? get margin => income > 0 ? result / income : null;
  double get open => (billed - received).clamp(0, double.infinity).toDouble();
  int get activeClients => {
        for (final e in clients.entries) if (e.value.billed > 0) e.key,
        for (final e in clientReceived.entries) if (e.value > 0) e.key,
      }.length;
  int get lessons => clients.values.fold(0, (s, c) => s + c.lessons);
  int get waived => clients.values.fold(0, (s, c) => s + c.waived);
  int get holidays => clients.values.fold(0, (s, c) => s + c.holidays);
  double? get perLessonValue {
    final pl = clients.values.where((c) => c.perLesson);
    final l = pl.fold(0, (s, c) => s + c.lessons);
    return l == 0 ? null : pl.fold(0.0, (s, c) => s + c.billed) / l;
  }

  double? get perClientIncome => activeClients == 0 ? null : received / activeClients;

  bool get hasData => income > 0 || expenses > 0 || billed > 0;

  bool get isPartial => months.length < period.months.length;

  static PeriodNumbers of(Period p) {
    final store = BillingStore.instance;
    final today = store.today;
    final current = DateTime(today.year, today.month);
    final months = [for (final m in p.months) if (!m.isAfter(current)) m];
    final n = PeriodNumbers(period: p, months: months, until: months.isEmpty ? p.start : months.last);
    for (final m in months) {
      final rec = store.clientReceived(m);
      final ext = store.extraReceived(m);
      final exps = store.expensesFor(m);
      final expTotal = exps.fold(0.0, (s, e) => s + e.amount);
      n.received += rec;
      n.extras += ext;
      n.expenses += expTotal;
      for (final e in exps) {
        if (e.isInstallment) {
          n.expInstallment += e.amount;
        } else if (e.fixed) {
          n.expFixed += e.amount;
        } else {
          n.expExtra += e.amount;
        }
        final key = e.description.trim().toLowerCase();
        n.expenseItems[key] = (n.expenseItems[key] ?? 0) + e.amount;
      }
      for (final e in Snapshots.instance.clientsOf(m).entries) {
        n.billed += e.value.billed;
        n.clients[e.key] = (n.clients[e.key] ?? ClientMonth.zero).plus(e.value);
      }
      for (final p in store.plans) {
        final r = store.received(p.id, month: m);
        if (r > 0) n.clientReceived[p.id] = (n.clientReceived[p.id] ?? 0) + r;
      }
      n.perMonth.add((month: m, income: rec + ext, expenses: expTotal));
    }
    return n;
  }
}

// ---------------------------------------------------------------------------
// Por que mudou
// ---------------------------------------------------------------------------

/// Uma causa da diferença entre os dois períodos, em reais.
class Driver {
  const Driver(this.label, this.amount, {this.detail = ''});
  final String label;
  final double amount;
  final String detail;
}

class Comparison {
  Comparison(this.current, this.base);
  final PeriodNumbers current;
  final PeriodNumbers base;

  String _names(Iterable<String> ids, Map<String, ClientMonth> a, Map<String, ClientMonth> b) {
    final names = [
      for (final id in ids) ((a[id]?.name.isNotEmpty ?? false) ? a[id]!.name : (b[id]?.name ?? '')).split(' ').first,
    ].where((s) => s.isNotEmpty).toList();
    if (names.isEmpty) return '';
    if (names.length <= 3) return names.join(', ');
    return '${names.take(3).join(', ')} e mais ${names.length - 3}';
  }

  /// Causas da variação dos ganhos. A soma é exatamente a diferença de ganhos.
  List<Driver> incomeDrivers() {
    final t = BillingStore.instance.terms;
    final cur = current, b = base;
    bool inCur(String id) => (cur.clients[id]?.billed ?? 0) > 0 || (cur.clientReceived[id] ?? 0) > 0;
    bool inBase(String id) => (b.clients[id]?.billed ?? 0) > 0 || (b.clientReceived[id] ?? 0) > 0;
    final ids = {...cur.clients.keys, ...b.clients.keys, ...cur.clientReceived.keys, ...b.clientReceived.keys};
    final newIds = [for (final id in ids) if (inCur(id) && !inBase(id)) id];
    final goneIds = [for (final id in ids) if (!inCur(id) && inBase(id)) id];
    final stay = [for (final id in ids) if (inCur(id) && inBase(id)) id];

    final newValue = newIds.fold(0.0, (s, id) => s + (cur.clientReceived[id] ?? 0));
    final goneValue = goneIds.fold(0.0, (s, id) => s + (b.clientReceived[id] ?? 0));

    var price = 0.0, lessonsOther = 0.0, waived = 0.0, holidays = 0.0, fixedPlans = 0.0, late = 0.0;
    var dWaived = 0, dHolidays = 0, dLessons = 0;
    for (final id in stay) {
      final c = cur.clients[id] ?? ClientMonth.zero;
      final o = b.clients[id] ?? ClientMonth.zero;
      final cr = cur.clientReceived[id] ?? 0;
      final br = b.clientReceived[id] ?? 0;
      final dBilled = c.billed - o.billed;
      if (c.perLesson && o.perLesson) {
        final unitBase = o.unit == 0 ? c.unit : o.unit;
        price += (c.unit - unitBase) * c.lessons;
        final lessonEffect = (c.lessons - o.lessons) * unitBase;
        final wEff = -(c.waived - o.waived) * unitBase;
        final hEff = -(c.holidays - o.holidays) * unitBase;
        waived += wEff;
        holidays += hEff;
        lessonsOther += lessonEffect - wEff - hEff;
        // O que sobrar de arredondamento vai para "outras aulas".
        lessonsOther += dBilled - ((c.unit - unitBase) * c.lessons + lessonEffect);
        dWaived += c.waived - o.waived;
        dHolidays += c.holidays - o.holidays;
        dLessons += c.lessons - o.lessons;
      } else {
        fixedPlans += dBilled;
      }
      // Recebido x cobrado: mais atraso agora = menos dinheiro.
      late += (cr - c.billed) - (br - o.billed);
    }
    final dExtras = cur.extras - b.extras;

    String plural(int n, String one, String many) => n.abs() == 1 ? one : many;
    final drivers = <Driver>[
      if (newIds.isNotEmpty)
        Driver('${newIds.length} ${plural(newIds.length, '${t.client} nov${t.g('a', 'o')}', '${t.clients} nov${t.g('as', 'os')}')}', newValue,
            detail: _names(newIds, cur.clients, b.clients)),
      if (goneIds.isNotEmpty)
        Driver('${goneIds.length} ${plural(goneIds.length, '${t.client} que saiu', '${t.clients} que saíram')}', -goneValue,
            detail: _names(goneIds, b.clients, cur.clients)),
      if (dWaived != 0 || waived.abs() >= 0.5)
        Driver(
          dWaived > 0
              ? '$dWaived ${plural(dWaived, 'falta não cobrada', 'faltas não cobradas')} a mais'
              : '${-dWaived} ${plural(dWaived, 'falta não cobrada', 'faltas não cobradas')} a menos',
          waived,
        ),
      if (dHolidays != 0 || holidays.abs() >= 0.5)
        Driver(
          dHolidays > 0
              ? '$dHolidays ${plural(dHolidays, '${t.session} em feriado', '${t.sessions} em feriado')} a mais'
              : '${-dHolidays} ${plural(dHolidays, '${t.session} em feriado', '${t.sessions} em feriado')} a menos',
          holidays,
        ),
      if (lessonsOther.abs() >= 0.5)
        Driver(
          lessonsOther > 0 ? 'Mais ${t.sessions} na agenda' : 'Menos ${t.sessions} na agenda',
          lessonsOther,
          detail: 'Dias no mês, reposições, avulsas e mudanças de rotina',
        ),
      if (price.abs() >= 0.5) Driver(price > 0 ? 'Aumento de preço' : 'Redução de preço', price),
      if (fixedPlans.abs() >= 0.5) Driver('Mensalidades e pacotes', fixedPlans),
      if (late.abs() >= 0.5)
        Driver(late < 0 ? 'Mais pagamentos em aberto' : 'Menos pagamentos em aberto', late,
            detail: late < 0 ? 'Cobrado, mas ainda não recebido' : 'Recebeu atrasados ou houve menos atraso'),
      if (dExtras.abs() >= 0.5) Driver(dExtras > 0 ? 'Mais ganhos extras' : 'Menos ganhos extras', dExtras),
    ];
    drivers.sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
    return drivers;
  }

  /// Causas da variação dos gastos: tipos de despesa e as contas que mais mudaram.
  List<Driver> expenseDrivers() {
    final cur = current, b = base;
    final drivers = <Driver>[
      if ((cur.expFixed - b.expFixed).abs() >= 0.5) Driver('Despesas fixas', cur.expFixed - b.expFixed),
      if ((cur.expInstallment - b.expInstallment).abs() >= 0.5) Driver('Parcelas', cur.expInstallment - b.expInstallment),
      if ((cur.expExtra - b.expExtra).abs() >= 0.5) Driver('Extraordinárias', cur.expExtra - b.expExtra),
    ];
    return drivers;
  }

  /// As contas que mais mudaram (nome da despesa).
  List<Driver> topExpenseItems({int count = 4}) {
    final keys = {...current.expenseItems.keys, ...base.expenseItems.keys};
    final items = [
      for (final k in keys)
        if (((current.expenseItems[k] ?? 0) - (base.expenseItems[k] ?? 0)).abs() >= 0.5)
          Driver(_cap(k), (current.expenseItems[k] ?? 0) - (base.expenseItems[k] ?? 0),
              detail: (base.expenseItems[k] ?? 0) == 0
                  ? 'Não existia antes'
                  : ((current.expenseItems[k] ?? 0) == 0 ? 'Não teve agora' : '')),
    ]..sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
    return items.take(count).toList();
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
