# Coach Flow Profissional — Auditoria e critérios de aceite do piloto 1.0

Data de início: 2026-10-22
Escopo: exclusivamente flutter_profissional/. Não alterar Coach Flow Pessoal.
Estado: AUDITORIA EM ANDAMENTO — NÃO APROVADO PARA DADOS REAIS.

## Achados confirmados no código

### P0 — bloqueadores
- [ ] A aplicação sem SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY inicia apenas em demonstração. Não existe comprovação de banco exclusivo do Coach Flow conectado na Vercel.
- [ ] O modo demo usa DemoLedger singleton e dados fictícios em memória; não é persistência.
- [ ] A agenda real consultava workspace_members/appointments/clients, mas ProfessionalRepository usa cf_clients/cf_appointments/cf_billing. Corrigida a consulta da agenda em 7251e2b8 para usar cf_appointments e cf_clients, filtrando owner_id. **A correção ainda exige testes contra um banco exclusivo.**
- [ ] Validar RLS e isolamento com dois usuários distintos para cf_clients, cf_appointments e cf_billing; filtro no Flutter não substitui políticas RLS.
- [ ] Validar criação, edição, exclusão, login/logout, recuperação de senha, retorno à sessão e recarga da página em dispositivos diferentes.
- [ ] Confirmar backups e restauração do banco; sem teste de restore não declarar backup suficiente.
- [ ] Validar ambiente Production separado de Preview, domínio estável e proteção de segredos.

### P1 — qualidade funcional
- [ ] Fluxo ponta a ponta: cliente → agendamento → realizado/cancelado → cobrança → pago → relatório; conciliar cálculos e status.
- [ ] Duração de atendimento não existe no contrato atual de cf_appointments: a agenda não deve presumir fim ou detectar conflito sem modelagem adicional.
- [ ] Erros de rede, sessão expirada, entrada inválida, concorrência e operação repetida (idempotência).
- [ ] Testar interface em iPhone Safari, Android Chrome e desktop; verificar números de calendário, botões, contraste, teclado, rolagem e navegação.
- [ ] Remover botões fictícios ou rotular explicitamente recursos não implementados, incluindo integração Apple/Google.
- [ ] Revisar política de privacidade, consentimento, retenção e exclusão de dados (LGPD).

### P2 — pós-piloto
- [ ] Sincronização bidirecional Google Calendar e Apple EventKit com backend seguro.
- [ ] Monitoramento de erros, alertas, métricas de uso e suporte.
- [ ] Otimização de performance, acessibilidade e testes automatizados.

## Matriz de aceite do piloto
1. Profissional A não lê, altera ou exclui dados do profissional B, inclusive usando requests diretos.
2. Cliente cadastrado continua presente após logout/login e em outro navegador.
3. Atendimento criado aparece no calendário e na apuração correta.
4. Cobrança paga não é duplicada em refresh/reenvio.
5. Falha de conexão não causa perda silenciosa de dados.
6. Fluxos principais funcionam em Safari iOS e Chrome Android.
7. Nenhuma funcionalidade de demonstração é confundida com recurso operacional.
8. Build de produção e ambiente de dados são separados, com rollback e restauração testados.

## Registro de mudanças
- 2026-10-22: corrigida a divergência de esquema da agenda em flutter_profissional/lib/agenda_repository.dart; o código consulta cf_appointments e cf_clients do mesmo owner. Ainda não foi validado em banco.

## Decisões pendentes
- Autorizar/criar projeto Supabase exclusivo Coach Flow Profissional; não reaproveitar 'empresa-em-movimento' nem 'Alem das curvas'.
- Definir profissionais participantes do piloto e termos de uso.
- Definir duração padrão do atendimento e regra de conflitos.
- Definir domínio de produção e fluxo de suporte.

## Próxima sequência técnica
1. Verificar esquema SQL existente e configuração do build, sem expor credenciais.
2. Preparar migrações idempotentes e políticas RLS no repositório, revisar com testes.
3. Provisionar backend exclusivo após confirmação da organização/custos.
4. Configurar variáveis no Vercel e executar testes com contas fictícias separadas.
5. Testar web mobile, corrigir P0/P1 e só então aprovar produção.
