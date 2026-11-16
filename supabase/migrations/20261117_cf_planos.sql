-- Planos Essencial x Profissional e assinatura pelo Asaas.
-- 1) _cf_is_pro: a conta tem as funções do Profissional?
--    Sim no teste grátis, na cortesia e no plano Profissional em dia (ou na tolerância).
create or replace function public._cf_is_pro(p_owner uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select case public._cf_state_of(s.status, s.current_period_end, s.trial_ends_at)
      when 'trialing' then true
      when 'courtesy' then true
      when 'active' then s.plan = 'profissional'
      when 'grace' then s.plan = 'profissional'
      else false end
    from public.cf_subscriptions s where s.owner_id = p_owner), false)
$$;
revoke all on function public._cf_is_pro(uuid) from public, anon, authenticated;
grant execute on function public._cf_is_pro(uuid) to service_role;

-- 2) O app sabe se a conta é Profissional.
create or replace function public.cf_my_subscription() returns jsonb
language sql stable security definer set search_path = '' as $$
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
    'client_limit', case when s.plan = 'essencial' and s.status <> 'courtesy' then 15 else null end
  )
  from (select 1) one
  left join public.cf_subscriptions s on s.owner_id = auth.uid()
$$;
revoke all on function public.cf_my_subscription() from public, anon;
grant execute on function public.cf_my_subscription() to authenticated;

-- 3) Agendamento online só para quem é Profissional (o link para de funcionar no Essencial).
do $$
declare d text;
begin
  d := pg_get_functiondef('public.cf_public_booking(text)'::regprocedure);
  if position('_cf_is_pro' in d) = 0 then
    d := replace(d, 'where s.slug = p_slug and s.enabled', 'where s.slug = p_slug and s.enabled and public._cf_is_pro(s.owner_id)');
    execute d;
  end if;
  d := pg_get_functiondef('public.cf_request_booking(text,text,text,text,date,text,text,text)'::regprocedure);
  if position('_cf_is_pro' in d) = 0 then
    d := replace(d, 'where slug = p_slug and enabled;', 'where slug = p_slug and enabled and public._cf_is_pro(owner_id);');
    execute d;
  end if;
  d := pg_get_functiondef('public.cf_request_change(text,text,text,text,text,text)'::regprocedure);
  if position('_cf_is_pro' in d) = 0 then
    d := replace(d, 'where slug = p_slug and enabled;', 'where slug = p_slug and enabled and public._cf_is_pro(owner_id);');
    execute d;
  end if;
end $$;

-- 4) Oferta de fundador: até 100 contas.
create or replace function public._cf_founder_slots() returns int
language sql stable security definer set search_path = '' as $$
  select greatest(0, 100 - (select count(*)::int from public.cf_subscriptions where founder and not internal))
$$;
revoke all on function public._cf_founder_slots() from public, anon, authenticated;
grant execute on function public._cf_founder_slots() to service_role;

-- 5) Pedidos de assinatura feitos pela página "Escolher plano".
create table if not exists public.cf_checkouts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  asaas_subscription_id text,
  plan text not null check (plan in ('essencial', 'profissional')),
  cycle text not null check (cycle in ('monthly', 'annual')),
  founder boolean not null default false,
  value numeric(10, 2) not null,
  created_at timestamptz not null default now()
);
alter table public.cf_checkouts enable row level security;
revoke all on public.cf_checkouts from anon, authenticated;
create index if not exists cf_checkouts_sub_idx on public.cf_checkouts (asaas_subscription_id);

-- 6) Aviso do Asaas: além de confirmar o pagamento, aplica o plano escolhido.
create or replace function public.cf_asaas_apply(p_event text, p_payment jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  pid text := p_payment ->> 'id';
  cust text := p_payment ->> 'customer';
  sub_id text := p_payment ->> 'subscription';
  ext text := p_payment ->> 'externalReference';
  v_owner uuid;
  v_status text;
  v_amount numeric := coalesce((p_payment ->> 'value')::numeric, 0);
  v_due date := nullif(p_payment ->> 'dueDate', '')::date;
  v_paid timestamptz := coalesce(nullif(p_payment ->> 'confirmedDate', '')::timestamptz,
                                 nullif(p_payment ->> 'paymentDate', '')::timestamptz);
  s public.cf_subscriptions;
  ck public.cf_checkouts;
  new_end timestamptz;
begin
  if pid is null then raise exception 'pagamento sem identificador'; end if;

  if sub_id is not null then
    select * into ck from public.cf_checkouts where asaas_subscription_id = sub_id order by created_at desc limit 1;
    v_owner := ck.owner_id;
  end if;
  if v_owner is null then
    select owner_id into v_owner from public.cf_subscriptions where asaas_customer_id = cust limit 1;
  end if;
  if v_owner is null and ext ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    select id into v_owner from auth.users where id = ext::uuid;
  end if;

  v_status := case
    when p_event = 'PAYMENT_DELETED' then 'deleted'
    else case p_payment ->> 'status'
      when 'RECEIVED' then 'received' when 'RECEIVED_IN_CASH' then 'received'
      when 'CONFIRMED' then 'confirmed' when 'OVERDUE' then 'overdue'
      when 'REFUNDED' then 'refunded' when 'REFUND_REQUESTED' then 'refunded'
      else 'pending' end
  end;

  select * into s from public.cf_subscriptions where owner_id = v_owner;

  insert into public.cf_saas_payments (owner_id, asaas_payment_id, amount, status, due_date, paid_at, plan)
    values (v_owner, pid, v_amount, v_status, v_due, v_paid, coalesce(ck.plan, s.plan))
  on conflict (asaas_payment_id) do update set
    owner_id = coalesce(excluded.owner_id, public.cf_saas_payments.owner_id),
    amount = excluded.amount, status = excluded.status,
    due_date = coalesce(excluded.due_date, public.cf_saas_payments.due_date),
    paid_at = coalesce(excluded.paid_at, public.cf_saas_payments.paid_at),
    updated_at = now();

  if v_owner is not null and s.owner_id is not null and s.status <> 'courtesy' then
    if v_status in ('received', 'confirmed') then
      new_end := coalesce(v_due, current_date)::timestamptz
                 + case when coalesce(ck.cycle, s.cycle) = 'annual' then interval '1 year' else interval '1 month' end;
      update public.cf_subscriptions set
        status = 'active',
        plan = coalesce(ck.plan, plan),
        cycle = coalesce(ck.cycle, cycle),
        founder = founder or coalesce(ck.founder, false),
        asaas_subscription_id = coalesce(sub_id, asaas_subscription_id),
        asaas_customer_id = coalesce(cust, asaas_customer_id),
        current_period_end = greatest(coalesce(current_period_end, new_end), new_end)
      where owner_id = v_owner;
    elsif v_status = 'overdue' and s.status = 'active' then
      update public.cf_subscriptions set status = 'past_due' where owner_id = v_owner;
    end if;
  end if;

  return jsonb_build_object('owner_found', v_owner is not null, 'status', v_status);
end $$;
revoke all on function public.cf_asaas_apply(text, jsonb) from public, anon, authenticated;
grant execute on function public.cf_asaas_apply(text, jsonb) to service_role;
