import 'package:flutter/material.dart';

import 'cf_theme.dart';
import 'widgets.dart';

/// Tela de entrada: explica em segundos o que o Okday resolve e
/// convida a pessoa a experimentar a demonstração.
class SalesEntry extends StatelessWidget {
  const SalesEntry({super.key, required this.onStart, this.onLogin, this.onSignup});
  final VoidCallback onStart;

  /// "Já tenho conta": abre a tela de entrar. Sem ele, o botão não aparece.
  final VoidCallback? onLogin;

  /// "Criar conta grátis": abre o cadastro com teste de 14 dias.
  final VoidCallback? onSignup;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CF.ink,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 920;
          final pitch = _Pitch(onStart: onStart, onLogin: onLogin, onSignup: onSignup, wide: wide);
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
  const _Pitch({required this.onStart, required this.wide, this.onLogin, this.onSignup});
  final VoidCallback onStart;
  final VoidCallback? onLogin;

  /// "Criar conta grátis": abre o cadastro com teste de 14 dias.
  final VoidCallback? onSignup;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const BrandMark(size: 36),
        const SizedBox(width: 10),
        Flexible(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Ok', style: CF.body(22, color: CF.lap, weight: FontWeight.w800)),
              TextSpan(text: 'day', style: CF.body(22, color: Colors.white, weight: FontWeight.w800)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onLogin != null) ...[
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onLogin,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: CF.ink,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Entrar'),
          ),
        ],
      ]),
      SizedBox(height: wide ? 40 : 28),
      Text(
        'A cobrança do mês, pronta antes do último atendimento.',
        style: CF.score(wide ? 64 : 44, color: Colors.white).copyWith(height: 1.02),
      ),
      const SizedBox(height: 16),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Text(
          'Para quem atende com hora marcada. Faltas, feriados, férias e remarcações '
          'entram na conta sozinhos, e você só confere e envia o resumo pelo WhatsApp.',
          style: CF.body(18, color: Colors.white70, height: 1.45),
        ),
      ),
      const SizedBox(height: 26),
      const _Benefit(
        icon: Icons.calculate_rounded,
        text: 'Conta explicada atendimento por atendimento, para ninguém questionar o valor.',
      ),
      const _Benefit(
        icon: Icons.tune_rounded,
        text: 'Por sessão, por hora, mensalidade ou pacote: do jeito que você já cobra.',
      ),
      const _Benefit(
        icon: Icons.chat_rounded,
        text: 'Lembrete de pagamento no WhatsApp com um toque. Você revisa antes de enviar.',
      ),
      const SizedBox(height: 28),
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (onSignup != null)
          FilledButton.icon(
            onPressed: onSignup,
            style: FilledButton.styleFrom(
              backgroundColor: CF.lap,
              foregroundColor: CF.ink,
              minimumSize: const Size(0, 56),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              textStyle: CF.body(18, weight: FontWeight.w700),
            ),
            icon: const Icon(Icons.rocket_launch_rounded),
            label: const Text('Criar conta grátis'),
          ),
        if (onSignup != null)
          OutlinedButton.icon(
            onPressed: onStart,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.transparent,
              side: const BorderSide(color: Colors.white38, width: 1.5),
              minimumSize: const Size(0, 56),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              textStyle: CF.body(18, weight: FontWeight.w700),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Ver como funciona'),
          )
        else
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
          label: const Text('Experimentar agora'),
        ),
        if (onLogin != null && onSignup == null)
          OutlinedButton.icon(
            onPressed: onLogin,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.transparent,
              side: const BorderSide(color: Colors.white38, width: 1.5),
              minimumSize: const Size(0, 56),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              textStyle: CF.body(18, weight: FontWeight.w700),
            ),
            icon: const Icon(Icons.login_rounded),
            label: const Text('Já tenho conta: entrar'),
          ),
      ]),
      const SizedBox(height: 12),
      Text(
          onSignup != null
              ? '14 dias grátis, sem cartão. Depois, a partir de R\$ 29,90 por mês. '
                  'Para psicólogos, fisioterapeutas, médicos, nutricionistas, personal trainers e outros profissionais.'
              : 'Para psicólogos, fisioterapeutas, médicos, nutricionistas, personal trainers e outros '
                  'profissionais. Sem cadastro: você escolhe a profissão e entra numa conta de exemplo.',
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
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: CF.mint.withValues(alpha: .15), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: CF.mint, size: 19),
          ),
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
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('R\$ 2.340', style: CF.score(40, color: Colors.white)),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Falta receber', style: CF.body(14, color: Colors.white70)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text('R\$ 1.180', style: CF.score(40, color: CF.lap)),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        const LaneTrack(progress: .66),
        const SizedBox(height: 18),
        const _MiniRow(initials: 'MC', name: 'Mariana', detail: 'Psicoterapia · 4 sessões × R\$ 200', value: 'R\$ 800', paid: true),
        const _MiniRow(initials: 'FL', name: 'Fernanda', detail: 'Fisioterapia · pacote de 10 sessões', value: 'R\$ 1.260', paid: false),
        const _MiniRow(initials: 'PM', name: 'Paulo', detail: 'Pilates · mensalidade', value: 'R\$ 390', paid: false),
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
