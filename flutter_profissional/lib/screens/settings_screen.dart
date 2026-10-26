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
      const SizedBox(height: 14),
      Panel(
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
