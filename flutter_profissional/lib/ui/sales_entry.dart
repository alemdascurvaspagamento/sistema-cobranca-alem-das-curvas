import 'package:flutter/material.dart';

import 'cf_theme.dart';

/// Tela de entrada: explica em segundos o que o Coach Flow resolve e
/// convida a pessoa a experimentar a demonstração.
class SalesEntry extends StatelessWidget {
  const SalesEntry({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CF.ink,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 920;
          final pitch = _Pitch(onStart: onStart, wide: wide);
          const preview = _ScoreboardPreview();
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: wide ? 56 : 22, vertical: wide ? 48 : 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: wide
                    ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Expanded(flex: 6, child: pitch),
                        const SizedBox(width: 56),
                        const Expanded(flex: 5, child: preview),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        pitch,
                        const SizedBox(height: 28),
                        preview,
                      ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Pitch extends StatelessWidget {
  const _Pitch({required this.onStart, required this.wide});
  final VoidCallback onStart;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: CF.lap, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.directions_run_rounded, color: CF.ink, size: 22),
        ),
        const SizedBox(width: 10),
        Text('Coach Flow', style: CF.body(20, color: Colors.white, weight: FontWeight.w700)),
        const SizedBox(width: 8),
        Text('Profissional', style: CF.body(20, color: Colors.white60)),
      ]),
      SizedBox(height: wide ? 40 : 28),
      Text(
        'A cobrança do mês, pronta antes de você terminar o treino.',
        style: CF.score(wide ? 64 : 44, color: Colors.white).copyWith(height: 1.02),
      ),
      const SizedBox(height: 16),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Text(
          'Faltas, feriados, férias e remarcações entram na conta sozinhos. '
          'Você confere o valor de cada aluno e envia o resumo pelo WhatsApp.',
          style: CF.body(18, color: Colors.white70, height: 1.45),
        ),
      ),
      const SizedBox(height: 26),
      const _Benefit(
        icon: Icons.calculate_rounded,
        text: 'Conta explicada aula por aula, para o aluno não questionar.',
      ),
      const _Benefit(
        icon: Icons.event_busy_rounded,
        text: 'Falta cobrada vira desconto no mês seguinte, sem anotação à parte.',
      ),
      const _Benefit(
        icon: Icons.chat_rounded,
        text: 'Lembrete de pagamento no WhatsApp com um toque. Você revisa antes de enviar.',
      ),
      const SizedBox(height: 28),
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FilledButton.icon(
          onPressed: onStart,
          style: FilledButton.styleFrom(
            backgroundColor: CF.lap,
            foregroundColor: CF.ink,
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            textStyle: CF.body(18, weight: FontWeight.w700),
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Experimentar com dados de exemplo'),
        ),
      ]),
      const SizedBox(height: 12),
      Text('Sem cadastro. Os alunos são fictícios e nada é enviado de verdade.',
          style: CF.body(14, color: Colors.white54)),
    ]);
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: CF.mint, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: CF.body(16, color: Colors.white, height: 1.4))),
        ]),
      );
}

/// Amostra estática do placar, para mostrar o produto antes de entrar.
class _ScoreboardPreview extends StatelessWidget {
  const _ScoreboardPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CF.inkSoft,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: CF.inkLine),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Recebido', style: CF.body(14, color: Colors.white70)),
              Text('R\$ 2.340', style: CF.score(40, color: Colors.white)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Falta receber', style: CF.body(14, color: Colors.white70)),
            Text('R\$ 1.180', style: CF.score(40, color: CF.lap)),
          ]),
        ]),
        const SizedBox(height: 16),
        const LaneTrack(progress: .66),
        const SizedBox(height: 18),
        const _MiniRow(initials: 'MC', name: 'Mariana', detail: '8 aulas × R\$ 180', value: 'R\$ 1.440', paid: true),
        const _MiniRow(initials: 'FL', name: 'Fernanda', detail: '1 falta compensada', value: 'R\$ 1.080', paid: false),
        const _MiniRow(initials: 'PM', name: 'Paulo', detail: 'Férias de 2 aulas', value: 'R\$ 400', paid: false),
      ]),
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({
    required this.initials,
    required this.name,
    required this.detail,
    required this.value,
    required this.paid,
  });
  final String initials, name, detail, value;
  final bool paid;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: CF.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: paid ? CF.greenBg : CF.amberBg,
            child: Text(initials, style: CF.body(13, weight: FontWeight.w700, color: paid ? CF.green : CF.amber)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: CF.body(16, weight: FontWeight.w700)),
              Text(detail, style: CF.body(13, color: CF.muted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value, style: CF.score(22)),
            Text(paid ? 'Pago' : 'A receber',
                style: CF.body(12, weight: FontWeight.w700, color: paid ? CF.green : CF.amber)),
          ]),
        ]),
      );
}
