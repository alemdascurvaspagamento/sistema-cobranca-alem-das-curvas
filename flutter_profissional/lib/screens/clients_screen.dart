import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_screen.dart';
import '../billing/billing_store.dart';
import '../profile/profession_profile.dart';
import '../ui/cf_theme.dart';
import '../ui/widgets.dart';

/// Lista de pacientes, alunos ou clientes (o nome muda com a profissão).
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final store = BillingStore.instance;
  String query = '';
  bool archived = false;
  bool table = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final t = store.terms;
        final source = archived ? store.archivedPlans : store.activePlans;
        final q = query.trim().toLowerCase();
        final list = source
            .where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || p.service.toLowerCase().contains(q))
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageTitle(
            t.clientsTitle,
            subtitle: '${store.activePlans.length} ativ${store.activePlans.length == 1 ? 'o' : 'os'}',
            trailing: FilledButton.icon(
              onPressed: () => openClientForm(context),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text('Novo'),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Buscar por nome ou serviço',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 0, runSpacing: 8, children: [
            ChoiceChip(
              label: Text('Ativos ${store.activePlans.length}'),
              selected: !archived,
              showCheckmark: false,
              selectedColor: CF.ink,
              labelStyle: CF.body(15, weight: FontWeight.w600, color: !archived ? Colors.white : CF.text),
              onSelected: (_) => setState(() => archived = false),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text('Arquivados ${store.archivedPlans.length}'),
              selected: archived,
              showCheckmark: false,
              selectedColor: CF.ink,
              labelStyle: CF.body(15, weight: FontWeight.w600, color: archived ? Colors.white : CF.text),
              onSelected: (_) => setState(() => archived = true),
            ),
          ]),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Panel(
              child: EmptyNote(
                icon: Icons.group_outlined,
                text: archived
                    ? 'Nenhum ${t.client} arquivado.'
                    : (q.isEmpty ? 'Cadastre seu primeiro ${t.client}.' : 'Ninguém encontrado com "$query".'),
                action: archived || q.isNotEmpty
                    ? null
                    : FilledButton(onPressed: () => openClientForm(context), child: Text('Cadastrar ${t.client}')),
              ),
            )
          else
            LayoutBuilder(builder: (context, box) {
              final wide = box.maxWidth >= 980;
              final toggle = Align(
                alignment: Alignment.centerRight,
                child: LayoutToggle(table: table, onChanged: (v) => setState(() => table = v)),
              );
              if (wide && table) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  toggle,
                  const SizedBox(height: 10),
                  _ClientsTable(plans: list),
                ]);
              }
              final columns = wide ? 2 : 1;
              const gap = 10.0;
              final w = (box.maxWidth - gap * (columns - 1)) / columns;
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (wide) ...[toggle, const SizedBox(height: 10)],
                Wrap(spacing: gap, runSpacing: gap, children: [
                  for (final p in list) SizedBox(width: w, child: _ClientTile(plan: p)),
                ]),
              ]);
            }),
        ]);
      },
    );
  }
}

