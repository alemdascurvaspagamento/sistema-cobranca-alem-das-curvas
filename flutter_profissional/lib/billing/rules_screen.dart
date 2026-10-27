import 'package:flutter/material.dart';

import '../profile/profession_profile.dart';
import '../ui/cf_theme.dart';
import '../ui/widgets.dart';
import 'billing_engine.dart';
import 'billing_store.dart';
import '../data/ids.dart';

/// Regras de cobrança e calendário de feriados do profissional.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key, this.onChangeProfession});

  /// Abre a escolha de profissão e forma de cobrança.
  final VoidCallback? onChangeProfession;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final profile = ProfessionalProfile.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final r = store.rules;
        final t = store.terms;
        final now = monthNames[store.today.month - 1];
        final nextMonth = monthNames[DateTime(store.today.year, store.today.month + 1).month - 1];
        final s = t.session, ss = t.sessions;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _ProfileCard(profile: profile, onChange: onChangeProfession),
              const SizedBox(height: 22),
              PageTitle(
                'Regras de cobrança',
                icon: Icons.rule_rounded,
                color: CF.amber,
                subtitle: 'Escolha uma vez e o Coach Flow aplica em todas as contas. '
                    'Você ainda pode ajustar cada $s, ${t.g('uma', 'um')} a ${t.g('uma', 'um')}.',
              ),
              const SizedBox(height: 18),
              _RuleCard(
                icon: Icons.person_off_rounded,
                title: 'Quando ${t.clients} faltam ou cancelam',
                options: [
                  _Option(
                    title: 'Cobrar e descontar no mês seguinte',
                    detail: 'A falta entra na conta e vira 1 $s de desconto no mês seguinte. '
                        'Ex.: faltou em $now, desconta em $nextMonth.',
                    selected: r.cancel == CancelRule.compensate,
                    onTap: () => store.setRules(r.copyWith(cancel: CancelRule.compensate)),
                  ),
                  _Option(
                    title: 'Cobrar normalmente',
                    detail: 'A falta é cobrada como ${t.g('uma', 'um')} $s comum, sem desconto depois.',
                    selected: r.cancel == CancelRule.charge,
                    onTap: () => store.setRules(r.copyWith(cancel: CancelRule.charge)),
                  ),
                  _Option(
                    title: 'Não cobrar',
                    detail: '${t.sessionTitle} ${t.g('cancelada', 'cancelado')} sai da conta do mês.',
                    selected: r.cancel == CancelRule.waive,
                    onTap: () => store.setRules(r.copyWith(cancel: CancelRule.waive)),
                  ),
                ],
                footnote: profile.model == BillingModel.monthly
                    ? 'Na mensalidade fixa, faltas não mudam o valor do mês.'
                    : null,
              ),
              const SizedBox(height: 12),
              _RuleCard(
                icon: Icons.celebration_rounded,
                title: 'Em feriados',
                options: [
                  _Option(
                    title: 'Não atendo, não cobrar',
                    detail: 'Feriados marcados como "sem atendimento" na lista abaixo saem da conta.',
                    selected: r.holiday == HolidayRule.noCharge,
                    onTap: () => store.setRules(r.copyWith(holiday: HolidayRule.noCharge)),
                  ),
                  _Option(
                    title: 'Cobrar normalmente',
                    detail: 'O feriado conta como um dia comum de $ss.',
                    selected: r.holiday == HolidayRule.charge,
                    onTap: () => store.setRules(r.copyWith(holiday: HolidayRule.charge)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _RuleCard(
                icon: Icons.swap_horiz_rounded,
                title: '${t.sessionTitle} ${t.g('remarcada', 'remarcado')} para outro mês',
                options: [
                  _Option(
                    title: 'Cobrar no mês da nova data',
                    detail: '${t.sessionTitle} sai da conta do mês original e entra na conta do mês em que acontecer.',
                    selected: r.move == MoveRule.chargeNewMonth,
                    onTap: () => store.setRules(r.copyWith(move: MoveRule.chargeNewMonth)),
                  ),
                  _Option(
                    title: 'Cobrar no mês original',
                    detail: '${t.sessionTitle} continua na conta do mês original e a reposição não é cobrada de novo.',
                    selected: r.move == MoveRule.chargeOriginalMonth,
                    onTap: () => store.setRules(r.copyWith(move: MoveRule.chargeOriginalMonth)),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const _HolidayList(),
            ]),
          ),
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, this.onChange});
  final ProfessionalProfile profile;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final p = profile.profession;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: CF.ink, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: CF.inkSoft, borderRadius: BorderRadius.circular(14)),
          child: Icon(p.icon, color: CF.lap),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: CF.body(18, color: Colors.white, weight: FontWeight.w700)),
            Text('Cobrança: ${profile.model.title.toLowerCase()}',
                style: CF.body(14, color: Colors.white70)),
          ]),
        ),
        if (onChange != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: CF.lap),
            onPressed: onChange,
            child: const Text('Mudar'),
          ),
      ]),
    );
  }
}

