# Coach Flow Profissional — plano de entrega técnica

## Limites obrigatórios
- Desenvolvimento somente em `flutter-profissional-foundation-20261019`, sob `flutter_profissional/`.
- Nunca alterar o Coach Flow Pessoal (`main`), suas tabelas, credenciais ou registros.
- Reutilizar fluxos e padrões de interface, não copiar dados pessoais.
- Nunca enviar cobranças/WhatsApp automaticamente nem ativar pagamentos sem configuração explícita.

## Implementado e publicado em preview
- Shell Flutter com navegação, dashboard e agenda demonstrativa.
- Clientes fictícios: criar, editar, buscar, filtrar, excluir com confirmação.
- Abertura de WhatsApp e preparação de lembrete para pendências.
- Financeiro fictício: receitas, despesas, status, filtros e saldo realizado.
- Meta anual demonstrativa com progresso e referências mensal/trimestral.
- Compilação Vercel automática em branch separada.

## Etapas ainda necessárias para produto comercial
1. **Modelo multi-tenant:** profissionais, clientes, serviços, contratos, agenda, lançamentos, pagamentos, metas, templates e auditoria.
2. **Autenticação e isolamento:** Supabase Auth, RLS em todas as tabelas por `owner_id`, testes de acesso cruzado, políticas de storage e recuperação de senha.
3. **Cadastros persistentes:** CRUD com validação, telefone E.164, busca, paginação, exclusão lógica e exportação.
4. **Agenda real:** compromissos, recorrência, conflitos, estados, fuso horário, feriados, remarcação e integração financeira opcional.
5. **Cobrança real:** cálculo de competências, vencimentos, parcial, descontos, créditos, histórico, Pix e comprovantes; revisar mensagens antes de enviar.
6. **Metas e relatórios:** acumulado anual real, mensal/trimestral, projeção, inadimplência, gráficos e exportação.
7. **Configurações:** marca por profissional, templates de WhatsApp, moeda, fuso horário e permissões.
8. **Qualidade:** testes unitários/widget/integrados, acessibilidade, responsividade, segurança, observabilidade, backups e política LGPD.
9. **Entrega:** ambiente de homologação com dados sintéticos, migrações versionadas, testes de ponta a ponta e checklist antes de produção.

## Critérios para considerar finalizado
- Todas as telas e operações reais persistem dados no tenant correto.
- Não há acesso cruzado entre profissionais; políticas RLS testadas.
- Valores de cobrança e metas reconciliam com transações e competência.
- Mensagens exigem revisão e ação humana de envio.
- Testes automatizados e build Flutter Web passam.
- Publicação de produção validada e processo de rollback documentado.

**Situação:** protótipo funcional em preview; ainda não é um SaaS comercial concluído.