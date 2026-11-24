-- Plano C: assinatura comprada dentro do iPhone (compra pela Apple).
-- A conta continua tendo UMA assinatura (cf_subscriptions); ela passa a dizer de onde veio:
-- 'asaas' (site) ou 'apple' (iPhone). O acesso é liberado igual para as duas.

alter table public.cf_subscriptions
  add column if not exists source text not null default 'asaas',
  add column if not exists apple_original_transaction_id text,
  add column if not exists apple_product_id text,
  add column if not exists apple_environment text;

do $$ begin
  alter table public.cf_subscriptions add constraint cf_subscriptions_source_chk check (source in ('asaas', 'apple'));
exception when duplicate_object then null; end $$;

create unique index if not exists cf_subscriptions_apple_tx_uq
  on public.cf_subscriptions (apple_original_transaction_id) where apple_original_transaction_id is not null;

-- Registro dos avisos da Apple (para não aplicar o mesmo aviso duas vezes e para conferência).
create table if not exists public.cf_apple_events (
  event_id text primary key,
  received_at timestamptz not null default now(),
  owner_id uuid,
  notification_type text,
  subtype text,
  original_transaction_id text,
  product_id text,
  environment text,
  result text
);
alter table public.cf_apple_events enable row level security;
revoke all on public.cf_apple_events from anon, authenticated;

-- Aplica na conta o que a Apple confirmou.
-- p_kind: 'active' (compra, renovação, período de carência), 'expired' (venceu sem renovar),
--         'refunded' (reembolso), 'revoked' (compra retirada pela Apple).
create or replace function public.cf_apple_apply(
  p_owner uuid,
  p_original_tx text,
  p_product text,
  p_expires timestamptz,
  p_kind text,
  p_env text,
  p_event_id text default null,
  p_type text default null,
  p_subtype text default null
) returns jsonb
language plpgsql security definer set search_path to ''
as $$
declare
  v_owner uuid;
  v_plan text := case when p_product like '%.essencial.%' then 'essencial' else 'profissional' end;
  v_cycle text := case when p_product like '%.anual' then 'annual' else 'monthly' end;
  s public.cf_subscriptions;
  v_state text;
  v_result text;
begin
  if p_kind not in ('active', 'expired', 'refunded', 'revoked') then
    raise exception 'cf_apple_kind_invalido';
  end if;

  -- Aviso repetido: não aplica de novo.
  if p_event_id is not null then
    insert into public.cf_apple_events (event_id, owner_id, notification_type, subtype, original_transaction_id, product_id, environment)
    values (p_event_id, p_owner, p_type, p_subtype, p_original_tx, p_product, p_env)
    on conflict (event_id) do nothing;
    if not found then
      return jsonb_build_object('result', 'duplicado');
    end if;
  end if;

  -- A compra já ligada a uma conta continua nessa conta (protege contra reaproveitar compra).
  select owner_id into v_owner from public.cf_subscriptions where apple_original_transaction_id = p_original_tx;
  v_owner := coalesce(v_owner, p_owner);

  if v_owner is null then
    v_result := 'sem_conta';
  else
    perform set_config('cf.source', 'apple:' || coalesce(p_type, 'compra'), true);
    insert into public.cf_subscriptions (owner_id) values (v_owner) on conflict (owner_id) do nothing;
    select * into s from public.cf_subscriptions where owner_id = v_owner for update;
    v_state := public._cf_state_of(s.status, s.current_period_end, s.trial_ends_at);

    if p_kind = 'active' then
      if s.status = 'courtesy' then
        -- Cortesia continua cortesia; só guarda a compra.
        update public.cf_subscriptions set apple_original_transaction_id = p_original_tx,
          apple_product_id = p_product, apple_environment = p_env, updated_at = now()
        where owner_id = v_owner;
        v_result := 'cortesia';
      elsif s.source = 'asaas' and v_state in ('active', 'grace') and s.asaas_subscription_id is not null
            and coalesce(s.apple_original_transaction_id, '') <> p_original_tx then
        -- Já pagava pelo site: não perde nada, fica com o maior prazo e o plano da Apple.
        update public.cf_subscriptions set source = 'apple', plan = v_plan, cycle = v_cycle, status = 'active',
          current_period_end = greatest(coalesce(s.current_period_end, now()), p_expires),
          apple_original_transaction_id = p_original_tx, apple_product_id = p_product,
          apple_environment = p_env, updated_at = now()
        where owner_id = v_owner;
        v_result := 'assinatura_dupla';
      else
        update public.cf_subscriptions set source = 'apple', plan = v_plan, cycle = v_cycle, status = 'active',
          current_period_end = p_expires, apple_original_transaction_id = p_original_tx,
          apple_product_id = p_product, apple_environment = p_env, updated_at = now()
        where owner_id = v_owner;
        v_result := 'ativa';
      end if;
    elsif s.source <> 'apple' or coalesce(s.apple_original_transaction_id, '') <> p_original_tx then
      -- Aviso de outra compra (ou conta que hoje paga pelo site): não mexe.
      v_result := 'ignorado';
    elsif p_kind = 'expired' then
      update public.cf_subscriptions set status = 'canceled',
        current_period_end = least(coalesce(current_period_end, p_expires), coalesce(p_expires, now())), updated_at = now()
      where owner_id = v_owner;
      v_result := 'vencida';
    else
      -- Reembolso ou compra retirada: sai do acesso pago agora (volta ao teste se ele ainda estiver valendo).
      update public.cf_subscriptions set
        status = case when trial_ends_at > now() then 'trialing' else 'canceled' end,
        current_period_end = now(), updated_at = now()
      where owner_id = v_owner;
      v_result := 'reembolsada';
    end if;
  end if;

  if p_event_id is not null then
    update public.cf_apple_events set result = v_result, owner_id = coalesce(v_owner, owner_id) where event_id = p_event_id;
  end if;

  select * into s from public.cf_subscriptions where owner_id = v_owner;
  return jsonb_build_object('result', v_result, 'owner', v_owner,
    'state', case when v_owner is null then null else public._cf_state_of(s.status, s.current_period_end, s.trial_ends_at) end);
end $$;

revoke all on function public.cf_apple_apply(uuid, text, text, timestamptz, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.cf_apple_apply(uuid, text, text, timestamptz, text, text, text, text, text) to service_role;

-- O app passa a saber de onde vem a assinatura.
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
    'has_subscription', s.asaas_subscription_id is not null or s.apple_original_transaction_id is not null,
    'source', coalesce(s.source, 'asaas'),
    'apple_product', s.apple_product_id,
    'client_limit', null
  )
  from (select 1) one
  left join public.cf_subscriptions s on s.owner_id = auth.uid()
$$;
