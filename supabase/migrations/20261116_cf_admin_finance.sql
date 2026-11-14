-- Painel de administração do Léguno (fases 2 e 3): financeiro e resumo diário.
-- Depende da migração 20261115_cf_admin.sql. Tudo novo: não mexe em dados existentes.
-- Os pagamentos chegam do Asaas por uma função de aviso (webhook). Enquanto o Asaas
-- não estiver ligado, a tela Financeiro mostra só a estimativa pelos planos.

-- 1) Pagamentos das assinaturas ---------------------------------------------------
create table if not exists public.cf_saas_payments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete set null,
  asaas_payment_id text not null unique,
  amount numeric(10, 2) not null,
  status text not null check (status in ('pending', 'confirmed', 'received', 'overdue', 'refunded', 'deleted')),
  due_date date,
  paid_at timestamptz,
  plan text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.cf_saas_payments enable row level security;
revoke all on public.cf_saas_payments from anon, authenticated;
create index if not exists cf_saas_payments_owner_idx on public.cf_saas_payments (owner_id);
create index if not exists cf_saas_payments_paid_idx on public.cf_saas_payments (paid_at);

-- 2) Tela Financeiro --------------------------------------------------------------
create or replace function public.cf_admin_finance() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  r jsonb;
  m0 date := date_trunc('month', now())::date;
  has_pay boolean;
begin
  perform public._cf_admin_guard();
  has_pay := exists (select 1 from public.cf_saas_payments);
  select jsonb_build_object(
    'source', case when has_pay then 'asaas' else 'estimate' end,
    'mrr', (select coalesce(round(sum(public._cf_monthly_price(a.plan, a.founder, a.cycle)), 2), 0)
              from public._cf_accounts() a where not a.internal and a.status = 'active' and a.state in ('active', 'grace')),
    'received_month', (select coalesce(sum(amount), 0) from public.cf_saas_payments
              where status in ('received', 'confirmed') and paid_at >= m0 and paid_at < m0 + interval '1 month'),
    'to_receive_month', (select coalesce(sum(amount), 0) from public.cf_saas_payments
              where status = 'pending' and due_date >= current_date and due_date < (m0 + interval '1 month')::date),
    'overdue', (select coalesce(sum(amount), 0) from public.cf_saas_payments where status = 'overdue'),
    'canceled_month', (select count(*) from public.cf_subscriptions s
              where s.status = 'canceled' and not s.internal and s.updated_at >= m0),
    'months', (select coalesce(jsonb_agg(jsonb_build_object('month', g.d, 'received',
                (select coalesce(sum(amount), 0) from public.cf_saas_payments
                  where status in ('received', 'confirmed') and paid_at >= g.d and paid_at < g.d + interval '1 month'))
                order by g.d), '[]'::jsonb)
              from (select (m0 - make_interval(months => k))::date as d from generate_series(5, 0, -1) k) g),
    'recent', (select coalesce(jsonb_agg(jsonb_build_object('email', u.email, 'amount', p.amount, 'status', p.status,
                'due_date', p.due_date, 'paid_at', p.paid_at) order by p.created_at desc), '[]'::jsonb)
              from (select * from public.cf_saas_payments order by created_at desc limit 20) p
              left join auth.users u on u.id = p.owner_id)
  ) into r;
  return r;
end $$;

revoke all on function public.cf_admin_finance() from public, anon;
grant execute on function public.cf_admin_finance() to authenticated;

