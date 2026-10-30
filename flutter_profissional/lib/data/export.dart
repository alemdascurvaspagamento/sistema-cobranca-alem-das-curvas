import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_store.dart';

/// Monta uma planilha (Excel) com todos os dados do profissional.
///
/// Abas: Resumo por mês, Cobranças, Pagamentos, Clientes, Atendimentos alterados,
/// Despesas, Ganhos extras e Feriados.
Uint8List buildDataWorkbook(BillingStore store) {
  final t = store.terms;
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();

  CellValue tx(String v) => TextCellValue(v);
  CellValue nu(double v) => DoubleCellValue((v * 100).roundToDouble() / 100);
  CellValue it(int v) => IntCellValue(v);
  String d(DateTime x) => '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
  String ym(DateTime x) => '${x.month.toString().padLeft(2, '0')}/${x.year}';

  Sheet sheet(String name, List<String> header) {
    final s = excel[name];
    s.appendRow([for (final h in header) tx(h)]);
    return s;
  }

  // Meses cobertos: do primeiro pagamento (ou 12 meses atrás) até o mês que vem.
  final now = DateTime(store.today.year, store.today.month);
  final first = store.firstPaymentMonth ?? DateTime(now.year, now.month - 11);
  final months = <DateTime>[];
  for (var m = first; !m.isAfter(DateTime(now.year, now.month + 1)); m = DateTime(m.year, m.month + 1)) {
    months.add(m);
  }

  // Resumo por mês
  final summary = sheet('Resumo por mês', [
    'Mês', 'Cobrado', 'Recebido de ${t.clients}', 'Ganhos extras', 'Despesas', 'Despesas pagas', 'Sobrou (caixa)',
  ]);
  for (final m in months) {
    final f = store.forecast(m);
    summary.appendRow([
      tx(ym(m)), nu(f.billed), nu(f.received), nu(f.extras), nu(f.expensesPlanned), nu(f.expensesPaid), nu(f.resultNow),
    ]);
  }

  // Cobranças por cliente e mês
  final bills = sheet('Cobranças', [
    'Mês', t.clientTitle, 'Forma de cobrança', t.sessionsTitle, 'Faltas', 'Desconto', 'Valor do mês',
    'Recebido', 'Falta receber', 'Vencimento', 'Situação',
  ]);
  for (final m in months) {
    for (final p in store.plans) {
      final b = store.bill(p, month: m);
      final got = store.received(p.id, month: m);
      if (b.total == 0 && got == 0) continue;
      bills.appendRow([
        tx(ym(m)), tx(p.name), tx(p.model.title), it(b.billedLessons),
        it(b.cancelledCharged + b.cancelledWaived), nu(b.discountValue), nu(b.total), nu(got),
        nu(store.remaining(p, month: m)), tx(d(store.dueDate(p, month: m))), tx(store.status(p, month: m).label),
      ]);
    }
  }

  // Pagamentos
  final pays = sheet('Pagamentos', ['Data', t.clientTitle, 'Mês de referência', 'Valor', 'Forma']);
  for (final m in months) {
    for (final p in store.plans) {
      for (final e in store.payments(p.id, month: m)) {
        pays.appendRow([tx(d(e.date)), tx(p.name), tx(ym(m)), nu(e.amount), tx(e.method)]);
      }
    }
  }

  // Clientes
  const weekNames = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  final clients = sheet(t.clientsTitle, [
    'Nome', 'Telefone', 'Serviço', 'Forma de cobrança', 'Valor', 'Dias e horários', 'Vencimento (dia)', 'Situação',
  ]);
  for (final p in store.plans) {
    final days = (p.weekdays.toList()..sort())
        .map((w) => '${weekNames[w - 1]}${p.times[w] != null ? ' ${p.times[w]}' : ''}')
        .join(', ');
    clients.appendRow([
      tx(p.name), tx(p.phone), tx(p.service), tx(p.model.title), nu(p.rate), tx(days), it(p.dueDay),
      tx(p.active ? 'Ativo' : 'Arquivado'),
    ]);
  }

  // Atendimentos com alteração (faltas, remarcações, avulsos...)
  final sessions = sheet('${t.sessionsTitle} alterad${t.g('a', 'o')}s', [
    'Data', t.clientTitle, 'O que aconteceu', 'Cobrar?', 'Nova data', 'Horário', 'Observação',
  ]);
  final rows = <(DateTime, String, LessonRecord)>[];
  for (final p in store.plans) {
    store.eventsFor(p.id).forEach((key, r) {
      final date = parseDateKey(key);
      if (date != null) rows.add((date, p.name, r));
    });
  }
  rows.sort((a, b) => a.$1.compareTo(b.$1));
  for (final (date, name, r) in rows) {
    sessions.appendRow([
      tx(d(date)), tx(name), tx(r.extra ? 'Avulso' : r.status.label(t)),
      tx(r.charge == null ? 'Regra padrão' : (r.charge! ? 'Sim' : 'Não')),
      tx(r.newDate == null ? '' : d(r.newDate!)), tx(r.time ?? ''), tx(r.note),
    ]);
  }

  // Despesas (cada mês de uma fixa vira uma linha)
  final exp = sheet('Despesas', ['Vencimento', 'Descrição', 'Valor', 'Fixa', 'Paga em']);
  for (final m in months) {
    for (final e in store.expensesFor(m)) {
      final paid = store.paidAt(e);
      exp.appendRow([tx(d(e.date)), tx(e.description), nu(e.amount), tx(e.fixed ? 'Sim' : 'Não'),
        tx(paid == null ? 'A pagar' : d(paid))]);
    }
  }

  // Ganhos extras
  final inc = sheet('Ganhos extras', ['Data', 'Descrição', 'Valor']);
  for (final e in [...store.allIncomes]..sort((a, b) => a.date.compareTo(b.date))) {
    inc.appendRow([tx(d(e.date)), tx(e.description), nu(e.amount)]);
  }

  // Feriados
  final hol = sheet('Feriados', ['Data', 'Nome', 'Tem ${t.session}?']);
  for (final h in store.holidays) {
    hol.appendRow([tx(d(h.date)), tx(h.name), tx(h.noClass ? 'Não' : 'Sim')]);
  }

  if (defaultSheet != null) excel.delete(defaultSheet);
  excel.setDefaultSheet('Resumo por mês');
  return Uint8List.fromList(excel.encode()!);
}

/// Gera a planilha e entrega: baixa no computador, salva em Downloads no celular.
Future<String> downloadMyData(BillingStore store) async {
  final bytes = buildDataWorkbook(store);
  final now = store.today;
  final name = 'okday-dados-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return FileSaver.instance.saveFile(name: name, bytes: bytes, ext: 'xlsx', mimeType: MimeType.microsoftExcel);
}
