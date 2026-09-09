# CoachFlow API

A camada de API do CoachFlow foi criada no Supabase como a Edge Function `coachflow-api`.

## Segurança

- JWT obrigatório (`verify_jwt=true`).
- O usuário é identificado exclusivamente pelo JWT autenticado.
- `owner_id` é derivado do `auth.uid()` do usuário autenticado; o cliente não pode escolher o proprietário.
- Apenas tabelas explicitamente permitidas podem ser acessadas.
- Leituras, alterações e exclusões são sempre limitadas ao `owner_id` autenticado.
- A `service_role` não é exposta ao navegador.

## Tabelas permitidas

`Alunos`, `horarios`, `aulas`, `cobrancas`, `pagamentos`, `feriados`, `ganhos_extras`, `configuracoes`, `despesas`, `despesas_fixas`, `despesas_fixas_lancamentos`.

## Estado da migração

A API está implantada e ativa como uma camada nova e independente. O frontend legado continua usando a conexão Supabase existente neste momento para evitar qualquer risco de interrupção dos dados e da rotina de sincronização.

A próxima etapa é migrar os pontos de leitura/escrita do frontend para esta API em blocos testáveis, mantendo o comportamento atual e validando cada módulo antes de remover o acesso direto.
