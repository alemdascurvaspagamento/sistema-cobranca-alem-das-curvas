/// Assinatura do profissional no Coach Flow (lida do banco).
class SubscriptionInfo {
  const SubscriptionInfo({
    required this.plan,
    required this.status,
    required this.state,
    this.trialEndsAt,
    this.currentPeriodEnd,
    this.founder = false,
    this.clientLimit,
  });

  /// `essencial` ou `profissional`.
  final String plan;

  /// Situação gravada: trialing, active, past_due, canceled, courtesy.
  final String status;

  /// Situação efetiva, já considerando as datas:
  /// trialing, active, grace (atraso dentro dos 7 dias), read_only, courtesy.
  final String state;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final bool founder;

  /// Máximo de clientes ativos (só no Essencial).
  final int? clientLimit;

  factory SubscriptionInfo.fromJson(Map<String, dynamic> j) => SubscriptionInfo(
        plan: j['plan'] as String? ?? 'profissional',
        status: j['status'] as String? ?? 'trialing',
        state: j['state'] as String? ?? 'trialing',
        trialEndsAt: j['trial_ends_at'] == null ? null : DateTime.parse(j['trial_ends_at'] as String).toLocal(),
        currentPeriodEnd:
            j['current_period_end'] == null ? null : DateTime.parse(j['current_period_end'] as String).toLocal(),
        founder: j['founder'] as bool? ?? false,
        clientLimit: (j['client_limit'] as num?)?.toInt(),
      );

  bool get canWrite => state != 'read_only';
  bool get isTrial => state == 'trialing';
  bool get isGrace => state == 'grace';
  bool get isReadOnly => state == 'read_only';
  bool get isCourtesy => state == 'courtesy';

  String get planName => plan == 'essencial' ? 'Essencial' : 'Profissional';

  /// Dias que faltam do teste grátis (0 no último dia).
  int trialDaysLeft(DateTime now) {
    final end = trialEndsAt;
    if (end == null) return 0;
    final h = end.difference(now).inHours;
    return h <= 0 ? 0 : (h / 24).ceil();
  }

  /// Dias de tolerância que sobram no atraso.
  int graceDaysLeft(DateTime now) {
    final end = currentPeriodEnd;
    if (end == null) return 0;
    final h = end.add(const Duration(days: 7)).difference(now).inHours;
    return h <= 0 ? 0 : (h / 24).ceil();
  }
}
