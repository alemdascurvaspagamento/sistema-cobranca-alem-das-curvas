import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../agenda_events.dart';
import '../billing/billing_engine.dart';
import '../billing/billing_store.dart';

/// Resumo da manhã por e-mail.
///
/// O app guarda no banco um resumo dos próximos dias (atendimentos, cobranças
/// em aberto, contas a pagar). A função `cf-morning-brief` lê esse resumo e
/// manda o e-mail no horário escolhido. O e-mail só leva o que está aqui.
class MorningBrief extends ChangeNotifier {
  MorningBrief._();
  static final instance = MorningBrief._();

  bool emailOn = false;
  int sendHour = 7;
  bool loaded = false;
  Timer? _timer;
  bool _listening = false;

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get _uid => _db?.auth.currentUser?.id;

  /// Lê a escolha da pessoa e passa a manter o resumo atualizado.
  Future<void> load() async {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return;
    try {
      final rows = await db.from('cf_morning_brief').select('email_on,send_hour').eq('owner_id', uid);
      if (rows.isNotEmpty) {
        emailOn = rows.first['email_on'] as bool? ?? false;
        sendHour = (rows.first['send_hour'] as num?)?.toInt() ?? 7;
      }
      loaded = true;
    } catch (e) {
      debugPrint('Léguno: resumo da manhã indisponível ($e)');
      return;
    }
    notifyListeners();
    if (!_listening) {
      _listening = true;
      BillingStore.instance.addListener(_changed);
      AgendaEvents.instance.addListener(_changed);
    }
    _changed();
  }

  void clear() {
    _timer?.cancel();
    if (_listening) {
      BillingStore.instance.removeListener(_changed);
      AgendaEvents.instance.removeListener(_changed);
      _listening = false;
    }
    emailOn = false;
    sendHour = 7;
    loaded = false;
    notifyListeners();
  }

  /// Junta várias mudanças seguidas numa só gravação.
  void _changed() {
    if (!loaded || _uid == null) return;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 20), () => unawaited(_save()));
  }

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static double _r(double v) => (v * 100).round() / 100;

  Map<String, Object?> buildPayload() {
    final store = BillingStore.instance;
    final today = store.today;
    final month = DateTime(today.year, today.month);
    final days = <String, Object?>{};
    for (var i = 0; i < 7; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      final items = <Map<String, String>>[
        for (final (p, line) in store.sessionsOn(day))
          if (store.happens(line.outcome)) {'t': line.time, 'n': p.name, 'k': 's'},
        for (final e in AgendaEvents.instance.on(day)) {'t': e.allDay ? '' : e.time, 'n': e.title, 'k': 'e'},
      ];
      days[_d(day)] = items;
    }
    final open = <Map<String, Object?>>[];
    for (final p in store.activePlans) {
      final left = store.remaining(p, month: month);
      if (left > 0) open.add({'n': p.name, 'v': _r(left), 'due': _d(store.dueDate(p, month: month))});
    }
    final bills = [
      for (final e in store.billsDue(days: 3)) {'n': e.description, 'v': _r(e.amount), 'due': _d(e.date)},
    ];
    final t = store.terms;
    return {
      'v': 1,
      'gen': DateTime.now().toUtc().toIso8601String(),
      'name': '',
      'term': t.session,
      'terms': t.sessions,
      'days': days,
      'months': {
        '${month.year}-${month.month.toString().padLeft(2, '0')}': {
          'rec': _r(store.monthReceived),
          'rem': _r(store.monthRemaining),
          'tot': _r(store.monthTotal),
        },
      },
      'open': open,
      'bills': bills,
    };
  }

  Future<bool> _save({bool includeChoice = false}) async {
    final db = _db;
    final uid = _uid;
    if (db == null || uid == null) return false;
    try {
      await db.from('cf_morning_brief').upsert({
        'owner_id': uid,
        if (includeChoice) 'email_on': emailOn,
        if (includeChoice) 'send_hour': sendHour,
        'payload': buildPayload(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'owner_id');
      return true;
    } catch (e) {
      debugPrint('Léguno: não foi possível guardar o resumo ($e)');
      return false;
    }
  }

  /// Liga ou desliga o e-mail e/ou muda o horário.
  Future<bool> setChoice({bool? on, int? hour}) async {
    final oldOn = emailOn, oldHour = sendHour;
    if (on != null) emailOn = on;
    if (hour != null) sendHour = hour;
    notifyListeners();
    final ok = await _save(includeChoice: true);
    if (!ok) {
      emailOn = oldOn;
      sendHour = oldHour;
      notifyListeners();
    }
    return ok;
  }

  /// Manda agora um resumo de teste para o e-mail da conta.
  Future<String?> sendTest() async {
    final db = _db;
    if (db == null) return 'Entre na sua conta.';
    if (!await _save()) return 'Não foi possível preparar o resumo. Confira a internet.';
    try {
      final res = await db.functions.invoke('cf-morning-brief', body: {'test': true});
      final d = res.data;
      if (d is Map && (d['sent'] as num?) == 1) return null;
      return d is Map && d['error'] != null ? '${d['error']}' : 'Não foi possível enviar agora. Tente de novo.';
    } catch (_) {
      return 'Não foi possível enviar agora. Tente de novo.';
    }
  }
}
