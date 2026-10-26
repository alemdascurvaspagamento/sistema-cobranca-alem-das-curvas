import 'package:flutter/material.dart';

import '../billing/billing_store.dart';
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
  late final pix = TextEditingController(text: store.pixKey);

  @override
  void dispose() {
    pix.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cloud = store.isCloud;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageTitle('Configurações'),
      const SizedBox(height: 14),
      Panel(
        title: 'Chave Pix',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Aparece no resumo de cobrança enviado pelo WhatsApp.', style: CF.body(14, color: CF.muted)),
          const SizedBox(height: 10),
          TextField(
            controller: pix,
            decoration: const InputDecoration(labelText: 'CPF, e-mail, telefone ou chave aleatória'),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () {
                store.setPixKey(pix.text);
                FocusScope.of(context).unfocus();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chave Pix salva.')));
              },
              child: const Text('Salvar chave Pix'),
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
