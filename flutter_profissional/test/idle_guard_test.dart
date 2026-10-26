import 'package:coachflow_profissional/ui/idle_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sai depois do tempo sem uso', (tester) async {
    var fired = 0;
    await tester.pumpWidget(MaterialApp(
      home: IdleGuard(
        timeout: const Duration(minutes: 30),
        onTimeout: () => fired++,
        child: const Scaffold(body: Text('app')),
      ),
    ));
    await tester.pump(const Duration(minutes: 29));
    expect(fired, 0);
    await tester.pump(const Duration(minutes: 2));
    expect(fired, 1);
    await tester.pump(const Duration(minutes: 40));
    expect(fired, 1);
  });

  testWidgets('desligado não sai', (tester) async {
    var fired = 0;
    await tester.pumpWidget(MaterialApp(
      home: IdleGuard(enabled: false, onTimeout: () => fired++, child: const Scaffold(body: Text('app'))),
    ));
    await tester.pump(const Duration(hours: 2));
    expect(fired, 0);
  });
}
