import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../ui/cf_theme.dart';
import '../ui/widgets.dart';

/// Léguno Fiscal: DEMONSTRAÇÃO.
///
/// Mostra como vai ser a emissão de notas fiscais, só com dados de exemplo.
/// Nada aqui emite nota, fala com prefeitura, Focus NFe ou Asaas, nem mexe no banco.
/// A única ação real é "Quero ser avisado", que manda um aviso à equipe pela
/// caixa de ajuda que já existe.
///
/// Onde aparece:
/// - no navegador, para todos (como antes);
/// - nos apps das lojas (iPhone/Android), SÓ para contas de teste marcadas no banco
///   (tabela cf_beta_testers). A conta de revisão da Apple não está lá, então não vê.
///   Nos apps a aba "Planos" e qualquer menção a plano/preço ficam escondidas.
const bool _fiscalFlag = bool.fromEnvironment('FISCAL_DEMO', defaultValue: true);

/// Liga a demonstração nos apps das lojas para contas de teste. Começa desligado.
final ValueNotifier<bool> fiscalBetaAllowed = ValueNotifier<bool>(false);

bool get fiscalDemoEnabled =>
    _fiscalFlag && ((kIsWeb && !AppConfig.hidePricing) || (AppConfig.hidePricing && fiscalBetaAllowed.value));

/// Pergunta ao banco se esta conta é de teste do Léguno Fiscal. Qualquer erro = não mostra.
Future<void> loadFiscalBeta() async {
  if (!_fiscalFlag || !AppConfig.hidePricing || !AppConfig.cloudEnabled) return;
  try {
    final r = await Supabase.instance.client.rpc('cf_has_beta', params: {'p_feature': 'fiscal_demo'});
    fiscalBetaAllowed.value = r == true;
  } catch (_) {
    fiscalBetaAllowed.value = false;
  }
}

/// Cartão que abre a demonstração, para ficar em Configurações.
class FiscalDemoEntry extends StatelessWidget {
  const FiscalDemoEntry({super.key});

  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
          leading: const Icon(Icons.receipt_long_rounded, color: CF.brand),
          title: Row(children: [
            Flexible(child: Text('Léguno Fiscal', style: CF.body(16, weight: FontWeight.w700))),
            const SizedBox(width: 8),
            _chip('Em breve', CF.violet, CF.violetBg),
          ]),
          subtitle: Text('Veja como vai ser a emissão de notas fiscais. Demonstração, com dados de exemplo.',
              style: CF.body(14, color: CF.muted)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FiscalDemoScreen())),
          ),
        ),
      );
}

Widget _chip(String text, Color fg, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: CF.body(12.5, weight: FontWeight.w700, color: fg)),
    );

enum _Tab { painel, emitir, historico, config, automacao, planos, fechar }

extension on _Tab {
  String get label => switch (this) {
        _Tab.painel => 'Painel',
        _Tab.emitir => 'Emitir nota',
        _Tab.historico => 'Histórico',
        _Tab.config => 'Configurações',
        _Tab.automacao => 'Automação',
        _Tab.planos => 'Planos',
        _Tab.fechar => 'Fechar o mês',
      };
}

class FiscalDemoScreen extends StatefulWidget {
  const FiscalDemoScreen({super.key});

  @override
  State<FiscalDemoScreen> createState() => _FiscalDemoScreenState();
}

class _FiscalDemoScreenState extends State<FiscalDemoScreen> {
  _Tab tab = _Tab.painel;
  bool autoAfterPayment = true;
  bool autoMonthClose = false;
  bool sendToClient = true;
  int issuer = 0;
  int filter = 0;
  bool interestSent = false;

