import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coachflow_profissional/main.dart';

void main() {
  testWidgets('Shows configuration instructions without credentials', (tester) async {
    await tester.pumpWidget(const CoachFlowApp());
    expect(find.textContaining('Configure SUPABASE_URL'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
