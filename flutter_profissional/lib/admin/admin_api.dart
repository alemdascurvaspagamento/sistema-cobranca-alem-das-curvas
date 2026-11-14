import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Painel do administrador do Léguno: acesso ao banco e modelos.
///
/// Tudo passa por funções `cf_admin_*` que confirmam, no próprio banco, que quem
/// chama é administrador. O painel mostra dados da CONTA (e-mail, plano, uso).
/// Nunca o conteúdo dos clientes do profissional, nem o que ele recebe.

typedef AdminRpc = Future<dynamic> Function(String fn, [Map<String, dynamic>? params]);

class AdminError implements Exception {
  AdminError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sabe se quem entrou é administrador (só vale no navegador).
class AdminAccess {
  AdminAccess._();
  static final isAdmin = ValueNotifier<bool>(false);

  static Future<void> load(SupabaseClient db) async {
    if (!kIsWeb) return;
    try {
      final r = await db.rpc('cf_is_admin');
      isAdmin.value = r == true;
    } catch (_) {
      isAdmin.value = false;
    }
  }

  static void clear() => isAdmin.value = false;
}

Map<String, dynamic> _map(dynamic v) => Map<String, dynamic>.from(v as Map);
List<Map<String, dynamic>> _list(dynamic v) =>
    (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

class AdminApi {
  AdminApi(this._rpc);

  factory AdminApi.supabase(SupabaseClient db) => AdminApi((fn, [params]) async {
        try {
          return await db.rpc(fn, params: params);
        } on PostgrestException catch (e) {
          if (e.code == '42501') throw AdminError('Acesso negado.');
          if (e.code == 'PGRST202' || e.code == '42883') {
            throw AdminError('Esta parte ainda não foi ativada no banco de dados.');
          }
          throw AdminError(e.message);
        }
      });

  final AdminRpc _rpc;

  Future<Map<String, dynamic>> overview(int days) async => _map(await _rpc('cf_admin_overview', {'p_days': days}));

  Future<Map<String, dynamic>> funnel(int days) async => _map(await _rpc('cf_admin_funnel', {'p_days': days}));

  Future<List<AdminAccount>> accounts({String? query, String filter = 'all'}) async {
    final r = await _rpc('cf_admin_accounts', {'p_q': query, 'p_filter': filter, 'p_limit': 200, 'p_offset': 0});
    return _list(r).map(AdminAccount.fromJson).toList();
  }

  Future<Map<String, dynamic>> detail(String ownerId) async => _map(await _rpc('cf_admin_account_detail', {'p_owner': ownerId}));

  Future<List<Map<String, dynamic>>> support() async => _list(await _rpc('cf_admin_support'));

  Future<List<Map<String, dynamic>>> log() async => _list(await _rpc('cf_admin_log_list', {'p_limit': 200}));

  Future<Map<String, dynamic>> finance() async => _map(await _rpc('cf_admin_finance'));

  Future<void> extendTrial(String ownerId, int days) async =>
      _rpc('cf_admin_extend_trial', {'p_owner': ownerId, 'p_days': days, 'p_note': null});

  Future<void> setFounder(String ownerId, bool on) async =>
      _rpc('cf_admin_set_founder', {'p_owner': ownerId, 'p_founder': on});

  Future<void> setCourtesy(String ownerId, bool on) async =>
      _rpc('cf_admin_set_courtesy', {'p_owner': ownerId, 'p_on': on});
}

class AdminAccount {
  const AdminAccount({
    required this.ownerId,
    required this.email,
    required this.createdAt,
    required this.plan,
    required this.status,
    required this.state,
    required this.founder,
    required this.internal,
    required this.clients,
    this.lastSignIn,
    this.profession,
    this.trialEndsAt,
    this.currentPeriodEnd,
    this.platform,
    this.lastSeen,
  });

  final String ownerId;
  final String email;
  final DateTime createdAt;
  final DateTime? lastSignIn;
  final String? profession;
  final String plan;
  final String status;

  /// trialing, active, grace, read_only ou courtesy.
  final String state;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final bool founder;
  final bool internal;
  final int clients;
  final String? platform;
  final DateTime? lastSeen;

  static DateTime? _d(Object? v) => v == null ? null : DateTime.tryParse(v as String)?.toLocal();

  factory AdminAccount.fromJson(Map<String, dynamic> j) => AdminAccount(
        ownerId: j['owner_id'] as String,
        email: (j['email'] as String?) ?? '',
        createdAt: _d(j['created_at']) ?? DateTime.now(),
        lastSignIn: _d(j['last_sign_in']),
        profession: j['profession'] as String?,
        plan: (j['plan'] as String?) ?? 'profissional',
        status: (j['status'] as String?) ?? 'trialing',
        state: (j['state'] as String?) ?? 'trialing',
        trialEndsAt: _d(j['trial_ends_at']),
        currentPeriodEnd: _d(j['current_period_end']),
        founder: j['founder'] as bool? ?? false,
        internal: j['internal'] as bool? ?? false,
        clients: (j['clients'] as num?)?.toInt() ?? 0,
        platform: j['platform'] as String?,
        lastSeen: _d(j['last_seen']),
      );

  /// Dias que faltam do teste (0 no último dia).
  int trialDaysLeft(DateTime now) {
    final end = trialEndsAt;
    if (end == null) return 0;
    final h = end.difference(now).inHours;
    return h <= 0 ? 0 : (h / 24).ceil();
  }

  int graceDaysLeft(DateTime now) {
    final end = currentPeriodEnd;
    if (end == null) return 0;
    final h = end.add(const Duration(days: 7)).difference(now).inHours;
    return h <= 0 ? 0 : (h / 24).ceil();
  }

  /// Último sinal de vida: o mais recente entre o uso registrado e o último login.
  DateTime? get lastActivity {
    final a = lastSeen, b = lastSignIn;
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  String get platformLabel => switch ((platform ?? '').toLowerCase()) {
        'ios' => 'iPhone',
        'android' => 'Android',
        'web' => 'Web',
        _ => '—',
      };
}
