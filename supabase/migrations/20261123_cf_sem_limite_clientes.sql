-- Nenhum plano limita o número de clientes (o Essencial deixava até 15 ativos).
create or replace function public.cf_check_client_limit()
returns trigger language plpgsql security definer set search_path to ''
as $$ begin return new; end; $$;

create or replace function public.cf_my_subscription() returns jsonb
language sql stable security definer set search_path to ''
as $$
  select jsonb_build_object(
    'plan', coalesce(s.plan, 'profissional'),
    'status', coalesce(s.status, 'trialing'),
    'state', public._cf_state_of(s.status, s.current_period_end, s.trial_ends_at),
    'trial_ends_at', s.trial_ends_at,
    'current_period_end', s.current_period_end,
    'founder', coalesce(s.founder, false),
    'cycle', coalesce(s.cycle, 'monthly'),
    'pro', public._cf_is_pro(auth.uid()),
    'has_subscription', s.asaas_subscription_id is not null,
    'client_limit', null
  )
  from (select 1) one
  left join public.cf_subscriptions s on s.owner_id = auth.uid()
$$;
