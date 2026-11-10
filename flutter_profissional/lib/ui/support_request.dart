import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cf_theme.dart';

const _appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');

String _platformName() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'iPhone',
    TargetPlatform.android => 'Android',
    _ => defaultTargetPlatform.name,
  };
}

/// Caixinha "Escreva o problema": o pedido chega por e-mail para a equipe.
Future<void> showSupportRequest(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _SupportSheet(),
  );
}

class _SupportSheet extends StatefulWidget {
  const _SupportSheet();
  @override
  State<_SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends State<_SupportSheet> {
  final text = TextEditingController();
  bool sending = false;
  bool sent = false;
  String? error;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = text.text.trim();
    if (msg.length < 5) {
      setState(() => error = 'Conte um pouco mais sobre o problema.');
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final res = await Supabase.instance.client.functions.invoke('cf-support-request',
          body: {'message': msg, 'platform': _platformName(), 'version': _appVersion});
      final d = res.data;
      if (d is Map && d['ok'] == true) {
        if (mounted) setState(() => sent = true);
      } else {
        setState(() => error = d is Map && d['error'] != null ? '${d['error']}' : 'Não foi possível enviar. Tente de novo.');
      }
    } on FunctionException catch (e) {
      final d = e.details;
      setState(() => error = d is Map && d['error'] != null ? '${d['error']}' : 'Não foi possível enviar. Confira a internet.');
    } catch (_) {
      setState(() => error = 'Não foi possível enviar. Confira a internet e tente de novo.');
    }
    if (mounted) setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: sent
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              const Icon(Icons.check_circle_rounded, color: CF.green, size: 56),
              const SizedBox(height: 10),
              Text('Pedido enviado!', style: CF.body(22, weight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('A equipe responde no e-mail da sua conta.',
                  textAlign: TextAlign.center, style: CF.body(15, color: CF.muted)),
              const SizedBox(height: 14),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
            ])
          : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Problema no aplicativo', style: CF.body(20, weight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Algo não funcionou? Conte para a equipe do Léguno. A resposta chega no seu e-mail.',
                  style: CF.body(14.5, color: CF.muted, height: 1.3)),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                minLines: 4,
                maxLines: 8,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Ex.: o pagamento que lancei ontem não aparece no resumo.'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(error!, style: CF.body(14.5, color: CF.red, weight: FontWeight.w600)),
                ),
              FilledButton(
                onPressed: sending ? null : _send,
                child: sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Enviar'),
              ),
            ]),
    );
  }
}
