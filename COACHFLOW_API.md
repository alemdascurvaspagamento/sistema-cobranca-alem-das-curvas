# CoachFlow API

A camada de API do CoachFlow está implantada no Supabase como a Edge Function `coachflow-api`.

## Segurança

- JWT obrigatório (`verify_jwt=true`).
- O usuário é identificado exclusivamente pelo JWT autenticado.
- `owner_id` é derivado do usuário autenticado; o cliente não pode escolher o proprietário nas operações protegidas.
- Apenas tabelas explicitamente permitidas podem ser acessadas pela camada API.
- Leituras, alterações e exclusões via API são limitadas ao `owner_id` autenticado.
- A `service_role` não é exposta ao navegador.
- As tabelas da aplicação mantêm RLS por proprietário.
- O papel `anon` não possui privilégios de DML nas tabelas da aplicação; `authenticated` mantém somente SELECT/INSERT/UPDATE/DELETE.

## Tabelas permitidas

`Alunos`, `horarios`, `aulas`, `cobrancas`, `pagamentos`, `feriados`, `ganhos_extras`, `configuracoes`, `despesas`, `despesas_fixas`, `despesas_fixas_lancamentos`.

## Estado da migração

O cliente `coachflow-api-client.js` é carregado pelo `index.html` e intercepta as operações padrão de `select`, `insert`, `update` e `delete` dessas tabelas, encaminhando-as para a Edge Function com o JWT da sessão.

A inicialização tardia do cliente evita corrida com a criação do `adcSupabase` pelo frontend. Operações em tabelas fora da lista permitida continuam usando o cliente Supabase nativo.

O frontend possui uma operação `upsert` existente que ainda usa o cliente Supabase autenticado como caminho de compatibilidade, porque a versão implantada da Edge Function não expõe `upsert`. Esse caminho continua protegido por RLS e pelos privilégios do papel `authenticated` e não usa `service_role`.

## Validação automatizada

O workflow `Validate CoachFlow` valida sintaxe, carregamento do cliente, endpoint da API, tabelas permitidas, cabeçalhos de segurança, ausência de `service_role` no frontend e o comportamento do proxy em um ambiente mockado.

O workflow de instalação também garante que o cliente da API permaneça conectado ao `index.html` publicado.
