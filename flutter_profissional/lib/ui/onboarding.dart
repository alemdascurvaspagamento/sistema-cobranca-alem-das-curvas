import 'package:flutter/material.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_store.dart';
import '../profile/profession_profile.dart';
import 'cf_theme.dart';

/// Boas-vindas em dois passos: profissão e forma de cobrança.
///
/// Ao terminar, o app passa a usar o vocabulário da profissão e monta
/// clientes de exemplo com a forma de cobrança escolhida.
class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.onDone, this.onBack, this.onChosen});
  final VoidCallback onDone;
  final VoidCallback? onBack;

  /// Conta real: recebe a escolha em vez de montar dados de exemplo.
  final void Function(ProfessionProfile profession, BillingModel model)? onChosen;

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  int step = 0;
  late ProfessionProfile? profession =
      ProfessionalProfile.instance.chosen ? ProfessionalProfile.instance.profession : null;
  late BillingModel model = ProfessionalProfile.instance.model;
  final otherName = TextEditingController();

  @override
  void dispose() {
    otherName.dispose();
    super.dispose();
  }

  void _pick(ProfessionProfile p) => setState(() {
        profession = p;
        model = p.defaultModel;
      });

  void _finish() {
    var p = profession!;
    if (p.id == 'outra' && otherName.text.trim().isNotEmpty) p = p.withName(otherName.text.trim());
    if (widget.onChosen != null) {
      widget.onChosen!(p, model);
      return;
    }
    ProfessionalProfile.instance.choose(p, model);
    BillingStore.instance.seed(p, model);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CF.bg,
      body: SafeArea(
        child: Column(children: [
          _TopBar(
            step: step,
            onBack: step == 1 ? () => setState(() => step = 0) : widget.onBack,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: step == 0 ? _professionStep() : _modelStep(),
                ),
              ),
            ),
          ),
          _BottomBar(
            label: step == 0 ? 'Continuar' : 'Ver meu Okday',
            onPressed: profession == null
                ? null
                : () {
                    if (step == 0) {
                      setState(() => step = 1);
                    } else {
                      _finish();
                    }
                  },
          ),
        ]),
      ),
    );
  }

  Widget _professionStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Qual é a sua profissão?', style: CF.score(38)),
      const SizedBox(height: 6),
      Text('O Okday passa a falar a sua língua: alunos e aulas, pacientes e consultas, '
          'clientes e sessões.', style: CF.body(16, color: CF.muted, height: 1.4)),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, box) {
        final columns = box.maxWidth >= 600 ? 3 : 2;
        const gap = 10.0;
        final w = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final p in professionProfiles)
            SizedBox(
              width: w,
              child: _ProfessionTile(
                profile: p,
                selected: profession?.id == p.id,
                onTap: () => _pick(p),
              ),
            ),
        ]);
      }),
      if (profession?.id == 'outra') ...[
        const SizedBox(height: 14),
        TextField(
          controller: otherName,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Qual é a sua profissão? (opcional)'),
        ),
      ],
    ]);
  }

  Widget _modelStep() {
    final p = profession!;
    final t = p.terms;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Como você cobra seus ${t.clients}?', style: CF.score(38)),
      const SizedBox(height: 6),
      Text('Escolha a forma mais comum para você. Depois dá para usar outra forma com cada ${t.client}.',
          style: CF.body(16, color: CF.muted, height: 1.4)),
      const SizedBox(height: 18),
      for (final m in BillingModel.values) ...[
        _ModelTile(
          model: m,
          profile: p,
          selected: model == m,
          recommended: m == p.defaultModel,
          onTap: () => setState(() => model = m),
        ),
        const SizedBox(height: 10),
      ],
    ]);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.step, this.onBack});
  final int step;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
        child: Row(children: [
          if (onBack != null)
            IconButton(tooltip: 'Voltar', onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded))
          else
            const SizedBox(width: 48),
          const Spacer(),
          Text('Passo ${step + 1} de 2', style: CF.body(14, color: CF.muted, weight: FontWeight.w600)),
          const SizedBox(width: 10),
          for (var i = 0; i < 2; i++)
            Container(
              width: 28, height: 6,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: i <= step ? CF.ink : CF.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ]),
      );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: const BoxDecoration(
          color: CF.surface,
          border: Border(top: BorderSide(color: CF.line)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
                child: Text(label),
              ),
            ),
          ),
        ),
      );
}

class _ProfessionTile extends StatelessWidget {
  const _ProfessionTile({required this.profile, required this.selected, required this.onTap});
  final ProfessionProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? CF.ink : CF.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 92),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: selected ? CF.ink : CF.line),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(profile.icon, color: selected ? CF.lap : CF.ink, size: 24),
                const SizedBox(height: 8),
                Text(
                  profile.name,
                  style: CF.body(15, weight: FontWeight.w600, color: selected ? Colors.white : CF.text, height: 1.2),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.model,
    required this.profile,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });
  final BillingModel model;
  final ProfessionProfile profile;
  final bool selected, recommended;
  final VoidCallback onTap;

  String _example() {
    final t = profile.terms;
    final r = profile.sampleRate;
    double round10(double v) => (v / 10).round() * 10.0;
    return switch (model) {
      BillingModel.perSession => 'Ex.: 8 ${t.sessions} × ${moneyCompact(r)} = ${moneyCompact(r * 8)} no mês',
      BillingModel.hourly =>
        'Ex.: ${moneyCompact(round10(r * 60 / profile.duration))} a hora; ${t.g('uma', 'um')} ${t.session} de '
            '${durationText(profile.duration)} sai por ${moneyCompact(round10(r * 60 / profile.duration) * profile.duration / 60)}',
      BillingModel.monthly =>
        profile.fixedRoutine
            ? 'Ex.: ${moneyCompact(round10(r * profile.perWeek * 4.3))} por mês, ${profile.perWeek}x por semana'
            : 'Ex.: ${moneyCompact(round10(r * profile.perWeek * 4.3))} por mês, com ${t.sessions} à vontade',
      BillingModel.package => 'Ex.: pacote de 10 ${t.sessions} por ${moneyCompact(round10(r * 9))}',
    };
  }

  IconData get _icon => switch (model) {
        BillingModel.perSession => Icons.event_available_rounded,
        BillingModel.hourly => Icons.schedule_rounded,
        BillingModel.monthly => Icons.calendar_month_rounded,
        BillingModel.package => Icons.inventory_2_rounded,
      };

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? const Color(0xFFE9EFFA) : CF.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? CF.ink : CF.line, width: selected ? 2 : 1),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(_icon, color: CF.ink, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(model.title, style: CF.body(18, weight: FontWeight.w700)),
                      if (recommended)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: CF.lap, borderRadius: BorderRadius.circular(999)),
                          child: Text('Mais comum na sua área',
                              style: CF.body(12, weight: FontWeight.w700, color: CF.ink)),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Text(model.describe(profile.terms), style: CF.body(15, color: CF.text, height: 1.35)),
                    const SizedBox(height: 6),
                    Text(_example(), style: CF.body(14, color: CF.muted)),
                  ]),
                ),
                const SizedBox(width: 8),
                Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: selected ? CF.ink : CF.muted),
              ]),
            ),
          ),
        ),
      );
}
