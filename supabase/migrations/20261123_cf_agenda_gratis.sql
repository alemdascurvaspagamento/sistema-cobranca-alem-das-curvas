-- Agenda Grátis: quem não tem plano em dia (estado 'read_only') continua usando a agenda,
-- mas não recebe e-mails do Léguno (resumo da manhã). Só leitura de dados; nada é apagado.
create or replace function public._cf_has_plan(p_owner uuid)
returns boolean
language sql stable security definer
set search_path to ''
as $$
  select coalesce((
    select public._cf_state_of(s.status, s.current_period_end, s.trial_ends_at) <> 'read_only'
    from public.cf_subscriptions s where s.owner_id = p_owner), false)
$$;
revoke all on function public._cf_has_plan(uuid) from public, anon, authenticated;
grant execute on function public._cf_has_plan(uuid) to service_role;
