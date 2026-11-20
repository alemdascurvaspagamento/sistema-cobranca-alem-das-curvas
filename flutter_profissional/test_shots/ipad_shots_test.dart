// Gera as telas do app em tamanho de iPad (13 pol., 2048 x 2732) para a App Store.
// Não faz parte dos testes normais: roda só no fluxo "Capturas do iPad".
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coachflow_profissional/billing/billing_engine.dart';
import 'package:coachflow_profissional/billing/billing_store.dart';
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
  const logical = Size(1024, 1366); // 2048 x 2732 com densidade 2
  final out = Directory('shots')..createSync(recursive: true);

  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT']!;
    await _font('MaterialIcons', ['$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    final barlow = [for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) 'fonts/Barlow-$w.ttf'];
    // Também com os nomes das fontes padrão (botões e textos sem fonte definida).
    for (final family in ['Barlow', 'FlutterTest', 'Ahem', 'Roboto', 'CupertinoSystemText', 'CupertinoSystemDisplay', '.AppleSystemUIFont', '.SF Pro Text', '.SF UI Text']) {
      await _font(family, barlow);
    }
  });

  setUp(() => CF.useGoogleFonts = false);

  final shots = <String, IconData?>{
    '1-inicio': null,
    '2-agenda': Icons.calendar_month_rounded,
    '3-cobrancas': Icons.receipt_long_rounded,
    '4-clientes': Icons.groups_rounded,
    '5-financeiro': Icons.account_balance_wallet_rounded,
    '6-relatorios': Icons.insights_rounded,
  };

  for (final e in shots.entries) {
    testWidgets('iPad ${e.key}', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final original = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('ink splashes may be invisible')) return;
        original?.call(d);
      };
      try {
        BillingStore.instance.seed(professionById('personal'), BillingModel.perSession);
        tester.view.physicalSize = logical * 2;
        tester.view.devicePixelRatio = 2;
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
            home: const DefaultTextStyle(
              style: TextStyle(fontFamily: 'Barlow'),
              child: CoachFlowShell(),
            ),
          ),
        ));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        if (e.value != null) {
          final rail = find.byType(NavigationRail);
          final bar = find.byType(NavigationBar);
          final scope = rail.evaluate().isNotEmpty ? rail : bar;
          await tester.tap(find.descendant(of: scope, matching: find.byIcon(e.value!)).first);
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 300));
          }
        }
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final img = await boundary.toImage(pixelRatio: 2);
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/${e.key}.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      } finally {
        FlutterError.onError = original;
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    });
  }
}