class _ClientsTable extends StatelessWidget {
  const _ClientsTable({required this.plans});
  final List<StudentPlan> plans;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final t = store.terms;
    final today = store.today;
    final current = DateTime(today.year, today.month);
    return WideTable(
      columns: [
        TableCol(t.clientTitle, flex: 4),
        const TableCol('Dias e horários', flex: 4),
        const TableCol('Cobrança', flex: 4),
        const TableCol('Vence', flex: 1),
        const TableCol('WhatsApp', flex: 3),
        const TableCol('Este mês', flex: 2),
      ],
      onTapRow: (i) => openClientProfile(context, plans[i].id),
      rows: [
        for (final p in plans)
          <Widget>[
            Row(children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: CF.greyBg,
                child: Text(initialsOf(p.name), style: CF.body(13, weight: FontWeight.w700, color: CF.ink)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: CF.body(16, weight: FontWeight.w700)),
                  if (p.service.isNotEmpty)
                    Text(p.service, maxLines: 1, overflow: TextOverflow.ellipsis, style: CF.body(13, color: CF.muted)),
                ]),
              ),
            ]),
            Text(p.hasRoutine ? routineText(p) : '${t.sessionsTitle} avuls${t.g('as', 'os')}',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: CF.body(14)),
            Text('${p.model.title} · ${planPriceText(p, t)}',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: CF.body(14)),
            Text('Dia ${p.dueDay}', style: CF.body(14)),
            Text(p.phone.isEmpty ? '—' : _formatPhone(p.phone), style: CF.body(14, color: CF.muted)),
            p.active ? StatusPill(store.status(p, month: current)) : Text('Arquivado', style: CF.body(14, color: CF.muted)),
          ],
      ],
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.plan});
  final StudentPlan plan;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final t = store.terms;
    final today = store.today;
    final status = plan.active ? store.status(plan, month: DateTime(today.year, today.month)) : null;
    return Material(
      color: CF.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openClientProfile(context, plan.id),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: CF.line)),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: CF.greyBg,
              child: Text(initialsOf(plan.name), style: CF.body(15, weight: FontWeight.w700, color: CF.ink)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(plan.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: CF.body(17, weight: FontWeight.w700)),
                Text(
                  '${plan.service.isEmpty ? '' : '${plan.service} · '}${plan.hasRoutine ? routineText(plan) : '${t.sessionsTitle} avuls${t.g('as', 'os')}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CF.body(14, color: CF.muted),
                ),
                Text(planPriceText(plan, t), style: CF.body(14, color: CF.text, weight: FontWeight.w600)),
              ]),
            ),
            if (status != null) ...[const SizedBox(width: 8), StatusPill(status)],
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ficha do cliente
// ---------------------------------------------------------------------------

Future<void> openClientProfile(BuildContext context, String id) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .9,
        minChildSize: .5,
        maxChildSize: .97,
        builder: (context, scroll) => _ClientProfile(id: id, scroll: scroll),
      ),
    );

class _ClientProfile extends StatelessWidget {
  const _ClientProfile({required this.id, required this.scroll});
  final String id;
  final ScrollController scroll;

  Future<void> _whatsapp(BuildContext context, StudentPlan p) async {
    var phone = p.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length == 10 || phone.length == 11) phone = '55$phone';
    if (phone.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastre um telefone com DDD.')));
      return;
    }
    await launchUrl(Uri.parse('https://wa.me/$phone'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final index = store.plans.indexWhere((p) => p.id == id);
        if (index < 0) return const SizedBox.shrink();
        final p = store.plans[index];
        final t = store.terms;
        final today = store.today;
        final months = [for (var k = 0; k < 4; k++) DateTime(today.year, today.month - k)];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
              Row(children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: CF.ink,
                  child: Text(initialsOf(p.name), style: CF.score(24, color: CF.lap)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, style: CF.body(24, weight: FontWeight.w700)),
                    Text(p.active ? (p.service.isEmpty ? t.clientTitle : p.service) : 'Arquivado',
                        style: CF.body(15, color: CF.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: CF.whatsapp),
                    onPressed: () => _whatsapp(context, p),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text('WhatsApp'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openClientForm(context, plan: p),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Editar'),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Panel(
                title: 'Cadastro',
                child: Column(children: [
                  _InfoRow(icon: Icons.payments_rounded, label: 'Cobrança', value: '${p.model.title} · ${planPriceText(p, t)}'),
                  _InfoRow(
                    icon: Icons.event_repeat_rounded,
                    label: 'Dias fixos',
                    value: p.hasRoutine ? routineText(p) : 'Sem dias fixos (${t.sessions} avuls${t.g('as', 'os')})',
                  ),
                  _InfoRow(icon: Icons.event_rounded, label: 'Vencimento', value: 'Todo dia ${p.dueDay}'),
                  _InfoRow(icon: Icons.phone_rounded, label: 'Telefone', value: p.phone.isEmpty ? 'Não informado' : _formatPhone(p.phone)),
                ]),
              ),
              const SizedBox(height: 14),
              if (p.active)
                Panel(
                  title: 'Últimos meses',
                  child: Column(children: [
                    for (final m in months)
                      InkWell(
                        onTap: () {
                          store.goToMonth(m);
                          openBillDetail(context, p);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            Expanded(
                              child: Text('${capitalize(monthNames[m.month - 1])} ${m.year}',
                                  style: CF.body(16, weight: FontWeight.w600)),
                            ),
                            Text(money(store.bill(p, month: m).total), style: CF.score(20)),
                            const SizedBox(width: 10),
                            StatusPill(store.status(p, month: m)),
                          ]),
                        ),
                      ),
                  ]),
                ),
              const SizedBox(height: 18),
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: p.active ? CF.red : CF.blue),
                  onPressed: () => _toggleArchive(context, p),
                  icon: Icon(p.active ? Icons.archive_rounded : Icons.unarchive_rounded, size: 18),
                  label: Text(p.active ? 'Arquivar ${t.client}' : 'Reativar ${t.client}'),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _toggleArchive(BuildContext context, StudentPlan p) async {
    final store = BillingStore.instance;
    final t = store.terms;
    if (!p.active) {
      store.setActive(p.id, true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Arquivar ${p.name}?'),
        content: Text('${p.name.split(' ').first} sai da agenda e das cobranças. O histórico fica guardado '
            'e você pode reativar quando quiser.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Manter')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CF.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Arquivar ${t.client}'),
          ),
        ],
      ),
    );
    if (ok == true) store.setActive(p.id, false);
  }
}

