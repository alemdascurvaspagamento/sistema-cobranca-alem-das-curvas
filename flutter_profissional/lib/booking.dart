import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'agenda_events.dart';
import 'billing/billing_engine.dart';
import 'billing/billing_store.dart';
import 'config.dart';
import 'data/ids.dart';
import 'ui/cf_theme.dart';
import 'ui/motion.dart';
import 'ui/widgets.dart';

// ---------------------------------------------------------------------------
// Dados
// ---------------------------------------------------------------------------

class BookingWindow {
  const BookingWindow(this.start, this.end);
  final String start, end;
  Map<String, String> toJson() => {'start': start, 'end': end};
}

class BookingSettings {
  BookingSettings({
    required this.slug,
    this.enabled = false,
    this.title = '',
    Set<int>? weekdays,
    List<BookingWindow>? windows,
    this.slotMinutes = 60,
    this.daysAhead = 14,
    List<String>? services,
  })  : weekdays = weekdays ?? {1, 2, 3, 4, 5},
        windows = windows ?? const [BookingWindow('08:00', '12:00'), BookingWindow('14:00', '19:00')],
        services = services ?? [];

  String slug;
  bool enabled;
  String title;
  Set<int> weekdays;
  List<BookingWindow> windows;
  int slotMinutes;
  int daysAhead;
  List<String> services;

  String get link => '${AppConfig.publicUrl}/?agendar=$slug';
}

class BookingRequest {
  const BookingRequest({
    required this.id,
    required this.name,
    required this.phone,
    required this.service,
    required this.date,
    required this.time,
    required this.note,
  });
  final String id, name, phone, service, time, note;
  final DateTime date;
}

String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _hhmm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// Link de horários: configuração, horários ocupados publicados e solicitações.
class Booking extends ChangeNotifier {
  Booking._();
  static final instance = Booking._();

  BookingSettings? settings;
  final List<BookingRequest> pending = [];
  bool _cloud = false;
  Timer? _debounce;
  Timer? _poll;
  void Function(String message)? onError;

  SupabaseClient get _db => Supabase.instance.client;

  void clear() {
    settings = null;
    pending.clear();
    _cloud = false;
    _debounce?.cancel();
    _poll?.cancel();
    BillingStore.instance.removeListener(_schedulePublish);
    AgendaEvents.instance.removeListener(_schedulePublish);
    notifyListeners();
  }

