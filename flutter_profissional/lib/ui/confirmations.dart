import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_store.dart';
import '../billing/pro_gate.dart';
import 'cf_theme.dart';
import 'whatsapp.dart';

/// Confirmação dos atendimentos do dia pelo WhatsApp.
///
/// O WhatsApp não deixa apps enviarem sozinhos: cada toque abre a conversa
/// com a mensagem pronta e a pessoa confirma o envio. Aqui só lembramos para
/// quem já foi, na conta da pessoa (vale no celular e no computador).
class Confirmations extends ChangeNotifier {
  Confirmations._();
  static final instance = Confirmations._();

  static const _sentKey = 'cf_confirm_sent';
  static const _templateKey = 'cf_confirm_template';

  /// Texto padrão. {nome}, {atendimento}, {quando} (hoje/amanhã) e {hora} são trocados na hora.
  static const defaultTemplate = 'Oi, {nome}! Passando para confirmar {atendimento} de {quando} às {hora}. Tudo certo? 👍';

  Map<String, List<String>>? _sent;
  String? _template;

  Map<String, dynamic> get _meta {
    try {
      return Supabase.instance.client.auth.currentUser?.userMetadata ?? const {};
    } catch (_) {
      return const {};
    }
  }

  Map<String, List<String>> get _sentMap => _sent ??= {
        for (final e in ((_meta[_sentKey] as Map?) ?? const {}).entries)
          '${e.key}': [for (final id in (e.value as List? ?? const [])) '$id'],
      };

  /// Esquece o texto e as marcações da conta anterior (ao sair da conta).
  void clear() {
    _sent = null;
    _template = null;
    notifyListeners();
  }

  String get template {
    final t = _template ?? _meta[_templateKey] as String?;
    return (t == null || t.trim().isEmpty) ? defaultTemplate : t;
  }

  static String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool sent(String planId, DateTime date) => _sentMap[_day(date)]?.contains(planId) ?? false;

  /// Atendimentos de hoje que dá para confirmar: marcados, ainda não feitos e com telefone.
  static bool canConfirm(StudentPlan plan, LessonLine line, DateTime today) => canConfirmOn(plan, line, today);

  /// O mesmo para um dia qualquer (usado para confirmar amanhã, à noite).
  static bool canConfirmOn(StudentPlan plan, LessonLine line, DateTime day) =>
      dateOnly(line.date) == dateOnly(day) &&
      line.outcome == LessonOutcome.charged &&
      line.record?.status != LessonStatus.completed &&
      plan.phone.replaceAll(RegExp(r'[^0-9]'), '').length >= 10;

  String messageFor(StudentPlan plan, LessonLine line) {
    final t = BillingStore.instance.terms;
    final first = plan.name.split(' ').first;
    final what = '${t.g('nossa', 'nosso')} ${t.session}';
    final today = dateOnly(BillingStore.instance.today);
    final tomorrow = dateOnly(line.date).isAfter(today);
    var text = template;
    // Texto antigo, salvo antes de existir {quando}: troca "hoje" por "amanhã".
    if (tomorrow && !text.contains('{quando}')) text = text.replaceAll('hoje', 'amanhã');
    return text
        .replaceAll('{nome}', first)
        .replaceAll('{atendimento}', what)
        .replaceAll('{quando}', tomorrow ? 'amanhã' : 'hoje')
        .replaceAll('{hora}', line.time.isEmpty ? 'no horário combinado' : line.time);
  }

  /// Abre o WhatsApp com a mensagem pronta e marca como enviada. Devolve se abriu.
  Future<bool> send(BuildContext context, StudentPlan plan, LessonLine line) async {
    if (!ProGate.check(context, 'A confirmação pelo WhatsApp')) return false;
    var phone = plan.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length == 10 || phone.length == 11) phone = '55$phone';
    final url = whatsAppLink(phone, text: messageFor(plan, line));
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp neste aparelho.')),
        );
      }
      return false;
    }
    await _mark(plan.id, line.date);
    return true;
  }

  Future<void> _mark(String planId, DateTime date) async {
    final key = _day(date);
    final map = _sentMap;
    // Guarda só hoje e ontem: o resto não importa mais.
    map.removeWhere((k, _) => k.compareTo(_day(date.subtract(const Duration(days: 1)))) < 0);
    final list = map.putIfAbsent(key, () => []);
    if (!list.contains(planId)) list.add(planId);
    notifyListeners();
    await _save({_sentKey: map});
  }

  Future<void> setTemplate(String text) async {
    _template = text.trim();
    notifyListeners();
    await _save({_templateKey: _template});
  }

  Future<void> _save(Map<String, Object?> data) async {
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(data: data));
    } catch (_) {
      // Demonstração ou sem internet: fica lembrado enquanto o app estiver aberto.
    }
  }
}

