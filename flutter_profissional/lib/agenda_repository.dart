import 'package:supabase_flutter/supabase_flutter.dart';

class AgendaAppointment {
  final String id;
  final String clientName;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  const AgendaAppointment({
    required this.id, required this.clientName,
    required this.startsAt, required this.endsAt, required this.status,
  });
}

/// Usa as mesmas tabelas e a mesma identidade do módulo de clientes.
/// RLS no banco é obrigatória; o filtro por owner_id não a substitui.
class AgendaRepository {
  final SupabaseClient client;
  const AgendaRepository(this.client);

  Future<List<AgendaAppointment>> forPeriod(DateTime start, DateTime end) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Faça login para consultar a agenda.');
    }
    final rows = await client.from('cf_appointments')
        .select('id,starts_at,status,cf_clients(name)')
        .eq('owner_id', userId)
        .gte('starts_at', start.toUtc().toIso8601String())
        .lt('starts_at', end.toUtc().toIso8601String())
        .order('starts_at', ascending: true)
        .limit(1000);
    return (rows as List).map((row) {
      final r = Map<String, dynamic>.from(row as Map);
      final nested = r['cf_clients'];
      final name = nested is Map ? nested['name']?.toString() : null;
      final startAt = DateTime.parse(r['starts_at'] as String).toLocal();
      return AgendaAppointment(
        id: r['id'].toString(),
        clientName: name ?? 'Cliente não vinculado',
        startsAt: startAt,
        // O esquema atual não registra a duração. Não inventar horários.
        endsAt: startAt,
        status: (r['status'] ?? 'Agendada').toString(),
      );
    }).toList();
  }
}
