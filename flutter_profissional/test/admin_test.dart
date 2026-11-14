import 'package:coachflow_profissional/admin/admin_account.dart';
import 'package:coachflow_profissional/admin/admin_api.dart';
import 'package:coachflow_profissional/admin/admin_screen.dart';
import 'package:coachflow_profissional/admin/admin_widgets.dart';
import 'package:coachflow_profissional/ui/cf_theme.dart';
import 'package:coachflow_profissional/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contas e números inventados: nada aqui é de gente de verdade.
Map<String, dynamic> _acc(String id, String email,
        {String status = 'trialing', String state = 'trialing', int trialDays = 10, bool founder = false, bool internal = false}) =>
    {
      'owner_id': id,
      'email': email,
      'created_at': DateTime.now().subtract(const Duration(days: 12)).toIso8601String(),
      'last_sign_in': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'profession': 'Psicóloga',
      'plan': 'profissional',
      'status': status,
      'state': state,
      'trial_ends_at': DateTime.now().add(Duration(days: trialDays)).toIso8601String(),
      'current_period_end': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'founder': founder,
      'internal': internal,
      'cycle': 'monthly',
      'clients': 7,
      'platform': 'iOS',
      'last_seen': null,
    };

final _calls = <String>[];

Future<dynamic> _fake(String fn, [Map<String, dynamic>? p]) async {
  _calls.add(fn);
  switch (fn) {
    case 'cf_admin_overview':
      return {
        'total': 12,
        'new_period': 4,
        'trialing': 5,
        'trial_ending': 2,
        'paying': 6,
        'mrr': 359.4,
        'late': 1,
        'late_amount': 59.9,
        'active_week': 8,
        'weekly': [
          for (var i = 0; i < 5; i++) {'week': DateTime(2026, 10, 12 + 7 * i).toIso8601String().substring(0, 10), 'n': i}
        ],
        'funnel': {'registered': 12, 'with_client': 9, 'billed': 6, 'paid': 6},
      };
    case 'cf_admin_funnel':
      return {'registered': 12, 'with_client': 9, 'billed': 6, 'paid': 6};
    case 'cf_admin_accounts':
      return [
        _acc('1', 'ana@exemplo.com'),
        _acc('2', 'bruno@exemplo.com', status: 'active', state: 'active', founder: true),
        _acc('3', 'carla@exemplo.com', status: 'past_due', state: 'grace'),
        _acc('4', 'interna@exemplo.com', internal: true),
      ];
    case 'cf_admin_account_detail':
      return {
        'account': _acc('1', 'ana@exemplo.com'),
        'usage': [
          {'event': 'app_aberto', 'day': '2026-11-13', 'platform': 'iOS'},
          {'event': 'app_aberto', 'day': '2026-11-12', 'platform': 'iOS'},
          {'event': 'cliente_novo', 'day': '2026-11-12', 'platform': 'iOS'},
        ],
        'support': [
          {'message': 'Como mudo a chave Pix?', 'platform': 'iOS', 'app_version': '1.0.0', 'created_at': '2026-11-13T12:00:00Z'}
        ],
        'log': [
          {'action': 'estender_teste', 'detail': {'dias': 7}, 'created_at': '2026-11-13T12:00:00Z'}
        ],
      };
    case 'cf_admin_finance':
      return {
        'source': 'estimate',
        'mrr': 359.4,
        'received_month': 0,
        'to_receive_month': 0,
        'overdue': 0,
        'canceled_month': 0,
        'months': [],
        'recent': [],
      };
    case 'cf_admin_support':
      return [
        {'owner_id': '1', 'email': 'ana@exemplo.com', 'message': 'Preciso de ajuda', 'platform': 'web', 'app_version': null, 'created_at': '2026-11-13T12:00:00Z'}
      ];
    case 'cf_admin_log_list':
      return [
        {'action': 'cortesia', 'detail': {'ligado': true}, 'created_at': '2026-11-13T12:00:00Z', 'admin': 'dono@exemplo.com', 'target': 'ana@exemplo.com'}
      ];
    default:
      return {};
  }
}

