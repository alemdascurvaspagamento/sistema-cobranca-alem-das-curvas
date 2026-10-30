import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../billing/billing_engine.dart' show money, moneyCompact;

/// Movimentos do Okday: curtos, rodam uma vez e respeitam o
/// "Reduzir movimento" do celular (aí tudo aparece parado).
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

Duration motion(BuildContext context, int ms) => reduceMotion(context) ? Duration.zero : Duration(milliseconds: ms);

/// Começa o movimento só quando o item aparece na tela (ao rolar até ele).
class WhenVisible extends StatefulWidget {
  const WhenVisible({super.key, required this.builder});
  final Widget Function(BuildContext context, bool visible) builder;

  @override
  State<WhenVisible> createState() => _WhenVisibleState();
}

class _WhenVisibleState extends State<WhenVisible> {
  bool visible = false;
  ScrollPosition? position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (visible) return;
    if (reduceMotion(context)) {
      visible = true;
      return;
    }
    position?.removeListener(_check);
    position = Scrollable.maybeOf(context)?.position;
    position?.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (visible || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final screen = MediaQuery.sizeOf(context).height;
    if (top < screen - 24 && top + box.size.height > 0) {
      position?.removeListener(_check);
      setState(() => visible = true);
    }
  }

  @override
  void dispose() {
    position?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, visible);
}

/// Número que "conta" até o valor certo (R$ 0 → R$ 13.952,50).
/// Aceita o texto já formatado: valores em reais, números inteiros e
/// "6 aulas" animam; qualquer outro texto aparece normal.
/// Começa quando o número aparece na tela.
class CountUpText extends StatelessWidget {
  const CountUpText(this.text, {super.key, this.style, this.textAlign});
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  static final _moneyRe = RegExp(r'^(−?)R\$ ([\d.]+)(,(\d{2}))?$');
  static final _intRe = RegExp(r'^(\d{1,6})(\s.*)?$');

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
    } else if (_intRe.firstMatch(text) case final i?) {
      target = double.parse(i.group(1)!);
      final suffix = i.group(2) ?? '';
      format = (v) => '${v.round()}$suffix';
    }
    if (target == null || format == null || target == 0) {
      return Text(text, style: style, textAlign: textAlign);
    }
    final f = format;
    final end = target;
    return WhenVisible(
      builder: (context, visible) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: visible ? end : 0),
        duration: motion(context, 1000),
        curve: Curves.easeOutCubic,
        // No fim mostra exatamente o texto original.
        builder: (context, v, _) => Text(v == end ? text : f(v), style: style, textAlign: textAlign),
      ),
    );
  }
}

/// Barra que enche até o valor (meta, recebido), quando aparece na tela.
class GrowingBar extends StatelessWidget {
  const GrowingBar({super.key, required this.value, this.minHeight = 8, this.color, this.backgroundColor});
  final double value;
  final double minHeight;
  final Color? color, backgroundColor;

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    return WhenVisible(
      builder: (context, visible) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: visible ? v : 0),
        duration: motion(context, 1200),
        curve: Curves.easeOutCubic,
        builder: (context, x, _) => ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: x, minHeight: minHeight, color: color, backgroundColor: backgroundColor),
        ),
      ),
    );
  }
}

/// Ícone que "toca" de tempos em tempos enquanto houver algo pendente
/// (três toques, pausa, e para depois de algumas vezes para não cansar).
class RingingLoop extends StatefulWidget {
  const RingingLoop({super.key, required this.child, this.active = true, this.times = 4});
  final Widget child;
  final bool active;
  final int times;

  @override
  State<RingingLoop> createState() => _RingingLoopState();
}

class _RingingLoopState extends State<RingingLoop> with SingleTickerProviderStateMixin {
  // Cada ciclo: 1,4 s tocando + 3,6 s parado.
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 5000));
  int done = 0;

  @override
  void initState() {
    super.initState();
    c.addStatusListener((s) {
      if (s == AnimationStatus.completed && ++done < widget.times && mounted) c.forward(from: 0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.active && !reduceMotion(context) && !c.isAnimating && done == 0) c.forward(from: 0);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: c,
      builder: (context, child) {
        final t = (c.value * 5000 / 1400).clamp(0.0, 1.0);
        final angle = t >= 1 ? 0.0 : math.sin(t * math.pi * 12) * .24 * (1 - t);
        return Transform.rotate(angle: angle, child: child);
      },
      child: widget.child,
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
