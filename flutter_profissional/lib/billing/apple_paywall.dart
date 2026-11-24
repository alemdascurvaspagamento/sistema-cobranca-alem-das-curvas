import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/cf_theme.dart';
import '../ui/legal.dart';
import '../ui/widgets.dart';
import 'apple_products.dart';
import 'apple_store.dart';
import 'billing_store.dart';

/// Abre a tela de planos com compra pela Apple (iPhone/iPad).
Future<void> showApplePaywall(BuildContext context, {AppleStoreBase? store}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ApplePaywall(store: store ?? appleStore)));

/// Planos Essencial e Profissional, mensal ou anual, comprados pela App Store.
/// Tem o que a Apple pede: preço e período claros, renovação automática explicada,
/// "Restaurar compras", como cancelar e os links de Termos e Privacidade.
class ApplePaywall extends StatefulWidget {
  const ApplePaywall({super.key, required this.store});
  final AppleStoreBase store;

  @override
  State<ApplePaywall> createState() => _ApplePaywallState();
}

class _ApplePaywallState extends State<ApplePaywall> {
  bool annual = false;

  @override
  void initState() {
    super.initState();
    widget.store.load();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(title: const Text('Planos do Léguno')),
      body: ListenableBuilder(
        listenable: Listenable.merge([store, BillingStore.instance]),
        builder: (context, _) {
          final sub = BillingStore.instance.subscription;
          final activeNow = sub != null && (sub.state == 'active' || sub.state == 'grace');
          final paidElsewhere = activeNow && sub.source != 'apple';
          final fromApple = activeNow && sub.source == 'apple';
          return ListView(padding: const EdgeInsets.all(16), children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (sub?.isCourtesy == true || paidElsewhere)
                  Panel(
                    icon: Icons.verified_rounded,
                    color: CF.green,
                    title: 'Sua assinatura já está ativa',
                    child: Text('Esta conta já tem acesso completo. Não é preciso assinar de novo.',
                        style: CF.body(15, color: CF.muted, height: 1.35)),
                  )
                else ...[
                  Text('Sua agenda continua grátis. Assine para cobrar, controlar o dinheiro e automatizar.',
                      style: CF.body(16, color: CF.muted, height: 1.35)),
                  const SizedBox(height: 14),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Mensal')),
                      ButtonSegment(value: true, label: Text('Anual')),
                    ],
                    selected: {annual},
                    onSelectionChanged: (s) => setState(() => annual = s.first),
                  ),
                  const SizedBox(height: 14),
                  for (final plan in const ['essencial', 'profissional'])
                    _PlanCard(
                      plan: plan,
                      productId: AppleProducts.idFor(plan, annual: annual),
                      annual: annual,
                      store: store,
                      current: fromApple && sub.appleProduct == AppleProducts.idFor(plan, annual: annual),
                    ),
                  if (store.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(store.error!, style: CF.body(14.5, color: CF.red, weight: FontWeight.w600)),
                    ),
                  if (store.notice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(store.notice!, style: CF.body(14.5, color: CF.green, weight: FontWeight.w700)),
                    ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    TextButton.icon(
                      onPressed: store.busy ? null : store.restore,
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Restaurar compras'),
                    ),
                    if (fromApple)
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri.parse(AppleProducts.manageUrl), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.settings_rounded),
                        label: const Text('Gerenciar assinatura'),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'A assinatura é cobrada na sua conta da Apple ao confirmar a compra e renova automaticamente '
                    'ao fim de cada período, pelo mesmo valor, a menos que seja cancelada até 24 horas antes. '
                    'Você pode gerenciar ou cancelar quando quiser em Ajustes › seu nome › Assinaturas.',
                    style: CF.body(13.5, color: CF.muted, height: 1.4),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(spacing: 4, children: [
                  TextButton(onPressed: () => openLegal(context, LegalDoc.terms), child: const Text('Termos de uso')),
                  TextButton(onPressed: () => openLegal(context, LegalDoc.privacy), child: const Text('Privacidade')),
                ]),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.productId,
    required this.annual,
    required this.store,
    required this.current,
  });
  final String plan;
  final String productId;
  final bool annual;
  final AppleStoreBase store;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final name = plan == 'essencial' ? 'Essencial' : 'Profissional';
    final price = store.priceOf(productId) ?? AppleProducts.referencePrice[productId]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        icon: plan == 'essencial' ? Icons.receipt_long_rounded : Icons.workspace_premium_rounded,
        color: plan == 'essencial' ? CF.green : CF.violet,
        title: name,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: price, style: CF.body(26, weight: FontWeight.w800, color: CF.text)),
            TextSpan(text: annual ? ' por ano' : ' por mês', style: CF.body(15, color: CF.muted)),
          ])),
          const SizedBox(height: 8),
          for (final f in AppleProducts.features[plan]!)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.check_rounded, size: 18, color: CF.green),
                const SizedBox(width: 6),
                Expanded(child: Text(f, style: CF.body(14.5, color: CF.text))),
              ]),
            ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: current || store.busy || !store.available ? null : () => store.buy(productId),
            child: Text(current ? 'Seu plano atual' : (store.busy ? 'Aguarde…' : 'Assinar o $name')),
          ),
        ]),
      ),
    );
  }
}
