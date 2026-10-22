# Coach Flow Profissional — sincronização bidirecional de calendários

## Estado
Fase 1: interface de configuração e modelo de privacidade preparados. **Nenhum provedor está conectado, nenhum dado é importado/exportado.** Não utilizar dados de clientes reais até autenticação, persistência, auditoria e testes estarem concluídos.

## Provedores
- Google Calendar: OAuth 2.0 com PKCE, escopos mínimos, consentimento, tokens armazenados somente no backend cifrados; nunca expor refresh token no Flutter. Sync incremental com nextSyncToken, paginação, re-sincronização quando receber 410; webhooks apenas para disparar reconciliação.
- Apple Calendar: EventKit no aplicativo nativo iOS/iPadOS, com permissão de acesso completo para leitura + escrita. **EventKit não funciona na aplicação Flutter Web**. A sincronização entre dispositivos requer uma estratégia separada (ex.: iCloud CalDAV com credenciais e requisitos próprios), a ser avaliada; não alegar sincronização iCloud via EventKit no web.
- Android: acesso ao calendário local via API nativa com permissões de leitura/escrita, ou Google Calendar API via OAuth para sync de conta em qualquer plataforma. Não duplicar o mesmo evento ao conectar Google e calendário local simultaneamente.

## Privacidade (padrões obrigatórios)
- Importar eventos externos como busy-only: persistir apenas início, fim, timezone, disponibilidade e ID opaco de origem; não persistir título, descrição, participantes, localização ou anexos de eventos pessoais.
- Não exportar nome do cliente por padrão: usar 'Atendimento • Coach Flow'. Exportar detalhes somente com consentimento explícito e avaliação de privacidade/LGPD.
- Não editar, excluir ou mover eventos pessoais importados; alterações originadas no Coach Flow devem afetar apenas eventos criados/vinculados pelo Coach Flow.
- Excluir dados sincronizados e revogar tokens ao desconectar, com mecanismo de reautorização.
- Evitar conflitos com eventos de dia inteiro, fuso horário, horário de verão, eventos recorrentes, exceções e eventos cancelados.
- Identificar o originador e versionar cada mudança para evitar loops de eco.

## Modelo de dados proposto (não aplicado)
- calendar_connections(id, user_id, provider, external_calendar_id, access_scope, status, sync_cursor, last_synced_at)
- calendar_event_links(id, user_id, appointment_id, connection_id, external_event_id, external_etag, last_origin, last_synced_at)
- calendar_busy_blocks(id, user_id, connection_id, external_event_key_hash, starts_at, ends_at, timezone, is_all_day)
- calendar_sync_jobs(id, user_id, connection_id, state, attempts, error_code, started_at, finished_at)
- Segredos OAuth separados de tabelas acessíveis ao cliente; tabelas com RLS por auth.uid() e política de ownership para SELECT/INSERT/UPDATE/DELETE.

## Regras de reconciliação
1. Criar/editar atendimento no Coach Flow => gravar primeiro no banco, enfileirar operação idempotente, aplicar apenas ao evento externo gerenciado pelo Coach Flow.
2. Mudança no evento externo gerenciado => reconciliar horário e status com o atendimento, registrar origem; em conflito simultâneo, não sobrescrever silenciosamente: sinalizar ao usuário.
3. Mudança em evento pessoal externo => atualizar somente busy block, sem detalhes e sem alterar atendimento automaticamente.
4. Cancelamento => marcar link e tratar tombstone; jamais excluir evento externo que não foi criado pelo Coach Flow.
5. Sincronização recorrente + acionamento por webhook quando disponível; renovação de credenciais e revogação verificadas no backend.

## Etapas restantes
1. Escolher/autorizar backend próprio do Coach Flow (não reutilizar Supabase de outros projetos), aplicar schema e RLS, testar isolamento entre usuários.
2. Configurar OAuth Google, URL de retorno e segredo no servidor, implementar conexão/desconexão, tokens e sync inicial/incremental.
3. Implementar engine de conflitos, fila idempotente, telemetria sem dados privados, testes de recorrência, fusos e exclusões.
4. Implementar plugin/bridge EventKit para builds nativos iOS, permissão granular e testes em simulador/dispositivo; Android Calendar Provider, se desejado.
5. Testar a integração de ponta a ponta antes de habilitar botões Conectar.

## Referências
- Google Calendar incremental sync: https://developers.google.com/workspace/calendar/api/guides/sync
- Apple EventKit: https://developer.apple.com/documentation/eventkit/accessing-the-event-store
- Supabase Edge Functions auth: https://supabase.com/docs/guides/functions/auth