-- 3) Aviso do Asaas (só a função de servidor chama) ---------------------------------
create or replace function public.cf_asaas_apply(p_event text, p_payment jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  pid text := p_payment ->> 'id';
  cust text := p_payment ->> 'customer';
  ext text := p_payment ->> 'externalReference';
  v_owner uuid;
  v_status text;
  v_amount numeric := coalesce((p_payment ->> 'value')::numeric, 0);
  v_due date := nullif(p_payment ->> 'dueDate', '')::date;
  v_paid timestamptz := coalesce(nullif(p_payment ->> 'confirmedDate', '')::timestamptz,
                                 nullif(p_payment ->> 'paymentDate', '')::timestamptz);
  s public.cf_subscriptions;
  new_end timestamptz;
begin
  if pid is null then raise exception 'pagamento sem identificador'; end if;

  select owner_id into v_owner from public.cf_subscriptions where asaas_customer_id = cust limit 1;
  if v_owner is null and ext ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    select id into v_owner from auth.users where id = ext::uuid;
  end if;

  v_status := case
    when p_event = 'PAYMENT_DELETED' then 'deleted'
    else case p_payment ->> 'status'
      when 'RECEIVED' then 'received'
      when 'RECEIVED_IN_CASH' then 'received'
      when 'CONFIRMED' then 'confirmed'
      when 'OVERDUE' then 'overdue'
      when 'REFUNDED' then 'refunded'
      when 'REFUND_REQUESTED' then 'refunded'
      else 'pending'
    end
  end;

  select * into s from public.cf_subscriptions where owner_id = v_owner;

  insert into public.cf_saas_payments (owner_id, asaas_payment_id, amount, status, due_date, paid_at, plan)
    values (v_owner, pid, v_amount, v_status, v_due, v_paid, s.plan)
  on conflict (asaas_payment_id) do update set
    owner_id = coalesce(excluded.owner_id, public.cf_saas_payments.owner_id),
    amount = excluded.amount,
    status = excluded.status,
    due_date = coalesce(excluded.due_date, public.cf_saas_payments.due_date),
    paid_at = coalesce(excluded.paid_at, public.cf_saas_payments.paid_at),
    updated_at = now();

  if v_owner is not null and s.owner_id is not null and s.status <> 'courtesy' then
    if v_status in ('received', 'confirmed') then
      -- Pagamento confirmado: libera o período seguinte. Repetir o aviso não muda o resultado.
      new_end := coalesce(v_due, current_date)::timestamptz
                 + case when s.cycle = 'annual' then interval '1 year' else interval '1 month' end;
      update public.cf_subscriptions
        set status = 'active', current_period_end = greatest(coalesce(current_period_end, new_end), new_end)
        where owner_id = v_owner;
    elsif v_status = 'overdue' and s.status = 'active' then
      update public.cf_subscriptions set status = 'past_due' where owner_id = v_owner;
    end if;
  end if;

  return jsonb_build_object('owner_found', v_owner is not null, 'status', v_status);
end $$;

revoke all on function public.cf_asaas_apply(text, jsonb) from public, anon, authenticated;
grant execute on function public.cf_asaas_apply(text, jsonb) to service_role;

-- 4) Resumo diário (só a função de servidor chama) -----------------------------------
create or replace function public.cf_admin_digest() returns jsonb
language sql stable security definer set search_path = '' as $$
  with a as (select * from public._cf_accounts() where not internal)
  select jsonb_build_object(
    'generated_at', now(),
    'totals', jsonb_build_object(
      'accounts', (select count(*) from a),
      'trialing', (select count(*) from a where state = 'trialing'),
      'paying', (select count(*) from a where status = 'active' and state = 'active'),
      'mrr', (select coalesce(round(sum(public._cf_monthly_price(plan, founder, cycle)), 2), 0)
                from a where status = 'active' and state in ('active', 'grace'))),
    'new_accounts', (select coalesce(jsonb_agg(jsonb_build_object('email', email, 'profession', profession)
                order by created_at desc), '[]'::jsonb) from a where created_at > now() - interval '24 hours'),
    'trials_ending', (select coalesce(jsonb_agg(jsonb_build_object('email', email, 'ends', trial_ends_at, 'clients', clients)
                order by trial_ends_at), '[]'::jsonb)
                from a where state = 'trialing' and trial_ends_at < now() + interval '3 days'),
    'late', (select coalesce(jsonb_agg(jsonb_build_object('email', email) order by email), '[]'::jsonb)
                from a where state = 'grace'),
    'support', (select coalesce(jsonb_agg(jsonb_build_object('email', u.email, 'message', left(s.message, 240))
                order by s.created_at desc), '[]'::jsonb)
                from public.cf_support_requests s left join auth.users u on u.id = s.owner_id
                where s.created_at > now() - interval '24 hours')
  )
$$;

revoke all on function public.cf_admin_digest() from public, anon, authenticated;
grant execute on function public.cf_admin_digest() to service_role;
