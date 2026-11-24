import 'package:coachflow_profissional/billing/billing_engine.dart';
import 'package:coachflow_profissional/billing/billing_store.dart';
import 'package:coachflow_profissional/config.dart';
import 'package:coachflow_profissional/data/cloud_sink.dart';
import 'package:coachflow_profissional/data/subscription.dart';
import 'package:coachflow_profissional/profile/profession_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _QuietSink implements CloudSink {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// iPhone/iPad: só a agenda, para todos (exigência da Apple). Android e web seguem a assinatura.
void main() {
  final paid = SubscriptionInfo(plan: 'profissional', status: 'active', state: 'active', pro: true);

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final store = BillingStore.instance;
    store.onLocked = null;
    store.setSubscription(null);
    store.seed(professionById('personal'), BillingModel.perSession);
  });

  test('iPhone com assinatura paga: agenda liberada, cobrança, financeiro e Pro travados', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AppConfig.agendaOnly, isTrue);
    final store = BillingStore.instance;
    store.seed(professionById('personal'), BillingModel.perSession);
    store.sink = _QuietSink();
    String? blocked;
    store.onLocked = (m) => blocked = m;
    store.setSubscription(paid);
    expect(store.isFree, isTrue);
    expect(store.isPro, isFalse);
    expect(store.canEdit, isTrue);
    final p = store.activePlans.first;
    expect(store.saveLesson(p.id, store.today, const LessonRecord(status: LessonStatus.cancelled)), isNull);
    expect(blocked, isNull);
    final before = store.received(p.id);
    store.addPayment(p.id, PaymentEntry(amount: 50, date: store.today, method: 'Pix'));
    expect(store.received(p.id), before);
    expect(blocked, contains('não está disponível neste app'));
    expect(blocked!.toLowerCase().contains('plano'), isFalse);
  });

  test('Android com assinatura paga: tudo liberado', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AppConfig.agendaOnly, isFalse);
    final store = BillingStore.instance;
    store.seed(professionById('personal'), BillingModel.perSession);
    store.setSubscription(paid);
    expect(store.isFree, isFalse);
    expect(store.isPro, isTrue);
  });
}
