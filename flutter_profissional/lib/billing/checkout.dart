import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/subscription.dart';
import '../ui/cf_theme.dart';
import '../ui/widgets.dart';
import 'billing_store.dart';

/// Preços dos planos (iguais aos do site e dos Termos). O servidor confere de novo.
const planPrices = {
  'essencial': {'monthly': 34.90, 'annual': 349.0},
  'profissional': {'monthly': 59.90, 'annual': 599.0},
};
const founderPrice = 39.90;

String _money(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

/// Só dígitos de CPF (11) ou CNPJ (14), com os dígitos verificadores certos.
bool validCpfCnpj(String raw) {
  final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length != 11 && d.length != 14) return false;
  if (RegExp(r'^(\d)\1+$').hasMatch(d)) return false;
  final n = d.split('').map(int.parse).toList();
  if (d.length == 11) {
    int dv(int len) {
      var s = 0;
      for (var i = 0; i < len; i++) {
        s += n[i] * (len + 1 - i);
      }
      final r = (s * 10) % 11;
      return r == 10 ? 0 : r;
    }
    return dv(9) == n[9] && dv(10) == n[10];
  }
  int dv(List<int> w) {
    var s = 0;
    for (var i = 0; i < w.length; i++) {
      s += n[i] * w[i];
    }
    final r = s % 11;
    return r < 2 ? 0 : 11 - r;
  }
  return dv([5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]) == n[12] && dv([6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]) == n[13];
}

/// Escolha de plano (só no site e no app web; o app das lojas não mostra).
class PlanChooser extends StatefulWidget {
  const PlanChooser({super.key, required this.store, required this.clients, required this.clientsTitle});
  final BillingStore store;
  final String clients;
  final String clientsTitle;

  @override
  State<PlanChooser> createState() => _PlanChooserState();
}

class _PlanChooserState extends State<PlanChooser> {
  late String cycle = widget.store.subscription?.cycle ?? 'monthly';

  SubscriptionInfo? get sub => widget.store.subscription;
  bool get paying => sub != null && sub!.hasSubscription && (sub!.state == 'active' || sub!.state == 'grace');
  bool get founderOpen => sub == null || sub!.isTrial || sub!.founder;

  @override
  Widget build(BuildContext context) {
    final annual = cycle == 'annual';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: RaisedToggle<String>(
            options: const [
              ('monthly', null, 'Mensal'),
              ('annual', null, 'Anual · 2 meses grátis'),
            ],
            selected: cycle,
            onChanged: (v) => setState(() => cycle = v),
          ),
        ),
      ),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth >= 520 ? (box.maxWidth - 10) / 2 : box.maxWidth;
        Widget card(String plan, String name, String what, bool highlight) {
          final price = planPrices[plan]![cycle]!;
          final founder = plan == 'profissional' && !annual && founderOpen;
          final current = paying && sub!.plan == plan && sub!.cycle == cycle;
          return Container(
            width: w,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: highlight ? const Color(0xFFDDF3F5) : CF.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: highlight ? CF.brand : CF.line, width: highlight ? 2 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: CF.body(16, weight: FontWeight.w700)),
              Text('${_money(price)}${annual ? '/ano' : '/mês'}', style: CF.score(28)),
              if (founder)
                Text('Fundador: ${_money(founderPrice)}/mês', style: CF.body(13, color: CF.amber, weight: FontWeight.w700))
              else
                Text(annual ? 'Pago uma vez por ano' : 'Cobrado todo mês', style: CF.body(13, color: CF.green, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(what, style: CF.body(14, color: CF.muted, height: 1.3)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: current
                    ? OutlinedButton(onPressed: null, child: const Text('Seu plano atual'))
                    : FilledButton(
                        onPressed: () => startCheckout(context, widget.store, plan, cycle),
                        child: Text(paying ? 'Mudar para o $name' : 'Assinar o $name'),
                      ),
              ),
            ]),
          );
        }

        return Wrap(spacing: 10, runSpacing: 10, children: [
          card('essencial', 'Essencial', '${widget.clientsTitle} ilimitados. Agenda, cobrança no WhatsApp com Pix e financeiro.', false),
          card('profissional', 'Profissional',
              'Tudo do Essencial, mais agendamento online, confirmação pelo WhatsApp, agenda no Outlook/Google e relatórios.', true),
        ]);
      }),
      const SizedBox(height: 8),
      Text(
        'Pagamento por Pix, boleto ou cartão. Sem fidelidade: cancele quando quiser.',
        style: CF.body(13, color: CF.muted),
      ),
    ]);
  }
}

