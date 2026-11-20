// Gera telas de celular do app e do Léguno Fiscal (demonstração) para apresentações.
// Não faz parte dos testes normais: roda só no fluxo "Capturas do iPad".
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coachflow_profissional/billing/billing_engine.dart';
import 'package:coachflow_profissional/billing/billing_store.dart';
import 'package:coachflow_profissional/fiscal/fiscal_demo.dart';
import 'package:coachflow_profissional/main.dart';
import 'package:coachflow_profissional/profile/profession_profile.dart';
import 'package:coachflow_profissional/ui/cf_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(File(f).readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}

void main() {
  const logical = Size(430, 932); // celular, densidade 3
  final out = Directory('shots_extra')..createSync(recursive: true);

  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT']!;
    await _font('MaterialIcons', ['$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    final barlow = [for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) 'fonts/Barlow-$w.ttf'];
    // Também com os nomes das fontes padrão (botões e textos sem fonte definida).
    for (final family in ['Barlow', 'FlutterTest', 'Ahem', 'Roboto', 'CupertinoSystemText', 'CupertinoSystemDisplay', '.AppleSystemUIFont', '.SF Pro Text', '.SF UI Text']) {
      await _font(family, barlow);
    }
    await _font('BarlowCondensed', [for (final w in ['Medium', 'SemiBold', 'Bold', 'ExtraBold']) 'fonts/BarlowCondensed-$w.ttf']);
  });

  setUp(() {
    CF.useGoogleFonts = false;
    CF.testFontFamily = 'Barlow';
    CF.testCondensedFamily = 'BarlowCondensed';
  });

  Future<void> shoot(WidgetTester tester, String name, Widget home, Future<void> Function()? act) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('ink splashes may be invisible')) return;
      original?.call(d);
    };
    try {
      BillingStore.instance.seed(professionById('personal'), BillingModel.perSession);
      tester.view.physicalSize = logical * 3;
      tester.view.devicePixelRatio = 3;
      final key = GlobalKey();
      final base = CF.theme();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: base.copyWith(
            textTheme: base.textTheme.apply(fontFamily: 'Barlow'),
            primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Barlow'),
          ),
          home: DefaultTextStyle(style: const TextStyle(fontFamily: 'Barlow'), child: home),
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      if (act != null) {
        await act();
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
      }
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 3);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    } finally {
      FlutterError.onError = original;
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  }

  final app = <String, IconData?>{
    'cel-1-inicio': null,
    'cel-2-agenda': Icons.calendar_month_rounded,
    'cel-3-cobrancas': Icons.receipt_long_rounded,
  };
  for (final e in app.entries) {
    testWidgets('Celular ${e.key}', (tester) async {
      await shoot(tester, e.key, const CoachFlowShell(), e.value == null
          ? null
          : () async {
              final rail = find.byType(NavigationRail);
              final bar = find.byType(NavigationBar);
              final scope = rail.evaluate().isNotEmpty ? rail : bar;
              await tester.tap(find.descendant(of: scope, matching: find.byIcon(e.value!)).first);
            });
    });
  }

  final fiscal = <String, String?>{
    'fiscal-1-painel': null,
    'fiscal-2-emitir': 'Emitir nota',
    'fiscal-3-historico': 'Histórico',
    'fiscal-4-automacao': 'Automação',
    'fiscal-5-fechar': 'Fechar o mês',
    'fiscal-6-planos': 'Planos',
  };
  for (final e in fiscal.entries) {
    testWidgets('Fiscal ${e.key}', (tester) async {
      await shoot(tester, e.key, const FiscalDemoScreen(), e.value == null
          ? null
          : () async {
              await tester.tap(find.text(e.value!).first);
            });
    });
  }
}