class _Option {
  const _Option({required this.title, required this.detail, required this.selected, required this.onTap});
  final String title, detail;
  final bool selected;
  final VoidCallback onTap;
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.icon, required this.title, required this.options, this.footnote});
  final IconData icon;
  final String title;
  final List<_Option> options;
  final String? footnote;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CF.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CF.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            IconBadge(icon, color: CF.amber, size: 38),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: CF.body(19, weight: FontWeight.w700))),
          ]),
          const SizedBox(height: 12),
          for (final o in options) ...[
            _OptionTile(option: o),
            if (o != options.last) const SizedBox(height: 8),
          ],
          if (footnote != null) ...[
            const SizedBox(height: 10),
            Text(footnote!, style: CF.body(14, color: CF.muted)),
          ],
        ]),
      );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option});
  final _Option option;

  @override
  Widget build(BuildContext context) {
    final on = option.selected;
    return Semantics(
      selected: on,
      button: true,
      child: Material(
        color: on ? const Color(0xFFE9EFFA) : CF.bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: option.onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? CF.ink : Colors.transparent, width: 2),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: on ? CF.ink : CF.muted, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(option.title, style: CF.body(16, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(option.detail, style: CF.body(14, color: CF.muted, height: 1.35)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _HolidayList extends StatelessWidget {
  const _HolidayList();

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final year = store.selectedMonth.year;
    final list = store.holidays.where((h) => h.date.year == year).toList();
    final today = store.today;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const IconBadge(Icons.celebration_rounded, color: CF.red, size: 46),
        const SizedBox(width: 12),
        Expanded(child: Text('Feriados de $year', style: CF.body(24, weight: FontWeight.w700))),
        FilledButton.icon(
          onPressed: () => _editHoliday(context, null),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Adicionar'),
        ),
      ]),
      const SizedBox(height: 4),
      Text('Já vêm os feriados nacionais. Inclua os da sua cidade e escolha em quais você não atende.',
          style: CF.body(15, color: CF.muted)),
      const SizedBox(height: 12),
      KpiRow([
        KpiCard(icon: Icons.celebration_rounded, label: 'Feriados no ano', value: '${list.length}', color: CF.red, accent: true),
        KpiCard(icon: Icons.event_busy_rounded, label: 'Sem atendimento', value: '${list.where((h) => h.noClass).length}', color: CF.amber, accent: true),
        KpiCard(icon: Icons.event_available_rounded, label: 'Com atendimento', value: '${list.where((h) => !h.noClass).length}', color: CF.green, accent: true),
      ]),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: CF.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CF.line),
        ),
        child: Column(children: [
          for (final h in list) ...[
            _HolidayRow(holiday: h, past: h.date.isBefore(today)),
            if (h != list.last) const Divider(height: 1, indent: 16, endIndent: 16),
          ],
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Nenhum feriado cadastrado para $year.', style: CF.body(15, color: CF.muted)),
            ),
        ]),
      ),
    ]);
  }
}

class _HolidayRow extends StatelessWidget {
  const _HolidayRow({required this.holiday, required this.past});
  final Holiday holiday;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final d = holiday.date;
    return InkWell(
      onTap: () => _editHoliday(context, holiday),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(children: [
          SizedBox(
            width: 54,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.day.toString().padLeft(2, '0'), style: CF.score(26, color: past ? CF.muted : CF.text)),
              Text(monthNames[d.month - 1].substring(0, 3), style: CF.body(13, color: CF.muted)),
            ]),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(holiday.name, style: CF.body(16, weight: FontWeight.w600, color: past ? CF.muted : CF.text)),
              Text(
                '${weekdayLong[d.weekday - 1]} · ${holiday.noClass ? 'sem atendimento' : 'dia normal'}',
                style: CF.body(14, color: CF.muted),
              ),
            ]),
          ),
          Switch(
            value: holiday.noClass,
            activeTrackColor: CF.ink,
            onChanged: (v) => store.saveHoliday(holiday.copyWith(noClass: v)),
          ),
        ]),
      ),
    );
  }
}

Future<void> _editHoliday(BuildContext context, Holiday? holiday) async {
  final store = BillingStore.instance;
  final name = TextEditingController(text: holiday?.name ?? '');
  var date = holiday?.date ?? store.today;
  var noClass = holiday?.noClass ?? true;
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, refresh) => AlertDialog(
        title: Text(holiday == null ? 'Novo feriado' : 'Editar feriado'),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: name,
              autofocus: holiday == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Aniversário da cidade'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: date,
                  firstDate: DateTime(date.year - 1),
                  lastDate: DateTime(date.year + 2, 12, 31),
                );
                if (picked != null) refresh(() => date = picked);
              },
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text('${weekdayLong[date.weekday - 1]}, ${ddmm(date)}/${date.year}'),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: noClass,
              activeTrackColor: CF.ink,
              onChanged: (v) => refresh(() => noClass = v),
              title: const Text('Não atendo neste dia'),
            ),
          ]),
        ),
        actions: [
          if (holiday != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: CF.red),
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: const Text('Excluir'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(ctx, 'save');
            },
            child: const Text('Salvar feriado'),
          ),
        ],
      ),
    ),
  );
  if (result == 'save') {
    store.saveHoliday(Holiday(
      id: holiday?.id ?? newUuid(),
      date: dateOnly(date),
      name: name.text.trim(),
      noClass: noClass,
    ));
  } else if (result == 'delete' && holiday != null && context.mounted) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir feriado?'),
        content: Text('${holiday.name} sai da lista e os atendimentos deste dia voltam a ser cobrados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Manter')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CF.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir feriado'),
          ),
        ],
      ),
    );
    if (ok == true) store.removeHoliday(holiday.id);
  }
  name.dispose();
}
