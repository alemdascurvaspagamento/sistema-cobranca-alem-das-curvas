import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_store.dart';
import '../ui/cf_theme.dart';
import '../ui/widgets.dart';
import '../data/ids.dart';

/// Financeiro: quanto entrou, quanto saiu e o que sobrou no mês.
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key, required this.onBilling});
  final VoidCallback onBilling;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final m = store.selectedMonth;
        return LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 980;
          final title = wide
              ? const PageTitle('Financeiro', trailing: MonthSwitcher())
              : const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  PageTitle('Financeiro'),
                  Align(alignment: Alignment.centerLeft, child: MonthSwitcher()),
                ]);
          final result = _ResultCard(month: m);
          final chart = _HistoryChart(month: m);
          final incomes = _Incomes(month: m, onBilling: onBilling);
          final expenses = _Expenses(month: m);
          if (wide) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              title,
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(children: [result, const SizedBox(height: 14), chart])),
                const SizedBox(width: 16),
                Expanded(child: Column(children: [incomes, const SizedBox(height: 14), expenses])),
              ]),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            title,
            const SizedBox(height: 10),
            result,
            const SizedBox(height: 14),
            incomes,
            const SizedBox(height: 14),
            expenses,
            const SizedBox(height: 14),
            chart,
            const SizedBox(height: 8),
          ]);
        });
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final income = store.totalIn(month);
    final out = store.expensesPaid(month);
    final toPay = store.expensesOpen(month);
    final result = income - out;
    final goal = store.monthlyGoal;
    final progress = goal <= 0 ? 0.0 : (income / goal).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: CF.ink, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Sobrou em ${monthNames[month.month - 1]}', style: CF.body(15, color: Colors.white70)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(moneyCompact(result), style: CF.score(48, color: result < 0 ? const Color(0xFFFF9AA2) : Colors.white)),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _DarkStat(label: 'Entrou', value: moneyCompact(income), color: CF.mint)),
          Expanded(child: _DarkStat(label: 'Saiu (pago)', value: moneyCompact(out), color: const Color(0xFFFF9AA2))),
          Expanded(child: _DarkStat(label: 'Contas a pagar', value: moneyCompact(toPay), color: CF.lap)),
        ]),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _editGoal(context),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    goal <= 0
                        ? 'Defina uma meta para o mês'
                        : 'Meta de ${moneyCompact(goal)} · ${(progress * 100).round()}% alcançada',
                    style: CF.body(14, color: Colors.white70),
                  ),
                ),
                const Icon(Icons.edit_rounded, size: 16, color: Colors.white54),
              ]),
              const SizedBox(height: 8),
              LaneTrack(progress: progress),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _DarkStat extends StatelessWidget {
  const _DarkStat({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: CF.body(14, color: Colors.white70)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: CF.score(28, color: color)),
        ),
      ]);
}

Future<void> _editGoal(BuildContext context) async {
  final store = BillingStore.instance;
  final input = TextEditingController(
      text: store.monthlyGoal <= 0 ? '' : store.monthlyGoal.toStringAsFixed(0));
  final value = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Meta do mês'),
      content: TextField(
        controller: input,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Quanto você quer receber por mês',
          prefixText: 'R\$ ',
          helperText: 'Conta tudo o que entra: cobranças e ganhos extras.',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, double.tryParse(input.text) ?? 0),
          child: const Text('Salvar meta'),
        ),
      ],
    ),
  );
  input.dispose();
  if (value != null) store.setGoal(value);
}

/// Barras simples dos últimos 6 meses: entrou × saiu.
class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final months = [for (var k = 5; k >= 0; k--) DateTime(month.year, month.month - k)];
    final ins = [for (final m in months) store.totalIn(m)];
    final outs = [for (final m in months) store.expensesPaid(m)];
    final top = [...ins, ...outs].fold<double>(1, (a, b) => b > a ? b : a);
    return Panel(
      title: 'Últimos 6 meses',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 150,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < months.length; i++)
              Expanded(
                child: Tooltip(
                  message: '${capitalize(monthNames[months[i].month - 1])}: entrou ${moneyCompact(ins[i])}, '
                      'saiu ${moneyCompact(outs[i])}',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(child: _Bar(height: 150 * ins[i] / top, color: CF.green, faded: i != months.length - 1)),
                      const SizedBox(width: 3),
                      Expanded(child: _Bar(height: 150 * outs[i] / top, color: CF.red, faded: i != months.length - 1)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          for (final m in months)
            Expanded(
              child: Text(monthNames[m.month - 1].substring(0, 3),
                  textAlign: TextAlign.center, style: CF.body(13, color: CF.muted)),
            ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _Legend(color: CF.green, text: 'Entrou'),
          const SizedBox(width: 16),
          _Legend(color: CF.red, text: 'Saiu'),
        ]),
      ]),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color, required this.faded});
  final double height;
  final Color color;
  final bool faded;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: height < 2 ? 2 : height,
        decoration: BoxDecoration(
          color: faded ? color.withValues(alpha: .45) : color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(text, style: CF.body(14, color: CF.muted)),
      ]);
}