/// Assina (ou troca de plano) e abre a página de pagamento.
Future<void> startCheckout(BuildContext context, BillingStore store, String plan, String cycle) async {
  final sub = store.subscription;
  // Assinatura comprada no iPhone: muda-se pela Apple, para não pagar duas vezes.
  if (sub != null && sub.source == 'apple' && (sub.state == 'active' || sub.state == 'grace')) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assinatura feita pelo iPhone'),
        content: Text(
          'Sua assinatura foi comprada pela App Store. Para trocar de plano ou cancelar, use o iPhone ou o iPad: '
          'Ajustes › seu nome › Assinaturas. Assim você não paga duas vezes.',
          style: CF.body(15, height: 1.4),
        ),
        actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Entendi'))],
      ),
    );
    return;
  }
  final paying = sub != null && sub.hasSubscription && (sub.state == 'active' || sub.state == 'grace');
  final name = plan == 'essencial' ? 'Essencial' : 'Profissional';
  Map<String, dynamic> body = {'plan': plan, 'cycle': cycle};

  if (paying) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mudar para o $name?'),
        content: Text(
          plan == 'profissional'
              ? 'As funções do Profissional ficam liberadas na hora. O novo valor vale a partir da próxima cobrança.'
              : 'O novo valor vale a partir da próxima cobrança. Nada é apagado. '
                  'O link de agendamento online, a confirmação pelo WhatsApp e os relatórios são desligados.',
          style: CF.body(15, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Mudar de plano')),
        ],
      ),
    );
    if (ok != true) return;
  } else {
    final data = await showDialog<Map<String, String>>(context: context, builder: (_) => _PayerDialog(plan: name));
    if (data == null) return;
    body = {...body, ...data};
  }
  if (!context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  String? error;
  String? url;
  try {
    final res = await Supabase.instance.client.functions.invoke('cf-checkout', body: body);
    final m = Map<String, dynamic>.from(res.data as Map);
    url = m['url'] as String?;
    error = m['error'] as String?;
  } on FunctionException catch (e) {
    final d = e.details;
    error = (d is Map && d['error'] is String) ? d['error'] as String : 'Não foi possível abrir o pagamento agora. Tente de novo.';
  } catch (_) {
    error = 'Não foi possível abrir o pagamento agora. Confira a internet e tente de novo.';
  }
  if (!context.mounted) return;
  Navigator.of(context).pop();

  // Atualiza a situação (a troca de plano vale na hora).
  try {
    final data = await Supabase.instance.client.rpc('cf_my_subscription');
    store.setSubscription(SubscriptionInfo.fromJson(Map<String, dynamic>.from(data as Map)));
  } catch (_) {}
  if (!context.mounted) return;

  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    return;
  }
  if (url != null) {
    final link = url;
    // O navegador só abre uma janela nova depois de um clique da pessoa, por isso o botão.
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: CF.green, size: 36),
        title: const Text('Sua fatura está pronta'),
        content: Text(
          'Toque no botão para abrir a página de pagamento (Pix, boleto ou cartão). '
          'Assim que o pagamento for confirmado, o plano é ativado sozinho.',
          style: CF.body(15, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Depois')),
          FilledButton.icon(
            onPressed: () {
              launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
              Navigator.of(ctx).pop();
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Abrir pagamento'),
          ),
        ],
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pronto! Você agora está no plano $name.')));
  }
}

class _PayerDialog extends StatefulWidget {
  const _PayerDialog({required this.plan});
  final String plan;
  @override
  State<_PayerDialog> createState() => _PayerDialogState();
}

class _PayerDialogState extends State<_PayerDialog> {
  final name = TextEditingController();
  final doc = TextEditingController();
  String? err;

  @override
  void dispose() {
    name.dispose();
    doc.dispose();
    super.dispose();
  }

  void _go() {
    if (name.text.trim().length < 3) return setState(() => err = 'Digite o nome completo ou a razão social.');
    if (!validCpfCnpj(doc.text)) return setState(() => err = 'Confira o CPF ou CNPJ.');
    Navigator.of(context).pop({'name': name.text.trim(), 'cpfCnpj': doc.text.replaceAll(RegExp(r'[^0-9]'), '')});
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Assinar o ${widget.plan}'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Estes dados vão na cobrança e na nota fiscal.', style: CF.body(14, color: CF.muted)),
            const SizedBox(height: 12),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome completo ou razão social')),
            const SizedBox(height: 10),
            TextField(
              controller: doc,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9./-]'))],
              decoration: const InputDecoration(labelText: 'CPF ou CNPJ'),
              onSubmitted: (_) => _go(),
            ),
            if (err != null) ...[
              const SizedBox(height: 8),
              Text(err!, style: CF.body(13.5, color: CF.red)),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Voltar')),
          FilledButton(onPressed: _go, child: const Text('Ir para o pagamento')),
        ],
      );
}