String _formatPhone(String digits) {
  final d = digits.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length == 11) return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
  if (d.length == 10) return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
  return digits;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: CF.muted),
          const SizedBox(width: 12),
          SizedBox(width: 100, child: Text(label, style: CF.body(15, color: CF.muted))),
          Expanded(child: Text(value, style: CF.body(15, weight: FontWeight.w600))),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Cadastro / edição
// ---------------------------------------------------------------------------

Future<void> openClientForm(BuildContext context, {StudentPlan? plan}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: _ClientForm(plan: plan, messengerContext: context),
      ),
    );

class _ClientForm extends StatefulWidget {
  const _ClientForm({this.plan, required this.messengerContext});
  final StudentPlan? plan;
  final BuildContext messengerContext;

  @override
  State<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<_ClientForm> {
  final store = BillingStore.instance;
  late final name = TextEditingController(text: widget.plan?.name ?? '');
  late final phone = TextEditingController(text: widget.plan?.phone ?? '');
  late final service = TextEditingController(text: widget.plan?.service ?? '');
  late final rate = TextEditingController(
      text: widget.plan == null ? '' : widget.plan!.rate.toStringAsFixed(2).replaceAll('.', ','));
  late final packageSize = TextEditingController(text: '${widget.plan?.packageSize ?? 10}');
  late BillingModel model = widget.plan?.model ?? ProfessionalProfile.instance.model;
  late Set<int> days = <int>{...?widget.plan?.weekdays};
  /// Horário de cada dia fixo (1 = segunda ... 7 = domingo).
  late Map<int, String> times = {...?widget.plan?.times};
  String _lastTime = '08:00';

  String _timeFor(int day) => times[day] ?? _lastTime;
  late int duration = widget.plan?.durationMinutes ?? ProfessionalProfile.instance.profession.duration;
  late int dueDay = widget.plan?.dueDay ?? 10;
  String? error;

  @override
  void dispose() {
    for (final c in [name, phone, service, rate, packageSize]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parseMoney(String s) =>
      double.tryParse(s.replaceAll('R\$', '').replaceAll(' ', '').replaceAll('.', '').replaceAll(',', '.'));

  Future<void> _pickTime(int day) async {
    final parts = _timeFor(day).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0),
      helpText: 'Horário de ${weekdayLong[day - 1].toLowerCase()}',
    );
    if (picked != null) {
      final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        times[day] = value;
        _lastTime = value;
      });
    }
  }

  void _toggleDay(int d) => setState(() {
        if (days.remove(d)) {
          times.remove(d);
        } else {
          days.add(d);
          times[d] = _lastTime;
        }
      });

  /// Copia o horário de um dia para todos os outros dias fixos.
  void _sameForAll(int from) => setState(() {
        final v = _timeFor(from);
        for (final d in days) {
          times[d] = v;
        }
      });

  void _save() {
    final t = store.terms;
    final value = _parseMoney(rate.text);
    if (name.text.trim().length < 2) {
      setState(() => error = 'Digite o nome do ${t.client}.');
      return;
    }
    if (value == null || value <= 0) {
      setState(() => error = 'Digite ${model.rateLabel(t).toLowerCase()}.');
      return;
    }
    final size = int.tryParse(packageSize.text) ?? 10;
    if (model == BillingModel.package && size < 1) {
      setState(() => error = 'O pacote precisa ter pelo menos 1 ${t.session}.');
      return;
    }
    final today = store.today;
    final p = StudentPlan(
      id: widget.plan?.id ?? store.newClientId(),
      name: name.text.trim(),
      phone: phone.text.replaceAll(RegExp(r'[^0-9]'), ''),
      service: service.text.trim(),
      rate: value,
      model: model,
      weekdays: days,
      times: {for (final d in days) d: _timeFor(d)},
      durationMinutes: duration,
      packageSize: size,
      packageStart: widget.plan?.packageStart ?? DateTime(today.year, today.month),
      dueDay: dueDay,
      active: widget.plan?.active ?? true,
    );
    store.savePlan(p);
    Navigator.pop(context);
    ScaffoldMessenger.of(widget.messengerContext).showSnackBar(SnackBar(
      content: Text(widget.plan == null ? 'Cadastro de ${p.name} criado. Já aparece na agenda e nas cobranças.' : 'Cadastro de ${p.name} atualizado.'),
    ));
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
    final t = store.terms;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.plan == null ? 'Novo ${t.client}' : 'Editar cadastro',
                style: CF.body(24, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: name,
              autofocus: widget.plan == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome completo'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9() -]'))],
              decoration: const InputDecoration(labelText: 'WhatsApp com DDD', hintText: '(11) 99999-0000'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: service,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Serviço (opcional)',
                hintText: ProfessionalProfile.instance.profession.services.first,
              ),
            ),
            const SizedBox(height: 18),
            Text('Como você cobra', style: CF.body(16, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in BillingModel.values) _chip(m.title, model == m, () => setState(() => model = m)),
            ]),
            const SizedBox(height: 6),
            Text(model.describe(t), style: CF.body(14, color: CF.muted)),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextField(
                  controller: rate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: InputDecoration(labelText: model.rateLabel(t), prefixText: 'R\$ '),
                ),
              ),
              if (model == BillingModel.package) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: packageSize,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: '${t.sessionsTitle} no pacote'),
                  ),
                ),
              ],
            ]),
            if (model == BillingModel.hourly) ...[
              const SizedBox(height: 12),
              Text('Duração de cada ${t.session}', style: CF.body(15, weight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in const [30, 45, 50, 60, 90, 120])
                  _chip(durationText(m), duration == m, () => setState(() => duration = m)),
              ]),
            ],
            const SizedBox(height: 18),
            Text('Dias fixos', style: CF.body(16, weight: FontWeight.w700)),
            Text(
              days.isEmpty
                  ? 'Sem dias fixos: você marca cada ${t.session} na agenda.'
                  : 'Toque nos dias em que ${t.g('as', 'os')} ${t.sessions} se repetem toda semana.',
              style: CF.body(14, color: CF.muted),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var d = 1; d <= 7; d++)
                _chip(weekdayShort[d - 1], days.contains(d), () => _toggleDay(d)),
            ]),
            if (days.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Horário de cada dia', style: CF.body(15, weight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: CF.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CF.line),
                ),
                child: Column(children: [
                  for (final d in (days.toList()..sort())) ...[
                    ListTile(
                      leading: const Icon(Icons.schedule_rounded, color: CF.muted),
                      title: Text(weekdayLong[d - 1], style: CF.body(16, weight: FontWeight.w600)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_timeFor(d), style: CF.score(24)),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_rounded, size: 18, color: CF.blue),
                      ]),
                      onTap: () => _pickTime(d),
                    ),
                  ],
                ]),
              ),
              if (days.length > 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _sameForAll((days.toList()..sort()).first),
                    child: Text('Usar o horário de ${weekdayLong[(days.toList()..sort()).first - 1].toLowerCase()} em todos'),
                  ),
                ),
            ],
            const SizedBox(height: 18),
            Text('Vencimento', style: CF.body(16, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(children: [
              IconButton.outlined(
                onPressed: dueDay > 1 ? () => setState(() => dueDay--) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Text('Todo dia $dueDay', textAlign: TextAlign.center, style: CF.score(26)),
              ),
              IconButton.outlined(
                onPressed: dueDay < 31 ? () => setState(() => dueDay++) : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ]),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: CF.body(15, color: CF.red, weight: FontWeight.w600)),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: Text(widget.plan == null ? 'Cadastrar ${t.client}' : 'Salvar alterações')),
          ]),
        ),
      ),
    );
  }
}