  Future<void> load() async {
    try {
      final rows = await _db.from('cf_booking_settings').select().limit(1);
      if (rows.isEmpty) {
        final services = BillingStore.instance.terms.session;
        final created = await _db
            .from('cf_booking_settings')
            .insert({'services': _defaultServices(services)})
            .select()
            .single();
        settings = _parse(created);
      } else {
        settings = _parse(rows.first);
      }
      _cloud = true;
      await loadRequests();
      BillingStore.instance.addListener(_schedulePublish);
      AgendaEvents.instance.addListener(_schedulePublish);
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(minutes: 2), (_) => loadRequests());
      if (settings!.enabled) unawaited(publishBusy());
    } catch (e) {
      debugPrint('Okday: link de horários indisponível ($e)');
    }
    notifyListeners();
  }

  static List<String> _defaultServices(String session) => [
        '${capitalize(session)} avulsa',
        'Reposição',
        'Avaliação',
      ];

  BookingSettings _parse(Map<String, dynamic> r) => BookingSettings(
        slug: r['slug'] as String,
        enabled: r['enabled'] as bool? ?? false,
        title: r['title'] as String? ?? '',
        weekdays: {for (final d in (r['weekdays'] as List? ?? const [])) (d as num).toInt()},
        windows: [
          for (final w in (r['windows'] as List? ?? const []))
            BookingWindow('${(w as Map)['start']}', '${w['end']}'),
        ],
        slotMinutes: (r['slot_minutes'] as num?)?.toInt() ?? 60,
        daysAhead: (r['days_ahead'] as num?)?.toInt() ?? 14,
        services: [for (final s in (r['services'] as List? ?? const [])) '$s'],
      );

  Future<void> loadRequests() async {
    if (!_cloud && settings == null) return;
    try {
      final rows = await _db
          .from('cf_booking_requests')
          .select()
          .eq('status', 'pending')
          .gte('date', _d(BillingStore.instance.today))
          .order('date')
          .order('time');
      pending
        ..clear()
        ..addAll([
          for (final r in rows)
            BookingRequest(
              id: r['id'] as String,
              name: r['name'] as String,
              phone: r['phone'] as String,
              service: r['service'] as String? ?? '',
              date: DateTime.parse(r['date'] as String),
              time: r['time'] as String,
              note: r['note'] as String? ?? '',
            ),
        ]);
      notifyListeners();
    } catch (e) {
      debugPrint('Okday: solicitações indisponíveis ($e)');
    }
  }

  Future<void> save(BookingSettings s) async {
    settings = s;
    notifyListeners();
    if (!_cloud) return;
    try {
      await _db.from('cf_booking_settings').update({
        'enabled': s.enabled,
        'title': s.title,
        'weekdays': (s.weekdays.toList()..sort()),
        'windows': [for (final w in s.windows) w.toJson()],
        'slot_minutes': s.slotMinutes,
        'days_ahead': s.daysAhead,
        'services': s.services,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('slug', s.slug);
      if (s.enabled) await publishBusy();
    } catch (_) {
      onError?.call('Não foi possível salvar o link de horários. Confira a internet.');
    }
  }

  /// Troca o link (o antigo para de funcionar).
  Future<void> newLink() async {
    final s = settings;
    if (s == null || !_cloud) return;
    final slug = newUuid().replaceAll('-', '');
    try {
      await _db.from('cf_booking_settings').update({'slug': slug}).eq('slug', s.slug);
      s.slug = slug;
      notifyListeners();
    } catch (_) {
      onError?.call('Não foi possível trocar o link. Tente de novo.');
    }
  }

  void _schedulePublish() {
    if (!_cloud || settings?.enabled != true) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), publishBusy);
  }

  /// Envia só "ocupado das X às Y" dos próximos dias (sem nomes).
  Future<void> publishBusy() async {
    final s = settings;
    if (s == null || !_cloud) return;
    final store = BillingStore.instance;
    final busy = <Map<String, Object>>[];
    final today = store.today;
    for (var i = 0; i <= s.daysAhead; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      for (final (p, line) in store.sessionsOn(day)) {
        if (!store.happens(line.outcome) || line.time.isEmpty) continue;
        final start = minutesOf(line.time);
        busy.add({'date': _d(day), 'start': start, 'end': start + p.durationMinutes});
      }
      for (final e in AgendaEvents.instance.on(day)) {
        busy.add({'date': _d(day), 'start': e.startMinute, 'end': e.endMinute});
      }
      final h = store.holidayOn(day);
      if (h != null && h.noClass) busy.add({'date': _d(day), 'start': 0, 'end': 24 * 60});
    }
    try {
      await _db.from('cf_booking_settings').update({
        'busy': busy,
        'busy_updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('slug', s.slug);
    } catch (e) {
      debugPrint('Okday: não publicou horários ocupados ($e)');
    }
  }

  /// Cliente cadastrado com o mesmo telefone (compara os últimos 8 dígitos).
  StudentPlan? matchClient(BookingRequest r) {
    final tail = r.phone.length >= 8 ? r.phone.substring(r.phone.length - 8) : r.phone;
    for (final p in BillingStore.instance.activePlans) {
      final digits = p.phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 8 && digits.endsWith(tail)) return p;
    }
    return null;
  }

  Future<String?> accept(BuildContext context, BookingRequest r) async {
    final store = BillingStore.instance;
    final client = matchClient(r);
    String? err;
    if (client != null) {
      err = store.addExtra(client.id, r.date, time: r.time, note: r.service);
    }
    if (client == null || err != null) {
      // Sem cadastro (ou já tem atendimento no dia): reserva o horário como compromisso.
      await AgendaEvents.instance.save(PersonalEvent(
        id: newUuid(),
        title: '${r.service.isEmpty ? 'Atendimento' : r.service} · ${r.name}',
        date: r.date,
        time: r.time,
        duration: settings?.slotMinutes ?? 60,
      ));
    }
    await _setStatus(r, 'accepted');
    if (context.mounted) {
      await _whatsApp(r.phone,
          'Oi, ${r.name.split(' ').first}! Confirmado: ${r.service.isEmpty ? 'atendimento' : r.service.toLowerCase()} '
          '${_dayText(r.date)} às ${r.time}. Até lá! 👍');
    }
    return client == null ? 'sem cadastro' : null;
  }

  Future<void> decline(BuildContext context, BookingRequest r) async {
    await _setStatus(r, 'declined');
    final link = settings?.link ?? '';
    if (context.mounted) {
      await _whatsApp(r.phone,
          'Oi, ${r.name.split(' ').first}! Infelizmente ${_dayText(r.date)} às ${r.time} não vai dar. '
          'Pode escolher outro horário aqui? $link');
    }
  }

  Future<void> _setStatus(BookingRequest r, String status) async {
    pending.removeWhere((x) => x.id == r.id);
    notifyListeners();
    try {
      await _db.from('cf_booking_requests').update({'status': status}).eq('id', r.id);
    } catch (_) {
      onError?.call('Não foi possível atualizar a solicitação. Confira a internet.');
    }
  }

  static String _dayText(DateTime d) {
    final today = BillingStore.instance.today;
    if (dateOnly(d) == today) return 'hoje';
    if (dateOnly(d) == DateTime(today.year, today.month, today.day + 1)) return 'amanhã';
    return '${weekdayLong[d.weekday - 1].toLowerCase()}, ${ddmm(d)}';
  }

  static Future<void> _whatsApp(String phone, String text) async {
    var p = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (p.length == 10 || p.length == 11) p = '55$p';
    await launchUrl(Uri.parse('https://wa.me/$p?text=${Uri.encodeComponent(text)}'),
        mode: LaunchMode.externalApplication);
  }

  /// Mensagem pronta para mandar o link a um cliente (sem número: a pessoa escolhe o contato).
  Future<void> shareLink(BuildContext context) async {
    final s = settings;
    if (s == null) return;
    final text = 'Oi! Veja meus horários livres e escolha o melhor para você: ${s.link}';
    await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
  }
}