class _Incomes extends StatelessWidget {
  const _Incomes({required this.month, required this.onBilling});
  final DateTime month;
  final VoidCallback onBilling;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final t = store.terms;
    final payments = store.paymentsIn(month);
    final extras = store.incomesFor(month);
    final open = store.activePlans.fold(0.0, (s, p) => s + store.remaining(p, month: month));
    return Panel(
      title: 'Entradas',
      action: TextButton.icon(
        onPressed: () => _openEntrySheet(context, expense: false),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Ganho extra'),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('De ${t.clients}', style: CF.body(14, color: CF.muted, weight: FontWeight.w600)),
        if (payments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Nenhum pagamento registrado neste mês.', style: CF.body(15, color: CF.muted)),
          )
        else
          for (final (p, e) in payments)
            _MoneyRow(
              title: p.name,
              detail: '${ddmm(e.date)} · ${e.method}',
              value: money(e.amount),
              color: CF.green,
            ),
        if (open > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              onTap: onBilling,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  const Icon(Icons.schedule_rounded, size: 18, color: CF.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Ainda falta receber ${moneyCompact(open)} das cobranças deste mês',
                        style: CF.body(14, color: CF.amber, weight: FontWeight.w600)),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: CF.amber),
                ]),
              ),
            ),
          ),
        const Divider(height: 22),
        Text('Ganhos extras', style: CF.body(14, color: CF.muted, weight: FontWeight.w600)),
        if (extras.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Avaliações avulsas, palestras, vendas: registre aqui o que não é mensalidade.',
                style: CF.body(15, color: CF.muted)),
          )
        else
          for (final e in extras)
            _MoneyRow(
              title: e.description,
              detail: ddmm(e.date),
              value: money(e.amount),
              color: CF.green,
              onDelete: () => _confirmRemove(context, 'Remover "${e.description}"?', 'O valor sai das entradas do mês.',
                  () => store.removeIncome(e.id)),
            ),
      ]),
    );
  }
}

class _Expenses extends StatelessWidget {
  const _Expenses({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final list = store.expensesFor(month);
    final open = store.expensesOpen(month);
    return Panel(
      title: 'Despesas',
      action: TextButton.icon(
        onPressed: () => _openEntrySheet(context, expense: true),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Despesa'),
      ),
      child: list.isEmpty
          ? const EmptyNote(icon: Icons.receipt_long_rounded, text: 'Nenhuma despesa neste mês.')
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                open > 0
                    ? 'Falta pagar ${moneyCompact(open)} de ${moneyCompact(store.expensesTotal(month))}'
                    : 'Todas as despesas do mês estão pagas.',
                style: CF.body(14, color: open > 0 ? CF.amber : CF.green, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              for (final e in list) _ExpenseRow(expense: e, month: month),
            ]),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense, required this.month});
  final Expense expense;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final store = BillingStore.instance;
    final e = expense;
    final status = store.expenseStatus(e);
    final paid = store.paidAt(e);
    final (fg, bg, label) = switch (status) {
      ExpenseStatus.paid => (CF.green, CF.greenBg, 'Paga'),
      ExpenseStatus.overdue => (CF.red, CF.redBg, 'Atrasada'),
      ExpenseStatus.open => (CF.amber, CF.amberBg, 'A pagar'),
    };
    final detail = StringBuffer(paid != null ? 'Paga em ${ddmm(paid)}' : 'Vence em ${ddmm(e.date)}');
    if (e.fixed) detail.write(' · fixa, todo mês');

