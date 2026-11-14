import 'package:flutter/material.dart';

import '../billing/billing_engine.dart';
import '../billing/billing_store.dart';
import '../profile/profession_profile.dart';
import 'cf_theme.dart';

/// Uma linha lida da lista colada: nome, telefone e valor.
class ImportRow {
  const ImportRow(this.name, this.phone, this.rate);
  final String name;
  final String phone;
  final double rate;
}

/// Lê a lista que a pessoa colou (do Excel, do Google Planilhas ou digitada).
/// Cada linha: nome, telefone e valor, separados por tab, ponto e vírgula ou vírgula.
/// Só o nome é obrigatório. Linhas vazias e cabeçalhos ("Nome") são ignorados.
List<ImportRow> parseClientList(String text) {
  final rows = <ImportRow>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final sep = line.contains('\t') ? '\t' : (line.contains(';') ? ';' : ',');
    final cols = line.split(sep).map((c) => c.trim()).toList();
    final name = cols.first;
    if (name.isEmpty || RegExp(r'^(nome|cliente|aluno|paciente)s?$', caseSensitive: false).hasMatch(name)) continue;
    var phone = '';
    var rate = 0.0;
    for (final c in cols.skip(1)) {
      final digits = c.replaceAll(RegExp(r'[^0-9]'), '');
      final isMoney = c.contains('R\$') || RegExp(r'[.,]\d{1,2}$').hasMatch(c);
      if (!isMoney && digits.length >= 8 && phone.isEmpty) {
        phone = digits;
      } else if (rate == 0) {
        final v = double.tryParse(c.replaceAll('R\$', '').replaceAll(' ', '').replaceAll('.', '').replaceAll(',', '.'));
        if (v != null) rate = v;
      }
    }
    rows.add(ImportRow(name, phone, rate));
  }
  return rows;
}

String _norm(String s) => s.trim().toLowerCase();

Future<void> openClientImport(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: _ClientImport(messengerContext: context),
      ),
    );

class _ClientImport extends StatefulWidget {
  const _ClientImport({required this.messengerContext});
  final BuildContext messengerContext;
  @override
  State<_ClientImport> createState() => _ClientImportState();
}

class _ClientImportState extends State<_ClientImport> {
  final store = BillingStore.instance;
  final text = TextEditingController();
  String? error;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void _import() {
    final rows = parseClientList(text.text);
    if (rows.isEmpty) {
      setState(() => error = 'Cole ou digite pelo menos um nome, um por linha.');
      return;
    }
    final existing = {for (final p in store.plans) _norm(p.name)};
    final profile = ProfessionalProfile.instance;
    final today = store.today;
    var added = 0, repeated = 0;
    for (final r in rows) {
      if (existing.contains(_norm(r.name))) {
        repeated++;
        continue;
      }
      final before = store.activePlans.length;
      store.savePlan(StudentPlan(
        id: store.newClientId(),
        name: r.name,
        phone: r.phone,
        rate: r.rate,
        model: profile.model,
        durationMinutes: profile.profession.duration,
        packageStart: DateTime(today.year, today.month),
        dueDay: 10,
      ));
      if (store.activePlans.length == before) break; // limite do plano ou conta somente leitura
      existing.add(_norm(r.name));
      added++;
    }
    final left = rows.length - added - repeated;
    Navigator.pop(context);
    final t = store.terms;
    final parts = [
      if (added > 0) '$added ${added == 1 ? t.client : t.clients} cadastrad${t.g('a', 'o')}${added == 1 ? '' : 's'}',
      if (repeated > 0) '$repeated já existia${repeated == 1 ? '' : 'm'}',
      if (left > 0) '$left não ${left == 1 ? 'coube' : 'couberam'} no seu plano',
    ];
    ScaffoldMessenger.of(widget.messengerContext).showSnackBar(SnackBar(
      content: Text(parts.isEmpty ? 'Nada foi importado.' : '${parts.join('. ')}.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = store.terms;
    final count = parseClientList(text.text).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Importar ${t.clients}', style: CF.body(24, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Cole aqui a sua lista, uma pessoa por linha: nome, telefone e valor. '
              'Pode copiar direto de uma planilha. Só o nome é obrigatório.',
              style: CF.body(15, color: CF.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: text,
              minLines: 6,
              maxLines: 12,
              keyboardType: TextInputType.multiline,
              onChanged: (_) => setState(() => error = null),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ana Souza; 11 99999-1111; 150\nBruno Lima; 11 98888-2222; 200,00\nCarla Dias',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              count == 0 ? 'Depois você ajusta dias, horários e forma de cobrança em cada cadastro.' : '$count ${count == 1 ? t.client : t.clients} encontrad${t.g('a', 'o')}${count == 1 ? '' : 's'}. Depois você ajusta dias, horários e cobrança em cada cadastro.',
              style: CF.body(14, color: CF.muted),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: CF.body(15, color: CF.red, weight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.upload_rounded),
              label: Text(count == 0 ? 'Importar' : 'Importar $count'),
            ),
          ]),
        ),
      ),
    );
  }
}