// ---------------------------------------------------------------------------
// Configuração (profissional)
// ---------------------------------------------------------------------------

Future<void> openBookingSettings(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _BookingSettingsScreen()),
    );

class _BookingSettingsScreen extends StatefulWidget {
  const _BookingSettingsScreen();

  @override
  State<_BookingSettingsScreen> createState() => _BookingSettingsScreenState();
}

class _BookingSettingsScreenState extends State<_BookingSettingsScreen> {
  final b = Booking.instance;
  late BookingSettings s;
  final serviceInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cur = b.settings;
    s = BookingSettings(
      slug: cur?.slug ?? '',
      enabled: cur?.enabled ?? false,
      title: cur?.title ?? '',
      weekdays: {...?cur?.weekdays},
      windows: [...?cur?.windows],
      slotMinutes: cur?.slotMinutes ?? 60,
      daysAhead: cur?.daysAhead ?? 14,
      services: [...?cur?.services],
    );
  }

  @override
  void dispose() {
    serviceInput.dispose();
    super.dispose();
  }

  Future<String?> _pickTime(String current) async {
    final m = minutesOf(current);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    return t == null ? null : _hhmm(t.hour * 60 + t.minute);
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: CF.ink,
        labelStyle: CF.body(15, weight: FontWeight.w600, color: selected ? Colors.white : CF.text),
        onSelected: (_) => onTap(),
      );

  @override
  Widget build(BuildContext context) {
    final ready = b.settings != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Link de horários')),
      body: !ready
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Entre na sua conta para usar o link de horários. Na demonstração ele não fica disponível.'),
            )
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(
                      'Seus clientes abrem o link, veem só os horários livres e pedem um horário. '
                      'Você aprova ou recusa na Secretária do Início.',
                      style: CF.body(15, color: CF.muted, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: s.enabled,
                      onChanged: (v) => setState(() => s.enabled = v),
                      title: Text('Link ativo', style: CF.body(17, weight: FontWeight.w700)),
                      subtitle: Text(s.enabled ? 'Quem tiver o link pode pedir horário.' : 'Desligado: o link mostra "não está ativo".',
                          style: CF.body(14, color: CF.muted)),
                    ),
                    const SizedBox(height: 8),
                    Panel(
                      icon: Icons.link_rounded,
                      color: CF.blue,
                      title: 'Seu link',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        SelectableText(s.link, style: CF.body(14, color: CF.blue)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          FilledButton.icon(
                            onPressed: () => b.shareLink(context),
                            style: FilledButton.styleFrom(backgroundColor: CF.whatsapp),
                            icon: const Icon(Icons.chat_rounded, size: 18),
                            label: const Text('Enviar pelo WhatsApp'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: s.link));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiado.')));
                              }
                            },
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Copiar'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await b.newLink();
                              if (mounted) setState(() => s.slug = b.settings!.slug);
                            },
                            child: const Text('Gerar link novo'),
                          ),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Panel(
                      icon: Icons.event_available_rounded,
                      color: CF.green,
                      title: 'Quando atendo',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (var d = 1; d <= 7; d++)
                            _chip(weekdayShort[d - 1], s.weekdays.contains(d), () => setState(() {
                                  s.weekdays.contains(d) ? s.weekdays.remove(d) : s.weekdays.add(d);
                                })),
                        ]),
                        const SizedBox(height: 14),
                        for (var i = 0; i < s.windows.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              Text('Das ', style: CF.body(15)),
                              OutlinedButton(
                                onPressed: () async {
                                  final t = await _pickTime(s.windows[i].start);
                                  if (t != null) setState(() => s.windows[i] = BookingWindow(t, s.windows[i].end));
                                },
                                child: Text(s.windows[i].start),
                              ),
                              Text(' às ', style: CF.body(15)),
                              OutlinedButton(
                                onPressed: () async {
                                  final t = await _pickTime(s.windows[i].end);
                                  if (t != null) setState(() => s.windows[i] = BookingWindow(s.windows[i].start, t));
                                },
                                child: Text(s.windows[i].end),
                              ),
                              const Spacer(),
                              if (s.windows.length > 1)
                                IconButton(
                                  tooltip: 'Remover faixa',
                                  onPressed: () => setState(() => s.windows.removeAt(i)),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                            ]),
                          ),
                        if (s.windows.length < 3)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setState(() => s.windows.add(const BookingWindow('18:00', '21:00'))),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Adicionar faixa de horário'),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text('Duração de cada horário', style: CF.body(15, weight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final m in const [30, 45, 50, 60, 90])
                            _chip(durationText(m), s.slotMinutes == m, () => setState(() => s.slotMinutes = m)),
                        ]),
                        const SizedBox(height: 12),
                        Text('Mostrar os próximos', style: CF.body(15, weight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final d in const [7, 14, 30])
                            _chip('$d dias', s.daysAhead == d, () => setState(() => s.daysAhead = d)),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Panel(
                      icon: Icons.list_alt_rounded,
                      color: CF.violet,
                      title: 'O que o cliente pode pedir',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final sv in s.services)
                            InputChip(label: Text(sv), onDeleted: () => setState(() => s.services.remove(sv))),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: serviceInput,
                              decoration: const InputDecoration(hintText: 'Ex.: Reunião, Avaliação'),
                              onSubmitted: (_) => _addService(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(onPressed: _addService, child: const Text('Adicionar')),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        await b.save(s);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link de horários salvo. Tá ok!')));
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Salvar'),
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }

  void _addService() {
    final v = serviceInput.text.trim();
    if (v.isEmpty || s.services.contains(v)) return;
    setState(() {
      s.services.add(v);
      serviceInput.clear();
    });
  }
}