/// Edita o texto da confirmação (Configurações).
Future<void> openConfirmTemplate(BuildContext context) {
  final c = Confirmations.instance;
  final controller = TextEditingController(text: c.template);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Mensagem de confirmação'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Use {nome}, {atendimento}, {quando} e {hora}: o Léguno troca pelos dados de cada um ({quando} vira "hoje" ou "amanhã").'),
          const SizedBox(height: 12),
          TextField(controller: controller, minLines: 3, maxLines: 6),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => controller.text = Confirmations.defaultTemplate,
          child: const Text('Voltar ao padrão'),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            c.setTemplate(controller.text);
            Navigator.pop(ctx);
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}


/// "Confirmar todos": abre o WhatsApp de cada atendimento, um depois do outro.
/// O WhatsApp não deixa enviar sozinho: a pessoa toca em enviar e volta aqui.
Future<void> showConfirmQueue(BuildContext context, List<(StudentPlan, LessonLine)> items, {bool tomorrow = false}) {
  if (!ProGate.check(context, 'A confirmação pelo WhatsApp')) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ConfirmQueueSheet(items: items, tomorrow: tomorrow),
  );
}

class _ConfirmQueueSheet extends StatefulWidget {
  const _ConfirmQueueSheet({required this.items, required this.tomorrow});
  final List<(StudentPlan, LessonLine)> items;
  final bool tomorrow;
  @override
  State<_ConfirmQueueSheet> createState() => _ConfirmQueueSheetState();
}

class _ConfirmQueueSheetState extends State<_ConfirmQueueSheet> {
  final skipped = <String>{};
  bool busy = false;

  String _key((StudentPlan, LessonLine) e) => '${e.$1.id}|${e.$2.date.toIso8601String()}|${e.$2.time}';
  bool _sent((StudentPlan, LessonLine) e) => Confirmations.instance.sent(e.$1.id, e.$2.date);
  bool _handled((StudentPlan, LessonLine) e) => _sent(e) || skipped.contains(_key(e));

  (StudentPlan, LessonLine)? get next {
    for (final e in widget.items) {
      if (!_handled(e)) return e;
    }
    return null;
  }

  Future<void> _open((StudentPlan, LessonLine) e) async {
    if (busy) return;
    setState(() => busy = true);
    await Confirmations.instance.send(context, e.$1, e.$2);
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Confirmations.instance,
        builder: (context, _) {
          final items = widget.items;
          final handled = items.where(_handled).length;
          final n = next;
          final first = n == null ? '' : n.$1.name.split(' ').first;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(widget.tomorrow ? 'Confirmar todos de amanhã' : 'Confirmar todos de hoje',
                      style: CF.body(22, weight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    'Toque no botão verde: o WhatsApp abre com a mensagem pronta de cada um. '
                    'Você só toca em enviar e volta aqui, que o próximo já está esperando. Nada é enviado sem você.',
                    style: CF.body(14.5, color: CF.muted, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: items.isEmpty ? 0 : handled / items.length, minHeight: 8),
                  ),
                  const SizedBox(height: 4),
                  Text('$handled de ${items.length}', style: CF.body(13, color: CF.muted)),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(shrinkWrap: true, children: [
                      for (final e in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _sent(e)
                                ? Icons.check_circle_rounded
                                : skipped.contains(_key(e))
                                    ? Icons.remove_circle_outline_rounded
                                    : Icons.radio_button_unchecked_rounded,
                            color: _sent(e) ? CF.green : CF.muted,
                          ),
                          title: Text(e.$1.name, style: CF.body(16, weight: FontWeight.w700)),
                          subtitle: Text(
                            '${e.$2.time.isEmpty ? 'Horário combinado' : e.$2.time}'
                            '${_sent(e) ? ' · enviada' : skipped.contains(_key(e)) ? ' · pulado' : ''}',
                            style: CF.body(13.5, color: CF.muted),
                          ),
                          trailing: Wrap(children: [
                            if (!_handled(e))
                              TextButton(
                                  onPressed: busy ? null : () => setState(() => skipped.add(_key(e))),
                                  child: const Text('Pular')),
                            TextButton(
                              onPressed: busy ? null : () => _open(e),
                              child: Text(_sent(e) ? 'Abrir de novo' : 'Abrir'),
                            ),
                          ]),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  if (n != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: CF.whatsapp, minimumSize: const Size(0, 48)),
                      onPressed: busy ? null : () => _open(n),
                      icon: busy
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.chat_rounded, size: 20),
                      label: Text(handled == 0 ? 'Começar: $first' : 'Próximo: $first'),
                    )
                  else
                    Text('Todos confirmados!',
                        textAlign: TextAlign.center, style: CF.body(17, weight: FontWeight.w700, color: CF.green)),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
                ]),
              ),
            ),
          );
        },
      );
}