    void undo() {
      store.unpayExpense(e);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: CF.body(16, weight: FontWeight.w600)),
              Text(detail.toString(), style: CF.body(14, color: CF.muted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(e.amount), style: CF.score(22, color: paid != null ? CF.muted : CF.text)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
              child: Text(label, style: CF.body(12, color: fg, weight: FontWeight.w700)),
            ),
          ]),
          PopupMenuButton<String>(
            tooltip: 'Mais ações',
            icon: const Icon(Icons.more_vert_rounded, color: CF.muted, size: 20),
            onSelected: (v) {
              if (v == 'undo') undo();
              if (v == 'date') _payOnDate(context, e);
              if (v == 'remove') {
                if (e.fixed) {
                  _confirmRemove(
                    context,
                    'Parar de repetir "${e.description}"?',
                    'Ela sai deste mês em diante. Os meses anteriores continuam como estão.',
                    () => store.removeExpense(e.id, fromMonth: month),
                    confirmLabel: 'Parar de repetir',
                  );
                } else {
                  _confirmRemove(context, 'Remover "${e.description}"?', 'O valor sai das despesas do mês.',
                      () => store.removeExpense(e.id));
                }
              }
            },
            itemBuilder: (_) => [
              if (paid != null) const PopupMenuItem(value: 'undo', child: Text('Desfazer baixa')),
              if (paid == null) const PopupMenuItem(value: 'date', child: Text('Dar baixa em outra data')),
              PopupMenuItem(value: 'remove', child: Text(e.fixed ? 'Parar de repetir' : 'Remover')),
            ],
          ),
        ]),
        if (paid == null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: status == ExpenseStatus.overdue ? CF.red : CF.ink,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () {
                  store.payExpense(e);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Baixa feita: ${e.description} paga hoje.'),
                    action: SnackBarAction(label: 'Desfazer', onPressed: undo),
                  ));
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Dar baixa'),
              ),
            ),
          ),
      ]),
    );
  }
}

Future<void> _payOnDate(BuildContext context, Expense e) async {
  final store = BillingStore.instance;
  final picked = await showDatePicker(
    context: context,
    initialDate: store.today,
    firstDate: DateTime(e.date.year - 1),
    lastDate: DateTime(e.date.year + 1, 12, 31),
    helpText: 'Data do pagamento',
  );
  if (picked != null) store.payExpense(e, on: picked);
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.title, required this.detail, required this.value, required this.color, this.onDelete});
  final String title, detail, value;
  final Color color;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: CF.body(16, weight: FontWeight.w600)),
              Text(detail, style: CF.body(14, color: CF.muted)),
            ]),
          ),
          Text(value, style: CF.score(22, color: color)),
          if (onDelete != null)
            PopupMenuButton<String>(
              tooltip: 'Mais ações',
              icon: const Icon(Icons.more_vert_rounded, color: CF.muted, size: 20),
              onSelected: (_) => onDelete!(),
              itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Remover'))],
            ),
        ]),
      );
}

Future<void> _confirmRemove(BuildContext context, String title, String body, VoidCallback onConfirm,
    {String confirmLabel = 'Remover'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Manter')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: CF.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  if (ok == true) onConfirm();
}

Future<void> _openEntrySheet(BuildContext context, {required bool expense}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: _EntrySheet(expense: expense),
      ),
    );

class _EntrySheet extends StatefulWidget {
  const _EntrySheet({required this.expense});
  final bool expense;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  final store = BillingStore.instance;
  final description = TextEditingController();
  final amount = TextEditingController();
  late DateTime date = _defaultDate();
  bool fixed = false;
  String? error;

  DateTime _defaultDate() {
    final m = store.selectedMonth;
    final today = store.today;
    return (today.year == m.year && today.month == m.month) ? today : DateTime(m.year, m.month, 1);
  }

  @override
  void dispose() {
    description.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(date.year - 1),
      lastDate: DateTime(date.year + 1, 12, 31),
    );
    if (picked != null) setState(() => date = picked);
  }

  void _save() {
    final v = double.tryParse(amount.text.replaceAll('.', '').replaceAll(',', '.'));
    if (description.text.trim().isEmpty) {
      setState(() => error = 'Escreva uma descrição.');
      return;
    }
    if (v == null || v <= 0) {
      setState(() => error = 'Digite um valor maior que zero.');
      return;
    }
    final id = newUuid();
    if (widget.expense) {
      store.addExpense(Expense(id: id, description: description.text.trim(), amount: v, date: date, fixed: fixed));
    } else {
      store.addIncome(ExtraIncome(id: id, description: description.text.trim(), amount: v, date: date));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(e ? 'Nova despesa' : 'Novo ganho extra', style: CF.body(24, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: description,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Descrição',
                hintText: e ? 'Ex.: Aluguel da sala' : 'Ex.: Avaliação avulsa',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              style: CF.score(26),
              decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text(e && fixed ? 'Começa em ${ddmm(date)}' : 'Data: ${ddmm(date)}'),
            ),
            if (e) ...[
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: CF.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CF.line),
                ),
                child: SwitchListTile(
                  value: fixed,
                  activeTrackColor: CF.ink,
                  onChanged: (v) => setState(() => fixed = v),
                  title: Text('Repete todo mês', style: CF.body(16, weight: FontWeight.w700)),
                  subtitle: Text('Para aluguel, internet, contador e outras contas fixas.',
                      style: CF.body(14, color: CF.muted)),
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: CF.body(15, color: CF.red, weight: FontWeight.w600)),
            ],
            const SizedBox(height: 18),
            FilledButton(onPressed: _save, child: Text(e ? 'Salvar despesa' : 'Salvar ganho')),
          ]),
        ),
      ),
    );
  }
}