  void _demoNotice() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.science_rounded, color: CF.brand, size: 34),
        title: const Text('Isto é uma demonstração'),
        content: Text(
          'Nesta versão nenhuma nota é emitida e nada é enviado para a prefeitura. '
          'Quando o Léguno Fiscal estiver pronto, este botão passa a funcionar de verdade.',
          style: CF.body(15.5, height: 1.4),
        ),
        actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Entendi'))],
      ),
    );
  }

  Future<void> _wantToBeNotified() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Avisar a equipe?'),
        content: Text(
          'Vamos avisar a equipe do Léguno que você quer usar o Léguno Fiscal quando ele ficar pronto. '
          'Você recebe um e-mail de confirmação na conta que usa no Léguno.',
          style: CF.body(15.5, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Agora não')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Quero ser avisado')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    var done = false;
    if (AppConfig.cloudEnabled) {
      try {
        final res = await Supabase.instance.client.functions.invoke('cf-fiscal-interest');
        final d = res.data;
        done = d is Map && d['ok'] == true;
      } catch (_) {
        done = false;
      }
    }
    if (!mounted) return;
    setState(() => interestSent = done);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(done ? 'Pronto! Avisamos a equipe.' : 'Não deu para enviar agora. Tente de novo mais tarde.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CF.bg,
      appBar: AppBar(title: const Text('Léguno Fiscal')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: CF.amberBg, borderRadius: BorderRadius.circular(14)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.science_rounded, color: CF.amber, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Demonstração. Os nomes e valores são de exemplo e nenhuma nota é emitida de verdade.',
                      style: CF.body(14.5, color: CF.amber, weight: FontWeight.w600, height: 1.3),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              PillGrid(columns: 3, narrowColumns: 2, children: [
                for (final t in _Tab.values.where((t) => !(AppConfig.hidePricing && t == _Tab.planos))) Pill(label: t.label, selected: tab == t, onTap: () => setState(() => tab = t)),
              ]),
              const SizedBox(height: 14),
              ...switch (tab) {
                _Tab.painel => _painel(),
                _Tab.emitir => _emitir(),
                _Tab.historico => _historico(),
                _Tab.config => _config(),
                _Tab.automacao => _automacao(),
                _Tab.planos => _planos(),
                _Tab.fechar => _fechar(),
              },
              const SizedBox(height: 14),
              Panel(
                icon: Icons.notifications_active_rounded,
                color: CF.violet,
                title: 'Quer usar quando sair?',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Estamos decidindo se vale construir. Se você tem interesse, avise a equipe.',
                      style: CF.body(14.5, color: CF.muted, height: 1.3)),
                  const SizedBox(height: 10),
                  RaisedActionButton(
                    icon: interestSent ? Icons.check_circle_rounded : Icons.notifications_rounded,
                    label: interestSent ? 'Equipe avisada' : 'Quero ser avisado',
                    filled: interestSent ? CF.green : CF.violet,
                    onPressed: interestSent ? () {} : _wantToBeNotified,
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _gap([double h = 12]) => SizedBox(height: h);

  // ---------- Painel ----------
  List<Widget> _painel() => [
        Panel(
          icon: Icons.verified_rounded,
          color: CF.brand,
          title: AppConfig.hidePricing ? 'Notas do mês' : 'Fiscal Plus',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('14 de 50 notas usadas em novembro', style: CF.body(15, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: const LinearProgressIndicator(value: 14 / 50, minHeight: 10, color: CF.brand, backgroundColor: CF.greyBg),
            ),
            const SizedBox(height: 6),
            Text(AppConfig.hidePricing ? 'Restam 36 notas neste mês' : 'Restam 36 notas no plano', style: CF.body(13.5, color: CF.muted)),
          ]),
        ),
        _gap(),
        const KpiRow([
          KpiCard(icon: Icons.check_circle_rounded, label: 'Autorizadas', value: '11', color: CF.green, accent: true),
          KpiCard(icon: Icons.hourglass_top_rounded, label: 'Pendentes', value: '2', color: CF.amber, accent: true),
          KpiCard(icon: Icons.error_rounded, label: 'Rejeitadas', value: '1', color: CF.red, accent: true),
          KpiCard(icon: Icons.block_rounded, label: 'Canceladas', value: '0', color: CF.grey, accent: true),
        ]),
        _gap(),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Serviços documentados em novembro', style: CF.body(14, color: CF.muted)),
            const SizedBox(height: 4),
            Text('R\$ 9.840,00', style: CF.score(30)),
          ]),
        ),
        _gap(),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: CF.redBg, borderRadius: BorderRadius.circular(14)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.warning_amber_rounded, color: CF.red, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text('1 nota rejeitada. O endereço da cliente Carla Mendes está incompleto. Corrija e envie de novo.',
                  style: CF.body(14.5, color: CF.red, weight: FontWeight.w600, height: 1.3)),
            ),
          ]),
        ),
        _gap(14),
        RaisedActionButton(icon: Icons.add_rounded, label: 'Emitir nota', filled: CF.brand, onPressed: () => setState(() => tab = _Tab.emitir)),
      ];

  // ---------- Emitir ----------
  Widget _field(String label, String value, {String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, helperText: hint),
          child: Text(value, style: CF.body(16, weight: FontWeight.w600)),
        ),
      );

  List<Widget> _emitir() => [
        Panel(
          icon: Icons.note_add_rounded,
          color: CF.brand,
          title: 'Emitir nota',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _field('Cliente', 'Bruno Lima', hint: 'CPF informado'),
            _field('Serviço', 'Treino funcional (sessão individual)'),
            Row(children: [
              Expanded(child: _field('Valor', 'R\$ 250,00')),
              const SizedBox(width: 10),
              Expanded(child: _field('Competência', 'Novembro/2026')),
            ]),
            _field('Descrição na nota', 'Sessão de treino funcional realizada em 16/11/2026.'),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: CF.amberBg, borderRadius: BorderRadius.circular(12)),
              child: Text('Modo de teste: neste ambiente nenhuma nota real é emitida.',
                  style: CF.body(13.5, color: CF.amber, weight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            RaisedActionButton(label: 'Revisar e emitir', filled: CF.brand, onPressed: _demoNotice),
          ]),
        ),
      ];

  // ---------- Histórico ----------
  static const _invoices = <(String, String, String, int, String)>[
    ('Isabela Prado', 'Nº 1042 · Nov/2026', 'R\$ 1.040,00', 0, 'Autorizada'),
    ('Bruno Lima', 'Nº 1041 · Nov/2026', 'R\$ 480,00', 0, 'Autorizada'),
    ('Diego Alves', 'Aguardando a prefeitura', 'R\$ 250,00', 1, 'Pendente'),
    ('Carla Mendes', 'Endereço da cliente incompleto', 'R\$ 700,00', 2, 'Rejeitada'),
  ];

  List<Widget> _historico() {
    const names = ['Todas', 'Autorizadas', 'Pendentes', 'Rejeitadas'];
    final shown = _invoices.where((i) => filter == 0 || i.$4 == filter - 1).toList();
    return [
      PillGrid(columns: 4, narrowColumns: 2, children: [
        for (var i = 0; i < names.length; i++) Pill(label: names[i], selected: filter == i, onTap: () => setState(() => filter = i)),
      ]),
      _gap(),
      for (final inv in shown) ...[
        Panel(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(inv.$1, style: CF.body(16, weight: FontWeight.w700)),
                  Text(inv.$2, style: CF.body(13.5, color: CF.muted)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(inv.$3, style: CF.body(16, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                switch (inv.$4) {
                  0 => _chip(inv.$5, CF.green, CF.greenBg),
                  1 => _chip(inv.$5, CF.amber, CF.amberBg),
                  _ => _chip(inv.$5, CF.red, CF.redBg),
                },
              ]),
            ]),
            if (inv.$4 == 0) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                RaisedActionButton(icon: Icons.picture_as_pdf_rounded, label: 'PDF', height: 40, onPressed: _demoNotice),
                RaisedActionButton(icon: Icons.code_rounded, label: 'XML', height: 40, onPressed: _demoNotice),
              ].map((w) => SizedBox(width: 120, child: w)).toList()),
            ],
          ]),
        ),
        _gap(10),
      ],
    ];
  }

  // ---------- Configurações ----------
  List<Widget> _config() => [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFDDF3F5), borderRadius: BorderRadius.circular(14)),
          child: Text(
            'Estes dados vêm de você e do seu contador. O Léguno não escolhe o enquadramento tributário por conta própria.',
            style: CF.body(14.5, color: CF.brand, weight: FontWeight.w600, height: 1.3),
          ),
        ),
        _gap(),
        Panel(
          icon: Icons.badge_rounded,
          color: CF.brand,
          title: 'Dados de quem emite',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _field('Quem emite', 'Pessoa jurídica (CNPJ)'),
            _field('Nome ou razão social', '[nome do profissional ou da empresa]'),
            _field('CNPJ', '00.000.000/0001-00'),
            Row(children: [
              Expanded(child: _field('Município', 'São Paulo / SP')),
              const SizedBox(width: 10),
              Expanded(child: _field('Inscrição municipal', '[número]')),
            ]),
            _field('Regime tributário', 'Simples Nacional', hint: 'Confirmado com o contador'),
            _field('Código do serviço', '[informado pelo contador]'),
            RaisedActionButton(label: 'Salvar configurações', filled: CF.brand, onPressed: _demoNotice),
          ]),
        ),
      ];

  // ---------- Automação ----------
  Widget _switch(String title, String sub, bool value, ValueChanged<bool> onChanged) => Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: value,
          onChanged: onChanged,
          title: Text(title, style: CF.body(15.5, weight: FontWeight.w700)),
          subtitle: Text(sub, style: CF.body(13.5, color: CF.muted, height: 1.25)),
        ),
      );

  Widget _radio(int i, String title, String sub) => Material(
        type: MaterialType.transparency,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(issuer == i ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: issuer == i ? CF.brand : CF.grey),
          title: Text(title, style: CF.body(15.5, weight: FontWeight.w700)),
          subtitle: Text(sub, style: CF.body(13.5, color: CF.muted, height: 1.25)),
          onTap: () => setState(() => issuer = i),
        ),
      );

  List<Widget> _automacao() => [
        Panel(
          icon: Icons.bolt_rounded,
          color: CF.lap,
          title: 'Quando a nota é emitida',
          child: Column(children: [
            _switch('Emitir quando o pagamento for confirmado', AppConfig.hidePricing ? 'A nota é pedida assim que o pagamento é confirmado.' : 'A nota é pedida assim que o Asaas avisa o pagamento.',
                autoAfterPayment, (v) => setState(() => autoAfterPayment = v)),
            _switch('Emitir no fechamento do mês', 'Para quem cobra por atendimentos realizados.', autoMonthClose,
                (v) => setState(() => autoMonthClose = v)),
            _switch('Enviar a nota ao cliente por e-mail', 'O PDF e o XML seguem junto.', sendToClient,
                (v) => setState(() => sendToClient = v)),
          ]),
        ),
        _gap(),
        Panel(
          icon: Icons.verified_user_rounded,
          color: CF.brand,
          title: 'Quem emite as notas',
          child: Column(children: [
            _radio(0, 'Léguno Fiscal', 'Recomendado para este profissional.'),
            _radio(1, AppConfig.hidePricing ? 'Emissão própria da cobrança' : 'Emissão própria do Asaas', 'Fica desligada para não duplicar nota.'),
          ]),
        ),
        _gap(),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: CF.amberBg, borderRadius: BorderRadius.circular(14)),
          child: Text('Só um emissor trabalha por vez. Se o mesmo aviso de pagamento chegar duas vezes, a nota sai uma vez só.',
              style: CF.body(14, color: CF.amber, weight: FontWeight.w600, height: 1.3)),
        ),
      ];

  // ---------- Planos ----------
  Widget _plan(String name, String price, String notes, {bool current = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(name, style: CF.body(18, weight: FontWeight.w800))),
              if (current) _chip('Plano atual', CF.green, CF.greenBg),
            ]),
            const SizedBox(height: 4),
            Text.rich(TextSpan(children: [
              TextSpan(text: 'R\$ $price', style: CF.score(30)),
              TextSpan(text: '  por mês', style: CF.body(14, color: CF.muted)),
            ])),
            Text('Até $notes notas por mês', style: CF.body(14.5, color: CF.muted)),
            const SizedBox(height: 10),
            RaisedActionButton(
              label: current ? 'Seu plano atual' : 'Mudar para este',
              filled: current ? null : CF.brand,
              onPressed: current ? () {} : _demoNotice,
            ),
          ]),
        ),
      );

  List<Widget> _planos() => [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: CF.amberBg, borderRadius: BorderRadius.circular(12)),
          child: Text('Valores de exemplo, ainda a definir. O Léguno Fiscal é opcional e separado da assinatura do app.',
              style: CF.body(14, color: CF.amber, weight: FontWeight.w600, height: 1.3)),
        ),
        _gap(),
        _plan('Fiscal Essencial', '19,90', '20'),
        _plan('Fiscal Plus', '29,90', '50', current: true),
        _plan('Fiscal Pro', '49,90', '150'),
      ];

  // ---------- Fechar o mês ----------
  List<Widget> _fechar() {
    const dates = ['Seg, 03/11', 'Qua, 05/11', 'Sex, 07/11', 'Seg, 10/11', 'Qua, 12/11', 'Sex, 14/11', 'Seg, 17/11', 'Qua, 19/11'];
    return [
      Panel(
        icon: Icons.fact_check_rounded,
        color: CF.brand,
        title: 'Bruno Lima · novembro',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Treino funcional · aulas realizadas', style: CF.body(14, color: CF.muted)),
          const SizedBox(height: 6),
          for (final d in dates)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: CF.green, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(d, style: CF.body(15.5, weight: FontWeight.w600))),
                Text('R\$ 250,00', style: CF.body(15.5)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              const Icon(Icons.cancel_rounded, color: CF.grey, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Sex, 21/11 · cancelada', style: CF.body(15.5, color: CF.muted))),
              Text('fora da conta', style: CF.body(14, color: CF.muted)),
            ]),
          ),
        ]),
      ),
      _gap(),
      Panel(
        child: Row(children: [
          Expanded(child: Text('8 aulas × R\$ 250,00', style: CF.body(15.5, weight: FontWeight.w600))),
          Text('R\$ 2.000,00', style: CF.score(28)),
        ]),
      ),
      _gap(),
      RaisedActionButton(label: 'Aprovar e gerar cobrança', filled: CF.brand, onPressed: _demoNotice),
      const SizedBox(height: 8),
      Text('A nota é pedida depois do pagamento, como você configurou.',
          textAlign: TextAlign.center, style: CF.body(13.5, color: CF.muted)),
    ];
  }
}
