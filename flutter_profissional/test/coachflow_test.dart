import 'package:coachflow_profissional/main.dart';
import 'package:coachflow_profissional/ui/cf_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => CF.useGoogleFonts = false);

  testWidgets('entrada mostra o convite para experimentar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const CoachFlowApp());
    expect(find.text('Experimentar agora'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('experimentar leva à escolha de profissão', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const CoachFlowApp());
    await tester.tap(find.text('Experimentar agora'));
    await tester.pumpAndSettle();
    expect(find.text('Qual é a sua profissão?'), findsOneWidget);
  });
}
