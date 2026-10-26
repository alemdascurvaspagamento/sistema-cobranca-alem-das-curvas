# Coach Flow Profissional: onde paramos

Última atualização: 26/10/2026 (tarde).

## Onde está o trabalho

- **Ramo de trabalho:** `etapa1-regras-cobranca`, criado a partir de `flutter-profissional-foundation-20261019`.
- **Pasta:** `flutter_profissional/` (Flutter). O Coach Flow Pessoal (`main`) não foi tocado.
- **Versão web de teste (Vercel):** `coachflow-profissional-flutter-git-etapa-51b6e7-alem-das-curvas.vercel.app`
  (protegida pela Vercel; o dono gera link de compartilhamento pelo painel).
- **App Android de teste:** Releases › `android-teste` no GitHub (substituído a cada versão que passa nos testes).
- **Verificação automática:** `.github/workflows/flutter-profissional.yml`. A cada mudança roda os testes,
  a análise e a montagem web; se passar, gera o app Android.
  Falhas aparecem como avisos legíveis na página da verificação.

## O que já está pronto (demonstração com dados de exemplo)

### Base e regras (Etapa 1)
- Motor de cobrança em `lib/billing/billing_engine.dart` (código puro, testado):
  - formas de cobrança: por atendimento, por hora, mensalidade fixa e pacote;
  - rotina com dias fixos e horário próprio por dia; atendimentos avulsos; horário só numa data;
  - faltas em 3 regras: cobrar e descontar no mês seguinte (jeito do Pessoal), cobrar, não cobrar;
  - feriados, férias, créditos, remarcação no mesmo mês e em outro mês (2 regras);
  - pagamentos parciais, situação (pago, em parte, a receber, atrasado);
  - "como chegamos a esse valor" explicado linha por linha.
- Vocabulário por profissão em `lib/billing/terms.dart` e `lib/profile/profession_profile.dart`
  (15 profissões: aluno/aula, paciente/sessão, paciente/consulta, cliente/atendimento...).
- Boas-vindas em 2 passos (profissão e forma de cobrança) em `lib/ui/onboarding.dart`.
- Tela de entrada para venda em `lib/ui/sales_entry.dart`.

### Telas (Etapa 2)
- **Início** (`lib/screens/home_screen.dart`): resumo do dia, Secretária com ações
  (confirmar atendimento, cobrar atrasado, lembrar vencimento, pacote acabando, contas a pagar),
  agenda de hoje e mês com meta.
- **Agenda** (`lib/screens/agenda_screen.dart`): visões Dia, Semana e Mês; marcar atendimento avulso com horário.
- **Cobranças** (`lib/billing/billing_screen.dart`): placar do mês, cartão por cliente, detalhe com cálculo,
  editar atendimento, férias, registrar pagamento, WhatsApp com revisão.
- **Pacientes/Alunos/Clientes** (`lib/screens/clients_screen.dart`): busca, ficha, cadastro completo, arquivar.
- **Financeiro** (`lib/screens/finance_screen.dart`): previsão do mês (vai faturar, vai gastar, deve sobrar),
  entradas, ganhos extras, despesas fixas e avulsas com **dar baixa** e **editar** (fixa: "daqui em diante" ou
  "todos os meses"), calendário de despesas, meta e gráfico de 6 meses.
- **Relatórios** (`lib/screens/reports_screen.dart`): visão geral do mês, meta do ano com projeção,
  situação por cliente, ano mês a mês, copiar resumo.
- **Início:** cartão vermelho "Em atraso" (só conta meses a partir do primeiro pagamento registrado).
- **Cobranças:** botão **Pix** com QR Code e "copia e cola" já com o valor (`lib/billing/pix.dart`, padrão BR Code);
  o código também vai na mensagem do WhatsApp. No computador largo, tabela com previstas, feriados, faltas,
  remarcadas, créditos e desconto.
- **Configurações:** dados do Pix (chave, nome, cidade) e **baixar meus dados** em planilha Excel (`lib/data/export.dart`).
- **Segurança:** saída automática após 30 minutos sem uso na conta real (`lib/ui/idle_guard.dart`).
- **Regras e feriados** (`lib/billing/rules_screen.dart`): regras de cobrança, feriados nacionais, troca de profissão.
- Identidade visual em `lib/ui/cf_theme.dart` (Barlow, azul-marinho, números em estilo placar).
- Todas as telas leem a mesma base (`lib/billing/billing_store.dart`): os números batem entre telas.

