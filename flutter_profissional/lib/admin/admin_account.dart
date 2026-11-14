import 'package:flutter/material.dart';

import '../ui/cf_theme.dart';
import '../ui/widgets.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';

/// Abre a ficha de uma conta (só dados da conta, nunca dos clientes dela).
Future<void> openAccountDialog(BuildContext context, AdminApi api, AdminAccount account, VoidCallback onChanged) =>
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: CF.bg,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
          child: _AccountView(api: api, account: account, onChanged: onChanged),
        ),
      ),
    );

class _AccountView extends StatefulWidget {
  const _AccountView({required this.api, required this.account, required this.onChanged});
  final AdminApi api;
  final AdminAccount account;
  final VoidCallback onChanged;

  @override
  State<_AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<_AccountView> {
  int _reload = 0;
  bool _busy = false;

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
          ],
        ),
      ) ??
      false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      widget.onChanged();
      setState(() => _reload++);
    } on AdminError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível concluir.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _extend(AdminAccount a) async {
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Estender o teste por quanto tempo?'),
        children: [
          for (final d in const [7, 14, 30])
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, d), child: Text('$d dias')),
        ],
      ),
    );
    if (days == null) return;
    await _run(() => widget.api.extendTrial(a.ownerId, days), 'Teste estendido em $days dias.');
  }

  Future<void> _founder(AdminAccount a) async {
    final on = !a.founder;
    if (!await _confirm(on ? 'Marcar como fundador?' : 'Tirar a marca de fundador?',
        on ? 'A conta passa a ter o preço de fundador (R\$ 39,90).' : 'A conta volta ao preço normal do plano.')) {
      return;
    }
    await _run(() => widget.api.setFounder(a.ownerId, on), on ? 'Marcada como fundador.' : 'Marca de fundador removida.');
  }

  Future<void> _courtesy(AdminAccount a) async {
    final on = a.status != 'courtesy';
    if (!await _confirm(on ? 'Dar cortesia?' : 'Tirar a cortesia?',
        on ? 'A conta fica com tudo liberado, sem cobrança.' : 'A conta volta ao teste grátis, com 7 dias.')) {
      return;
    }
    await _run(() => widget.api.setCourtesy(a.ownerId, on), on ? 'Cortesia concedida.' : 'Cortesia removida.');
  }

  @override
  Widget build(BuildContext context) => AsyncBlock<Map<String, dynamic>>(
        load: () => widget.api.detail(widget.account.ownerId),
        reloadKey: _reload,
        builder: (context, d) {
          final raw = d['account'];
          final a = raw is Map ? AdminAccount.fromJson(Map<String, dynamic>.from(raw)) : widget.account;
          final now = DateTime.now();
          final (label, fg, bg) = accountLook(a, now);
          final usage = (d['usage'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final support = (d['support'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final log = (d['log'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

          // Uso: por função, quantos dias e o último dia.
          final byEvent = <String, (int, String)>{};
          for (final u in usage) {
            final e = u['event'] as String? ?? '';
            final day = u['day'] as String? ?? '';
            final cur = byEvent[e];
            byEvent[e] = (cur == null ? 1 : cur.$1 + 1, cur == null || day.compareTo(cur.$2) > 0 ? day : cur.$2);
          }

          Widget row(String k, String v) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 140, child: Text(k, style: CF.body(14, color: CF.muted))),
                  Expanded(child: Text(v, style: CF.body(14.5, weight: FontWeight.w600))),
                ]),
              );

          final period = a.state == 'trialing' || a.status == 'trialing'
              ? ('Teste até', a.trialEndsAt == null ? '—' : dmy(a.trialEndsAt!))
              : ('Período até', a.currentPeriodEnd == null ? '—' : dmy(a.currentPeriodEnd!));

          return ListView(padding: const EdgeInsets.all(18), shrinkWrap: true, children: [
            Row(children: [
              Expanded(child: Text(a.email, style: CF.body(19, weight: FontWeight.w700))),
              IconButton(tooltip: 'Fechar', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              StatusChip(label, fg: fg, bg: bg),
              if (a.founder) const StatusChip('Fundador', fg: CF.ink, bg: Color(0xFFFFEFC2)),
              if (a.internal) const StatusChip('Conta interna', fg: CF.grey, bg: CF.greyBg),
            ]),
            const SizedBox(height: 12),
            Panel(
              child: Column(children: [
                row('Profissão', a.profession ?? '—'),
                row('Plataforma', a.platformLabel),
                row('Cadastro', dmy(a.createdAt)),
                row('Último acesso', sinceText(a.lastActivity, now)),
                row('Clientes ativos', '${a.clients}'),
                row('Plano', '${a.plan == 'essencial' ? 'Essencial' : 'Profissional'}'),
                row(period.$1, period.$2),
              ]),
            ),
            const SizedBox(height: 12),
            Panel(
              title: 'Ações',
              icon: Icons.bolt_rounded,
              color: CF.lap,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (a.status == 'trialing')
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _extend(a),
                      icon: const Icon(Icons.more_time_rounded, size: 18),
                      label: const Text('Estender teste'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _founder(a),
                    icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                    label: Text(a.founder ? 'Tirar fundador' : 'Marcar fundador'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _courtesy(a),
                    icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                    label: Text(a.status == 'courtesy' ? 'Tirar cortesia' : 'Dar cortesia'),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('Toda ação fica registrada no histórico.', style: CF.body(13, color: CF.muted)),
              ]),
            ),
            const SizedBox(height: 12),
            Panel(
              title: 'Uso recente',
              icon: Icons.touch_app_rounded,
              color: CF.blue,
              child: byEvent.isEmpty
                  ? Text('Ainda sem registro de uso.', style: CF.body(14.5, color: CF.muted))
                  : Column(children: [
                      for (final e in byEvent.entries)
                        row(usageNames[e.key] ?? e.key, '${e.value.$1} ${e.value.$1 == 1 ? 'dia' : 'dias'} · último em ${_dayText(e.value.$2)}'),
                    ]),
            ),
            if (support.isNotEmpty) ...[
              const SizedBox(height: 12),
              Panel(
                title: 'Pedidos de suporte',
                icon: Icons.support_agent_rounded,
                color: CF.violet,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final s in support)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s['message'] as String? ?? '', style: CF.body(14.5)),
                        Text(whenText(s['created_at']), style: CF.body(12.5, color: CF.muted)),
                      ]),
                    ),
                ]),
              ),
            ],
            if (log.isNotEmpty) ...[
              const SizedBox(height: 12),
              Panel(
                title: 'Histórico de ações',
                icon: Icons.history_rounded,
                color: CF.grey,
                child: Column(children: [
                  for (final l in log) row(whenText(l['created_at']), actionText(l['action'] as String?, l['detail'])),
                ]),
              ),
            ],
          ]);
        },
      );
}

String _dayText(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : dm(d);
}

String whenText(Object? iso) {
  final d = iso is String ? DateTime.tryParse(iso)?.toLocal() : null;
  return d == null ? '' : '${dmy(d)} ${two(d.hour)}:${two(d.minute)}';
}

/// Texto simples para uma ação do registro.
String actionText(String? action, Object? detail) {
  final d = detail is Map ? detail : const {};
  switch (action) {
    case 'estender_teste':
      return 'Estendeu o teste em ${d['dias']} dias';
    case 'fundador':
      return d['ligado'] == true ? 'Marcou como fundador' : 'Tirou a marca de fundador';
    case 'cortesia':
      return d['ligado'] == true ? 'Deu cortesia' : 'Tirou a cortesia';
    default:
      return action ?? '';
  }
}
