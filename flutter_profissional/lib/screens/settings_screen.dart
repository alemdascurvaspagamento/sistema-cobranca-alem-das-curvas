import 'package:flutter/material.dart';

import '../billing/billing_screen.dart' show openPixSettings;
import '../billing/billing_store.dart';
import '../data/export.dart';
import '../ui/cf_theme.dart';
import '../ui/widgets.dart';

/// Configurações: chave Pix, conta e sincronização de agenda.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.onCalendarSync,
    this.email,
    this.onSignOut,
    this.onLeaveDemo,
  });
  final VoidCallback onCalendarSync;
  final String? email;
  final VoidCallback? onSignOut;
  final VoidCallback? onLeaveDemo;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final store = BillingStore.instance;
  Future<void> _download() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await downloadMyData(store);
      messenger.showSnackBar(const SnackBar(content: Text('Planilha baixada. Procure na pasta Downloads.')));
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('Não foi possível baixar a planilha. Tente de novo.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = store.isCloud;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageTitle('Configurações'),
      const SizedBox(height: 14),
      AnimatedBuilder(
        animation: store,
        builder: (context, _) => Panel(
          icon: Icons.qr_code_2_rounded,
          color: CF.pix,
          title: 'Pix',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Vai na cobrança pelo WhatsApp e gera o Pix copia e cola e o QR Code já com o valor de cada cliente.',
                style: CF.body(14, color: CF.muted, height: 1.35)),
            const SizedBox(height: 10),
            if (store.pixKey.isEmpty)
              Text('Nenhuma chave cadastrada.', style: CF.body(15, weight: FontWeight.w600))
            else ...[
              Text('Chave: ${store.pixKey}', style: CF.body(15, weight: FontWeight.w600)),
              if (store.pixName.isNotEmpty || store.pixCity.isNotEmpty)
                Text([store.pixName, store.pixCity].where((e) => e.isNotEmpty).join(' · '),
                    style: CF.body(14, color: CF.muted)),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: () => openPixSettings(context),
                child: Text(store.pixKey.isEmpty ? 'Cadastrar Pix' : 'Alterar dados do Pix'),
              ),
            ),
          ]),
        ),
      ),
      if (cloud) ...[
        const SizedBox(height: 14),
        AnimatedBuilder(animation: store, builder: (context, _) => _SubscriptionPanel(store: store)),
      ],
      const SizedBox(height: 14),
      Panel(
        icon: Icons.download_rounded,
        color: CF.blue,
        title: 'Seus dados',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            'Baixe tudo numa planilha do Excel: resumo por mês, cobranças, pagamentos, clientes, '
            'atendimentos alterados, despesas, ganhos extras e feriados. Os dados são seus: '
            'guarde como cópia ou leve para o contador.',
            style: CF.body(14, color: CF.muted, height: 1.35),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Baixar meus dados (planilha)'),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Panel(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: const Icon(Icons.sync_rounded, color: CF.ink),
          title: Text('Sincronização de calendários', style: CF.body(16, weight: FontWeight.w700)),
          subtitle: Text('Apple, Google e privacidade dos compromissos', style: CF.body(14, color: CF.muted)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: widget.onCalendarSync,
        ),
      ),
      const SizedBox(height: 14),
      Panel(
        icon: Icons.manage_accounts_rounded,
        color: CF.ink,
        title: 'Conta',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(cloud ? Icons.cloud_done_rounded : Icons.science_rounded, color: cloud ? CF.green : CF.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                cloud
                    ? 'Conectado como ${widget.email ?? ''}. Tudo o que você muda é salvo na nuvem.'
                    : 'Você está na demonstração. Os dados são de exemplo e somem ao fechar.',
                style: CF.body(15),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (widget.onSignOut != null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sair da conta'),
              ),
            ),
          if (widget.onLeaveDemo != null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: widget.onLeaveDemo,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sair da demonstração'),
              ),
            ),
        ]),
      ),
    ]);
  }
}

/// Situação da assinatura e os planos.
class _SubscriptionPanel extends StatelessWidget {
  const _SubscriptionPanel({required this.store});
  final BillingStore store;

  @override
  Widget build(BuildContext context) {
    final sub = store.subscription;
    final now = DateTime.now();
    String date(DateTime? d) => d == null
        ? ''
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final (String title, String detail, Color color) = switch (sub?.state) {
      'courtesy' => ('Conta cortesia', 'Acesso completo, sem cobrança.', CF.green),
      'active' => (
          'Plano ${sub!.planName}${sub.founder ? ' · fundador' : ''}',
          sub.status == 'canceled'
              ? 'Cancelado. Você usa até ${date(sub.currentPeriodEnd)}.'
              : 'Em dia. Próxima cobrança em ${date(sub.currentPeriodEnd)}.',
          CF.green,
        ),
      'grace' => ('Pagamento em atraso', 'Acesso garantido até ${date(sub!.currentPeriodEnd?.add(const Duration(days: 7)))}.', CF.red),
      'read_only' => ('Somente leitura', 'Você vê e baixa seus dados. Para voltar a lançar, assine um plano.', CF.red),
      _ => (
          'Teste grátis',
          sub == null
              ? '14 dias com tudo liberado.'
              : 'Faltam ${sub.trialDaysLeft(now)} dias (até ${date(sub.trialEndsAt)}). Tudo liberado, sem cartão.',
          CF.amber,
        ),
    };
    final t = store.terms;
    return Panel(
      icon: Icons.workspace_premium_rounded,
      color: CF.amber,
      title: 'Assinatura',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: CF.body(18, weight: FontWeight.w700, color: color)),
        Text(detail, style: CF.body(14.5, color: CF.muted, height: 1.35)),
        if (sub?.isCourtesy != true) ...[
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth >= 520 ? (box.maxWidth - 10) / 2 : box.maxWidth;
            Widget plan(String name, String price, String what, bool highlight) => Container(
                  width: w,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: highlight ? const Color(0xFFE9EFFA) : CF.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: highlight ? CF.ink : CF.line, width: highlight ? 2 : 1),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: CF.body(16, weight: FontWeight.w700)),
                    Text(price, style: CF.score(28)),
                    Text(what, style: CF.body(14, color: CF.muted)),
                  ]),
                );
            return Wrap(spacing: 10, runSpacing: 10, children: [
              plan('Essencial', 'R\$ 29,90/mês', 'Até 15 ${t.clients} ativos', false),
              plan('Profissional', 'R\$ 49,90/mês', '${t.clientsTitle} ilimitados', true),
            ]);
          }),
          const SizedBox(height: 10),
          Text('Plano anual com 2 meses grátis. A assinatura pelo site abre em breve; '
              'você entra no app com este mesmo e-mail.',
              style: CF.body(13.5, color: CF.muted, height: 1.35)),
        ],
      ]),
    );
  }
}