// ---------------------------------------------------------------------------
// Solicitações no Início
// ---------------------------------------------------------------------------

class BookingRequestsPanel extends StatelessWidget {
  const BookingRequestsPanel({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Booking.instance,
        builder: (context, _) {
          final list = Booking.instance.pending;
          if (list.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Panel(
              icon: Icons.event_seat_rounded,
              color: CF.violet,
              ringing: true,
              title: list.length == 1 ? '1 pedido de horário' : '${list.length} pedidos de horário',
              child: Column(children: [
                for (var i = 0; i < list.length; i++) ...[
                  FadeInUp(delayMs: 120 * (i + 1), child: _RequestTile(r: list[i])),
                  if (i < list.length - 1) const Divider(height: 1),
                ],
              ]),
            ),
          );
        },
      );
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.r});
  final BookingRequest r;

  @override
  Widget build(BuildContext context) {
    final b = Booking.instance;
    final client = b.matchClient(r);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const IconBadge(Icons.person_rounded, color: CF.violet, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: CF.body(16, weight: FontWeight.w700)),
              Text(
                '${r.service.isEmpty ? '' : '${r.service} · '}${capitalize(Booking._dayText(r.date))} às ${r.time}',
                style: CF.body(14, color: CF.text, weight: FontWeight.w600),
              ),
              Text(client != null ? 'Já é seu ${BillingStore.instance.terms.client}' : 'Ainda não cadastrad${BillingStore.instance.terms.g('a', 'o')}',
                  style: CF.body(13, color: CF.muted)),
              if (r.note.isNotEmpty) Text('"${r.note}"', style: CF.body(13, color: CF.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          FilledButton.icon(
            onPressed: () async {
              final res = await b.accept(context, r);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(res == null
                      ? 'Aceito: já está na agenda e na cobrança.'
                      : 'Aceito: horário reservado na agenda. Cadastre ${r.name.split(' ').first} para entrar na cobrança.'),
                ));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: CF.green, minimumSize: const Size(0, 40)),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Aceitar'),
          ),
          OutlinedButton.icon(
            onPressed: () => b.decline(context, r),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
            icon: const Icon(Icons.close_rounded, size: 18, color: CF.red),
            label: const Text('Recusar'),
          ),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Página pública (cliente)
// ---------------------------------------------------------------------------

class BookingPublicPage extends StatefulWidget {
  const BookingPublicPage({super.key, required this.slug});
  final String slug;

  @override
  State<BookingPublicPage> createState() => _BookingPublicPageState();
}

class _BookingPublicPageState extends State<BookingPublicPage> {
  Map<String, dynamic>? data;
  bool loading = true;
  String? fatal;
  DateTime? day;
  String? time;
  String? service;
  final name = TextEditingController();
  final phone = TextEditingController();
  final note = TextEditingController();
  bool sending = false;
  String? error;
  bool done = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final r = await Supabase.instance.client.rpc('cf_public_booking', params: {'p_slug': widget.slug});
      if (r == null) {
        fatal = 'Este link não está ativo. Fale direto com o profissional.';
      } else {
        data = Map<String, dynamic>.from(r as Map);
        final services = (data!['services'] as List? ?? const []);
        if (services.isNotEmpty) service ??= '${services.first}';
      }
    } catch (_) {
      fatal = 'Não foi possível abrir os horários agora. Confira a internet e tente de novo.';
    }
    if (mounted) setState(() => loading = false);
  }

  /// Horários livres de um dia.
  List<String> _slots(DateTime d) {
    final m = data!;
    final weekdays = {for (final x in (m['weekdays'] as List)) (x as num).toInt()};
    if (!weekdays.contains(d.weekday)) return const [];
    final slot = (m['slot_minutes'] as num).toInt();
    final key = _d(d);
    final busy = <(int, int)>[];
    for (final b in (m['busy'] as List? ?? const [])) {
      final mm = b as Map;
      if ('${mm['date']}' != key) continue;
      final s = mm['start'];
      final start = s is num ? s.toInt() : minutesOf('$s');
      final e = mm['end'];
      final end = e is num ? e.toInt() : start + slot;
      busy.add((start, end));
    }
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    final nowMin = now.hour * 60 + now.minute + 60; // pelo menos 1 h de antecedência
    final out = <String>[];
    for (final w in (m['windows'] as List)) {
      final ww = w as Map;
      var t = minutesOf('${ww['start']}');
      final end = minutesOf('${ww['end']}');
      while (t + slot <= end) {
        final free = busy.every((b) => !(t < b.$2 && b.$1 < t + slot));
        if (free && (!isToday || t >= nowMin)) out.add(_hhmm(t));
        t += slot;
      }
    }
    return out;
  }

  Future<void> _send() async {
    if (day == null || time == null) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final r = await Supabase.instance.client.rpc('cf_request_booking', params: {
        'p_slug': widget.slug,
        'p_name': name.text,
        'p_phone': phone.text,
        'p_service': service ?? '',
        'p_date': _d(day!),
        'p_time': time,
        'p_note': note.text,
      });
      if (r == 'ok') {
        setState(() => done = true);
      } else {
        setState(() => error = '$r');
        if ('$r'.contains('ocupado') || '$r'.contains('já pediu')) {
          time = null;
          await _load();
        }
      }
    } catch (_) {
      setState(() => error = 'Não foi possível enviar. Confira a internet e tente de novo.');
    }
    if (mounted) setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CF.bg,
      appBar: AppBar(
        backgroundColor: CF.ink,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const BrandMark(size: 28),
          const SizedBox(width: 8),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'Ok', style: CF.body(20, color: CF.lap, weight: FontWeight.w800)),
            TextSpan(text: 'day', style: CF.body(20, color: Colors.white, weight: FontWeight.w800)),
          ])),
        ]),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : fatal != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(fatal!, textAlign: TextAlign.center, style: CF.body(17))))
              : done
                  ? _done()
                  : _form(),
    );
  }

  Widget _done() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const PopCheck(color: CF.green, size: 72),
            const SizedBox(height: 14),
            Text('Pedido enviado!', style: CF.body(26, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              '${capitalize(weekdayLong[day!.weekday - 1].toLowerCase())}, ${ddmm(day!)} às $time.\n'
              'Você recebe a confirmação pelo WhatsApp assim que for aprovado.',
              textAlign: TextAlign.center,
              style: CF.body(16, color: CF.muted, height: 1.4),
            ),
          ]),
        ),
      );

  Widget _form() {
    final m = data!;
    final ahead = (m['days_ahead'] as num).toInt();
    final now = DateTime.now();
    final days = [
      for (var i = 0; i <= ahead; i++) DateTime(now.year, now.month, now.day + i),
    ].where((d) => _slots(d).isNotEmpty).toList();
    final services = [for (final s in (m['services'] as List? ?? const [])) '$s'];
    final slots = day == null ? const <String>[] : _slots(day!);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${m['title']}', style: CF.body(26, weight: FontWeight.w800)),
            Text('Escolha um horário livre e peça para marcar.', style: CF.body(15, color: CF.muted)),
            const SizedBox(height: 16),
            if (services.isNotEmpty) ...[
              Text('O que você quer marcar?', style: CF.body(16, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in services)
                  ChoiceChip(
                    label: Text(s),
                    selected: service == s,
                    showCheckmark: false,
                    selectedColor: CF.ink,
                    labelStyle: CF.body(15, weight: FontWeight.w600, color: service == s ? Colors.white : CF.text),
                    onSelected: (_) => setState(() => service = s),
                  ),
              ]),
              const SizedBox(height: 16),
            ],
            Text('Dia', style: CF.body(16, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (days.isEmpty)
              Text('Nenhum horário livre nos próximos dias. Fale direto com o profissional.', style: CF.body(15, color: CF.muted))
            else
              SizedBox(
                height: 74,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final d in days)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _DayChip(
                        day: d,
                        selected: day != null && dateOnly(day!) == d,
                        onTap: () => setState(() {
                          day = d;
                          time = null;
                        }),
                      ),
                    ),
                ]),
              ),
            if (day != null) ...[
              const SizedBox(height: 16),
              Text('Horário', style: CF.body(16, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in slots)
                  ChoiceChip(
                    label: Text(t),
                    selected: time == t,
                    showCheckmark: false,
                    selectedColor: CF.green,
                    labelStyle: CF.body(16, weight: FontWeight.w700, color: time == t ? Colors.white : CF.text),
                    onSelected: (_) => setState(() => time = t),
                  ),
              ]),
            ],
            if (time != null) ...[
              const SizedBox(height: 18),
              TextField(controller: name, textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Seu nome')),
              const SizedBox(height: 10),
              TextField(controller: phone, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Seu WhatsApp com DDD', hintText: '(11) 99999-9999')),
              const SizedBox(height: 10),
              TextField(controller: note, maxLength: 300, decoration: const InputDecoration(labelText: 'Recado (opcional)')),
              if (error != null) ...[
                const SizedBox(height: 4),
                Text(error!, style: CF.body(15, color: CF.red, weight: FontWeight.w600)),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: sending ? null : _send,
                child: Text(sending ? 'Enviando...' : 'Pedir ${ddmm(day!)} às $time'),
              ),
              const SizedBox(height: 8),
              Text('O profissional confirma pelo WhatsApp. Seus dados são usados só para este agendamento.',
                  textAlign: TextAlign.center, style: CF.body(13, color: CF.muted)),
            ],
          ]),
        ),
      ),
    ]);
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.selected, required this.onTap});
  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? CF.ink : CF.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 62,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: CF.line)),
            alignment: Alignment.center,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(weekdayShort[day.weekday - 1], style: CF.body(13, color: selected ? Colors.white70 : CF.muted)),
              Text('${day.day}', style: CF.score(24, color: selected ? Colors.white : CF.text)),
            ]),
          ),
        ),
      );
}
