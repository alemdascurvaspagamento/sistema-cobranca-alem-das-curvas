import 'package:flutter/material.dart';

import '../config.dart';
import '../ui/cf_theme.dart';
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
