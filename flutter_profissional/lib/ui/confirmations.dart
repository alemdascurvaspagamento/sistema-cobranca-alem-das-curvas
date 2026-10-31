import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_store.dart';

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

  /// Abre o WhatsApp com a mensagem pronta e marca como enviada.
  Future<void> send(BuildContext context, StudentPlan plan, LessonLine line) async {
    var phone = plan.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length == 10 || phone.length == 11) phone = '55$phone';
    final url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(messageFor(plan, line))}');
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp neste aparelho.')),
        );
      }
      return;
    }
    await _mark(plan.id, line.date);
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
          const Text('Use {nome}, {atendimento}, {quando} e {hora}: o Okday troca pelos dados de cada um ({quando} vira "hoje" ou "amanhã").'),
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
