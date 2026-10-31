import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'agenda_events.dart';
import 'billing/billing_store.dart';
import 'config.dart';
import 'data/ids.dart';
import 'ui/cf_theme.dart';
import 'ui/widgets.dart';

String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Link de calendário (.ics) para ver a agenda do Okday no Office 365/Outlook,
/// Google Agenda e Calendário do iPhone. Vai só do Okday para lá.
class CalendarFeed extends ChangeNotifier {
  CalendarFeed._();
  static final instance = CalendarFeed._();

  String? token;
  bool showNames = false;
  bool _cloud = false;
  Timer? _debounce;

  SupabaseClient get _db => Supabase.instance.client;

  String get httpsLink => '${AppConfig.supabaseUrl}/functions/v1/cf-calendar?t=$token';
  String get webcalLink => httpsLink.replaceFirst(RegExp('^https?://'), 'webcal://');

  void clear() {
    token = null;
    _cloud = false;
    _debounce?.cancel();
    BillingStore.instance.removeListener(_schedule);
    AgendaEvents.instance.removeListener(_schedule);
    notifyListeners();
  }

  Future<void> load() async {
    try {
      final rows = await _db.from('cf_calendar_feed').select('token, show_names').limit(1);
      if (rows.isNotEmpty) {
        token = rows.first['token'] as String;
        showNames = rows.first['show_names'] as bool? ?? false;
        _cloud = true;
        BillingStore.instance.addListener(_schedule);
        AgendaEvents.instance.addListener(_schedule);
        unawaited(publish());
      }
    } catch (e) {
      debugPrint('Okday: calendário indisponível ($e)');
    }
    notifyListeners();
  }

  /// Cria o link na primeira vez que a pessoa pede.
  Future<void> create() async {
    try {
      final row = await _db.from('cf_calendar_feed').insert({}).select('token, show_names').single();
      token = row['token'] as String;
      _cloud = true;
      BillingStore.instance.addListener(_schedule);
      AgendaEvents.instance.addListener(_schedule);
      await publish();
    } catch (e) {
      debugPrint('Okday: não criou o calendário ($e)');
    }
    notifyListeners();
  }

  Future<void> setShowNames(bool v) async {
    showNames = v;
    notifyListeners();
    if (!_cloud) return;
    try {
      await _db.from('cf_calendar_feed').update({'show_names': v}).neq('token', '');
      await publish();
    } catch (_) {}
  }

  Future<void> newLink() async {
    if (!_cloud) return;
    try {
      final row = await _db
          .from('cf_calendar_feed')
          .update({'token': _randomToken()})
          .neq('token', '')
          .select('token')
          .single();
      token = row['token'] as String;
      notifyListeners();
    } catch (_) {}
  }

  static String _randomToken() => (newUuid() + newUuid()).replaceAll('-', '');

  void _schedule() {
    if (!_cloud) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), publish);
  }

  /// Atendimentos e compromissos de 30 dias atrás a 60 dias à frente.
  Future<void> publish() async {
    if (!_cloud) return;
    final store = BillingStore.instance;
    final t = store.terms;
    final today = store.today;
    final events = <Map<String, Object>>[];
    for (var i = -30; i <= 60; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      for (final (p, line) in store.sessionsOn(day)) {
        if (!store.happens(line.outcome) || line.time.isEmpty) continue;
        final start = minutesOf(line.time);
        events.add({
          'id': '${p.id}-${_d(day)}',
          'date': _d(day),
          'start': start,
          'end': start + p.durationMinutes,
          'title': showNames ? '${capitalize(t.session)} · ${p.name}' : '${capitalize(t.session)} (Okday)',
        });
      }
      for (final e in AgendaEvents.instance.on(day)) {
        events.add({
          'id': '${e.id}-${_d(day)}',
          'date': _d(day),
          'start': e.allDay ? -1 : e.startMinute,
          'end': e.allDay ? -1 : e.endMinute,
          'title': e.title,
        });
      }
    }
    try {
      await _db.from('cf_calendar_feed').update({
        'events': events,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).neq('token', '');
    } catch (e) {
      debugPrint('Okday: não publicou o calendário ($e)');
    }
  }
}

