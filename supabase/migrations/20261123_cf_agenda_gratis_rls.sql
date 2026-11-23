-- Agenda Grátis: a agenda (clientes, aulas/eventos, sessões e feriados) pode ser
-- alterada mesmo sem plano em dia. Continua valendo a regra "cada dono só mexe no que é seu".
-- Financeiro (pagamentos, despesas, entradas) segue exigindo teste, plano em dia ou cortesia.
do $$
declare t text; c text;
begin
  foreach t in array array['cf_clients','cf_events','cf_sessions','cf_holidays'] loop
    foreach c in array array['inserir','alterar','apagar'] loop
      execute format('drop policy if exists %I on public.%I', 'assinatura em dia (' || c || ')', t);
    end loop;
  end loop;
end $$;
