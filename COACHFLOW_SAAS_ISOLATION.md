# CoachFlow Profissional / SaaS 2.0 — Regras de isolamento

## Regra principal

Esta branch (`coachflow-2-saas`) pertence exclusivamente ao CoachFlow Profissional / SaaS 2.0.

**NUNCA fazer merge desta branch na `main` deste repositório.**

A `main` está reservada ao CoachFlow Pessoal legado, usado por Daniel Barsottini com dados reais. Em 01/10/2026 o SaaS 2.0 foi incorporado por engano à `main` e substituiu a aplicação pessoal em produção. A alteração foi revertida pela PR #4.

## Ambientes que devem permanecer separados

### CoachFlow Pessoal
- Código de produção: `main` deste repositório.
- Uso: aplicação pessoal/legada.
- Dados: reais.
- Política: não usar como ambiente de testes do SaaS.

### CoachFlow Profissional / SaaS 2.0
- Código protegido: `coachflow-2-saas`.
- Uso: produto comercial/multiusuário.
- Deve possuir projeto Vercel próprio e domínio/URL próprios.
- Deve possuir configuração de ambiente própria.
- Antes de qualquer desenvolvimento adicional, validar também o isolamento do Supabase/banco.

## Checklist obrigatório antes de qualquer deploy do SaaS

1. Confirmar repositório.
2. Confirmar branch = `coachflow-2-saas` (ou branch derivada dela).
3. Confirmar que o projeto Vercel é o projeto exclusivo do SaaS.
4. Confirmar domínio/URL de destino.
5. Confirmar variáveis de ambiente e Supabase do SaaS.
6. Fazer deploy Preview.
7. Validar Preview desktop/mobile e fluxos críticos.
8. Somente depois promover dentro do projeto SaaS.
9. Nunca promover o SaaS pela `main` do CoachFlow Pessoal.

## Histórico de segurança

- PR #3: merge acidental do SaaS 2.0 na `main`.
- Merge acidental: `0f377bfb245ea4899f498716165ca3c03ef404f9`.
- PR #4: reversão da PR #3 e restauração da aplicação pessoal.
- Merge da reversão: `2f494e4238728968a69ada938b25a38aa902f64c`.
- Snapshot preservado do SaaS 2.0: branch `coachflow-2-saas`.

Nenhuma nova funcionalidade do SaaS deve ser desenvolvida antes de concluirmos a separação Vercel + banco + domínio.