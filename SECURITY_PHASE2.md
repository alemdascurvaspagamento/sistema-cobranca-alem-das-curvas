# Fase 2 — Hardening de segurança

Data: 2026-09-08

## Correções aplicadas

- Fixada a versão do Supabase JS usada no navegador em `2.115.0`.
- Removido o registro de um Service Worker legado que não existe mais no repositório.
- Adicionada uma política CSP no HTML para restringir scripts, estilos, fontes, conexões, objetos e base URL.
- Mantida a validação de que `initialStudents` permanece vazio e `COACHFLOW_BACKUP_V12_3` permanece vazio.
- Workflow temporário de hardening executado com sucesso e removido após a aplicação.

## Itens ainda pendentes de configuração externa

- Ativar a proteção do Supabase contra senhas já vazadas (Leaked Password Protection) no painel de Auth.
- Revisar/revogar privilégios `anon` das tabelas públicas e configurar privilégios padrão mínimos no banco. O RLS continua sendo a barreira principal de autorização.

## Observação

Nenhum dado de aluno foi alterado nesta fase.
