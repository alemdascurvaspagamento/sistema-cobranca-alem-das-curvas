# Coach Flow Profissional: onde paramos

Última atualização: 23/10/2026, fim do dia.

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
- **Financeiro** (`lib/screens/finance_screen.dart`): sobra do mês, entradas, ganhos extras,
  despesas fixas e avulsas com **dar baixa** por mês, contas a pagar, meta e gráfico de 6 meses.
- **Regras e feriados** (`lib/billing/rules_screen.dart`): regras de cobrança, feriados nacionais, troca de profissão.
- Identidade visual em `lib/ui/cf_theme.dart` (Barlow, azul-marinho, números em estilo placar).
- Todas as telas leem a mesma base (`lib/billing/billing_store.dart`): os números batem entre telas.

### Qualidade
- Testes em `test/`: motor de cobrança, 15 profissões × 4 formas de cobrança, avulsos, despesas,
  baixa, horários, calendário do mês × dia, telas de entrada.

## Próximos passos (em ordem)

1. **Daniel:** testar o app Android e a Agenda (principalmente a visão Mês no celular) e mandar ajustes.
2. **Etapa 3 (banco gratuito):**
   - criar uma organização nova no Supabase (Daniel faz, com passo a passo) — plano gratuito;
   - usar o desenho inicial em `sql/coachflow_profissional_schema.sql` como ponto de partida;
   - tabelas: profissionais, clientes, atendimentos, feriados, regras, pagamentos, despesas, ganhos extras;
   - cada profissional vê só os próprios dados (RLS por `owner_id`), com teste de acesso cruzado;
   - cadastro e login próprios, recuperação de senha; a demonstração continua separada;
   - `BillingStore` passa a ler e gravar no banco, sem mudar o motor de cálculo.
3. Antes de vender: teste com 2 ou 3 profissionais, termos de uso e privacidade (LGPD), preço e teste grátis,
   ícone e marca final, assinatura do app Android para a Google Play, versão iPhone.

## Observações técnicas

- O ambiente de trabalho do Claude não instala o Flutter (sites bloqueados). Quem compila é a Vercel
  e o GitHub Actions; o `gh` funciona para acompanhar a verificação e ler os avisos.
- As telas antigas de demonstração (`demo_*.dart`, `professional_dashboard.dart` etc.) ainda existem
  e são usadas só no modo com banco conectado; serão substituídas na Etapa 3.
- `DemoLedger` recebe os números da `BillingStore` só para manter compatíveis as telas antigas.
