import 'package:flutter/material.dart';

import '../config.dart';
import '../ui/cf_theme.dart';
import 'billing_engine.dart';
import 'billing_store.dart';

/// Trava das funções do plano Profissional.
/// No teste grátis e na cortesia tudo fica liberado; no Essencial estas funções pedem o Profissional.
/// O servidor também trava (link de agendamento e agenda no Outlook/Google), esta é a parte da tela.
class ProGate {
  ProGate._();

  /// Abre a tela de planos (Configurações). Quem monta o app liga esta função.
  static VoidCallback? openPlans;

  static bool get isPro => BillingStore.instance.isPro;

  /// Devolve true se pode seguir. Se não puder, mostra o aviso.
  static bool check(BuildContext context, String feature) {
    if (isPro) return true;
    showProDialog(context, feature);
    return false;
  }

  static Future<void> showProDialog(BuildContext context, String feature) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.lock_rounded, color: CF.brand, size: 34),
          title: Text(AppConfig.hidePricing ? 'Recurso indisponível' : 'Recurso do plano Profissional'),
          content: Text(
            AppConfig.hidePricing
                ? '$feature não está disponível na sua conta.'
                : '$feature faz parte do plano Profissional. Você pode trocar de plano em Configurações, na parte Assinatura.',
            style: CF.body(15.5, color: CF.text, height: 1.4),
          ),
          actions: [
            if (!AppConfig.hidePricing && openPlans != null)
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openPlans!();
                },
                child: const Text('Ver planos'),
              ),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Entendi')),
          ],
        ),
      );
}

/// Tela inteira bloqueada (usada em Relatórios no plano Essencial).
class ProLockedView extends StatelessWidget {
  const ProLockedView({super.key, required this.title, required this.what});
  final String title;
  final String what;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: const Color(0xFFDDF3F5), borderRadius: BorderRadius.circular(22)),
                child: const Icon(Icons.lock_rounded, color: CF.brand, size: 36),
              ),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: CF.body(22, weight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                AppConfig.hidePricing ? '$what Não está disponível na sua conta.' : '$what Faz parte do plano Profissional.',
                textAlign: TextAlign.center,
                style: CF.body(15.5, color: CF.muted, height: 1.4),
              ),
              if (!AppConfig.hidePricing && ProGate.openPlans != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: ProGate.openPlans,
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const Text('Ver planos'),
                ),
              ],
            ]),
          ),
        ),
      );
}


/// Valor das aulas do mês atual (chamariz do Agenda Grátis).
double freeMonthValue() {
  final store = BillingStore.instance;
  final t = store.today;
  return store.forecast(DateTime(t.year, t.month)).billed;
}

/// Tela de recurso pago no Agenda Grátis (Cobranças, Financeiro, Relatórios).
class FreeLockedView extends StatelessWidget {
  const FreeLockedView({super.key, required this.title, required this.what, required this.icon});
  final String title;
  final String what;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final value = freeMonthValue();
    final web = !AppConfig.hidePricing;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: const Color(0xFFDDF3F5), borderRadius: BorderRadius.circular(22)),
              child: Icon(icon, color: CF.brand, size: 36),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: CF.body(22, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              web ? '$what Sua agenda continua grátis; esta parte vem com os planos Essencial e Profissional.'
                  : '$what Não está disponível na sua conta. A agenda continua liberada.',
              textAlign: TextAlign.center,
              style: CF.body(15.5, color: CF.muted, height: 1.4),
            ),
            if (web && value > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: CF.amberBg, borderRadius: BorderRadius.circular(16)),
                child: Text(
                  'Pela sua agenda, as aulas deste mês somam ${money(value)}. '
                  'Com um plano, o Léguno calcula e cobra cada aluno no WhatsApp com Pix.',
                  textAlign: TextAlign.center,
                  style: CF.body(15, weight: FontWeight.w600, color: CF.ink, height: 1.35),
                ),
              ),
            ],
            if (web && ProGate.openPlans != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: ProGate.openPlans,
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Ver planos'),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Cartão do Início no Agenda Grátis: mostra quanto o mês vale e convida para um plano.
class FreeInviteCard extends StatelessWidget {
  const FreeInviteCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppConfig.hidePricing) return const SizedBox.shrink();
    final value = freeMonthValue();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: CF.amberBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: CF.lap)),
      child: Row(children: [
        const Icon(Icons.payments_rounded, color: CF.amber, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              value > 0 ? 'Suas aulas deste mês somam ${money(value)}' : 'Sua agenda é grátis para sempre',
              style: CF.body(16.5, weight: FontWeight.w800, color: CF.ink),
            ),
            const SizedBox(height: 2),
            Text('Ative um plano para cobrar no WhatsApp com Pix e controlar o financeiro.',
                style: CF.body(14, color: CF.muted, height: 1.3)),
          ]),
        ),
        if (ProGate.openPlans != null) ...[
          const SizedBox(width: 10),
          FilledButton(onPressed: ProGate.openPlans, child: const Text('Ver planos')),
        ],
      ]),
    );
  }
}
