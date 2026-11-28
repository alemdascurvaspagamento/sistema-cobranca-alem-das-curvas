-- Compras de teste da Apple (TestFlight / Sandbox) só liberam contas de teste.
-- O TestFlight do Léguno tem link público e lá as compras são gratuitas.
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
  elsif p_env = 'Sandbox' and not exists (
    select 1 from public.cf_beta_testers b where b.user_id = v_owner and 'apple_sandbox' = any(b.features)
  ) then
    -- Compra de teste (TestFlight/Sandbox) só libera contas de teste cadastradas.
    v_result := 'sandbox_ignorado';
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


-- Contas de teste que podem usar compras de teste: Daniel, +teste, +gratis e a conta da revisão da Apple.
insert into public.cf_beta_testers (user_id, features)
select u.id, array['apple_sandbox']
from auth.users u
where u.email in ('daniel.barsottini@gmail.com', 'daniel.barsottini+teste@gmail.com',
                  'daniel.barsottini+gratis@gmail.com', 'daniel.barsottini+apple@gmail.com')
on conflict (user_id) do update
  set features = (select array_agg(distinct f) from unnest(public.cf_beta_testers.features || array['apple_sandbox']) f);