Future<void> openCalendarFeed(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _CalendarFeedScreen()));

class _CalendarFeedScreen extends StatelessWidget {
  const _CalendarFeedScreen();

  @override
  Widget build(BuildContext context) {
    final f = CalendarFeed.instance;
    final cloud = BillingStore.instance.isCloud;
    return Scaffold(
      appBar: AppBar(title: const Text('Ver no seu calendário')),
      body: ListenableBuilder(
        listenable: f,
        builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                  'Seus atendimentos e compromissos do Okday aparecem no Office 365/Outlook, no Google Agenda '
                  'ou no Calendário do iPhone. É só colar o link uma vez.',
                  style: CF.body(15, color: CF.muted, height: 1.35),
                ),
                const SizedBox(height: 14),
                if (!cloud)
                  const Text('Entre na sua conta para usar. Na demonstração não fica disponível.')
                else if (f.token == null)
                  FilledButton.icon(
                    onPressed: f.create,
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('Criar meu link de calendário'),
                  )
                else ...[
                  Panel(
                    icon: Icons.link_rounded,
                    color: CF.blue,
                    title: 'Seu link de calendário',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SelectableText(f.httpsLink, style: CF.body(13, color: CF.blue)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        FilledButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: f.httpsLink));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiado.')));
                            }
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copiar link'),
                        ),
                        TextButton(onPressed: f.newLink, child: const Text('Gerar link novo')),
                      ]),
                      const SizedBox(height: 4),
                      Text('Não compartilhe: quem tiver o link vê sua agenda.', style: CF.body(13, color: CF.muted)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: f.showNames,
                    onChanged: f.setShowNames,
                    title: Text('Mostrar o nome do cliente', style: CF.body(16, weight: FontWeight.w600)),
                    subtitle: Text(
                        f.showNames ? 'Ex.: "Aula · Carlão"' : 'Desligado: aparece só "Aula (Okday)", mais privado.',
                        style: CF.body(14, color: CF.muted)),
                  ),
                  const SizedBox(height: 10),
                  const _Steps(
                    icon: Icons.mail_rounded,
                    title: 'Office 365 / Outlook',
                    steps: [
                      'Abra o Outlook no computador (outlook.office.com).',
                      'Vá em Calendário › Adicionar calendário › Assinar da Web.',
                      'Cole o link, dê o nome "Okday" e toque em Importar.',
                    ],
                  ),
                  const _Steps(
                    icon: Icons.calendar_month_rounded,
                    title: 'Google Agenda',
                    steps: [
                      'Abra calendar.google.com no computador.',
                      'Em "Outras agendas", toque no + › Do URL.',
                      'Cole o link e toque em Adicionar agenda.',
                    ],
                  ),
                  const _Steps(
                    icon: Icons.phone_iphone_rounded,
                    title: 'iPhone (Calendário)',
                    steps: [
                      'Abra Ajustes › Calendário › Contas › Adicionar Conta.',
                      'Toque em Outra › Adicionar Calendário Assinado.',
                      'Cole o link e toque em Seguinte › Salvar.',
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'As mudanças chegam ao seu calendário no ritmo de cada um: no iPhone em minutos, no Outlook '
                    'em algumas horas, no Google em até um dia. O Okday atualiza o link sempre que você usa o app.',
                    style: CF.body(13.5, color: CF.muted, height: 1.35),
                  ),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.icon, required this.title, required this.steps});
  final IconData icon;
  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(
          icon: icon,
          color: CF.violet,
          title: title,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${i + 1}. ${steps[i]}', style: CF.body(15, height: 1.3)),
              ),
          ]),
        ),
      );
}
