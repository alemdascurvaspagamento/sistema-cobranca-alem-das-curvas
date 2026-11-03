import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'billing/billing_engine.dart';
import 'billing/billing_store.dart';
import 'config.dart';
import 'ui/cf_theme.dart';
import 'ui/widgets.dart';

String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Link de pagamento: uma página pública com o valor, o QR Code e o botão
/// "Copiar código Pix". O WhatsApp barra mensagens com o código copia e cola,
/// então a cobrança leva só o link.
class PayLinks {
  PayLinks._();

  /// Cria (ou reaproveita) o link de pagamento. `null` na demonstração, sem
  /// chave Pix, sem nada a pagar ou sem internet: aí a mensagem vai sem link.
  static Future<String?> linkFor({
    required String clientId,
    required String payerFirst,
    required double amount,
    required DateTime due,
    required String pixKey,
    required String pixCode,
  }) async {
    final store = BillingStore.instance;
    if (!store.isCloud || pixKey.isEmpty || amount <= 0) return null;
    final m = store.selectedMonth;
    final month = DateTime(m.year, m.month);
    final value = double.parse(amount.toStringAsFixed(2));
    try {
      final db = Supabase.instance.client;
      // Mesmo cliente, mês e valor: usa o link que já existe.
      final found = await db
          .from('cf_pay_links')
          .select('token')
          .eq('client_id', clientId)
          .eq('month', _d(month))
          .eq('amount', value)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .limit(1);
      String token;
      if (found.isNotEmpty) {
        token = found.first['token'] as String;
      } else {
        final row = await db
            .from('cf_pay_links')
            .insert({
              'client_id': clientId,
              'payer_first': payerFirst,
              'title': store.pixName.isNotEmpty ? store.pixName : store.businessName,
              'month': _d(month),
              'amount': value,
              'due': _d(due),
              'pix_key': pixKey,
              'pix_code': pixCode,
              // Vale até o fim do mês seguinte.
              'expires_at': DateTime(month.year, month.month + 2).toUtc().toIso8601String(),
            })
            .select('token')
            .single();
        token = row['token'] as String;
      }
      return '${AppConfig.publicUrl}/?pagar=$token';
    } catch (e) {
      debugPrint('Leguno: link de pagamento indisponível ($e)');
      return null;
    }
  }
}

/// Página que o aluno abre pelo link: valor, vencimento, QR Code e "Copiar código Pix".
class PayPublicPage extends StatefulWidget {
  const PayPublicPage({super.key, required this.token});
  final String token;

  @override
  State<PayPublicPage> createState() => _PayPublicPageState();
}

class _PayPublicPageState extends State<PayPublicPage> {
  Map<String, dynamic>? data;
  bool loading = true;
  String? fatal;
  bool copied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Supabase.instance.client.rpc('cf_public_pay', params: {'p_token': widget.token});
      if (r == null) {
        fatal = 'Este link de pagamento não vale mais. Peça um novo a quem te cobrou.';
      } else {
        data = Map<String, dynamic>.from(r as Map);
      }
    } catch (_) {
      fatal = 'Não foi possível abrir o pagamento agora. Confira a internet e tente de novo.';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _copy(String text, String msg) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => copied = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CF.bg,
      appBar: AppBar(
        backgroundColor: CF.ink,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const BrandMark(size: 28),
          const SizedBox(width: 8),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'Le', style: CF.body(20, color: Colors.white, weight: FontWeight.w800)),
            TextSpan(text: 'g', style: CF.body(20, color: CF.lap, weight: FontWeight.w800)),
            TextSpan(text: 'uno', style: CF.body(20, color: Colors.white, weight: FontWeight.w800)),
          ])),
        ]),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : fatal != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(fatal!, textAlign: TextAlign.center, style: CF.body(17)),
                  ),
                )
              : _page(),
    );
  }

  Widget _page() {
    final m = data!;
    final amount = (m['amount'] as num).toDouble();
    final month = DateTime.parse('${m['month']}');
    final due = m['due'] == null ? null : DateTime.parse('${m['due']}');
    final code = '${m['pix_code']}';
    final key = '${m['pix_key']}';
    final payer = '${m['payer']}'.trim();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 40), children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(payer.isEmpty ? 'Pagamento' : 'Olá, $payer!', style: CF.body(24, weight: FontWeight.w800)),
            Text('Pagamento de ${monthNames[month.month - 1]} para ${m['title']}.',
                style: CF.body(16, color: CF.muted, height: 1.35)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: CF.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CF.line),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Valor', style: CF.body(14, color: CF.muted)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(money(amount), style: CF.score(46)),
                ),
                if (due != null) Text('Vencimento: ${ddmm(due)}', style: CF.body(15, color: CF.muted)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _copy(code, 'Código Pix copiado. Abra o app do seu banco e escolha "Pix copia e cola".'),
                  style: FilledButton.styleFrom(backgroundColor: CF.pix, minimumSize: const Size(0, 54)),
                  icon: Icon(copied ? Icons.check_rounded : Icons.copy_rounded),
                  label: Text(copied ? 'Código copiado' : 'Copiar código Pix'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Depois, no app do seu banco: Pix › Pix copia e cola › cole o código. '
                  'O valor já vai preenchido.',
                  style: CF.body(14, color: CF.muted, height: 1.35),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CF.line),
                ),
                child: QrImageView(data: code, size: 200, backgroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text('Pagando pelo computador? Leia este QR Code com o app do banco no celular.',
                textAlign: TextAlign.center, style: CF.body(13.5, color: CF.muted)),
            if (key.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _copy(key, 'Chave Pix copiada.'),
                icon: const Icon(Icons.key_rounded, size: 18),
                label: Text('Ou copie a chave Pix: $key', overflow: TextOverflow.ellipsis),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }
}
