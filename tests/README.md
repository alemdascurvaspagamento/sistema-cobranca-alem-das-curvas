# Testes de sincronização

Simulam um banco (Supabase) em memória e abrem o `index.html` num navegador de verdade
(Playwright). Cada teste reproduz um problema que já aconteceu (férias que somem, aluno
duplicado, baixa de pagamento que volta, aluno excluído reaparecendo) ou protege a economia
de idas ao banco (ciclo parado sem nenhuma escrita).

Rodar (precisa de Node 20+ e Playwright com Chromium instalado):

    NODE_PATH=$(npm root -g) node --test tests/sync.test.js

Não usam o banco real nem a internet.
