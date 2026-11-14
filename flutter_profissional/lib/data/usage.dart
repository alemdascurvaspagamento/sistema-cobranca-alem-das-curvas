import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registro de uso: guarda só o nome da função usada e o dia.
/// Nunca leva nomes, valores ou telefones. Serve para saber o que melhorar.
/// Falhas são ignoradas: medir nunca atrapalha o uso do app.
class Usage {
  Usage._();

  static final _sent = <String>{};

  static void clear() => _sent.clear();

  /// Eventos usados: app_aberto, cliente_novo, cliente_importado, cobranca_whatsapp,
  /// agendamento_online_ligado, resumo_manha_ligado, relatorios_aberto, pedido_remarcacao.
  static void track(String event) {
    final day = DateTime.now().toIso8601String().substring(0, 10);
    if (!_sent.add('$event|$day')) return;
    try {
      final db = Supabase.instance.client;
      final uid = db.auth.currentUser?.id;
      if (uid == null) {
        _sent.remove('$event|$day');
        return;
      }
      db.from('cf_usage_events').upsert({
        'owner_id': uid,
        'event': event,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      }, onConflict: 'owner_id,event,day', ignoreDuplicates: true).then((_) {}).catchError((Object _) {});
    } catch (_) {
      _sent.remove('$event|$day');
    }
  }
}
