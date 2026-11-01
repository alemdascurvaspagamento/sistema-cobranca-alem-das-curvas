import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../billing/billing_screen.dart' show openPixSettings, openSecondPixSettings;
import '../billing/billing_store.dart';
import '../data/export.dart';
import '../ui/cf_theme.dart';
import '../booking.dart';
import '../calendar_feed.dart';
import '../ui/confirmations.dart';
import '../ui/start_guide.dart';
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

  /// Excluir a conta (exigência da Apple e da LGPD). Pede para digitar EXCLUIR.
  Future<void> _deleteAccount() async {
    final typed = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Excluir minha conta?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text(
              'Isso apaga para sempre seus clientes, agenda, cobranças, despesas e configurações do Avora. '
              'Não dá para desfazer. Se quiser guardar uma cópia, use antes "Baixar meus dados".',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: typed,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setLocal(() {}),
              decoration: const InputDecoration(labelText: 'Para confirmar, digite EXCLUIR'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: CF.red),
              onPressed: typed.text.trim().toUpperCase() == 'EXCLUIR' ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Excluir para sempre'),
            ),
          ],
        ),
      ),
    );
    typed.dispose();
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await Supabase.instance.client.rpc('cf_delete_my_account');
      messenger.showSnackBar(SnackBar(
        content: Text(result == 'account_deleted'
            ? 'Sua conta foi excluída.'
            : 'Seus dados do Avora foram apagados. Seu login continua porque você usa outro sistema da Além das Curvas.'),
      ));
      widget.onSignOut?.call();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Não foi possível excluir agora. Verifique a internet e tente de novo, ou fale com o suporte.'),
      ));
    }
  }

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
      const PageTitle('Configurações', icon: Icons.tune_rounded, color: CF.ink),
      const SizedBox(height: 14),
      AnimatedBuilder(
        animation: store,
        builder: (context, _) => KpiRow([
          KpiCard(
            icon: Icons.workspace_premium_rounded,
            label: 'Plano',
            value: store.subscription?.planName ?? 'Demonstração',
            color: CF.amber,
            accent: true,
          ),
          KpiCard(
            icon: Icons.qr_code_2_rounded,
            label: 'Pix',
            value: store.pixKey.isEmpty ? 'Sem chave' : 'Ativo',
            hint: store.pixKey.isEmpty ? 'Cadastre abaixo' : 'Nas cobranças pelo WhatsApp',
            color: CF.pix,
            accent: true,
          ),
          KpiCard(
            icon: Icons.cloud_done_rounded,
            label: 'Dados',
            value: cloud ? 'Na nuvem' : 'Neste aparelho',
            hint: cloud ? 'Salvos na sua conta' : 'Só na demonstração',
            color: CF.green,
            accent: true,
          ),
        ]),
      ),
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
              Text('${store.hasSecondPix ? '${store.pixLabelOf(1)}: ' : 'Chave: '}${store.pixKey}',
                  style: CF.body(15, weight: FontWeight.w600)),
              if (store.pixName.isNotEmpty || store.pixCity.isNotEmpty)
                Text([store.pixName, store.pixCity].where((e) => e.isNotEmpty).join(' · '),
                    style: CF.body(14, color: CF.muted)),
              if (store.hasSecondPix) ...[
                const SizedBox(height: 6),
                Text('${store.pixLabelOf(2)}: ${store.pixKey2}', style: CF.body(15, weight: FontWeight.w600)),
                Text('Usada por ${store.plans.where((p) => p.active && p.pixChoice == 2).length} '
                    'de ${store.plans.where((p) => p.active).length} ${store.terms.clients}. Escolha na ficha de cada um.',
                    style: CF.body(14, color: CF.muted)),
              ],
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(
                onPressed: () => openPixSettings(context),
                child: Text(store.pixKey.isEmpty ? 'Cadastrar Pix' : 'Alterar dados do Pix'),
              ),
              if (store.pixKey.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => openSecondPixSettings(context),
                  icon: Icon(store.hasSecondPix ? Icons.edit_rounded : Icons.add_rounded, size: 18),
                  label: Text(store.hasSecondPix ? 'Alterar segunda chave' : 'Adicionar segunda chave'),
                ),
            ]),
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
        color: CF.whatsapp,
        child: ListTile(
          leading: const Icon(Icons.event_available_rounded, color: CF.brand),
          title: Text('Agendamento online', style: CF.body(16, weight: FontWeight.w700)),
          subtitle: Text('Agora fica no topo da Agenda. Aqui você ajusta os horários.', style: CF.body(14, color: CF.muted)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => openBookingSettings(context),
        ),
      ),
      const SizedBox(height: 14),
      Panel(
        padding: const EdgeInsets.symmetric(vertical: 4),
        color: CF.whatsapp,
        child: ListTile(
          leading: const Icon(Icons.chat_rounded, color: CF.whatsapp),
          title: Text('Confirmação pelo WhatsApp', style: CF.body(16, weight: FontWeight.w700)),
          subtitle: Text('Mensagem que vai ao tocar em "Confirmar" na agenda do dia', style: CF.body(14, color: CF.muted)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => openConfirmTemplate(context),
        ),
      ),
      const SizedBox(height: 14),
      Panel(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: const Icon(Icons.sync_rounded, color: CF.ink),
          title: Text('Ver no seu calendário', style: CF.body(16, weight: FontWeight.w700)),
          subtitle: Text('Office 365/Outlook, Google Agenda e iPhone', style: CF.body(14, color: CF.muted)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => openCalendarFeed(context),
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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await StartGuide.instance.showAgain();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('Pronto. O guia "Comece por aqui" voltou para o Início.')));
              },
              icon: const Icon(Icons.rocket_launch_rounded, size: 18),
              label: const Text('Mostrar o guia de início de novo'),
            ),
          ),
          const SizedBox(height: 4),
          if (widget.onSignOut != null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sair da conta'),
              ),
            ),
          if (widget.onSignOut != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: CF.red),
                onPressed: _deleteAccount,
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: const Text('Excluir minha conta'),
              ),
            ),
          ],
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
              ? '60 dias com tudo liberado.'
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
            Widget plan(String name, String price, String yearly, String what, bool highlight) => Container(
                  width: w,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: highlight ? const Color(0xFFDDF3F5) : CF.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: highlight ? CF.brand : CF.line, width: highlight ? 2 : 1),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: CF.body(16, weight: FontWeight.w700)),
                    Text(price, style: CF.score(28)),
                    Text(yearly, style: CF.body(13, color: CF.green, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(what, style: CF.body(14, color: CF.muted, height: 1.3)),
                  ]),
                );
            return Wrap(spacing: 10, runSpacing: 10, children: [
              plan('Essencial', 'R\$ 34,90/mês', 'ou R\$ 349/ano (2 meses grátis)',
                  'Até 15 ${t.clients} ativos. Agenda, cobrança e Pix.', false),
              plan('Profissional', 'R\$ 59,90/mês', 'ou R\$ 599/ano (2 meses grátis)',
                  '${t.clientsTitle} ilimitados, agendamento online, confirmação pelo WhatsApp, '
                      'agenda no Outlook/Google e relatórios.',
                  true),
            ]);
          }),
          if (sub?.state == 'trialing' || sub == null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CF.amberBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CF.lap),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.star_rounded, color: CF.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: 'Oferta de fundador: ', style: CF.body(14.5, weight: FontWeight.w800, color: CF.amber)),
                    TextSpan(
                      text: 'assine durante o teste e tenha o Profissional por R\$ 39,90/mês para sempre. '
                          'Só para as primeiras 100 contas.',
                      style: CF.body(14.5, color: CF.text, height: 1.35),
                    ),
                  ])),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 10),
          Text('A assinatura é feita pelo site, que abre em breve; você entra no app com este mesmo e-mail.',
              style: CF.body(13.5, color: CF.muted, height: 1.35)),
        ],
      ]),
    );
  }
}