void main() {
  setUp(() {
    CF.useGoogleFonts = false;
    _calls.clear();
  });

  test('situação da conta em palavras simples', () {
    final now = DateTime.now();
    String look(Map<String, dynamic> j) => accountLook(AdminAccount.fromJson(j), now).$1;
    expect(look(_acc('1', 'a@x.com', trialDays: 10)), 'Teste · 10 dias');
    expect(look(_acc('1', 'a@x.com', trialDays: 0)), contains('último dia'));
    expect(look(_acc('1', 'a@x.com', status: 'active', state: 'active')), 'Pagante');
    expect(look(_acc('1', 'a@x.com', status: 'courtesy', state: 'courtesy')), 'Cortesia');
    expect(look(_acc('1', 'a@x.com', status: 'past_due', state: 'grace')), startsWith('Atraso'));
    expect(look(_acc('1', 'a@x.com', status: 'trialing', state: 'read_only')), 'Somente leitura');
  });

  test('último acesso e nomes de ações', () {
    final now = DateTime(2026, 11, 14, 12);
    expect(sinceText(null, now), 'nunca');
    expect(sinceText(DateTime(2026, 11, 14, 8), now), 'hoje');
    expect(sinceText(DateTime(2026, 11, 13, 23), now), 'ontem');
    expect(sinceText(DateTime(2026, 11, 10), now), 'há 4 dias');
    expect(actionText('estender_teste', {'dias': 14}), 'Estendeu o teste em 14 dias');
    expect(actionText('cortesia', {'ligado': false}), 'Tirou a cortesia');
    expect(AdminAccount.fromJson(_acc('1', 'a@x.com')).platformLabel, 'iPhone');
  });

  for (final size in const [Size(390, 900), Size(1400, 1000)]) {
    testWidgets('painel: todas as abas em ${size.width.toInt()} px', (tester) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(MaterialApp(
        theme: CF.theme(),
        home: Scaffold(
          body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: AdminScreen(api: AdminApi(_fake))),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Em teste grátis'), findsOneWidget);
      expect(find.text('ana@exemplo.com'), findsWidgets);

      for (final tab in ['Contas', 'Funil', 'Financeiro', 'Suporte', 'Registro']) {
        await tester.tap(find.widgetWithText(Pill, tab));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }
      expect(find.textContaining('Estendeu') .evaluate().length + find.textContaining('Deu cortesia').evaluate().length, greaterThan(0));
      expect(_calls, containsAll(['cf_admin_overview', 'cf_admin_accounts', 'cf_admin_funnel', 'cf_admin_finance', 'cf_admin_support', 'cf_admin_log_list']));
    });
  }

  testWidgets('abrir a ficha de uma conta mostra uso, suporte e ações', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    await tester.pumpWidget(MaterialApp(
      theme: CF.theme(),
      home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: AdminScreen(api: AdminApi(_fake)))),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.widgetWithText(Pill, 'Contas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('ana@exemplo.com').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Abriu o app'), findsOneWidget);
    expect(find.text('Estender teste'), findsOneWidget);
    expect(find.text('Marcar fundador'), findsOneWidget);
    expect(find.textContaining('Como mudo a chave Pix?'), findsOneWidget);
  });

  testWidgets('estender o teste chama o banco com os dias escolhidos', (tester) async {
    final sent = <Map<String, dynamic>>[];
    Future<dynamic> rpc(String fn, [Map<String, dynamic>? p]) async {
      if (fn == 'cf_admin_extend_trial') sent.add(p!);
      return _fake(fn, p);
    }

    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    await tester.pumpWidget(MaterialApp(
      theme: CF.theme(),
      home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: AdminScreen(api: AdminApi(rpc)))),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.widgetWithText(Pill, 'Contas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('ana@exemplo.com').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Estender teste'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('14 dias'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(sent, hasLength(1));
    expect(sent.first['p_days'], 14);
    expect(sent.first['p_owner'], '1');
  });

  testWidgets('erro do banco aparece em palavras simples, com botão para tentar de novo', (tester) async {
    Future<dynamic> rpc(String fn, [Map<String, dynamic>? p]) async => throw AdminError('Acesso negado.');
    await tester.binding.setSurfaceSize(const Size(900, 900));
    await tester.pumpWidget(MaterialApp(
      theme: CF.theme(),
      home: Scaffold(body: SingleChildScrollView(child: AdminScreen(api: AdminApi(rpc)))),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Acesso negado.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });
}
