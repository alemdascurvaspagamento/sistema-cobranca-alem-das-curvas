import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../billing/billing_engine.dart' show money, moneyCompact;

/// Movimentos do Okday: curtos, rodam uma vez e respeitam o
/// "Reduzir movimento" do celular (aí tudo aparece parado).
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

Duration motion(BuildContext context, int ms) => reduceMotion(context) ? Duration.zero : Duration(milliseconds: ms);

/// Número que "conta" até o valor certo (R$ 0 → R$ 13.952,50).
/// Aceita o texto já formatado: valores em reais e números inteiros animam;
/// qualquer outro texto aparece normal.
class CountUpText extends StatelessWidget {
  const CountUpText(this.text, {super.key, this.style, this.textAlign});
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  static final _moneyRe = RegExp(r'^(−?)R\$ ([\d.]+)(,(\d{2}))?$');
  static final _intRe = RegExp(r'^\d{1,6}$');

  @override
  Widget build(BuildContext context) {
    final m = _moneyRe.firstMatch(text);
    double? target;
    String Function(double)? format;
    if (m != null) {
      final reais = int.parse(m.group(2)!.replaceAll('.', ''));
      final cents = m.group(4) == null ? 0 : int.parse(m.group(4)!);
      final value = (reais + cents / 100) * (m.group(1)!.isEmpty ? 1 : -1);
      final compact = m.group(3) == null;
      target = value;
      format = compact ? (v) => moneyCompact(v.round()) : (v) => money(v);
    } else if (_intRe.hasMatch(text)) {
      target = double.parse(text);
      format = (v) => v.round().toString();
    }
    if (target == null || format == null || target == 0) {
      return Text(text, style: style, textAlign: textAlign);
    }
    final f = format;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: motion(context, 900),
      curve: Curves.easeOutCubic,
      // No fim mostra exatamente o texto original.
      builder: (context, v, _) => Text(v == target ? text : f(v), style: style, textAlign: textAlign),
    );
  }
}

/// Barra que enche até o valor (meta, recebido).
class GrowingBar extends StatelessWidget {
  const GrowingBar({super.key, required this.value, this.minHeight = 8, this.color, this.backgroundColor});
  final double value;
  final double minHeight;
  final Color? color, backgroundColor;

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: v),
      duration: motion(context, 1100),
      curve: Curves.easeOutCubic,
      builder: (context, x, _) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(value: x, minHeight: minHeight, color: color, backgroundColor: backgroundColor),
      ),
    );
  }
}

/// Cartão que surge de leve ao abrir a tela.
class FadeInUp extends StatelessWidget {
  const FadeInUp({super.key, required this.child, this.delayMs = 0});
  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    final total = 380 + delayMs;
    final start = delayMs / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, t, child) {
        final p = Curves.easeOutCubic.transform(((t - start) / (1 - start)).clamp(0.0, 1.0));
        return Opacity(opacity: p, child: Transform.translate(offset: Offset(0, 14 * (1 - p)), child: child));
      },
      child: child,
    );
  }
}

/// Ícone que "toca" como um telefone (balança algumas vezes e para).
/// Usado só quando há algo pendente.
class Ringing extends StatelessWidget {
  const Ringing({super.key, required this.child, this.active = true});
  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active || reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      builder: (context, t, child) {
        // Três "toques" que vão diminuindo.
        final angle = math.sin(t * math.pi * 12) * .22 * (1 - t);
        return Transform.rotate(angle: angle, child: child);
      },
      child: child,
    );
  }
}

/// Check que "salta" ao confirmar algo (pagamento, atendimento realizado).
class PopCheck extends StatelessWidget {
  const PopCheck({super.key, this.color = const Color(0xFF5CD08A), this.size = 22});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: motion(context, 500),
        curve: Curves.elasticOut,
        builder: (context, s, child) => Transform.scale(scale: s, child: child),
        child: Icon(Icons.check_circle_rounded, color: color, size: size),
      );
}