### Qualidade
- Testes em `test/`: motor de cobrança, 15 profissões × 4 formas de cobrança, avulsos, despesas,
  baixa, horários, calendário do mês × dia, telas de entrada.

## Banco de dados (Etapa 3, feita em 26/10)

- **Projeto Supabase:** "Além das Curvas" (`yjpxjzgvshaabjpdpbsc`), o mesmo do Coach Flow Pessoal.
  O Profissional usa só as tabelas `cf_*` (desenho em `sql/cf_schema_v1.sql`). As tabelas do Pessoal não foram alteradas.
- **Segurança:** RLS em todas as `cf_*` (dono = `auth.uid()`); visitante sem login não tem acesso; testado com intruso simulado.
- **Dados do Daniel copiados do Pessoal em 26/10:** 17 alunos ativos + 5 arquivados, horários por dia, 183 aulas com alteração,
  10 feriados, 53 pagamentos (R$ 63.097,50), 37 despesas lançadas até outubro (36 pagas) + 13 despesas fixas a partir de novembro,
  6 ganhos extras, meta anual (`annual_goal`, mensal = anual ÷ 12), regras do Pessoal.
- Colunas novas em `cf_profiles`: `annual_goal`, `pix_name`, `pix_city`.
- **App:** `lib/data/cloud.dart` carrega tudo ao entrar e grava cada mudança em fila; `lib/config.dart` tem o endereço e a
  chave pública (publishable). Login com a mesma conta do Pessoal. Recuperar senha envia e-mail pelo Supabase.
- **A partir de 26/10 os dois sistemas são independentes:** o que for lançado no Pessoal não aparece no Profissional e vice-versa.

## Assinatura (26/10)

- Preços aprovados por Daniel: teste de 14 dias sem cartão; Essencial R$ 29,90 (até 15 clientes ativos);
  Profissional R$ 49,90 (ilimitado); anual com 2 meses grátis; fundador R$ 39,90 para os 50 primeiros.
  Proposta completa: documento "Coach Flow Profissional: planos e regras de cobrança".
- Banco (`sql/cf_subscriptions_v1.sql`): `cf_subscriptions` (só o servidor altera), `cf_access_state()`,
  `cf_my_subscription()`, teste começa ao criar o perfil, gravação bloqueada em somente leitura (políticas
  restritivas), limite de 15 clientes ativos no Essencial. Conta do Daniel = cortesia.
- App: cadastro "Criar conta grátis", faixa de teste/atraso/somente leitura, painel Assinatura em Configurações.
- Falta: cobrança pelo Asaas (página de assinatura + função que recebe o aviso de pagamento), termos e privacidade.

## Próximos passos (em ordem)

1. **Daniel:** entrar com a conta do Pessoal, conferir alunos/horários/valores e o mês de outubro; publicar o
   endereço fixo na Vercel (Production Branch = `etapa1-regras-cobranca`).
2. **Piloto de 1 mês:** usar os dois em paralelo e comparar as cobranças; depois aposentar o Pessoal
   (backup, limpar `audit_log`, remover tabelas antigas, incluindo as de uma tentativa SaaS anterior sem uso).
3. Cadastro aberto para outros profissionais (hoje só contas criadas no painel entram); proteção contra senhas vazadas.
4. Versão computador definitiva, marca e ícone, Android na Play Store, iPhone na App Store.
5. Antes de vender: teste com 2 ou 3 profissionais, termos de uso e privacidade (LGPD), preço e teste grátis,
   ícone e marca final, assinatura do app Android para a Google Play, versão iPhone.

## Observações técnicas

- O ambiente de trabalho do Claude não instala o Flutter (sites bloqueados). Quem compila é a Vercel
  e o GitHub Actions; o `gh` funciona para acompanhar a verificação e ler os avisos.
- As telas antigas de demonstração (`demo_*.dart`, `professional_dashboard.dart` etc.) ainda existem
  e são usadas só no modo com banco conectado; serão substituídas na Etapa 3.
- `DemoLedger` recebe os números da `BillingStore` só para manter compatíveis as telas antigas.
