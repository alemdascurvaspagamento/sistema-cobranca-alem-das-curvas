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

class AgendaRepository {
  final SupabaseClient client;
  const AgendaRepository(this.client);

  Future<String> workspaceForCurrentUser() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Faça login para consultar a agenda.');
    final member = await client.from('workspace_members')
        .select('workspace_id')
        .eq('user_id', user.id)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();
    final workspaceId = member?['workspace_id'] as String?;
    if (workspaceId == null) {
      throw StateError('Nenhum espaço de trabalho ativo encontrado.');
    }
    return workspaceId;
  }

  Future<List<AgendaAppointment>> forPeriod(DateTime start, DateTime end) async {
    final workspace = await workspaceForCurrentUser();
    final rows = await client.from('appointments')
        .select('id,starts_at,ends_at,status,clients(display_name)')
        .eq('workspace_id', workspace)
        .gte('starts_at', start.toUtc().toIso8601String())
        .lt('starts_at', end.toUtc().toIso8601String())
        .order('starts_at', ascending: true)
        .limit(1000);
    return (rows as List).map((row) {
      final r = row as Map<String, dynamic>;
      final nested = r['clients'];
      final name = nested is Map ? nested['display_name']?.toString() : null;
      return AgendaAppointment(
        id: r['id'] as String,
        clientName: name ?? 'Cliente não vinculado',
        startsAt: DateTime.parse(r['starts_at'] as String).toLocal(),
        endsAt: DateTime.parse(r['ends_at'] as String).toLocal(),
        status: (r['status'] ?? 'Agendado').toString(),
      );
    }).toList();
  }
}
