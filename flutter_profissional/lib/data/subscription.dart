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
    this.pro = true,
    this.cycle = 'monthly',
    this.hasSubscription = false,
    this.source = 'asaas',
    this.appleProduct,
  });

  /// De onde vem a assinatura: `asaas` (site) ou `apple` (compra no iPhone).
  final String source;

  /// Produto comprado na Apple (quando `source` é `apple`).
  final String? appleProduct;

  /// `essencial` ou `profissional`.
  final String plan;

  /// Situação gravada: trialing, active, past_due, canceled, courtesy.
  final String status;

  /// Situação efetiva, já considerando as datas:
  /// trialing, active, grace (atraso dentro dos 7 dias), read_only, courtesy.
  /// `read_only` hoje significa **Agenda Grátis**: a agenda e os alunos seguem
  /// liberados para sempre; cobrança, financeiro e relatórios pedem um plano.
  final String state;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final bool founder;

  /// Máximo de clientes ativos (só no Essencial).
  final int? clientLimit;

  /// Tem as funções do Profissional (teste grátis, cortesia ou plano Profissional em dia).
  final bool pro;

  /// `monthly` ou `annual`.
  final String cycle;

  /// Já tem assinatura criada no Asaas (troca de plano em vez de assinatura nova).
  final bool hasSubscription;

  factory SubscriptionInfo.fromJson(Map<String, dynamic> j) => SubscriptionInfo(
        plan: j['plan'] as String? ?? 'profissional',
        status: j['status'] as String? ?? 'trialing',
        state: j['state'] as String? ?? 'trialing',
        trialEndsAt: j['trial_ends_at'] == null ? null : DateTime.parse(j['trial_ends_at'] as String).toLocal(),
        currentPeriodEnd:
            j['current_period_end'] == null ? null : DateTime.parse(j['current_period_end'] as String).toLocal(),
        founder: j['founder'] as bool? ?? false,
        clientLimit: (j['client_limit'] as num?)?.toInt(),
        pro: j['pro'] as bool? ?? true,
        cycle: j['cycle'] as String? ?? 'monthly',
        hasSubscription: j['has_subscription'] as bool? ?? false,
        source: j['source'] as String? ?? 'asaas',
        appleProduct: j['apple_product'] as String?,
      );

  /// A agenda sempre pode ser usada (também no Agenda Grátis).
  bool get canWrite => true;

  /// Plano Agenda Grátis (teste acabou ou não há pagamento em dia).
  bool get isFree => state == 'read_only';

  /// Cobrança, pagamentos, despesas e entradas liberados?
  bool get canFinance => !isFree;
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
