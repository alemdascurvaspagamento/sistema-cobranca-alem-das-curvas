import 'package:flutter/material.dart';

import '../ui/cf_theme.dart';
import '../ui/widgets.dart';
import 'admin_api.dart';

/// Peças visuais do painel do administrador.

String two(int n) => n.toString().padLeft(2, '0');

String dmy(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

String dm(DateTime d) => '${two(d.day)}/${two(d.month)}';

/// "hoje", "ontem", "há 4 dias", "nunca".
String sinceText(DateTime? d, DateTime now) {
  if (d == null) return 'nunca';
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (days <= 0) return 'hoje';
  if (days == 1) return 'ontem';
  return 'há $days dias';
}

/// Nome de cada evento de uso, em português simples.
const usageNames = {
  'app_aberto': 'Abriu o app',
  'cliente_novo': 'Cadastrou cliente',
  'cliente_importado': 'Importou clientes',
  'cobranca_whatsapp': 'Cobrou pelo WhatsApp',
  'agendamento_online_ligado': 'Ligou o agendamento online',
  'resumo_manha_ligado': 'Ligou o resumo da manhã',
  'relatorios_aberto': 'Abriu os relatórios',
  'graficos_aberto': 'Abriu os gráficos',
  'pedido_remarcacao': 'Recebeu pedido de remarcação',
};

/// Texto e cores da situação de uma conta.
(String, Color, Color) accountLook(AdminAccount a, DateTime now) {
  switch (a.state) {
    case 'trialing':
      final d = a.trialDaysLeft(now);
      return (d <= 1 ? 'Teste · último dia' : 'Teste · $d dias', CF.amber, CF.amberBg);
    case 'courtesy':
      return ('Cortesia', CF.violet, CF.violetBg);
    case 'grace':
      final d = a.graceDaysLeft(now);
      return ('Atraso · $d ${d == 1 ? 'dia' : 'dias'}', CF.red, CF.redBg);
    case 'active':
      if (a.status == 'canceled') {
        final end = a.currentPeriodEnd;
        return (end == null ? 'Cancelada' : 'Cancelada · até ${dm(end)}', CF.grey, CF.greyBg);
      }
      return ('Pagante', CF.green, CF.greenBg);
    default:
      return ('Somente leitura', CF.red, CF.redBg);
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.text, {super.key, required this.fg, required this.bg});
  final String text;
  final Color fg, bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: CF.body(12.5, color: fg, weight: FontWeight.w600)),
      );
}

/// Cartão de número grande, no estilo placar do app.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.noteColor = CF.muted,
    this.valueColor = CF.text,
  });
  final String label, value;
  final String? note;
  final Color noteColor, valueColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: CF.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CF.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: CF.body(13, color: CF.muted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: CF.score(34, color: valueColor)),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note!, style: CF.body(12.5, color: noteColor), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ]),
      );
}

/// Grade que ajusta o número de colunas à largura.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth >= 720 ? 3 : 2;
        const gap = 10.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final c in children) SizedBox(width: w, child: c),
        ]);
      });
}

/// Colunas simples (novas contas por semana, receita por mês).
class BarSeries extends StatelessWidget {
  const BarSeries({super.key, required this.labels, required this.values, this.valueText, this.color = CF.blue, this.highlightLast = true});
  final List<String> labels;
  final List<double> values;
  final String Function(double)? valueText;
  final Color color;
  final bool highlightLast;

  @override
  Widget build(BuildContext context) {
    final top = values.fold<double>(0, (m, v) => v > m ? v : m);
    return SizedBox(
      height: 132,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(valueText?.call(values[i]) ?? values[i].round().toString(),
                    style: CF.body(12.5, color: CF.muted, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  height: top <= 0 ? 3 : (3 + 74 * (values[i] / top)),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: (highlightLast && i != values.length - 1) ? .45 : 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(labels[i], style: CF.body(11.5, color: CF.muted)),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Barras horizontais do funil.
class FunnelBars extends StatelessWidget {
  const FunnelBars({super.key, required this.steps});
  final List<(String, int)> steps;

  @override
  Widget build(BuildContext context) {
    final top = steps.isEmpty || steps.first.$2 == 0 ? 1 : steps.first.$2;
    const colors = [CF.ink, CF.inkSoft, CF.blue, CF.lap];
    return Column(children: [
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(steps[i].$1, style: CF.body(14, weight: FontWeight.w600))),
              Text(i == 0 ? '${steps[i].$2}' : '${steps[i].$2} · ${(100 * steps[i].$2 / top).round()}%',
                  style: CF.body(14, weight: FontWeight.w700)),
            ]),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: (steps[i].$2 / top).clamp(0.0, 1.0),
                backgroundColor: CF.greyBg,
                color: colors[i % colors.length],
              ),
            ),
          ]),
        ),
    ]);
  }
}

/// Carrega algo, mostra o resultado e deixa tentar de novo se falhar.
class AsyncBlock<T> extends StatefulWidget {
  const AsyncBlock({super.key, required this.load, required this.builder, this.reloadKey});
  final Future<T> Function() load;
  final Widget Function(BuildContext, T) builder;
  final Object? reloadKey;

  @override
  State<AsyncBlock<T>> createState() => _AsyncBlockState<T>();
}

class _AsyncBlockState<T> extends State<AsyncBlock<T>> {
  late Future<T> _future = widget.load();

  @override
  void didUpdateWidget(AsyncBlock<T> old) {
    super.didUpdateWidget(old);
    if (old.reloadKey != widget.reloadKey) _future = widget.load();
  }

  void _retry() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            final msg = snap.error is AdminError ? snap.error.toString() : 'Não foi possível carregar.';
            return Panel(
              icon: Icons.cloud_off_rounded,
              color: CF.red,
              title: 'Não carregou',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(msg, style: CF.body(15, color: CF.muted)),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: _retry, child: const Text('Tentar de novo')),
              ]),
            );
          }
          return widget.builder(context, snap.data as T);
        },
      );
}
