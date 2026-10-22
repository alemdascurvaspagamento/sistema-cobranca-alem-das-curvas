# Inventário de dependências e plano de preservação — 22/10/2026

**Somente leitura.** Nenhum banco foi pausado, excluído, migrado ou modificado. Nenhum backup restaurável foi criado até o momento.

## Fontes verificadas
- Supabase: organização Alem das curvas; projetos `yjpxjzgvshaabjpdpbsc` (Alem das curvas, us-west-2) e `tdygfkeeavsqaliwxujl` (empresa-em-movimento, sa-east-1), ambos ACTIVE_HEALTHY.
- GitHub: repositórios `alemdascurvaspagamento/sistema-cobranca-alem-das-curvas` e `alemdascurvaspagamento/empresa-em-movimento`.
- Vercel: projetos `sistema-cobranca-alem-das-curvas` e `empresa-em-movimento` identificados na equipe; projeto Flutter Profissional exige confirmar escopo/ambiente separadamente.
- Não foram exibidos valores de segredos ou chaves privadas.

## Dependências comprovadas
1. **Coach Flow Pessoal:** `index.html` e `vercel.json` na branch main referenciam diretamente `https://yjpxjzgvshaabjpdpbsc.supabase.co`. Usa Supabase Auth. Pausar esse projeto quebra ao menos o login/acesso à API do sistema pessoal.
2. **Banco Alem das curvas:** além de dados pessoais, contém tabelas `workspaces`, `workspace_members`, `professional_profiles`, `clients`, `appointments`, `charges` e outras do protótipo profissional. Não assumir que todas estejam desativadas.
3. **Edge Function `coachflow-api`:** ativa, versão 3, no projeto antigo; consumidores e endpoints ainda não auditados. Precisa inspecionar código e chamadas antes de pausar.
4. **Empresa em Movimento:** repositório separado usa Supabase Auth, serviço administrativo e APIs; Vercel tem variáveis SUPABASE_URL, NEXT_PUBLIC_SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY configuradas. Não foi confirmado se o URL aponta para o projeto próprio ou para o antigo porque não foram lidos valores de segredos. Não modificar.
5. **Coach Flow Profissional Flutter:** branch `flutter-profissional-foundation-20261019`, configuração `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` via dart-define; sem configuração usa demonstração. Código real usa `cf_clients`, `cf_appointments`, `cf_billing`; essas tabelas não aparecem no inventário atual do projeto antigo. Exige backend exclusivo.

## Volume aproximado no banco antigo
- `audit_log`: ~76,5 mil linhas (estimativa PostgreSQL)
- `aulas`: 623; `cobrancas`: 83; `despesas`: 69; `pagamentos`: 17
- `auth.users`: 1; `storage.objects`: 0; `storage.buckets`: 0
- As contagens estimadas não são prova de integridade nem backup.

## Segurança observada (sem alterações)
- Supabase Security Advisor sinaliza `public.get_my_athlete_intelligence()` como SECURITY DEFINER executável por autenticados: revisar autorização e necessidade; https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- Proteção contra senhas vazadas desativada: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- RLS está habilitado nas tabelas públicas listadas, mas as políticas e testes entre usuários ainda não foram auditados.

## Plano seguro de backup (pendente de execução)
1. Mapear todas as dependências: Edge Function, URLs, domínios, Vercel Production/Preview, tarefas agendadas, clientes locais, integrações e usuários ativos.
2. Criar exportação **completa** PostgreSQL com `pg_dump` em formato custom, incluindo esquemas, dados, funções, triggers, policies e migrações; guardar criptografada fora do GitHub, com controle de acesso.
3. Exportar metadados de Auth e identidades com método oficialmente suportado; senhas/hashes e sessões exigem procedimento específico. Salvar configurações de Auth (providers, URLs de redirect, SMTP) sem divulgar segredos.
4. Exportar configurações de Edge Functions, nomes de secrets (nunca seus valores em relatórios), políticas e buckets; confirmar se há dados fora do banco.
5. Verificar arquivo, checksum SHA-256, contagens por tabela e restaurar **em ambiente descartável e isolado**, testando login e fluxo principal com dados anonimizados quando possível.
6. Planejar alternativa de continuidade para Coach Flow Pessoal (manter o projeto ou migrar serviço inteiro, não apenas tabelas); testar novos endpoints, Auth e integrações.
7. Somente após aceite explícito do usuário e plano de reversão, pausar o projeto antigo para liberar uma vaga Free.
8. Criar o projeto Coach Flow Profissional na mesma organização, em `sa-east-1`, desde que o Supabase confirme custo zero; aplicar esquema e RLS específicos; executar testes de isolamento e persistência.

## Critérios para NÃO pausar
- Backup sem restauração validada.
- Dependências externas ou Edge Function sem inventário.
- Sistema pessoal ainda utilizado sem migração testada.
- Necessidade de manter autenticação ou URL antiga.
- Falta de confirmação explícita do proprietário.

## Próxima ação operacional
Investigar a Edge Function `coachflow-api`, confirmar configurações por ambiente sem expor chaves, gerar plano de exportação compatível com as ferramentas disponíveis. Não usar SQL como substituto de backup completo.
